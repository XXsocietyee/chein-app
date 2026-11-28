import Foundation

/// Owner correction 11-28 04:45 / sweep 04:50 (mp-activity P1): the registration sheet's "Pay with" row.
/// CN offers WeChat Pay (default) and Alipay; US offers Apple Pay (default when the device can pay) and
/// Card (Stripe). The choice is presentation only until the pay step: the order-status poll stays the truth.
public enum RegistrationPayMethod: String, CaseIterable, Hashable, Sendable {
    case wechatPay
    case alipay
    case applePay
    case card

    /// Owner check 11-28 05:35: Alipay is selectable only once backend `alipay.trade.app.pay` and the SDK bridge
    /// (`AlipaySDKPaymentAdapter`) are wired. Until then Release hides it and DEBUG shows it disabled (Coming soon).
    public static let alipayReady = false

    /// Channels offered in a market, default first. Apple Pay only when the device can pay with it;
    /// Alipay only when `alipayReady`.
    public static func options(market: RegionalMarket?, applePayAvailable: Bool,
                               alipayReady: Bool = RegistrationPayMethod.alipayReady) -> [RegistrationPayMethod] {
        switch market ?? .china {
        case .unitedStates: return applePayAvailable ? [.applePay, .card] : [.card]
        default: return alipayReady ? [.wechatPay, .alipay] : [.wechatPay]
        }
    }

    /// DEBUG only: the China market lists Alipay as a disabled "Coming soon" row while it is not ready.
    public static func showsAlipayComingSoon(market: RegionalMarket?, alipayReady: Bool = RegistrationPayMethod.alipayReady) -> Bool {
        (market ?? .china) != .unitedStates && !alipayReady
    }

    public static func defaultMethod(market: RegionalMarket?, applePayAvailable: Bool) -> RegistrationPayMethod {
        options(market: market, applePayAvailable: applePayAvailable)[0]
    }

    /// The official channel names (no logos). zh first, en second.
    public var names: (zh: String, en: String) {
        switch self {
        case .wechatPay: return ("微信支付", "WeChat Pay")
        case .alipay: return ("支付宝", "Alipay")
        case .applePay: return ("Apple Pay", "Apple Pay")
        case .card: return ("银行卡", "Card")
        }
    }

}
