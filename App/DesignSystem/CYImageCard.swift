import SwiftUI

/// Cover image with bottom gradient scrim, title and a meta line over it. Remote images are HTTPS-only;
/// without a URL a neutral placeholder tile is shown (also used in debug fixtures).
struct CYImageCard: View {
    private let title: LocalizedStringKey
    private let meta: LocalizedStringKey?
    private let imageURL: URL?
    private let aspectRatio: CGFloat

    @Environment(\.cyPalette) private var palette

    init(_ title: LocalizedStringKey, meta: LocalizedStringKey? = nil, imageURL: URL? = nil, aspectRatio: CGFloat = 16.0 / 10.0) {
        self.title = title
        self.meta = meta
        self.imageURL = (imageURL?.scheme?.lowercased() == "https") ? imageURL : nil
        self.aspectRatio = aspectRatio
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
                .padding(CYSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                )
            }
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
