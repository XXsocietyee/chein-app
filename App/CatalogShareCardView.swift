import SwiftUI
import UIKit

/// Share card composer for catalog content (official routes, activities). The data is public catalog
/// content, yet the place name still sits behind an opt-in toggle (default off, unknown shows an em dash).
/// The rendered PNG leaves through the system `ShareLink`; nothing is uploaded or linked by the app.
@MainActor struct CatalogShareCardView: View {
    private let base: CYShareCardContent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var style: CYShareCardStyle
    @State private var caption = ""
    @State private var includePlace = false
    @State private var rendered: UIImage?
    @State private var renderFailed = false
    @State private var shareTick = 0

    init(content: CYShareCardContent, tint: CYShareCardTint = .ocean) {
        base = content
        _style = State(initialValue: CYShareCardStyle(template: .poster, ratio: .story, tint: tint))
    }

    private struct RenderKey: Equatable {
        let style: CYShareCardStyle
        let caption: String
        let includePlace: Bool
    }
    private var renderKey: RenderKey { RenderKey(style: style, caption: caption, includePlace: includePlace) }

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
                                Text("share.card.includePlaceHint").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(CYSpacing.lg)
                            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        }
                    } actions: {
                        if let rendered {
                            ShareLink(item: Image(uiImage: rendered),
                                      preview: SharePreview(Text(verbatim: base.title), image: Image(uiImage: rendered))) {
                                Label("share.card.share", systemImage: "square.and.arrow.up")
                                    .font(CYTypography.cardTitle)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            }
                            .buttonStyle(.cyPrimary)
                            .simultaneousGesture(TapGesture().onEnded { shareTick += 1 })
                            .accessibilityIdentifier("share.card.share")
                            .cyEntrance()
                        } else if renderFailed {
                            Text("roam.share.renderFailed").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        } else {
                            ProgressView { Text("share.card.rendering") }
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .accessibilityIdentifier("share.card.rendering")
                        }
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
            // Re-render after each change, debounced so a carousel swipe does not raster three times.
            .task(id: renderKey) {
                rendered = nil; renderFailed = false
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                let image = CYShareCardRenderer.render(content, style: style)
                guard !Task.isCancelled else { return }
                rendered = image; renderFailed = image == nil
            }
            .cyHaptic(.impactLight, trigger: shareTick)
        }
    }
}
