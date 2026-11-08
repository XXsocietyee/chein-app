import Foundation

/// Port-2: the mini-program datetime range sheet shows a "span" badge (N days H hours M minutes)
/// next to the start/end columns (utils/datetime-range.js `spanMinutes` + `formatSpan`).
/// Pure value logic; never mutates a draft and never publishes.
public struct CouponValiditySpan: Equatable {
    public let days: Int
    public let hours: Int
    public let minutes: Int
    public var totalMinutes: Int { days * 1440 + hours * 60 + minutes }

    public init(totalMinutes: Int) {
        let safe = max(0, totalMinutes)
        days = safe / 1440
        hours = (safe % 1440) / 60
        minutes = safe % 60
    }

    /// nil when either end is missing or the end is not strictly after the start
    /// (the mini-program shows no badge then, and the blocker text explains why).
    public static func make(start: Date?, end: Date?) -> CouponValiditySpan? {
        guard let start, let end,
              start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite else { return nil }
        let seconds = end.timeIntervalSince(start)
        let whole = Int((seconds / 60).rounded(.down))
        guard whole > 0 else { return nil }
        return CouponValiditySpan(totalMinutes: whole)
    }
}
