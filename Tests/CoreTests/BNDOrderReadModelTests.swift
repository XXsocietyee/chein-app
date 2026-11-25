import XCTest
@testable import QuestifyCore
import Foundation

// Synthetic fixtures only (BNDFixtures lives in BNDContractsDecodingTests.swift). No network, no real clock.
@MainActor final class BNDOrderReadModelTests: XCTestCase {
    private func view(_ json: String) throws -> BundleOrderView {
        try JSONDecoder().decode(BundleOrderView.self, from: Data(json.utf8))
    }
    private func model(_ json: String) throws -> BundleOrderReadModel { BundleOrderReadModel(view: try view(json)) }
    private func receipt(_ json: String) throws -> BundleOrderReceipt {
        try JSONDecoder().decode(BundleOrderReceipt.self, from: Data(json.utf8))
    }
    private func withStatus(_ payment: Int, _ registration: Int) -> String {
        BNDFixtures.orderView()
            .replacingOccurrences(of: "\"paymentStatus\":2", with: "\"paymentStatus\":\(payment)")
            .replacingOccurrences(of: "\"registrationStatus\":2", with: "\"registrationStatus\":\(registration)")
    }

    func testActivationDerivedOnlyFromServerStatusInts() throws {
        XCTAssertEqual(try model(withStatus(2, 2)).activation, .active)
        XCTAssertEqual(try model(withStatus(1, 2)).activation, .pending)
        XCTAssertEqual(try model(withStatus(2, 1)).activation, .pending)
        XCTAssertEqual(try model(withStatus(0, 0)).activation, .pending)
        // Missing ints => unknown, never "active".
        let missing = BNDFixtures.orderView()
            .replacingOccurrences(of: "\"paymentStatus\":2,", with: "")
            .replacingOccurrences(of: "\"registrationStatus\":2,", with: "")
        XCTAssertEqual(try model(missing).activation, .unknown)
        // All units REFUNDED (server status) => refunded; the amount is never looked at.
        XCTAssertEqual(try model(BNDFixtures.orderView(unitStatus: "REFUNDED")).activation, .refunded)
        // Unknown unit status does not change activation.
        XCTAssertEqual(try model(BNDFixtures.orderView(unitStatus: "SOMETHING_NEW")).activation, .active)
    }

    func testLegacyOrderRoutesToLegacy() throws {
        let legacy = try model(BNDFixtures.legacyOrder)
        XCTAssertTrue(legacy.isLegacy)
        XCTAssertTrue(legacy.balances.isEmpty); XCTAssertTrue(legacy.units.isEmpty); XCTAssertTrue(legacy.reservations.isEmpty)
        XCTAssertFalse(legacy.hasBalanceDetail)
        XCTAssertEqual(legacy.registrationNo, "R-9001")
        XCTAssertFalse(try model(BNDFixtures.orderView()).isLegacy)
        // Thin decode from the existing order contract routes the same way.
        let thin = try JSONDecoder().decode(FreeExploreLaunchOrder.self, from: Data(BNDFixtures.legacyOrder.utf8))
        XCTAssertTrue(BundleOrderReadModel(order: thin).isLegacy)
    }

    func testReceiptPollStopsOnFoundAndNeverCreatesOrder() async throws {
        var requested: [String] = []
        var sleeps: [UInt64] = []
        let notFound = try receipt(BNDFixtures.receiptNotFound)
        let found = try receipt(BNDFixtures.receiptFound())
        let poller = BundleReceiptPoller(requestId: "bundle-order:9001", delaysNanoseconds: [10, 20, 40],
            fetch: { id in
                requested.append(id)
                return requested.count < 3 ? notFound : found
            },
            sleep: { sleeps.append($0) })
        await poller.run()
        XCTAssertEqual(requested, ["bundle-order:9001", "bundle-order:9001", "bundle-order:9001"])
        XCTAssertEqual(sleeps, [10, 20]) // backoff schedule honoured; stops right after FOUND
        guard case .found(let order) = poller.state else { return XCTFail("expected found, got \(poller.state)") }
        XCTAssertEqual(order.registrationId.value, 9001)
        // The poller only holds a read closure; the file itself contains no write route or POST.
        let source = try String(contentsOfFile: Self.sourcePath("Core/BundleOrderReadModel.swift"), encoding: .utf8)
        XCTAssertFalse(source.contains("\"POST\""))
        XCTAssertFalse(source.contains("registration/create"))
    }

    func testPollExhaustionIsStillUnconfirmedNotFailure() async throws {
        var calls = 0
        let notFound = try receipt(BNDFixtures.receiptNotFoundParked)
        let poller = BundleReceiptPoller(requestId: "bundle-order:9001", delaysNanoseconds: [1, 2],
            fetch: { _ in calls += 1; return notFound }, sleep: { _ in })
        await poller.run()
        XCTAssertEqual(calls, 3) // initial read + one per backoff entry
        XCTAssertEqual(poller.state, .stillUnconfirmed)
        XCTAssertFalse(notFound.provesNoWrite)
        if case .failed = poller.state { XCTFail("NOT_FOUND must not be a failure") }
    }

    func testPollDefiniteFailureStops() async throws {
        var calls = 0
        let poller = BundleReceiptPoller(requestId: "bundle-order:9001", delaysNanoseconds: [1, 2, 3],
            fetch: { _ in calls += 1; throw FreeExploreLaunchFailure.response(status: 200, code: 409, businessCode: "LOGIN_REQUIRED", message: nil) },
            sleep: { _ in })
        await poller.run()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(poller.state, .failed(.response(status: 200, code: 409, businessCode: "LOGIN_REQUIRED", message: nil)))
    }

    func testBalancesRenderCountsFromServerOnly() throws {
        // Server counts deliberately disagree with the single unit row: the model must copy the counts verbatim.
        let json = BNDFixtures.orderView().replacingOccurrences(
            of: "\"counts\":{\"AVAILABLE\":1,\"RESERVED\":0,", with: "\"counts\":{\"AVAILABLE\":7,\"RESERVED\":3,\"NEW_STATE\":2,")
        let m = try model(json)
        let balance = try XCTUnwrap(m.balances.first)
        XCTAssertEqual(balance.counts["AVAILABLE"], 7)
        XCTAssertEqual(balance.counts["RESERVED"], 3)
        XCTAssertEqual(balance.counts["NEW_STATE"], 2)
        XCTAssertEqual(m.units.count, 1)
        XCTAssertEqual(balance.orderedCountKeys.first, "AVAILABLE")
        XCTAssertEqual(balance.orderedCountKeys.last, "NEW_STATE") // unknown keys kept, after the known ones
        XCTAssertEqual(balance.unitsTotal, 1)
    }

    func testExpiredFlagComesFromServer() throws {
        let live = try model(BNDFixtures.orderView())
        XCTAssertFalse(try XCTUnwrap(live.balances.first).expired)
        XCTAssertEqual(live.activation, .active)
        // validTo in the fixture is far past or future relative to nothing: only the server flag matters.
        let json = BNDFixtures.orderView().replacingOccurrences(of: "\"expired\":false", with: "\"expired\":true")
        let expired = try model(json)
        XCTAssertTrue(try XCTUnwrap(expired.balances.first).expired)
        XCTAssertEqual(expired.activation, .expired)
        // Source scan: the read model never reads the device clock.
        let source = try String(contentsOfFile: Self.sourcePath("Core/BundleOrderReadModel.swift"), encoding: .utf8)
        XCTAssertFalse(source.contains("Date()"))
        XCTAssertFalse(source.contains("Date.now"))
    }

    func testReservationRowsSortedByStartAtAsServerOrder() throws {
        // Two reservations given later-first; the model must keep the server's order and not re-sort.
        let json = BNDFixtures.orderView().replacingOccurrences(
            of: "\"reservations\":[{",
            with: #""reservations":[{"id":32,"unitId":21,"registrationId":9001,"holderMemberId":5,"chapterId":11,"offerId":7,"merchantId":3,"startAt":"2027-01-01 12:00:00","status":"FULFILLED","idempotencyKey":"k-2","requestFingerprint":"fp-r2"},{"#)
        let m = try model(json)
        XCTAssertEqual(m.reservations.map { $0.id.value }, [32, 31])
        XCTAssertEqual(m.reservations.map(\.startAt), ["2027-01-01 12:00:00", "2026-12-01 12:00:00"])
        XCTAssertEqual(m.reservations.map(\.status), ["FULFILLED", "BOOKED"])
        XCTAssertTrue(m.reservations.allSatisfy(\.isKnownStatus))
        XCTAssertFalse(BundleReservationRow(id: try FreeExploreLaunchID(1), unitId: try FreeExploreLaunchID(1),
            chapterId: try FreeExploreLaunchID(1), offerId: try FreeExploreLaunchID(1), merchantId: try FreeExploreLaunchID(1),
            startAt: "x", status: "NEW").isKnownStatus)
    }

    private static func sourcePath(_ relative: String) -> String {
        // #filePath = <repo>/Tests/CoreTests/BNDOrderReadModelTests.swift
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url.appendingPathComponent(relative).path
    }
}
