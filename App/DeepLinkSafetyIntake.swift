import Foundation

extension AppSession {
    /// Audits `url` before any legacy parser. Returns true when this intake owns the URL
    /// (routed, or inert). Returns false only for `chein://`, its `chengyin://` alias, and `wx…`
    /// callbacks that are not payment or password routes, so those existing handlers still run.
    /// Unsafe, unknown, cross-realm, unauthenticated, payment, and password URLs do not navigate.
    func consumeDeepLinkSafetyAudit(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        let closed = DeepLinkAndUniversalLinkSafetyAudit.isPaymentOrPasswordRoute(url)
        if !closed, CheinDeepLink.isPlayerScheme(scheme) || scheme.hasPrefix("wx") {
            return false
        }
        let context = DeepLinkAndUniversalLinkSafetyAudit.SessionContext(
            realmIdentifier: DeepLinkSafetyAudit.realmIdentifier(market: operationalMarket),
            isAuthenticated: (account?.id ?? 0) > 0,
            accountID: account?.id ?? 0
        )
        let report = DeepLinkAndUniversalLinkSafetyAudit.audit(
            url: url,
            session: context,
            verifiedHTTPSHosts: DeepLinkSafetyAudit.verifiedHTTPSHosts
        )
        DeepLinkSafetySnapshot.recordIntake(
            report: report,
            marketCode: operationalMarket?.rawValue.lowercased() ?? "",
            realmIdentifier: context.realmIdentifier,
            allowlistedHTTPSHostsCount: DeepLinkSafetyAudit.verifiedHTTPSHosts.count
        )
        if case .allowReadOnly(let destination) = report.decision,
           !closed,
           let intent = DeepLinkSafetyAudit.navigationIntent(for: destination) {
            receiveNativeIntent(intent)
        }
        return true
    }
}
