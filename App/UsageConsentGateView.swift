import SwiftUI

/// UserDefaults holds only the agreed document versions and pending request IDs, never tokens.
final class UserDefaultsUsageConsentStorage: UsageConsentStorage, @unchecked Sendable {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    func set(_ value: Data?, forKey key: String) { defaults.set(value, forKey: key) }
}

enum UsageConsentEnvironment {
    /// DEBUG launches that carry any argument (every UI test does) start with consent treated as
    /// given in memory, so existing entry flows stay unchanged; `--uitesting-usage-consent-pending`
    /// exercises the real gate with isolated storage. The XCTest-hosted app (AppUnit target) also
    /// starts granted, so a launch sheet never covers test-owned windows. Plain launches and Release use UserDefaults.
    static var policy: UsageConsentPolicy {
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--uitesting-usage-consent-pending") { return UsageConsentPolicy(storage: UsageConsentFixtureStorage.pending) }
        let xctestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if args.count > 1 || xctestHost { return UsageConsentPolicy(storage: UsageConsentFixtureStorage.granted) }
#endif
        return UsageConsentPolicy(storage: UserDefaultsUsageConsentStorage())
    }
}

#if DEBUG
/// Per-process memory only, so UI tests never read or write the real stored choice.
enum UsageConsentFixtureStorage {
    static let pending = MemoryUsageConsentStorage()
    static let granted: MemoryUsageConsentStorage = {
        let storage = MemoryUsageConsentStorage(); try? UsageConsentPolicy(storage: storage).agree(agreementChecked: true); return storage
    }()
}

final class MemoryUsageConsentStorage: UsageConsentStorage {
    private var values: [String: Data] = [:]
    func data(forKey key: String) -> Data? { values[key] }
    func set(_ value: Data?, forKey key: String) { values[key] = value }
}
#endif

/// Mini-program components/cy/privacy-gate. The sheet cannot be swiped away while a decision is pending.
struct UsageConsentGateView: View {
    let market: RegionalMarket?
    let onAgree: () -> Void
    let onDecline: () -> Void
    var legalReader: any SettingsLegalReading = SettingsBundledLegalReader(
        privacyPolicyApproved: RegionalLaunchConfiguration.composition.reviewed?.legalCatalogApproved == true
    )
    @State private var checked = false
    @State private var showsCheckRequired = false
    @State private var agreeTaps = 0
    @State private var document: AuthEntryLegalSheet?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                    Image(systemName: checked ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(checked ? CYColor.successText : CYColor.textPrimary)
                        .frame(width: 64, height: 64)
                        .background(CYColor.bgElevated, in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, options: .nonRepeating, value: checked)
                        .accessibilityHidden(true)
                    Text("authEntry.gate.title", tableName: "AuthEntry")
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        Text("authEntry.gate.summary", tableName: "AuthEntry")
                            .font(CYTypography.body)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        // Full disclosure stays one tap away; the identifier keeps the original body text addressable.
                        DisclosureGroup {
                            Text("authEntry.gate.body", tableName: "AuthEntry")
                                .font(CYTypography.bodyCompact)
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, CYSpacing.sm)
                                .accessibilityIdentifier("authEntry.gate.body")
                            Text("authEntry.gate.localOnly", tableName: "AuthEntry")
                                .font(.footnote).foregroundStyle(CYColor.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, CYSpacing.sm)
                        } label: {
                            Text("authEntry.gate.details", tableName: "AuthEntry")
                                .font(CYTypography.bodyCompact.weight(.semibold))
                                .foregroundStyle(CYColor.textPrimary)
                        }
                        .tint(CYColor.textSecondary)
                        .accessibilityIdentifier("authEntry.gate.details")
                    }
                    VStack(spacing: 0) {
                        documentRow("authEntry.gate.openPrivacyGuide", id: "authEntry.gate.privacyGuide", type: .privacyPolicy)
                        Divider().overlay(CYColor.borderSubtle)
                        documentRow("authEntry.gate.openAgreement", id: "authEntry.gate.agreement", type: .userAgreement)
                    }
                    .padding(.horizontal, CYSpacing.lg)
                    .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                }
                .padding(CYSpacing.xxl)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                    Toggle(isOn: $checked) { Text("authEntry.gate.checkbox", tableName: "AuthEntry").font(CYTypography.bodyCompact) }
                        .toggleStyle(.switch)
                        .tint(CYColor.accent)
                        .sensoryFeedback(.selection, trigger: checked)
                        .accessibilityIdentifier("authEntry.gate.checkbox")
                    if showsCheckRequired && !checked {
                        Label { Text("authEntry.gate.checkRequired", tableName: "AuthEntry") } icon: { Image(systemName: "exclamationmark.circle") }
                            .font(CYTypography.bodyCompact)
                            .foregroundStyle(CYColor.dangerText)
                            .accessibilityIdentifier("authEntry.gate.checkRequired")
                    }
                }
                VStack(spacing: CYSpacing.sm) {
                    // One primary action; declining is a quiet text button (guest browsing continues).
                    Button {
                        guard checked else { showsCheckRequired = true; return }
                        agreeTaps += 1
                        onAgree()
                    } label: { Text("authEntry.gate.agree", tableName: "AuthEntry") }
                        .buttonStyle(.cyPrimary)
                        .disabled(!checked)
                        .sensoryFeedback(.success, trigger: agreeTaps)
                        .accessibilityIdentifier("authEntry.gate.agree")
                    Button(action: onDecline) { Text("authEntry.gate.decline", tableName: "AuthEntry").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget) }
                        .font(CYTypography.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("authEntry.gate.decline")
                }
    
                }
                .padding(.horizontal, CYSpacing.xxl)
                .padding(.top, CYSpacing.md)
                .padding(.bottom, CYSpacing.md)
                .background(CYColor.bgPage)
            }
            .background(CYColor.bgPage)
            .themeDomain(.player)
            .navigationTitle(Text("authEntry.gate.title", tableName: "AuthEntry"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $document) { sheet in
                NavigationStack {
                    SettingsLegalDocumentView(type: sheet.type, market: market, reader: legalReader)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { document = nil } } }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func documentRow(_ title: LocalizedStringKey, id: String, type: SettingsLegalType) -> some View {
        Button { document = AuthEntryLegalSheet(type: type) } label: {
            HStack(spacing: CYSpacing.md) {
                Text(title, tableName: "AuthEntry")
                    .font(CYTypography.bodyCompact)
                    .foregroundStyle(CYColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    .foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
            }
            .frame(minHeight: CYSpacing.minTouchTarget + CYSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// Local wrapper so this file never claims a global Identifiable conformance for a Core type.
struct AuthEntryLegalSheet: Identifiable { let type: SettingsLegalType; var id: String { type.rawValue } }

/// Shown once per launch to a signed-out user who has not agreed to the current versions.
/// Declining keeps guest browsing (mini-program: no wx.login, public lists still load).
private struct UsageConsentLaunchGate: ViewModifier {
    let signedIn: Bool
    let market: RegionalMarket?
    let onDecline: () -> Void
    @State private var presented = false
    @State private var declinedThisLaunch = false
    private let policy = UsageConsentEnvironment.policy

    func body(content: Content) -> some View {
        content
            .onAppear { presented = UsageConsentGateDecision.showAtLaunch(granted: policy.granted, signedIn: signedIn, declinedThisLaunch: declinedThisLaunch) }
            .sheet(isPresented: $presented) {
                UsageConsentGateView(market: market, onAgree: {
                    try? policy.agree(agreementChecked: true); presented = false
                }, onDecline: {
                    policy.decline(); declinedThisLaunch = true; presented = false; onDecline()
                })
            }
    }
}

extension View {
    func usageConsentLaunchGate(signedIn: Bool, market: RegionalMarket?, onDecline: @escaping () -> Void) -> some View {
        modifier(UsageConsentLaunchGate(signedIn: signedIn, market: market, onDecline: onDecline))
    }
}

/// Sign-in surfaces require the current agreement first; reopening the gate is always explicit.
struct UsageConsentSignInRequirement: View {
    let market: RegionalMarket?
    var policy: UsageConsentPolicy = UsageConsentEnvironment.policy
    @Binding var granted: Bool
    @State private var presented = false

    var body: some View {
        Section {
            Text("authEntry.gate.requiredForSignIn", tableName: "AuthEntry")
                .accessibilityIdentifier("authEntry.gate.requiredForSignIn")
            Button { presented = true } label: { Text("authEntry.gate.review", tableName: "AuthEntry") }
                .accessibilityIdentifier("authEntry.gate.review")
        }
        .sheet(isPresented: $presented) {
            UsageConsentGateView(market: market, onAgree: {
                try? policy.agree(agreementChecked: true); granted = policy.granted; presented = false
            }, onDecline: { policy.decline(); granted = false; presented = false })
        }
    }
}
