import XCTest
@testable import QuestifyCore
import Foundation

// All values synthetic. No network; the service is a test double that lives only in Tests/.
@MainActor private final class AppealMemoryStorage: TemplateAuthoringStorage {
    var items: [String: Data] = [:]
    func read(_ key: String) throws -> Data? { items[key] }
    func write(_ data: Data, key: String) throws { items[key] = data }
    func remove(_ key: String) throws { items[key] = nil }
}

@MainActor private final class FakeAppealService: BundleAppealServing {
    var submitHandler: (BundleAppealCommand) async throws -> BundleAppeal = { _ in throw URLError(.timedOut) }
    var receiptHandler: (String) async throws -> BundleAppealReceipt = { _ in throw URLError(.timedOut) }
    private(set) var submitted: [BundleAppealCommand] = []
    private(set) var receiptKeys: [String] = []
    func submit(_ command: BundleAppealCommand) async throws -> BundleAppeal {
        submitted.append(command); return try await submitHandler(command)
    }
    func receipt(idempotencyKey: String) async throws -> BundleAppealReceipt {
        receiptKeys.append(idempotencyKey); return try await receiptHandler(idempotencyKey)
    }
    func list(registrationID: FreeExploreLaunchID) async throws -> [BundleAppeal] { [] }
}

@MainActor final class BNDAppealModelTests: XCTestCase {
    private let key = "appeal-test-key-1"
    private func session() throws -> FreeExploreLaunchSession {
        try FreeExploreLaunchSession(baseURL: URL(string: "https://example.test")!, accountID: 5, market: "CN",
                                     namespace: "test", role: "player", epoch: 1, token: "synthetic-test-credential")
    }
    private func id(_ n: Int64) throws -> FreeExploreLaunchID { try FreeExploreLaunchID(n) }
    private func appeal(status: String = "OPEN", applyState: String? = nil) throws -> BundleAppeal {
        let apply = applyState.map { #""\#($0)""# } ?? "null"
        let json = #"{"id":77,"registrationId":9001,"unitId":21,"holderMemberId":5,"reasonCode":"MERCHANT_FORGOT_SCAN","status":"\#(status)","applyState":\#(apply),"idempotencyKey":"\#(key)","version":0}"#
        return try JSONDecoder().decode(BundleAppeal.self, from: Data(json.utf8))
    }
    private func receipt(_ kind: String, _ appeal: BundleAppeal?) throws -> BundleAppealReceipt {
        let body = appeal == nil ? "null" : #"{"id":77,"registrationId":9001,"unitId":21,"holderMemberId":5,"reasonCode":"MERCHANT_FORGOT_SCAN","status":"OPEN","idempotencyKey":"\#(key)","version":0}"#
        return try JSONDecoder().decode(BundleAppealReceipt.self, from: Data(#"{"idempotencyKey":"\#(key)","receipt":"\#(kind)","appeal":\#(body)}"#.utf8))
    }
    private func make(_ service: FakeAppealService, _ storage: AppealMemoryStorage) throws -> (BundleAppealModel, BundleAppealPendingStore) {
        let store = BundleAppealPendingStore(storage: storage, session: try session())
        let key = self.key
        return (BundleAppealModel(service: service, store: store, makeKey: { key }), store)
    }
    private func submit(_ model: BundleAppealModel) async throws {
        let registration = try id(9001), unit = try id(21)
        await model.submit(registrationID: registration, unitID: unit, reason: .merchantForgotScan, note: "n", evidenceRefs: ["m1"])
    }

    func testSubmitPersistsCommandBeforeDispatch() async throws {
        let service = FakeAppealService(), storage = AppealMemoryStorage()
        let (model, store) = try make(service, storage)
        var persistedAtDispatch: BundleAppealCommand?
        let reply = try appeal()
        service.submitHandler = { _ in persistedAtDispatch = try store.load(); return reply }
        try await submit(model)
        XCTAssertEqual(persistedAtDispatch?.idempotencyKey, key)
        XCTAssertEqual(persistedAtDispatch, service.submitted.first)
        XCTAssertNil(try store.load(), "a matching server answer releases the lock")
        XCTAssertEqual(model.state, .submitted(reply))
    }

    func testStorageFailureSendsNothing() async throws {
        @MainActor final class Failing: TemplateAuthoringStorage {
            func read(_ key: String) throws -> Data? { nil }
            func write(_ data: Data, key: String) throws { throw URLError(.cannotWriteToFile) }
            func remove(_ key: String) throws {}
        }
        let service = FakeAppealService()
        let model = BundleAppealModel(service: service, store: BundleAppealPendingStore(storage: Failing(), session: try session()), makeKey: { "appeal-k" })
        try await submit(model)
        XCTAssertEqual(model.state, .storageFailed)
        XCTAssertTrue(service.submitted.isEmpty)
    }

    func testUnknownOutcomeReadsBackBySameKey() async throws {
        let service = FakeAppealService(), storage = AppealMemoryStorage()
        let (model, store) = try make(service, storage)
        service.submitHandler = { _ in throw FreeExploreLaunchFailure.outcomeUnknown }
        try await submit(model)
        XCTAssertEqual(model.state, .awaitingReadback)
        XCTAssertNotNil(try store.load(), "command must survive an unknown outcome")
        let found = try receipt("FOUND", try appeal())
        service.receiptHandler = { _ in found }
        await model.recover()
        XCTAssertEqual(service.receiptKeys, [key])
        XCTAssertEqual(service.submitted.count, 1, "recovery never re-sends")
        XCTAssertNil(try store.load())
        XCTAssertEqual(model.state, .submitted(try appeal()))
    }

    func testReceiptNotFoundKeepsCommandAndDoesNotResendAutomatically() async throws {
        let service = FakeAppealService(), storage = AppealMemoryStorage()
        let (model, store) = try make(service, storage)
        service.submitHandler = { _ in throw URLError(.timedOut) }
        try await submit(model)
        let missing = try receipt("NOT_FOUND", nil)
        service.receiptHandler = { _ in missing }
        await model.recover()
        XCTAssertEqual(model.state, .readbackNotFound)
        XCTAssertFalse(missing.provesNoWrite)
        XCTAssertNotNil(try store.load())
        XCTAssertEqual(service.submitted.count, 1)
        // Explicit retry re-sends the SAME command (same key).
        service.submitHandler = { _ in try self.appeal() }
        await model.retryOriginal()
        XCTAssertEqual(service.submitted.map { $0.idempotencyKey }, [key, key])
    }

    func testSecondAppealForSameUnitBlockedByServerCodeShown() async throws {
        let service = FakeAppealService(), storage = AppealMemoryStorage()
        let (model, store) = try make(service, storage)
        service.submitHandler = { _ in throw FreeExploreLaunchFailure.response(status: 200, code: 409, businessCode: "APPEAL_ALREADY_OPEN", message: nil) }
        try await submit(model)
        XCTAssertEqual(model.state, .blocked(serverCode: "APPEAL_ALREADY_OPEN"))
        XCTAssertNil(try store.load(), "a definite refusal releases the lock")
    }

    func testLoginRequiredKeepsPendingCommand() async throws {
        let service = FakeAppealService(), storage = AppealMemoryStorage()
        let (model, store) = try make(service, storage)
        service.submitHandler = { _ in throw FreeExploreLaunchFailure.response(status: 200, code: 409, businessCode: "LOGIN_REQUIRED", message: nil) }
        try await submit(model)
        XCTAssertEqual(model.state, .loginRequired)
        XCTAssertNotNil(try store.load())
    }

    func testApprovedAppealDoesNotShowUnitAsRedeemedUntilServerSaysSo() throws {
        W8Text.languageOverride = "en"; defer { W8Text.languageOverride = nil }
        for apply in ["PENDING_SETTLEMENT_DECISION", "NOT_APPLIED", nil] {
            let shown = BundleAppealPresentation(try appeal(status: "APPROVED", applyState: apply))
            XCTAssertEqual(shown.headline, .approvedNotYetApplied)
            XCTAssertFalse(shown.showsUnitAsRedeemed)
            let copy = (shown.title + (shown.detail ?? "")).lowercased()
            for banned in ["refunded", "consumed", "redeemed"] { XCTAssertFalse(copy.contains(banned), copy) }
        }
        let open = BundleAppealPresentation(try appeal())
        XCTAssertEqual(open.headline, .submittedForReview)
        XCTAssertTrue(open.title.lowercased().contains("submitted for review"))
        XCTAssertEqual(BundleAppealPresentation(try appeal(status: "SOMETHING_NEW")).headline, .unknown)
    }

    func testCommandLimitsAndUnavailableDefault() async throws {
        XCTAssertThrowsError(try BundleAppealCommand(registrationId: id(1), unitId: id(2), reasonCode: .other,
            note: String(repeating: "a", count: 501), evidenceRefs: [], idempotencyKey: "k"))
        XCTAssertThrowsError(try BundleAppealCommand(registrationId: id(1), unitId: id(2), reasonCode: .other,
            note: "", evidenceRefs: (1...7).map { "m\($0)" }, idempotencyKey: "k"))
        XCTAssertNoThrow(try BundleAppealCommand(registrationId: id(1), unitId: id(2), reasonCode: .other,
            note: String(repeating: "a", count: 500), evidenceRefs: (1...6).map { "m\($0)" }, idempotencyKey: "k"))
        let model = BundleAppealModel(service: UnavailableBundleAppealService(),
                                      store: BundleAppealPendingStore(storage: AppealMemoryStorage(), session: try session()), makeKey: { "appeal-k" })
        try await submit(model)
        XCTAssertEqual(model.state, .unavailable)
    }
}
