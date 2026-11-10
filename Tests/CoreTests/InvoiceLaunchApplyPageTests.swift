import XCTest
@testable import QuestifyCore

@MainActor final class InvoiceLaunchApplyPageTests: XCTestCase {
    private typealias S = InvoiceLaunchTestSupport

    func testApplyPageStaysHiddenWithoutAReadAndDoesNotCallTheCoordinator() async throws {
        let hidden = InvoiceLaunchApplyPage.project(
            lines: [InvoiceLaunchApplyOrderLine(orderID: 21, title: "Synthetic order", amount: .from(0))],
            titles: [], unresolved: false, capability: .absent)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        XCTAssertTrue(hidden.lines.isEmpty)
        XCTAssertTrue(hidden.titles.isEmpty)
        XCTAssertFalse(hidden.showsApplyAction)
        XCTAssertFalse(InvoiceLaunchApplyPage.routeMarkedLive)
        XCTAssertFalse(InvoiceLaunchApplyPage.includedInPlayerFirstEntry)
        XCTAssertFalse(InvoiceLaunchApplyPage.paymentEnabled)
        XCTAssertEqual(InvoiceLaunchApplyPage.titlesPath, "api/invoice/titles")
        XCTAssertEqual(InvoiceLaunchApplyPage.eligibleOrdersPath, "api/invoice/orders/eligible")
        XCTAssertEqual(InvoiceLaunchApplyPage.listPath, "api/invoice/list")
        XCTAssertEqual(InvoiceLaunchApplyPage.applyPath, "api/invoice/apply")
        XCTAssertEqual(InvoiceLaunchApplyPage.Key.referenced,
                       ["loading", "noOrders", "loadFailed", "session", "storage", "notSaved", "unknown", "retry", "checkResult"])

        let h = try S.Harness()
        h.enabled = true
        let denied = await InvoiceLaunchApplyPage.load(coordinator: try h.coordinator(), capability: .absent)
        XCTAssertTrue(denied.hidden)
        XCTAssertNil(denied.phase)
        XCTAssertTrue(h.wire.requests.isEmpty)

        let closed = try S.Harness()
        closed.enabled = false
        let refused = await InvoiceLaunchApplyPage.load(
            coordinator: try closed.coordinator(),
            capability: .init(readsEnabled: true, mutationsEnabled: true))
        XCTAssertTrue(refused.hidden)
        XCTAssertNil(refused.phase)
        XCTAssertFalse(refused.showsApplyAction)
        XCTAssertTrue(closed.wire.requests.isEmpty)
    }

    func testApplyPageLoadingEmptyReadyAndLiteralZero() async throws {
        let loading = InvoiceLaunchApplyPage.loading(capability: .init(readsEnabled: true, mutationsEnabled: false))
        XCTAssertEqual(loading.phase, .some(.loading))
        XCTAssertTrue(loading.hidden)
        XCTAssertEqual(loading.stateKey, "loading")
        XCTAssertTrue(loading.lines.isEmpty)
        XCTAssertFalse(loading.showsApplyAction)

        let absentLoading = InvoiceLaunchApplyPage.loading(capability: .absent)
        XCTAssertNil(absentLoading.phase)
        XCTAssertTrue(absentLoading.hidden)

        let h = try S.Harness()
        h.wire.responses = [try S.success([]), try S.success([]), try S.success([])]
        let empty = await InvoiceLaunchApplyPage.load(
            coordinator: try h.coordinator(),
            capability: .init(readsEnabled: true, mutationsEnabled: true))
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertEqual(empty.stateKey, "noOrders")
        XCTAssertFalse(empty.hidden)
        XCTAssertTrue(empty.lines.isEmpty)
        XCTAssertFalse(empty.showsApplyAction)
        XCTAssertEqual(h.wire.requests.map { $0.url!.lastPathComponent }, ["titles", "eligible", "list"])

        let readyHost = try S.Harness()
        readyHost.wire.responses = [
            try S.success([S.title]),
            try S.success([["orderId": "21", "amount": 0, "orderTitle": "Synthetic order"]]),
            try S.success([])
        ]
        let ready = await InvoiceLaunchApplyPage.load(
            coordinator: try readyHost.coordinator(),
            capability: .init(readsEnabled: true, mutationsEnabled: false))
        XCTAssertEqual(ready.phase, .some(.ready))
        XCTAssertNil(ready.stateKey)
        XCTAssertEqual(ready.lines.map(\.amountText), ["0"])
        XCTAssertEqual(ready.lines.first?.amount.literal, Optional(Decimal(0)))
        XCTAssertEqual(ready.lines.first?.titleText, "Synthetic order")
        XCTAssertEqual(ready.titles.map(\.id), [11])
        XCTAssertFalse(ready.showsApplyAction)
        XCTAssertFalse(readyHost.wire.requests.map { $0.url!.lastPathComponent }.contains("apply"))

        let granted = try S.Harness()
        granted.wire.responses = [
            try S.success([S.title]),
            try S.success([["orderId": "21", "amount": 0, "orderTitle": "Synthetic order"]]),
            try S.success([])
        ]
        let shown = await InvoiceLaunchApplyPage.load(
            coordinator: try granted.coordinator(),
            capability: .init(readsEnabled: true, mutationsEnabled: true))
        XCTAssertEqual(shown.phase, .some(.ready))
        XCTAssertTrue(shown.showsApplyAction)
        XCTAssertFalse(InvoiceLaunchApplyPage.paymentEnabled)
        XCTAssertFalse(granted.wire.requests.map { $0.url!.lastPathComponent }.contains("apply"))
    }

    func testUnknownAmountsAreEmDashAndALiteralZeroStaysZero() throws {
        XCTAssertEqual(InvoiceLaunchApplyAmount.parse(.absent).displayText, "—")
        XCTAssertNil(InvoiceLaunchApplyAmount.parse(.absent).literal)
        XCTAssertEqual(InvoiceLaunchApplyAmount.parse(.text("0")).displayText, "—")
        XCTAssertNil(InvoiceLaunchApplyAmount.parse(.text("0")).literal)
        XCTAssertEqual(InvoiceLaunchApplyAmount.parse(.text("0.00")).displayText, "—")
        XCTAssertEqual(InvoiceLaunchApplyAmount.parse(.notANumber).displayText, "—")
        XCTAssertNotEqual(InvoiceLaunchApplyAmount.parse(.text("0")).displayText, "0")
        let zero = InvoiceLaunchApplyAmount.parse(.number(0))
        XCTAssertEqual(zero.literal, Optional(Decimal(0)))
        XCTAssertEqual(zero.displayText, "0")
        XCTAssertEqual(InvoiceLaunchApplyAmount.parse(.number(Decimal(string: "0.00")!)).displayText, "0")
        XCTAssertEqual(InvoiceLaunchApplyAmount.parse(.number(Decimal(string: "7.125")!)).displayText, "7.125")
        XCTAssertEqual(InvoiceLaunchApplyAmount.from(.nan).displayText, "—")
        XCTAssertNil(InvoiceLaunchApplyAmount.from(.nan).literal)

        let title = InvoiceLaunchApplyTitleLine(id: 11, name: "Synthetic title", isDefault: false)
        let lines = [
            InvoiceLaunchApplyOrderLine(orderID: 21, title: "Synthetic order", amount: .parse(.text("0"))),
            InvoiceLaunchApplyOrderLine(orderID: 22, title: "   ", amount: .parse(.number(0)))
        ]
        let page = InvoiceLaunchApplyPage.project(
            lines: lines, titles: [title], unresolved: false,
            capability: .init(readsEnabled: true, mutationsEnabled: true))
        XCTAssertEqual(page.phase, .some(.unknown))
        XCTAssertEqual(page.stateKey, "unknown")
        XCTAssertEqual(page.recoveryKey, "checkResult")
        XCTAssertFalse(page.showsApplyAction)
        XCTAssertEqual(page.lines.map(\.amountText), ["—", "0"])
        XCTAssertEqual(page.lines[1].titleText, "—")
        XCTAssertEqual(page.lines[1].amount.literal, Optional(Decimal(0)))
        XCTAssertNil(page.lines[0].amount.literal)
    }

    func testLoadUsesTheExistingOverviewAndKeepsFailuresOffZero() async throws {
        let missing = try S.Harness()
        missing.wire.responses = [try S.success([S.title]), try S.success([["orderId": "21"]])]
        let failed = await InvoiceLaunchApplyPage.load(
            coordinator: try missing.coordinator(),
            capability: .init(readsEnabled: true, mutationsEnabled: true))
        XCTAssertEqual(failed.phase, .some(.error("loadFailed")))
        XCTAssertEqual(failed.retryKey, "retry")
        XCTAssertTrue(failed.lines.isEmpty)
        XCTAssertFalse(failed.showsApplyAction)
        XCTAssertEqual(missing.wire.requests.map { $0.url!.lastPathComponent }, ["titles", "eligible"])

        let rejected = try S.Harness()
        rejected.wire.responses = [try S.success([S.title]), try S.failure("INVOICE_FEATURE_OFF")]
        let notSaved = await InvoiceLaunchApplyPage.load(
            coordinator: try rejected.coordinator(),
            capability: .init(readsEnabled: true, mutationsEnabled: false))
        XCTAssertEqual(notSaved.phase, .some(.error("notSaved")))
        XCTAssertTrue(notSaved.lines.isEmpty)

        let stale = try S.Harness()
        stale.current = try S.session(account: 8)
        let session = await InvoiceLaunchApplyPage.load(
            coordinator: try stale.coordinator(),
            capability: .init(readsEnabled: true, mutationsEnabled: false))
        XCTAssertEqual(session.phase, .some(.error("session")))
        XCTAssertTrue(stale.wire.requests.isEmpty)

        let pendingHost = try S.Harness()
        let pending = InvoiceLaunchPending(kind: .apply, apply: try pendingHost.command())
        try pendingHost.store.save(pending)
        pendingHost.wire.responses = [
            try S.success([S.title]),
            try S.success([["orderId": "21", "amount": 0, "orderTitle": "Synthetic order"]]),
            try S.success([])
        ]
        let unresolved = await InvoiceLaunchApplyPage.load(
            coordinator: try pendingHost.coordinator(),
            capability: .init(readsEnabled: true, mutationsEnabled: true))
        XCTAssertEqual(unresolved.phase, .some(.unknown))
        XCTAssertEqual(unresolved.lines.map(\.amountText), ["0"])
        XCTAssertEqual(unresolved.lines.first?.amount.literal, Optional(Decimal(0)))
        XCTAssertFalse(unresolved.showsApplyAction)
        XCTAssertEqual(pendingHost.wire.requests.map { $0.url!.lastPathComponent }, ["titles", "eligible", "list"])
        XCTAssertFalse(pendingHost.wire.requests.map { $0.url!.lastPathComponent }.contains("apply"))
    }
}
