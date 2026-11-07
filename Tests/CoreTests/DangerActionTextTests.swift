#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// Encodes utils/danger-actions.js postExcerpt / fillTemplate.
final class DangerActionTextTests: XCTestCase {
    typealias D = DangerActionText

    func testExcerptCollapsesWhitespaceAndTrims() {
        XCTAssertEqual(D.postExcerpt("  hello \n\t world  ", imageOnlyText: "IMG"), "hello world")
    }

    func testExcerptOfEmptyNilOrBlankIsTheImageOnlyText() {
        XCTAssertEqual(D.postExcerpt(nil, imageOnlyText: "IMG"), "IMG")
        XCTAssertEqual(D.postExcerpt("", imageOnlyText: "IMG"), "IMG")
        XCTAssertEqual(D.postExcerpt(" \n\u{FEFF}\t ", imageOnlyText: "IMG"), "IMG")
    }

    func testExcerptCutsAtLimitWithEllipsisOnlyWhenLonger() {
        XCTAssertEqual(D.postExcerpt("123456789012", imageOnlyText: "IMG"), "123456789012")
        XCTAssertEqual(D.postExcerpt("1234567890123", imageOnlyText: "IMG"), "123456789012…")
        XCTAssertEqual(D.postExcerpt("abcdef", limit: 3, imageOnlyText: "IMG"), "abc…")
    }

    func testExcerptNonPositiveLimitFallsBackToTwelve() {
        XCTAssertEqual(D.postExcerpt("1234567890123", limit: 0, imageOnlyText: "IMG"), "123456789012…")
        XCTAssertEqual(D.postExcerpt("1234567890123", limit: -4, imageOnlyText: "IMG"), "123456789012…")
    }

    func testExcerptMeasuresChineseInUtf16UnitsAndNeverSplitsASurrogatePair() {
        XCTAssertEqual(D.postExcerpt("今天去了城市里的一个很有意思的地方", imageOnlyText: "IMG"), "今天去了城市里的一个很有…")
        // 11 BMP units + one astral scalar (2 units) = 13 units: the pair does not fit, so it is dropped whole.
        XCTAssertEqual(D.postExcerpt("12345678901😀", imageOnlyText: "IMG"), "12345678901…")
    }

    func testFillTemplateReplacesKnownKeys() {
        XCTAssertEqual(D.fillTemplate("Stop {name}?", params: ["name": "Coupon A"], neutral: "this item"), "Stop Coupon A?")
        XCTAssertEqual(D.fillTemplate("{a}-{b}-{a}", params: ["a": "1", "b": "2"], neutral: "?"), "1-2-1")
    }

    func testFillTemplateUsesNeutralForMissingOrEmptyValuesAndNeverShowsBarePlaceholders() {
        XCTAssertEqual(D.fillTemplate("Stop {name}?", params: nil, neutral: "this item"), "Stop this item?")
        XCTAssertEqual(D.fillTemplate("Stop {name}?", params: ["name": ""], neutral: "this item"), "Stop this item?")
        XCTAssertEqual(D.fillTemplate("Stop {name}?", params: ["other": "x"], neutral: "this item"), "Stop this item?")
    }

    func testFillTemplateKeepsNonPlaceholderBracesAndHandlesEmptyInput() {
        XCTAssertEqual(D.fillTemplate("{ not key } and {}", params: [:], neutral: "?"), "{ not key } and {}")
        XCTAssertEqual(D.fillTemplate("", params: ["a": "b"], neutral: "?"), "")
        XCTAssertEqual(D.fillTemplate(nil, params: nil, neutral: "?"), "")
    }

    func testFillTemplateDoesNotReexpandReplacementText() {
        XCTAssertEqual(D.fillTemplate("{a}", params: ["a": "{b}", "b": "x"], neutral: "?"), "{b}")
    }
}
#endif
