import Foundation

/// mp-journey r3: MP 游玩工具 本局用时 · 当前得分 · 同行者榜 第 N 名 (`pages/play/index.wxml:349-357` `sessStats`), built
/// the way `pages/play/utils/play-hud-overlays.js` `loadSessionStats` / `scoreScreen` build it from
/// `GET /api/orient/scoring/session/{id}` plus the optional `/leaderboard` read.
public enum PlayToolsSessionStats: Equatable {
    /// MP `state: 'loading'`: one static row 本局用时 · 当前得分 …
    case loading
    /// MP `state: 'ok'`. `elapsed` nil hides 本局用时 (MP `wx:if="{{sessStats.elapsed}}"`); `rank` nil leaves 同行者榜
    /// without a value.
    case ready(elapsed: String?, score: String, rank: Int?, provisional: Bool)
    /// MP `state: 'error'`: 暂时没有读到 · 重试.
    case failed

    /// MP `scoreScreen`: the board counts only when it is for the same session; elapsed is the board's own `me.elapsedMs`,
    /// else the session's `startedAt` to `endedAt` (ended) or to now.
    /// `final` is ended (status 1 or 2) with no open dispute window; anything else is 暂列 (provisional).
    public static func project(score: OrientSessionScore, board: OrientSessionLeaderboard?, now: Date = Date()) -> PlayToolsSessionStats {
        let sameBoard = board.flatMap { $0.sessionID == score.sessionID ? $0 : nil }
        let me = sameBoard?.me
        let ended = score.status == 1 || score.status == 2
        let windowOpen: Bool = {
            guard ended, let deadline = score.disputeWindowDeadline else { return false }
            guard let date = parseDeadline(deadline) else { return true }
            return date > now
        }()
        let rank = me.flatMap { $0.rank > 0 ? $0.rank : nil }
        // MP `scoreScreen`: the board's `me.elapsedMs` first; else `startedAt → endedAt` (ended) or `startedAt → now`.
        var elapsed = me?.elapsedMs.map(clock(milliseconds:))
        if elapsed == nil, let started = score.startedAt {
            let end: Date? = ended ? score.endedAt : now
            if let end { elapsed = clock(milliseconds: Int((end.timeIntervalSince(started) * 1000).rounded())) }
        }
        return .ready(elapsed: elapsed, score: points(centi: score.totalCenti),
                      rank: rank, provisional: !(ended && !windowOpen))
    }

    /// MP: `ORIENT_SCORING_DISABLED` / `ORIENT_SCORING_NOT_APPLICABLE` mean scoring is off here, so no row shows (not an error).
    public static func hidesRows(for error: Error) -> Bool {
        guard let failure = error as? OrientSessionFailure else { return false }
        let off: Set<String> = ["ORIENT_SCORING_DISABLED", "ORIENT_SCORING_NOT_APPLICABLE"]
        return off.contains(failure.errorCode ?? "") || off.contains(failure.err ?? "")
    }

    /// MP `points`: centi / 100, whole numbers without decimals, otherwise one decimal (17, 17.5, -3).
    public static func points(centi: Int) -> String {
        let tenths = (Double(centi) / 10).rounded()
        if Int(tenths) % 10 == 0 { return String(Int(tenths) / 10) }
        return String(format: "%.1f", tenths / 10)
    }

    /// MP `play-board-view.js` `clock`: mm:ss, or h:mm:ss from one hour; negative is 00:00.
    public static func clock(milliseconds: Int) -> String {
        guard milliseconds > 0 else { return "00:00" }
        let seconds = milliseconds / 1000
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60, rest = seconds % 60
        let mm = String(format: "%02d", minutes), ss = String(format: "%02d", rest)
        return hours > 0 ? "\(hours):\(mm):\(ss)" : "\(mm):\(ss)"
    }

    /// ISO 8601 or the backend's `yyyy-MM-dd HH:mm:ss` in China time (MP `toTimestamp`).
    static func parseDeadline(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: trimmed) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        for pattern in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy/MM/dd HH:mm:ss"] {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}

/// mp-journey-b r3: MP 同行者榜 on a city run (`pages/play/index.js` `openBoard`, mode 1 with `routeState.sessionId`):
/// the orient-scoring board `/api/orient/scoring/session/{id}/leaderboard`, projected the way
/// `pages/play/utils/play-board-view.js` `project` does for SCORE / ROUTE boards.
public struct PlayOrientBoard: Equatable {
    public struct Row: Equatable, Identifiable {
        public let id: String
        public let rank: Int
        /// MP nickname: 我 for the player's own row, else 同行者 (the orient board carries no names or avatars).
        public let mine: Bool
        /// SCORE: MP `centi` (two decimals, "17.50"); nil on a ROUTE board.
        public let points: String?
        /// ROUTE: 已到达结局 / 尚未到达结局.
        public let reachedEnding: Bool
        /// MP `elapsedText`: `clock(elapsedMs)`, nil = 用时待确认.
        public let elapsed: String?
    }
    public let mode: OrientSessionLeaderboard.Mode
    public let rows: [Row]
    public let me: Row?

    public init(_ board: OrientSessionLeaderboard) {
        mode = board.mode
        func row(_ raw: OrientSessionLeaderboard.Row) -> Row {
            Row(id: raw.rowKey, rank: raw.rank, mine: raw.mine,
                points: board.mode == .score ? Self.centi(raw.scoreCenti) : nil,
                reachedEnding: raw.reachedEnding,
                elapsed: raw.elapsedMs.map(PlayToolsSessionStats.clock(milliseconds:)))
        }
        rows = board.list.map(row)
        me = board.me.map(row)
    }

    /// MP `orient-score-view.js` `centi` without the 分 suffix: 1750 → "17.50", -5 → "-0.05".
    public static func centi(_ value: Int) -> String {
        let digits = String(value.magnitude)
        let padded = String(repeating: "0", count: max(0, 3 - digits.count)) + digits
        let whole = String(padded.dropLast(2)), fraction = String(padded.suffix(2))
        let sign = value < 0 ? "-" : ""
        return sign + whole + "." + fraction
    }
}

/// mp-journey-b r3: result of the MP `openBoard` orient read. `.scoringOff` (`ORIENT_SCORING_DISABLED` /
/// `ORIENT_SCORING_NOT_APPLICABLE`) is the only case that falls back to `/api/play/leaderboard`; any other failure is
/// the board error (MP: "Network/permission failures do not").
public enum PlayOrientBoardRead: Equatable {
    case board(PlayOrientBoard)
    case scoringOff
    case failed
}
