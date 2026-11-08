import Foundation

/// club/detail leaderboard + member strip parity (pure presentation logic).
public enum ClubDetailRankingPort {
    public enum Row<ID: Hashable>: Equatable where ID: Equatable {
        case member(rank: Int, id: ID, isMe: Bool)
        case gap(hidden: Int)
    }

    /// Mini `foldLeaderboard`: <= 6 rows show everything; otherwise top 3, a "⋯ N hidden" row, then
    /// the last 3 (widened to start one row before the viewer when the viewer ranks 4th or lower).
    public static func fold<ID: Hashable>(_ ids: [ID], me: ID?) -> [Row<ID>] {
        let rows = ids.enumerated().map { Row<ID>.member(rank: $0.offset + 1, id: $0.element, isMe: me != nil && $0.element == me) }
        guard rows.count > 6 else { return rows }
        var tailStart = rows.count - 3
        if let me, let myIndex = ids.firstIndex(of: me), myIndex >= 3 {
            tailStart = min(tailStart, max(3, myIndex - 1))
        }
        var out = Array(rows[0..<3])
        let hidden = tailStart - 3
        if hidden > 0 { out.append(.gap(hidden: hidden)) }
        return out + Array(rows[tailStart...])
    }

    /// `1小时5分` / `45分`; 0, negative or missing is an em dash (no valid timing), never "0 minutes".
    public static func durationText(minutes: Double?) -> String {
        guard let minutes, minutes.isFinite, minutes > 0 else { return "—" }
        let total = Int(minutes.rounded(.down))
        guard total > 0 else { return "—" }
        let hours = total / 60, rest = total % 60
        return hours > 0 ? "\(hours)小时\(rest)分" : "\(total)分"
    }

    /// One decimal place, e.g. `15.0` (mini `toFixed(1)`), so rows never mix `15` and `42.3`.
    public static func oneDecimal(_ value: Double?) -> String { String(format: "%.1f", value ?? 0) }

    /// Localization key for the empty leaderboard of the current sort.
    public static func emptyKey(sort: String) -> String {
        switch sort { case "mileage": return "mileage"; case "duration": return "duration"; default: return "composite" }
    }

    public struct MemberStrip: Equatable {
        public let shownIndexes: [Int]
        public let overflow: Int
    }

    /// Up to four member avatars and a fifth "+N" slot when the real total exceeds what is shown.
    public static func memberStrip(loaded: Int, total: Int?) -> MemberStrip {
        let shown = min(max(loaded, 0), 4)
        let known = max(total ?? loaded, loaded)
        return .init(shownIndexes: Array(0..<shown), overflow: max(known - shown, 0))
    }
}
