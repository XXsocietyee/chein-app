import Foundation

/// Route detail 「活动内容」 keeps only the story; practical lines (safety, hours, transit,
/// route lists) and facts already on the topic move into a short 「出发前」 list.
/// Mirrors mini-program `pages/topic/utils/depart-notes.js` (1121) and `topic-motion.js buyOptions`.
/// Nothing is invented: a fact the server did not send is simply left out.
/// Ported from chengyin-ios `fd2bdc49` (port plan r1 C13); adapted to our `TopicDetail` and to
/// `TopicXcxFacts.includes` so the 「含 …」 line counts chapters exactly like the rest of the page.
public enum TopicDepartNotes {
    public enum Item: Equatable {
        /// One way in. `from` marks a 起 price (same-name tickets at different prices; the lowest is kept).
        /// `sharedBy` is how many people share it, only when two or more.
        case price(name: String?, amount: Decimal, from: Bool, sharedBy: Int?)
        /// The 「含 …」 line: chapters / stops / games / audio guide only, in `TopicXcxFacts.includes` order.
        case includes([TopicXcxFacts.Include])
        /// City routes can pause and pick up where they stopped; free exploration has no run.
        case pauseResume
        /// Finish medal; nil name means the app's own fallback copy.
        case badge(name: String?)
        case coupon
        /// A practical sentence lifted out of the author's description, verbatim.
        case note(String)
    }

    public struct Split: Equatable {
        public let story: String
        public let notes: [String]
    }

    private static let heading = try! NSRegularExpression(pattern:
        #"^[【\[〔(（]?\s*(出发前|注意事项|温馨提示|安全提示|安全须知|游玩须知|参与须知|活动须知|须知|小贴士|贴士|提示|注意|tips|路线|路线安排|营业时间|开放时间|交通|集合)\s*[】\]〕)）]?\s*[:：]?"#,
        options: [.caseInsensitive])
    private static let practical = try! NSRegularExpression(pattern:
        #"停稳|看手机|斑马线|过马路|红绿灯|注意安全|安全第一|营业时间|营业|闭店|打烊|休息日|店休|开放时间|请勿|切勿|禁止|不要在|雨天|穿舒适|舒适的鞋|携带|带好|充电宝|电量|地铁|公交|停车|卫生间|洗手间|厕所|全程约|步行约|路线[:：]|→|➜|⇒"#)
    private static let listMark = try! NSRegularExpression(pattern:
        #"^\s*(?:[-*•·●▪]|\d{1,2}\s*[.、)）]|[①-⑳]|[（(]\d{1,2}[)）])\s*"#)
    private static let sentence = try! NSRegularExpression(pattern: #"[^。！？!?；;]+[。！？!?；;]*"#)

    /// Story paragraphs and practical lines, split by paragraph, line, then sentence.
    public static func split(_ text: String?) -> Split {
        let raw = (text ?? "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw != "null" else { return Split(story: "", notes: []) }
        var notes: [String] = []
        var paragraphs: [String] = []
        for paragraph in raw.components(separatedBy: "\n").split(whereSeparator: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            var isPractical = false
            var keep: [String] = []
            for line in paragraph.map({ $0.trimmingCharacters(in: .whitespaces) }) where !line.isEmpty {
                if let head = match(heading, line) {
                    isPractical = true
                    notes += sentences(String(line[head.upperBound...])).compactMap(clean)
                    continue
                }
                if isPractical || match(listMark, line) != nil {
                    notes += sentences(line).compactMap(clean)
                    continue
                }
                var story = ""
                for part in sentences(line) {
                    if match(practical, part, anchored: false) != nil { if let c = clean(part) { notes.append(c) } }
                    else { story += part }
                }
                let trimmed = story.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { keep.append(trimmed) }
            }
            if !keep.isEmpty { paragraphs.append(keep.joined(separator: "\n")) }
        }
        var seen = Set<String>()
        return Split(story: paragraphs.joined(separator: "\n\n"), notes: notes.filter { seen.insert($0).inserted })
    }

    /// The 「出发前」 rows for this route, in MP order: prices, what is included, pause/resume,
    /// the finishing badge and coupon, then the practical lines from the description.
    public static func items(for topic: TopicDetail) -> [Item] {
        var out: [Item] = []
        // MP buyOptions: the self-play pass first (one person), then session tickets, which only count
        // when the route has sessions (`activityList`). Same-name tickets fold into one 起 price.
        if topic.selfPlay == 1, let amount = topic.selfPlayPrice { out.append(.price(name: nil, amount: amount, from: false, sharedBy: nil)) }
        if !(topic.activities ?? []).isEmpty {
            var order: [String] = []
            var folded: [String: (amount: Decimal?, from: Bool, people: Int)] = [:]
            for ticket in topic.tickets {
                let name = ticket.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                guard var hit = folded[name] else {
                    order.append(name)
                    folded[name] = (ticket.price, false, ticket.teamSize ?? 1)
                    continue
                }
                if let price = ticket.price, hit.amount != price {
                    hit.from = true
                    if hit.amount.map({ price < $0 }) ?? true { hit.amount = price }
                    folded[name] = hit
                }
            }
            for name in order {
                guard let hit = folded[name], let amount = hit.amount else { continue }
                out.append(.price(name: name, amount: amount, from: hit.from, sharedBy: hit.people >= 2 ? hit.people : nil))
            }
        }
        let parts = TopicXcxFacts.includes(topic).filter { part in
            switch part {
            case .chapters, .chapterBreakdown, .stops, .plays, .audio, .audioMinutes: return true
            case .medal, .coupon: return false
            }
        }
        if !parts.isEmpty { out.append(.includes(parts)) }
        if topic.productType != 2 { out.append(.pauseResume) }
        let medal = topic.finishMedalName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let medalImage = topic.finishMedalImage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !medal.isEmpty || !medalImage.isEmpty {
            // MP fallback chain: finishMedalName, else "<route name> · 通关", else the app's unnamed copy.
            let routeName = topic.name.trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(.badge(name: !medal.isEmpty ? medal : (routeName.isEmpty ? nil : routeName + " · 通关")))
        }
        if topic.completeRewardCouponID != nil { out.append(.coupon) }
        return out + split(topic.introduction).notes.map(Item.note)
    }

    private static func match(_ regex: NSRegularExpression, _ text: String, anchored: Bool = true) -> Range<String.Index>? {
        let range = NSRange(text.startIndex..., in: text)
        guard let hit = regex.firstMatch(in: text, options: anchored ? [.anchored] : [], range: range) else { return nil }
        return Range(hit.range, in: text)
    }
    private static func sentences(_ line: String) -> [String] {
        let range = NSRange(line.startIndex..., in: line)
        return sentence.matches(in: line, range: range).compactMap { Range($0.range, in: line).map { String(line[$0]) } }
    }
    private static func clean(_ text: String) -> String? {
        var value = text
        if let mark = match(listMark, value) { value.removeSubrange(mark) }
        let leading = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":：,，、"))
        let trailing = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "。；;，,、"))
        while let first = value.unicodeScalars.first, leading.contains(first) { value.unicodeScalars.removeFirst() }
        while let last = value.unicodeScalars.last, trailing.contains(last) { value.unicodeScalars.removeLast() }
        return value.isEmpty ? nil : value
    }
}
