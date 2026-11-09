import SwiftUI

/// Cover image with bottom gradient scrim, title and a meta line over it. Remote images are HTTPS-only;
/// without a URL a neutral placeholder tile is shown (also used in debug fixtures).
struct CYImageCard: View {
    /// `.hero` is full-width and tall (16:10); `.shelf` is a compact 3:2 card, 280pt wide, for horizontal shelves.
    enum Style { case hero, shelf }
    private let style: Style
    private let title: LocalizedStringKey
    private let meta: LocalizedStringKey?
    private let imageURL: URL?
    private let aspectRatio: CGFloat

    @Environment(\.cyPalette) private var palette

    init(_ title: LocalizedStringKey, meta: LocalizedStringKey? = nil, imageURL: URL? = nil, aspectRatio: CGFloat? = nil, style: Style = .hero) {
        self.style = style
        self.title = title
        self.meta = meta
        self.imageURL = (imageURL?.scheme?.lowercased() == "https") ? imageURL : nil
        self.aspectRatio = aspectRatio ?? (style == .shelf ? 3.0 / 2.0 : 16.0 / 10.0)
    }

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay { cover }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text(title)
                        .font(CYTypography.sectionTitle)
                        .lineLimit(2)
                    if let meta {
                        Text(meta).font(CYTypography.meta).opacity(0.85).lineLimit(1)
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
    private var placeholder: some View {
        LinearGradient(colors: [palette.bgStrong, palette.bgRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(palette.textPlaceholder))
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
