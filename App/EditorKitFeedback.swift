import SwiftUI

// Design hand-off r1 · Editor/Toast, Editor/Tool Chip + Editor/Popover, Editor/Result,
// Editor/Confirm Dialog and Editor/State (CF-16, CF-18, CF-25, CF-41, CF-52, CF-53, CF-70, CF-77, CF-78).

/// `Editor/Toast` icon.
enum EditorToastIcon: Sendable {
    case none, success, info
    var symbol: String? {
        switch self {
        case .none: return nil
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

/// One toast: dark pill on light pages (light on dark, via ink tokens), optional icon, bottom-anchored
/// 12 above the bottom bar, 2 s, max width 329, wraps to two lines. Only for results of an action
/// elsewhere, never for validation or limits (CF-16).
struct EditorToast: View {
    let message: String
    var icon: EditorToastIcon = .none
    var undoTitle: Text? = nil
    var onUndo: (() -> Void)? = nil
    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            if let symbol = icon.symbol { Image(systemName: symbol).accessibilityHidden(true) }
            Text(verbatim: message).cyText(.bodyMedium).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            if let onUndo {
                Button(action: onUndo) { undoTitle ?? EditorKitText.text("editorKit.undo") }
                    .fontWeight(.semibold)
                    .buttonStyle(.borderless)
                    .editorHitTarget()
                    .accessibilityIdentifier("editorKit.toast.undo")
            }
        }
        // native-a r3: a system HUD capsule (regular material, primary label, accent Undo) instead of an inverted
        // black/white pill; reads in Light and Dark without our own colours.
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, 11)
        .frame(maxWidth: EditorKitMetric.toastMaxWidth)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("editorKit.toast")
    }
}

/// A toast request. Equality is by id so the same text twice still shows twice.
struct EditorToastRequest: Equatable, Identifiable {
    let id = UUID()
    let message: String
    var icon: EditorToastIcon = .none
    var undoTitle: Text? = nil
    var onUndo: (() -> Void)? = nil
    static func == (lhs: EditorToastRequest, rhs: EditorToastRequest) -> Bool { lhs.id == rhs.id }
}

private struct EditorToastModifier: ViewModifier {
    @Binding var request: EditorToastRequest?
    var bottomInset: CGFloat
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let request {
                let undo: (() -> Void)? = request.onUndo == nil ? nil : { request.onUndo?(); self.request = nil }
                EditorToast(message: request.message, icon: request.icon, undoTitle: request.undoTitle, onUndo: undo)
                .padding(.horizontal, CYSpacing.lg)
                .padding(.bottom, bottomInset + EditorKitMetric.toastBottomGap)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .task(id: request.id) {
                    try? await Task.sleep(nanoseconds: UInt64(EditorMotionSpec.toastSeconds * (request.onUndo == nil ? 1 : 2.5) * 1_000_000_000))
                    if self.request?.id == request.id { self.request = nil }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: EditorMotionSpec.revealSeconds), value: request)
    }
}

extension View {
    /// Shows `Editor/Toast` while `request` is non-nil. `bottomInset` is the height of the bottom bar.
    func editorToast(_ request: Binding<EditorToastRequest?>, bottomInset: CGFloat = 0) -> some View {
        modifier(EditorToastModifier(request: request, bottomInset: bottomInset))
    }

    /// CF-25 / CF-77 / CF-78: an action sheet anchored to the trigger, destructive choice in red.
    func editorConfirm(
        _ title: Text,
        isPresented: Binding<Bool>,
        message: Text? = nil,
        actionTitle: Text,
        isDestructive: Bool = true,
        secondaryTitle: Text? = nil,
        secondaryAction: (() -> Void)? = nil,
        cancelTitle: Text? = nil,
        action: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button(role: isDestructive ? .destructive : nil, action: action) { actionTitle }
            if let secondaryTitle, let secondaryAction {
                Button(action: secondaryAction) { secondaryTitle }
            }
            Button(role: .cancel) {} label: { cancelTitle ?? EditorKitText.text("editorKit.cancel") }
        } message: {
            if let message { message }
        }
    }
}

/// `Editor/Tool Chip` state (CF-53).
enum EditorToolChipState: Sendable { case available, added, blocked }

/// Tool chip: incompatible tools look unavailable before the tap; tapping a blocked chip shows a popover
/// anchored to it with the reason and the fix. Haptic `.warning` on a blocked tap.
struct EditorToolChip: View {
    let title: Text
    let state: EditorToolChipState
    var reason: Text? = nil
    var fix: Text? = nil
    var accessibilityID: String? = nil
    let action: () -> Void

    @Environment(\.cyPalette) private var palette
    @State private var showsReason = false
    @State private var blockedTaps = 0

    /// native-a r3: a system capsule button. Added = `.borderedProminent`, available = `.bordered`; a blocked chip
    /// stays tappable (it explains itself in the popover) but reads unavailable through the secondary label colour.
    var body: some View {
        Group {
            if state == .added {
                chipButton.buttonStyle(.borderedProminent)
            } else {
                chipButton.buttonStyle(.bordered)
            }
        }
        .buttonBorderShape(.capsule)
        .accessibilityValue(EditorKitText.text("editorKit.tool." + stateKey))
        .modifier(EditorOptionalIdentifier(identifier: accessibilityID))
        .sensoryFeedback(.warning, trigger: blockedTaps)
        .popover(isPresented: $showsReason, attachmentAnchor: .rect(.bounds)) {
            EditorPopoverContent(title: title, message: reason, action: fix)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var chipButton: some View {
        Button {
            if state == .blocked { showsReason = true; blockedTaps += 1 } else { action() }
        } label: {
            if state == .blocked {
                chipLabel.foregroundStyle(.secondary)
            } else {
                chipLabel
            }
        }
    }

    private var chipLabel: some View {
        Label { title } icon: { Image(systemName: icon) }
    }

    private var icon: String {
        switch state {
        case .available: return "plus"
        case .added: return "checkmark"
        case .blocked: return "link"
        }
    }

    private var stateKey: String {
        switch state {
        case .available: return "available"
        case .added: return "added"
        case .blocked: return "blocked"
        }
    }
}

/// `Editor/Popover`: title, one line of reason, the fix.
struct EditorPopoverContent: View {
    let title: Text
    var message: Text? = nil
    var action: Text? = nil
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            title.cyText(.bodyMedium).foregroundStyle(palette.textPrimary)
            if let message { message.cyText(.bodyCompact).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true) }
            if let action { action.cyText(.bodyMedium).foregroundStyle(palette.textPrimary) }
        }
        .padding(CYSpacing.md)
        .frame(maxWidth: 280, alignment: .leading)
    }
}
