import XCTest
@testable import QuestifyCore
import Foundation

// All values synthetic. The service is a test double; nothing here touches a network.
@MainActor private final class BNDReviewMemoryStorage: TemplateAuthoringStorage {
    var values: [String: Data] = [:]
    func read(_ key: String) throws -> Data? { values[key] }
    func write(_ data: Data, key: String) throws { values[key] = data }
    func remove(_ key: String) throws { values[key] = nil }
}

@MainActor private final class BNDReviewService: BundleReviewServing {
    var mineResult: Result<BundleReviewMine, Error> = .failure(FreeExploreLaunchFailure.disabled)
    var submitResult: Result<BundleReview, Error> = .failure(FreeExploreLaunchFailure.disabled)
    var pages: [Result<BundleReviewPage, Error>] = []
    private(set) var submitted: [BundleReviewCommand] = []
    private(set) var storedAtSubmit: [Bool] = []
    var onSubmit: (() -> Bool)?
    func mine(registrationID: FreeExploreLaunchID) async throws -> BundleReviewMine { try mineResult.get() }
    func list(topicID: FreeExploreLaunchID, cursor: String?, limit: Int) async throws -> BundleReviewPage {
        try pages.removeFirst().get()
    }
    func submit(_ command: BundleReviewCommand) async throws -> BundleReview {
        submitted.append(command)
        storedAtSubmit.append(onSubmit?() ?? false)
        return try submitResult.get()
    }
}

@MainActor final class BNDReviewModelTests: XCTestCase {
    private func id(_ n: Int64) throws -> FreeExploreLaunchID { try FreeExploreLaunchID(n) }
    private func session() throws -> FreeExploreLaunchSession {
        try FreeExploreLaunchSession(baseURL: URL(string: "https://example.test")!, accountID: 5, market: "CN",
                                     namespace: "test", role: "player", epoch: 1, token: "synthetic-test-credential")
    }
    private func review(_ n: Int64 = 1, status: String = "PENDING", key: String? = "rv-1",
                        registration: Int64 = 9001, holder: Int64 = 5) throws -> BundleReview {
        BundleReview(id: try id(n), registrationId: try id(registration), holderMemberId: try id(holder), topicId: try id(7),
                     rating: 4, content: "synthetic", status: status, idempotencyKey: key, createTime: nil)
    }
    private func model(_ service: BNDReviewService, storage: BNDReviewMemoryStorage? = nil) throws -> BundleReviewComposeModel {
        let store = try storage.map { BundleReviewPendingStore(storage: $0, session: try session()) }
        return BundleReviewComposeModel(registrationID: try id(9001), accountID: try id(5), service: service,
                                        pendingStore: store, makeKey: { "rv-1" })
    }

    func testComposeBlockedWhenServerSaysNotEligible() async throws {
        let service = BNDReviewService()
        service.mineResult = .success(BundleReviewMine(eligible: false, reasonCode: "SYNTHETIC_NOT_ELIGIBLE", review: nil))
        let model = try model(service)
        await model.load()
        XCTAssertEqual(model.state, .blocked(reasonCode: "SYNTHETIC_NOT_ELIGIBLE"))
        let sent = await model.submit(rating: 5, content: "great")
        XCTAssertFalse(sent)
        XCTAssertTrue(service.submitted.isEmpty, "a blocked compose must never reach the service")
    }

    func testPendingReviewShownAsUnderReview() async throws {
        let service = BNDReviewService()
        service.mineResult = .success(BundleReviewMine(eligible: true, reasonCode: nil, review: nil))
        service.submitResult = .success(try review(status: "PENDING"))
        let model = try model(service)
        await model.load()
        XCTAssertEqual(model.state, .ready)
        await model.submit(rating: 4, content: "  synthetic  ")
        guard case .submitted(let shown) = model.state else { return XCTFail("expected submitted, got \(model.state)") }
        XCTAssertEqual(shown.statusKind, .underReview)
        XCTAssertEqual(BundleReviewStatusKind.underReview.label, "审核中")
        XCTAssertNotEqual(BundleReviewStatusKind(status: "PENDING"), .published)
        XCTAssertEqual(BundleReviewStatusKind(status: "SOMETHING_NEW"), .unknown)
        XCTAssertEqual(service.submitted.first?.content, "synthetic")
    }

    func testDuplicateReviewShowsServerCode() async throws {
        let service = BNDReviewService()
        service.mineResult = .success(BundleReviewMine(eligible: true, reasonCode: nil, review: nil))
        service.submitResult = .failure(FreeExploreLaunchFailure.response(status: 200, code: 409, businessCode: "SYNTHETIC_DUPLICATE", message: nil))
        let storage = BNDReviewMemoryStorage()
        let model = try model(service, storage: storage)
        await model.load()
        await model.submit(rating: 3, content: "again")
        XCTAssertEqual(model.state, .rejected(code: "SYNTHETIC_DUPLICATE"))
        XCTAssertTrue(storage.values.isEmpty, "a definite refusal releases the pending command")
    }

    func testPendingCommandIsPersistedBeforeDispatch() async throws {
        let service = BNDReviewService()
        let storage = BNDReviewMemoryStorage()
        service.mineResult = .success(BundleReviewMine(eligible: true, reasonCode: nil, review: nil))
        service.submitResult = .success(try review())
        service.onSubmit = { !storage.values.isEmpty }
        let model = try model(service, storage: storage)
        await model.load()
        await model.submit(rating: 5, content: "ok")
        XCTAssertEqual(service.storedAtSubmit, [true])
        XCTAssertTrue(storage.values.isEmpty, "confirmed success clears the pending command")
    }

    func testUnknownOutcomeReadsBackThenResendsSameKeyOnly() async throws {
        let service = BNDReviewService()
        let storage = BNDReviewMemoryStorage()
        service.mineResult = .success(BundleReviewMine(eligible: true, reasonCode: nil, review: nil))
        service.submitResult = .failure(FreeExploreLaunchFailure.outcomeUnknown)
        let model = try model(service, storage: storage)
        await model.load()
        await model.submit(rating: 5, content: "ok")
        XCTAssertEqual(model.state, .outcomeUnknown)
        XCTAssertFalse(model.canRetryOriginal, "no resend before a read-back")
        await model.retryOriginal()
        XCTAssertEqual(service.submitted.count, 1)
        await model.recover()
        XCTAssertTrue(model.canRetryOriginal)
        let landedReview = try review(key: "rv-1")
        service.submitResult = .success(landedReview)
        await model.retryOriginal()
        XCTAssertEqual(service.submitted.map(\.idempotencyKey), ["rv-1", "rv-1"])
        let expected = try review(key: "rv-1")
        XCTAssertEqual(model.state, .submitted(expected))
    }

    func testReadBackFindingSameKeyResolvesWithoutResend() async throws {
        let service = BNDReviewService()
        let storage = BNDReviewMemoryStorage()
        service.mineResult = .success(BundleReviewMine(eligible: true, reasonCode: nil, review: nil))
        service.submitResult = .failure(URLError(.timedOut))
        let model = try model(service, storage: storage)
        await model.load()
        await model.submit(rating: 5, content: "ok")
        let landed = try review(key: "rv-1")
        service.mineResult = .success(BundleReviewMine(eligible: false, reasonCode: nil, review: landed))
        await model.recover()
        let expected = try review(key: "rv-1")
        XCTAssertEqual(model.state, .submitted(expected))
        XCTAssertEqual(service.submitted.count, 1)
    }

    func testLoginRequiredKeepsPendingCommand() async throws {
        let service = BNDReviewService()
        let storage = BNDReviewMemoryStorage()
        service.mineResult = .success(BundleReviewMine(eligible: true, reasonCode: nil, review: nil))
        service.submitResult = .failure(FreeExploreLaunchFailure.response(status: 200, code: 409, businessCode: "LOGIN_REQUIRED", message: nil))
        let model = try model(service, storage: storage)
        await model.load()
        await model.submit(rating: 5, content: "ok")
        XCTAssertEqual(model.state, .outcomeUnknown)
        XCTAssertFalse(storage.values.isEmpty)
    }

    func testUnavailableDefaultNeverReturnsData() async throws {
        let model = BundleReviewComposeModel(registrationID: try id(9001), accountID: try id(5),
                                             service: UnavailableBundleReviewClient())
        await model.load()
        XCTAssertEqual(model.state, .unavailable)
        let list = BundleReviewListModel(topicID: try id(7), service: UnavailableBundleReviewClient())
        await list.load()
        XCTAssertEqual(list.state, .unavailable)
        XCTAssertTrue(list.items.isEmpty)
    }

    func testListShowsApprovedOnlyAndDeduplicates() async throws {
        let service = BNDReviewService()
        let r1 = try review(1, status: "APPROVED"), r2 = try review(2, status: "PENDING")
        let r3 = try review(3, status: "REJECTED"), r4 = try review(4, status: "APPROVED")
        service.pages = [
            .success(BundleReviewPage(items: [r1, r2, r3], nextCursor: "c2")),
            .success(BundleReviewPage(items: [r1, r4], nextCursor: nil))
        ]
        let list = BundleReviewListModel(topicID: try id(7), service: service)
        await list.load()
        XCTAssertEqual(list.items.map { $0.id.value }, [1])
        XCTAssertTrue(list.hasMore)
        await list.loadMore()
        XCTAssertEqual(list.items.map { $0.id.value }, [1, 4])
        XCTAssertFalse(list.hasMore)
    }

    func testCommandValidationBounds() throws {
        let reg = try id(9001)
        XCTAssertNoThrow(try BundleReviewCommand(registrationId: reg, rating: 1, content: "x", idempotencyKey: "k-1"))
        XCTAssertThrowsError(try BundleReviewCommand(registrationId: reg, rating: 0, content: "x", idempotencyKey: "k"))
        XCTAssertThrowsError(try BundleReviewCommand(registrationId: reg, rating: 6, content: "x", idempotencyKey: "k"))
        XCTAssertThrowsError(try BundleReviewCommand(registrationId: reg, rating: 3, content: "   ", idempotencyKey: "k"))
        XCTAssertNoThrow(try BundleReviewCommand(registrationId: reg, rating: 3, content: String(repeating: "评", count: 500), idempotencyKey: "k"))
        XCTAssertThrowsError(try BundleReviewCommand(registrationId: reg, rating: 3, content: String(repeating: "评", count: 501), idempotencyKey: "k"))
        XCTAssertThrowsError(try BundleReviewCommand(registrationId: reg, rating: 3, content: "x", idempotencyKey: "bad key"))
    }

    func testReviewDecodesWithStringIdsAndUnknownStatus() throws {
        let json = #"{"id":"11","registrationId":9001,"holderMemberId":"5","topicId":7,"rating":5,"content":"c","status":"FUTURE_STATE"}"#
        let value = try JSONDecoder().decode(BundleReview.self, from: Data(json.utf8))
        XCTAssertEqual(value.id.value, 11)
        XCTAssertEqual(value.statusKind, .unknown)
    }
}
