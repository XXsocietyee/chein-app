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
            Section { Text("authEntry.gate.body", tableName: "AuthEntry").font(CYTypography.body).foregroundStyle(CYColor.textSecondary).lineSpacing(CYSpacing.xs).fixedSize(horizontal: false, vertical: true) }
            Section {
                ForEach(PrivacyGuideSummaryPresentation.defaultItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(item.id + ".title"), tableName: "PrivacyGuideSummary").font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary)
                        Text(LocalizedStringKey(item.id + ".detail"), tableName: "PrivacyGuideSummary").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    }
                }
            }
            .accessibilityIdentifier("privacy.guide.summaryItems")
            Section {
                Button { document = AuthEntryLegalSheet(type: .privacyPolicy) } label: { Text("authEntry.gate.openPrivacyGuide", tableName: "AuthEntry") }
                    .accessibilityIdentifier("authEntry.privacy.guide")
                if !isPrivacyPolicyBundled {
                    Text("authEntry.privacy.guideUnavailable", tableName: "AuthEntry").font(.footnote).foregroundStyle(.secondary)
                }
                Button { document = AuthEntryLegalSheet(type: .userAgreement) } label: { Text("authEntry.gate.openAgreement", tableName: "AuthEntry") }
                    .accessibilityIdentifier("authEntry.privacy.agreement")
            }
            Section {
                LabeledContent {
                    if granted { Text("authEntry.privacy.consentGranted", tableName: "AuthEntry") }
                    else { Text("authEntry.privacy.consentMissing", tableName: "AuthEntry") }
                } label: { Text("authEntry.privacy.consentStatus", tableName: "AuthEntry") }
                    .accessibilityIdentifier("authEntry.privacy.consentStatus")
                Text("authEntry.privacy.manage", tableName: "AuthEntry").font(.footnote).foregroundStyle(.secondary)
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
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .navigationTitle(Text("authEntry.privacy.title", tableName: "AuthEntry"))
        .sheet(item: $document) { sheet in
            NavigationStack {
                SettingsLegalDocumentView(type: sheet.type, market: market, reader: legalReader)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { document = nil } } }
            }
        }
    }
}
