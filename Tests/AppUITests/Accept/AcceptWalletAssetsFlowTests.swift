import XCTest

/// Wallet assets. Design fixture `e4-wallet-assets`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptWalletAssetsFlowTests: XCTestCase {
    func testWalletAssetsFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e4-wallet-assets", markers: ["wallet.assets.loading", "wallet.assets.available", "wallet.assets.unknown", "wallet.assets.revolutCard"], en: "Assets", zh: "我的资产")
    }
}
