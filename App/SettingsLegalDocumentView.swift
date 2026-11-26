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
            VStack(alignment: .leading, spacing: 24) {
                // pages/agreement: phases, version, and date come from `SettingsLegalAgreementPage` (blank is an em dash).
                let page = SettingsLegalAgreementPage.facts(for: model.state)
                switch model.state {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                        .accessibilityIdentifier("settingsNative.legal.loading")
                case .failed:
                    ContentUnavailableView {
                        Label { Text("settingsNative.legal.loadFailed").accessibilityIdentifier("settingsNative.legal.error") } icon: { Image(systemName: "exclamationmark.triangle") }
                    } actions: {
                        Button { Task { await model.load(type: type, market: market) } } label: { Text("settingsNative.retry") }
                            .buttonStyle(.bordered).controlSize(.large)
                            .accessibilityIdentifier(SettingsLegalAgreementPage.retryAccessibilityIdentifier)
                    }
                case .loaded(.missing(let reason)):
                    ContentUnavailableView {
                        Label { Text("settingsNative.legal.missingTitle").accessibilityIdentifier("settingsNative.legal.missing") } icon: { Image(systemName: "doc.questionmark") }
                    } description: {
                        Text(LocalizedStringKey(reason.messageKey))
                    }
                case .loaded(.sourceDocument):
                    if case .ready(let document) = page.phase {
                        readyBody(document, page: page)
                    } else {
                        // An all-blank shell is unknown, not a document with blank fields.
                        ContentUnavailableView {
                            Label { Text("settingsNative.legal.unknownTitle").accessibilityIdentifier("settingsNative.legal.unknown") } icon: { Image(systemName: "questionmark.circle") }
                        } description: {
                            Text(verbatim: SettingsLegalAgreementPage.unknownDisplay)
                        } actions: {
                            Button { Task { await model.load(type: type, market: market) } } label: { Text("settingsNative.retry") }
                                .buttonStyle(.bordered).controlSize(.large)
                                .accessibilityIdentifier(SettingsLegalAgreementPage.retryAccessibilityIdentifier)
                        }
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .leading).padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(Text(LocalizedStringKey(type.titleKey)))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: loadID) { await model.load(type: type, market: market) }
        .onDisappear { model.invalidate() }
    }

    @ViewBuilder private func readyBody(_ document: SettingsLegalDocument, page: SettingsLegalAgreementPage.Facts) -> some View {
        // The mini-program page opens straight on the title; the Chinese-only note is for other UI languages.
        if locale.language.languageCode != .chinese {
            Label("settingsNative.legal.sourceNotice", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("settingsNative.legal.sourceNotice")
        }
        // B-AG-01: the inline bar carries the document title; version and date live in one footer (MP agreement wxml:23).
        if !document.intro.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(verbatim: document.intro).font(.body).foregroundStyle(.secondary).textSelection(.enabled)
        }
        ForEach(Array(document.sections.enumerated()), id: \.offset) { index, section in
            VStack(alignment: .leading, spacing: 8) {
                // B-AG-03: MP heading is the card-title step, not the section title.
                Text(verbatim: section.heading).font(.headline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(SettingsLegalLine.lines(in: section.body).enumerated()), id: \.offset) { _, line in
                    VStack(alignment: .leading, spacing: 2) {
                        if let marker = line.marker { Text(verbatim: marker).fixedSize(horizontal: false, vertical: true) }
                        Text(verbatim: line.text).frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }.font(.body).foregroundStyle(.secondary).textSelection(.enabled).accessibilityElement(children: .combine)
                }
            }
            .accessibilityIdentifier(SettingsLegalAgreementPage.sectionAccessibilityIdentifier(index: index))
        }
        // Source footer (B-AG-01): 「版本 x · 生效日期：y」 on one line, wrapping to two at large text sizes.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                legalVersion(page)
                Text(verbatim: "·").accessibilityHidden(true)
                legalEffectiveDate(page)
            }
            VStack(alignment: .leading, spacing: 2) {
                legalVersion(page)
                legalEffectiveDate(page)
            }
        }
        .font(.footnote).foregroundStyle(.tertiary).padding(.top, 16)
        Text("settingsNative.legal.noAcceptance").font(.footnote).foregroundStyle(.secondary)
            .accessibilityIdentifier("settingsNative.legal.noAcceptance")
    }

    private func legalVersion(_ page: SettingsLegalAgreementPage.Facts) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("settingsNative.legal.version")
            Text(verbatim: page.versionText).accessibilityIdentifier(SettingsLegalAgreementPage.versionAccessibilityIdentifier)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func legalEffectiveDate(_ page: SettingsLegalAgreementPage.Facts) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("settingsNative.legal.effectiveDate")
            Text(verbatim: page.effectiveDateText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settingsNative.legal.effectiveDate")
    }
}
