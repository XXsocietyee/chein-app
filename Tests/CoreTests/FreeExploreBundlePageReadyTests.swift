import XCTest
@testable import QuestifyCore

/// Page states for `subpackageMember/free-explore/index`. Existing bundle tests stay as they are.
final class FreeExploreBundlePageReadyTests: XCTestCase {
    private func catalog(_ json: String) throws -> FreeExploreLaunchCatalog {
        try JSONDecoder().decode(FreeExploreLaunchCatalog.self, from: Data(json.utf8))
    }

    private func order(_ json: String) throws -> FreeExploreLaunchOrder {
        try JSONDecoder().decode(FreeExploreLaunchOrder.self, from: Data(json.utf8))
    }

    private func quote(_ json: String) throws -> FreeExploreLaunchRefundQuote {
        try JSONDecoder().decode(FreeExploreLaunchRefundQuote.self, from: Data(json.utf8))
    }

    private func ready(_ state: FreeExploreBundlePageReady.Screen) -> FreeExploreBundlePageReady.Facts? {
        if case .ready(let facts) = state { return facts }
        return nil
    }

    private var onSale: String {
        #"{"topicId":88,"productType":2,"saleEnabled":true,"reservationEnabled":false,"items":[{"chapterId":3,"unitsPerHolder":1,"stores":[{"offerId":29}]}]}"#
    }

    private var offSaleEmpty: String {
        #"{"topicId":88,"productType":2,"saleEnabled":false,"reservationEnabled":false,"items":[]}"#
    }

    func testUnknownMoneyIsADashAndLiteralZeroStaysZero() throws {
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText(nil as String?), FreeExploreBundlePageReady.unknownMoney)
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText(""), FreeExploreBundlePageReady.unknownMoney)
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText("   "), FreeExploreBundlePageReady.unknownMoney)
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText("nope"), FreeExploreBundlePageReady.unknownMoney)
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText("UNKNOWN"), FreeExploreBundlePageReady.unknownMoney)
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText("-1"), FreeExploreBundlePageReady.unknownMoney)
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText(nil as FreeExploreLaunchDecimal?), FreeExploreBundlePageReady.unknownMoney)
        XCTAssertEqual(FreeExploreBundlePageReady.unknownMoney, "—")
        XCTAssertNotEqual(FreeExploreBundlePageReady.moneyText(nil as String?), "0")
        XCTAssertNotEqual(FreeExploreBundlePageReady.moneyText(nil as String?), "0.00")
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText("0"), "0")
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText(" 0 "), "0")
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText("0.00"), "0.00")
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText("10.07"), "10.07")
        let zero = try JSONDecoder().decode(FreeExploreLaunchDecimal.self, from: Data("0".utf8))
        let zeroText = try JSONDecoder().decode(FreeExploreLaunchDecimal.self, from: Data("\"0.00\"".utf8))
        XCTAssertEqual(zero.text, "0")
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText(zero), "0")
        XCTAssertEqual(zeroText.text, "0.00")
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText(zeroText), "0.00")
        let missingAmount = #"{"route":"ORIGINAL_METHOD","amount":null,"totalValue":"1","remainingValue":"1","remainingRatio":"1","afterSalesForMerchantBreach":false,"reason":"x","policyVersion":"v"}"#
        XCTAssertThrowsError(try quote(missingAmount))
    }

    func testLoadingEmptyErrorAndUnknownStayDistinct() throws {
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .loading, failed: false, linkMissing: false, kept: nil), .loading)
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .loading, failed: false, linkMissing: true, kept: nil), .empty)
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .idle, failed: false, linkMissing: true, kept: nil), .empty)
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .idle, failed: true, linkMissing: false, kept: nil), .error(.load))
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .staleSession, failed: false, linkMissing: false, kept: nil), .error(.stale))
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .idle, failed: false, linkMissing: false, kept: nil), .unknown)
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .confirmed, failed: false, linkMissing: false, kept: nil), .unknown)
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .outcomeUnknown, failed: true, linkMissing: false, kept: nil), .unknown)
        let priced = FreeExploreBundlePageReady.Snapshot(priceText: "12.50")
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .outcomeUnknown, failed: false, linkMissing: false, kept: priced), .unknown)
        let bare = FreeExploreBundlePageReady.Snapshot()
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .idle, failed: false, linkMissing: false, kept: bare), .empty)
        let shelf = FreeExploreBundlePageReady.Snapshot(catalog: try catalog(offSaleEmpty))
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .idle, failed: false, linkMissing: false, kept: shelf), .empty)
        let garbage = FreeExploreBundlePageReady.Snapshot(catalog: try catalog(offSaleEmpty), priceText: "nope")
        XCTAssertEqual(FreeExploreBundlePageReady.screen(state: .idle, failed: false, linkMissing: false, kept: garbage), .empty)
        XCTAssertEqual(FreeExploreBundlePageReady.moneyText(garbage.priceText), "—")
    }

    func testLiteralZeroPriceAndPaidAmountStayZero() throws {
        let snapshot = FreeExploreBundlePageReady.Snapshot(catalog: try catalog(onSale), priceText: "0", paidAmountText: "0")
        let facts = try XCTUnwrap(ready(FreeExploreBundlePageReady.screen(state: .idle, failed: false, linkMissing: false, kept: snapshot)))
        XCTAssertEqual(facts.priceText, "0")
        XCTAssertEqual(facts.paidAmountText, "0")
        XCTAssertEqual(facts.refundAmountText, "—")
        XCTAssertEqual(facts.remainingValueText, "—")
        XCTAssertEqual(facts.totalValueText, "—")
        XCTAssertEqual(facts.saleEnabled, true)
        XCTAssertFalse(facts.catalogEmpty)
        XCTAssertFalse(facts.legacyOrder)
        XCTAssertFalse(facts.showsPurchase)
        XCTAssertFalse(facts.showsUnsubscribe)
        XCTAssertFalse(facts.showsQuoteOnlyNotice)
        XCTAssertFalse(facts.refreshing)
        XCTAssertFalse(facts.refreshFailed)
    }

    func testZeroQuoteStaysZeroAndMissingSaleIsNotFalse() throws {
        let body = #"{"route":"NOT_REFUNDABLE","amount":0,"totalValue":"0.00","remainingValue":"0","remainingRatio":"0","afterSalesForMerchantBreach":false,"reason":"none","policyVersion":"v"}"#
        let snapshot = FreeExploreBundlePageReady.Snapshot(quote: try quote(body), paidAmountText: "0.00")
        let facts = try XCTUnwrap(ready(FreeExploreBundlePageReady.screen(state: .confirmed, failed: false, linkMissing: false, kept: snapshot)))
        XCTAssertEqual(facts.refundAmountText, "0")
        XCTAssertEqual(facts.totalValueText, "0.00")
        XCTAssertEqual(facts.remainingValueText, "0")
        XCTAssertEqual(facts.paidAmountText, "0.00")
        XCTAssertEqual(facts.priceText, "—")
        XCTAssertNil(facts.saleEnabled)
        XCTAssertTrue(facts.showsQuoteOnlyNotice)
        XCTAssertFalse(facts.showsPurchase)
        XCTAssertFalse(facts.showsUnsubscribe)
        XCTAssertTrue(facts.catalogEmpty)
    }

    func testLegacyOrderIsNotAnEmptyShelfAndNotAZeroPrice() throws {
        let snapshot = FreeExploreBundlePageReady.Snapshot(catalog: try catalog(offSaleEmpty), order: try order(#"{"registrationId":41}"#))
        let facts = try XCTUnwrap(ready(FreeExploreBundlePageReady.screen(state: .idle, failed: false, linkMissing: false, kept: snapshot)))
        XCTAssertTrue(facts.legacyOrder)
        XCTAssertTrue(facts.catalogEmpty)
        XCTAssertEqual(facts.saleEnabled, false)
        XCTAssertEqual(facts.priceText, "—")
        XCTAssertEqual(facts.paidAmountText, "—")
        XCTAssertFalse(facts.showsPurchase)
    }

    func testRefreshKeepsThePreviousAmount() throws {
        let kept = FreeExploreBundlePageReady.Snapshot(catalog: try catalog(onSale), priceText: "19.50", paidAmountText: "19.50")
        let failed = try XCTUnwrap(ready(FreeExploreBundlePageReady.screen(state: .idle, failed: true, linkMissing: false, kept: kept)))
        XCTAssertEqual(failed.priceText, "19.50")
        XCTAssertEqual(failed.paidAmountText, "19.50")
        XCTAssertTrue(failed.refreshFailed)
        XCTAssertFalse(failed.refreshing)
        let loading = try XCTUnwrap(ready(FreeExploreBundlePageReady.screen(state: .loading, failed: true, linkMissing: false, kept: kept)))
        XCTAssertEqual(loading.priceText, "19.50")
        XCTAssertTrue(loading.refreshing)
        XCTAssertFalse(loading.refreshFailed)
        let stale = FreeExploreBundlePageReady.screen(state: .staleSession, failed: false, linkMissing: false, kept: kept)
        XCTAssertEqual(stale, .error(.stale))
    }

    func testSaleFlagDoesNotOpenPurchaseAndPlayerFirstStaysClosed() throws {
        let closed = #"{"topicId":88,"productType":2,"saleEnabled":false,"reservationEnabled":true,"items":[{"chapterId":3,"unitsPerHolder":1,"stores":[{"offerId":29}]}]}"#
        let facts = try XCTUnwrap(ready(FreeExploreBundlePageReady.screen(
            state: .idle, failed: false, linkMissing: false,
            kept: .init(catalog: try catalog(closed), priceText: "35.30"))))
        XCTAssertEqual(facts.saleEnabled, false)
        XCTAssertEqual(facts.priceText, "35.30")
        XCTAssertFalse(facts.showsPurchase)
        XCTAssertFalse(facts.showsUnsubscribe)
        XCTAssertFalse(FreeExploreBundlePageReady.includedInPlayerFirstEntry)
        let china = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        XCTAssertFalse(FreeExploreBundlePageReady.showsPage(baseURL: nil, playerFirstEntry: false))
        XCTAssertFalse(FreeExploreBundlePageReady.showsPage(baseURL: china, playerFirstEntry: true))
        XCTAssertTrue(FreeExploreBundlePageReady.showsPage(baseURL: china, playerFirstEntry: false))
        XCTAssertFalse(FreeExploreBundlePageReady.showsPurchase(baseURL: china, playerFirstEntry: false, saleEnabled: true))
        XCTAssertFalse(FreeExploreBundlePageReady.showsPurchase(baseURL: china, playerFirstEntry: false, saleEnabled: false))
        XCTAssertFalse(FreeExploreBundlePageReady.showsUnsubscribe(baseURL: china, playerFirstEntry: false))
        XCTAssertFalse(FreeExploreBundlePageReady.showsUnsubscribe(baseURL: china, playerFirstEntry: true))
        XCTAssertNil(ChinaReviewedRouteCapability.mark(for: FreeExploreBundlePageReady.catalogRoute))
        XCTAssertNil(ChinaReviewedRouteCapability.mark(for: FreeExploreBundlePageReady.orderRoute))
        XCTAssertNil(ChinaReviewedRouteCapability.mark(for: FreeExploreBundlePageReady.refundQuoteRoute))
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/free-explore/bundle/transfer"), .liveInProduction)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/free-explore/bundle/voucher/appeal"), .liveInProduction)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
    }

    func testWelcomeHomeAndAccountStayOffThisPage() throws {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let welcome = try String(contentsOf: url.appendingPathComponent("App/WelcomeView.swift"), encoding: .utf8)
        let home = try String(contentsOf: url.appendingPathComponent("App/HomeFeedView.swift"), encoding: .utf8)
        let account = try String(contentsOf: url.appendingPathComponent("App/AccountView.swift"), encoding: .utf8)
        let orders = try String(contentsOf: url.appendingPathComponent("App/ProfileOrdersView.swift"), encoding: .utf8)
        XCTAssertTrue(welcome.contains("static let showsMerchantChoice = false"))
        XCTAssertFalse(welcome.contains("showsMerchantChoice = true"))
        XCTAssertFalse(welcome.contains("FreeExploreBundle"))
        XCTAssertFalse(home.contains("FreeExploreBundle"))
        XCTAssertFalse(account.contains("FreeExploreBundle"))
        XCTAssertTrue(orders.contains("FreeExploreBundleReadEntry"))
    }
}
