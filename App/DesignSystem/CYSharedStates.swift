import SwiftUI

// MARK: - Shared loading / offline / toast chrome (UI-10)
// Revolut pattern: calm skeletons, a quiet inline offline banner, a short bottom toast.
// Colours come only from CYColor; both light (merchant) and dark (player) schemes are supported.

// MARK: 1. Skeleton block

/// Native r2: a system redacted placeholder line (`.redacted(reason: .placeholder)`), no shimmer of our own.
/// `height` picks the text style the placeholder stands in for; `cornerRadius` is kept for call sites only.
public struct CYSkeletonBlock: View {
    private let cornerRadius: CGFloat
    private let height: CGFloat

    public init(height: CGFloat = 16, cornerRadius: CGFloat = CYRadius.sm) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Text(verbatim: "Placeholder placeholder placeholder placeholder placeholder placeholder")
            .font(height >= 18 ? .headline : (height <= 12 ? .footnote : .body))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .redacted(reason: .placeholder)
            .accessibilityHidden(true)
    }
}

// MARK: 2. Loading state

/// Native r2: the system `ProgressView` with the MP `cy-empty kind="loading"` / `cy-loading-mask` words visible
/// (加载中… / Loading…), the one loading pattern on player screens. `rows` is kept for call sites.
public struct CYLoadingStateView: View {
    private let rows: Int
    private let label: LocalizedStringKey

    /// `label` is the page's own loading words (default 加载中…); they show on screen and VoiceOver reads them.
    public init(rows: Int = 3, label: LocalizedStringKey = "cy.state.loading") {
        self.rows = max(1, rows)
        self.label = label
    }

    public var body: some View {
        ProgressView {
            Text(label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.xxl)
    }
}

// MARK: 3. Offline banner

/// Native r2: a `Label(wifi.slash)` footnote plus a borderless retry. No tinted banner fill.
public struct CYOfflineBanner: View {
    private let onRetry: (() -> Void)?

    public init(onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: CYSpacing.md) {
                bannerLabel
                retryButton
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                bannerLabel
                retryButton
            }
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var bannerLabel: some View {
        Label {
            Text("cy.state.offline.title")
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: "wifi.slash")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var retryButton: some View {
        if let onRetry {
            Button(action: onRetry) {
                Text("cy.state.offline.retry")
            }
            .buttonStyle(.borderless)
            .font(.footnote)
        }
    }
}

/// Inline validation or recoverable section error banner (`dangerSoft` surface + `dangerText` icon + optional retry).
public struct CYInlineError: View {
    private let message: LocalizedStringKey?
    private let verbatim: String?
    private let retryTitle: LocalizedStringKey?
    private let onRetry: (() -> Void)?
    public init(
        _ message: LocalizedStringKey,
        retryTitle: LocalizedStringKey? = "cy.state.offline.retry",
        onRetry: (() -> Void)? = nil
    ) {
        self.message = message
        self.verbatim = nil
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    public init(
        verbatim message: String,
        retryTitle: LocalizedStringKey? = "cy.state.offline.retry",
        onRetry: (() -> Void)? = nil
    ) {
        self.message = nil
        self.verbatim = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: CYSpacing.md) {
                errorLabel
                retryButton
            }
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                errorLabel
                retryButton
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Native r2: a `Label(exclamationmark.circle)` footnote in the system red, no tinted box.
    private var errorLabel: some View {
        Label {
            Group {
                if let verbatim {
                    Text(verbatim: verbatim)
                } else if let message {
                    Text(message)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: "exclamationmark.circle")
        }
        .font(.footnote)
        .foregroundStyle(.red)
    }

    @ViewBuilder
    private var retryButton: some View {
        if let retryTitle, let onRetry {
            Button(action: onRetry) {
                Text(retryTitle)
            }
            .buttonStyle(.borderless)
            .font(.footnote)
        }
    }
}

// MARK: 4. Toast

public enum CYToastTone: Sendable, Hashable {
    case info
    case success
    case warning
    case undoable

    var systemImage: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .undoable: return "arrow.uturn.backward.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .info: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .undoable: return .accentColor
        }
    }
}

/// Floating pill toast (native r2: system secondary background, no shadow).
public struct CYToastPill: View {
    private let messageKey: LocalizedStringKey?
    private let verbatim: String?
    private let tone: CYToastTone
    private let undoTitle: LocalizedStringKey?
    private let onUndo: (() -> Void)?

    public init(
        _ message: LocalizedStringKey,
        tone: CYToastTone = .info,
        undoTitle: LocalizedStringKey? = nil,
        onUndo: (() -> Void)? = nil
    ) {
        self.messageKey = message
        self.verbatim = nil
        self.tone = tone
        self.undoTitle = undoTitle
        self.onUndo = onUndo
    }

    public init(
        verbatim message: String,
        tone: CYToastTone = .info,
        undoTitle: LocalizedStringKey? = nil,
        onUndo: (() -> Void)? = nil
    ) {
        self.messageKey = nil
        self.verbatim = message
        self.tone = tone
        self.undoTitle = undoTitle
        self.onUndo = onUndo
    }

    public var body: some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: tone.systemImage)
                .font(.callout)
                .foregroundStyle(tone.iconColor)
                .accessibilityHidden(true)

            Group {
                if let verbatim {
                    Text(verbatim: verbatim)
                } else if let messageKey {
                    Text(messageKey)
                }
            }
            .font(.subheadline)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            if let undoTitle, let onUndo {
                Button(action: onUndo) {
                    Text(undoTitle)
                }
                .buttonStyle(.borderless)
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.s2_5)
        .frame(maxWidth: 300)
        // Native r2: no Apple toast control exists; the closest is a plain secondary-background capsule
        // (no shadow, no blur), like the system "Copied" HUD.
        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Native r2 M4: with `nativeR2.island` on, every `cyToast` is a thin shim over `IslandCenter` (a `.status`
/// island at the top). The binding is handed to the island and cleared, exactly as the bottom pill cleared it.
/// Flag off: the bottom pill below, unchanged.
private struct CYToastModifier: ViewModifier {
    @Binding var message: LocalizedStringKey?
    let tone: CYToastTone
    let undoTitle: LocalizedStringKey?
    let duration: Double
    let onUndo: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if IslandCenter.isEnabled {
            content.onChange(of: message, initial: true) { _, next in
                guard let next else { return }
                CYToastIslandBridge.post(.localized(next), tone: tone, undoTitle: undoTitle, duration: duration, onUndo: onUndo)
                message = nil
            }
        } else {
            pill(content: content)
        }
    }

    private func pill(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                CYToastPill(message, tone: tone, undoTitle: undoTitle, onUndo: onUndo.map { action in
                    {
                        action()
                        self.message = nil
                    }
                })
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.bottom, CYSpacing.xxl)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .task(id: messageKeyId(message)) {
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        self.message = nil
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: message != nil)
    }

    private func messageKeyId(_ key: LocalizedStringKey) -> String {
        String(describing: key)
    }
}

private struct CYToastVerbatimModifier: ViewModifier {
    @Binding var message: String?
    let tone: CYToastTone
    let undoTitle: LocalizedStringKey?
    let duration: Double
    let onUndo: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if IslandCenter.isEnabled {
            content.onChange(of: message, initial: true) { _, next in
                guard let next else { return }
                CYToastIslandBridge.post(.verbatim(next), tone: tone, undoTitle: undoTitle, duration: duration, onUndo: onUndo)
                message = nil
            }
        } else {
            pill(content: content)
        }
    }

    private func pill(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                CYToastPill(verbatim: message, tone: tone, undoTitle: undoTitle, onUndo: onUndo.map { action in
                    {
                        action()
                        self.message = nil
                    }
                })
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.bottom, CYSpacing.xxl)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .task(id: message) {
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        self.message = nil
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: message != nil)
    }
}

public extension View {
    /// Shows a short bottom toast while `message` is non-nil, then clears it.
    func cyToast(message: Binding<LocalizedStringKey?>, duration: Double = 2.5) -> some View {
        modifier(CYToastModifier(message: message, tone: .info, undoTitle: nil, duration: duration, onUndo: nil))
    }

    /// Shows a toned floating pill toast with optional undo action.
    func cyToast(
        message: Binding<LocalizedStringKey?>,
        tone: CYToastTone = .info,
        undoTitle: LocalizedStringKey? = nil,
        duration: Double = 2.5,
        onUndo: (() -> Void)? = nil
    ) -> some View {
        modifier(CYToastModifier(message: message, tone: tone, undoTitle: undoTitle, duration: duration, onUndo: onUndo))
    }

    /// Shows a toned floating pill toast for an already localized runtime string.
    func cyToast(
        verbatimMessage: Binding<String?>,
        tone: CYToastTone = .info,
        undoTitle: LocalizedStringKey? = nil,
        duration: Double = 2.5,
        onUndo: (() -> Void)? = nil
    ) -> some View {
        modifier(CYToastVerbatimModifier(message: verbatimMessage, tone: tone, undoTitle: undoTitle, duration: duration, onUndo: onUndo))
    }
}

// MARK: - Empty illustration

/// Mini-program empty art. Generic is the `cy/empty` background plus figure (the tray slot).
/// Ticket and no-data are the other two shared empty illustrations.
struct CYEmptyIllustration: View {
    enum Kind { case generic, ticket, noData }

    var kind: Kind = .generic
    var size: CGFloat = 132

    var body: some View {
        ZStack {
            switch kind {
            case .generic:
                MPAsset.EmptyState.emptyStateBg
                    .resizable()
                    .scaledToFit()
                MPAsset.EmptyState.emptyStateFigure
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
            case .ticket:
                MPAsset.EmptyState.iconTicketEmpty
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
            case .noData:
                MPAsset.EmptyState.noData
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size * 1.2, height: size * 1.1)
        .accessibilityHidden(true)
    }

    /// Symbol → illustration. `nil` keeps the themed state art (search stays the magnifier).
    static func kind(matching symbol: String) -> Kind? {
        switch symbol {
        case "tray": return .generic
        case "sparkles": return .noData
        case "ticket", "ticket.fill": return .ticket
        default: return nil
        }
    }
}

// MARK: - Previews (synthetic, preview-only)

#Preview("Shared states") {
    VStack(spacing: CYSpacing.lg) {
        CYOfflineBanner(onRetry: {})
        CYLoadingStateView(rows: 2)
        Spacer()
    }
}
