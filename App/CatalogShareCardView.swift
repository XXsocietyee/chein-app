import SwiftUI
import UIKit

/// Share card composer for catalog content (official routes, activities). The data is public catalog
/// content, yet the place name still sits behind an opt-in toggle (default off, unknown shows an em dash).
/// The carousel is the live preview; `ImageRenderer` runs only on prepare (`CYShareComposerMachine`), and the
/// rendered PNG leaves through the system `ShareLink`; nothing is uploaded or linked by the app.
@MainActor struct CatalogShareCardView: View {
    private let base: CYShareCardContent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var reduceMotion
    @State private var machine = CYShareComposerMachine()
    @State private var style: CYShareCardStyle
    @State private var caption = ""
    @State private var includePlace = false
    @State private var shareTick = 0

    init(content: CYShareCardContent, tint: CYShareCardTint = .ocean) {
        base = content
        _style = State(initialValue: CYShareCardStyle(template: .poster, ratio: .story, tint: tint))
    }

    /// What the exported image contains: the base content with the user's caption and place choice applied.
    private var content: CYShareCardContent {
        var copy = base
        copy.caption = caption
        if !includePlace {
            copy.place = nil
            // A single pin is a position; only a route shape (two or more points) stays without the place name.
            if copy.silhouette.count < 2 { copy.silhouette = [] }
        }
        return copy
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.xl) {
                    CYHeroHeader("share.card.title", subtitle: "share.card.privacy")
                    CYShareComposer(content: content, style: $style, caption: $caption,
                                    captionPlaceholder: appLocalized("share.card.caption.placeholder", locale: locale),
                                    accessibilityPrefix: "share.card.composer") {
                        if base.place != nil || base.silhouette.count == 1 {
                            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                Toggle("share.card.includePlace", isOn: $includePlace)
                                    .accessibilityIdentifier("share.card.includePlace")
                                Text("share.card.includePlaceHint").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(CYSpacing.lg)
                            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        }
                    } actions: {
                        actionsSection
                            .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: machine.state)
                    }
                }
                .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.xxxl)
            }
            .background(CYColor.bgPage.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }.accessibilityIdentifier("share.card.done")
                }
            }
            .onChange(of: style) { _, _ in machine.send(.styleChanged) }
            .onChange(of: caption) { _, _ in machine.send(.captionChanged) }
            .onChange(of: includePlace) { _, _ in machine.send(.invalidate) }
            .onChange(of: machine.readyTick) { _, _ in CYShareAnnouncer.announce(appLocalized("roam.share.ready", locale: locale)) }
            .cyHaptic(.impactLight, trigger: machine.readyTick)
            .cyHaptic(.impactLight, trigger: shareTick)
        }
        .cyPlayerSheetGlass()
        .cyDomainScreen(.player)
    }

    @ViewBuilder private var actionsSection: some View {
        if let rendered = machine.image {
            CYShareReadyRow(image: rendered, title: "roam.share.ready", hint: "roam.share.readyHint",
                            previewLabel: "roam.share.previewLabel", identifier: "share.card.preview")
            // `ShareLink` has no completion callback, so this confirms the tap; the roam surfaces confirm the outcome.
            ShareLink(item: Image(uiImage: rendered),
                      preview: SharePreview(Text(verbatim: base.title), image: Image(uiImage: rendered))) {
                Label("share.card.share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .simultaneousGesture(TapGesture().onEnded { shareTick += 1 })
            .accessibilityIdentifier("share.card.share")
        } else {
            if case .renderFailed = machine.state {
                Text("roam.share.renderFailed").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            CYSharePrepareButton(title: "roam.share.prepare", state: machine.state, identifier: "share.card.prepare") { prepare() }
        }
    }

    /// Render off the press frame: `.rendering` commits first, the bitmap lands in the next main-actor turn.
    private func prepare() {
        machine.send(.prepare)
        let renderContent = content, renderStyle = style
        Task { @MainActor in
            machine.send(.rendered(CYShareCardRenderer.render(renderContent, style: renderStyle)))
        }
    }
}
