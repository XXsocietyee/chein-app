import SwiftUI
import UIKit

/// Insert these sections inside the existing SettingsView Form. No language picker, new root
/// NavigationStack, regional override, credentials, or session service is created here.
@MainActor struct SettingsSupportSections: View {
    let market: RegionalMarket?
    let complianceCoordinator: AccountComplianceCoordinator?
    private(set) var showsNPCChatDataEntry: Bool
    func hidingNPCChatDataEntry() -> Self { var copy = self; copy.showsNPCChatDataEntry = false; return copy }
    let soundStore: any SettingsSoundStoring
    let legalReader: any SettingsLegalReading
    let appInformation: SettingsAppInformation
    let copyText: (String) throws -> Void
    init(market: RegionalMarket?, complianceCoordinator: AccountComplianceCoordinator? = nil, soundStore: (any SettingsSoundStoring)? = nil,
         legalReader: (any SettingsLegalReading)? = nil,
         appInformation: SettingsAppInformation = .current(),
         copyText: @escaping (String) throws -> Void = { LocalPasteboard.copy($0) },
         showsNPCChatDataEntry: Bool = true) {
        self.showsNPCChatDataEntry = showsNPCChatDataEntry
        self.complianceCoordinator = complianceCoordinator
        self.market = market; self.soundStore = soundStore ?? SettingsLocalSoundStore()
        self.legalReader = legalReader ?? SettingsBundledLegalReader()
        self.appInformation = appInformation; self.copyText = copyText
    }
    var body: some View {
        Section {
            NavigationLink {
                SettingsSoundPreferencesView(store: soundStore)
            } label: { Label("settingsNative.sound.title", systemImage: "speaker.wave.2.fill") }
            .accessibilityIdentifier("settingsNative.openSound")
        }
        .environment(\.settingsTileTint, SettingsTint.pink)
        Section("settingsNative.legal.title") {
            ForEach(SettingsLegalType.allCases) { type in
                NavigationLink {
                    SettingsLegalDocumentView(type: type, market: market, reader: legalReader)
                } label: { Label(LocalizedStringKey(type.titleKey), systemImage: "doc.text") }
                .accessibilityIdentifier("settingsNative.openLegal.\(type.rawValue)")
            }
        }
        // UIV-06: 关于 sits with legal; privacy/compliance (incl. account deregistration) follows, then sign-out last.
        Section {
            NavigationLink {
                SettingsAboutView(market: market, appInformation: appInformation, legalReader: legalReader, copyText: copyText)
            } label: {
                // Source shezhi entry description: 版本、协议、联系与我的二维码.
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settingsNative.about.title")
                        Text("settingsNative.about.entryHint").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    }
                } icon: { Image(systemName: "info.circle.fill") }
            }
            .accessibilityIdentifier("settingsNative.openAbout")
        }
        .environment(\.settingsTileTint, SettingsTint.blue)
        if let complianceCoordinator {
            AccountComplianceSettingsSection(makeCoordinator: { complianceCoordinator }, market: market, legalReader: legalReader, showsNPCChatDataEntry: showsNPCChatDataEntry)
        } else {
        Section("settingsNative.privacy.title") {
            ForEach(SettingsUnavailableFeature.allCases) { feature in
                NavigationLink {
                    SettingsUnavailableFeatureView(feature: feature, market: market, legalReader: legalReader)
                } label: { Label(LocalizedStringKey(feature.titleKey), systemImage: "lock.shield") }
                .accessibilityIdentifier("settingsNative.openBlocked.\(feature.rawValue)")
            }
        }
        }
    }
}

@MainActor private final class SettingsSoundViewModel: ObservableObject {
    @Published private(set) var state = SettingsSoundState()
    private let coordinator: SettingsSoundCoordinator
    init(store: any SettingsSoundStoring) {
        coordinator = SettingsSoundCoordinator(store: store)
        coordinator.onChange = { [weak self] in self?.state = $0 }
    }
    func load() async { await coordinator.load() }
    func set(_ key: SettingsSoundKey, to value: Bool) async { await coordinator.set(key, to: value) }
}
@MainActor struct SettingsSoundPreferencesView: View {
    @StateObject private var model: SettingsSoundViewModel
    init(store: any SettingsSoundStoring) { _model = StateObject(wrappedValue: SettingsSoundViewModel(store: store)) }
    var body: some View {
        Form {
            if let preferences = model.state.preferences {
                Section {
                    soundToggle(.sound, preferences: preferences)
                    soundToggle(.haptics, preferences: preferences)
                }
                Section("settingsNative.sound.ambient") {
                    ForEach([SettingsSoundKey.airplane, .ocean, .raindrop, .forest]) { key in
                        soundToggle(key, preferences: preferences)
                    }
                }
            } else if model.state.isBusy {
                ProgressView("settingsNative.loading").accessibilityIdentifier("settingsNative.sound.loading")
            }
            if let key = model.state.messageKey {
                Section {
                    Text(LocalizedStringKey(key)).foregroundStyle(.secondary)
                        .accessibilityIdentifier("settingsNative.sound.error")
                    if model.state.preferences == nil {
                        Button("settingsNative.retry") { Task { await model.load() } }
                            .accessibilityIdentifier("settingsNative.sound.retry")
                    }
                }
            }
        }
        .cyPageTitle("settingsNative.sound.title")
        .task { await model.load() }
    }
    private func soundToggle(_ key: SettingsSoundKey, preferences: SettingsSoundPreferences) -> some View {
        HStack {
            Text(LocalizedStringKey(key.titleKey)).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true) // The native switch supplies this spoken label.
            Spacer(minLength: 16)
            // Keep the native switch's accessibility/hit frame on the control itself.
            // A Form Toggle can otherwise expose the entire label row as a Switch.
            Toggle(LocalizedStringKey(key.titleKey), isOn: Binding(
                get: { model.state.preferences?[key] ?? preferences[key] },
                set: { value in Task { await model.set(key, to: value) } }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .fixedSize()
            .disabled(model.state.isBusy)
            .accessibilityLabel(Text(LocalizedStringKey(key.titleKey)))
            .accessibilityIdentifier("settingsNative.sound.\(key.rawValue)")
        }
        .frame(minHeight: 44)
    }
}

@MainActor struct SettingsUnavailableFeatureView: View {
    let feature: SettingsUnavailableFeature
    let market: RegionalMarket?
    let legalReader: any SettingsLegalReading
    var body: some View {
        Form {
            Section {
                Label("settingsNative.blocked.unavailable", systemImage: "info.circle")
                Text(LocalizedStringKey(feature.messageKey)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("settingsNative.blocked.message")
            }
            Section {
                let type: SettingsLegalType = feature == .accountDeletion ? .cancellationNotice : .privacyPolicy
                NavigationLink {
                    SettingsLegalDocumentView(type: type, market: market, reader: legalReader)
                } label: { Text(LocalizedStringKey(type.titleKey)) }
                .accessibilityIdentifier("settingsNative.blocked.openDocument")
            }
        }
        .navigationTitle(Text(LocalizedStringKey(feature.titleKey)))
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor struct SettingsAttributionsSection: View {
    let copyText: (String) throws -> Void
    var body: some View {
        Section("settingsNative.attribution.title") {
            ForEach(SettingsSourceAttribution.all) { attribution in
                VStack(alignment: .leading, spacing: 8) {
                    // Keep the row anchor on this leaf. A container identifier can
                    // overwrite the independent copy button and feedback identifiers.
                    Text(verbatim: attribution.title).font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("settingsNative.attribution.\(attribution.id)")
                    Text(verbatim: attribution.detail).cyText(.bodyCompact)
                    Text(verbatim: attribution.sourceURL).cyText(.bodyCompact).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    NativeCopyTextButton(text: attribution.sourceURL,
                        title: LocalizedStringKey(attribution.copyTitleKey),
                        identifier: "settingsNative.attribution.copy.\(attribution.id)", copyText: copyText)
                }
            }
        }
    }
}

/// iOS Settings style row icon: a 30pt continuous rounded-square tile, filled with the group tint
/// (`settingsTileTint`) and a white glyph. Rows in a group share a hue; the default is neutral gray.
struct SettingsTileLabelStyle: LabelStyle {
    @Environment(\.cyPalette) private var palette
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            configuration.icon
                .cyText(.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .frame(width: 30, height: 30)
                .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
                .accessibilityHidden(true)
            configuration.title
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
