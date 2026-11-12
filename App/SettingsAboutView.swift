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
            // Source section 我的二维码: the voucher stays in its error state until a real player code exists.
            Section {
                playerCodeVoucher
            } header: { Text("settingsNative.about.playerCode") }
            Section {
                ForEach([SettingsLegalType.userAgreement, .privacyPolicy]) { type in
                    NavigationLink {
                        SettingsLegalDocumentView(type: type, market: market, reader: legalReader)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey(type.titleKey))
                                if type == .userAgreement {
                                    Text("settingsNative.about.agreementHint").font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                                }
                            }
                        } icon: { Image(systemName: type == .privacyPolicy ? "hand.raised.fill" : "doc.text.fill") }
                            .environment(\.settingsTileTint, type == .privacyPolicy ? SettingsTint.blue : SettingsTint.gray)
                    }
                    .accessibilityIdentifier("settingsNative.about.openLegal.\(type.rawValue)")
                }
            } header: { Text("settingsNative.about.linksSection") }
            .labelStyle(SettingsTileLabelStyle())
            if let phone = model.contactPhone {
                Section {
                    Text(verbatim: phone)
                        .font(CYTypography.numericBody)
                        .foregroundStyle(palette.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("settingsNative.about.contactPhone")
                } header: { Text("settingsNative.about.contact") } footer: { Text("settingsNative.about.contactSource") }
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
        .onDisappear { copyStatus = nil; showsPlayerCodePending = false }
    }

    /// `SettingsAboutPageModel.playerCode`. Production is `.error` (the player-code POST stays uninstalled), so the
    /// voucher shows the source error copy; nothing generates or requests a code here.
    @ViewBuilder private var playerCodeVoucher: some View {
        let phase = model.playerCode
        VStack(spacing: CYSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                    .fill(palette.bgRaised)
                if case .loading = phase {
                    CYSkeleton()
                } else if let url = phase.imageURL {
                    AsyncImage(url: url) { image in
                        image.resizable().interpolation(.none).scaledToFit().padding(CYSpacing.md)
                    } placeholder: { CYSkeleton() }
                    .accessibilityLabel(Text("settingsNative.about.playerCode"))
                } else {
                    Image(systemName: "qrcode")
                        .font(.largeTitle).imageScale(.large)
                        .foregroundStyle(palette.textTertiary.opacity(0.5))
                        .accessibilityHidden(true)
                    RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                        .strokeBorder(palette.textTertiary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .frame(width: 168, height: 168)
            switch phase {
            case .ready:
                EmptyView()
            case .loading:
                Text("settingsNative.loading").font(CYTypography.meta).foregroundStyle(palette.textSecondary)
            case .error:
                Text("settingsNative.about.playerCodeUnavailable").font(CYTypography.bodyMedium).foregroundStyle(palette.textPrimary)
                    .accessibilityIdentifier("settingsNative.about.playerCodeUnavailable")
                Text("settingsNative.about.playerCodeHint").font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            case .empty, .unknown:
                Text(verbatim: SettingsAboutMetadataPhase.unknownText).font(CYTypography.numericBody).foregroundStyle(palette.textSecondary)
                    .accessibilityLabel(Text("settingsNative.about.playerCodeUnavailable"))
            }
            if showsPlayerCodePending {
                CYStatusChip("settingsNative.about.playerCodePending", tone: .neutral, systemImage: "clock")
                    .accessibilityIdentifier("settingsNative.about.playerCodePending")
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.sm)
        .contentShape(Rectangle())
        // Source bind:retry="explainQrPending": a tap explains, it never requests a code.
        .onTapGesture { if case .error = phase { showsPlayerCodePending = true } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(phase == .error ? .isButton : [])
        .accessibilityAction { if case .error = phase { showsPlayerCodePending = true } }
        .accessibilityIdentifier("settingsNative.about.playerCode")
        .cyAnimation(CYMotion.standard, value: showsPlayerCodePending)
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
