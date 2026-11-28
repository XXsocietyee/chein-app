import SwiftUI

/// FIN-20-2: one hero section, as in the MP invite history (scene-member-invite-history index.wxml:5-18):
/// 首购奖励积分, +N (待同步 until the ledger is complete), then 已邀请 N 人 · 已到账 M 人. No duplicate total row.
@MainActor struct ProfileInviteRewardReviewSection: View {
    let review: ProfileInviteRewardReview
    let total: Int?
    /// Invitation pages still loading reward coverage (`rewardCoverage != .complete`).
    var coverageIncomplete = false
    let isLoading: Bool
    let reload: () -> Void
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("profile.inviteRewards.hero").font(.subheadline).foregroundStyle(.secondary)
                if let points = review.cumulativePoints {
                    Text(verbatim: "+" + NSDecimalNumber(decimal: points).stringValue)
                        .cyText(.dataXL).foregroundStyle(.primary)
                        .accessibilityIdentifier("profile.inviteRewards.cumulative")
                } else {
                    Text("profile.inviteRewards.heroPending").font(.title3).foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile.inviteRewards.pending")
                }
                Group {
                    if let earned = review.earnedCount {
                        Text("profile.inviteRewards.meta \(ProfileInviteHistoryPageReady.countText(total)) \(earned)")
                    } else {
                        Text("profile.inviteRewards.metaInvited \(ProfileInviteHistoryPageReady.countText(total))")
                    }
                }
                .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                .accessibilityIdentifier("social.invites.total")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            if coverageIncomplete {
                Label {
                    Text("social.invites.partial")
                } icon: {
                    Image(systemName: "hourglass").foregroundStyle(.orange)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("social.invites.partial")
            }
            if review.ledgerState != .complete {
                Label("profile.inviteRewards.incomplete", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("profile.inviteRewards.incomplete")
                Button("profile.inviteRewards.reload", action: reload).disabled(isLoading).buttonStyle(.borderless)
                    .accessibilityIdentifier("profile.inviteRewards.reload")
            }
            Text("profile.inviteRewards.monthScope").font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
struct ProfileInviteMonthReward: View {
    let month: ProfileInviteRewardReview.Month
    var body: some View {
        VStack(alignment: .trailing, spacing: Theme.Space.s1) {
            if month.displaysPoints, let points = month.earnedPoints {
                Text(verbatim: "+" + NSDecimalNumber(decimal: points).stringValue)
                Text(month.isPartial ? "profile.inviteRewards.partialPoints" : "social.invites.points")
            } else {
                Text(verbatim: String(month.loadedMemberCount))
                Text("profile.inviteRewards.loadedPeople")
            }
        }.font(.subheadline).foregroundStyle(.secondary).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("profile.inviteRewards.month")
    }
}
