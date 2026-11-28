import SwiftUI

/// 1128 gap #13 (C-08; MP topic-detail/index.js:309 loadManageStats): the topic-manage-stats read decides
/// whether the director console, 场次管理 and 核销 show. A failure used to be swallowed (`try?`), which hid the
/// console for every owner. A role refusal still hides it quietly (MP applyVerifyVisibility); any other
/// failure shows a retry row.
struct ClubTopicStatsLoadKey: Hashable {
    let generation: UInt64
    let attempt: Int
}

@MainActor enum ClubTopicStatsLoad {
    struct Outcome: Equatable {
        let value: ClubGovernanceValue?
        let retryable: Bool
    }

    static func run(access: any ClubGovernanceAccess, scope: ClubGovernanceScope) async -> Outcome {
        do {
            let snapshot = try await access.read(.topicStats, scope: scope, options: [:])
            return Outcome(value: snapshot.value, retryable: false)
        } catch {
            return Outcome(value: nil, retryable: retryable(error))
        }
    }

    /// Cancellation, sign-out and a role refusal are not offered a retry.
    static func retryable(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        if let failure = error as? ClubGovernanceFailure {
            return ![.forbidden, .signedOut, .notConfigured].contains(failure)
        }
        if let api = error as? APIError, api == .unauthorized { return false }
        return true
    }
}

struct ClubTopicStatsRetryRow: View {
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text("club.topic.stats.failed")
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("action.retry", action: retry)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("club.topic.stats.retry")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club.topic.stats.failed")
    }
}
