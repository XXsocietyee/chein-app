import XCTest

/// Wallet earnings. Design fixture `wallet`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptWalletEarningsFlowTests: XCTestCase {
    func testWalletEarningsFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "wallet", markers: ["wallet.earnings.overview", "wallet.earnings.loading"], en: "Account earnings", zh: "账户收益")
    }
}
