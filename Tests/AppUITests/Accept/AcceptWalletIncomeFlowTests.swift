import XCTest

/// Income details. Design fixture `e4-wallet-income`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptWalletIncomeFlowTests: XCTestCase {
    func testWalletIncomeFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e4-wallet-income", markers: ["wallet.income.filter"], en: "Income details", zh: "收益明细")
    }
}
