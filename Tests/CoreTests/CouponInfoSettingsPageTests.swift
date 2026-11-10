import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

@MainActor final class CouponInfoSettingsPageTests: XCTestCase {
    final class Transport: CouponManagementTransport {
        var isSynthetic = true
        var requests: [CouponManagementRequest] = []
        var result: Result<(Data, Int), Error> = .success((Data(#"{"code":200,"data":[]}"#.utf8), 200))
        func send(_ request: CouponManagementRequest, session: CouponManagementSession) async throws -> (Data, Int) {
            requests.append(request)
            return try result.get()
        }
    }

    private func session() throws -> CouponManagementSession {
        try .init(accountID: 1, namespace: "synthetic", epoch: 1, authorizationRevision: "a")
    }

    private func rows(_ json: String) throws -> [CouponDefinition] {
        try CouponManagementContract.decodePublished(Data(json.utf8), status: 200)
    }

    private func validDraft() -> CouponManagementDraft {
        var draft = CouponManagementDraft()
        draft.name = "0"
        draft.quantity = "20"
        draft.couponType = 0
        draft.startTime = Date(timeIntervalSince1970: 1_800_000_000)
        draft.endTime = Date(timeIntervalSince1970: 1_800_086_400)
        return draft
    }

    func testSettingsPageStaysHiddenWithoutAReadAndDoesNotCallTheAdapter() async throws {
        let transport = Transport()
        let adapter = CouponManagementAdapter(transport: transport)
        let capability = CouponInfoSettingsCapability(readsGranted: false, publishGranted: true)
        XCTAssertFalse(capability.publishGranted)
        let hidden = await CouponInfoSettingsPage.load(
            adapter: adapter, session: try session(), editingID: 710,
            draft: validDraft(), capability: capability)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        XCTAssertNil(hidden.form)
        XCTAssertFalse(hidden.showsPublishAction)
        XCTAssertFalse(hidden.showsSaveAction)
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertFalse(CouponInfoSettingsPage.routeMarkedLive)
        XCTAssertFalse(CouponInfoSettingsPage.includedInPlayerFirstEntry)
        XCTAssertFalse(CouponInfoSettingsPage.paymentEnabled)
        XCTAssertFalse(CouponInfoSettingsPage.virtualGoodsEnabled)
        XCTAssertFalse(CouponInfoSettingsPage.saveEnabled)
        XCTAssertEqual(CouponInfoSettingsPage.publishedPath, "/api/coupon/mypublishlist")
        XCTAssertEqual(CouponInfoSettingsPage.publishPath, "/api/coupon/publish")
        XCTAssertEqual(CouponInfoSettingsPage.Key.referenced, [
            "couponManagement.loading", "couponManagement.empty", "couponManagement.signIn",
            "couponManagement.unavailable", "couponManagement.malformed", "couponManagement.serverError",
            "couponManagement.unknownOutcome", "couponManagement.forbidden", "couponManagement.storage",
            "couponManagement.changed", "couponManagement.invalid", "couponManagement.refresh",
            "couponManagement.checkPendingResults"
        ])

        let absent = await CouponInfoSettingsPage.load(
            adapter: adapter, session: try session(), editingID: nil, capability: .absent)
        XCTAssertTrue(absent.hidden)
        XCTAssertTrue(transport.requests.isEmpty)

        let closed = CouponInfoSettingsPage.loading(capability: .absent)
        XCTAssertNil(closed.phase)
        XCTAssertTrue(closed.hidden)
    }

    func testLoadingEmptyReadyAndLiteralZero() async throws {
        let read = CouponInfoSettingsCapability(canRead: true, canSubmitPublish: false)
        let loading = CouponInfoSettingsPage.project(
            sessionPresent: true, editingID: 710, rows: nil, failure: nil, unresolved: false,
            draft: nil, capability: read)
        XCTAssertEqual(loading.phase, .some(.loading))
        XCTAssertTrue(loading.hidden)
        XCTAssertEqual(loading.stateKey, "couponManagement.loading")
        XCTAssertNil(loading.form)
        XCTAssertFalse(loading.showsPublishAction)

        let signedOut = CouponInfoSettingsPage.project(
            sessionPresent: false, editingID: nil, rows: nil, failure: nil, unresolved: false,
            draft: nil, capability: read)
        XCTAssertEqual(signedOut.phase, .some(.empty))
        XCTAssertEqual(signedOut.stateKey, "couponManagement.signIn")
        XCTAssertNil(signedOut.form)
        XCTAssertFalse(signedOut.hidden)

        let noCreate = CouponInfoSettingsPage.project(
            sessionPresent: true, editingID: nil, rows: [], failure: nil, unresolved: false,
            draft: validDraft(), capability: read)
        XCTAssertEqual(noCreate.phase, .some(.empty))
        XCTAssertEqual(noCreate.stateKey, "couponManagement.empty")
        XCTAssertNil(noCreate.form)
        XCTAssertFalse(noCreate.showsPublishAction)
        XCTAssertFalse(noCreate.showsSaveAction)

        let transport = Transport()
        let created = await CouponInfoSettingsPage.load(
            adapter: CouponManagementAdapter(transport: transport), session: try session(),
            editingID: nil, draft: validDraft(),
            capability: .init(canRead: true, canSubmitPublish: true))
        XCTAssertEqual(created.phase, .some(.ready))
        XCTAssertNil(created.stateKey)
        XCTAssertEqual(created.form?.nameText, "0")
        XCTAssertEqual(created.form?.quantityText, "20")
        XCTAssertEqual(created.form?.amountText, "—")
        XCTAssertNil(created.form?.amount.literal)
        XCTAssertEqual(created.form?.typeText, "couponManagement.gift")
        XCTAssertTrue(created.showsPublishAction)
        XCTAssertFalse(created.showsSaveAction)
        XCTAssertFalse(CouponInfoSettingsPage.paymentEnabled)
        XCTAssertTrue(transport.requests.isEmpty)

        let zero = try rows(#"{"code":200,"data":[{"id":710,"name":"0","status":0,"publishCount":0,"receiveCount":0,"useCount":0,"amount":0,"currency":"0","perLimit":0}]}"#)
        let edited = CouponInfoSettingsPage.project(
            sessionPresent: true, editingID: 710, rows: zero, failure: nil, unresolved: false,
            draft: validDraft(), capability: .init(canRead: true, canSubmitPublish: true))
        XCTAssertEqual(edited.phase, .some(.ready))
        XCTAssertEqual(edited.form?.nameText, "0")
        XCTAssertEqual(edited.form?.quantityText, "0")
        XCTAssertEqual(edited.form?.publishedText, "0")
        XCTAssertEqual(edited.form?.receivedText, "0")
        XCTAssertEqual(edited.form?.usedText, "0")
        XCTAssertEqual(edited.form?.remainingText, "0")
        XCTAssertEqual(edited.form?.perLimitText, "0")
        XCTAssertEqual(edited.form?.amountText, "0")
        XCTAssertEqual(edited.form?.amount.literal, Optional(Decimal(0)))
        XCTAssertEqual(edited.form?.currencyText, "0")
        XCTAssertEqual(edited.form?.statusText, "couponManagement.scheduled")
        XCTAssertFalse(edited.showsPublishAction)
        XCTAssertFalse(edited.showsSaveAction)
    }

    func testUnknownAmountsAreEmDashAndALiteralZeroStaysZero() throws {
        XCTAssertEqual(CouponInfoAmount.parse(.absent).displayText, "—")
        XCTAssertNil(CouponInfoAmount.parse(.absent).literal)
        XCTAssertEqual(CouponInfoAmount.parse(.text("0")).displayText, "—")
        XCTAssertNil(CouponInfoAmount.parse(.text("0")).literal)
        XCTAssertEqual(CouponInfoAmount.parse(.text("0.00")).displayText, "—")
        XCTAssertEqual(CouponInfoAmount.parse(.text("UNKNOWN")).displayText, "—")
        XCTAssertEqual(CouponInfoAmount.parse(.notANumber).displayText, "—")
        XCTAssertNotEqual(CouponInfoAmount.parse(.text("0")).displayText, "0")
        let zero = CouponInfoAmount.parse(.number(0))
        XCTAssertEqual(zero.literal, Optional(Decimal(0)))
        XCTAssertEqual(zero.displayText, "0")
        XCTAssertEqual(CouponInfoAmount.parse(.number(Decimal(string: "0.00")!)).displayText, "0")
        XCTAssertEqual(CouponInfoAmount.parse(.number(Decimal(string: "7.125")!)).displayText, "7.125")
        XCTAssertEqual(CouponInfoAmount.from(.nan).displayText, "—")
        XCTAssertNil(CouponInfoAmount.from(.nan).literal)
        XCTAssertEqual(CouponInfoCount.display(nil), "—")
        XCTAssertEqual(CouponInfoCount.display(0), "0")

        let rows = try rows(#"{"code":200,"data":[{"id":710,"name":"0","status":1,"publishCount":0,"amount":null},{"id":711,"status":99,"publishCount":0,"amount":0}]}"#)
        let missing = CouponInfoSettingsPage.project(
            sessionPresent: true, editingID: 710, rows: rows, failure: nil, unresolved: false,
            draft: nil, capability: .init(canRead: true, canSubmitPublish: false))
        XCTAssertEqual(missing.phase, .some(.ready))
        XCTAssertEqual(missing.form?.nameText, "0")
        XCTAssertEqual(missing.form?.amountText, "—")
        XCTAssertNil(missing.form?.amount.literal)
        XCTAssertEqual(missing.form?.quantityText, "0")
        XCTAssertEqual(missing.form?.publishedText, "0")
        XCTAssertEqual(missing.form?.receivedText, "—")
        XCTAssertEqual(missing.form?.remainingText, "—")
        XCTAssertEqual(missing.form?.currencyText, "—")
        XCTAssertFalse(missing.showsPublishAction)

        let unknown = CouponInfoSettingsPage.project(
            sessionPresent: true, editingID: 711, rows: rows, failure: nil, unresolved: false,
            draft: nil, capability: .init(canRead: true, canSubmitPublish: true))
        XCTAssertEqual(unknown.phase, .some(.unknown))
        XCTAssertEqual(unknown.stateKey, "couponManagement.unknownOutcome")
        XCTAssertEqual(unknown.recoveryKey, "couponManagement.checkPendingResults")
        XCTAssertEqual(unknown.form?.amountText, "0")
        XCTAssertEqual(unknown.form?.amount.literal, Optional(Decimal(0)))
        XCTAssertEqual(unknown.form?.quantityText, "0")
        XCTAssertEqual(unknown.form?.statusText, "couponManagement.unknownStatus")
        XCTAssertFalse(unknown.showsPublishAction)
        XCTAssertFalse(unknown.showsSaveAction)

        var typed = CouponManagementDraft()
        typed.quantity = "0"
        typed.name = "0"
        let held = CouponInfoSettingsPage.project(
            sessionPresent: true, editingID: nil, rows: nil, failure: nil, unresolved: true,
            draft: typed, capability: .init(canRead: true, canSubmitPublish: true))
        XCTAssertEqual(held.phase, .some(.unknown))
        XCTAssertEqual(held.form?.nameText, "0")
        XCTAssertEqual(held.form?.quantityText, "0")
        XCTAssertEqual(held.form?.amountText, "—")
        XCTAssertFalse(held.showsPublishAction)
    }

    func testEditLoadUsesThePublishedListAndKeepsFailuresOffZero() async throws {
        let transport = Transport()
        transport.result = .success((Data(#"{"code":200,"data":[{"id":710,"name":"Synthetic","status":1,"publishCount":5,"amount":"12.50"}]}"#.utf8), 200))
        let loaded = await CouponInfoSettingsPage.load(
            adapter: CouponManagementAdapter(transport: transport), session: try session(),
            editingID: 710, capability: .init(canRead: true, canSubmitPublish: true))
        XCTAssertEqual(loaded.phase, .some(.ready))
        XCTAssertEqual(loaded.form?.amount.literal, Decimal(string: "12.50"))
        XCTAssertNotEqual(loaded.form?.amountText, "—")
        XCTAssertNotEqual(loaded.form?.amountText, "0")
        XCTAssertEqual(loaded.form?.quantityText, "5")
        XCTAssertEqual(transport.requests.map(\.path), ["/api/coupon/mypublishlist"])
        XCTAssertFalse(transport.requests.contains(where: \.mutates))
        XCTAssertFalse(loaded.showsSaveAction)
        XCTAssertFalse(loaded.showsPublishAction)

        let missing = Transport()
        let absent = await CouponInfoSettingsPage.load(
            adapter: CouponManagementAdapter(transport: missing), session: try session(),
            editingID: 710, capability: .init(canRead: true, canSubmitPublish: false))
        XCTAssertEqual(absent.phase, .some(.error("couponManagement.unavailable")))
        XCTAssertEqual(absent.retryKey, "couponManagement.refresh")
        XCTAssertNil(absent.form)
        XCTAssertFalse(absent.showsPublishAction)
        XCTAssertEqual(missing.requests.map(\.path), ["/api/coupon/mypublishlist"])

        let bad = Transport()
        let invalid = await CouponInfoSettingsPage.load(
            adapter: CouponManagementAdapter(transport: bad), session: try session(),
            editingID: 0, capability: .init(canRead: true, canSubmitPublish: true))
        XCTAssertEqual(invalid.phase, .some(.error("couponManagement.invalid")))
        XCTAssertNil(invalid.form)
        XCTAssertTrue(bad.requests.isEmpty)

        let unknownAmount = Transport()
        unknownAmount.result = .success((Data(#"{"code":200,"data":[{"id":710,"amount":"UNKNOWN","status":1}]}"#.utf8), 200))
        let failed = await CouponInfoSettingsPage.load(
            adapter: CouponManagementAdapter(transport: unknownAmount), session: try session(),
            editingID: 710, capability: .init(canRead: true, canSubmitPublish: true))
        XCTAssertEqual(failed.phase, .some(.error("couponManagement.malformed")))
        XCTAssertNil(failed.form)
        XCTAssertFalse(failed.showsPublishAction)

        let rejected = Transport()
        rejected.result = .success((Data(#"{"code":500,"msg":"no"}"#.utf8), 500))
        let server = await CouponInfoSettingsPage.load(
            adapter: CouponManagementAdapter(transport: rejected), session: try session(),
            editingID: 710, capability: .init(canRead: true, canSubmitPublish: false))
        XCTAssertEqual(server.phase, .some(.error("couponManagement.serverError")))
        XCTAssertNil(server.form)

        let thrown = Transport()
        thrown.result = .failure(URLError(.timedOut))
        let down = await CouponInfoSettingsPage.load(
            adapter: CouponManagementAdapter(transport: thrown), session: try session(),
            editingID: 710, capability: .init(canRead: true, canSubmitPublish: false))
        XCTAssertEqual(down.phase, .some(.error("couponManagement.unavailable")))
        XCTAssertNil(down.form)

        let cancelled = Transport()
        cancelled.result = .failure(CancellationError())
        let waiting = await CouponInfoSettingsPage.load(
            adapter: CouponManagementAdapter(transport: cancelled), session: try session(),
            editingID: 710, capability: .init(canRead: true, canSubmitPublish: true))
        XCTAssertEqual(waiting.phase, .some(.loading))
        XCTAssertTrue(waiting.hidden)
        XCTAssertNil(waiting.form)

        let locked = CouponInfoSettingsPage.project(
            sessionPresent: true, editingID: 710, rows: nil, failure: .locked, unresolved: false,
            draft: nil, capability: .init(canRead: true, canSubmitPublish: true))
        XCTAssertEqual(locked.phase, .some(.unknown))
        XCTAssertEqual(locked.form?.amountText, "—")
        XCTAssertNil(locked.form?.amount.literal)
        XCTAssertFalse(locked.showsPublishAction)
        XCTAssertFalse(locked.showsSaveAction)

        let unsigned = await CouponInfoSettingsPage.load(
            adapter: CouponManagementAdapter(transport: Transport()), session: nil,
            editingID: 710, capability: .init(canRead: true, canSubmitPublish: true))
        XCTAssertEqual(unsigned.phase, .some(.empty))
        XCTAssertEqual(unsigned.stateKey, "couponManagement.signIn")
        XCTAssertNil(unsigned.form)
    }
}
