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
    private enum CopyStatus { case copied, failed }

    private var model: SettingsAboutPageModel { SettingsAboutPageModel(information: appInformation, market: market) }

    var body: some View {
        Form {
            Section {
                VStack(spacing: CYSpacing.md) {
                    Image(uiImage: UIImage(named: "SettingsBrandMark") ?? UIImage())
                        .resizable()
                        .scaledToFit()
                        .padding(CYSpacing.lg)
                        .frame(width: 112, height: 112)
                        .background {
                            ZStack {
                                CYCoverArt(seed: "about-brand", symbol: "mappin", showsDebugLabel: false, showsGlyph: false)
                                Color.black.opacity(0.35)
                            }.clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        }
                        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                        .accessibilityHidden(true)
                    appName
                    Text("settingsNative.about.tagline")
                        .font(CYTypography.body)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: CYSpacing.xl, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            }
            Section {
                SettingsFactRow(title: "settingsNative.about.version", value: appInformation.version == nil ? nil : model.version.text + " (" + model.build.text + ")",
                                identifier: "settingsNative.about.version", systemImage: "number")
                marketRow
            } header: { Text("settingsNative.about.appSection") } footer: { AIGCFilingNumberText() }
            .labelStyle(SettingsTileLabelStyle())
            // Mini-program about page: "我的二维码" with the pending player code placeholder.
            Section {
                Label("settingsNative.about.myCodePending", systemImage: "qrcode")
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .accessibilityIdentifier("settingsNative.about.myCode")
            } header: { Text("settingsNative.about.myCode") }
            Section {
                ForEach([SettingsLegalType.userAgreement, .privacyPolicy]) { type in
                    NavigationLink {
                        SettingsLegalDocumentView(type: type, market: market, reader: legalReader)
                    } label: {
                        Label(LocalizedStringKey(type.titleKey), systemImage: type == .privacyPolicy ? "hand.raised.fill" : "doc.text.fill")
                            .environment(\.settingsTileTint, type == .privacyPolicy ? SettingsTint.blue : SettingsTint.gray)
                    }
                    .accessibilityIdentifier("settingsNative.about.openLegal.\(type.rawValue)")
                }
            } header: { Text("settingsNative.about.linksSection") }
            .labelStyle(SettingsTileLabelStyle())
            if let phone = model.contactPhone {
                Section("settingsNative.about.contact") {
                    Text(verbatim: phone)
                        .font(CYTypography.numericBody)
                        .foregroundStyle(palette.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("settingsNative.about.contactPhone")
                }
            }
            SettingsAttributionsSection(copyText: copyText)
        }
        .scrollContentBackground(.hidden)
        .cyDomainPageBackground()
        .appNavigationTitle("settingsNative.about.title")
        .safeAreaInset(edge: .bottom) {
            if let phone = model.contactPhone {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    if let copyStatus {
                        Text(LocalizedStringKey(copyStatus == .copied ? "localCopy.copied" : "localCopy.failed"))
                            .font(CYTypography.meta)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settingsNative.about.copyPhone." + (copyStatus == .copied ? "copied" : "failed"))
                    }
                    CYPillButton("settingsNative.about.copyPhone", systemImage: "doc.on.doc") {
                        copy(phone)
                    }
                    .accessibilityIdentifier("settingsNative.about.copyPhone")
                }
                .padding(CYSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.bgPage)
            }
        }
        .onDisappear { copyStatus = nil }
    }

    private var appName: some View {
        Text(verbatim: "chein - 城瘾")
            .font(CYTypography.pageTitle)
            .foregroundStyle(palette.textPrimary)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("settingsNative.about.appName")
    }

    private var versionLine: String {
        "v" + model.version.text + " (" + model.build.text + ")"
    }

    private var marketRow: some View {
        LabeledContent {
            Text(verbatim: SettingsHomePage.marketText(market)).font(CYTypography.numericBody).foregroundStyle(palette.textSecondary)
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
            .font(CYTypography.numericBody)
            .foregroundStyle(palette.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
                "CFBundleDisplayName": "Questify",
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
