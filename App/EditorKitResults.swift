import SwiftUI

// Design hand-off r1 · Editor/Result (CF-41, CF-52), Editor/State (CF-18, CF-70), Editor/Seam (CF-23)
// and the 选择玩法 grid (CF-51).

/// `Editor/Result` state.
enum EditorResultState: Sendable {
    case success, pending, failed, unknown

    var symbol: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

/// One result sheet: icon, title (the object's state), one line of what happens next, one primary and one
/// secondary. No ✕: it ends with buttons (CF-41, CF-52). Creation tone is restrained: the icon scales
/// .8 → 1 once; haptic `.success` / `.error`.
struct EditorResultContent: View {
    let state: EditorResultState
    let title: Text
    var message: Text? = nil
    let primaryTitle: Text
    var secondaryTitle: Text? = nil
    var primaryID: String? = nil
    var secondaryID: String? = nil
    let primary: () -> Void
    var secondary: (() -> Void)? = nil

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: CYSpacing.md) {
            Image(systemName: state.symbol)
                .font(.largeTitle)
                .foregroundStyle(iconColour)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.8)
                .accessibilityHidden(true)
            title.cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let message {
                message.font(.subheadline).foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: CYSpacing.sm) {
                Button(action: primary) { primaryTitle.frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .modifier(EditorOptionalIdentifier(identifier: primaryID))
                if let secondaryTitle, let secondary {
                    Button(action: secondary) { secondaryTitle.frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .modifier(EditorOptionalIdentifier(identifier: secondaryID))
                }
            }
            .padding(.top, CYSpacing.sm)
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.top, CYSpacing.xxl)
        .padding(.bottom, CYSpacing.lg)
        .frame(maxWidth: .infinity)
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: EditorMotionSpec.revealSeconds)) { appeared = true } }
        .sensoryFeedback(state == .failed ? SensoryFeedback.error : SensoryFeedback.success, trigger: appeared && state != .unknown, condition: CYHapticTransition.turnedOn)
        .interactiveDismissDisabled(false)
    }

    private var iconColour: Color {
        switch state {
        case .success: return palette.success
        case .pending: return palette.textPrimary
        case .failed: return palette.danger
        case .unknown: return palette.textSecondary
        }
    }
}

/// `Editor/State` kind (CF-18).
enum EditorStateKind: Sendable {
    case loading, empty, error, signedOut, noPermission
    var symbol: String {
        switch self {
        case .loading: return "hourglass"
        case .empty: return "doc"
        case .error: return "wifi.exclamationmark"
        case .signedOut: return "person.crop.circle"
        case .noPermission: return "lock"
        }
    }
}

/// Page and sheet states: loading = skeleton that mirrors the final layout (no scrim, no card);
/// the others = 64 pt icon tile, title, body, one button (CF-18). Failure copy uses the handbook wording:
/// `<对象>没加载出来` / `网络没连上，请重试` / `重试` (CF-70, owner default Q-E).
struct EditorStateView: View {
    let kind: EditorStateKind
    var title: Text? = nil
    var message: Text? = nil
    var actionTitle: Text? = nil
    var skeletonRows: Int = 4
    var accessibilityID: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.cyPalette) private var palette

    var body: some View {
        Group {
            if kind == .loading {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    ForEach(0..<max(1, skeletonRows), id: \.self) { index in
                        RoundedRectangle(cornerRadius: index % 3 == 0 ? EditorKitMetric.cardRadius : 7, style: .continuous)
                            .fill(palette.skeletonBase)
                            .frame(maxWidth: index % 3 == 2 ? 200 : .infinity)
                            .frame(height: index % 3 == 0 ? 88 : 14)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(EditorKitText.text("editorKit.state.loading"))
            } else {
                // native-a r3: the system empty/error state (icon, title, description, one action) instead of a
                // hand-drawn icon tile + text stack; same copy and the same single action.
                ContentUnavailableView {
                    Label { title ?? defaultTitle } icon: { Image(systemName: kind.symbol) }
                } description: {
                    if let text = message ?? defaultMessage { text }
                } actions: {
                    if let action {
                        Button(action: action) { actionTitle ?? defaultAction }
                            .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .modifier(EditorOptionalIdentifier(identifier: accessibilityID))
    }

    private var defaultTitle: Text {
        switch kind {
        case .loading: return EditorKitText.text("editorKit.state.loading")
        case .empty: return EditorKitText.text("editorKit.state.empty.title")
        case .error: return EditorKitText.text("editorKit.state.error.title")
        case .signedOut: return EditorKitText.text("editorKit.state.signedOut.title")
        case .noPermission: return EditorKitText.text("editorKit.state.noPermission.title")
        }
    }

    private var defaultMessage: Text? {
        switch kind {
        case .loading: return nil
        case .empty: return EditorKitText.text("editorKit.state.empty.message")
        case .error: return EditorKitText.text("editorKit.state.error.message")
        case .signedOut: return EditorKitText.text("editorKit.state.signedOut.message")
        case .noPermission: return EditorKitText.text("editorKit.state.noPermission.message")
        }
    }

    private var defaultAction: Text {
        switch kind {
        case .error: return EditorKitText.text("editorKit.retry")
        case .signedOut: return EditorKitText.text("editorKit.state.signedOut.action")
        case .noPermission: return EditorKitText.text("editorKit.state.noPermission.action")
        case .loading, .empty: return EditorKitText.text("editorKit.add")
        }
    }
}

/// `Story/Seam`: a 44 pt-high insert row with a hairline and a 28 pt "＋" circle (CF-23). VoiceOver: `在这里插入`.
struct EditorInsertSeam: View {
    var isExpanded: Bool = false
    var accessibilityID: String? = nil
    let action: () -> Void
    @Environment(\.cyPalette) private var palette

    var body: some View {
        Button(action: action) {
            ZStack {
                Divider()
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: EditorKitMetric.seamCircle, height: EditorKitMetric.seamCircle)
                    .background(Circle().fill(palette.bgElevated))
                    .overlay(Circle().strokeBorder(palette.borderStrong, lineWidth: 1))
            }
            .frame(maxWidth: .infinity, minHeight: EditorKitMetric.hit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(EditorKitText.text("editorKit.seam.insert"))
        .modifier(EditorOptionalIdentifier(identifier: accessibilityID))
        .sensoryFeedback(.selection, trigger: isExpanded)
    }
}

/// One entry of the 选择玩法 grid (CF-51).
struct EditorGameplayChoice: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String?
    let systemImage: String
    let category: String?
    /// nil when available; otherwise why it is off, shown on its row and in the footer (MP `g.reason`).
    let unavailableReason: String?
}

/// 选择玩法 (MP `publish/temp/index.wxml:1656-1680`, `temp/r5-editor.js:191-198`): one row of category tabs that only
/// scrolls sideways (no 全部; the sheet opens on the category that holds the current pick), under it the rows of that
/// category only (icon · name · description or the reason it is off · check), and a footer with the picked name and
/// its description, or 选一个玩法 before a pick, plus 试看. A row that is off stays in place, dimmed, with its reason.
struct EditorGameplayPickerGrid: View {
    let choices: [EditorGameplayChoice]
    @Binding var selection: String?
    var onPreview: ((EditorGameplayChoice) -> Void)? = nil

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var category: String?
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 36

    private var categories: [String] {
        var seen: [String] = []
        for choice in choices { if let value = choice.category, !seen.contains(value) { seen.append(value) } }
        return seen
    }
    /// MP `openR5GameSheet`: the group of the current pick, else the first group.
    private var shownCategory: String? {
        if let category { return category }
        if let picked, let value = picked.category { return value }
        return categories.first
    }
    private var visible: [EditorGameplayChoice] {
        guard let shownCategory, categories.count > 1 else { return choices }
        return choices.filter { $0.category == shownCategory }
    }
    private var picked: EditorGameplayChoice? { choices.first { $0.id == selection } }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if categories.count > 1 { categoryTabs }
            VStack(spacing: 0) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, choice in
                    if index > 0 { Divider().padding(.leading, iconSide + CYSpacing.md) }
                    row(choice)
                }
            }
            .editorCardSurface(padding: CYSpacing.md)
            .animation(reduceMotion ? nil : .easeInOut(duration: EditorMotionSpec.collapseSeconds), value: shownCategory)
            .accessibilityIdentifier("editorKit.gameplay.list")
            footer
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CYSpacing.sm) {
                ForEach(categories, id: \.self) { value in tab(value) }
            }
        }
        .accessibilityIdentifier("editorKit.gameplay.tabs")
    }

    /// Category tabs are system capsule buttons (`.borderedProminent` when shown, `.bordered` otherwise).
    @ViewBuilder
    private func tab(_ value: String) -> some View {
        let isOn = shownCategory == value
        Group {
            if isOn {
                Button { category = value } label: { Text(verbatim: value) }.buttonStyle(.borderedProminent)
            } else {
                Button { category = value } label: { Text(verbatim: value) }.buttonStyle(.bordered)
            }
        }
        .buttonBorderShape(.capsule)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: isOn, condition: CYHapticTransition.isOn)
    }

    private func row(_ choice: EditorGameplayChoice) -> some View {
        let isSelected = selection == choice.id
        let isOff = choice.unavailableReason != nil
        return Button { selection = choice.id } label: {
            HStack(alignment: .center, spacing: CYSpacing.md) {
                Image(systemName: choice.systemImage)
                    .font(.body)
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: iconSide, height: iconSide)
                    .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(palette.inputFilledBg))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: choice.title).cyText(.bodyMedium).foregroundStyle(palette.textPrimary)
                    if let sub = choice.unavailableReason ?? choice.summary {
                        Text(verbatim: sub).cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: CYSpacing.sm)
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.brand)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, CYSpacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(isOff ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: choice.title))
        .accessibilityHint(Text(verbatim: EditorUnknown.display(choice.unavailableReason ?? choice.summary)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("editorKit.gameplay.tile." + choice.id)
        .sensoryFeedback(.selection, trigger: isSelected, condition: CYHapticTransition.isOn)
    }

    /// MP `cg-tsheet__foot`: picked name + description (or its reason), else 选一个玩法; 预览 beside it.
    private var footer: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                if let picked {
                    Text(verbatim: picked.title).cyText(.bodyMedium).foregroundStyle(palette.textPrimary)
                    Text(verbatim: EditorUnknown.display(picked.unavailableReason ?? picked.summary))
                        .cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    EditorKitText.text("editorKit.gameplay.pickOne")
                        .cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            if let picked, let onPreview {
                Button { onPreview(picked) } label: { EditorKitText.text("editorKit.gameplay.tryPreview") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("editorKit.gameplay.tryPreview")
            }
        }
        .editorCardSurface(padding: CYSpacing.md)
        .accessibilityIdentifier("editorKit.gameplay.footer")
    }
}
