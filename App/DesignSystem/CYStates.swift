import SwiftUI

/// Icon + one line + one action. Domain-aware sibling of `CYEmptyStateView`/`CYErrorStateView`
/// (those keep their legacy callers). The action stays secondary unless the caller makes it the screen's one primary.
struct CYEmptyState: View {
    private let systemImage: String
    private let message: LocalizedStringKey
    private let tableName: String?
    private let detail: LocalizedStringKey?
    private let detailVerbatim: String?
    private let messageIdentifier: String?
    private let actionTitle: LocalizedStringKey?
    private let actionIdentifier: String?
    private let actionStyle: CYPillStyle
    private let action: (() -> Void)?
    private let kind: CYStateKind?

    /// Already-resolved copy (restyled merchant/member screens). Not looked up again in a string table.
    init(systemImage: String = "tray", verbatimTitle: String, verbatimSubtitle: String? = nil,
         kind: CYStateKind? = nil, action: (() -> Void)? = nil) {
        self.init(systemImage: systemImage, LocalizedStringKey(verbatimTitle), detailVerbatim: verbatimSubtitle,
                  kind: kind, action: action)
    }

    init(
        systemImage: String = "tray",
        _ message: LocalizedStringKey,
        tableName: String? = nil,
        detail: LocalizedStringKey? = nil,
        detailVerbatim: String? = nil,
        messageIdentifier: String? = nil,
        actionTitle: LocalizedStringKey? = nil,
        actionIdentifier: String? = nil,
        actionStyle: CYPillStyle = .secondary,
        kind: CYStateKind? = nil,
        action: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.systemImage = systemImage
        self.message = message
        self.tableName = tableName
        self.detail = detail
        self.detailVerbatim = detailVerbatim
        self.messageIdentifier = messageIdentifier
        self.actionTitle = actionTitle
        self.actionIdentifier = actionIdentifier
        self.actionStyle = actionStyle
        self.action = action
    }

    /// R9-MEM-IOS-1 (native-r2): the system `ContentUnavailableView`. The icon is the MP empty art via `MPAsset`
    /// when the symbol maps to one (`CYEmptyIllustration`), otherwise the SF Symbol. The one action keeps its style.
    var body: some View {
        ContentUnavailableView {
            Label {
                Text(message, tableName: tableName)
            } icon: {
                if let art = CYEmptyIllustration.kind(matching: systemImage) {
                    CYEmptyIllustration(kind: art, size: 96)
                } else {
                    Image(systemName: kind?.symbol ?? systemImage)
                }
            }
        } description: {
            if let detailVerbatim {
                Text(verbatim: detailVerbatim)
            } else if let detail {
                Text(detail, tableName: tableName)
            }
        } actions: {
            if let actionTitle, let action {
                actionButton(actionTitle, action: action)
            }
        }
        .cyIdentifier(messageIdentifier)
    }

    @ViewBuilder private func actionButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) { Text(title, tableName: tableName) }
            .controlSize(.large)
            .cyIdentifier(actionIdentifier)
        switch actionStyle {
        case .primary: button.buttonStyle(.borderedProminent)
        case .secondary: button.buttonStyle(.bordered)
        case .tertiary: button.buttonStyle(.borderless)
        }
    }
}

private extension View {
    @ViewBuilder func cyIdentifier(_ identifier: String?) -> some View {
        if let identifier { accessibilityIdentifier(identifier) }
        else { self }
    }
}

/// Loading sibling of `CYEmptyState` / `CYErrorState`: the one loading pattern, a system `ProgressView` with the
/// MP loading words as its visible label (加载中… / Loading…). No invented rows.
struct CYLoadingState: View {
    private let message: LocalizedStringKey
    private let messageIdentifier: String?

    init(_ message: LocalizedStringKey = "accountCollection.loading", messageIdentifier: String? = nil) {
        self.message = message
        self.messageIdentifier = messageIdentifier
    }

    var body: some View {
        ProgressView {
            Text(message)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.xxl)
        .padding(.horizontal, CYSpacing.lg)
        .cyIdentifier(messageIdentifier)
    }
}

/// The one busy-button label: while the action runs, a small system `ProgressView` sits before the action's own title
/// (the title never disappears, the button keeps its width, VoiceOver keeps hearing the title). P10: never a spinner alone.
struct CYBusyLabel<Title: View>: View {
    private let busy: Bool
    private let title: Title

    init(busy: Bool, @ViewBuilder title: () -> Title) {
        self.busy = busy
        self.title = title()
    }

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            if busy {
                ProgressView()
                    .controlSize(.small)
            }
            title
        }
    }
}

struct CYErrorState: View {
    private let message: LocalizedStringKey
    private let retryTitle: LocalizedStringKey
    private let offline: Bool
    private let onRetry: () -> Void

    init(_ message: LocalizedStringKey = "Couldn't load this. Check your connection.", retryTitle: LocalizedStringKey = "action.retry", offline: Bool = false, onRetry: @escaping () -> Void) {
        self.message = message
        self.retryTitle = retryTitle
        self.offline = offline
        self.onRetry = onRetry
    }

    /// Kind form used by restyled merchant screens. `.network` shows the offline variant.
    enum Kind { case server, permission, network }
    init(kind: Kind, message: LocalizedStringKey, retryTitle: LocalizedStringKey = "action.retry", onRetry: @escaping () -> Void) {
        self.init(message, retryTitle: retryTitle, offline: kind == .network, onRetry: onRetry)
    }

    var body: some View {
        CYEmptyState(systemImage: "exclamationmark.triangle", message, actionTitle: retryTitle, kind: offline ? .offline : .failure, action: onRetry)
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
