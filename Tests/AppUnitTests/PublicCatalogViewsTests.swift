import XCTest
@testable import Questify

@MainActor
final class PublicCatalogViewsTests: XCTestCase {
    func testViewAndWiringKeepMoneyOff() {
        XCTAssertFalse(PublicCatalogViews.moneyEnabled)
        XCTAssertFalse(PublicCatalogHostWiring.moneyEnabled)
        XCTAssertFalse(PublicCatalogHost.moneyEnabled)
        XCTAssertNil(PublicCatalogHostWiring.host)
    }

    func testUnknownPriceRowIsAnEmDash() {
        let card = PWaveCatalogCard(id: "9", canonicalPath: nil, cityCode: nil, cityName: nil, name: "江岸",
                                    subtitle: nil, summary: "夜", imageURL: nil, productType: nil, chapterNames: nil,
                                    priceFrom: .value(0), priceState: "UNKNOWN", priceUnit: "起", saleState: nil,
                                    freeSelfPlay: nil, groupEligible: nil, schoolEligible: nil, requestedLocale: nil,
                                    actualLocale: nil, translationState: nil, revisionState: nil)
        let fact = PWaveThemeCollectionFact(cards: [card], cities: [])
        let presented = PWavePresentation(clientCapabilityPresent: true, serverFactPresent: true, phase: .ready(fact))
        guard case .ready(let rows) = PublicCatalogScreen.state(presented) else { return XCTFail("expected a row") }
        XCTAssertEqual(rows[0].price, PWaveNumberFact.unknownDisplay)
        XCTAssertEqual(rows[0].price, "—")
        XCTAssertNotEqual(rows[0].price, "0")
        XCTAssertNil(rows[0].unit)
        XCTAssertEqual(rows[0].summary, "夜")
    }
}
