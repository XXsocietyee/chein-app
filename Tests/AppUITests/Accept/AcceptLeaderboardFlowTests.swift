import XCTest

/// Leaderboard. Design fixture `d4-leaderboard`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptLeaderboardFlowTests: XCTestCase {
    func testLeaderboardFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d4-leaderboard", markers: ["growth.board.period", "growth.board.refresh"], en: "Leaderboard", zh: "完整排行榜")
    }
}
