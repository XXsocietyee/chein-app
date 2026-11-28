import XCTest
@testable import Questify

@MainActor final class FreeExploreBundleLaunchModelTests: XCTestCase {
    private func id(_ value: Int64) throws -> FreeExploreLaunchID { try FreeExploreLaunchID(value) }
    private func model(_ wire: Wire, _ storage: Store, allowed: @escaping () -> Bool = { false }) throws -> FreeExploreBundleLaunchModel {
        try FreeExploreBundleLaunchModel(topicID: id(88), registrationID: id(41), service: wire,
            pending: FreeExploreLaunchPendingStore(storage: storage, session: wire.session), dispatchAllowed: allowed)
    }
    private func prepare(_ model: FreeExploreBundleLaunchModel) throws {
        model.prepare(unitID: try id(17), offerID: try id(29), startAt: 1_900_000_000_000)
    }
    func testDefaultHostGrantNeverCreatesReviewOrDispatches() async throws {
        let wire = try Wire(), model = try model(wire, Store())
        await model.load(); try prepare(model)
        XCTAssertNotNil(model.order); XCTAssertNil(model.review); XCTAssertFalse(model.canReserve)
        XCTAssertEqual(wire.posts.count, 0)
    }
    func testServerFlagCannotOverrideClosedServiceGrant() async throws {
        let wire = try Wire(); wire.permitsReservationDispatch = false
        let model = try model(wire, Store(), allowed: { true })
        await model.load(); try prepare(model)
        XCTAssertNil(model.review); XCTAssertEqual(wire.posts.count, 0)
    }
    func testWrongUnitAndOfferNeverCreateReview() async throws {
        let wire = try Wire(), model = try model(wire, Store(), allowed: { true })
        await model.load()
        model.prepare(unitID: try id(99), offerID: try id(29), startAt: 1_900_000_000_000)
        XCTAssertNil(model.review)
        model.prepare(unitID: try id(17), offerID: try id(99), startAt: 1_900_000_000_000)
        XCTAssertNil(model.review); XCTAssertTrue(wire.posts.isEmpty)
    }
    func testCancelReviewDoesNotPersistOrPost() async throws {
        let wire = try Wire(), store = Store(), model = try model(wire, store, allowed: { true })
        await model.load(); try prepare(model); XCTAssertNotNil(model.review)
        model.cancelReview(); XCTAssertNil(model.review)
        XCTAssertTrue(store.values.isEmpty); XCTAssertTrue(wire.posts.isEmpty)
    }
    func testRevocationAfterReviewBlocksConfirm() async throws {
        let wire = try Wire(), store = Store(); var granted = true
        let model = try model(wire, store, allowed: { granted })
        await model.load(); try prepare(model); let review = try XCTUnwrap(model.review)
        granted = false; await model.confirm(review)
        XCTAssertTrue(wire.posts.isEmpty); XCTAssertTrue(store.values.isEmpty)
    }
    func testRevocationDuringPreflightBlocksPersistenceAndPost() async throws {
        let wire = try Wire(), store = Store(); var granted = true
        let model = try model(wire, store, allowed: { granted })
        await model.load(); try prepare(model); let review = try XCTUnwrap(model.review)
        wire.onCatalog = { granted = false }
        await model.confirm(review)
        XCTAssertTrue(wire.posts.isEmpty); XCTAssertTrue(store.values.isEmpty)
        XCTAssertEqual(model.failure, .disabled)
    }
    func testUnknownPostRelaunchUsesOriginalKeyAndGetOnlyRecovery() async throws {
        let wire = try Wire(), store = Store(), first = try model(wire, store, allowed: { true })
        await first.load(); try prepare(first); let original = try XCTUnwrap(first.review)
        await first.confirm(original)
        XCTAssertEqual(first.state, .outcomeUnknown); XCTAssertEqual(wire.posts, [original.command])
        let relaunched = try model(wire, store) // host grant now CLOSED
        wire.hasReceipt = true; await relaunched.load()
        XCTAssertEqual(wire.posts.count, 1); XCTAssertEqual(wire.receiptKeys.last, original.command.idempotencyKey)
        XCTAssertTrue(store.values.isEmpty); XCTAssertNotNil(relaunched.order)
    }
    func testNullReceiptKeepsUnknownAndNoAutomaticReplay() async throws {
        let wire = try Wire(), store = Store(), model = try model(wire, store, allowed: { true })
        await model.load(); try prepare(model); let original = try XCTUnwrap(model.review)
        await model.confirm(original); await model.load(); await model.recover()
        XCTAssertEqual(model.state, .outcomeUnknown); XCTAssertEqual(wire.posts, [original.command])
        XCTAssertFalse(store.values.isEmpty); XCTAssertFalse(model.canReserve)
    }
    func testExplicitRetryReusesExactOriginalCommand() async throws {
        let wire = try Wire(), model = try model(wire, Store(), allowed: { true })
        await model.load(); try prepare(model); let original = try XCTUnwrap(model.review)
        await model.confirm(original); await model.retryOriginal()
        XCTAssertEqual(wire.posts, [original.command, original.command])
    }
    func testClosedRetryGrantLeavesRecoveryAvailable() async throws {
        let wire = try Wire(), store = Store(), first = try model(wire, store, allowed: { true })
        await first.load(); try prepare(first); await first.confirm(try XCTUnwrap(first.review))
        let closed = try model(wire, store)
        await closed.retryOriginal(); XCTAssertEqual(wire.posts.count, 1)
        await closed.recover(); XCTAssertFalse(wire.receiptKeys.isEmpty)
        XCTAssertEqual(closed.state, .outcomeUnknown)
    }
    func testRetirementHidesFactsAndPreservesUnknownRecord() async throws {
        let wire = try Wire(), store = Store(), model = try model(wire, store, allowed: { true })
        await model.load(); try prepare(model); let original = try XCTUnwrap(model.review)
        await model.confirm(original); model.retire(); await model.confirm(original)
        XCTAssertNil(model.catalog); XCTAssertNil(model.order); XCTAssertNil(model.review)
        XCTAssertEqual(model.state, .staleSession); XCTAssertFalse(store.values.isEmpty)
        XCTAssertEqual(wire.posts.count, 1)
    }
    func testSessionChangeDuringLoadRejectsLateFacts() async throws {
        let wire = try Wire(), model = try model(wire, Store())
        wire.onCatalog = { wire.isCurrent = false }
        await model.load()
        XCTAssertNil(model.order); XCTAssertNil(model.catalog); XCTAssertEqual(model.state, .staleSession)
    }
    func testReadFailureClearsPreviousDisplay() async throws {
        let wire = try Wire(), model = try model(wire, Store())
        await model.load(); XCTAssertNotNil(model.order)
        wire.failRead = true; await model.load()
        XCTAssertNil(model.order); XCTAssertNil(model.catalog); XCTAssertNotNil(model.failure)
    }
    func testStaleReviewCannotSubmitAfterRefresh() async throws {
        let wire = try Wire(), model = try model(wire, Store(), allowed: { true })
        await model.load(); try prepare(model); let original = try XCTUnwrap(model.review)
        await model.load(); await model.confirm(original)
        XCTAssertTrue(wire.posts.isEmpty)
    }
    func testLoadedOrderKeepsValidityHoldExitShopAndCancelFlagWithoutPosting() async throws {
        let wire = try Wire()
        wire.bundleFacts = [
            "units": [["id": 17, "registrationId": 41, "holderMemberId": 7, "chapterId": 3, "status": "AVAILABLE", "validTo": "2026-12-31"]],
            "chapters": [["chapterId": 3, "name": "章", "content": "正文", "stores": [["offerId": 29, "merchantName": "店"]]]],
            "reservations": [
                ["id": 61, "registrationId": 41, "holderMemberId": 7, "unitId": 17, "chapterId": 3, "offerId": 29, "merchantId": 5, "startAt": "2030-03-17T00:00:00Z", "status": "BOOKED", "idempotencyKey": "k", "requestFingerprint": "f"],
                ["id": 62, "registrationId": 41, "holderMemberId": 7, "unitId": 17, "chapterId": 3, "offerId": 29, "merchantId": 5, "startAt": "2030-03-18T00:00:00Z", "status": "CANCELLED", "idempotencyKey": "k2", "requestFingerprint": "f2"]
            ],
            "refundHold": ["state": "PREPARED", "refundId": 9],
            "exitCases": [["id": 10, "decision": "SWAP_CONSENTED", "unitId": 17], ["id": 11, "decision": "REFUND_UNFULFILLED"]]
        ]
        let model = try model(wire, Store())
        await model.load()
        let bundle = try XCTUnwrap(model.order?.bundle)
        XCTAssertEqual(bundle.units.first?.validTo, "2026-12-31")
        XCTAssertEqual(bundle.chapterContent(chapterID: try id(3)), "正文")
        XCTAssertEqual(bundle.shopName(offerID: try id(29)), "店")
        XCTAssertEqual(bundle.refundHold?.state, "PREPARED")
        XCTAssertEqual(bundle.refundHold?.refundId, "9")
        XCTAssertEqual(bundle.exitCases.map(\.decision), ["SWAP_CONSENTED", "REFUND_UNFULFILLED"])
        XCTAssertEqual(bundle.reservations.map(\.canCancel), [true, false])
        XCTAssertTrue(wire.posts.isEmpty)
        XCTAssertEqual(FreeExploreBundleLaunchView.reservationHeading(shopName: "店", chapterName: "章", locale: Locale(identifier: "zh-Hans")), "店")
        XCTAssertEqual(FreeExploreBundleLaunchView.reservationHeading(shopName: "", chapterName: "章", locale: Locale(identifier: "zh-Hans")), "章")
        XCTAssertNil(FreeExploreBundleLaunchView.refundHoldTitle("NOPE"))
        XCTAssertNotNil(FreeExploreBundleLaunchView.refundHoldTitle("PREPARED"))
        XCTAssertNotNil(FreeExploreBundleLaunchView.refundHoldTitle("RECONCILIATION_REQUIRED"))
        XCTAssertNil(FreeExploreBundleLaunchView.exitCaseTitle("OTHER"))
        XCTAssertNotNil(FreeExploreBundleLaunchView.exitCaseTitle("SWAP_CONSENTED"))
        XCTAssertNotNil(FreeExploreBundleLaunchView.exitCaseTitle("REFUND_UNFULFILLED"))
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let page = try String(contentsOf: root.appendingPathComponent("App/FreeExploreBundleLaunchView.swift"), encoding: .utf8)
        let catalog = try String(contentsOf: root.appendingPathComponent("Resources/FreeExploreBundleLaunch.xcstrings"), encoding: .utf8)
        for token in ["chapterContent(chapterID:", "shopName(offerID:", "unit.validTo", "reservation.canCancel",
                      "reservation.cancel", "reservation.monthlyWaiver", "freeBundle.refundHold", "exitCases.title",
                      "exitCase.SWAP_CONSENTED", "exitCase.REFUND_UNFULFILLED", "refundHold.PREPARED",
                      "freeBundle.unit.reserve.", "reserve.title", "displayedComponents: .hourAndMinute"] {
            XCTAssertTrue(page.contains(token), token)
        }
        // MP: the reserve form opens from a unit's 预约 and has no step counter or standing chapter picker.
        XCTAssertFalse(page.contains("stepHeader"))
        XCTAssertFalse(page.contains("Picker(selection: $unitID)"))
        XCTAssertFalse(page.contains("cancel-quote"))
        XCTAssertFalse(page.contains("makeCancel"))
        XCTAssertFalse(page.contains("exit-decision"))
        for copy in ["有效期至 %@", "退款准备中", "退款已申请", "退款已批准", "原路退款已确认到账",
                     "无现金取消已完成，没有现金退款", "退款未通过，权益暂时冻结", "退款人工处理中，权益暂时冻结",
                     "退款处理中", "售后记录", "已同意替换商家", "已申请未使用部分退款", "取消预约", "使用每月免费取消", "预约", "预约 %@", "日期", "时间"] {
            XCTAssertTrue(catalog.contains(copy), copy)
        }
    }
    private final class Store: TemplateAuthoringStorage {
        var values: [String: Data] = [:]
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { values[key] = data }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    private final class Wire: FreeExploreLaunchServing {
        let session: FreeExploreLaunchSession
        var isCurrent = true
        var permitsReservationDispatch = true
        var failRead = false, hasReceipt = false
        var posts: [FreeExploreLaunchReservationCommand] = []
        var receiptKeys: [String] = []
        var bundleFacts: [String: Any] = [:]
        var onCatalog: (() -> Void)?
        init() throws {
            session = try .init(baseURL: URL(string: "https://example.test")!, accountID: 7,
                market: "CN", namespace: "test", role: "player", epoch: 1, token: "synthetic-token")
        }
        private func decode<T: Decodable>(_ value: Any) throws -> T {
            try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
        }
        func catalog(topicID: FreeExploreLaunchID) async throws -> FreeExploreLaunchCatalog {
            onCatalog?(); if failRead { throw URLError(.notConnectedToInternet) }
            return try decode(["topicId": 88, "productType": 2, "saleEnabled": false, "reservationEnabled": true,
                "items": [["chapterId": 3, "unitsPerHolder": 1, "stores": [["offerId": 29]]]]])
        }
        private func receiptValue(_ command: FreeExploreLaunchReservationCommand) -> [String: Any] {
            ["id": 91, "registrationId": 41, "holderMemberId": 7, "unitId": 17, "chapterId": 3,
             "offerId": 29, "merchantId": 5, "startAt": "2030-03-17T00:00:00Z", "status": "BOOKED",
             "idempotencyKey": command.idempotencyKey, "requestFingerprint": command.fingerprint]
        }
        func order(registrationID: FreeExploreLaunchID) async throws -> FreeExploreLaunchOrder {
            if failRead { throw URLError(.notConnectedToInternet) }
            let reservations = hasReceipt ? posts.last.map { [receiptValue($0)] } ?? [] : []
            var bundle: [String: Any] = [
                "order": ["registrationId": 41, "holderMemberId": 7, "topicId": 88],
                "units": [["id": 17, "registrationId": 41, "holderMemberId": 7, "chapterId": 3, "status": "AVAILABLE"]],
                "reservations": reservations]
            for (key, value) in bundleFacts { bundle[key] = value }
            return try decode(["registrationId": 41, "bundle": bundle])
        }
        func reserve(_ command: FreeExploreLaunchReservationCommand) async throws -> FreeExploreLaunchReservation {
            posts.append(command); throw URLError(.networkConnectionLost)
        }
        func receipt(_ command: FreeExploreLaunchReservationCommand) async throws -> FreeExploreLaunchReservation? {
            receiptKeys.append(command.idempotencyKey)
            return hasReceipt ? try decode(receiptValue(command)) : nil
        }
        func refundQuote(registrationID: FreeExploreLaunchID) async throws -> FreeExploreLaunchRefundQuote {
            XCTFail("No refund surface in this candidate"); throw FreeExploreLaunchFailure.disabled
        }
    }
}
