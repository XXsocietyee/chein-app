import Foundation

/// Round-2 Core models & helpers for remaining `play-roam` MP gaps:
/// `RNEAR-2/7`, `ROAM-8/13`, `RHIST-1/2`, `RPOI-3`, `BWALL-2/3`, `B3D-1`,
/// `JREPORT-2/3`, `JLAND-7`, `JSETTLE-4`, `RTEAMS-3`, `TGOALS-4`, `SALBUM-6`.

// MARK: - RNEAR-2 / RNEAR-7: Nearby Teams Map + Avatar Pins

public struct NearbyTeamMapPin: Identifiable, Equatable, Sendable {
    public let id: Int
    public let teamName: String
    public let leaderName: String
    public let leaderAvatarURL: String?
    public let memberCount: Int
    public let capacity: Int
    public let latitude: Double
    public let longitude: Double

    public init(
        id: Int,
        teamName: String,
        leaderName: String,
        leaderAvatarURL: String?,
        memberCount: Int,
        capacity: Int,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.teamName = teamName
        self.leaderName = leaderName
        self.leaderAvatarURL = leaderAvatarURL
        self.memberCount = memberCount
        self.capacity = capacity
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - RHIST-1 / RHIST-2: Merged Roam History

public struct MergedRoamHistoryRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let sessionID: String?
    public let timestamp: TimeInterval
    public let title: String
    public let distanceKM: Double
    public let durationText: String
    public let isLocalOnly: Bool

    public init(
        id: String,
        sessionID: String? = nil,
        timestamp: TimeInterval,
        title: String,
        distanceKM: Double,
        durationText: String,
        isLocalOnly: Bool
    ) {
        self.id = id
        self.sessionID = sessionID
        self.timestamp = timestamp
        self.title = title
        self.distanceKM = distanceKM
        self.durationText = durationText
        self.isLocalOnly = isLocalOnly
    }

    /// Mirrors MP `scene-roam-history/index.js` merge & dedupe by `sessionId` or `timestamp`.
    public static func merge(local: [MergedRoamHistoryRow], remote: [MergedRoamHistoryRow]) -> [MergedRoamHistoryRow] {
        var seenSessionIDs = Set<String>()
        var seenTimestamps = Set<Int>()
        var result: [MergedRoamHistoryRow] = []

        for item in remote + local {
            if let sid = item.sessionID, !sid.isEmpty {
                if seenSessionIDs.contains(sid) { continue }
                seenSessionIDs.insert(sid)
            } else {
                let sec = Int(item.timestamp)
                if seenTimestamps.contains(sec) { continue }
                seenTimestamps.insert(sec)
            }
            result.append(item)
        }
        return result.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - RPOI-3: Pending Check-In Recovery

public struct RoamPendingCheckInContext: Equatable, Sendable {
    public let poiID: Int
    public let attemptID: String
    public let method: Int
    public let createdAt: Date

    public init(poiID: Int, attemptID: String, method: Int, createdAt: Date = Date()) {
        self.poiID = poiID
        self.attemptID = attemptID
        self.method = method
        self.createdAt = createdAt
    }
}

// MARK: - BWALL-2 / BWALL-3 / B3D-1: Badge Wall & 3D Pin Support

public struct BadgeWallMedalItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let familyName: String
    public let imageURL: String?
    public let isUnlocked: Bool
    public let isIdentityPin: Bool
    public let rarityTier: Int

    public init(
        id: String,
        title: String,
        familyName: String,
        imageURL: String?,
        isUnlocked: Bool,
        isIdentityPin: Bool = false,
        rarityTier: Int = 1
    ) {
        self.id = id
        self.title = title
        self.familyName = familyName
        self.imageURL = imageURL
        self.isUnlocked = isUnlocked
        self.isIdentityPin = isIdentityPin
        self.rarityTier = rarityTier
    }
}

public enum BadgeWallGrouping {
    public static func split(_ items: [BadgeWallMedalItem]) -> (unlocked: [BadgeWallMedalItem], locked: [BadgeWallMedalItem]) {
        (items.filter(\.isUnlocked), items.filter { !$0.isUnlocked })
    }
}

// MARK: - JREPORT-3 / JLAND-7 / JSETTLE-4 / TGOALS-4

public struct JourneyLeaderboardScopeQuery: Equatable, Sendable {
    public let scope: String
    public let topicID: Int?
    public let activityID: Int?
    public let teamID: Int?
    public let cityCode: String?
    public let countryCode: String?
    public let clubID: Int?

    public init(
        scope: String,
        topicID: Int? = nil,
        activityID: Int? = nil,
        teamID: Int? = nil,
        cityCode: String? = nil,
        countryCode: String? = nil,
        clubID: Int? = nil
    ) {
        self.scope = scope
        self.topicID = topicID
        self.activityID = activityID
        self.teamID = teamID
        self.cityCode = cityCode
        self.countryCode = countryCode
        self.clubID = clubID
    }
}

public enum JourneyDateFormatterHelper {
    /// Formats a date as MP `M月d日 HH:mm` (Beijing time) for `JLAND-7` / `JPROMO-5`.
    public static func monthDayTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

public struct ExplorationGoalProgressItem: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let progress: Int?
    public let target: Int

    public init(id: Int, title: String, progress: Int?, target: Int) {
        self.id = id
        self.title = title
        self.progress = progress
        self.target = max(1, target)
    }

    public var showsProgressBar: Bool { progress != nil }
}
