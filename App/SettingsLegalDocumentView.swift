import SwiftUI

@MainActor private final class SettingsLegalViewModel: ObservableObject {
    @Published private(set) var state: SettingsLegalState = .idle
    private let coordinator: SettingsLegalCoordinator
    init(reader: any SettingsLegalReading) {
        coordinator = SettingsLegalCoordinator(reader: reader)
        coordinator.onChange = { [weak self] in self?.state = $0 }
    }
    func load(type: SettingsLegalType, market: RegionalMarket?) async { await coordinator.load(type: type, market: market) }
    func invalidate() { coordinator.invalidate() }
}

/// Read-only source document. Opening, scrolling, or dismissing never accepts an agreement.
@MainActor struct SettingsLegalDocumentView: View {
    let type: SettingsLegalType
    let market: RegionalMarket?
    @StateObject private var model: SettingsLegalViewModel
    @Environment(\.locale) private var locale
    init(type: SettingsLegalType, market: RegionalMarket?, reader: any SettingsLegalReading) {
        self.type = type; self.market = market
        _model = StateObject(wrappedValue: SettingsLegalViewModel(reader: reader))
    }
    private var loadID: String { type.rawValue + ":" + (market?.rawValue ?? "missing") }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                // pages/agreement: phases, version, and date come from `SettingsLegalAgreementPage` (blank is an em dash).
                let page = SettingsLegalAgreementPage.facts(for: model.state)
                switch model.state {
                case .idle, .loading:
                    CYLoadingStateView(rows: 3)
                        .accessibilityIdentifier("settingsNative.legal.loading")
                case .failed:
                    CYEmptyState(systemImage: "exclamationmark.triangle", "settingsNative.legal.loadFailed",
                                 messageIdentifier: "settingsNative.legal.error", actionTitle: "settingsNative.retry",
                                 actionIdentifier: SettingsLegalAgreementPage.retryAccessibilityIdentifier, kind: .failure) {
                        Task { await model.load(type: type, market: market) }
                    }
                case .loaded(.missing(let reason)):
                    CYEmptyState(systemImage: "doc.questionmark", "settingsNative.legal.missingTitle", detail: LocalizedStringKey(reason.messageKey), messageIdentifier: "settingsNative.legal.missing")
                case .loaded(.sourceDocument):
                    if case .ready(let document) = page.phase {
                        readyBody(document, page: page)
                    } else {
                        // An all-blank shell is unknown, not a document with blank fields.
                        CYEmptyState(systemImage: "questionmark.circle", "settingsNative.legal.unknownTitle",
                                     detailVerbatim: SettingsLegalAgreementPage.unknownDisplay, messageIdentifier: "settingsNative.legal.unknown",
                                     actionTitle: "settingsNative.retry", actionIdentifier: SettingsLegalAgreementPage.retryAccessibilityIdentifier) {
                            Task { await model.load(type: type, market: market) }
                        }
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .leading).padding(CYSpacing.pageHorizontal)
            .frame(maxWidth: .infinity)
        }
        .cyDocumentSurface()
        .navigationTitle(Text(LocalizedStringKey(type.titleKey)))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: loadID) { await model.load(type: type, market: market) }
        .onDisappear { model.invalidate() }
    }

    @ViewBuilder private func readyBody(_ document: SettingsLegalDocument, page: SettingsLegalAgreementPage.Facts) -> some View {
        // The mini-program page opens straight on the title; the Chinese-only note is for other UI languages.
        if locale.language.languageCode != .chinese {
            Text("settingsNative.legal.sourceNotice").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("settingsNative.legal.sourceNotice")
        }
        // B-AG-01: the inline bar carries the document title; version and date live in one footer (MP agreement wxml:23).
        if !document.intro.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(verbatim: document.intro).cyText(.body).foregroundStyle(CYColor.textSecondary).textSelection(.enabled)
        }
        ForEach(Array(document.sections.enumerated()), id: \.offset) { index, section in
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                // B-AG-03: MP heading is the card-title step, not the section title.
                Text(verbatim: section.heading).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(SettingsLegalLine.lines(in: section.body).enumerated()), id: \.offset) { _, line in
                    VStack(alignment: .leading, spacing: 2) {
                        if let marker = line.marker { Text(verbatim: marker).fixedSize(horizontal: false, vertical: true) }
                        Text(verbatim: line.text).frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }.cyText(.body).foregroundStyle(CYColor.textSecondary).textSelection(.enabled).accessibilityElement(children: .combine)
                }
            }
            .accessibilityIdentifier(SettingsLegalAgreementPage.sectionAccessibilityIdentifier(index: index))
        }
        // Source footer (B-AG-01): 「版本 x · 生效日期：y」 on one line, wrapping to two at large text sizes.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                legalVersion(page)
                Text(verbatim: "·").accessibilityHidden(true)
                legalEffectiveDate(page)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                legalVersion(page)
                legalEffectiveDate(page)
            }
        }
        .cyText(.meta).foregroundStyle(CYColor.textTertiary).padding(.top, CYSpacing.lg)
        Text("settingsNative.legal.noAcceptance").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            .accessibilityIdentifier("settingsNative.legal.noAcceptance")
    }

    private func legalVersion(_ page: SettingsLegalAgreementPage.Facts) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xxs) {
            Text("settingsNative.legal.version")
            Text(verbatim: page.versionText).accessibilityIdentifier(SettingsLegalAgreementPage.versionAccessibilityIdentifier)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func legalEffectiveDate(_ page: SettingsLegalAgreementPage.Facts) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xxs) {
            Text("settingsNative.legal.effectiveDate")
            Text(verbatim: page.effectiveDateText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settingsNative.legal.effectiveDate")
    }
}
