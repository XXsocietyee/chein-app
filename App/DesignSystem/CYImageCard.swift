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
    private var artSeed = ""

    @Environment(\.cyPalette) private var palette

    init(_ title: LocalizedStringKey, meta: LocalizedStringKey? = nil, imageURL: URL? = nil, aspectRatio: CGFloat? = nil, style: Style = .hero) {
        self.style = style
        self.title = Text(title)
        self.artSeed = String(describing: title)
        self.meta = meta.map { Text($0) }
        self.imageURL = (imageURL?.scheme?.lowercased() == "https") ? imageURL : nil
        self.aspectRatio = aspectRatio ?? (style == .shelf ? 3.0 / 2.0 : 16.0 / 10.0)
    }

    /// Server-supplied title (shown verbatim) and a pre-composed meta `Text`, for real data rows.
    init(title: Text, meta: Text?, imageURL: URL? = nil, style: Style = .hero) {
        self.style = style
        self.title = title
        self.artSeed = String(describing: title)
        self.meta = meta
        self.imageURL = (imageURL?.scheme?.lowercased() == "https") ? imageURL : nil
        self.aspectRatio = style == .shelf ? 3.0 / 2.0 : 16.0 / 10.0
    }

    /// Server-authored title and meta shown verbatim (never looked up as localisation keys).
    /// An empty title falls back to `fallback`; a blank meta line is omitted.
    init(verbatim title: String, fallback: LocalizedStringKey, meta: String? = nil, imageURL: URL? = nil, aspectRatio: CGFloat? = nil, style: Style = .hero) {
        self.style = style
        self.title = title.isEmpty ? Text(fallback) : Text(verbatim: title)
        self.artSeed = title
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
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay { cover }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    title
                        .font(CYTypography.sectionTitle)
                        .lineLimit(2)
                    if let meta {
                        meta.font(CYTypography.meta).monospacedDigit().opacity(0.85).lineLimit(2)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, style == .shelf ? CYSpacing.md : CYSpacing.lg)
                .padding(.bottom, style == .shelf ? CYSpacing.md : CYSpacing.lg)
                .padding(.top, CYSpacing.jumbo)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.78), location: 0.7)], startPoint: .top, endPoint: .bottom)
                )
            }
            .frame(width: style == .shelf ? 280 : nil)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .shadow(color: palette.cardShadowColor.opacity(0.4), radius: 8, x: 0, y: 3)
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var cover: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
            }
        } else {
            placeholder
        }
    }
    @ViewBuilder private var placeholder: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--design-fixture") {
            debugArt
        } else { neutralPlaceholder }
        #else
        neutralPlaceholder
        #endif
    }
    private var neutralPlaceholder: some View {
        LinearGradient(colors: [palette.bgStrong, palette.bgRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(palette.textPlaceholder))
    }
    #if DEBUG
    /// DEBUG-only generated cover art so design fixtures are judged with imagery. Never compiled into Release.
    private var debugArt: some View {
        let sum = artSeed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }
        let hue = Double(sum) / 360
        let symbols = ["sparkles", "map", "figure.walk", "building.2", "leaf", "moon.stars", "camera", "music.note"]
        return ZStack {
            LinearGradient(colors: [Color(hue: hue, saturation: 0.62, brightness: 0.62), Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.22), .clear], center: .topTrailing, startRadius: 4, endRadius: 220)
            Image(systemName: symbols[sum % symbols.count]).font(.system(size: 64, weight: .light)).foregroundStyle(.white.opacity(0.35))
        }
        .overlay(alignment: .topTrailing) {
            Text(verbatim: "DEBUG ART").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.5)).padding(8)
        }
    }
    #endif
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
