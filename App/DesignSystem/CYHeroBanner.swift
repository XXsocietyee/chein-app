import SwiftUI

/// One slide of a `CYHeroBanner`. A slide without a usable HTTPS cover shows a plain system fill (never an empty frame).
struct CYHeroBannerItem: Identifiable {
    let id: Int
    var imageURL: URL?
    var accessibilityLabel: LocalizedStringKey?
    /// Optional copy drawn over the art with a scrim. Without it the slide is art only.
    var title: Text? = nil
    var subtitle: Text? = nil
    var action: (() -> Void)?
}

/// Banner pager (mini-program home hero swiper), native r2: the system page-style `TabView` (system page dots),
/// each page the cover image (or a plain system fill with a photo symbol when there is no HTTPS cover) in the one
/// card radius, with an optional title / subtitle in plain text below it. No gradients, scrim, shadow, parallax or
/// scale. Renders nothing when `items` is empty.
struct CYHeroBanner: View {
    let items: [CYHeroBannerItem]
    @State private var page: Int = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    private var hasCaption: Bool { items.contains { $0.title != nil } }

    var body: some View {
        if !items.isEmpty {
            if typeSize.isAccessibilitySize {
                accessibilityPager
            } else {
                regularPager
            }
        }
    }

    /// Default text size: caption sits under the cover inside the 4:3 pager.
    private var regularPager: some View {
        TabView(selection: $page) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                slide(item)
                    .padding(.horizontal)
                    .padding(.bottom, items.count > 1 ? CYSpacing.xxl : 0)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .frame(maxWidth: .infinity)
        .aspectRatio(hasCaption ? 4.0 / 3.0 : 16.0 / 10.0, contentMode: .fit)
        .sensoryFeedback(.selection, trigger: page)
    }

    /// AX-XXXL: the 4:3 frame clipped the caption. The cover keeps 16:9; the title sits under it and can grow.
    private var accessibilityPager: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            TabView(selection: $page) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    coverButton(item)
                        .padding(.horizontal)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            if items.indices.contains(page) {
                caption(items[page], titleLines: 4, subtitleLines: 3)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.selection, trigger: page)
    }

    @ViewBuilder private func slide(_ item: CYHeroBannerItem) -> some View {
        let content = VStack(alignment: .leading, spacing: CYSpacing.sm) {
            cover(item)
            caption(item, titleLines: 2, subtitleLines: 2)
        }
        if let action = item.action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibilityLabel ?? "")
        } else {
            content.accessibilityHidden(true)
        }
    }

    @ViewBuilder private func caption(_ item: CYHeroBannerItem, titleLines: Int, subtitleLines: Int) -> some View {
        if let title = item.title {
            VStack(alignment: .leading, spacing: 2) {
                title.font(.headline).lineLimit(titleLines).fixedSize(horizontal: false, vertical: titleLines > 2)
                if let subtitle = item.subtitle {
                    subtitle.font(.subheadline).foregroundStyle(.secondary).lineLimit(subtitleLines).fixedSize(horizontal: false, vertical: subtitleLines > 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func coverButton(_ item: CYHeroBannerItem) -> some View {
        if let action = item.action {
            Button(action: action) { cover(item) }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibilityLabel ?? "")
        } else {
            cover(item)
        }
    }

    private func cover(_ item: CYHeroBannerItem) -> some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                if let url = item.imageURL, url.scheme?.lowercased() == "https" {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
                    }
                } else {
                    placeholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
    }

    private var placeholder: some View {
        Color(uiColor: .secondarySystemFill)
            .overlay {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
    }
}

#Preview("HeroBanner") {
    CYHeroBanner(items: (0..<3).map { CYHeroBannerItem(id: $0) })
        .frame(maxHeight: .infinity, alignment: .top)
}
