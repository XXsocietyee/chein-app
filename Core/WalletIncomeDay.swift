import Foundation

/// Income-detail row date (mini-program `scene-asset-income-detail.formatDate`):
/// 今天 / 昨天 / M月D日, compared by calendar day. Unparseable input stays raw.
public enum WalletIncomeDay: Equatable {
    case today, yesterday
    case monthDay(month: Int, day: Int)

    /// `createTime` is `yyyy-MM-dd HH:mm:ss` (or a bare `yyyy-MM-dd`) in server local time.
    public static func make(_ createTime: String?, now: Date = Date(),
                            calendar: Calendar = WalletIncomeDay.serverCalendar) -> WalletIncomeDay? {
        guard let raw = createTime?.trimmingCharacters(in: .whitespaces), raw.count >= 10 else { return nil }
        let parts = raw.prefix(10).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.month, from: date) == month, calendar.component(.day, from: date) == day
        else { return nil }
        let today = calendar.startOfDay(for: now)
        if date == today { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), date == yesterday { return .yesterday }
        return .monthDay(month: month, day: day)
    }

    public static var serverCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar
    }

    public func localizedTitle(isEnglish: Bool) -> String {
        switch self {
        case .today:
            return isEnglish ? "Today" : "今天"
        case .yesterday:
            return isEnglish ? "Yesterday" : "昨天"
        case .monthDay(let month, let day):
            if isEnglish {
                let names = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                let monthName = (1...12).contains(month) ? names[month] : "\(month)"
                return "\(monthName) \(day)"
            }
            return "\(month)月\(day)日"
        }
    }

    /// Groups ledger rows into Revolut-style date sections by server civil day while preserving exact row order.
    public static func group(
        _ rows: [WalletLedgerRow],
        now: Date = Date(),
        calendar: Calendar = serverCalendar
    ) -> [WalletLedgerDateGroup] {
        var groups: [WalletLedgerDateGroup] = []
        var indexByKey: [String: Int] = [:]

        for row in rows {
            let trimmed = row.createTime?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let datePrefix = trimmed.count >= 10 ? String(trimmed.prefix(10)) : trimmed
            let parsedDay = make(row.createTime, now: now, calendar: calendar)
            let groupKey: String
            if let parsedDay {
                switch parsedDay {
                case .today:
                    groupKey = "today:\(datePrefix)"
                case .yesterday:
                    groupKey = "yesterday:\(datePrefix)"
                case .monthDay(let m, let d):
                    groupKey = "monthDay:\(datePrefix):\(m)-\(d)"
                }
            } else {
                groupKey = datePrefix.isEmpty ? "unknown" : "raw:\(datePrefix)"
            }

            if let existingIndex = indexByKey[groupKey] {
                groups[existingIndex].rows.append(row)
            } else {
                indexByKey[groupKey] = groups.count
                groups.append(
                    WalletLedgerDateGroup(
                        id: groupKey,
                        day: parsedDay,
                        rawDatePrefix: datePrefix.isEmpty ? nil : datePrefix,
                        rows: [row]
                    )
                )
            }
        }
        return groups
    }
}

public struct WalletLedgerDateGroup: Equatable, Identifiable {
    public let id: String
    public let day: WalletIncomeDay?
    public let rawDatePrefix: String?
    public fileprivate(set) var rows: [WalletLedgerRow]

    public init(id: String, day: WalletIncomeDay?, rawDatePrefix: String?, rows: [WalletLedgerRow]) {
        self.id = id
        self.day = day
        self.rawDatePrefix = rawDatePrefix
        self.rows = rows
    }

    public func headerText(isEnglish: Bool) -> String {
        if let day {
            return day.localizedTitle(isEnglish: isEnglish)
        }
        if let rawDatePrefix, !rawDatePrefix.isEmpty {
            return rawDatePrefix
        }
        return isEnglish ? "Transactions" : "交易明细"
    }
}

/// Points-detail month grouping (mini-program `subpackageMember/points-history/rows.js`
/// `monthKey` / `groupByMonth` / `monthLabel`). Rows keep the server order (id descending);
/// adjacent rows of the same `createTime` month form one group. A row whose time cannot be
/// read goes to an "unknown time" group and is never dropped.
public struct WalletPointsMonthGroup: Equatable, Identifiable {
    public let id: String
    /// `YYYY-MM`, or nil for the unknown-time group.
    public let monthKey: String?
    public fileprivate(set) var rows: [WalletLedgerRow]

    public init(id: String, monthKey: String?, rows: [WalletLedgerRow]) {
        self.id = id; self.monthKey = monthKey; self.rows = rows
    }

    /// `YYYY-MM` from the first seven characters of `createTime`; nil when unreadable.
    public static func monthKey(_ createTime: String?) -> String? {
        guard let raw = createTime?.trimmingCharacters(in: .whitespacesAndNewlines), raw.count >= 7 else { return nil }
        let parts = raw.prefix(7).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
              parts[0].allSatisfy(\.isASCII), parts[0].allSatisfy(\.isNumber),
              let month = Int(parts[1]), (1...12).contains(month) else { return nil }
        return String(raw.prefix(7))
    }

    public func headerText(isEnglish: Bool) -> String {
        guard let monthKey, monthKey.count == 7, let month = Int(monthKey.suffix(2)), (1...12).contains(month) else {
            return isEnglish ? "Unknown time" : "时间未知"
        }
        let year = String(monthKey.prefix(4))
        if isEnglish {
            let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            return names[month - 1] + " " + year
        }
        return year + "年" + String(month) + "月"
    }

    public static func group(_ rows: [WalletLedgerRow]) -> [WalletPointsMonthGroup] {
        var groups: [WalletPointsMonthGroup] = []
        for row in rows {
            let key = monthKey(row.createTime)
            if let last = groups.last, last.monthKey == key {
                groups[groups.count - 1].rows.append(row)
            } else {
                groups.append(WalletPointsMonthGroup(id: (key ?? "unknown") + "-" + String(groups.count), monthKey: key, rows: [row]))
            }
        }
        return groups
    }
}
