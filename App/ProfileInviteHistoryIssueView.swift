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
        return CYEmptyState(systemImage: kind == .signIn ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle",
                            LocalizedStringKey(kind.titleKey),
                            detail: kind.detailKey.map { LocalizedStringKey($0) },
                            messageIdentifier: "profile.inviteHistory.issue",
                            actionTitle: action == nil ? nil : (kind == .signIn ? "auth.signIn" : "action.retry"),
                            actionIdentifier: action == nil ? nil : "profile.inviteHistory.issue.action",
                            kind: .failure,
                            action: action)
    }
    private func inline(_ kind: ProfileInviteHistoryIssueKind) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYStatusChip(LocalizedStringKey(kind.titleKey), tone: .warning, systemImage: "exclamationmark.circle")
            if let detail = kind.detailKey { Text(LocalizedStringKey(detail)).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            if kind.canRetry, let retry { CYPillButton("action.retry", style: .secondary, fullWidth: false, action: retry) }
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
        HStack(alignment: .center, spacing: CYSpacing.md) {
            CYAvatarView(url: member.avatar.flatMap { URL(string: $0) }, name: member.nickname ?? "—", size: .lg)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("u9cde.invite.points \(NSDecimalNumber(decimal: reward.points).stringValue)")
                    .cyText(.cardTitle).monospacedDigit().foregroundStyle(CYColor.brand)
                HStack(spacing: 0) {
                    if let nickname = member.nickname, !nickname.isEmpty { Text(verbatim: nickname + " · ") }
                    Text("social.invites.earned")
                }
                .cyText(.meta).foregroundStyle(CYColor.textSecondary).lineLimit(1)
            }
            Spacer(minLength: CYSpacing.sm)
            if let time = reward.createdAt, !time.isEmpty {
                Text(verbatim: WalletPointsShortTime.text(time)).cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary)
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.inviteHistory.latestEarn")
    }
}

/// Source empty state: 还没有人接受你的邀请 with its hint.
struct ProfileInviteHistoryEmptyView: View {
    var body: some View {
        CYEmptyState(systemImage: "person.2.badge.plus", "profile.inviteHistory.empty", messageIdentifier: "profile.inviteHistory.empty")
    }
}

/// Source summary 累计邀请 {total} 人; absent until the server reports a total.
struct ProfileInviteHistorySummaryLine: View {
    let total: Int?
    var body: some View {
        if let total {
            Text("profile.inviteHistoryP2.summary \(total)").cyText(.cardTitle)
                .accessibilityIdentifier("profile.inviteHistory.summary")
        }
    }
}
