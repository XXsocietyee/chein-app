import SwiftUI

// MARK: - Shared loading / offline / toast chrome (UI-10)
// Revolut pattern: calm skeletons, a quiet inline offline banner, a short bottom toast.
// Colours come only from CYColor; both light (merchant) and dark (player) schemes are supported.

// MARK: 1. Skeleton block

/// Placeholder block with a quiet shimmer. The shimmer is disabled under Reduce Motion.
public struct CYSkeletonBlock: View {
    private let cornerRadius: CGFloat
    private let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    public init(height: CGFloat = 16, cornerRadius: CGFloat = CYRadius.xs) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(CYColor.skeletonBase)
            .frame(height: height)
            .opacity(isDimmed && !reduceMotion ? 0.55 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: 2. Loading state

/// Skeleton list shown while content loads. Announces one VoiceOver label instead of each block.
public struct CYLoadingStateView: View {
    private let rows: Int

    public init(rows: Int = 3) {
        self.rows = max(1, rows)
    }

    public var body: some View {
        VStack(spacing: CYSpacing.md) {
            ForEach(0..<rows, id: \.self) { _ in
                CYCard {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYSkeletonBlock(height: 18)
                            .frame(maxWidth: 200)
                        CYSkeletonBlock(height: 12)
                        CYSkeletonBlock(height: 12)
                            .frame(maxWidth: 140)
                    }
                }
            }
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("cy.state.loading"))
    }
}

// MARK: 3. Offline banner

/// Inline banner for "no connection". One optional retry action; text wraps at large Dynamic Type sizes.
public struct CYOfflineBanner: View {
    private let onRetry: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
    }

    public var body: some View {
        Group {
            if dynamicTypeSize >= .xxLarge {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    bannerLabel
                    retryButton
                }
            } else {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    bannerLabel
                    retryButton
                }
            }
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.xs)
        .background(CYColor.warningSoft)
        .accessibilityElement(children: .combine)
    }

    private var bannerLabel: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Image(systemName: "wifi.slash")
                .font(CYTypography.label)
                .foregroundStyle(CYColor.warningText)
                .accessibilityHidden(true)

            Text("cy.state.offline.title")
                .cyText(.bodyCompact)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var retryButton: some View {
        if let onRetry {
            Button(action: onRetry) {
                Text("cy.state.offline.retry")
                    .cyText(.label)
                    .foregroundStyle(CYColor.brand)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// Inline validation or recoverable section error banner (`dangerSoft` surface + `dangerText` icon + optional retry).
public struct CYInlineError: View {
    private let message: LocalizedStringKey?
    private let verbatim: String?
    private let retryTitle: LocalizedStringKey?
    private let onRetry: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        Group {
            if dynamicTypeSize >= .xxLarge {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    errorLabel
                    retryButton
                }
            } else {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    errorLabel
                    retryButton
                }
            }
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.md)
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.dangerSoft))
        .accessibilityElement(children: .combine)
    }

    private var errorLabel: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(CYTypography.label)
                .foregroundStyle(CYColor.dangerText)
                .accessibilityHidden(true)

            Group {
                if let verbatim {
                    Text(verbatim: verbatim)
                } else if let message {
                    Text(message)
                }
            }
            .cyText(.bodyCompact)
            .foregroundStyle(CYColor.dangerText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var retryButton: some View {
        if let retryTitle, let onRetry {
            Button(action: onRetry) {
                Text(retryTitle)
                    .cyText(.label, weight: .semibold)
                    .foregroundStyle(CYColor.dangerText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
        case .info: return CYColor.textPrimary
        case .success: return CYColor.successText
        case .warning: return CYColor.warningText
        case .undoable: return CYColor.infoText
        }
    }
}

/// Floating pill toast (`maxWidth: 300pt`, `10 × 16pt` padding, `modalPanel` fill + float shadow, zero outer border).
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
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(tone.iconColor)
                .accessibilityHidden(true)

            Group {
                if let verbatim {
                    Text(verbatim: verbatim)
                } else if let messageKey {
                    Text(messageKey)
                }
            }
            .cyText(.bodyCompact)
            .foregroundStyle(CYColor.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            if let undoTitle, let onUndo {
                Button(action: onUndo) {
                    Text(undoTitle)
                        .cyText(.label, weight: .bold)
                        .foregroundStyle(CYColor.infoText)
                        .padding(.horizontal, CYSpacing.xs)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.s2_5)
        .frame(maxWidth: 300)
        .background(Capsule(style: .continuous).fill(CYColor.modalPanel))
        .shadow(color: CYColor.floatShadowColor, radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct CYToastModifier: ViewModifier {
    @Binding var message: LocalizedStringKey?
    let tone: CYToastTone
    let undoTitle: LocalizedStringKey?
    let duration: Double
    let onUndo: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
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

    func body(content: Content) -> some View {
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

#Preview("Shared states - dark (player)") {
    VStack(spacing: CYSpacing.lg) {
        CYOfflineBanner(onRetry: {})
        CYLoadingStateView(rows: 2)
        Spacer()
    }
    .background(CYColor.bgPage)
    .preferredColorScheme(.dark)
}

#Preview("Shared states - light (merchant)") {
    VStack(spacing: CYSpacing.lg) {
        CYOfflineBanner(onRetry: {})
        CYLoadingStateView(rows: 2)
        Spacer()
    }
    .background(CYColor.bgPage)
    .preferredColorScheme(.light)
}
