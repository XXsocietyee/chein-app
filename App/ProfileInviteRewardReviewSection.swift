import SwiftUI

@MainActor struct ProfileInviteRewardReviewSection: View {
    let review: ProfileInviteRewardReview
    let isLoading: Bool
    let reload: () -> Void
    var body: some View {
        Section("profile.inviteRewards.title") {
            LabeledContent("profile.inviteRewards.total") {
                if let points = review.cumulativePoints {
                    Text(verbatim: NSDecimalNumber(decimal: points).stringValue)
                        .cyText(.sheetTitle).monospacedDigit().fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("profile.inviteRewards.cumulative")
                } else {
                    Text("social.invites.synchronizing").accessibilityIdentifier("profile.inviteRewards.pending")
                }
            }
            if review.ledgerState != .complete {
                Text("profile.inviteRewards.incomplete").cyText(.label).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("profile.inviteRewards.incomplete")
                Button("profile.inviteRewards.reload", action: reload).disabled(isLoading)
                    .accessibilityIdentifier("profile.inviteRewards.reload")
            }
            Text("profile.inviteRewards.monthScope").cyText(.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
        }.cyText(.label).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("profile.inviteRewards.month")
    }
}
