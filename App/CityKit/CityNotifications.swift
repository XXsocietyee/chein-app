import Foundation
import UserNotifications
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// The three core-loop notifications (owner Q6, N1 · 系统触点 431:6562). Widgets come one release later.
//   1. 保护快结束 – "老麦咖啡馆的保护还剩 1 小时", actions 开护盾 · 60 积分 / 稍后. Scheduled locally from the
//      server's protection end, so it fires with the app closed.
//   2. 今天收租 – one daily summary at 20:00 with the rent the server reported when the app last read it.
//   3. 被拿走 – posted when a refresh finds a place gone. A server push for it (and for a live rent
//      total at 20:00) does not exist yet; the receipt lists it as a missing endpoint.
// Nothing asks for permission until the player asks for a reminder or holds a place.

enum CityNotifications {
    static let shieldCategory = "city.shield.ending"
    static let shieldAction = "city.shield.open"
    static let laterAction = "city.shield.later"
    private static let prefix = "city."
    /// mp-nav r3: a tap lands on the 漫游 tab (the City board is its map mode), routed by MPNotificationTapRouter like
    /// a subscribe-message `page`; before, the tap only opened the app wherever it was.
    static let tapPage = "pages/roam/index"

    /// Registers the shield category with its two actions (call once at launch or before scheduling).
    static func registerCategories(locale: Locale) {
        let copy = CityCopy(locale: locale)
        let shield = UNNotificationAction(identifier: shieldAction, title: copy("开护盾 · \(CityMonopolyRules.shieldCost) 积分", "Shield · \(CityMonopolyRules.shieldCost) pts"), options: [.foreground])
        let later = UNNotificationAction(identifier: laterAction, title: copy("稍后", "Later"), options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: shieldCategory, actions: [shield, later], intentIdentifiers: [], options: [])
        ])
    }

    /// "保护结束时提醒我" on another player's place (N09). Asks for permission on this tap.
    @MainActor static func remindProtectionEnd(place: CityPlace, at date: Date, locale: Locale) async -> Bool {
        guard await authorize(asking: true) else { return false }
        let copy = CityCopy(locale: locale)
        let content = UNMutableNotificationContent()
        content.title = copy("\(copy.title(place))的保护结束了", "\(copy.title(place)) is no longer protected")
        content.body = copy("现在可以发起挑战。", "You can challenge it now.")
        content.threadIdentifier = "city"
        content.userInfo = ["page": tapPage]
        return await schedule("protection-" + place.id, content: content, at: date)
    }

    /// Re-schedules the owner's notifications from the latest board read.
    @MainActor static func sync(store: CityBoardStore, locale: Locale, now: Date = Date()) async {
        guard !store.mine.isEmpty, await authorize(asking: false) else { return }
        registerCategories(locale: locale)
        let copy = CityCopy(locale: locale)
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix + "shield-") || $0.hasPrefix(prefix + "rent-") })
        for place in store.mine {
            guard let until = place.protectedUntil, until.addingTimeInterval(-3600) > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = copy("\(copy.title(place))的保护还剩 1 小时", "1 hour of protection left at \(copy.title(place))")
            content.body = copy("开护盾再保护 12 小时，或者稍后到场守住它。", "Shield it for 12 more hours, or visit it later.")
            content.categoryIdentifier = shieldCategory
            content.threadIdentifier = "city"
            content.userInfo = ["territoryId": place.territoryId ?? place.id, "page": tapPage]
            _ = await schedule("shield-" + place.id, content: content, at: until.addingTimeInterval(-3600))
        }
        if let rent = store.todayRent, rent > 0, let evening = eightPM(after: now) {
            let content = UNMutableNotificationContent()
            content.title = copy("今天收租 +\(rent)", "Rent today +\(rent)")
            content.body = copy("截至 \(copy.clock(now, now: now))，03:00 核对后入账。", "As of \(copy.clock(now, now: now)); settled after 03:00.")
            content.threadIdentifier = "city"
            content.userInfo = ["page": tapPage]
            _ = await schedule("rent-" + dayKey(now), content: content, at: evening)
        }
    }

    /// A refresh found the viewer's place gone (N40's notification twin).
    @MainActor static func placeLost(_ place: CityPlace, locale: Locale) async {
        guard await authorize(asking: false) else { return }
        let copy = CityCopy(locale: locale)
        let content = UNMutableNotificationContent()
        content.title = copy("\(copy.title(place))被拿走了", "\(copy.title(place)) was taken")
        content.body = copy("24 小时内反击，挑战费减半。", "Strike back within 24 h at half the fee.")
        content.threadIdentifier = "city"
        content.userInfo = ["page": tapPage]
        let request = UNNotificationRequest(identifier: prefix + "lost-" + place.id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func authorize(asking: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined:
            guard asking else { return false }
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default: return false
        }
    }

    private static func schedule(_ id: String, content: UNMutableNotificationContent, at date: Date) async -> Bool {
        guard date > Date() else { return false }
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let request = UNNotificationRequest(identifier: prefix + id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
        do { try await UNUserNotificationCenter.current().add(request); return true } catch { return false }
    }

    private static func eightPM(after now: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        guard let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now), evening > now else { return nil }
        return evening
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd"; formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
}
