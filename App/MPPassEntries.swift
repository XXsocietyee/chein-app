import SwiftUI

// Platform pass entry points outside the market pages (mini-program `pages/talent/list` storeCard and
// `pages/topic/components/cy/self-play-checkout`). Both render nothing until their `MPParityBindings` factory exists,
// and nothing for merchants. Tapping goes through `MPParityDestination`, so a missing page binding shows the quiet state.

/// `utils/discover-store-card.js`: only city / period / year passes with a cash price and covered works.
struct PassStoreCard: Equatable {
    /// "上海通票" (one city) or "城市通票".
    let title: String
    /// "N 个主题" (one pass) or "N 种通票".
    let meta: String
    /// Cheapest cash price, "¥99 起" when there is more than one.
    let priceText: String
    /// Up to three covered topic titles.
    let covers: [String]
}

/// Checkout coverage of one topic.
struct PassCheckoutCover: Equatable {
    /// Server `platformPassCovered`: this order is ¥0.
    let covered: Bool
    /// On-sale city passes that cover this topic.
    let passes: [PassCheckoutPass]
}

struct PassCheckoutPass: Identifiable, Equatable {
    let id: String
    let name: String
    let priceText: String?
    let meta: String?
}

/// Explore feed store card (r2-store): one card in the feed, never a paywall. Tap → 通行证 list.
@MainActor struct MPPassExploreCard: View {
    @Environment(\.mpParity) private var bindings
    @Environment(\.locale) private var locale
    @State private var card: PassStoreCard?
    @State private var read = false

    var body: some View {
        Group {
            if let card, !bindings.isMerchant, bindings.passStoreCard != nil {
                NavigationLink { MPParityDestination(route: .passes(tab: .shop)) } label: { content(card) }
                    .buttonStyle(.cyPressable)
                    .accessibilityIdentifier("homeFeed.passStoreCard")
                    .transition(.opacity)
            }
        }
        .task {
            // Read once per appearance of the feed (mini-program _storeCardRead), never for merchants.
            guard !read, !bindings.isMerchant, let load = bindings.passStoreCard else { return }
            read = true
            card = await load()
        }
    }

    private func content(_ card: PassStoreCard) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.lg) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: card.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                Text(verbatim: card.meta).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                if !card.covers.isEmpty {
                    HStack(spacing: CYSpacing.xs) {
                        ForEach(card.covers.prefix(3), id: \.self) { cover in
                            Text(verbatim: cover).cyText(.caption).foregroundStyle(CYColor.textPrimary).lineLimit(1)
                                .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                                .background(.fill.tertiary, in: Capsule())
                        }
                    }
                }
            }
            Spacer(minLength: CYSpacing.sm)
            VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                Text(verbatim: LocaleDisplay.yuanAmounts(in: card.priceText, locale: locale)).cyText(.sectionTitle).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                Text("mp.pass.store.go").cyText(.label).foregroundStyle(CYColor.textInverse)
                    .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                    .background(CYColor.textPrimary, in: Capsule())
            }
        }
        .padding(CYSpacing.lg)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(.background.secondary)
                PassKeyEmblem(size: 96, lit: true).opacity(0.3).offset(x: 20, y: -16)
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Checkout rows in mini-program order: 你的通行证覆盖这个主题 · 本单 ¥0, then `single` (单次购买, selected),
/// then the 城市通票 rows covering this topic (tap → pass detail). Placed inside the checkout Form.
@MainActor struct MPPassCheckoutRows<Single: View>: View {
    let topicID: Int
    @ViewBuilder let single: Single
    @Environment(\.mpParity) private var bindings
    @Environment(\.locale) private var locale
    @State private var cover: PassCheckoutCover?

    var body: some View {
        Group {
            if let cover, cover.covered, !bindings.isMerchant {
                Label { Text("mp.pass.checkout.covered") } icon: { Image(systemName: "key.fill").foregroundStyle(CYNight.lantern) }
                    .cyText(.bodyMedium)
                    .accessibilityIdentifier("contextSelfPlay.passCovered")
            }
            single
            if let cover, !bindings.isMerchant {
                ForEach(cover.passes) { pass in
                    NavigationLink { MPParityDestination(route: .pass(productID: pass.id)) } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "circle").foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                Text(verbatim: pass.name).cyText(.bodyMedium)
                                if let meta = pass.meta { Text(verbatim: meta).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                            }
                            Spacer()
                            if let price = pass.priceText { Text(verbatim: LocaleDisplay.yuanAmounts(in: price, locale: locale)).cyText(.bodyMedium).monospacedDigit() }
                        }
                    }
                    .accessibilityIdentifier("contextSelfPlay.cityPass.\(pass.id)")
                }
            }
        }
        .task(id: topicID) {
            guard !bindings.isMerchant, let load = bindings.passCheckoutCover else { return }
            cover = await load(topicID)
        }
    }
}
