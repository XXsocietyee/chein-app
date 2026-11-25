import XCTest
@testable import QuestifyCore
import Foundation

// All values synthetic. No network. The service is a test double; production default is the unavailable one.
@MainActor private final class RenewalDouble: BundleRenewalServing {
    var isCurrent = true
    var permitsWrites = true
    var latest: BundleRenewalRecord?
    var readError: Error?
    var submitHandler: (BundleRenewalCommand) throws -> BundleRenewalRecord = { _ in throw FreeExploreLaunchFailure.disabled }
    private(set) var submitted: [BundleRenewalCommand] = []
    func latestIntent(registrationID: FreeExploreLaunchID) async throws -> BundleRenewalRecord? {
        if let readError { throw readError }
        return latest
    }
    func submitIntent(_ command: BundleRenewalCommand) async throws -> BundleRenewalRecord {
        submitted.append(command); return try submitHandler(command)
    }
}

@MainActor final class BNDRenewalModelTests: XCTestCase {
    private func rid(_ n: Int64 = 9001) throws -> FreeExploreLaunchID { try FreeExploreLaunchID(n) }
    private func record(id: Int64, intent: String, key: String? = nil, extra: String = "") throws -> BundleRenewalRecord {
        let keyJSON = key.map { #","idempotencyKey":"\#($0)""# } ?? ""
        let json = #"{"id":\#(id),"registrationId":9001,"holderMemberId":5,"intent":"\#(intent)"\#(keyJSON)\#(extra)}"#
        return try JSONDecoder().decode(BundleRenewalRecord.self, from: Data(json.utf8))
    }
    private func model(_ service: RenewalDouble, keys: [String] = ["k1", "k2", "k3"]) throws -> BundleRenewalModel {
        var remaining = keys
        return BundleRenewalModel(registrationID: try rid(), service: service, makeKey: { remaining.isEmpty ? "kx" : remaining.removeFirst() })
    }

    func testLatestIntentWins() async throws {
        let service = RenewalDouble()
        service.latest = try record(id: 10, intent: "MAYBE")
        let m = try model(service)
        await m.load()
        XCTAssertEqual(m.latest?.intent, "MAYBE")
        service.submitHandler = { [self] command in try record(id: 11, intent: command.intent.rawValue, key: command.idempotencyKey) }
        await m.submit(intent: .willRenew, note: nil)
        XCTAssertEqual(m.latest?.intent, "WILL_RENEW")
        XCTAssertEqual(m.latest?.id.value, 11)
        // A stale read (lower server id) never replaces the newer intent.
        service.latest = try record(id: 10, intent: "MAYBE")
        await m.load()
        XCTAssertEqual(m.latest?.intent, "WILL_RENEW")
        // A newer record from elsewhere does.
        service.latest = try record(id: 12, intent: "NO")
        await m.load()
        XCTAssertEqual(m.latest?.intent, "NO")
    }

    func testRenewalNeverShowsPriceOrPaymentUI() throws {
        // 1. The record contract carries no money field even if the server sends one.
        let decoded = try record(id: 1, intent: "MAYBE", extra: #","price":"199.00","amount":199,"paidAmount":"199","currency":"CNY""#)
        let fields = Mirror(reflecting: decoded).children.compactMap { $0.label }
        for forbidden in ["price", "amount", "paidAmount", "currency"] { XCTAssertFalse(fields.contains(forbidden)) }
        // 2. The command body has no money field.
        let body = try BundleRenewalCommand(registrationId: rid(), intent: .willRenew, note: "x", idempotencyKey: "k1")
        let encoded = try String(data: JSONEncoder().encode(body), encoding: .utf8) ?? ""
        for forbidden in ["price", "amount", "currency", "pay"] { XCTAssertFalse(encoded.lowercased().contains(forbidden)) }
        // 3. The view source references no price / payment / purchase vocabulary.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("App/BundleRenewalIntentView.swift"), encoding: .utf8).lowercased()
        for forbidden in ["price", "pay", "charge", "amount", "currency", "decimal", "storekit", "purchase", "checkout", "buy", "order", "¥", "$("] {
            XCTAssertFalse(source.contains(forbidden), "view source mentions \(forbidden)")
        }
        XCTAssertTrue(source.contains("renewal.intentonly"))
    }

    func testDefaultServiceIsUnavailableAndNeverWrites() async throws {
        let m = BundleRenewalModel(registrationID: try rid(), service: BundleRenewalUnavailableService())
        await m.load()
        XCTAssertEqual(m.phase, .unavailable)
        XCTAssertNil(m.latest)
        XCTAssertFalse(m.canSubmit)
        await m.submit(intent: .willRenew, note: nil)
        XCTAssertNil(m.latest)
        XCTAssertEqual(m.phase, .unavailable)
    }

    func testSubmitBlockedWhenWritesNotPermitted() async throws {
        let service = RenewalDouble(); service.permitsWrites = false
        let m = try model(service)
        XCTAssertFalse(m.canSubmit)
        await m.submit(intent: .no, note: nil)
        XCTAssertTrue(service.submitted.isEmpty)
    }

    func testUnknownOutcomeRetriesWithSameKeyAndNeverRekeys() async throws {
        let service = RenewalDouble()
        service.submitHandler = { _ in throw FreeExploreLaunchFailure.outcomeUnknown }
        let m = try model(service)
        await m.submit(intent: .willRenew, note: " later ")
        XCTAssertEqual(m.phase, .outcomeUnknown)
        XCTAssertFalse(m.canSubmit)
        service.submitHandler = { [self] command in try record(id: 20, intent: command.intent.rawValue, key: command.idempotencyKey) }
        await m.retry()
        XCTAssertEqual(service.submitted.map { $0.idempotencyKey }, ["k1", "k1"])
        XCTAssertEqual(service.submitted.last?.note, "later")
        XCTAssertEqual(m.phase, .loaded)
        XCTAssertEqual(m.latest?.id.value, 20)
        XCTAssertTrue(m.canSubmit)
    }

    func testRecoverResolvesOnlyWhenServerEchoesTheKey() async throws {
        let service = RenewalDouble()
        service.submitHandler = { _ in throw URLError(.timedOut) }
        let m = try model(service)
        await m.submit(intent: .maybe, note: nil)
        XCTAssertEqual(m.phase, .outcomeUnknown)
        service.latest = try record(id: 30, intent: "NO", key: "other")
        await m.recover()
        XCTAssertEqual(m.phase, .outcomeUnknown) // a read without our key proves nothing
        service.latest = try record(id: 31, intent: "MAYBE", key: "k1")
        await m.recover()
        XCTAssertEqual(m.phase, .loaded)
        XCTAssertEqual(m.latest?.id.value, 31)
    }

    func testDefiniteRefusalClearsPendingAndAllowsNewSubmit() async throws {
        let service = RenewalDouble()
        service.submitHandler = { _ in throw FreeExploreLaunchFailure.response(status: 200, code: 409, businessCode: "LOGIN_REQUIRED", message: nil) }
        let m = try model(service)
        await m.submit(intent: .no, note: nil)
        XCTAssertEqual(m.phase, .failed)
        XCTAssertEqual(m.failure, .response(status: 200, code: 409, businessCode: "LOGIN_REQUIRED", message: nil))
        XCTAssertTrue(m.canSubmit)
    }

    func testCommandValidation() throws {
        XCTAssertThrowsError(try BundleRenewalCommand(registrationId: rid(), intent: .no, note: String(repeating: "a", count: 201), idempotencyKey: "k"))
        XCTAssertThrowsError(try BundleRenewalCommand(registrationId: rid(), intent: .no, note: nil, idempotencyKey: ""))
        XCTAssertThrowsError(try BundleRenewalCommand(registrationId: rid(), intent: .no, note: nil, idempotencyKey: "bad key"))
        XCTAssertNil(try BundleRenewalCommand(registrationId: rid(), intent: .no, note: "   ", idempotencyKey: "k").note)
        XCTAssertEqual(BundleRenewalIntent.allCases.map { $0.rawValue }, ["WILL_RENEW", "MAYBE", "NO"])
    }

    func testRetiredModelHidesDataAndStopsWork() async throws {
        let service = RenewalDouble(); service.latest = try record(id: 5, intent: "MAYBE")
        let m = try model(service)
        await m.load()
        m.retire()
        XCTAssertNil(m.latest)
        XCTAssertFalse(m.canSubmit)
    }
}
