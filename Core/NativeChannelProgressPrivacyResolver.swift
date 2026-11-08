import Foundation

/// Pure resolver: the strictest of the user's preference and the channel's permission wins.
/// No I/O, no wire change. The audit projection is a separate concern and is never merged into user scopes.
public enum NativeChannelProgressPrivacyResolver {
    /// What the channel allows (a ceiling). Photos are closed unless the channel explicitly opens them.
    public struct ChannelPermission: Equatable {
        public let aggregateCeiling: NativeChannelProgressScope
        public let detailCeiling: NativeChannelProgressScope
        public let photoCeiling: NativeChannelProgressPhotoScope
        public let leaderboard: NativeChannelProgressLeaderboardScope
        public init(aggregateCeiling: NativeChannelProgressScope, detailCeiling: NativeChannelProgressScope,
                    photoCeiling: NativeChannelProgressPhotoScope = .onlyMe, leaderboard: NativeChannelProgressLeaderboardScope) {
            self.aggregateCeiling = aggregateCeiling; self.detailCeiling = detailCeiling
            self.photoCeiling = photoCeiling; self.leaderboard = leaderboard
        }
    }
    public struct Resolved: Equatable {
        public let aggregateScope: NativeChannelProgressScope
        public let detailScope: NativeChannelProgressScope
        public let photoScope: NativeChannelProgressPhotoScope
        public let leaderboardScope: NativeChannelProgressLeaderboardScope
    }
    /// Teammates' photos are closed unless the owner explicitly chose a wider photo scope.
    public static let defaultPhotoScope: NativeChannelProgressPhotoScope = .onlyMe

    public static func resolve(preference: NativeChannelProgressPrivacyValues, channel: ChannelPermission) -> Resolved {
        let aggregate = preference.aggregateScope.strictest(with: channel.aggregateCeiling)
        // Detail is never public (matches `NativeChannelProgressPrivacyValues`) and never wider than aggregate.
        var detail = preference.detailScope.strictest(with: channel.detailCeiling)
        if detail == .publicAccess { detail = .channel }
        detail = detail.strictest(with: aggregate)
        var photo = preference.photoScope.breadth <= channel.photoCeiling.breadth ? preference.photoScope : channel.photoCeiling
        // The original photo is never wider than the detail audience.
        if detail == .onlyMe { photo = .onlyMe }
        let leaderboard: NativeChannelProgressLeaderboardScope =
            (preference.leaderboardScope == .included && channel.leaderboard == .included) ? .included : .out
        return .init(aggregateScope: aggregate, detailScope: detail, photoScope: photo, leaderboardScope: leaderboard)
    }

    /// Whether a teammate (not the owner) may see the owner's photos. Closed by default.
    public static func teammateCanSeePhotos(_ resolved: Resolved) -> Bool {
        resolved.photoScope == .team && resolved.detailScope.breadth >= NativeChannelProgressScope.team.breadth
    }
}
