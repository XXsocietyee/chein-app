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
            // B-PV-03: the page title is the inline system title; the lead stays as the first line.
            Section { Text("authEntry.gate.lead", tableName: "AuthEntry").font(.body).foregroundStyle(.secondary) }
            Section {
                ForEach(PrivacyGuideSummaryPresentation.defaultItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(item.id + ".title"), tableName: "PrivacyGuideSummary").font(.body)
                        Text(LocalizedStringKey(item.id + ".detail"), tableName: "PrivacyGuideSummary").font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityIdentifier("privacy.guide.summaryItems")
            Section {
                Button { document = AuthEntryLegalSheet(type: .privacyPolicy) } label: { Text("authEntry.gate.openPrivacyGuide", tableName: "AuthEntry") }
                    .accessibilityIdentifier("authEntry.privacy.guide")
                    .accessibilityLabel(Text("authEntry.gate.openPrivacyGuide", tableName: "AuthEntry"))
                    .accessibilityValue(Text("authEntry.gate.lead", tableName: "AuthEntry"))
                    .accessibilityHint(Text("authEntry.privacy.manage", tableName: "AuthEntry"))
                if !isPrivacyPolicyBundled {
                    ContentUnavailableView {
                        Label { Text("authEntry.privacy.guideUnavailable", tableName: "AuthEntry") } icon: { Image(systemName: "doc.questionmark") }
                    }
                    .accessibilityIdentifier("authEntry.privacy.guideUnavailable")
                }
                Button { document = AuthEntryLegalSheet(type: .userAgreement) } label: { Text("authEntry.gate.openAgreement", tableName: "AuthEntry") }
                    .accessibilityIdentifier("authEntry.privacy.agreement")
                    .accessibilityLabel(Text("authEntry.gate.openAgreement", tableName: "AuthEntry"))
                    .accessibilityValue(Text("authEntry.gate.lead", tableName: "AuthEntry"))
                    .accessibilityHint(Text("authEntry.privacy.manage", tableName: "AuthEntry"))
            }
            Section {
                LabeledContent {
                    if granted { Label { Text("authEntry.privacy.consentGranted", tableName: "AuthEntry") } icon: { Image(systemName: "checkmark.seal") }.foregroundStyle(.green) }
                    else { Label { Text("authEntry.privacy.consentMissing", tableName: "AuthEntry") } icon: { Image(systemName: "exclamationmark.circle") }.foregroundStyle(.orange) }
                } label: { Text("authEntry.privacy.consentStatus", tableName: "AuthEntry") }
                    .accessibilityIdentifier("authEntry.privacy.consentStatus")
                    .accessibilityLabel(Text("authEntry.privacy.consentStatus", tableName: "AuthEntry"))
                    .accessibilityValue(Text(LocalizedStringKey(granted ? "authEntry.privacy.consentGranted" : "authEntry.privacy.consentMissing"), tableName: "AuthEntry"))
                    .accessibilityHint(Text("authEntry.privacy.manage", tableName: "AuthEntry"))
                Text("authEntry.privacy.manage", tableName: "AuthEntry").font(.footnote).foregroundStyle(.secondary)
                if granted {
                    Button(role: .destructive) {
                        policy.decline()
                        granted = policy.granted
                    } label: {
                        Text("compliance.revoke")
                    }
                    .accessibilityIdentifier("authEntry.privacy.withdrawConsent")
                    .accessibilityLabel(Text("compliance.revoke"))
                    .accessibilityValue(Text("authEntry.privacy.consentGranted", tableName: "AuthEntry"))
                    .accessibilityHint(Text("authEntry.privacy.manage", tableName: "AuthEntry"))
                }
            }
            SessionLocationHoldsSection()
            if !granted { UsageConsentSignInRequirement(market: market, policy: policy, granted: $granted) }
        }
        .navigationTitle(Text("authEntry.privacy.title", tableName: "AuthEntry")).navigationBarTitleDisplayMode(.inline)
        .sheet(item: $document) { sheet in Group {
            NavigationStack {
                SettingsLegalDocumentView(type: sheet.type, market: market, reader: legalReader)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { document = nil } } }
            }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}
