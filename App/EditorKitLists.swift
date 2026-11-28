import SwiftUI

// Design hand-off r1 · Editor/List Item, Editor/Handle, Editor/Add Row, Editor/Answer Option and the
// drag-to-reorder spec (CF-33, CF-46, CF-60, CF-68).

/// Trailing "⋯" pull-down for a list item: 上移, 下移, 复制, 删除 (red, last). Disabled moves stay visible
/// (HIG Menus: show unavailable items). This is also the non-drag way to reorder (CF-60).
struct EditorRowActionsMenu: View {
    let index: Int
    let count: Int
    var actions: [EditorRowAction] = [.moveUp, .moveDown, .delete]
    var deleteTitle: Text? = nil
    var menuID: String? = nil
    var deleteID: String? = nil
    let onAction: (EditorRowAction) -> Void

    @Environment(\.cyPalette) private var palette

    var body: some View {
        Menu {
            ForEach(actions.filter { !$0.isDestructive }, id: \.self) { action in
                Button { onAction(action) } label: { Label { title(action) } icon: { Image(systemName: symbol(action)) } }
                    .disabled(!isAvailable(action))
            }
            if actions.contains(.delete) {
                Divider()
                Button(role: .destructive) { onAction(.delete) } label: {
                    Label { deleteTitle ?? title(.delete) } icon: { Image(systemName: "trash") }
                }
                .modifier(EditorOptionalIdentifier(identifier: deleteID))
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
                .editorHitTarget()
        }
        .accessibilityLabel(EditorKitText.text("editorKit.more"))
        .accessibilityIdentifier(menuID ?? "editorKit.rowMenu.\(index)")
    }

    private func isAvailable(_ action: EditorRowAction) -> Bool {
        switch action {
        case .moveUp: return EditorReorder.canMoveUp(index: index, count: count)
        case .moveDown: return EditorReorder.canMoveDown(index: index, count: count)
        case .duplicate, .delete: return true
        }
    }

    private func title(_ action: EditorRowAction) -> Text { EditorKitText.text("editorKit.action." + action.rawValue) }

    private func symbol(_ action: EditorRowAction) -> String {
        switch action {
        case .moveUp: return "arrow.up"
        case .moveDown: return "arrow.down"
        case .duplicate: return "plus.square.on.square"
        case .delete: return "trash"
        }
    }
}

/// `Editor/Handle`: ≡ glyph, always trailing, 44 × 44 hit area. VoiceOver: `调整顺序`.
struct EditorDragHandle: View {
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.body.weight(.semibold))
            .foregroundStyle(palette.textTertiary)
            .editorHitTarget()
            .accessibilityLabel(EditorKitText.text("editorKit.handle"))
    }
}

/// `Editor/List Item` header: title · meta · "⋯" · trailing handle.
struct EditorListItemHeader: View {
    let title: Text
    var meta: Text? = nil
    let index: Int
    let count: Int
    var actions: [EditorRowAction] = [.moveUp, .moveDown, .delete]
    var showsHandle: Bool = true
    let onAction: (EditorRowAction) -> Void

    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(spacing: CYSpacing.xs) {
            title.cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: CYSpacing.sm)
            if let meta { meta.cyText(.meta).foregroundStyle(palette.textTertiary) }
            EditorRowActionsMenu(index: index, count: count, actions: actions, onAction: onAction)
            if showsHandle { EditorDragHandle() }
        }
        .frame(minHeight: EditorKitMetric.hit)
        .editorReorderAccessibility(index: index, count: count, onAction: onAction)
    }
}

extension View {
    /// CF-60 / CF-68: VoiceOver reorder actions that mirror the "⋯" menu.
    func editorReorderAccessibility(index: Int, count: Int, onAction: @escaping (EditorRowAction) -> Void) -> some View {
        self
            .accessibilityAction(named: EditorKitText.text("editorKit.action.moveUp")) {
                if EditorReorder.canMoveUp(index: index, count: count) { onAction(.moveUp) }
            }
            .accessibilityAction(named: EditorKitText.text("editorKit.action.moveDown")) {
                if EditorReorder.canMoveDown(index: index, count: count) { onAction(.moveDown) }
            }
    }
}

/// `Editor/Add Row`: one dashed row, 44 high, at the end of its list. At the limit it greys out and shows
/// the count (`12/12`) instead of a toast (CF-16).
struct EditorAddRow: View {
    let title: Text
    var count: Int? = nil
    var limit: Int? = nil
    var accessibilityID: String? = nil
    let action: () -> Void

    @Environment(\.cyPalette) private var palette

    private var atLimit: Bool {
        guard let count, let limit else { return false }
        return count >= limit
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.s1_5) {
                Image(systemName: "plus").font(.body.weight(.semibold)).accessibilityHidden(true)
                title.cyText(.cardTitle)
                if let count, let limit {
                    Text(verbatim: "\(count)/\(limit)").accessibilityLabel(Text("a11y.value.ofTotal \(Int(count)) \(Int(limit))")).cyText(.meta, monospacedDigit: true).foregroundStyle(palette.textTertiary)
                }
            }
            .foregroundStyle(atLimit ? palette.textDisabled : palette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: EditorKitMetric.hit)
            .overlay(
                RoundedRectangle(cornerRadius: EditorKitMetric.fieldRadius, style: .continuous)
                    .strokeBorder(palette.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(atLimit)
        .sensoryFeedback(.impact(weight: .light), trigger: count ?? 0) { old, new in new > old }
        .modifier(EditorOptionalIdentifier(identifier: accessibilityID))
    }
}

/// CF-60 insertion line: 2 pt, shows the landing slot while dragging.
struct EditorDropLine: View {
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Capsule().fill(palette.textPrimary).frame(height: 2).accessibilityHidden(true)
    }
}

/// Drag-to-reorder for list editors that are not `List` rows (story-flow blocks, option rows, steps).
/// Rows lift on drag (system drag preview), a 2 pt line marks the landing slot, the drop settles with the
/// CF-60 spring, and the "⋯" menu plus VoiceOver actions remain the non-drag alternative.
/// Inside a `List` / `Form`, prefer `ForEach(...).onMove`, which gives the same lift and insertion.
struct EditorReorderableStack<Item: Identifiable, Row: View>: View {
    let items: [Item]
    let key: (Item) -> String
    let onMove: (IndexSet, Int) -> Void
    var spacing: CGFloat = CYSpacing.sm
    var isEnabled: Bool = true
    @ViewBuilder let row: (Item, Int) -> Row

    @State private var targetKey: String?
    @State private var drops = 0
    @QuestifyReduceMotion private var reduceMotion
    private static var endKey: String { "editorKit.reorder.end" }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let itemKey = key(item)
                row(item, index)
                    .overlay(alignment: .top) {
                        if targetKey == itemKey { EditorDropLine().offset(y: -(spacing / 2) - 1) }
                    }
                    .modifier(EditorReorderDrag(
                        isEnabled: isEnabled,
                        payload: itemKey,
                        onDrop: { dropped in move(dropped, before: index) },
                        onTarget: { targeted in updateTarget(itemKey, targeted) }
                    ))
            }
            Color.clear
                .frame(height: CYSpacing.md)
                .overlay(alignment: .top) { if targetKey == Self.endKey { EditorDropLine() } }
                .modifier(EditorReorderDrag(
                    isEnabled: isEnabled, payload: nil,
                    onDrop: { dropped in move(dropped, before: items.count) },
                    onTarget: { targeted in updateTarget(Self.endKey, targeted) }
                ))
        }
        .animation(EditorKitMotion.move(reduceMotion: reduceMotion), value: items.map(key))
        .sensoryFeedback(.selection, trigger: targetKey) { _, new in new != nil }
        .sensoryFeedback(.impact(weight: .light), trigger: drops)
    }

    private func updateTarget(_ itemKey: String, _ targeted: Bool) {
        if targeted { targetKey = itemKey } else if targetKey == itemKey { targetKey = nil }
    }

    private func move(_ dropped: [String], before destination: Int) -> Bool {
        targetKey = nil
        guard isEnabled, let source = dropped.first, let from = items.firstIndex(where: { key($0) == source }) else { return false }
        guard destination != from, destination != from + 1 else { return false }
        withAnimation(EditorKitMotion.drop(reduceMotion: reduceMotion)) { onMove(IndexSet(integer: from), destination) }
        drops += 1
        return true
    }
}

private struct EditorReorderDrag: ViewModifier {
    let isEnabled: Bool
    let payload: String?
    let onDrop: ([String]) -> Bool
    let onTarget: (Bool) -> Void

    @ViewBuilder func body(content: Content) -> some View {
        if isEnabled {
            if let payload {
                content
                    .draggable(payload)
                    .dropDestination(for: String.self) { items, _ in onDrop(items) } isTargeted: { onTarget($0) }
            } else {
                content.dropDestination(for: String.self) { items, _ in onDrop(items) } isTargeted: { onTarget($0) }
            }
        } else {
            content
        }
    }
}

/// `Editor/Answer Option` kind (CF-46).
enum EditorAnswerKind: Sendable {
    /// One correct answer: a circle.
    case single
    /// Several correct answers: a rounded square.
    case multi
    /// 问卷: no correct answer; the control is hidden.
    case survey
}

/// `Editor/Answer Option`: one 52 pt row — the correct-answer control in front, the text, an optional
/// 36 pt thumbnail, the "⋯" and the handle. Only the option being edited expands (CF-46).
struct EditorAnswerOptionRow<Expanded: View>: View {
    let kind: EditorAnswerKind
    let letter: String
    @Binding var text: String
    let isCorrect: Bool
    var thumbnail: Image? = nil
    var isExpanded: Bool = false
    var error: Text? = nil
    let index: Int
    let count: Int
    var accessibilityID: String? = nil
    let onToggleCorrect: () -> Void
    let onAction: (EditorRowAction) -> Void
    var onExpand: () -> Void = {}
    @ViewBuilder var expanded: () -> Expanded

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.xs) {
                if kind != .survey { correctControl }
                TextField(text: $text) { Text(verbatim: letter) }
                    .cyText(.body)
                    .foregroundStyle(palette.textPrimary)
                    .submitLabel(.next)
                    .onTapGesture { onExpand() }
                    .modifier(EditorOptionalIdentifier(identifier: accessibilityID))
                if let thumbnail {
                    thumbnail.resizable().scaledToFill()
                        .frame(width: EditorKitMetric.optionThumb, height: EditorKitMetric.optionThumb)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
                        .accessibilityHidden(true)
                }
                EditorRowActionsMenu(index: index, count: count, onAction: onAction)
                EditorDragHandle()
            }
            .padding(.leading, kind == .survey ? EditorKitMetric.fieldPaddingX : 0)
            .frame(minHeight: EditorKitMetric.optionRowHeight)
            .background(RoundedRectangle(cornerRadius: EditorKitMetric.fieldRadius, style: .continuous).fill(palette.inputFilledBg))
            .overlay(
                RoundedRectangle(cornerRadius: EditorKitMetric.fieldRadius, style: .continuous)
                    .strokeBorder(error == nil ? Color.clear : palette.danger, lineWidth: error == nil ? 0 : EditorKitMetric.selectedBorder)
            )
            if let error { EditorFieldFootnote(error: error) }
            if isExpanded {
                expanded()
                    .padding(.leading, CYSpacing.md)
                    .transition(.opacity)
            }
        }
        .animation(EditorKitMotion.reveal(reduceMotion: reduceMotion), value: isExpanded)
        .editorReorderAccessibility(index: index, count: count, onAction: onAction)
    }

    private var correctControl: some View {
        Button(action: onToggleCorrect) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(isCorrect ? palette.textPrimary : palette.borderStrong)
                .scaleEffect(isCorrect || reduceMotion ? 1 : 0.92)
                .contentTransition(.symbolEffect(.replace))
                .editorHitTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(EditorKitText.text("editorKit.answer.correct"))
        .accessibilityValue(EditorKitText.text(isCorrect ? "editorKit.answer.selected" : "editorKit.answer.notSelected"))
        .accessibilityAddTraits(isCorrect ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: isCorrect)
    }

    private var symbol: String {
        switch kind {
        case .single: return isCorrect ? "checkmark.circle.fill" : "circle"
        case .multi: return isCorrect ? "checkmark.square.fill" : "square"
        case .survey: return "circle"
        }
    }
}

extension EditorAnswerOptionRow where Expanded == EmptyView {
    init(kind: EditorAnswerKind, letter: String, text: Binding<String>, isCorrect: Bool, error: Text? = nil,
         index: Int, count: Int, accessibilityID: String? = nil,
         onToggleCorrect: @escaping () -> Void, onAction: @escaping (EditorRowAction) -> Void) {
        self.kind = kind; self.letter = letter; self._text = text; self.isCorrect = isCorrect; self.error = error
        self.index = index; self.count = count; self.accessibilityID = accessibilityID
        self.onToggleCorrect = onToggleCorrect; self.onAction = onAction
        self.expanded = { EmptyView() }
    }
}
