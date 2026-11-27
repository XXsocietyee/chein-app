import SwiftUI

/// R7-PC-B1-12: MP `cy-pass-reveal` after a successful self-play order (pages/topic/index/index.wxml:511-513, index.js:1007-1015).
/// i18n r3: kind and duration lines come from `topicReveal.*` keys (zh keeps the MP wording).
/// The window follows MP `passWindow` (pages/topic/utils/topic-motion.js:381-404): China natural days, 90 days or the topic end.
enum TopicPurchaseRevealBuilder {
    static func model(topic: TopicDetail, now: Date = Date(), locale: Locale = .current) -> TopicPurchaseRevealCardModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let today = calendar.startOfDay(for: now)
        var last = calendar.date(byAdding: .day, value: 89, to: today) ?? today
        var endsWithTopic = false
        if let end = topic.endDate.flatMap({ parseDay($0, calendar: calendar) }), end < last {
            last = end; endsWithTopic = true
        }
        let parts = calendar.dateComponents([.month, .day], from: last)
        let month = parts.month ?? 1, day = parts.day ?? 1
        let days = max(0, calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: last)).day ?? 0)
        return TopicPurchaseRevealCardModel(
            coverURL: topic.imageURL,
            topicName: topic.name,
            kindText: appLocalized(topic.productType == 2 ? "topicReveal.kind.free" : "topicReveal.kind.city", locale: locale),
            untilText: String(format: "%02d/%02d", month, day),
            daysText: String(days),
            durationLine: endsWithTopic ? appLocalized("topicReveal.durationTopicEnd \(month) \(day) \(days)", locale: locale)
                                        : appLocalized("topicReveal.duration \(month) \(day) \(days)", locale: locale)
        )
    }

    private static func parseDay(_ raw: String, calendar: Calendar) -> Date? {
        let digits = raw.prefix(10).split(whereSeparator: { $0 == "-" || $0 == "/" || $0 == "." })
        guard digits.count == 3, let y = Int(digits[0]), let m = Int(digits[1]), let d = Int(digits[2]) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d))
    }
}
