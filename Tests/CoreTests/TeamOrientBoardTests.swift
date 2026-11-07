import XCTest
@testable import QuestifyCore

@MainActor final class TeamOrientBoardTests: XCTestCase {
    func testDecodeDetailBuildsTasksMembersAndSummary() throws {
        let raw: [String: Any] = [
            "tasks": [
                ["id": 10, "name": "外滩钟楼"],
                ["id": 20, "title": "和平饭店"],
                ["id": 30, "name": "外白渡桥"]
            ],
            "members": [
                ["memberId": 101, "nickname": "阿明", "completedTaskIds": [10, 20]],
                ["memberId": 102, "memberName": "小林", "completedTaskIds": [20]]
            ],
            "completedCount": 2
        ]
        let detail = try XCTUnwrap(TeamOrientBoardRules.decodeDetail(raw))
        XCTAssertEqual(detail.tasks.map(\.id), [10, 20, 30])
        XCTAssertEqual(detail.tasks.map(\.title), ["外滩钟楼", "和平饭店", "外白渡桥"])
        XCTAssertEqual(detail.members.count, 2)
        XCTAssertTrue(detail.members[0].hasCompleted(taskID: 10))
        XCTAssertTrue(detail.members[0].hasCompleted(taskID: 20))
        XCTAssertFalse(detail.members[0].hasCompleted(taskID: 30))
        XCTAssertEqual(detail.completedCount, 2)
        XCTAssertEqual(detail.summaryText, "全队已完成 2 / 3 个节点")
    }

    func testDecodeRankingAndMyTeamFlag() {
        let raw: [[String: Any]] = [
            ["rank": 1, "teamId": 88, "teamName": "先锋小队", "completedCount": 5, "totalTasks": 5, "durationSeconds": 125],
            ["rank": 2, "teamId": 99, "title": "慢游小队", "completedCount": 3, "totalTasks": 5, "durationText": "18m 00s"]
        ]
        let rows = TeamOrientBoardRules.decodeRanking(raw)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].rank, 1)
        XCTAssertEqual(rows[0].teamName, "先锋小队")
        XCTAssertEqual(rows[0].durationText, "2m 5s")
        XCTAssertTrue(rows[0].isMyTeam(currentTeamID: 88))
        XCTAssertFalse(rows[1].isMyTeam(currentTeamID: 88))
        XCTAssertEqual(rows[1].durationText, "18m 00s")
    }
}
