import Foundation

/// Client checks from `pages/club/event-ops/index.js` and `pages/club/utils/weekly-schedule-window.js`.
/// The series create body is still `POST api/club/event-ops/series/create`. The server remains authoritative.
public enum ClubEventOpsFormRules {
    public static let maxFutureDays = 90
    public static let maxOccurrences = 64

    /// Hide the capacity field when one session sells more than one ticket (`sessionTicketCount > 1`).
    public static func showsCapacity(sessionTicketCount: Int) -> Bool { sessionTicketCount <= 1 }

    /// Offer-minutes readout. Out of 5...1440 is blank; 1440 is 「1 天」.
    public static func offerWindowText(minutes: Int) -> String {
        guard (5...1440).contains(minutes) else { return "" }
        if minutes % 1440 == 0 { return "\(minutes / 1440) 天" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时" }
        if minutes < 60 { return "\(minutes) 分钟" }
        return "\(minutes / 60) 小时 \(minutes % 60) 分"
    }

    /// Weekly occurrences that fit in the 90 Shanghai days that begin on `startDate`.
    /// The first date itself must fall on today through today + 90 days; a date outside that returns 0.
    /// Keys are `yyyy-MM-dd`, compared as civil dates. 90 / 7 + 1 is 13.
    public static func maxWeeklyOccurrences(startDate: String, todayKey: String) -> Int {
        guard let start = dayNumber(startDate), let today = dayNumber(todayKey) else { return 0 }
        if start < today || start > today + maxFutureDays { return 0 }
        return min(maxOccurrences, maxFutureDays / 7 + 1)
    }

    public static func weeklyHorizonMessage(max: Int) -> String {
        "首次日期起 90 天内最多可排 \(max) 期"
    }

    private static func dayNumber(_ key: String) -> Int? {
        let parts = key.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let actual = calendar.dateComponents([.year, .month, .day], from: date)
        guard actual.year == year, actual.month == month, actual.day == day else { return nil }
        return Int(date.timeIntervalSince1970 / 86_400)
    }
}
