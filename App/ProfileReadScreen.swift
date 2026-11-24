import SwiftUI

/// A concrete root exists before the task starts. Refresh/retry/disappearance advance the
/// generation, so a slower response cannot replace a newer result or resurrect a dismissed page.
@MainActor
struct ProfileReadScreen<Value, Content: View>: View {
    let reader: any ProfileReading
    let accessibilityPrefix: String
    let load: () async throws -> Value
    let content: (Value) -> Content
    /// Nil keeps the shared Profile copy; a screen may supply its source-specific copy.
    let issueCopy: ProfileReadIssueCopy?
    /// Sign-in action for the signed-out state (MP 登录). Nil keeps the state without a button.
    let onSignIn: (() -> Void)?
    /// FIN-16-8: native pages refresh by pull only (restyle spec §3.1). Older hosts keep the ↻ until restyled.
    @Environment(\.profileReadShowsRefreshButton) private var showsRefreshButton
    /// Host-provided 登录 used when the screen was built without `onSignIn` (deep-link hosts).
    @Environment(\.profileReadSignIn) private var environmentSignIn
    @State private var value: Value?
    @State private var refreshToast: LocalizedStringKey?
    @State private var isLoading = true
    @State private var issue: ProfileLoadIssue?
    @State private var generation: UInt64 = 0
    @State private var loadOwner = ManualMapReadTaskOwner()

    init(reader: any ProfileReading, accessibilityPrefix: String,
         issueCopy: ProfileReadIssueCopy? = nil,
         onSignIn: (() -> Void)? = nil,
         load: @escaping () async throws -> Value,
         @ViewBuilder content: @escaping (Value) -> Content) {
        self.reader = reader
        self.accessibilityPrefix = accessibilityPrefix
        self.issueCopy = issueCopy
        self.onSignIn = onSignIn
        self.load = load
        self.content = content
    }

    private var signIn: (() -> Void)? { onSignIn ?? environmentSignIn }
    /// Configured, signed in and the first read is in flight.
    private var isShowingLoad: Bool { reader.identity != nil && reader.isConfigured && isLoading }
    var body: some View {
        CYLoadSlot(isLoading: isShowingLoad, label: LocalizedStringKey(issueCopy?.loadingKey ?? "profile.loading"),
                   identifier: accessibilityPrefix + ".loading", announces: true) {
            readBody
        }
        .refreshable { await loadOwner.run { await reload(keepingValue: true) } }
        .toolbar {
            if showsRefreshButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("profile.refresh", systemImage: "arrow.clockwise") { loadOwner.start { await reload(keepingValue: true) } }
                        .disabled(isLoading || !reader.isConfigured || reader.identity == nil)
                        .accessibilityIdentifier(accessibilityPrefix + ".refresh")
                }
            }
        }
        .task(id: reader.identity) { loadOwner.activate(); await loadOwner.run { await reload() } }
        .onDisappear {
            // Keep the immutable list snapshot while its NavigationLink destination is
            // pushed. Removing that link here can unexpectedly pop native navigation.
            // Account replacement destroys the root; a new appearance refreshes the data.
            loadOwner.deactivate(); generation &+= 1
        }
        .cyToast(message: $refreshToast, tone: .warning)
    }
    @ViewBuilder private var readBody: some View {
        ZStack {
            if reader.identity == nil {
                CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", LocalizedStringKey(issueCopy?.signInTitleKey ?? "profile.signInRequired"), detail: LocalizedStringKey(issueCopy?.signInDetailKey ?? "auth.expired"), messageIdentifier: accessibilityPrefix + ".signIn",
                             actionTitle: signIn == nil ? nil : "auth.signIn", actionIdentifier: signIn == nil ? nil : accessibilityPrefix + ".signIn.action",
                             action: signIn)
            } else if !reader.isConfigured {
                CYEmptyState(systemImage: "network.slash", "profile.unavailable", detail: "auth.notConfigured", messageIdentifier: accessibilityPrefix + ".unavailable")
            } else if isLoading {
                Color.clear
            } else if let issue {
                CYEmptyState(
                    systemImage: "exclamationmark.triangle",
                    LocalizedStringKey(issue.titleKey),
                    detail: issue.message == nil && !issue.detailKey.isEmpty ? LocalizedStringKey(issue.detailKey) : nil,
                    detailVerbatim: issue.message,
                    messageIdentifier: accessibilityPrefix + ".error",
                    actionTitle: issue.canRetry ? "action.retry" : nil,
                    actionIdentifier: issue.canRetry ? accessibilityPrefix + ".retry" : nil,
                    kind: .failure,
                    action: issue.canRetry ? { loadOwner.start { await reload() } } : nil
                )
            } else if let value {
                content(value)
            }
        }
    }
    /// First load and account change clear the page. A pull or toolbar refresh keeps what is on screen
    /// (FIN-16-3, MP 订单刷新失败): a retryable failure shows a toast; sign-in / not-configured still clear it.
    private func reload(keepingValue: Bool = false) async {
        generation &+= 1
        let request = generation
        let keeps = keepingValue && value != nil
        if !keeps { value = nil; isLoading = true }
        issue = nil
        guard reader.isConfigured, reader.identity != nil else { value = nil; isLoading = false; return }
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await load()
            guard generation == request, !Task.isCancelled else { return }
            value = result
        } catch is CancellationError {
            // Navigation/session changes discard the result; they are not networking errors.
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            issue = issueCopy.map { ProfileLoadIssue(error, copy: $0) } ?? ProfileLoadIssue(error)
            if keeps, issue?.canRetry == true {
                issue = nil
                refreshToast = "profile.refreshFailed"
            } else {
                value = nil
            }
        }
    }
}

private struct ProfileLoadIssue {
    let titleKey: String
    let detailKey: String
    let message: String?
    let canRetry: Bool
    init(_ error: Error) {
        let failure = error as? ProfileReadFailure
        if error as? APIError == .unauthorized || failure?.isUnauthorized == true {
            titleKey = "profile.signInRequired"; detailKey = "auth.expired"; message = nil; canRetry = false
        } else if error as? APIError == .notConfigured {
            titleKey = "profile.unavailable"; detailKey = "auth.notConfigured"; message = nil; canRetry = false
        } else {
            titleKey = "profile.loadFailed"
            detailKey = error as? APIError == .malformedResponse ? "auth.invalidResponse" : "profile.retryHint"
            message = failure?.message.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            canRetry = true
        }
    }
    /// Screen-specific source copy. Sign-in and not-configured remain non-retryable;
    /// a 403 keeps any server message, generic failures use the fixed source wording.
    init(_ error: Error, copy: ProfileReadIssueCopy) {
        switch ProfileReadIssueCopy.kind(of: error) {
        case .signIn:
            titleKey = copy.signInTitleKey; detailKey = copy.signInDetailKey; message = nil; canRetry = false
        case .forbidden:
            let failure = error as? ProfileReadFailure
            titleKey = copy.forbiddenTitleKey; detailKey = ""
            message = failure?.message.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            canRetry = true
        case .malformed:
            titleKey = copy.failureTitleKey; detailKey = copy.malformedDetailKey; message = nil; canRetry = true
        case .failure:
            if error as? APIError == .notConfigured {
                titleKey = "profile.unavailable"; detailKey = "auth.notConfigured"; message = nil; canRetry = false
            } else {
                titleKey = copy.failureTitleKey; detailKey = copy.failureDetailKey; message = nil; canRetry = true
            }
        }
    }
}

/// Server strings remain literal text. Empty strings do not produce unlabeled rows.
struct ProfileOptionalRow: View {
    let key: LocalizedStringKey
    let value: String?
    var body: some View {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            LabeledContent(key) { Text(verbatim: value).textSelection(.enabled) }
        }
    }
}

struct ProfileEmptyState: View {
    let title: LocalizedStringKey
    let hint: LocalizedStringKey
    let symbol: String
    let identifier: String
    var body: some View {
        CYEmptyState(systemImage: symbol, title, messageIdentifier: identifier)
        // `hint` is kept for callers; the spec allows no helper captions under empty states.
    }
}

private struct ProfileReadShowsRefreshButtonKey: EnvironmentKey { static let defaultValue = true }
private struct ProfileReadSignInKey: EnvironmentKey { static let defaultValue: (() -> Void)? = nil }
extension EnvironmentValues {
    /// FIN-16-8: false drops the toolbar ↻ on pages that refresh by pull only.
    var profileReadShowsRefreshButton: Bool {
        get { self[ProfileReadShowsRefreshButtonKey.self] }
        set { self[ProfileReadShowsRefreshButtonKey.self] = newValue }
    }
    /// R7-MEM-17-1: 登录 for a `ProfileReadScreen` whose host had no sign-in closure to pass.
    var profileReadSignIn: (() -> Void)? {
        get { self[ProfileReadSignInKey.self] }
        set { self[ProfileReadSignInKey.self] = newValue }
    }
}
