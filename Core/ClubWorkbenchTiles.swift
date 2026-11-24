import Foundation

/// Manage-tab tiles 待核销 and 本周场次. A missing read stays nil so the tile can hide.
public enum ClubWorkbenchTiles {
    /// `topicOverview.pendingVerifyCount`. A missing or non-integer field is unknown.
    public static func pendingVerifyCount(_ overview: ClubGovernanceValue) -> Int? {
        guard case .integer(let count) = overview["pendingVerifyCount"], count >= 0 else { return nil }
        return count
    }

    /// Sessions in the current Shanghai week (Monday–Sunday) that this month snapshot fully covers.
    /// A truncated read, or a week that crosses the snapshot month, stays nil.
    public static func sessionsThisWeek(_ snapshot: ClubCalendarSessionsSnapshot, now: Date = Date()) -> Int? {
        guard !snapshot.truncated else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
        calendar.firstWeekday = 2
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now),
              let end = calendar.date(byAdding: .day, value: 6, to: interval.start) else { return nil }
        let startKey = dayKey(interval.start, calendar)
        let endKey = dayKey(end, calendar)
        guard startKey.hasPrefix(snapshot.month.key), endKey.hasPrefix(snapshot.month.key) else { return nil }
        return snapshot.sessions.filter { $0.state != .cancelled && $0.day.id >= startKey && $0.day.id <= endKey }.count
    }

    private static func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
