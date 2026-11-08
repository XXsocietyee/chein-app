import Foundation

/// Pure reserve-window presentation model (IWP-6).
///
/// UX clipping only. The server stays the authority on `startAt > now` and on unit
/// validity; this type merely avoids offering days that can never succeed.
public struct BundleReserveWindow: Equatable {
    public static let maxDays = 14

    public struct Day: Equatable {
        /// Midnight (in the injected calendar) that starts this day, epoch ms.
        public let dayStartMs: Int64
        /// Earliest selectable instant inside this day, epoch ms (inclusive).
        public let earliestMs: Int64
        /// Latest selectable instant inside this day, epoch ms (inclusive).
        public let latestMs: Int64
        public func contains(_ ms: Int64) -> Bool { ms >= earliestMs && ms <= latestMs }
    }

    public let days: [Day]
    public var isEmpty: Bool { days.isEmpty }
    public var earliestMs: Int64? { days.first?.earliestMs }
    public var latestMs: Int64? { days.last?.latestMs }

    public func contains(_ ms: Int64) -> Bool { days.contains { $0.contains(ms) } }

    /// - Parameters:
    ///   - validFromMs / validToMs: server unit validity (nil = unbounded on that side).
    ///   - serverNowMs: server clock; when provided the device clock is ignored.
    ///   - deviceNowMs: fallback only when the server did not provide `now`.
    ///   - calendar: injected for deterministic day boundaries.
    public static func make(validFromMs: Int64?, validToMs: Int64?, serverNowMs: Int64?,
                            deviceNowMs: Int64, calendar: Calendar = .current) -> BundleReserveWindow {
        let now = serverNowMs ?? deviceNowMs
        // Server requires startAt > now, so the first selectable instant is now + 1.
        let (bumped, overflow) = now.addingReportingOverflow(1)
        guard !overflow else { return BundleReserveWindow(days: []) }
        let lower = max(bumped, validFromMs ?? bumped)
        guard let lowerDate = date(lower) else { return BundleReserveWindow(days: []) }
        var firstDayStart = calendar.startOfDay(for: lowerDate)
        var days: [Day] = []
        for _ in 0..<maxDays {
            guard let next = calendar.date(byAdding: .day, value: 1, to: firstDayStart) else { break }
            let dayStart = Int64((firstDayStart.timeIntervalSince1970 * 1_000).rounded())
            let dayEnd = Int64((next.timeIntervalSince1970 * 1_000).rounded()) - 1
            let upper = min(dayEnd, validToMs ?? dayEnd)
            let earliest = max(dayStart, lower)
            if earliest <= upper {
                days.append(Day(dayStartMs: dayStart, earliestMs: earliest, latestMs: upper))
            }
            if let validToMs, validToMs <= dayEnd { break }
            firstDayStart = next
        }
        return BundleReserveWindow(days: days)
    }

    private static func date(_ ms: Int64) -> Date? {
        let seconds = Double(ms) / 1_000
        guard seconds.isFinite, abs(seconds) < 4_000_000_000_000 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
