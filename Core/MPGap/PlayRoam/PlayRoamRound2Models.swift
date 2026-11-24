import Foundation
import CoreFoundation

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
    /// MP `rank` query `scopeId`. City, country, club, quest and team ids go here, not as their own keys.
    public let scopeID: String?
    /// MP `rank` query `period`. Empty and `"0"` are omitted, matching `idQuery`.
    public let period: String?

    public init(
        scope: String,
        topicID: Int? = nil,
        activityID: Int? = nil,
        teamID: Int? = nil,
        cityCode: String? = nil,
        countryCode: String? = nil,
        clubID: Int? = nil,
        scopeID: String? = nil,
        period: String? = nil
    ) {
        self.scope = scope
        self.topicID = topicID
        self.activityID = activityID
        self.teamID = teamID
        self.cityCode = cityCode
        self.countryCode = countryCode
        self.clubID = clubID
        self.scopeID = scopeID
        self.period = period
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

/// Pending on-site check-in for one player and one POI.
/// `scene-roam-poi-detail` `pendingContext`: key `cy_roam_poi_checkin_pending:v1:{owner}:{poi}`.
/// The record stores `v`, `ownerId`, `poiId`, `attemptId`, and `uncertain`. It does not store
/// coordinates, answers, photos, or scan contents. The photo cache is the sibling key `:photo`.
public struct RoamPendingCheckInRecord: Equatable, Sendable {
    public let ownerID: String
    public let poiID: String
    public let attemptID: String
    public let uncertain: Bool
    public init(ownerID: String, poiID: String, attemptID: String, uncertain: Bool) {
        self.ownerID = ownerID
        self.poiID = poiID
        self.attemptID = attemptID
        self.uncertain = uncertain
    }
}

public protocol RoamPendingCheckInStoring: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

public final class RoamPendingCheckInMemory: RoamPendingCheckInStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var box: [String: Data] = [:]
    public init() {}
    public func data(forKey key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return box[key]
    }
    public func set(_ data: Data?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        if let data { box[key] = data } else { box.removeValue(forKey: key) }
    }
}

public enum RoamPendingCheckInError: Error, Equatable {
    case invalid
    case notSaved
    case notRemoved
}

public enum RoamPendingCompleteStep: Equatable, Sendable {
    /// The body is neither an accepted receipt nor a known pre-write rejection. Mark the attempt uncertain.
    case unknown
    /// A new rejection must not erase an earlier unknown attempt.
    case keepPreviousUnknown(message: String)
    case clear
}

public enum RoamPendingCheckInJournal {
    public static let prewriteRejections: Set<String> = [
        "请先登录", "参数不合规", "据点未开放或已下线", "节点未上线", "节点未设置坐标", "缺少定位",
        "离据点太远，请到店后再完成", "答案不正确", "请上传拍照打卡照片", "照片地址不合法，请重新上传",
        "请扫描本店的到店打卡码", "这张码不属于本店", "照片未上传成功或不属于当前账号，请重新拍摄上传",
        "照片校验暂不可用，请稍后重试"
    ]

    public static func storageKey(ownerID: String, poiID: String) -> String? {
        guard JourneyLoopSource.isID(ownerID), JourneyLoopSource.isID(poiID) else { return nil }
        return "cy_roam_poi_checkin_pending:v1:" + ownerID + ":" + poiID
    }

    public static func photoKey(_ key: String) -> String { key + ":photo" }

    public static func read(_ store: RoamPendingCheckInStoring, key: String, ownerID: String, poiID: String) throws -> RoamPendingCheckInRecord? {
        guard let data = store.data(forKey: key), !data.isEmpty else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw RoamPendingCheckInError.invalid }
        guard int(object["v"]) == 1, id(object["ownerId"]) == ownerID, id(object["poiId"]) == poiID,
              let attempt = object["attemptId"] as? String, !attempt.isEmpty else { throw RoamPendingCheckInError.invalid }
        let uncertain = bool(object["uncertain"]) == true
        return RoamPendingCheckInRecord(ownerID: ownerID, poiID: poiID, attemptID: attempt, uncertain: uncertain)
    }

    /// `_pendingNotice`: only an existing certain record is flipped to `uncertain`. Identifiers stay.
    public static func markUncertain(_ store: RoamPendingCheckInStoring, key: String, ownerID: String, poiID: String) throws -> RoamPendingCheckInRecord? {
        guard let current = try read(store, key: key, ownerID: ownerID, poiID: poiID) else { return nil }
        if current.uncertain { return current }
        try write(store, key: key, record: RoamPendingCheckInRecord(ownerID: ownerID, poiID: poiID, attemptID: current.attemptID, uncertain: true))
        guard let saved = try read(store, key: key, ownerID: ownerID, poiID: poiID), saved.uncertain, saved.attemptID == current.attemptID else {
            throw RoamPendingCheckInError.notSaved
        }
        return saved
    }

    /// `completeNode` writes the record before the POST. A fresh attempt requires an empty slot.
    /// A re-verify reuses the same attempt id and stores `uncertain: true`.
    public static func begin(_ store: RoamPendingCheckInStoring, key: String, ownerID: String, poiID: String, attemptID: String, reverify: Bool) throws -> RoamPendingCheckInRecord {
        guard !attemptID.isEmpty else { throw RoamPendingCheckInError.invalid }
        let existing = try read(store, key: key, ownerID: ownerID, poiID: poiID)
        if reverify {
            guard existing?.attemptID == attemptID else { throw RoamPendingCheckInError.invalid }
        } else if existing != nil {
            throw RoamPendingCheckInError.invalid
        }
        let record = RoamPendingCheckInRecord(ownerID: ownerID, poiID: poiID, attemptID: attemptID, uncertain: reverify)
        try write(store, key: key, record: record)
        guard let saved = try read(store, key: key, ownerID: ownerID, poiID: poiID), saved.attemptID == attemptID else {
            throw RoamPendingCheckInError.notSaved
        }
        return saved
    }

    /// `clearPending`: removes the record and the `:photo` sibling only when the attempt id matches.
    public static func clear(_ store: RoamPendingCheckInStoring, key: String, ownerID: String, poiID: String, attemptID: String) throws -> Bool {
        guard let current = try read(store, key: key, ownerID: ownerID, poiID: poiID), current.attemptID == attemptID else { return false }
        store.set(nil, forKey: photoKey(key))
        if store.data(forKey: photoKey(key)) != nil { throw RoamPendingCheckInError.notRemoved }
        store.set(nil, forKey: key)
        if try read(store, key: key, ownerID: ownerID, poiID: poiID) != nil { throw RoamPendingCheckInError.notRemoved }
        return true
    }

    /// `complete` success callback. `unknownBefore` is `reverify || stored.uncertain`.
    /// `receiptAccepted` is the page's `ok` (code 200, matching poi, coupon, needRedeem bool, completed/alreadyClaimed shape).
    public static func step(code: String, message: String?, receiptAccepted: Bool, unknownBefore: Bool) -> RoamPendingCompleteStep {
        let rejected = code == "500" && message.map(prewriteRejections.contains) == true
        if !receiptAccepted && !rejected { return .unknown }
        if rejected && unknownBefore { return .keepPreviousUnknown(message: message ?? "") }
        return .clear
    }

    /// The page's `ok` predicate for `POST /api/city/nodes/{id}/complete`.
    public static func receiptAccepted(code: String, poiID: String, data: [String: Any]?) -> Bool {
        guard code == "200", let data, matchesPoi(data, poiID: poiID), validCoupon(data) else { return false }
        guard bool(data["needRedeem"]) != nil, let needRedeem = bool(data["needRedeem"]) else { return false }
        if let completed = value(data["completed"]) {
            guard let flag = bool(completed), flag != needRedeem else { return false }
        }
        if value(data["alreadyClaimed"]) != nil, bool(data["alreadyClaimed"]) == nil { return false }
        return true
    }

    private static func matchesPoi(_ data: [String: Any], poiID: String) -> Bool {
        for key in ["poiId", "id"] where data.keys.contains(key) {
            guard id(data[key]) == poiID else { return false }
        }
        return true
    }

    private static func validCoupon(_ data: [String: Any]) -> Bool {
        if bool(data["needRedeem"]) == true { return id(data["couponId"]) != nil }
        return true
    }

    private static func value(_ raw: Any?) -> Any? {
        if raw is NSNull { return nil }
        return raw
    }

    private static func bool(_ raw: Any?) -> Bool? {
        guard let raw = value(raw) else { return nil }
        if let flag = raw as? Bool { return flag }
        guard let number = raw as? NSNumber, CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func write(_ store: RoamPendingCheckInStoring, key: String, record: RoamPendingCheckInRecord) throws {
        var object: [String: Any] = [
            "attemptId": record.attemptID,
            "ownerId": record.ownerID,
            "poiId": record.poiID,
            "v": 1
        ]
        if record.uncertain { object["uncertain"] = true }
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            throw RoamPendingCheckInError.notSaved
        }
        store.set(data, forKey: key)
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() {
            return number.intValue
        }
        return nil
    }

    private static func id(_ value: Any?) -> String? {
        if let number = int(value), number > 0, JourneyLoopSource.isID(String(number)) { return String(number) }
        if let text = value as? String, JourneyLoopSource.isID(text) { return text }
        return nil
    }
}