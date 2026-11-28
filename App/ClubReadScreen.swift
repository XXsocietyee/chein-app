import SwiftUI

/// Reader must publish account/epoch changes. Stored content is also identity checked in
/// body, so a previous account's rows are hidden before the replacement task starts.
@MainActor
struct ClubReadScreen<Reader: ClubReading & ObservableObject, Value, Content: View>: View {
    @ObservedObject var reader: Reader
    let accessibilityPrefix: String
    let refreshRevision: UInt64
    /// CLB-detail-44: the club page drops the bar 刷新 (pull-to-refresh, as the MP). Native restyle (spec §3.1): every
    /// club read refreshes by pull only, so the bar button is now opt-in.
    let showsToolbarRefresh: Bool
    /// CLB-detail-28 (parity r2): the club page's own states. Sign-in reads 登录后查看俱乐部, and a business rejection
    /// (a dissolved or closed club) shows the server sentence with 返回 instead of a pointless 重试. Default off.
    let usesClubPageStates: Bool
    /// mp-states r3 (MP talent/list wxml:65 cy-error): the club tab's list titles — 登录后查看我的俱乐部 /
    /// 当前身份不能查看俱乐部 / 俱乐部列表加载失败. Default off.
    let usesClubTabStates: Bool
    @Environment(\.dismiss) private var dismiss
    private struct LoadIdentity: Equatable {
        let identity: ClubReadIdentity
        let revision: UInt64
    }
    let requiresSignIn: Bool
    let onSignIn: (() -> Void)?
    let load: () async throws -> Value
    let content: (Value) -> Content
    @State private var value: Value?
    @State private var loadedIdentity: ClubReadIdentity?
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @State private var issue: ClubLoadIssue?
    @State private var issueIdentity: ClubReadIdentity?
    @State private var isLoading = false
    @State private var generation: UInt64 = 0

    init(reader: Reader, accessibilityPrefix: String, requiresSignIn: Bool = false, refreshRevision: UInt64 = 0,
         showsToolbarRefresh: Bool = false, usesClubPageStates: Bool = false, usesClubTabStates: Bool = false, onSignIn: (() -> Void)? = nil, load: @escaping () async throws -> Value,
         @ViewBuilder content: @escaping (Value) -> Content) {
        self.reader = reader; self.accessibilityPrefix = accessibilityPrefix
        self.refreshRevision = refreshRevision; self.showsToolbarRefresh = showsToolbarRefresh
        self.usesClubPageStates = usesClubPageStates
        self.usesClubTabStates = usesClubTabStates
        self.requiresSignIn = requiresSignIn; self.onSignIn = onSignIn
        self.load = load; self.content = content
    }
    /// True while no issue and no content for the current identity exists yet: the first load.
    private var isInitialLoading: Bool {
        guard reader.isClubConfigured else { return false }
        if requiresSignIn && !reader.clubIdentity.isSignedIn { return false }
        if issueIdentity == reader.clubIdentity, issue != nil { return false }
        return !(loadedIdentity == reader.clubIdentity && value != nil)
    }
    var body: some View {
        Group {
            if isInitialLoading {
                ProgressView { usesClubPageStates ? Text("club.detail.loading") : Text("club.loading") }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(accessibilityPrefix + ".loading")
            } else {
                readBody
            }
        }
        .refreshable { await reload() }
        .toolbar {
            if showsToolbarRefresh {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("club.refresh", systemImage: "arrow.clockwise") { Task { await reload() } }
                        .disabled(isLoading || !reader.isClubConfigured || (requiresSignIn && !reader.clubIdentity.isSignedIn))
                        .accessibilityIdentifier(accessibilityPrefix + ".refresh")
                }
            }
        }
        .task(id: LoadIdentity(identity: reader.clubIdentity, revision: refreshRevision)) { await reload() }
        .onDisappear {
            // Invalidate outstanding work without removing NavigationLink source rows on push.
            generation &+= 1
            isLoading = false
        }
    }
    @ViewBuilder private var readBody: some View {
        Group {
            if !reader.isClubConfigured {
                // One way forward: the Passport tab hosts Settings and the account.
                ContentUnavailableView {
                    Label { Text("club.unavailable").accessibilityIdentifier(accessibilityPrefix + ".unavailable") } icon: {
                        Image(systemName: "network.slash")
                    }
                } description: {
                    Text("auth.notConfigured")
                } actions: {
                    if rootTabSwitch.isAvailable {
                        Button("settings.title") { rootTabSwitch(.mine) }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(accessibilityPrefix + ".openSettings")
                    }
                }
            } else if requiresSignIn && !reader.clubIdentity.isSignedIn {
                issueView(ClubLoadIssue(ClubReadFailure.unauthorized(message: nil)))
            } else if issueIdentity == reader.clubIdentity, let issue {
                issueView(issue)
            } else if loadedIdentity == reader.clubIdentity, let value {
                content(value)
                    .overlay(alignment: .top) {
                        if isLoading { ProgressView().padding(8).background(.regularMaterial, in: Capsule()) }
                    }
            } else {
                Color.clear
            }
        }
    }
    @ViewBuilder private func issueView(_ issue: ClubLoadIssue) -> some View {
        if usesClubPageStates, let sentence = issue.rejectionMessage {
            ContentUnavailableView {
                Label { Text(LocalizedStringKey(sentence)).accessibilityIdentifier(accessibilityPrefix + ".error") } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            } actions: {
                Button("action.back") { dismiss() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(accessibilityPrefix + ".back")
            }
        } else {
            defaultIssueView(issue)
        }
    }
    @ViewBuilder private func defaultIssueView(_ issue: ClubLoadIssue) -> some View {
        let symbol = issue.needsSignIn ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle"
        // mp-states r3 (MP club/detail wxml:291,305): the members page reads 成员列表加载失败 · 重新加载, and a non-member
        // sees 加入俱乐部后可查看成员 with no button.
        let membersGate = isMembersPage && issue.titleKey == "club.membersUnavailable"
        let retryTitle: LocalizedStringKey = isMembersPage ? "club.members.reload" : "action.retry"
        let actionTitle: LocalizedStringKey? = issue.needsSignIn ? (onSignIn == nil ? nil : "club.signIn") : (issue.canRetry && !membersGate ? retryTitle : nil)
        let actionID = issue.needsSignIn ? accessibilityPrefix + ".signIn" : accessibilityPrefix + ".retry"
        let action: (() -> Void)? = actionTitle == nil ? nil : {
            if issue.needsSignIn { onSignIn?() }
            else { Task { await reload() } }
        }
        let signInPage = usesClubPageStates && issue.needsSignIn
        let titleKey = usesClubTabStates ? clubTabTitleKey(issue) : (isMembersPage ? membersTitleKey(issue) : (signInPage ? "club.detail.signIn" : issue.titleKey))
        ContentUnavailableView {
            Label {
                Text(LocalizedStringKey(titleKey))
                    .accessibilityIdentifier(accessibilityPrefix + ".error")
            } icon: { Image(systemName: symbol) }
        } description: {
            if !signInPage && !(usesClubTabStates && issue.needsSignIn) && !membersGate {
                if let message = issue.message { Text(verbatim: message) }
                else { Text(LocalizedStringKey(issue.hintKey)) }
            }
        } actions: {
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(actionID)
            }
        }
    }
    private var isMembersPage: Bool { accessibilityPrefix == "club.members" }
    private func membersTitleKey(_ issue: ClubLoadIssue) -> String {
        if issue.titleKey == "club.membersUnavailable" { return "club.members.joinToView" }
        if issue.titleKey == "club.loadFailed" { return "club.members.loadFailed" }
        return issue.titleKey
    }
    private func clubTabTitleKey(_ issue: ClubLoadIssue) -> String {
        if issue.needsSignIn { return "club.tab.state.signIn" }
        if issue.titleKey == "club.accessDenied" { return "club.tab.state.forbidden" }
        return "club.tab.state.loadFailed"
    }
    private func reload() async {
        // A cancelled refresh must not retire a newer read or clear its accepted state.
        guard !Task.isCancelled else { return }
        generation &+= 1
        let request = generation, identity = reader.clubIdentity
        if loadedIdentity != identity { value = nil; loadedIdentity = nil }
        issue = nil; issueIdentity = nil
        guard reader.isClubConfigured, !requiresSignIn || identity.isSignedIn else { isLoading = false; return }
        isLoading = true
        defer { if request == generation { isLoading = false } }
        do {
            let result = try await load()
            guard !Task.isCancelled, request == generation, reader.clubIdentity == identity else { return }
            value = result; loadedIdentity = identity
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled, request == generation, reader.clubIdentity == identity else { return }
            value = nil; loadedIdentity = nil
            issue = ClubLoadIssue(error); issueIdentity = identity
        }
    }
}

struct ClubLoadIssue {
    let titleKey: String
    let hintKey: String
    let message: String?
    let needsSignIn: Bool
    let canRetry: Bool
    /// The server's sentence when it refused the read as a business rule (not a network or auth failure).
    let rejectionMessage: String?
    init(_ error: Error) {
        let failure = error as? ClubReadFailure
        if case .rejected(_, let sentence)? = failure,
           let text = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            rejectionMessage = text
        } else { rejectionMessage = nil }
        message = failure?.message.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        needsSignIn = failure?.isUnauthorized == true || error as? APIError == .unauthorized
        canRetry = !needsSignIn && error as? APIError != .notConfigured
        if needsSignIn { titleKey = "club.signInRequired"; hintKey = "club.signInHint" }
        else if failure?.isForbidden == true { titleKey = "club.accessDenied"; hintKey = "club.accessDeniedHint" }
        else if failure == .membershipRequired { titleKey = "club.membersUnavailable"; hintKey = "club.joinToSeeMembers" }
        else if error as? APIError == .malformedResponse { titleKey = "club.loadFailed"; hintKey = "club.invalidResponse" }
        else { titleKey = "club.loadFailed"; hintKey = "club.retryHint" }
    }
}
