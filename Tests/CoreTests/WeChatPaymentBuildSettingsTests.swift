import Foundation
import XCTest
@testable import QuestifyCore

/// fix/1128-cn-pay P0-2: the APP-pay identity is read from Info.plist build settings only.
final class WeChatPaymentBuildSettingsTests: XCTestCase {
    private func info(appID: String = "wxSynthetic01", link: String = "https://www.chengyinhub.com/app/",
                      merchant: String = "1900000109") -> [String: Any] {
        [WeChatPaymentBuildSettings.appIDKey: appID,
         WeChatPaymentBuildSettings.universalLinkKey: link,
         WeChatPaymentBuildSettings.merchantIDKey: merchant]
    }

    func testOwnerValuesBuildTheSDKConfigurationAndCallbacks() throws {
        let value = try XCTUnwrap(WeChatPaymentBuildSettings.configuration(info: info()))
        XCTAssertEqual(value.sdk.appID, "wxSynthetic01")
        XCTAssertEqual(value.sdk.universalLink.absoluteString, "https://www.chengyinhub.com/app/")
        XCTAssertEqual(value.merchantIDs, ["1900000109"])
        XCTAssertTrue(value.sdk.acceptsURL(URL(string: "wxsynthetic01://pay/?returnKey=&ret=0")!))
        XCTAssertTrue(value.sdk.acceptsUniversalLink(URL(string: "https://www.chengyinhub.com/app/wxSynthetic01/pay/?ret=0")!))
        XCTAssertFalse(value.sdk.acceptsUniversalLink(URL(string: "https://www.chengyinhub.com/pages/index/index")!))
    }

    func testPlaceholdersAndMalformedValuesKeepPaymentOff() {
        XCTAssertNil(WeChatPaymentBuildSettings.configuration(info: nil))
        XCTAssertNil(WeChatPaymentBuildSettings.configuration(info: info(appID: "")))
        XCTAssertNil(WeChatPaymentBuildSettings.configuration(info: info(appID: "$(QUESTIFY_WECHAT_APP_ID)")))
        XCTAssertNil(WeChatPaymentBuildSettings.configuration(info: info(appID: "notwx")))
        XCTAssertNil(WeChatPaymentBuildSettings.configuration(info: info(link: "http://www.chengyinhub.com/app/")))
        XCTAssertNil(WeChatPaymentBuildSettings.configuration(info: info(merchant: "")))
        XCTAssertNil(WeChatPaymentBuildSettings.configuration(info: info(merchant: "mch-abc")))
    }

    func testPayParamsFromTheBackendMapToTheSDKRequest() throws {
        let configuration = try XCTUnwrap(WeChatPaymentBuildSettings.configuration(info: info()))
        // Backend WechatPaymentSdkGateway APP prepay: appId, partnerId, prepayId, packageValue, nonceStr, timeStamp, sign.
        let params = ["appId": "wxSynthetic01", "partnerId": "1900000109", "prepayId": "wx-synthetic-prepay",
                      "packageValue": "Sign=WXPay", "nonceStr": "synthetic", "timeStamp": "1764300000", "sign": "synthetic-sign"]
        let request = try WeChatSDKPaymentRequest(parameters: params, configuration: configuration)
        XCTAssertEqual(request.partnerID, "1900000109")
        XCTAssertEqual(request.prepayID, "wx-synthetic-prepay")
        XCTAssertEqual(request.timestamp, 1_764_300_000)
    }
}
