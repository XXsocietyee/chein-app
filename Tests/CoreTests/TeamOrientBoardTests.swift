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
        XCTAssertEqual(detail.completedCountText, "2")
        XCTAssertEqual(detail.progressText, "2 / 3")
        XCTAssertEqual(TeamOrientBoardRules.phase(loading: false, failed: false, detail: detail), .ready)
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
        XCTAssertEqual(rows[0].rankText, "1")
        XCTAssertEqual(rows[0].progressText, "5 / 5")
        XCTAssertEqual(rows[1].progressText, "3 / 5")
    }

    func testOmittedCountsAreEmDashAndLiteralZeroStaysZero() throws {
        let omittedBoard = TeamOrientBoardRules.decodeDetail([
            "tasks": [["id": 10, "name": "外滩钟楼"]],
            "members": [["memberId": 101, "nickname": "阿明", "completedTaskIds": [10]]]
        ])
        let board = try XCTUnwrap(omittedBoard)
        XCTAssertEqual(board.completedCountText, "—")
        XCTAssertEqual(board.progressText, "—")
        XCTAssertNotEqual(board.progressText, "0 / 1")
        XCTAssertNotEqual(board.progressText, "1 / 1")
        XCTAssertEqual(TeamOrientBoardRules.phase(loading: false, failed: false, detail: board), .unknown)
        XCTAssertEqual(TeamOrientBoardRules.phase(loading: true, failed: false, detail: nil), .loading)
        XCTAssertEqual(TeamOrientBoardRules.phase(loading: false, failed: false, detail: nil), .empty)
        XCTAssertEqual(TeamOrientBoardRules.phase(loading: false, failed: true, detail: nil), .error)
        let empty = TeamOrientBoardDetail(tasks: [], members: [], completedCount: 0)
        XCTAssertEqual(TeamOrientBoardRules.phase(loading: false, failed: false, detail: empty), .empty)
        XCTAssertEqual(empty.summaryText, "当前场次暂无定向任务")

        let rows = TeamOrientBoardRules.decodeRanking([["teamId": 7, "teamName": "Synthetic"]])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].rankText, "—")
        XCTAssertEqual(rows[0].progressText, "—")
        XCTAssertNotEqual(rows[0].progressText, "0 / 0")
        XCTAssertNotEqual(rows[0].rankText, "0")
        XCTAssertNotEqual(rows[0].rankText, "1")
        let zero = TeamOrientBoardRules.decodeRanking([[
            "rank": 0, "teamId": 7, "teamName": "Synthetic", "completedCount": 0, "totalTasks": 5
        ]])
        XCTAssertEqual(zero[0].rankText, "0")
        XCTAssertEqual(zero[0].progressText, "0 / 5")
        let negative = TeamOrientBoardRules.decodeRanking([[
            "rank": -2, "teamId": 7, "teamName": "Synthetic", "completedCount": -1, "totalTasks": 5
        ]])
        XCTAssertEqual(negative[0].rankText, "—")
        XCTAssertEqual(negative[0].progressText, "—")
    }
}
