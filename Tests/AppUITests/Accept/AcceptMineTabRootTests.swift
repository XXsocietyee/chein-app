import XCTest

/// Mine tab root. Design fixture `d2-me`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptMineTabRootTests: XCTestCase {
    func testMineTabRoot() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d2-me", markers: ["account.mine.tabs"], en: "Me", zh: "我的")
    }
}
