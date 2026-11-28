import Foundation

/// What the registration pay step shows after `POST /api/registration/pay/app` returned WeChat APP params
/// (MP baoming → `wx.requestPayment`; in the app the WeChat SDK). A provider return never means paid on its own:
/// only the one `api/registration/info` read after it (`paymentStatus == 2`) does.
public enum RegistrationAppPayStage: Equatable, Sendable {
    /// WeChat is opening (or the player has not come back yet).
    case launching
    /// `paymentStatus == 2` on the readback: the ticket is in the wallet.
    case paid
    /// The player cancelled in WeChat, or WeChat refused the order. "Pay again" re-opens WeChat with the same params.
    case cancelled
    /// The provider answered but the readback is not paid yet (or failed): "Checking payment…" with Refresh.
    case checking
    /// No WeChat SDK provider (not installed, not configured, or money writes closed).
    case weChatUnavailable
}

public enum RegistrationAppPayResolver {
    /// Matches the sheet's `snapshot.paymentStatus != 2` pay gate.
    public static let paidStatus = 2

    /// The registration was paid, whatever the provider said.
    public static func isPaid(_ paymentStatus: Int?) -> Bool { paymentStatus == paidStatus }

    /// One readback after the provider returns decides the stage; there is no polling loop.
    public static func stage(providerReturn: TopicSelfPlayProviderReturn, paymentStatus: Int?) -> RegistrationAppPayStage {
        if isPaid(paymentStatus) { return .paid }
        switch providerReturn {
        case .cancelled, .failed: return .cancelled
        case .returned, .unknown: return .checking
        }
    }

    /// A manual Refresh read: paid wins, otherwise the player keeps the "Checking payment…" row.
    public static func refreshed(paymentStatus: Int?) -> RegistrationAppPayStage {
        isPaid(paymentStatus) ? .paid : .checking
    }

    /// Every in-app pay goes through the APP route (WeChat open-platform prepay), never the MP JSAPI one.
    public static let inAppChannel: RegistrationPayChannel = .app
}
