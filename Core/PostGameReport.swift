import Foundation
import CoreFoundation

// §九 U08-01 / U08-05 post-game facts, ported from mini-program `subpackageJourney/utils/journey-view.js`
// (`reportView`, `memoryView`, `rankView`) and `pages/play/utils/finish-result.js`.
// Wire shapes: hengyin `PlayerRunReportVO`, `PlayerJourneyMemoryVO`, `ScopedLeaderboardVO`, orient team ranking rows.
// Unknown, NOT_SCORED and null stay nil. They are never 0. Reading never finishes a run, grants a reward or ranks anyone.

public enum PostGameCompletion: String, Equatable, Sendable {
    case legitimate = "LEGITIMATE_COMPLETION"
    case assisted = "ASSISTED_COMPLETION"
    case ended = "ENDED"
    case inProgress = "IN_PROGRESS"
    case notStarted = "NOT_STARTED"
}

/// One P7 battle report (`GET /api/play/player-journey/report`).
public struct PostGameRunReport: Equatable, Sendable {
    public struct Node: Equatable, Sendable {
        public enum Mode: Equatable, Sendable { case skipped, revealed }
        public let id: String
        public let name: String?
        public let mode: Mode?
        /// Nil: this node is not scored. Only `scored == true` with a number fills it.
        public let score: Int?
        /// Player's own station photo (`node.photoUrl`). Empty and non-strings stay nil.
        public let photoURL: String?
    }

    public let completion: PostGameCompletion?
    public let runState: String?
    /// `scopeKind != RUN`: legacy topic history, not one run.
    public let legacyScope: Bool
    public let runID: String?
    public let topicID: String?
    public let activityID: String?
    public let completedAt: Date?
    public let completedNodes: Int?
    public let totalNodes: Int?
    public let elapsedSeconds: Int?
    public let elapsedSource: String?
    /// `score.state == SCORED` with a number. Nil means "this run is not scored".
    public let score: Int?
    /// Only when scored and above 0.
    public let penalties: Int?
    /// `rank.qualified == true` with a number. Completed-node rank, not a net score.
    public let rank: Int?
    /// Completed node count behind `rank`.
    public let rankScore: Int?
    public let nodes: [Node]
    /// Nodes whose `completionMode` is `SKIPPED` or `REVEALED`. The settle cell shows only when this is above 0.
    public let assistedCount: Int
    /// `RUN_START_MODE_LABEL`: `DESK` → 桌面完成, `ALT` → 替代站开局. A normal start (`null`) stays nil.
    public let startModeText: String?
    /// Theme/activity backpack item count (`rewardsScope == TOPIC_ACTIVITY`). Never "earned this run".
    public let backpackItems: Int?

    public var showsAssistedCount: Bool { assistedCount > 0 }
    public var showsStartMode: Bool { startModeText != nil }

    /// `runState == COMPLETED` with a legitimate completion.
    public var win: Bool { runState == "COMPLETED" && completion == .legitimate }
    public var finished: Bool { runState == "COMPLETED" || runState == "ENDED" }
    public var inProgress: Bool { runState == "IN_PROGRESS" }

    /// `completed/total`, `completed/?`, or nil when the server gave no count.
    public var nodesText: String? {
        guard let completedNodes else { return nil }
        return "\(completedNodes)/" + (totalNodes.map(String.init) ?? "?")
    }

    public var elapsedText: String? { PostGameText.duration(elapsedSeconds) }

    /// `journey-view.js` `RUN_START_MODE_LABEL`. Anything else, including a missing field, is a normal start.
    static func label(forStartMode value: Any?) -> String? {
        switch PostGameJSON.string(value) {
        case "DESK": return "桌面完成"
        case "ALT": return "替代站开局"
        default: return nil
        }
    }
    public var dateText: String? { completedAt.map { PostGameText.beijingDay($0) } }

    public static func decode(_ data: Data?) -> PostGameRunReport? {
        guard let object = PostGameJSON.object(data) else { return nil }
        let score = object["score"] as? [String: Any] ?? [:]
        let scored = PostGameJSON.string(score["state"]) == "SCORED" ? PostGameJSON.int(score["score"]) : nil
        let penalties = scored == nil ? nil : PostGameJSON.int(score["penalties"]).flatMap { $0 > 0 ? $0 : nil }
        let rank = object["rank"] as? [String: Any] ?? [:]
        let ranked = (rank["qualified"] as? Bool) == true ? PostGameJSON.int(rank["rank"]) : nil
        let total = PostGameJSON.int(object["totalNodes"]).flatMap { $0 > 0 ? $0 : nil }
        let nodes = (object["nodes"] as? [Any] ?? []).compactMap { value -> Node? in
            guard let row = value as? [String: Any], let id = PostGameJSON.id(row["nodeId"]) else { return nil }
            let mode: Node.Mode?
            switch PostGameJSON.string(row["completionMode"]) {
            case "SKIPPED": mode = .skipped
            case "REVEALED": mode = .revealed
            default: mode = nil
            }
            let score = (row["scored"] as? Bool) == true ? PostGameJSON.int(row["score"]) : nil
            return Node(id: id, name: PostGameJSON.string(row["name"]), mode: mode, score: score,
                        photoURL: PostGameJSON.string(row["photoUrl"]))
        }
        let items: Int?
        if PostGameJSON.string(object["rewardsState"]) == "AVAILABLE", let rewards = object["rewards"] as? [String: Any] {
            let count = ["items", "cards", "objects"].lazy.map { (rewards[$0] as? [Any])?.count ?? 0 }.first { $0 > 0 } ?? 0
            items = count > 0 ? count : nil
        } else {
            items = nil
        }
        let startedAt = PostGameJSON.date(object["startedAt"])
        let completedAt = PostGameJSON.date(object["completedAt"])
        let closeAt = completedAt ?? PostGameJSON.date(object["endedAt"])
        let explicitElapsed = PostGameJSON.int(object["elapsedSeconds"]).flatMap { $0 >= 0 ? $0 : nil }
        let elapsed: Int? = explicitElapsed ?? {
            guard let startedAt, let closeAt else { return nil }
            let seconds = Int(closeAt.timeIntervalSince(startedAt).rounded())
            return (1...(7 * 24 * 3600)).contains(seconds) ? seconds : nil
        }()
        return PostGameRunReport(
            completion: PostGameJSON.string(object["completionKind"]).flatMap(PostGameCompletion.init(rawValue:))
                ?? PostGameJSON.string(object["runState"]).flatMap(PostGameCompletion.init(rawValue:)),
            runState: PostGameJSON.string(object["runState"]),
            legacyScope: PostGameJSON.string(object["scopeKind"]) != "RUN",
            runID: PostGameJSON.id(object["runId"]), topicID: PostGameJSON.id(object["topicId"]),
            activityID: PostGameJSON.id(object["activityId"]),
            completedAt: closeAt,
            completedNodes: PostGameJSON.int(object["completedNodes"]).flatMap { $0 >= 0 ? $0 : nil },
            totalNodes: total, elapsedSeconds: elapsed, elapsedSource: PostGameJSON.string(object["elapsedSource"]),
            score: scored, penalties: penalties, rank: ranked,
            rankScore: ranked == nil ? nil : PostGameJSON.int(rank["score"]),
            nodes: nodes, assistedCount: nodes.filter { $0.mode != nil }.count,
            startModeText: Self.label(forStartMode: object["runStartMode"]), backpackItems: items)
    }
}

/// `finish-result.js resolveFinishResult`: the finish-screen result word comes from the server report.
/// Photos, an end time or reading the last page are not a legitimate completion (U08-01 acceptance).
public enum PostGameFinishResult: Equatable, Sendable {
    case cleared
    case assisted
    case ended
    case chapterDone
    /// Every stop is marked done but the report is still loading or could not be read: no result word.
    case unknown

    public enum ReportState: Equatable, Sendable { case pending, failed, loaded(PostGameCompletion?) }

    /// `topicCompleted` is the server's own completion fact from the arrival receipt. `allDone` alone is not.
    public static func resolve(report: ReportState, topicCompleted: Bool, allDone: Bool, chapterDone: Bool) -> PostGameFinishResult {
        if case .loaded(let completion?) = report {
            switch completion {
            case .legitimate: return .cleared
            case .assisted: return .assisted
            case .ended: return .ended
            case .inProgress, .notStarted: break
            }
        }
        if topicCompleted { return .cleared }
        if case .loaded = report {} else if allDone { return .unknown }
        return chapterDone ? .chapterDone : .ended
    }

    public var win: Bool { self == .cleared }
}

/// One P8 memory (`GET /api/play/player-journey/memory`). Own completed stops and own photos only.
public struct PostGameRunMemory: Equatable, Sendable {
    public struct Moment: Equatable, Sendable {
        public let id: String
        public let name: String?
        public let text: String?
        /// https only.
        public let pictureURL: URL?
        public let checkinTime: Date?
        /// Beijing day, written only when it changes from the previous moment.
        public let dayText: String?
        public let timeText: String?
    }

    public let runID: String?
    public let moments: [Moment]
    /// Only above 1 ("N people together"); 0 or 1 or unknown is nil.
    public let companions: Int?
    /// `photoShareCapability == AVAILABLE`. Otherwise other members' private photos are not shown.
    public let peerPhotosAvailable: Bool
    public let photoShareReason: String?

    public var hasPhotos: Bool { moments.contains { $0.pictureURL != nil } }
    public var isEmpty: Bool { moments.isEmpty && companions == nil }

    public static func decode(_ data: Data?) -> PostGameRunMemory? {
        guard let object = PostGameJSON.object(data) else { return nil }
        var previousDay: String?
        let moments = (object["moments"] as? [Any] ?? []).enumerated().compactMap { index, value -> Moment? in
            guard let row = value as? [String: Any] else { return nil }
            let at = PostGameJSON.date(row["checkinTime"])
            let day = at.map { PostGameText.beijingDay($0) }
            let shownDay = day != nil && day != previousDay ? day : nil
            previousDay = day
            let id = PostGameJSON.id(row["nodeId"]) ?? "moment-\(index)"
            return Moment(id: id, name: PostGameJSON.string(row["name"]), text: PostGameJSON.string(row["fragmentText"]),
                          pictureURL: PostGameJSON.httpsURL(row["picUrl"]), checkinTime: at, dayText: shownDay,
                          timeText: at.map { PostGameText.beijingClock($0) })
        }
        let participants = PostGameJSON.int(object["participantCount"])
        return PostGameRunMemory(runID: PostGameJSON.id(object["runId"]), moments: moments, companions: participants.flatMap { $0 > 1 ? $0 : nil },
                                 peerPhotosAvailable: PostGameJSON.string(object["photoShareCapability"]) == "AVAILABLE",
                                 photoShareReason: PostGameJSON.string(object["photoShareReason"]))
    }
}

/// §23.4 `GET /api/rank/list` (`ScopedLeaderboardVO`) and `GET /api/orient/team/ranking` rows.
public struct PostGameRankBoard: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let id: String
        public let rank: Int
        public let name: String?
        public let avatarURL: URL?
        /// Nil renders unknown, never 0.
        public let score: Int?
        /// Team rows: done count over total tasks.
        public let total: Int?
        /// Team rows: active members.
        public let active: Int?
        public let mine: Bool
    }

    public enum Basis: Equatable, Sendable { case completedNodes, teamTasks }

    public let entries: [Entry]
    public let basis: Basis?
    public let myRank: Int?
    public let rankedMembers: Int?
    /// city/country only: runs with no frozen geography.
    public let unattributedRuns: Int?
    /// Runs with completions but no valid paid registration or pass. Not ranked.
    public let unverifiedRuns: Int?
    public let periodStart: Date?
    /// Exclusive.
    public let periodEnd: Date?

    /// "top N%" only when the server gave the ranked total and there are 5+ ranked players.
    public var topPercent: Int? {
        guard let myRank, let rankedMembers, rankedMembers >= 5, myRank >= 1, myRank <= rankedMembers else { return nil }
        return max(1, Int((Double(myRank) / Double(rankedMembers) * 100).rounded(.up)))
    }

    /// Server week window in Beijing days; the exclusive end is shown as the day before.
    public var windowText: String? {
        guard let periodStart, let periodEnd else { return nil }
        return PostGameText.beijingDay(periodStart) + " – " + PostGameText.beijingDay(periodEnd.addingTimeInterval(-1))
    }

    public enum Decoded: Equatable, Sendable {
        case board(PostGameRankBoard)
        case empty
        /// The server answered another scope, scope id or period. Never shown as the selected board.
        case mismatch
        case malformed
    }

    /// `rankView`: entries without a numeric rank are dropped; `me` only with a numeric rank.
    public static func decodeScoped(_ data: Data?, scope: String, scopeID: String?, period: String) -> Decoded {
        guard let object = PostGameJSON.object(data) else { return .malformed }
        let echoedID = PostGameJSON.id(object["scopeId"]) ?? PostGameJSON.string(object["scopeId"]) ?? ""
        guard PostGameJSON.string(object["scope"]) == scope, echoedID == (scopeID ?? ""),
              PostGameJSON.string(object["period"]) == period else { return .mismatch }
        let me = object["me"] as? [String: Any]
        let myRank = me.flatMap { PostGameJSON.int($0["rank"]) }
        let myID = me.flatMap { PostGameJSON.id($0["memberId"]) }
        let entries = (object["entries"] as? [Any] ?? []).compactMap { value -> Entry? in
            guard let row = value as? [String: Any], let rank = PostGameJSON.int(row["rank"]) else { return nil }
            let member = PostGameJSON.id(row["memberId"])
            return Entry(id: (member ?? "anon") + ":" + String(rank), rank: rank, name: PostGameJSON.string(row["nickname"]),
                         avatarURL: PostGameJSON.httpsURL(row["avatar"]), score: PostGameJSON.int(row["score"]), total: nil, active: nil,
                         mine: member != nil && member == myID)
        }
        let coverage = object["coverage"] as? [String: Any] ?? [:]
        let board = PostGameRankBoard(
            entries: entries, basis: PostGameJSON.string(object["scoreBasis"]) == "COMPLETED_NODES" ? .completedNodes : nil,
            myRank: myRank, rankedMembers: PostGameJSON.int(coverage["rankedMembers"]),
            unattributedRuns: PostGameJSON.int(coverage["unattributedRuns"]).flatMap { $0 > 0 ? $0 : nil },
            unverifiedRuns: PostGameJSON.int(coverage["unverifiedRuns"]).flatMap { $0 > 0 ? $0 : nil },
            periodStart: period == "week" ? PostGameJSON.date(object["periodStart"]) : nil,
            periodEnd: period == "week" ? PostGameJSON.date(object["periodEnd"]) : nil)
        return entries.isEmpty && myRank == nil ? .empty : .board(board)
    }

    static let teamBoardLimit = 200

    /// Team-to-team ranking (`ownerType` 1 topic / 2 activity). This is not a member board inside one team.
    public static func decodeTeams(_ data: Data?) -> Decoded {
        guard let data, let rows = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else { return .malformed }
        let entries = rows.compactMap { value -> Entry? in
            guard let row = value as? [String: Any], let rank = PostGameJSON.int(row["rank"]),
                  let team = PostGameJSON.id(row["teamId"]) else { return nil }
            return Entry(id: "team:" + team, rank: rank, name: PostGameJSON.string(row["title"]), avatarURL: nil,
                         score: PostGameJSON.int(row["teamDoneCount"]), total: PostGameJSON.int(row["totalTasks"]),
                         active: PostGameJSON.int(row["activeCount"]), mine: (row["mine"] as? Bool) == true)
        }
        guard !entries.isEmpty else { return .empty }
        // A page at the server cap may be truncated, so it is not a total for "top N%".
        return .board(PostGameRankBoard(entries: entries, basis: .teamTasks, myRank: entries.first { $0.mine }?.rank,
                                        rankedMembers: entries.count >= teamBoardLimit ? nil : entries.count, unattributedRuns: nil, unverifiedRuns: nil,
                                        periodStart: nil, periodEnd: nil))
    }
}

public enum PostGameText {
    private static let beijing = TimeZone(secondsFromGMT: 8 * 3600)!

    /// `durationText`: `h:mm:ss` or `mm:ss`; nil (em dash) when unknown.
    public static func duration(_ seconds: Int?) -> String? {
        guard let seconds, seconds >= 0 else { return nil }
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// Server times are shown in Beijing time, not the phone's zone.
    public static func beijingDay(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d.%02d.%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func beijingClock(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = beijing
        return calendar
    }
}

enum PostGameJSON {
    static func object(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func int(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite, double.rounded() == double, abs(double) <= 9_007_199_254_740_991 else { return nil }
        return Int(double)
    }

    /// Positive id from a number or canonical digit string.
    static func id(_ value: Any?) -> String? {
        if let number = int(value) { return number > 0 ? String(number) : nil }
        guard let text = value as? String, JourneyLoopSource.isID(text) else { return nil }
        return text
    }

    static func string(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func httpsURL(_ value: Any?) -> URL? {
        guard let text = string(value), let url = URL(string: text), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        return url
    }

    /// `parseDate`: epoch millis, `yyyy-MM-dd HH:mm[:ss]` as Beijing time, or ISO 8601.
    static func date(_ value: Any?) -> Date? {
        if let millis = int(value) { return Date(timeIntervalSince1970: Double(millis) / 1000) }
        guard let text = string(value) else { return nil }
        let plain = DateFormatter()
        plain.locale = Locale(identifier: "en_US_POSIX")
        plain.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"] {
            plain.dateFormat = format
            if let date = plain.date(from: text) { return date }
        }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: text)
    }
}
