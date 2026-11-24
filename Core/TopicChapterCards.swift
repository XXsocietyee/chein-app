import Foundation

/// Route detail "节点介绍": one card per chapter (owner request 2026-11-19, paired with the
/// mini-program `pages/topic/utils/chapter-cards.js`). Ending chapters are never shown, so the
/// card row cannot spoil them. Pure values only; the view decides how to load an image source.
/// Ported from chengyin-ios `f815bf30` (port plan r1 C9).
public struct TopicChapterCard: Equatable, Identifiable {
    public let id: Int
    public let title: String
    /// First chapter image, else the route cover; nil means show the placeholder tone.
    public let imageSource: String?
    /// Positive game count, else nil (the part is hidden).
    public let gameCount: Int?
    /// Rounded minutes, else nil (the part is hidden).
    public let minutes: Int?
    public let description: String?
}

public enum TopicChapterCards {
    /// Splits `img_arr`: a JSON array string or a comma/semicolon list.
    public static func imageList(_ raw: String?) -> [String] {
        let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text == "null" { return [] }
        if text.hasPrefix("["), let data = text.data(using: .utf8),
           let list = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            return list.compactMap { item -> String? in
                let value = (item as? String) ?? ((item as? [String: Any])?["url"] as? String)
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty || !isDisplayable(trimmed) ? nil : trimmed
            }
        }
        // REV-B B-04 (MP chapter-cards.js:15-32): plain lists drop `[`, `]` and quotes, and `media-asset:N` refs.
        return text.split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "[]\"'"))) }
            .filter { !$0.isEmpty && isDisplayable($0) }
    }

    /// MP `station-image.js` `isDisplayable`: a `media-asset:` reference cannot load, so it never becomes the image.
    public static func isDisplayable(_ source: String) -> Bool {
        !source.lowercased().hasPrefix("media-asset:")
    }

    /// Endings: the name starts with 结局, or the chapter has neither games nor duration.
    public static func isEnding(_ chapter: TopicChapter) -> Bool {
        if chapter.title.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("结局") { return true }
        return (chapter.templateCount ?? 0) <= 0 && (chapter.totalTimeSeconds ?? 0) <= 0
    }

    /// `total_time` is seconds, rounded to minutes (at least 1). When it is 0 or missing,
    /// the chapter's template durations (minutes) are summed; nil hides the duration.
    public static func minutes(_ chapter: TopicChapter) -> Int? {
        if let seconds = chapter.totalTimeSeconds, seconds > 0 {
            return max(1, Int((Double(seconds) / 60).rounded()))
        }
        let sum = chapter.nodes.compactMap { $0.template?.duration }.filter { $0 > 0 }.reduce(0, +)
        return sum > 0 ? sum : nil
    }

    public static func cards(chapters: [TopicChapter], routeCover: String?) -> [TopicChapterCard] {
        let cover = imageList(routeCover).first
        let ordered = chapters.enumerated().sorted { a, b in
            switch (a.element.sortID, b.element.sortID) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.offset < b.offset
            }
        }.map(\.element)
        return ordered.filter { !isEnding($0) }.map { chapter in
            let description = chapter.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            return TopicChapterCard(
                id: chapter.id,
                title: chapter.title,
                imageSource: chapter.imageSources.first(where: isDisplayable) ?? cover,  // REV-B B-04
                gameCount: (chapter.templateCount ?? 0) > 0 ? chapter.templateCount : nil,
                minutes: minutes(chapter),
                description: (description?.isEmpty ?? true) || description == "null" ? nil : description
            )
        }
    }

    /// One open card at a time: tapping the open card closes it, tapping another switches.
    public static func toggle(open: Int?, tapped: Int) -> Int? {
        open == tapped ? nil : tapped
    }
}
