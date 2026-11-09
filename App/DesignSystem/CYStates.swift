import SwiftUI

/// Icon + one line + one action. Domain-aware sibling of `CYEmptyStateView`/`CYErrorStateView`
/// (those keep their legacy callers). The action stays secondary unless the caller makes it the screen's one primary.
struct CYEmptyState: View {
    private let systemImage: String
    private let message: LocalizedStringKey
    private let tableName: String?
    private let detail: LocalizedStringKey?
    private let messageIdentifier: String?
    private let actionTitle: LocalizedStringKey?
    private let actionIdentifier: String?
    private let actionStyle: CYPillStyle
    private let action: (() -> Void)?
    @Environment(\.cyPalette) private var palette

    init(
        systemImage: String = "tray",
        _ message: LocalizedStringKey,
        tableName: String? = nil,
        detail: LocalizedStringKey? = nil,
        messageIdentifier: String? = nil,
        actionTitle: LocalizedStringKey? = nil,
        actionIdentifier: String? = nil,
        actionStyle: CYPillStyle = .secondary,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.message = message
        self.tableName = tableName
        self.detail = detail
        self.messageIdentifier = messageIdentifier
        self.actionTitle = actionTitle
        self.actionIdentifier = actionIdentifier
        self.actionStyle = actionStyle
        self.action = action
    }

    var body: some View {
        VStack(spacing: CYSpacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
            Text(message, tableName: tableName)
                .font(CYTypography.body)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .cyIdentifier(messageIdentifier)
            if let detail {
                Text(detail)
                    .font(CYTypography.body)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                CYPillButton(actionTitle, style: actionStyle, fullWidth: false, action: action)
                    .cyIdentifier(actionIdentifier)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.xxl)
        .padding(.horizontal, CYSpacing.xxl)
    }
}

private extension View {
    @ViewBuilder func cyIdentifier(_ identifier: String?) -> some View {
        if let identifier { accessibilityIdentifier(identifier) }
        else { self }
    }
}

struct CYErrorState: View {
    private let message: LocalizedStringKey
    private let retryTitle: LocalizedStringKey
    private let onRetry: () -> Void

    init(_ message: LocalizedStringKey = "Couldn't load this. Check your connection.", retryTitle: LocalizedStringKey = "Retry", onRetry: @escaping () -> Void) {
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    var body: some View {
        CYEmptyState(systemImage: "exclamationmark.triangle", message, actionTitle: retryTitle, action: onRetry)
    }
}

private struct CYStatesPreviewBody: View {
    var body: some View {
        VStack {
            CYEmptyState(systemImage: "ticket", "No tickets yet", actionTitle: "Browse quests", action: {})
            CYErrorState(onRetry: {})
            CYSkeleton().padding(CYSpacing.lg)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
    }
}
#Preview("States · player dark") { CYStatesPreviewBody().themeDomain(.player) }
#Preview("States · merchant light") { CYStatesPreviewBody().themeDomain(.merchant) }
