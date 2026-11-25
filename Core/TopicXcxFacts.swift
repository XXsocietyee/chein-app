import Foundation

/// Display rules ported from mini-program `pages/topic/index` and `pages/topic/utils/topic-detail-facts.js`.
/// Pure presentation over `TopicDetail`; no request, purchase or write authority.
public enum TopicXcxFacts {
    /// Source `buildTopicStatBar`: cells are skipped when missing or not positive.
    public enum StatCell: Equatable {
        case rating(value: Double, stars: Int)
        case hours(text: String)
        case open(start: String, end: String)
        case mileage(text: String)
        case merchants(Int)
    }
    public static func statBar(_ topic: TopicDetail) -> [StatCell] {
        var cells: [StatCell] = []
        if let rating = topic.averageRating, rating.isFinite, rating > 0 {
            cells.append(.rating(value: (rating * 10).rounded() / 10, stars: max(0, min(5, Int(rating.rounded())))))
        }
        if let seconds = topic.totalTimeSeconds, Double(seconds) / 3600 >= 0.1 {
            let hours = (Double(seconds) / 3600 * 10).rounded() / 10
            let text = hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours)
            cells.append(.hours(text: text + "+"))
        }
        if let start = monthDay(topic.startDate), let end = monthDay(topic.endDate) { cells.append(.open(start: start, end: end)) }
        if let mileage = topic.totalMileage, mileage.isFinite, mileage > 0 {
            cells.append(.mileage(text: mileage == mileage.rounded() ? String(Int(mileage)) : String(mileage)))
        }
        if let merchants = topic.merchantCount, merchants > 0 { cells.append(.merchants(merchants)) }
        return cells
    }

    /// Source `M.D` in China time from `yyyy-MM-dd[ HH:mm:ss]`.
    public static func monthDay(_ raw: String?) -> String? {
        guard let raw, let date = SquareXcxTime.date(raw.count == 10 ? raw + " 00:00:00" : raw) else { return nil }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return nil }
        return "\(month).\(day)"
    }

    /// Source `formatTimeToChinese(seconds)`.
    public enum Duration: Equatable { case zero, underMinute, minutes(Int), hours(Int), hoursMinutes(Int, Int) }
    public static func duration(seconds: Int?) -> Duration {
        guard let seconds, seconds >= 0 else { return .zero }
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        if hours == 0 { return minutes == 0 ? .underMinute : .minutes(minutes) }
        return minutes == 0 ? .hours(hours) : .hoursMinutes(hours, minutes)
    }

    /// Source `contentIncludes`, in order, each only when present.
    public enum Include: Equatable {
        case chapters(Int), chapterBreakdown(story: Int, endings: Int), stops(Int), plays(Int), audioMinutes(Int), audio, medal(String?), coupon
    }
    /// Buyer-facing chapter count (`utils/chapter-count.js`): a chapter whose name starts with 结局 is an ending, not a chapter.
    /// Ending names are counted only from the chapters already delivered. `totalChapterCount` still includes them.
    public static func buyerChapterCounts(_ topic: TopicDetail) -> (story: Int, endings: Int) {
        let names = topic.chapters.map(\.title)
        let total = topic.totalChapterCount > 0 ? topic.totalChapterCount : names.count
        let endings = min(names.filter(Self.isEndingChapterName).count, max(0, total))
        return (max(0, total - endings), endings)
    }
    public static func isEndingChapterName(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("结局")
    }
    /// Generated 「第N章」 is skipped when the name already carries 第X章 / 结局 / 终章 / 序章 / 尾声.
    public static func hidesGeneratedChapterOrdinal(_ name: String) -> Bool {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let expression = Self.selfOrdinalExpression else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }
    /// Preview guide: description, else nothing. Puzzle prompts are cut off. At most 60 characters.
    public static func chapterGuide(description: String?) -> String {
        let limit = 60
        let source = Self.stripPuzzle(description ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if source.count <= limit { return source }
        let head = String(source.prefix(limit))
        let breaks = ["。", "！", "？", "."].compactMap { head.lastIndex(of: Character($0)) }
        if let cut = breaks.max(), head.distance(from: head.startIndex, to: cut) >= 12 {
            return String(head[...cut])
        }
        var trimmed = head
        while let last = trimmed.last, "，,、；; \t".contains(last) { trimmed.removeLast() }
        return trimmed + "…"
    }
    /// Cover subtitle: 20 characters, with an ellipsis when the cut is not already at the end.
    public static func heroIntro(_ subtitle: String?) -> String? {
        let raw = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return nil }
        let chars = Array(raw)
        if chars.count <= 20 { return String(chars) }
        var head = String(chars.prefix(20))
        while let last = head.last, "，,、；;。 \t".contains(last) { head.removeLast() }
        return head + "…"
    }
    /// Paywall 「与到店权益」 only when a shop card would be shown.
    public static func showsInStorePerks(_ topic: TopicDetail) -> Bool {
        Self.lineup(topic).contains { $0.kind == .merchant }
    }
    public static func includes(_ topic: TopicDetail) -> [Include] {
        var rows: [Include] = []
        let counts = Self.buyerChapterCounts(topic)
        if counts.endings > 0 { rows.append(.chapterBreakdown(story: counts.story, endings: counts.endings)) }
        else if counts.story > 0 { rows.append(.chapters(counts.story)) }
        if let stops = topic.locationCount, stops > 0 { rows.append(.stops(stops)) }
        if topic.templateCount > 0 { rows.append(.plays(topic.templateCount)) }
        if let audio = topic.audioURL, !audio.trimmingCharacters(in: .whitespaces).isEmpty {
            let minutes = Int((Double(topic.audioDuration ?? 0) / 60).rounded())
            rows.append(minutes > 0 ? .audioMinutes(minutes) : .audio)
        }
        let medal = topic.finishMedalName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (medal?.isEmpty == false) || topic.finishMedalImage?.isEmpty == false {
            // Source fallback chain: finishMedalName, else "<name> · 通关", else 通关纪念 (nil → App copy).
            rows.append(.medal(medal?.isEmpty == false ? medal : (topic.name.isEmpty ? nil : topic.name + " · 通关")))
        }
        if topic.completeRewardCouponID != nil { rows.append(.coupon) }
        return rows
    }

    /// Source `buildVenue`: `名称（地址）` with full-width or ASCII parentheses.
    public static func venue(_ addressName: String?) -> (name: String, address: String?)? {
        guard let raw = addressName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "null" else { return nil }
        for (open, close) in [("（", "）"), ("(", ")")] {
            if raw.hasSuffix(close), let range = raw.range(of: open) {
                let name = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let address = String(raw[range.upperBound..<raw.index(before: raw.endIndex)]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return (name, address.isEmpty ? nil : address) }
            }
        }
        return (raw, nil)
    }

    /// Source `buildLineup`: club first, then distinct node merchants.
    public struct LineupMember: Equatable { public enum Kind: Equatable { case club, merchant }; public let kind: Kind; public let targetID: Int; public let name: String }
    public static func lineup(_ topic: TopicDetail) -> [LineupMember] {
        var rows: [LineupMember] = []
        if let club = topic.clubName?.trimmingCharacters(in: .whitespacesAndNewlines), !club.isEmpty {
            rows.append(.init(kind: .club, targetID: topic.clubID ?? 0, name: club))
        }
        var seen = Set<String>()
        for merchant in topic.chapters.flatMap({ $0.nodes.flatMap(\.merchants) }) {
            let name = merchant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(merchant.memberID > 0 ? "id:\(merchant.memberID)" : "name:" + name).inserted else { continue }
            rows.append(.init(kind: .merchant, targetID: merchant.memberID, name: name))
        }
        return rows
    }

    /// Source session text: same day `MM-DD HH:mm–HH:mm`, otherwise `start ~ end`.
    public static func sessionTime(start: String?, end: String?) -> String? {
        func parts(_ raw: String?) -> (day: String, time: String)? {
            guard let raw, raw.count >= 16 else { return nil }
            let chars = Array(raw)
            guard chars[4] == "-", chars[7] == "-", chars[13] == ":" else { return nil }
            return (String(chars[5..<10]), String(chars[11..<16]))
        }
        guard let first = parts(start) else { return nil }
        guard let last = parts(end) else { return first.day + " " + first.time }
        return first.day == last.day ? "\(first.day) \(first.time)–\(last.time)" : "\(first.day) \(first.time) ~ \(last.day) \(last.time)"
    }

    /// Bottom bar states (source `is_join`, `lifecycle` 1/2/7, `selfPlay`).
    /// PC-B-1-3: `closed` = sale deadline passed (MP `topicSaleClosed`, x-fix2 P-1): the bar states 已截止 and offers no buy.
    public enum Action: Equatable { case ticketWallet, locked(Int), closed, selfPlay(price: Decimal?), signUp }
    public static func action(_ topic: TopicDetail, now: Date = Date(), preferSession: Bool = false) -> Action {
        if topic.isSignUp { return .ticketWallet }
        if let lifecycle = topic.lifecycle, [1, 2, 7].contains(lifecycle) { return .locked(lifecycle) }
        if !topic.merchantClosed, saleClosed(topic, now: now) { return .closed }
        // via=session and a non-empty activityList: the bar opens the session picker (signup) before self-play.
        if preferSession, topic.activities?.isEmpty == false { return .signUp }
        return topic.selfPlay == 1 ? .selfPlay(price: topic.selfPlayPrice) : .signUp
    }
    /// MP `topicSaleClosed`: deadline = `saleEndAt`, else `endDate`; unknown deadline → still open.
    public static func saleClosed(_ topic: TopicDetail, now: Date = Date()) -> Bool {
        guard let deadline = IMInboxTime.parse(topic.saleEndAt) ?? IMInboxTime.parse(topic.endDate) else { return false }
        return now >= deadline
    }
    /// Owner of a lifecycle-2 topic leaves the buy toast. Free explore (productType 2) opens the topic editor;
    /// every other product opens pricing. Merchant publishers carry `scope=MERCHANT`.
    public enum OwnerSaleRoute: Equatable { case pricing(scope: String?), editor(scope: String?) }
    public static func ownerSaleRoute(_ topic: TopicDetail) -> OwnerSaleRoute? {
        guard topic.isOwner, topic.lifecycle == 2 else { return nil }
        let scope: String? = topic.contentPublisherType?.uppercased() == "MERCHANT" ? "MERCHANT" : nil
        return topic.productType == 2 ? .editor(scope: scope) : .pricing(scope: scope)
    }
    /// True only when the owner sale route is the pricing page. Free-explore owners are `.editor`, not this.
    public static func opensPricing(_ topic: TopicDetail) -> Bool {
        if case .pricing = ownerSaleRoute(topic) { return true }
        return false
    }
    /// Stops whose first merchant published `derivativeBenefits`. Matches topic-motion `routeNote`.
    public static func giftStopCount(_ topic: TopicDetail) -> Int {
        topic.chapters.reduce(0) { total, chapter in
            total + chapter.nodes.filter { $0.shopGift != nil }.count
        }
    }

    private static let selfOrdinalExpression: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:第\s*[0-9一二三四五六七八九十百零两]+\s*章|结局|终章|序章|尾声)"#)
    private static let puzzleExpression: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"【\s*(?:题目|观察位置|谜题|提示|线索|密码表?|密文|答案)[^】]*】|(?:^|\s)(?:题目|观察位置)[:：]|密码表|对照表|[A-Z]\s*=\s*\d"#)

    private static func stripPuzzle(_ source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let expression = Self.puzzleExpression else { return trimmed }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = expression.firstMatch(in: trimmed, range: range),
              let swiftRange = Range(match.range, in: trimmed) else { return trimmed }
        return String(trimmed[..<swiftRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
