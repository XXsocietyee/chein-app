import SwiftUI
import UIKit

/// pages/shezhi/about/index. Settings archetype: hero, fact cards, one copy action, empty personal code.
/// Reads the same bundle facts and CN contact. Missing facts stay an em dash. No ICP, address, or legal body.
@MainActor struct SettingsAboutView: View {
    let market: RegionalMarket?
    let appInformation: SettingsAppInformation
    let legalReader: any SettingsLegalReading
    var copyText: (String) throws -> Void = { LocalPasteboard.copy($0) }
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @State private var copyStatus: CopyStatus?
    private enum CopyStatus { case copied, failed }

    var body: some View {
        Form {
            Section {
                VStack(spacing: CYSpacing.md) {
                    Image("SettingsBrandMark")
                        .resizable()
                        .scaledToFit()
                        .padding(CYSpacing.md)
                        .frame(width: 88, height: 88)
                        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(palette.textPrimary.opacity(0.1), lineWidth: 1))
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
                .listRowInsets(EdgeInsets(top: CYSpacing.lg, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            }
            Section {
                SettingsFactRow(title: "settingsNative.about.version", value: appInformation.version, identifier: "settingsNative.about.version", systemImage: "number")
                SettingsFactRow(title: "settingsNative.about.build", value: appInformation.build, identifier: "settingsNative.about.build", systemImage: "hammer")
                marketRow
            }
            Section {
                VStack(spacing: CYSpacing.sm) {
                    CYEmptyState(systemImage: "qrcode", "settingsNative.about.playerCode")
                    Text("settingsNative.about.playerCodeUnavailable")
                        .font(CYTypography.body)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("settingsNative.about.codeUnavailable")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            Section {
                ForEach([SettingsLegalType.userAgreement, .privacyPolicy]) { type in
                    NavigationLink {
                        SettingsLegalDocumentView(type: type, market: market, reader: legalReader)
                    } label: {
                        CYListRow(LocalizedStringKey(type.titleKey), trailing: .none, card: true) {
                            CYRowIcon(systemImage: "doc.text")
                        }
                    }
                    .accessibilityIdentifier("settingsNative.about.openLegal.\(type.rawValue)")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            if let phone = SettingsSourceContact.phone(market: market) {
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
            if let phone = SettingsSourceContact.phone(market: market) {
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
        Text(verbatim: "Chengyin 城瘾")
            .font(CYTypography.pageTitle)
            .foregroundStyle(palette.textPrimary)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("settingsNative.about.appName")
    }

    private var marketRow: some View {
        CYListRow("region.market", trailing: .value(market?.rawValue ?? "—"), card: true) {
            CYRowIcon(systemImage: "globe")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("region.market"))
        .accessibilityValue(Text(verbatim: market?.rawValue ?? "—"))
        .accessibilityIdentifier("settingsNative.about.market")
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
        ZStack(alignment: .trailing) {
            CYListRow(title, trailing: .value(shown), card: true) {
                CYRowIcon(systemImage: systemImage)
            }
            .accessibilityHidden(true)
            labeledValue
                .padding(.trailing, CYSpacing.lg)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
