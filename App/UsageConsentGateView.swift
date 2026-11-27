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
    @State private var agreeTaps = 0
    @State private var document: AuthEntryLegalSheet?
    /// r9 B-PV-04: MP pages/privacy/index.wxml:10 `我已阅读并同意` checkbox; :22 同意 is disabled until it is checked.
    @State private var agreementChecked = false

    /// MP privacy/index.wxml:10: one checkbox row 我已阅读并同意《用户服务协议》《隐私保护指引》.
    /// iOS has no checkbox control, so the closest Apple control is a `Toggle` (native-r2 N-12, noted in the receipt).
    private var agreementToggle: some View {
        Toggle(isOn: $agreementChecked) {
            Text("fixr9.ap.consent.readAndAgree")
        }
        .accessibilityIdentifier("authEntry.gate.checkbox")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("authEntry.gate.lead", tableName: "AuthEntry")
                        .accessibilityIdentifier("authEntry.gate.lead")
                }
                Section {
                    documentRow("authEntry.gate.openAgreement", id: "authEntry.gate.agreement", type: .userAgreement)
                    documentRow("authEntry.gate.openPrivacyGuide", id: "authEntry.gate.privacyGuide", type: .privacyPolicy)
                } header: {
                    Text("authEntry.gate.continueMeans", tableName: "AuthEntry")
                }
                Section {
                    agreementToggle
                }
                Section {
                    // One confirm button agrees to both documents (MP privacy/index.wxml:22). Declining stays borderless.
                    Button {
                        agreeTaps += 1
                        onAgree()
                    } label: {
                        Text("authEntry.gate.agree", tableName: "AuthEntry").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!agreementChecked)
                    .sensoryFeedback(.success, trigger: agreeTaps)
                    .accessibilityIdentifier("authEntry.gate.agree")
                    .accessibilityHint(Text("authEntry.gate.continueMeans", tableName: "AuthEntry"))
                    Button(action: onDecline) {
                        Text("authEntry.gate.decline", tableName: "AuthEntry").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("authEntry.gate.decline")
                    .accessibilityHint(Text("authEntry.gate.continueMeans", tableName: "AuthEntry"))
                }
                .listRowBackground(Color.clear)
            }
            .themeDomain(.player)
            .navigationTitle(Text("authEntry.gate.title", tableName: "AuthEntry"))
            .navigationBarTitleDisplayMode(.inline)
            .cySheet(item: $document) { sheet in
                NavigationStack {
                    SettingsLegalDocumentView(type: sheet.type, market: market, reader: legalReader)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("action.close") { document = nil }
                                    .accessibilityIdentifier("usageConsent.legal.close")
                            }
                        }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .interactiveDismissDisabled()
    }

    private func documentRow(_ title: LocalizedStringKey, id: String, type: SettingsLegalType) -> some View {
        // A sheet instead of a pushed page keeps the gate in place (Settings → Privacy style rows with a chevron).
        Button { document = AuthEntryLegalSheet(type: type) } label: {
            LabeledContent {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            } label: {
                Text(title, tableName: "AuthEntry").foregroundStyle(.primary)
            }
        }
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
    var presentation: RootPresentationCoordinator? = nil
    let onDecline: () -> Void
    @State private var presented = false
    @State private var declinedThisLaunch = false
    private let policy = UsageConsentEnvironment.policy

    func body(content: Content) -> some View {
        content
            // The "agreed while signed out" line lives on the privacy page (MP pages/privacy), not app-wide:
            // app-wide it covered the welcome screen's Browse-as-guest button (11-27).
            .onAppear { presented = UsageConsentGateDecision.showAtLaunch(granted: policy.granted, signedIn: signedIn, declinedThisLaunch: declinedThisLaunch); presentation?.consentActive = presented }
            .onChange(of: presented) { _, value in presentation?.consentActive = value }
            .cySheet(isPresented: $presented) { Group {
                UsageConsentGateView(market: market, onAgree: {
                    try? policy.agree(agreementChecked: true); presented = false
                }, onDecline: {
                    policy.decline(); declinedThisLaunch = true; presented = false; onDecline()
                })
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func usageConsentLaunchGate(signedIn: Bool, market: RegionalMarket?, presentation: RootPresentationCoordinator? = nil, onDecline: @escaping () -> Void) -> some View {
        modifier(UsageConsentLaunchGate(signedIn: signedIn, market: market, presentation: presentation, onDecline: onDecline))
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
                .accessibilityLabel(Text("authEntry.gate.review", tableName: "AuthEntry"))
                .accessibilityValue(Text("authEntry.gate.requiredForSignIn", tableName: "AuthEntry"))
                .accessibilityHint(Text("authEntry.gate.lead", tableName: "AuthEntry"))
        }
        .cySheet(isPresented: $presented) { Group {
            UsageConsentGateView(market: market, onAgree: {
                try? policy.agree(agreementChecked: true); granted = policy.granted; presented = false
            }, onDecline: { policy.decline(); granted = false; presented = false })
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}
