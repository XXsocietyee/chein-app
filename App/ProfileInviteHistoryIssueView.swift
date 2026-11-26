import SwiftUI

/// Source 邀请记录 failure states. Server messages stay with the generic social issue view;
/// this view only chooses the page's own title and hint and offers retry for ordinary failures.
struct ProfileInviteHistoryIssueView: View {
    let error: Error
    var retry: (() -> Void)? = nil
    @Environment(\.inviteHistoryIssueFullPage) private var fullPage
    @Environment(\.inviteHistorySignIn) private var signIn
    var body: some View {
        let kind = ProfileInviteHistoryIssueKind(error)
        if fullPage { page(kind) } else { inline(kind) }
    }
    /// FIN-20-4: MP cy-error fill size lg while no row is loaded: 登录 for signed-out, 重试 for ordinary failures.
    private func page(_ kind: ProfileInviteHistoryIssueKind) -> some View {
        let action: (() -> Void)? = kind == .signIn ? signIn : (kind.canRetry ? retry : nil)
        return ContentUnavailableView {
            Label(LocalizedStringKey(kind.titleKey),
                  systemImage: kind == .signIn ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle")
        } description: {
            if let detail = kind.detailKey { Text(LocalizedStringKey(detail)) }
        } actions: {
            if let action {
                Button(action: action) {
                    Text(LocalizedStringKey(kind == .signIn ? "auth.signIn" : "action.retry"))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("profile.inviteHistory.issue.action")
            }
        }
        .accessibilityIdentifier("profile.inviteHistory.issue")
    }
    private func inline(_ kind: ProfileInviteHistoryIssueKind) -> some View {
        VStack(alignment: .leading) {
            Label {
                Text(LocalizedStringKey(kind.titleKey))
            } icon: {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
            }
            if let detail = kind.detailKey { Text(LocalizedStringKey(detail)).font(.subheadline).foregroundStyle(.secondary) }
            if kind.canRetry, let retry {
                Button(action: retry) { Text("action.retry") }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("profile.inviteHistory.issue")
    }
}

private struct InviteHistoryIssueFullPageKey: EnvironmentKey { static let defaultValue = false }
private struct InviteHistorySignInKey: EnvironmentKey { static let defaultValue: (() -> Void)? = nil }
extension EnvironmentValues {
    var inviteHistoryIssueFullPage: Bool {
        get { self[InviteHistoryIssueFullPageKey.self] }
        set { self[InviteHistoryIssueFullPageKey.self] = newValue }
    }
    var inviteHistorySignIn: (() -> Void)? {
        get { self[InviteHistorySignInKey.self] }
        set { self[InviteHistorySignInKey.self] = newValue }
    }
}

/// R7-MEM-20-1: MP `ir-earn`: +N 积分, nickname · 首购奖励已到账, time. Static (no scan animation).
struct ProfileInviteLatestEarnCard: View {
    let member: SocialInvitedMember
    let reward: SocialInviteReward
    var body: some View {
        HStack(alignment: .center) {
            CYAvatarView(url: member.avatar.flatMap { URL(string: $0) }, name: member.nickname ?? "—", size: .lg)
            VStack(alignment: .leading) {
                Text("u9cde.invite.points \(NSDecimalNumber(decimal: reward.points).stringValue)")
                    .font(.headline).monospacedDigit().foregroundStyle(.tint)
                HStack(spacing: 0) {
                    if let nickname = member.nickname, !nickname.isEmpty { Text(verbatim: nickname + " · ") }
                    Text("social.invites.earned")
                }
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let time = reward.createdAt, !time.isEmpty {
                Text(verbatim: WalletPointsShortTime.text(time)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.inviteHistory.latestEarn")
    }
}

/// Source empty state: 还没有人接受你的邀请 with its hint.
struct ProfileInviteHistoryEmptyView: View {
    var body: some View {
        ContentUnavailableView("profile.inviteHistory.empty", systemImage: "tray")
            .accessibilityIdentifier("profile.inviteHistory.empty")
    }
}

/// Source summary 累计邀请 {total} 人; absent until the server reports a total.
struct ProfileInviteHistorySummaryLine: View {
    let total: Int?
    var body: some View {
        if let total {
            Text("profile.inviteHistoryP2.summary \(total)").font(.headline)
                .accessibilityIdentifier("profile.inviteHistory.summary")
        }
    }
}
