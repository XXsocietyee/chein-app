import Foundation

/// fix-1128-alipay (P32 checkout): which method the CN pay step uses. WeChat Pay stays the default; Alipay is
/// offered only when the backend lists `APP_ALIPAY` and the app can open Alipay (`AlipayAppPayChannel.offered`).
public extension RegistrationPayMethod {
    /// The player's choice when it is offered, else the market default. A China order whose backend lists
    /// `APP_ALIPAY` but not WeChat `APP` defaults to Alipay.
    static func effective(selection: RegistrationPayMethod?, market: RegionalMarket?, applePayAvailable: Bool,
                          alipayOffered: Bool, paymentChannels: [String]?) -> RegistrationPayMethod {
        let offered = options(market: market, applePayAvailable: applePayAvailable, alipayReady: alipayOffered)
        if let selection, offered.contains(selection) { return selection }
        if offered.contains(.alipay), let paymentChannels, !paymentChannels.contains("APP") { return .alipay }
        return offered[0]
    }

    /// The localization key of the pay button for this method ("Pay ¥12.50 with WeChat Pay").
    var payButtonKey: String {
        switch self {
        case .wechatPay: return "registration.payWith.wechatPay %@"
        case .alipay: return "registration.payWith.alipay %@"
        case .applePay: return "registration.payWith.applePay %@"
        case .card: return "registration.payWith.card %@"
        }
    }
}
