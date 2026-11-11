import Foundation

/// Page-ready facts for `subpackageMember/myinvite/myinvite` over reads that already exist:
/// `api/user/invite_list` through `SocialInvitePagination` and the first bounded reward page
/// through `SocialRewardScan`. Presentation only. It builds no request, opens no route, and
/// changes no capability. A missing total is an em dash, never 0; a literal 0 stays "0".
public enum ProfileInviteHistoryPageReady {
    public static let unknownMark = "\u{2014}"
    public static let invitationsPath = ProfileInviteHistoryReadRoute.invitations
    public static let rewardsPath = ProfileInviteHistoryReadRoute.rewards

    public static let loadingIdentifier = "social.invites.loading"
    public static let emptyIdentifier = "social.invites.empty"
    public static let errorIdentifier = "social.invites.error"
    public static let unknownIdentifier = "social.invites.unknown"
    public static let readyIdentifier = "social.invites.ready"

    /// Whether the reward ledger page explains every invited member yet.
    public enum RewardCoverage: Equatable {
        /// The ledger read failed or has not returned. Say nothing about earned or pending.
        case notSynchronized
        /// A first page without a total, or a total larger than what was fetched.
        case partial
        case complete
    }

    public struct Snapshot: Equatable {
        public let loadedCountText: String
        public let totalText: String
        public let hasMore: Bool
        public let continuationInvalid: Bool
        public let rewardCoverage: RewardCoverage
        public let accessibilityIdentifier: String
    }

    public enum Phase: Equatable {
        case loading
        case empty
        case error(ProfileInviteHistoryIssueKind)
        case unknown
        case ready(Snapshot)
    }

    public static func countText(_ count: Int?) -> String {
        guard let count, count >= 0 else { return unknownMark }
        return String(count)
    }

    public static func rewardCoverage(_ scan: SocialRewardScan?) -> RewardCoverage {
        guard let scan else { return .notSynchronized }
        return scan.isComplete ? .complete : .partial
    }

    /// A failure wins over rows already shown. No accepted page yet is `.loading` while a request
    /// runs and `.unknown` otherwise, never an empty history. Zero members after an accepted page
    /// and no more pages is `.empty`.
    public static func phase(loading: Bool, error: Error?, pagination: SocialInvitePagination?,
                             scan: SocialRewardScan?) -> Phase {
        if let error { return .error(ProfileInviteHistoryIssueKind(error)) }
        guard let pagination, pagination.nextPage > 1 else { return loading ? .loading : .unknown }
        if pagination.members.isEmpty && !pagination.hasMore && !pagination.continuationInvalid { return .empty }
        return .ready(Snapshot(
            loadedCountText: countText(pagination.members.count),
            totalText: countText(pagination.total),
            hasMore: pagination.hasMore,
            continuationInvalid: pagination.continuationInvalid,
            rewardCoverage: rewardCoverage(scan),
            accessibilityIdentifier: readyIdentifier
        ))
    }

    public static func identifier(for phase: Phase) -> String {
        switch phase {
        case .loading: return loadingIdentifier
        case .empty: return emptyIdentifier
        case .error: return errorIdentifier
        case .unknown: return unknownIdentifier
        case .ready(let snapshot): return snapshot.accessibilityIdentifier
        }
    }
}
