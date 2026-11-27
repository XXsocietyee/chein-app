import SwiftUI
import UIKit

/// pages/shezhi/about/index. Settings archetype: hero, fact cards, one copy action, empty personal code.
/// Reads the same bundle facts and CN contact. Missing facts stay an em dash. No ICP, address, or legal body.
/// The generative-AI filing number (`aigcFilingNo`) shows under the version only when the features read supplies it.
@MainActor struct SettingsAboutView: View {
    let market: RegionalMarket?
    let appInformation: SettingsAppInformation
    let legalReader: any SettingsLegalReading
    var copyText: (String) throws -> Void = { LocalPasteboard.copy($0) }
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @State private var copyStatus: CopyStatus?
    @State private var showsPlayerCodePending = false
    @State private var toastMessage: LocalizedStringKey?
    private enum CopyStatus { case copied, failed }

    private var model: SettingsAboutPageModel { SettingsAboutPageModel(information: appInformation, market: market) }

    var body: some View {
        Form {
            Section {
                VStack {
                    // MP about: `/images/cy_logo_mark.png`, aspectFit, no backdrop.
                    MPAsset.BrandLogo.cyLogoMark
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                        .accessibilityHidden(true)
                    appName // MP about.wxml: logo + 城瘾 only, no tagline
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            Section {
                SettingsFactRow(title: "settingsNative.about.version", value: appInformation.version == nil ? nil : model.version.text + " (" + model.build.text + ")",
                                identifier: "settingsNative.about.version", systemImage: "number")
                marketRow
            } header: { Text("settingsNative.about.appSection") } footer: { AIGCFilingNumberText() }
            .labelStyle(SettingsTileLabelStyle())
            // B-AB-01 (hand-off MC-43): 我的二维码 shows only once a real player code exists; no permanent error voucher.
            if model.playerCode.imageURL != nil {
                Section {
                    playerCodeVoucher
                } header: { Text("settingsNative.about.playerCode") }
            }
            Section {
                ForEach([SettingsLegalType.userAgreement, .privacyPolicy]) { type in
                    NavigationLink {
                        SettingsLegalDocumentView(type: type, market: market, reader: legalReader)
                    } label: {
                        Label { Text(LocalizedStringKey(type.titleKey)) } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconAgreement) } // MP about: icon_agreement on both
                            .environment(\.settingsTileTint, type == .privacyPolicy ? SettingsTint.blue : SettingsTint.gray)
                    }
                    .accessibilityIdentifier("settingsNative.about.openLegal.\(type.rawValue)")
                }
            } header: { Text("settingsNative.about.linksSection") }
            .labelStyle(SettingsTileLabelStyle())
            if let phone = model.contactPhone {
                // B-AB-05: the MP about page has no footer bar; copying the number is the contact row's own action.
                Section {
                    HStack {
                        AccountPublishMPGlyph(MPAsset.FeatureIcon.iconHeadset) // MP about 联系我们 = icon_headset
                            .foregroundStyle(.secondary)
                        Text(verbatim: phone)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("settingsNative.about.contactPhone")
                        Button { copy(phone) } label: {
                            Image(systemName: "doc.on.doc")
                                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("settingsNative.about.copyPhone"))
                        .accessibilityIdentifier("settingsNative.about.copyPhone")
                    }
                    if let copyStatus {
                        Text(LocalizedStringKey(copyStatus == .copied ? "localCopy.copied" : "localCopy.failed"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("settingsNative.about.copyPhone." + (copyStatus == .copied ? "copied" : "failed"))
                    }
                } header: { Text("settingsNative.about.contact") } footer: { Text("settingsNative.about.contactSource") }
            } else {
                // B-AB-03: the MP always offers 联系我们; without a phone the support contact page is the way in.
                Section {
                    NavigationLink { WithdrawalSupportContactView() } label: {
                        Label { Text("settingsNative.about.contact") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconHeadset) }
                    }
                    .accessibilityIdentifier("settingsNative.about.contactFallback")
                }
                .labelStyle(SettingsTileLabelStyle())
            }
            SettingsAttributionsSection(copyText: copyText)
        }
        .cyDomainPageBackground()
        .cyPageTitle("settingsNative.about.title")
        .onDisappear { copyStatus = nil; showsPlayerCodePending = false; toastMessage = nil }
        .cyToast(message: $toastMessage, tone: copyStatus == .failed ? .warning : .info)
    }

    /// `SettingsAboutPageModel.playerCode`. Production is `.error` (the player-code POST stays uninstalled), so the
    /// voucher shows the source error copy; nothing generates or requests a code here.
    @ViewBuilder private var playerCodeVoucher: some View {
        let phase = model.playerCode
        VStack {
            ZStack {
                if case .loading = phase {
                    ProgressView()
                } else if let url = phase.imageURL {
                    AsyncImage(url: url) { image in
                        image.resizable().interpolation(.none).scaledToFit().padding()
                    } placeholder: { ProgressView() }
                    .accessibilityLabel(Text("settingsNative.about.playerCode"))
                } else {
                    Image(systemName: "qrcode")
                        .font(.largeTitle).imageScale(.large)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 168, height: 168)
            switch phase {
            case .ready:
                EmptyView()
            case .loading:
                Text("settingsNative.loading").font(.footnote).foregroundStyle(.secondary)
            case .error:
                Text("settingsNative.about.playerCodeUnavailable").font(.body.weight(.medium)).foregroundStyle(.primary)
                    .accessibilityIdentifier("settingsNative.about.playerCodeUnavailable")
                Text("settingsNative.about.playerCodeHint").font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .empty, .unknown:
                Text(verbatim: SettingsAboutMetadataPhase.unknownText).monospacedDigit().foregroundStyle(.secondary)
                    .accessibilityLabel(Text("settingsNative.about.playerCodeUnavailable"))
            }
            if showsPlayerCodePending {
                Label("settingsNative.about.playerCodePending", systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settingsNative.about.playerCodePending")
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        // Source bind:retry="explainQrPending": a tap explains, it never requests a code.
        .onTapGesture {
            if case .error = phase {
                showsPlayerCodePending = true
                toastMessage = "settingsNative.about.playerCodePending"
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(phase == .error ? .isButton : [])
        .accessibilityAction {
            if case .error = phase {
                showsPlayerCodePending = true
                toastMessage = "settingsNative.about.playerCodePending"
            }
        }
        .accessibilityIdentifier("settingsNative.about.playerCode")
    }

    private var appName: some View {
        // B-AB-04: MP about/index.wxml:24 shows the product name 城瘾 only.
        Text(verbatim: "城瘾")
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("settingsNative.about.appName")
    }

    private var versionLine: String {
        "v" + model.version.text + " (" + model.build.text + ")"
    }

    private var marketRow: some View {
        LabeledContent {
            Text(verbatim: SettingsHomePage.marketText(market)).foregroundStyle(.secondary)
        } label: {
            Label("region.market", systemImage: "globe").environment(\.settingsTileTint, SettingsTint.teal)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("region.market"))
        .accessibilityValue(Text(verbatim: SettingsHomePage.marketText(market)))
        .accessibilityIdentifier("settingsNative.about.market")
    }

    private func copy(_ phone: String) {
        do {
            try copyText(phone)
            copyStatus = .copied
        } catch {
            copyStatus = .failed
        }
        let key: String.LocalizationValue = copyStatus == .copied ? "localCopy.copied" : "localCopy.failed"
        toastMessage = copyStatus == .copied ? "localCopy.copied" : "localCopy.failed"
        UIAccessibility.post(notification: .announcement, argument: appLocalized(key, locale: locale))
    }
}

/// Version and build. The value text keeps the existing identifier only when the bundle provided one.
private struct SettingsFactRow: View {
    let title: LocalizedStringKey
    let value: String?
    let identifier: String
    let systemImage: String
    @Environment(\.cyPalette) private var palette
    private var shown: String { value ?? "—" }

    var body: some View {
        LabeledContent {
            labeledValue
        } label: {
            Label(title, systemImage: systemImage).environment(\.settingsTileTint, SettingsTint.blue)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var labeledValue: some View {
        let text = Text(verbatim: shown)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        if let value {
            text
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(verbatim: value))
                .accessibilityIdentifier(identifier)
        } else {
            text.accessibilityLabel(Text("settingsNative.about.metadataMissing"))
        }
    }
}

#if DEBUG
#Preview("About · player") {
    NavigationStack {
        SettingsAboutView(
            market: .china,
            appInformation: SettingsAppInformation(info: [
                "CFBundleDisplayName": "Chein",
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "1"
            ]),
            legalReader: SettingsBundledLegalReader()
        )
    }
    .themeDomain(.player)
}

#Preview("About · merchant") {
    NavigationStack {
        SettingsAboutView(
            market: nil,
            appInformation: SettingsAppInformation(info: [:]),
            legalReader: SettingsBundledLegalReader()
        )
    }
    .themeDomain(.merchant)
}
#endif
