import XCTest
@testable import QuestifyCore

final class NearbyTeamReportedCountsTests: XCTestCase {
    private func row(_ fields: String = "") throws -> NearbyTeam {
        try JSONDecoder().decode(NearbyTeam.self, from: Data(("{\"teamId\":503" + fields + "}").utf8))
    }

    func testAbsentNullMalformedAndNegativeAreNotDisplayedAsZero() throws {
        for fields in ["", ",\"joinedCount\":null,\"maxMembers\":null,\"pendingCount\":null",
                       ",\"joinedCount\":\"unknown\",\"maxMembers\":true,\"pendingCount\":[]",
                       ",\"joinedCount\":-1,\"maxMembers\":-4,\"pendingCount\":-2"] {
            let team = try row(fields)
            XCTAssertNil(team.reportedJoinedCount)
            XCTAssertNil(team.reportedMaxMembers)
            XCTAssertNil(team.reportedPendingCount)
            XCTAssertEqual(team.joinedCount, 0)
            XCTAssertEqual(team.maxMembers, 0)
            XCTAssertEqual(team.pendingCount, 0)
            XCTAssertEqual(team.mode, "unknown")
        }
    }

    func testExplicitZeroAndExistingNumericStringsRemainSourceValues() throws {
        let team = try row(",\"joinedCount\":0,\"maxMembers\":\"4\",\"pendingCount\":\"0\"")
        XCTAssertEqual(team.reportedJoinedCount, 0)
        XCTAssertEqual(team.reportedMaxMembers, 4)
        XCTAssertEqual(team.reportedPendingCount, 0)
    }

    func testPartialCountsDoNotInventMissingCapacityOrMembership() throws {
        let team = try row(",\"joinedCount\":2")
        XCTAssertEqual(team.reportedJoinedCount, 2)
        XCTAssertNil(team.reportedMaxMembers)
        XCTAssertNil(team.reportedPendingCount)
        XCTAssertEqual(team.viewerStatus, .unknown)
        XCTAssertFalse(team.viewerHasTicket)
    }

    func testNoClientReconciliationOfOverCapacitySourceValues() throws {
        let team = try row(",\"joinedCount\":5,\"maxMembers\":4,\"pendingCount\":3")
        XCTAssertEqual(team.reportedJoinedCount, 5)
        XCTAssertEqual(team.reportedMaxMembers, 4)
        XCTAssertEqual(team.reportedPendingCount, 3)
    }
}
