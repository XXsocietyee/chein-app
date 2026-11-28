import Foundation
import UIKit

/// fix-1128-alipay (audit P0-4): hands the backend's signed `orderString` to Alipay.
/// With the AlipaySDK framework linked and `QUESTIFY_ALIPAY_SDK_APPROVED=1` the official SDK runs
/// (`QFAlipayPaymentBridge`). Otherwise the order goes to Alipay through `alipay://alipayclient/?…` and Alipay
/// comes back on the app's own scheme (`<QUESTIFY_ALIPAY_APP_SCHEME>://safepay/?…`). Either way Alipay's answer only
/// ends the wait: the pay step always confirms with `POST /api/pay/alipay/query`.
@MainActor final class AlipayPaymentDriver: AlipaySDKPaymentDriving {
    private let bridge = QFAlipayPaymentBridge()
    private var urlResult: ((String) -> Void)?
    /// True when the last URL hand-off could not open Alipay (not installed). Cleared on every new pay.
    private(set) var lastLaunchFailedToOpen = false

    /// The SDK, or the URL hand-off that needs no SDK binary. The adapter still needs the owner's scheme.
    var isLinked: Bool { true }
    var usesSDK: Bool { bridge.sdkLinked }

    /// `QuestifyAlipayAppScheme` (Info.plist ← `QUESTIFY_ALIPAY_APP_SCHEME` in xcconfig). Empty keeps Alipay off.
    static func configuration(bundle: Bundle = .main) -> AlipaySDKPaymentConfiguration? {
        let raw = bundle.object(forInfoDictionaryKey: "QuestifyAlipayAppScheme") as? String ?? ""
        guard !raw.hasPrefix("$(") else { return nil }
        return try? AlipaySDKPaymentConfiguration(appScheme: raw)
    }

    func pay(orderString: String, fromScheme: String, result: @escaping (String) -> Void) {
        lastLaunchFailedToOpen = false
        if bridge.sdkLinked {
            bridge.pay(orderString: orderString, fromScheme: fromScheme, result: result)
            return
        }
        guard let url = AlipayURLPayment.launchURL(orderString: orderString, fromScheme: fromScheme) else {
            result("4000")
            return
        }
        urlResult = result
        UIApplication.shared.open(url, options: [:], completionHandler: { [weak self] opened in
            Self.launchFinished(self, opened: opened)
        })
    }

    private static func launchFinished(_ driver: AlipayPaymentDriver?, opened: Bool) {
        guard let driver, !opened else { return }
        driver.lastLaunchFailedToOpen = true
        let pending = driver.urlResult
        driver.urlResult = nil
        pending?("4000")
    }

    func handle(_ url: URL, result: @escaping (String) -> Void) -> Bool {
        if bridge.sdkLinked { return bridge.handle(url: url, result: result) }
        guard url.host?.lowercased() == "safepay" else { return false }
        urlResult = nil
        result(AlipayURLPayment.resultStatus(from: url) ?? "6004")
        return true
    }
}
