import SwiftUI

/// Icon + one line + one action. Domain-aware sibling of `CYEmptyStateView`/`CYErrorStateView`
/// (those keep their legacy callers). Action is a tertiary-weight pill to respect "one primary per screen".
struct CYEmptyState: View {
    private let systemImage: String
    private let message: LocalizedStringKey
    private let tableName: String?
    private let messageIdentifier: String?
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?
    @Environment(\.cyPalette) private var palette

    init(systemImage: String = "tray", _ message: LocalizedStringKey, tableName: String? = nil, messageIdentifier: String? = nil, actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil) {
        self.systemImage = systemImage
        self.message = message
        self.tableName = tableName
        self.messageIdentifier = messageIdentifier
        self.actionTitle = actionTitle
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
                .modifier(CYOptionalIdentifier(messageIdentifier))
            if let actionTitle, let action {
                CYPillButton(actionTitle, style: .secondary, fullWidth: false, action: action)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.xxl)
        .padding(.horizontal, CYSpacing.xxl)
    }
}

private struct CYOptionalIdentifier: ViewModifier {
    let identifier: String?
    func body(content: Content) -> some View {
        if let identifier { content.accessibilityIdentifier(identifier) } else { content }
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
