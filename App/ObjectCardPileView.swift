import SwiftUI

/// OCARDS-2 (MP object-cards wxml:17-24, utils/object-pile.js): the latest 40 cards lie in a heap on a ground line;
/// each can be picked up and dragged or flung; ✦ gathers them into one ball and drops them again; a tap opens the card.
/// Native: a deterministic SwiftUI heap (no physics canvas). Images read only through the bounded `objectCardMedia`
/// loader. The host shows its grid instead under VoiceOver or Reduce Motion, so every card stays reachable there.
@MainActor struct ObjectCardPileView: View {
    let cards: [ObjectCard]
    let onSelect: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gathered = false
    @State private var moved: [Int: CGSize] = [:]
    @State private var dragIndex: Int?
    @State private var dragTranslation: CGSize = .zero
    private let tile: CGFloat = 78
    private let height: CGFloat = 380
    static let limit = 40

    var body: some View {
        let shown = Array(cards.prefix(Self.limit).enumerated())
        VStack(alignment: .trailing, spacing: CYSpacing.sm) {
            if shown.count > 1 { gatherButton }
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(shown, id: \.offset) { index, card in
                        let base: CGPoint = position(index, count: shown.count, in: geo.size)
                        let extra: CGSize = (moved[index] ?? .zero) + (dragIndex == index ? dragTranslation : .zero)
                        pileTile(card, index: index)
                            .scaleEffect(dragIndex == index ? 1.08 : 1)
                            .position(clamped(CGPoint(x: base.x + extra.width, y: base.y + extra.height), in: geo.size))
                            .zIndex(dragIndex == index ? 1_000 : Double(shown.count - index))
                            .highPriorityGesture(drag(index, base: base, size: geo.size))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: height)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("objects.pile")
        }
    }

    private var gatherButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.25)) {
                gathered.toggle(); moved.removeAll()
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.body.weight(.semibold))
                .foregroundStyle(gathered ? CYColor.bgPage : CYColor.textPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(gathered ? CYColor.textPrimary : CYColor.bgSurface))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // MP aria-label: 聚成一团 / 让它们落下来.
        .accessibilityLabel(Text(gathered ? "objects.pile.drop" : "objects.pile.gatherOne"))
        .accessibilityIdentifier("objects.pile.gather")
    }

    private func pileTile(_ card: ObjectCard, index: Int) -> some View {
        Button { onSelect(index) } label: {
            BoundedMediaThumbnail(url: card.thumbnail) {
                RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(CYColor.bgRaised)
                    .overlay { Image(systemName: "shippingbox").foregroundStyle(CYColor.textTertiary) }
            }
            .frame(width: tile, height: tile)  // N-OCARDS (r10): untilted, no shadow
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: ObjectCardTitleOverrides.shared.title(for: card)))
        .accessibilityIdentifier("objects.card.\(card.id)")
    }

    private func drag(_ index: Int, base: CGPoint, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in dragIndex = index; dragTranslation = value.translation }
            .onEnded { value in
                let prior = moved[index] ?? .zero
                // Fling: carry part of the predicted travel, then keep the card inside the pile area.
                let fling: CGSize = reduceMotion ? .zero : (value.predictedEndTranslation - value.translation) * 0.35
                let target = clamped(CGPoint(x: base.x + prior.width + value.translation.width + fling.width,
                                             y: base.y + prior.height + value.translation.height + fling.height), in: size)
                moved[index] = prior + value.translation
                dragIndex = nil; dragTranslation = .zero
                withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.3)) {
                    moved[index] = CGSize(width: target.x - base.x, height: target.y - base.y)
                }
            }
    }

    /// Heap: columns across the ground line, newer cards on higher layers; gathered: a golden-angle ball in the middle.
    private func position(_ index: Int, count: Int, in size: CGSize) -> CGPoint {
        if gathered {
            let angle = Double(index) * 2.399963
            let radius = sqrt(Double(index)) * Double(tile) * 0.22
            return CGPoint(x: size.width / 2 + CGFloat(cos(angle) * radius), y: size.height / 2 + CGFloat(sin(angle) * radius))
        }
        let columns = max(1, Int((size.width - tile) / (tile * 0.62)))
        let order = count - 1 - index
        let column = (order * 7) % columns
        let layer = order / columns
        let step = columns > 1 ? (size.width - tile) / CGFloat(columns - 1) : 0
        let jitter = CGFloat((order * 37) % 17) - 8
        return CGPoint(x: tile / 2 + CGFloat(column) * step + jitter,
                       y: size.height - tile / 2 - CGFloat(layer) * tile * 0.55 - CGFloat((order * 13) % 9))
    }

    private func tilt(_ index: Int) -> Double { Double((index * 29) % 31) - 15 }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, tile / 2), max(tile / 2, size.width - tile / 2)),
                y: min(max(point.y, tile / 2), max(tile / 2, size.height - tile / 2)))
    }
}

private func + (lhs: CGSize, rhs: CGSize) -> CGSize { CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height) }
private func - (lhs: CGSize, rhs: CGSize) -> CGSize { CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height) }
private func * (lhs: CGSize, rhs: CGFloat) -> CGSize { CGSize(width: lhs.width * rhs, height: lhs.height * rhs) }
