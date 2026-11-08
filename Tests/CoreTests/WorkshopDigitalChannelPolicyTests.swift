import Foundation
import XCTest
@testable import QuestifyCore

/// FP-H5 (App Store 3.1.1): a digital-product approval on iOS can only name APPLE_STOREKIT. WeChat Pay,
/// wallet balance, other platforms and non-digital product types cannot even construct an approval.
final class WorkshopDigitalChannelPolicyTests: XCTestCase {
    private func context() throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: "https://example.com/cn/")!, role: "player",
              session: try .init(accountID: 7, epoch: 1, namespace: "synthetic", token: "synthetic-only"))
    }
    private func approval(platform: String = "IOS", productType: String = "DIGITAL_MOD", channel: String = "APPLE_STOREKIT") throws -> WorkshopCommerceApproval {
        try WorkshopCommerceApproval(context: context(), expiresAt: Date().addingTimeInterval(60), readApprovalReference: "synthetic-ref",
                                     platform: platform, market: "CN", productType: productType, channel: channel)
    }
    func testOnlyAppleStoreKitDigitalApprovalOnIOSConstructs() throws {
        let value = try approval()
        XCTAssertEqual(value.channel, "APPLE_STOREKIT"); XCTAssertEqual(value.productType, "DIGITAL_MOD"); XCTAssertEqual(value.platform, "IOS")
    }
    func testNonStoreKitChannelsAreRejected() throws {
        for channel in ["WECHAT_PAY", "WECHAT", "WALLET", "WALLET_BALANCE", "ALIPAY", "POINTS", "", "apple_storekit"] {
            XCTAssertThrowsError(try approval(channel: channel), "channel \(channel)") { XCTAssertEqual($0 as? WorkshopCommerceIssue, .invalid) }
        }
    }
    func testOtherPlatformsAndProductTypesAreRejected() throws {
        for platform in ["ANDROID", "WEB", "MINI_PROGRAM", ""] { XCTAssertThrowsError(try approval(platform: platform), platform) }
        for productType in ["PHYSICAL_GOODS", "ACTIVITY_TICKET", "VIRTUAL_CURRENCY", "DIGITAL_MOD_BUNDLE", ""] { XCTAssertThrowsError(try approval(productType: productType), productType) }
    }
}
