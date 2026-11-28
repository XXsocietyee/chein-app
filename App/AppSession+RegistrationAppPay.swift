import Foundation

/// Owner check 11-28 05:35 (mp-activity P0): registration `pay/app` hands its WeChat APP params to the session's
/// WeChat SDK provider (`registrationPaymentProvider`, the one self-play checkout and order lifecycle use).
extension AppSession {
    /// Money payments open for this API host (same switch as `RegistrationPayBridge.paymentsOpen`).
    var registrationAppPayAllowed: Bool {
        ReviewedAreaSwitch.moneyPayments(apiHost: regionalConfiguration?.apiConfiguration?.baseURL.host)
    }

    /// One `api/registration/info` read after WeChat returns (no polling); nil when signed out or the read fails.
    func readRegistrationPaymentStatus(registrationID: Int) async -> Int? {
        guard registrationID > 0, let token, AuthRequestBuilder.isValidToken(token) else { return nil }
        let snapshot = try? await registrationStatusBackend.readStatus(registrationID: registrationID, token: token)
        return snapshot?.paymentStatus
    }
}
