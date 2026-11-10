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

/// Page facts for 收益明细. The live read stays `WalletCommerceService.ledger(.income)`,
/// which already posts `api/user/balance/list`. This value does not register a route,
/// open a host, or turn on payment, payout, withdrawal, or virtual goods.
/// Unknown money is an em dash (U+2014), never `0`. A decoded zero stays `0`.
public enum WalletIncomeDetailPageModel {
    public static let unknownMoney = "\u{2014}"
    public static let existingReadPath = "api/user/balance/list"
    public static let registersRoute = false
    public static let opensHost = false
    public static let showsMerchantChoice = false
    public static let showsOrganizerShare = false
    public static let enablesPayment = false
    public static let enablesPayout = false
    public static let enablesWithdrawal = false
    public static let enablesVirtualGoods = false

    public enum Phase: String, Equatable, Sendable {
        case loading, empty, error, unknown, ready
    }

    public struct State: Equatable, Sendable {
        public let phase: Phase
        public let moneyText: String
        public init(phase: Phase, moneyText: String) {
            self.phase = phase
            self.moneyText = moneyText
        }
    }

    public enum Accessibility {
        public static let screen = "wallet.income.detail"
        public static let close = "wallet.income.detail.close"
        public static let retired = "wallet.income.detail.retired"
        public static let empty = "wallet.ledger.empty"
        public static let loadMore = "wallet.ledger.loadMore"
        public static let unknownMoney = "wallet.income.detail.unknownMoney"
        public static let loading = "wallet.income.detail.loading"
        public static let error = "wallet.income.detail.error"
        public static let rowPrefix = "wallet.ledger."
        public static let openPrefix = "wallet.income.detail.open."
        public static let dateGroupPrefix = "wallet.ledger.dateGroup."
    }

    /// List phase. Loading wins. A page that has not loaded is unknown, not empty and not zero.
    public static func list(loading: Bool, failed: Bool, hasLoadedPage: Bool, rowCount: Int) -> State {
        if loading { return State(phase: .loading, moneyText: "") }
        if failed { return State(phase: .error, moneyText: unknownMoney) }
        guard hasLoadedPage, rowCount >= 0 else { return State(phase: .unknown, moneyText: unknownMoney) }
        if rowCount == 0 { return State(phase: .empty, moneyText: unknownMoney) }
        return State(phase: .ready, moneyText: "")
    }

    /// Nil is unknown. A present amount, including zero, keeps `WalletAmount.text`.
    public static func money(_ amount: WalletAmount?) -> String {
        guard let amount else { return unknownMoney }
        return amount.text
    }

    /// Ready list plus a missing amount is the unknown state. Known zero stays ready and `0`.
    public static func amount(_ list: State, _ amount: WalletAmount?) -> State {
        guard list.phase == .ready else { return list }
        guard let amount else { return State(phase: .unknown, moneyText: unknownMoney) }
        return State(phase: .ready, moneyText: amount.text)
    }
}
