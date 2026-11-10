import XCTest
@testable import QuestifyCore

/// Page states for `pages/topic/pricing/index`. Existing pricing tests stay as they are.
final class TopicPricingPageReadyTests: XCTestCase {
    private func payload(_ object: [String: ProjectEditJSON]) -> TopicPricingXcx.Read {
        .payload(.object(object))
    }

    private func ready(_ state: TopicPricingXcx.Screen) -> TopicPricingXcx.Screen.Ready? {
        if case .ready(let value) = state { return value }
        return nil
    }

    func testUnknownMoneyIsADashAndLiteralZeroStaysZero() {
        XCTAssertEqual(TopicPricingXcx.moneyText(nil as String?), TopicPricingXcx.unknownMoney)
        XCTAssertEqual(TopicPricingXcx.moneyText(""), TopicPricingXcx.unknownMoney)
        XCTAssertEqual(TopicPricingXcx.moneyText("   "), TopicPricingXcx.unknownMoney)
        XCTAssertEqual(TopicPricingXcx.moneyText("nope"), TopicPricingXcx.unknownMoney)
        XCTAssertEqual(TopicPricingXcx.moneyText(decimal: nil), TopicPricingXcx.unknownMoney)
        XCTAssertEqual(TopicPricingXcx.moneyText("0"), "0.00")
        XCTAssertEqual(TopicPricingXcx.moneyText("0.0"), "0.00")
        XCTAssertEqual(TopicPricingXcx.moneyText(decimal: 0), "0.00")
        XCTAssertEqual(TopicPricingXcx.moneyText(decimal: Decimal(string: "35.3")), "35.30")
        XCTAssertEqual(TopicPricingXcx.moneyText(decimal: Decimal(string: "-1.2")), "-1.20")
        XCTAssertNotEqual(TopicPricingXcx.moneyText(nil as String?), "0")
        XCTAssertNotEqual(TopicPricingXcx.moneyText(decimal: nil), "0.00")
    }

    func testMissingTopicIsEmptyAndDoesNotInventAZeroFloor() {
        let state = TopicPricingXcx.screen(read: .missingTopic, kept: nil, subtype: .selfPlay, teamSize: nil, price: nil)
        guard case .empty = state else { return XCTFail("expected empty, got \(state)") }
    }

    func testLoadingEmptyErrorAndUnknownStayDistinct() throws {
        XCTAssertEqual(TopicPricingXcx.screen(read: .loading, kept: nil, subtype: .selfPlay, teamSize: nil, price: nil), .loading)
        XCTAssertEqual(TopicPricingXcx.screen(read: .failed, kept: nil, subtype: .selfPlay, teamSize: nil, price: nil), .error(.load))
        XCTAssertEqual(TopicPricingXcx.screen(read: .idle, kept: nil, subtype: .guided, teamSize: nil, price: nil), .unknown)
        let incomplete = TopicPricingXcx.screen(read: payload([:]), kept: nil, subtype: .selfPlay, teamSize: nil, price: nil)
        XCTAssertEqual(incomplete, .error(.incomplete))
        let stringZero = TopicPricingXcx.screen(read: payload(["priceMin": .string("0")]), kept: nil, subtype: .selfPlay, teamSize: nil, price: nil)
        XCTAssertEqual(stringZero, .error(.incomplete))
    }

    func testLiteralZeroFloorStaysZeroAndUnknownConfirmIsNotBlocked() throws {
        let state = TopicPricingXcx.screen(
            read: payload(["priceMin": .number(0), "lineup": .array([])]),
            kept: nil, subtype: .selfPlay, teamSize: nil, price: nil)
        let facts = try XCTUnwrap(ready(state))
        XCTAssertEqual(facts.floorText, "0.00")
        XCTAssertEqual(facts.finalPriceText, "0.00")
        XCTAssertEqual(facts.confirm, .unknown)
        XCTAssertTrue(facts.canSubmit)
        XCTAssertTrue(facts.lineupEmpty)
        XCTAssertEqual(facts.reference, .insufficient)
        XCTAssertFalse(facts.refreshing)
        XCTAssertFalse(facts.refreshFailed)
    }

    func testGuidedZeroTeamCannotSubmitEvenWhenFloorIsZero() throws {
        let body: [String: ProjectEditJSON] = ["priceMin": .number(0), "canConfirm": .bool(true)]
        let missing = TopicPricingXcx.screen(read: payload(body), kept: nil, subtype: .guided, teamSize: nil, price: nil)
        XCTAssertFalse(try XCTUnwrap(ready(missing)).canSubmit)
        let zero = TopicPricingXcx.screen(read: payload(body), kept: nil, subtype: .guided, teamSize: 0, price: 0)
        let facts = try XCTUnwrap(ready(zero))
        XCTAssertFalse(facts.canSubmit)
        XCTAssertEqual(facts.floorText, "0.00")
        XCTAssertEqual(facts.confirm, .allowed)
        let group = TopicPricingXcx.screen(read: payload(["priceMin": .number(Decimal(string: "35.30")!), "canConfirm": .bool(true)]),
                                            kept: nil, subtype: .guided, teamSize: 4, price: nil)
        let priced = try XCTUnwrap(ready(group))
        XCTAssertEqual(priced.floorText, "35.30")
        XCTAssertEqual(priced.finalPriceText, "36.00")
        XCTAssertTrue(priced.canSubmit)
    }

    func testBlockedConfirmAndLiteralZeroReference() throws {
        let blocked = TopicPricingXcx.screen(
            read: payload(["priceMin": .number(20), "canConfirm": .bool(false)]),
            kept: nil, subtype: .selfPlay, teamSize: nil, price: 20)
        XCTAssertEqual(try XCTUnwrap(ready(blocked)).confirm, .blocked)
        XCTAssertFalse(try XCTUnwrap(ready(blocked)).canSubmit)
        let reference = TopicPricingXcx.screen(
            read: payload(["priceMin": .number(20), "canConfirm": .bool(true),
                           "cityReferencePrice": .number(0), "cityReferenceSampleSize": .number(4)]),
            kept: nil, subtype: .selfPlay, teamSize: nil, price: 20)
        XCTAssertEqual(try XCTUnwrap(ready(reference)).reference, .average(money: "0.00", samples: 4))
        let noSamples = TopicPricingXcx.screen(
            read: payload(["priceMin": .number(20), "cityReferencePrice": .number(12)]),
            kept: nil, subtype: .selfPlay, teamSize: nil, price: 20)
        XCTAssertEqual(try XCTUnwrap(ready(noSamples)).reference, .insufficient)
    }

    func testRefreshKeepsThePreviousFloor() throws {
        let kept = try PublisherPricingPreview(.object(["priceMin": .number(12), "canConfirm": .bool(true)]))
        let failed = TopicPricingXcx.screen(read: .failed, kept: kept, subtype: .selfPlay, teamSize: nil, price: 12)
        let facts = try XCTUnwrap(ready(failed))
        XCTAssertEqual(facts.floorText, "12.00")
        XCTAssertTrue(facts.refreshFailed)
        XCTAssertFalse(facts.refreshing)
        let loading = TopicPricingXcx.screen(read: .loading, kept: kept, subtype: .selfPlay, teamSize: nil, price: 12)
        XCTAssertTrue(try XCTUnwrap(ready(loading)).refreshing)
        XCTAssertFalse(try XCTUnwrap(ready(loading)).refreshFailed)
        let broken = TopicPricingXcx.screen(read: payload(["priceMin": .string("nope")]), kept: kept, subtype: .selfPlay, teamSize: nil, price: 12)
        XCTAssertEqual(try XCTUnwrap(ready(broken)).floorText, "12.00")
        XCTAssertTrue(try XCTUnwrap(ready(broken)).refreshFailed)
    }

    func testMissingCapabilityStaysHiddenAndPlayerFirstNeverEnters() throws {
        XCTAssertFalse(TopicPricingXcx.includedInPlayerFirstEntry)
        let china = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        XCTAssertFalse(TopicPricingXcx.showsPage(baseURL: nil, playerFirstEntry: false))
        XCTAssertFalse(TopicPricingXcx.showsPage(baseURL: china, playerFirstEntry: true))
        XCTAssertTrue(TopicPricingXcx.showsPage(baseURL: china, playerFirstEntry: false))
        XCTAssertFalse(TopicPricingXcx.showsEntry(owner: true, lifecycle: 2, baseURL: nil, playerFirstEntry: false))
        XCTAssertFalse(TopicPricingXcx.showsEntry(owner: false, lifecycle: 2, baseURL: china, playerFirstEntry: false))
        XCTAssertFalse(TopicPricingXcx.showsEntry(owner: true, lifecycle: nil, baseURL: china, playerFirstEntry: false))
        XCTAssertFalse(TopicPricingXcx.showsEntry(owner: true, lifecycle: 0, baseURL: china, playerFirstEntry: false))
        XCTAssertFalse(TopicPricingXcx.showsEntry(owner: true, lifecycle: 2, baseURL: china, playerFirstEntry: true))
        XCTAssertTrue(TopicPricingXcx.showsEntry(owner: true, lifecycle: 2, baseURL: china, playerFirstEntry: false))
        XCTAssertFalse(TopicPricingXcx.showsConfirm(baseURL: china, playerFirstEntry: false, pricingGrantPresent: false))
        XCTAssertTrue(TopicPricingXcx.showsConfirm(baseURL: china, playerFirstEntry: false, pricingGrantPresent: true))
        XCTAssertFalse(TopicPricingXcx.showsConfirm(baseURL: china, playerFirstEntry: true, pricingGrantPresent: true))
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: TopicPricingXcx.previewRoute), .liveInProduction)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: TopicPricingXcx.confirmRoute), .liveInProduction)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
    }

    func testWelcomeStaysPlayerFirst() throws {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let source = try String(contentsOf: url.appendingPathComponent("App/WelcomeView.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("static let showsMerchantChoice = false"))
        XCTAssertFalse(source.contains("showsMerchantChoice = true"))
    }
}
