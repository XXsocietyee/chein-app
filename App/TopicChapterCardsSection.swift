import SwiftUI

/// Route detail 「节点介绍」: a horizontal row of chapter cards (owner request 2026-11-19; MP `index.wxml` `det4`,
/// `pages/topic/utils/chapter-cards.js`). Tapping a card discloses its description in place; tapping again
/// collapses it, and only one card is open at a time. Ending chapters are already excluded by `TopicChapterCards`.
/// Ported from chengyin-ios `f815bf30` (port plan r1 C9), re-skinned for the native iOS rule: Dynamic Type `.cyText` tokens,
/// native r2: system text styles and colours, system animation (instant under Reduce Motion), plain button.
/// Replaces the old per-template 「节点介绍」 shelf (`TopicXcxTemplatesSection`), which the MP also replaced.
struct TopicChapterCardsSection: View {
    let cards: [TopicChapterCard]
    @State private var openID: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !cards.isEmpty {
            Section("topicXcx.section.nodeIntro") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(cards) { card in
                            TopicChapterCardView(card: card, isOpen: openID == card.id) { toggle(card.id) }
                        }
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
                .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: 16, bottom: CYSpacing.sm, trailing: 16))
                .accessibilityIdentifier("topic.chapterCards")
            }
        }
    }

    private func toggle(_ id: Int) {
        let next = TopicChapterCards.toggle(open: openID, tapped: id)
        // Reduce Motion: the description is simply there (plan C9: "instant under Reduce Motion").
        guard !reduceMotion else { openID = next; return }
        withAnimation { openID = next }
    }
}

struct TopicChapterCardView: View {
    let card: TopicChapterCard
    let isOpen: Bool
    let toggle: () -> Void
    private static let width: CGFloat = 156
    /// a11y-dt r3: in the 156 pt rail card one AX5 line holds a few glyphs; title and meta wrap there instead of truncating.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var titleLines: Int { dynamicTypeSize.isAccessibilitySize ? 3 : 1 }

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                // The image's own retry button must not swallow the card tap; a later appearance retries it.
                Group {
                    if card.imageSource == nil {
                        // REV-B B-05 (MP chapter-cards.js FALLBACK_COVER): no chapter or route image → `route_city_cover.png`.
                        Color.clear
                            .aspectRatio(CYCachedAsyncImageRole.cover.aspectRatio, contentMode: .fit)
                            .overlay { MPAsset.BannerCover.routeCityCover.resizable().scaledToFill() }
                            .clipped()
                            .accessibilityIdentifier("topic.chapterCard.fallbackCover")
                    } else {
                        CYCachedAsyncImage(card.imageSource, role: .cover)
                    }
                }
                    .frame(width: Self.width)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Text(verbatim: card.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(titleLines)
                if let metaText {
                    metaText
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(titleLines)
                }
                if isOpen, let description = card.description {
                    Text(verbatim: description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: Self.width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(Text(isOpen ? LocalizedStringKey("topic.chapterCard.expanded") : LocalizedStringKey("topic.chapterCard.collapsed")))
        .accessibilityIdentifier("topic.chapterCard.\(card.id)")
    }

    /// 含 N 个玩法 · 约 M 分钟; a missing part is left out, never written as zero (plan Q3a).
    private var metaText: Text? {
        let games = card.gameCount.map { Text("topic.chapterCard.games \($0)") }
        let minutes = card.minutes.map { Text("topic.chapterCard.minutes \($0)") }
        switch (games, minutes) {
        case let (g?, m?): return g + Text(verbatim: " · ") + m
        case let (g?, nil): return g
        case let (nil, m?): return m
        default: return nil
        }
    }
}
