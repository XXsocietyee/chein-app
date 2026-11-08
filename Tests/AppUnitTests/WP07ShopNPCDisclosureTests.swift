import XCTest
@testable import Questify

@MainActor final class WP07ShopNPCDisclosureTests: XCTestCase {
    func testBannerPresentInProductionShopNPCView() throws {
        // The production default policy is non-nil and renders the AI identity keys.
        let policy = try XCTUnwrap(ShopNPCView.defaultSafetyPolicy)
        XCTAssertEqual(policy.surface, .publicMerchantNPC)
        let keys = SafetyDisclosureBanner.contentKeys(for: policy)
        XCTAssertTrue(keys.contains("opsSafety.ai.title"))
        XCTAssertTrue(keys.contains("opsSafety.ai.notHuman"))
        // The real view's source mounts the banner (guards against it being unmounted).
        let source = try String(contentsOfFile: #filePath.replacingOccurrences(
            of: "Tests/AppUnitTests/WP07ShopNPCDisclosureTests.swift", with: "App/ShopNPCView.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("SafetyDisclosureBanner(policy: safetyPolicy)"))
    }

    func testBannerAbsentDoesNotCrashWhenPolicyNil() {
        XCTAssertEqual(SafetyDisclosureBanner.contentKeys(for: nil), [])
        _ = SafetyDisclosureBanner(policy: nil).body
    }
}
