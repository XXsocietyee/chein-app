import SwiftUI

/// Cover image with bottom gradient scrim, title and a meta line over it. Remote images are HTTPS-only;
/// without a URL a neutral placeholder tile is shown (also used in debug fixtures).
struct CYImageCard: View {
    /// `.hero` is full-width and tall (16:10); `.shelf` is a compact 3:2 card, 280pt wide, for horizontal shelves.
    enum Style { case hero, shelf }
    private let style: Style
    private let title: Text
    private var meta: Text?
    private let imageURL: URL?
    private let aspectRatio: CGFloat
    private let seed: String
    var cachesFeedImage = false
    /// MP default cover (`MPAsset.BannerCover.*`), drawn aspect-fit on the neutral tile when there is no image.
    var fallbackArtwork: Image? = nil

    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ title: LocalizedStringKey, meta: LocalizedStringKey? = nil, imageURL: URL? = nil, aspectRatio: CGFloat? = nil, style: Style = .hero) {
        self.style = style
        self.title = Text(title)
        self.seed = String(describing: title)
        self.meta = meta.map { Text($0) }
        self.imageURL = (imageURL?.scheme?.lowercased() == "https") ? imageURL : nil
        self.aspectRatio = aspectRatio ?? (style == .shelf ? 3.0 / 2.0 : 16.0 / 10.0)
    }

    /// Server-supplied title (shown verbatim) and a pre-composed meta `Text`, for real data rows.
    init(title: Text, meta: Text?, imageURL: URL? = nil, style: Style = .hero) {
        self.style = style
        self.seed = String(describing: title)
        self.title = title
        self.meta = meta
        self.imageURL = (imageURL?.scheme?.lowercased() == "https") ? imageURL : nil
        self.aspectRatio = style == .shelf ? 3.0 / 2.0 : 16.0 / 10.0
    }

    /// Server-authored title and meta shown verbatim (never looked up as localisation keys).
    /// An empty title falls back to `fallback`; a blank meta line is omitted.
    init(verbatim title: String, fallback: LocalizedStringKey, meta: String? = nil, imageURL: URL? = nil, aspectRatio: CGFloat? = nil, style: Style = .hero) {
        self.style = style
        self.title = title.isEmpty ? Text(fallback) : Text(verbatim: title)
        self.seed = title.isEmpty ? String(describing: fallback) : title
        let trimmed = meta?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.meta = trimmed.isEmpty ? nil : Text(verbatim: meta ?? "")
        self.imageURL = (imageURL?.scheme?.lowercased() == "https") ? imageURL : nil
        self.aspectRatio = aspectRatio ?? (style == .shelf ? 3.0 / 2.0 : 16.0 / 10.0)
    }

    /// Pre-formatted (already localized) meta line, shown verbatim.
    init(_ title: LocalizedStringKey, metaText: String, imageURL: URL? = nil, aspectRatio: CGFloat? = nil, style: Style = .hero) {
        self.init(title, imageURL: imageURL, aspectRatio: aspectRatio, style: style)
        self.meta = Text(verbatim: metaText)
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { stackedCard } else { overlayCard }
        }
        .frame(width: style == .shelf ? 280 : nil)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .shadow(color: palette.cardShadowColor.opacity(0.4), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .cyPressTracking()
    }

    /// Default: text sits on the photo over a bottom scrim.
    private var overlayCard: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay { cover }
            .overlay(alignment: .bottomLeading) {
                textBlock
                    .foregroundStyle(.white)
                    .padding(.top, CYSpacing.jumbo)
                    .background(
                        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(contrast == .increased ? 0.92 : 0.78), location: 0.7)], startPoint: .top, endPoint: .bottom)
                    )
            }
    }

    /// Accessibility sizes: the photo keeps its ratio and the text moves below it on a solid surface, so nothing is clipped.
    private var stackedCard: some View {
        VStack(spacing: 0) {
            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay { cover }
                .clipped()
            textBlock
                .foregroundStyle(palette.textPrimary)
                .background(palette.bgElevated)
        }
    }

    private var textBlock: some View {
        let stacked = typeSize.isAccessibilitySize
        return VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            title
                .cyText(.sectionTitle)
                .lineLimit(stacked ? nil : 2)
            if let meta {
                meta.cyText(.meta).monospacedDigit()
                    .opacity(stacked || contrast == .increased ? 1 : 0.85)
                    .lineLimit(stacked ? nil : 2)
            }
        }
        .fixedSize(horizontal: false, vertical: stacked)
        .padding(.horizontal, style == .shelf ? CYSpacing.md : CYSpacing.lg)
        .padding(.bottom, style == .shelf ? CYSpacing.md : CYSpacing.lg)
        .padding(.top, stacked ? (style == .shelf ? CYSpacing.md : CYSpacing.lg) : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func fallbackArtwork(_ image: Image) -> CYImageCard {
        var copy = self
        copy.fallbackArtwork = image
        return copy
    }

    func cachingFeedImage(_ enabled: Bool = true) -> CYImageCard {
        var copy = self
        copy.cachesFeedImage = enabled
        return copy
    }

    @ViewBuilder private var cover: some View {
        if let imageURL, cachesFeedImage {
            PlayerFeedRemoteImage(url: imageURL, maxPixel: style == .shelf ? 960 : 1200, placeholder: { placeholder }, failure: { placeholder })
        } else if let imageURL {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
            }
        } else {
            placeholder
        }
    }
    /// Generated art (never a grey box): deterministic per title, tiny DEBUG label in debug builds.
    @ViewBuilder private var placeholder: some View {
        if let fallbackArtwork {
            LinearGradient(colors: [palette.bgStrong, palette.bgRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay { fallbackArtwork.resizable().scaledToFit().padding(CYSpacing.lg) }
                .accessibilityHidden(true)
        } else { CYCoverArt(seed: seed) }
    }
}

private struct CYImageCardPreviewBody: View {
    var body: some View {
        CYImageCard("Night Market Quest", meta: "0.8 km · Open until 23:00")
            .padding(CYSpacing.pageHorizontal)
            .frame(maxHeight: .infinity, alignment: .top)
            .cyDomainPageBackground()
    }
}
#Preview("ImageCard · player dark") { CYImageCardPreviewBody().themeDomain(.player) }
#Preview("ImageCard · merchant light") { CYImageCardPreviewBody().themeDomain(.merchant) }
