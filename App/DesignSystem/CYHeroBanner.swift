import SwiftUI

/// One slide of a `CYHeroBanner`. A slide without a usable HTTPS cover shows a brand gradient (never an empty frame).
struct CYHeroBannerItem: Identifiable {
    let id: Int
    var imageURL: URL?
    var accessibilityLabel: LocalizedStringKey?
    var action: (() -> Void)?
}

/// Full-width rounded banner pager (mini-program home hero swiper) with page dots.
/// Renders nothing when `items` is empty, so there is no empty frame when the server has no banners.
struct CYHeroBanner: View {
    let items: [CYHeroBannerItem]
    @State private var page = 0

    private static let gradients: [[Color]] = [
        [Color(red: 0.05, green: 0.36, blue: 0.45), Color(red: 0.10, green: 0.10, blue: 0.20)],
        [Color(red: 0.62, green: 0.25, blue: 0.10), Color(red: 0.16, green: 0.07, blue: 0.10)],
        [Color(red: 0.08, green: 0.36, blue: 0.24), Color(red: 0.04, green: 0.12, blue: 0.14)],
    ]

    var body: some View {
        if !items.isEmpty {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    TabView(selection: $page) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            slide(item, index: index).tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .overlay(alignment: .bottom) {
                    if items.count > 1 { dots.padding(.bottom, CYSpacing.md) }
                }
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        }
    }

    @ViewBuilder private func slide(_ item: CYHeroBannerItem, index: Int) -> some View {
        let art = cover(item, index: index)
        if let action = item.action {
            Button(action: action) { art }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibilityLabel ?? "")
        } else {
            art.accessibilityHidden(true)
        }
    }

    @ViewBuilder private func cover(_ item: CYHeroBannerItem, index: Int) -> some View {
        if let url = item.imageURL, url.scheme?.lowercased() == "https" {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { gradient(index) }
            }
        } else {
            gradient(index)
        }
    }

    private func gradient(_ index: Int) -> some View {
        LinearGradient(colors: Self.gradients[index % Self.gradients.count], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == page ? 1 : 0.45))
                    .frame(width: index == page ? 18 : 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: page)
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
