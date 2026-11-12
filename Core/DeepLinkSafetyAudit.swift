import Foundation

/// Live deep-link gate named by the C05 review. Classification stays in
/// `DeepLinkAndUniversalLinkSafetyAudit`; this type decides which of those
/// decisions may become navigation. The production host allowlist is empty.
public enum DeepLinkSafetyAudit {
    /// Hosts the real entry will treat as verified. Empty unless a test installs a fixture host.
    public static var verifiedHTTPSHosts: Set<String> = []

    public static func realmIdentifier(market: RegionalMarket?) -> String {
        switch market {
        case .china: return "cn"
        case .unitedStates: return "us"
        case nil: return ""
        }
    }

    public static func classify(
        url: URL,
        session: DeepLinkAndUniversalLinkSafetyAudit.SessionContext,
        verifiedHTTPSHosts: Set<String>
    ) -> DeepLinkAndUniversalLinkSafetyAudit.AuditDecision {
        DeepLinkAndUniversalLinkSafetyAudit.audit(
            url: url,
            session: session,
            verifiedHTTPSHosts: verifiedHTTPSHosts
        ).decision
    }

    /// Screens a link may open. Payment, password, order, and workspace destinations are not among them.
    public static func navigationIntent(
        for destination: DeepLinkAndUniversalLinkSafetyAudit.SafeDestination
    ) -> NativeEntryIntent? {
        switch destination {
        case .publicTopicDetail(let topicID):
            return NativeContentTarget(kind: .topic, id: topicID).map(NativeEntryIntent.content)
        case .teamInvitation(let inviteCode):
            return (try? TeamInvitationRoute(code: inviteCode)).map(NativeEntryIntent.teamInvitation)
        case .publicMerchantHome(let merchantID):
            return PublicMerchantRowID(merchantID).map { .publicMerchant(.legacyMerchantRowID($0)) }
        case .publicMemberProfile, .memberOrders, .orderDetail, .clubWorkspace, .merchantWorkbench:
            return nil
        }
    }
}
