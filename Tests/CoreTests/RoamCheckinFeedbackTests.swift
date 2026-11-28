import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// mp-roam r3 P2-7: every MP `onPoiTap` branch maps to exactly one toast (or the place page).
final class RoamCheckinFeedbackTests: XCTestCase {
    func testDispositionsFollowMPOnPoiTapToasts() {
        XCTAssertEqual(RoamCheckinFeedback(disposition: .tooFar, placeName: "A"), .tooFar)
        XCTAssertEqual(RoamCheckinFeedback(disposition: .needsScan(poiID: 9), placeName: "A"), .openPlace(poiID: 9))
        XCTAssertNil(RoamCheckinFeedback.openPlace(poiID: 9).messageKey)
        XCTAssertEqual(RoamCheckinFeedback(disposition: .lit(firstVisit: true, awardedXP: 5), placeName: "外滩"),
                       .litFirstVisit(xp: 5, name: "外滩"))
        XCTAssertEqual(RoamCheckinFeedback(disposition: .lit(firstVisit: false, awardedXP: 0), placeName: "A"), .alreadyLit)
        XCTAssertEqual(RoamCheckinFeedback(disposition: .nothingToRecord, placeName: "A"), .nothingToRecord)
        XCTAssertEqual(RoamCheckinFeedback.litFirstVisit(xp: 5, name: "A").messageKey, "roam.checkin.litFirstVisit %lld %@")
    }

    func testFailuresFollowMPOnPoiTapToasts() {
        XCTAssertEqual(RoamCheckinFeedback(error: APIError.unauthorized), .signIn)
        XCTAssertEqual(RoamCheckinFeedback(error: APIError.httpStatus(403)), .signIn)
        XCTAssertEqual(RoamCheckinFeedback(error: APIError.httpStatus(500)), .serviceUnavailable)
        XCTAssertEqual(RoamCheckinFeedback(error: APIError.businessCode(500)), .serviceUnavailable)
        XCTAssertEqual(RoamCheckinFeedback(error: URLError(.notConnectedToInternet)), .network)
        XCTAssertEqual(RoamCheckinFeedback.needsLiveFix.messageKey, "roam.checkin.needsLiveFix")
    }
}
