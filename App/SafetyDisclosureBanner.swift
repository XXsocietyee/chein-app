import SwiftUI

/// WP-07: mounts the existing AI-identity and offline-node disclosures inside a real screen.
/// Presentation only; it performs no request and decides nothing. A nil policy renders nothing.
struct SafetyDisclosureBanner: View {
    let policy: SafetyDisclosurePolicy?
    var showsNodeSafety = false

    /// Keys this banner renders for a policy; empty for nil. Kept separate so it is unit-testable.
    static func contentKeys(for policy: SafetyDisclosurePolicy?) -> [String] {
        guard let policy else { return [] }
        return [policy.aiIdentity.titleKey] + policy.aiIdentity.boundaryKeys
    }

    var body: some View {
        if let policy {
            VStack(alignment: .leading, spacing: 8) {
                AIIdentityDisclosureView(disclosure: policy.aiIdentity)
                if showsNodeSafety { OfflineNodeSafetyView(state: policy.effectiveNodeSafety) }
                if let clause = policy.noAutoFundsClauseKey {
                    Text(LocalizedStringKey(clause), tableName: "OpsSafety").cyText(.bodyCompact).foregroundStyle(.secondary)
                        .accessibilityIdentifier("opsSafety.pay.noAutoFunds")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("opsSafety.banner")
        }
    }
}
