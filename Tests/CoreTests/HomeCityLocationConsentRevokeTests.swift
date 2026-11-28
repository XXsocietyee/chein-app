import XCTest
@testable import QuestifyCore

/// mp-home r3 (continue 32): MP `getHomeCityLocation({userInitiated})` stops on a REVOKE row (pages/index/index.js:1322).
final class HomeCityLocationConsentRevokeTests: XCTestCase {
    private func consent(_ event: String) throws -> ComplianceConsent {
        let json = #"{"docType":"privacy_policy","scene":"home_city_location","eventType":"\#(event)"}"#
        return try JSONDecoder().decode(ComplianceConsent.self, from: Data(json.utf8))
    }

    func testRevokeRowIsRevoked() throws {
        let baseline = HomeCityLocationConsentBaseline(consent: try consent("REVOKE"), requestID: nil)
        XCTAssertTrue(HomeCityLocationConsentRecord.isRevoked(baseline))
        XCTAssertFalse(HomeCityLocationConsentRecord.shouldAsk(baseline))
    }

    func testNoRowOrAgreeIsNotRevoked() throws {
        XCTAssertFalse(HomeCityLocationConsentRecord.isRevoked(HomeCityLocationConsentBaseline(consent: nil, requestID: nil)))
        let agree = HomeCityLocationConsentBaseline(consent: try consent("AGREE"), requestID: "r-1")
        XCTAssertFalse(HomeCityLocationConsentRecord.isRevoked(agree))
    }
}
