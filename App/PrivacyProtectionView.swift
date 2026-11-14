import SwiftUI

/// Mini-program pages/privacy (route title 隐私保护): the gate summary, both document links,
/// and this device's agreement state. Signed-in revoke actions (roam location, marketing)
/// stay in Settings › Privacy and location, which already hosts them.
struct PrivacyProtectionView: View {
    let market: RegionalMarket?
    var policy: UsageConsentPolicy = UsageConsentEnvironment.policy
    var legalReader: any SettingsLegalReading = SettingsBundledLegalReader(
        privacyPolicyApproved: RegionalLaunchConfiguration.composition.reviewed?.legalCatalogApproved == true
    )
    @State private var granted: Bool
    @State private var document: AuthEntryLegalSheet?

    init(market: RegionalMarket?, policy: UsageConsentPolicy = UsageConsentEnvironment.policy,
         legalReader: (any SettingsLegalReading)? = nil) {
        self.market = market
        self.policy = policy
        let resolvedReader = legalReader ?? SettingsBundledLegalReader(
            privacyPolicyApproved: RegionalLaunchConfiguration.composition.reviewed?.legalCatalogApproved == true
        )
        self.legalReader = resolvedReader
        _granted = State(initialValue: policy.granted)
    }

    private var isPrivacyPolicyBundled: Bool {
        (legalReader as? SettingsBundledLegalReader)?.privacyPolicyApproved == true
    }

    @discardableResult
    mutating func withdrawConsent() -> Bool {
        policy.decline()
        return policy.granted
    }

    var body: some View {
        Form {
            Section { CYHeroHeader("authEntry.privacy.title", subtitle: "authEntry.gate.lead", tableName: "AuthEntry").listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            Section {
                ForEach(PrivacyGuideSummaryPresentation.defaultItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(item.id + ".title"), tableName: "PrivacyGuideSummary").font(.subheadline.weight(.medium))
                        Text(LocalizedStringKey(item.id + ".detail"), tableName: "PrivacyGuideSummary").font(.footnote).foregroundStyle(CYColor.textSecondary)
                    }
                }
            }
            .accessibilityIdentifier("privacy.guide.summaryItems")
            Section {
                Button { document = AuthEntryLegalSheet(type: .privacyPolicy) } label: { Text("authEntry.gate.openPrivacyGuide", tableName: "AuthEntry") }
                    .accessibilityIdentifier("authEntry.privacy.guide")
                if !isPrivacyPolicyBundled {
                    Text("authEntry.privacy.guideUnavailable", tableName: "AuthEntry").font(.footnote).foregroundStyle(CYColor.textSecondary)
                }
                Button { document = AuthEntryLegalSheet(type: .userAgreement) } label: { Text("authEntry.gate.openAgreement", tableName: "AuthEntry") }
                    .accessibilityIdentifier("authEntry.privacy.agreement")
            }
            Section {
                LabeledContent {
                    if granted { Label { Text("authEntry.privacy.consentGranted", tableName: "AuthEntry") } icon: { Image(systemName: "checkmark.seal") }.foregroundStyle(CYColor.successText) }
                    else { Label { Text("authEntry.privacy.consentMissing", tableName: "AuthEntry") } icon: { Image(systemName: "exclamationmark.circle") }.foregroundStyle(CYColor.warningText) }
                } label: { Text("authEntry.privacy.consentStatus", tableName: "AuthEntry") }
                    .accessibilityIdentifier("authEntry.privacy.consentStatus")
                Text("authEntry.privacy.manage", tableName: "AuthEntry").font(.footnote).foregroundStyle(CYColor.textSecondary)
                if granted {
                    Button(role: .destructive) {
                        policy.decline()
                        granted = policy.granted
                    } label: {
                        Text("compliance.revoke")
                    }
                    .accessibilityIdentifier("authEntry.privacy.withdrawConsent")
                }
            }
            if !granted { UsageConsentSignInRequirement(market: market, policy: policy, granted: $granted) }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
        .sheet(item: $document) { sheet in
            NavigationStack {
                SettingsLegalDocumentView(type: sheet.type, market: market, reader: legalReader)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { document = nil } } }
            }
        }
    }
}
