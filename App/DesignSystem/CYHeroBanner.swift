import SwiftUI

/// One slide of a `CYHeroBanner`. A slide without a usable HTTPS cover shows a brand gradient (never an empty frame).
struct CYHeroBannerItem: Identifiable {
    let id: Int
    var imageURL: URL?
    var accessibilityLabel: LocalizedStringKey?
    /// Optional copy drawn over the art with a scrim. Without it the slide is art only.
    var title: Text? = nil
    var subtitle: Text? = nil
    var action: (() -> Void)?
}

/// Rounded banner pager (mini-program home hero swiper) with real depth: the neighbours peek in, the active
/// card is full scale and the others recede (scale + dim), and the cover parallaxes inside its card.
/// Reduce Motion keeps the paging but drops scale and parallax. Renders nothing when `items` is empty.
struct CYHeroBanner: View {
    let items: [CYHeroBannerItem]
    @State private var page: Int? = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let gradients: [[Color]] = [
        [Color(red: 0.05, green: 0.36, blue: 0.45), Color(red: 0.10, green: 0.10, blue: 0.20)],
        [Color(red: 0.62, green: 0.25, blue: 0.10), Color(red: 0.16, green: 0.07, blue: 0.10)],
        [Color(red: 0.08, green: 0.36, blue: 0.24), Color(red: 0.04, green: 0.12, blue: 0.14)],
    ]

    private static let cardFraction: CGFloat = 0.88

    var body: some View {
        if !items.isEmpty {
            VStack(spacing: CYSpacing.sm) {
                // The clear box fixes the height (card width x 9/16) so the pager never collapses inside a List row.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .aspectRatio(items.count > 1 ? 16.0 / 9.0 / Self.cardFraction : 16.0 / 9.0, contentMode: .fit)
                    .overlay { pager }
                if items.count > 1 { dots }
            }
        }
    }

    private var pager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: CYSpacing.md) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    card(item, index: index).id(index)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, CYSpacing.lg, for: .scrollContent)
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $page)
        .sensoryFeedback(.selection, trigger: page)
    }

    private func card(_ item: CYHeroBannerItem, index: Int) -> some View {
        let reduced = reduceMotion
        return slide(item, index: index)
            .containerRelativeFrame(.horizontal) { width, _ in items.count > 1 ? width * Self.cardFraction : width }
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
            .scrollTransition(axis: .horizontal) { content, phase in
                content
                    .scaleEffect(reduced ? 1 : 1 - abs(phase.value) * 0.07)
                    .opacity(reduced ? 1 : 1 - abs(phase.value) * 0.3)
            }
    }

    @ViewBuilder private func slide(_ item: CYHeroBannerItem, index: Int) -> some View {
        let art = cover(item, index: index).overlay(alignment: .bottomLeading) { caption(item) }
        if let action = item.action {
            Button(action: action) { art }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibilityLabel ?? "")
        } else {
            art.accessibilityHidden(true)
        }
    }

    /// Cover (or brand gradient) drawn 18% oversized and shifted against the scroll so it parallaxes inside the card.
    @ViewBuilder private func cover(_ item: CYHeroBannerItem, index: Int) -> some View {
        let reduced = reduceMotion
        Group {
            if let url = item.imageURL, url.scheme?.lowercased() == "https" {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { gradient(index) }
                }
            } else {
                gradient(index)
            }
        }
        .scaleEffect(reduceMotion ? 1 : 1.18)
        .scrollTransition(axis: .horizontal) { content, phase in
            content.offset(x: reduced ? 0 : phase.value * -44)
        }
    }

    @ViewBuilder private func caption(_ item: CYHeroBannerItem) -> some View {
        if let title = item.title {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                title.cyText(.dataXL).lineLimit(3).minimumScaleFactor(0.7)
                if let subtitle = item.subtitle { subtitle.cyText(.bodyCompact).opacity(0.9).lineLimit(2) }
            }
            .foregroundStyle(.white)
            .padding(CYSpacing.lg)
            .padding(.top, CYSpacing.jumbo)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
        }
    }

    private func gradient(_ index: Int) -> some View {
        ZStack {
            LinearGradient(colors: Self.gradients[index % Self.gradients.count], startPoint: .topLeading, endPoint: .bottomTrailing)
            CYCoverArt(seed: "hero-\(index)", showsDebugLabel: false).opacity(0.6)
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.primary.opacity(index == (page ?? 0) ? 0.9 : 0.3))
                    .frame(width: index == (page ?? 0) ? 18 : 6, height: 6)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: page)
        .accessibilityHidden(true)
    }
}

#Preview("HeroBanner · player dark") {
    CYHeroBanner(items: (0..<3).map { CYHeroBannerItem(id: $0) })
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
        .themeDomain(.player)
}
