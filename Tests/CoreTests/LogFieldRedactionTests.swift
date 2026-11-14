import XCTest
@testable import QuestifyCore

final class LogFieldRedactionTests: XCTestCase {
    func testKeyedSecretsAreReplacedAndTheEventStays() {
        let openID = "o" + String(repeating: "x", count: 27)
        // 19900000000 is a fixture digit run, not a real number. 1 Fixture Road is a fixture street.
        let raw = #"{"token":"fixture-token","phone":"19900000000","openid":"\#(openID)","address":"1 Fixture Road","addressName":"Old Town","code":200}"#
        let logged = LogFieldRedaction.redacted(raw)
        XCTAssertFalse(logged.contains("fixture-token"))
        XCTAssertFalse(logged.contains("19900000000"))
        XCTAssertFalse(logged.contains(openID))
        XCTAssertFalse(logged.contains("1 Fixture Road"))
        XCTAssertTrue(logged.contains(#""token":"[redacted]""#))
        XCTAssertTrue(logged.contains(#""phone":"[redacted]""#))
        XCTAssertTrue(logged.contains(#""addressName":"Old Town""#))
        XCTAssertTrue(logged.contains(#""code":200"#))
    }

    func testBareTokenPhoneAndStreetAreReplaced() {
        XCTAssertEqual(LogFieldRedaction.redacted("fixture-token"), LogFieldRedaction.marker)
        XCTAssertEqual(LogFieldRedaction.redacted("token=fixture-token"), "token=[redacted]")
        XCTAssertEqual(LogFieldRedaction.redacted("19900000000"), LogFieldRedaction.marker)
        XCTAssertEqual(LogFieldRedaction.redacted("street=1 Fixture Road"), "street=[redacted]")
        XCTAssertEqual(LogFieldRedaction.redacted("https://example.test/path?token=fixture-token"),
                       "https://example.test/path?token=[redacted]")
    }

    func testFailureWordStays() {
        XCTAssertEqual(LogFieldRedaction.redacted("notConfigured"), "notConfigured")
        XCTAssertEqual(LogFieldRedaction.redacted("rejected(409, Optional(\"hello\"))"),
                       "rejected(409, Optional(\"hello\"))")
    }
}
