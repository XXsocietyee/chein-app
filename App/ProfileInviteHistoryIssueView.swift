import SwiftUI

/// Source 邀请记录 failure states. Server messages stay with the generic social issue view;
/// this view only chooses the page's own title and hint and offers retry for ordinary failures.
struct ProfileInviteHistoryIssueView: View {
    let error: Error
    var retry: (() -> Void)? = nil
    var body: some View {
        let kind = ProfileInviteHistoryIssueKind(error)
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYStatusChip(LocalizedStringKey(kind.titleKey), tone: .warning, systemImage: "exclamationmark.circle")
            if let detail = kind.detailKey { Text(LocalizedStringKey(detail)).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            if kind.canRetry, let retry { CYPillButton("action.retry", style: .secondary, fullWidth: false, action: retry) }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("profile.inviteHistory.issue")
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
