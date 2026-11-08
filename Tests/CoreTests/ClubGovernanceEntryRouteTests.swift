#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class ClubGovernanceEntryRouteTests: XCTestCase {
    private func route(_ options: [String: String], chinese: Bool = true) throws -> ClubGovernanceEntryRoute {
        try ClubGovernanceEntryRoute.resolve(options, chinese: chinese).get()
    }
    func testMissingOrNonPositiveClubIDFails() {
        for bad in [nil, "", "0", "-3", "abc", "1.5"] {
            var options: [String: String] = ["mode": "appeal"]
            if let bad { options["clubId"] = bad }
            XCTAssertEqual(ClubGovernanceEntryRoute.resolve(options), .failure(.missingClub))
        }
    }
    func testUnknownModeFallsBackToManageAndKeepsFocusMember() throws {
        XCTAssertEqual(try route(["clubId": "7"]).mode, .manage(focusMemberID: nil))
        XCTAssertEqual(try route(["clubId": "7", "mode": "weird", "memberId": "22"]).mode, .manage(focusMemberID: 22))
    }
    func testAppealIgnoresMemberFocus() throws {
        XCTAssertEqual(try route(["clubId": "7", "mode": "appeal", "memberId": "22"]).mode, .appeal)
    }
    func testReportRequiresLegalTargetAndNormalizesCase() throws {
        XCTAssertEqual(ClubGovernanceEntryRoute.resolve(["clubId": "7", "mode": "report"]), .failure(.invalidReportTarget))
        XCTAssertEqual(ClubGovernanceEntryRoute.resolve(["clubId": "7", "mode": "report", "targetType": "POST", "targetId": "3"]), .failure(.invalidReportTarget))
        XCTAssertEqual(ClubGovernanceEntryRoute.resolve(["clubId": "7", "mode": "report", "targetType": "activity"]), .failure(.invalidReportTarget))
        let ok = try route(["clubId": "7", "mode": "report", "targetType": "activity", "targetId": "501", "targetName": "  夜跑 \n 09-24 "])
        XCTAssertEqual(ok.mode, .report(type: .activity, targetID: 501, label: "活动「夜跑 09-24」"))
    }
    func testLegacyMemberTargetAndClubDefaultTarget() throws {
        XCTAssertEqual(try route(["clubId": "7", "mode": "report", "targetMemberId": "9"]).mode, .report(type: .member, targetID: 9, label: "成员"))
        XCTAssertEqual(try route(["clubId": "7", "mode": "report", "targetType": "CLUB"]).mode, .report(type: .club, targetID: 7, label: "俱乐部"))
    }
    func testEnglishLabelAndNameTruncation() throws {
        let long = String(repeating: "n", count: 60)
        let mode = try route(["clubId": "7", "mode": "report", "targetType": "MEMBER", "targetId": "2", "targetName": long], chinese: false).mode
        XCTAssertEqual(mode, .report(type: .member, targetID: 2, label: "Member \u{201C}" + String(repeating: "n", count: 40) + "\u{201D}"))
    }
}
#endif
