import XCTest
@testable import Questify

/// mp-home r3 (continue 32): MP `utils/category-icon.js` rules, plus English names for the US market.
final class SearchCategorySymbolTests: XCTestCase {
    func testChineseNamesFollowTheMiniProgramRules() {
        XCTAssertEqual(SearchCategorySymbol.name(for: "美食"), "fork.knife")
        XCTAssertEqual(SearchCategorySymbol.name(for: "摄影"), "camera")
        XCTAssertEqual(SearchCategorySymbol.name(for: "夜游"), "star")
        XCTAssertEqual(SearchCategorySymbol.name(for: "人文"), "storefront")
    }

    func testEnglishNamesGetTheSameSymbols() {
        XCTAssertEqual(SearchCategorySymbol.name(for: "Food"), "fork.knife")
        XCTAssertEqual(SearchCategorySymbol.name(for: "Photography"), "camera")
        XCTAssertEqual(SearchCategorySymbol.name(for: "Culture"), "book")
        XCTAssertEqual(SearchCategorySymbol.name(for: "Night walks"), "star")
        XCTAssertEqual(SearchCategorySymbol.name(for: "family"), "person.2")
    }

    func testEnglishMatchesWordStartsOnly() {
        XCTAssertEqual(SearchCategorySymbol.name(for: "Party"), "storefront")
        XCTAssertEqual(SearchCategorySymbol.name(for: "Brunch"), "storefront")
        XCTAssertEqual(SearchCategorySymbol.name(for: ""), "storefront")
    }
}
