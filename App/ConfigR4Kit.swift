import SwiftUI

// Screens r4 · config worker (ui/r4-config): the gameplay config editor, publish, template and external-game pages
// (Figma C2 `235:178`, C3 `235:13237`). Feature-local helpers shared by those screens. Copy lives in `ConfigR4`.

/// Localized text in the `ConfigR4` string table.
enum ConfigR4Text {
    static let table = "ConfigR4"
    static func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    static func string(_ key: String, locale: Locale) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(key), table: table, locale: locale))
    }
}

// MARK: - Undo (C2's one delete rule, shared with the gameplay editor)

private struct ConfigUndoCenterKey: EnvironmentKey {
    static let defaultValue: ProjectEditUndoCenter? = nil
}

extension EnvironmentValues {
    /// The page's undo center (C2 `ProjectEditUndoCenter`): a delete happens at once and leaves 已删除「X」 撤销 for 5 s,
    /// registered with the window's `UndoManager` too. nil outside a page that shows the toast.
    var configUndoCenter: ProjectEditUndoCenter? {
        get { self[ConfigUndoCenterKey.self] }
        set { self[ConfigUndoCenterKey.self] = newValue }
    }
}

// MARK: - Drag to reorder with the release velocity (CF-60, xrefs-1 "interruptible + velocity handoff")

/// The CF-60 drop spring as a physical spring (Figma prototype: stiffness 300, damping 26, mass 1), so the gesture's
/// release velocity can be handed to it. Reduce Motion: a 200 ms cross-fade-like ease, no velocity.
enum EditorDragReorderMotion {
    static let stiffness: Double = 300
    static let damping: Double = 26
    /// Lift: long-press 180 ms on the row (immediate under VoiceOver through the "⋯" / rotor actions instead).
    static let liftDelay: Double = 0.18
    static let liftScale: CGFloat = 1.03

    /// `initialVelocity` of `interpolatingSpring` is relative to the distance still to travel.
    static func settle(residual: CGFloat, releaseVelocity: CGFloat, reduceMotion: Bool) -> Animation {
        if reduceMotion { return CYMotion.reduced }
        let relative: Double = abs(residual) < 1 ? 0 : Double(-releaseVelocity / residual)
        return .interpolatingSpring(mass: 1, stiffness: stiffness, damping: damping,
                                    initialVelocity: min(max(relative, -20), 20))
    }

    /// Where the dragged row lands: the number of other rows whose midpoint is above the dragged row's midpoint.
    static func landingIndex(from: Int, translation: CGFloat, heights: [CGFloat], spacing: CGFloat) -> Int {
        guard heights.indices.contains(from) else { return from }
        let tops = layoutTops(heights, spacing: spacing)
        let center = tops[from] + heights[from] / 2 + translation
        var index = 0
        for other in heights.indices where other != from && tops[other] + heights[other] / 2 < center { index += 1 }
        return index
    }

    /// `onMove` destination for a row that lands at `landing` (its index after the move).
    static func destination(from: Int, landing: Int) -> Int { landing > from ? landing + 1 : landing }

    static func layoutTops(_ heights: [CGFloat], spacing: CGFloat) -> [CGFloat] {
        var tops: [CGFloat] = [], y: CGFloat = 0
        for height in heights { tops.append(y); y += height + spacing }
        return tops
    }
}

/// Drag-to-reorder for list editors that are not `List` rows (option rows, rule steps, cards in a page).
/// Long-press a row (180 ms) to lift it (1.03, float shadow, `.impact(.medium)`); neighbours slide out of the way on
/// `CYMotion.standard` and a 2 pt line marks the slot (`.selection` per slot change); on release the row settles into
/// its slot on the CF-60 spring **starting at the finger's release velocity**, so a flick lands with momentum and a
/// slow drop lands softly (`.impact(.light)`). A new drag retargets a row that is still settling. The "⋯" menu and
/// the VoiceOver rotor actions stay the non-drag way to reorder. Offsets are kept per position, so rows whose ids are
/// positional (A–D options) work as well as rows with stable ids.
struct EditorDragReorderStack<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var spacing: CGFloat = CYSpacing.sm
    var isEnabled: Bool = true
    /// `onMove` semantics: `to` is the index before which the row is inserted.
    let onMove: (_ from: Int, _ to: Int) -> Void
    @ViewBuilder let row: (Item, Int) -> Row

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var heights: [Int: CGFloat] = [:]
    @State private var dragging: Int?
    @State private var translation: CGFloat = 0
    @State private var landing: Int?
    @State private var settling: Int?
    @State private var settleOffset: CGFloat = 0
    @State private var drops = 0

    private var measured: [CGFloat] { items.indices.map { heights[$0] ?? 0 } }

    var body: some View {
        // Typed pieces: the one-expression form did not type-check in reasonable time (integ build).
        let enumerated: [(offset: Int, element: Item)] = Array(items.enumerated())
        let lifts: (Int?, Int?) -> Bool = { old, new in old == nil && new != nil }
        let moves: (Int?, Int?) -> Bool = { old, new in old != nil && new != nil }
        let motion: Animation = CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)
        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(enumerated, id: \.element.id) { pair in
                reorderRow(pair.element, pair.offset)
            }
        }
        .animation(motion, value: landing)
        .sensoryFeedback(.impact(weight: .medium), trigger: dragging, condition: lifts)
        .sensoryFeedback(.selection, trigger: landing, condition: moves)
        .sensoryFeedback(.impact(weight: .light), trigger: drops)
    }

    /// One row with its lift, shift, drop lines and gesture. Split out of `body` so the type checker stays fast
    /// (integ: "unable to type-check this expression in reasonable time"); behaviour unchanged.
    private func reorderRow(_ item: Item, _ index: Int) -> some View {
        let lifted = dragging == index
        let shift = offset(for: index)
        return row(item, index)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[index] = $0 }
            .scaleEffect(lifted && !reduceMotion ? EditorDragReorderMotion.liftScale : 1)
            .shadow(color: lifted ? palette.floatShadowColor : Color.clear, radius: 12, y: 8)
            .offset(y: shift)
            .zIndex(lifted || settling == index ? 1 : 0)
            .overlay(alignment: .top) { topDropLine(index, shift: shift) }
            .overlay(alignment: .bottom) { bottomDropLine(index, shift: shift) }
            .gesture(dragGesture(index), including: isEnabled ? .all : .subviews)
    }

    @ViewBuilder private func topDropLine(_ index: Int, shift: CGFloat) -> some View {
        if let dragging, let landing, landing != dragging, lineIndex(dragging: dragging, landing: landing) == index {
            EditorDropLine().offset(y: -(spacing / 2) - 1 + shift)
        }
    }

    @ViewBuilder private func bottomDropLine(_ index: Int, shift: CGFloat) -> some View {
        if let dragging, let landing, landing != dragging, landing == items.count - 1, index == items.count - 1 {
            EditorDropLine().offset(y: spacing / 2 + 1 + shift)
        }
    }

    /// The row whose top edge carries the insertion line for a landing slot.
    private func lineIndex(dragging: Int, landing: Int) -> Int? {
        if landing < dragging { return landing }
        if landing < items.count - 1 { return landing + 1 }
        return nil
    }

    private func offset(for index: Int) -> CGFloat {
        if index == settling { return settleOffset }
        guard let dragging else { return 0 }
        if index == dragging { return translation }
        guard let landing, measured.indices.contains(dragging) else { return 0 }
        let gap = measured[dragging] + spacing
        if dragging < index && index <= landing { return -gap }
        if landing <= index && index < dragging { return gap }
        return 0
    }

    private func dragGesture(_ index: Int) -> some Gesture {
        LongPressGesture(minimumDuration: EditorDragReorderMotion.liftDelay, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if dragging != index {
                    // Interruptible: a new lift retargets a row that is still settling; nothing queues.
                    settling = nil; settleOffset = 0
                    dragging = index; landing = index; translation = 0
                }
                guard let drag else { return }
                translation = drag.translation.height
                landing = EditorDragReorderMotion.landingIndex(from: index, translation: translation, heights: measured, spacing: spacing)
            }
            .onEnded { value in
                guard dragging == index else { return }
                var velocity: CGFloat = 0
                if case .second(true, let drag?) = value { velocity = drag.velocity.height }
                drop(from: index, velocity: velocity)
            }
    }

    private func drop(from index: Int, velocity: CGFloat) {
        let heights = measured
        let target = landing ?? index
        let tops = EditorDragReorderMotion.layoutTops(heights, spacing: spacing)
        var moved = heights
        if target != index, heights.indices.contains(index) {
            EditorReorder.move(&moved, fromOffsets: IndexSet(integer: index), toOffset: EditorDragReorderMotion.destination(from: index, landing: target))
        }
        let newTops = EditorDragReorderMotion.layoutTops(moved, spacing: spacing)
        let drawnTop = (tops.indices.contains(index) ? tops[index] : 0) + translation
        let residual = drawnTop - (newTops.indices.contains(target) ? newTops[target] : drawnTop)
        var instant = Transaction(); instant.disablesAnimations = true
        withTransaction(instant) {
            if target != index { onMove(index, EditorDragReorderMotion.destination(from: index, landing: target)) }
            dragging = nil; landing = nil; translation = 0
            settling = target; settleOffset = residual
        }
        if target != index { drops += 1 }
        // Next turn: the moved row is now laid out in its slot, drawn at the release point. Settle with momentum.
        let animation = EditorDragReorderMotion.settle(residual: residual, releaseVelocity: velocity, reduceMotion: reduceMotion)
        Task { @MainActor in
            await Task.yield()
            guard settling == target, dragging == nil else { return }
            withAnimation(animation) { settleOffset = 0 }
        }
    }
}
