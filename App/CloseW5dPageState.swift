import SwiftUI

/// Shared load-state model used by the W5 close-the-gap screens.
/// Pure value logic so it can be unit tested without hosting SwiftUI.
enum CloseW5dPageState: Equatable {
    case loading
    case content
    case empty
    case error
    case denied

    /// Precedence: permission-denied, then error (only when nothing is cached),
    /// then loading (only when nothing is cached), then empty, then content.
    /// Cached content stays visible during refreshes and transient errors.
    static func resolve(loading: Bool, failed: Bool, denied: Bool, hasContent: Bool, isEmpty: Bool) -> CloseW5dPageState {
        if denied { return .denied }
        if hasContent {
            return isEmpty ? .empty : .content
        }
        if failed { return .error }
        if loading { return .loading }
        return isEmpty ? .empty : .content
    }

    /// True when the state replaces the normal screen body.
    var blocksContent: Bool {
        switch self {
        case .loading, .error, .denied, .empty: return true
        case .content: return false
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .loading: return "closew5d.state.loading"
        case .content: return "closew5d.state.content"
        case .empty: return "closew5d.state.empty"
        case .error: return "closew5d.state.error"
        case .denied: return "closew5d.state.denied"
        }
    }
}

/// Renders loading / empty / error-with-retry / permission-denied for a
/// `CloseW5dPageState`. Renders nothing for `.content`.
struct CloseW5dStateView: View {
    let state: CloseW5dPageState
    let emptyTitle: LocalizedStringKey
    let emptyMessage: LocalizedStringKey
    let retry: () -> Void

    var body: some View {
        switch state {
        case .content:
            EmptyView()
        case .loading:
            ProgressView("closew5d.state.loading")
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier(state.accessibilityIdentifier)
        case .empty:
            CYEmptyStateView(title: emptyTitle, description: emptyMessage)
                .accessibilityIdentifier(state.accessibilityIdentifier)
        case .error:
            CYErrorStateView(title: "closew5d.state.error.title", message: "closew5d.state.error.message",
                             retryTitle: "closew5d.state.retry", onRetry: retry)
                .accessibilityIdentifier(state.accessibilityIdentifier)
        case .denied:
            CYEmptyStateView(systemImage: "lock", title: "closew5d.state.denied.title", description: "closew5d.state.denied.message")
                .accessibilityIdentifier(state.accessibilityIdentifier)
        }
    }
}

/// Honest notice for a write that is gated (no production grant / route).
struct CloseW5dGatedNotice: View {
    let message: LocalizedStringKey
    var body: some View {
        Label(message, systemImage: "hourglass")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("closew5d.state.gated")
    }
}

/// CRM campaigns page: maps the view-model's published values onto the shared state.
enum MerchantEngagementPageState {
    static let deniedKey = "merchant.business.denied"
    static func resolve(loading: Bool, issue: String?, hasAccess: Bool, hasIdentity: Bool) -> CloseW5dPageState {
        // An inactive/unknown merchant identity (access loaded, no identity) cannot use CRM tools.
        let denied = issue == deniedKey || (hasAccess && !hasIdentity)
        return CloseW5dPageState.resolve(loading: loading, failed: issue != nil, denied: denied, hasContent: hasAccess && hasIdentity, isEmpty: false)
    }
}

/// Brand center (merchant decor) home: an inactive merchant has not finished onboarding
/// (mini-program `loadState === 'empty'`); an active one with no visible entries lacks
/// decor permission (`loadState === 'permission'`).
enum MerchantOperationsHomeState {
    static func resolve(active: Bool, visibleEntryCount: Int) -> CloseW5dPageState {
        if !active { return .empty }
        if visibleEntryCount <= 0 { return .denied }
        return .content
    }
}
