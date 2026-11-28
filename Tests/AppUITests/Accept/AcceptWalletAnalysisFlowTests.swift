import XCTest

/// Income analysis. Design fixture `e4-wallet-analysis`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptWalletAnalysisFlowTests: XCTestCase {
    func testWalletAnalysisFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e4-wallet-analysis", markers: ["wallet.analysis", "wallet.analysis.loading"], en: "Analysis", zh: "分析")
    }
}
