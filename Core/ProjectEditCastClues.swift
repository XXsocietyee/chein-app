import Foundation

/// MP story-cast.js, checked when the topic is sent (`theme-cast.js` `payloadOf` → `serializeCastConfig`), not only
/// when the 角色 sheet closes: a 你知道的 clue whose unlock chapter has since been deleted.
/// - Publishing stops with `memberIssues` 「第 N 条解锁的章节已经不在了，重新选一章」.
/// - A cloud draft drops the clue (`draftView`): turning it into 开局就有 would show it to players early.
/// Chapter ids compare as text, like the MP `String(c.chapterId)`; only saved chapters (with an id) count.
public enum ProjectEditCastClues {
    public static let key = "castConfig"

    static func idText(_ value: ProjectEditJSON?) -> String? {
        switch value {
        case .string(let text): return text.isEmpty ? nil : text
        case .number(let number): return "\(number)"
        default: return nil
        }
    }

    static func chapterIDs(_ draft: ProjectEditDraft) -> Set<String> {
        Set(draft.chapters.compactMap { chapter in idText(chapter.preserved["id"]) })
    }

    static func root(_ value: ProjectEditJSON?) -> [String: ProjectEditJSON]? {
        switch value {
        case .object(let object): return object
        case .string(let raw):
            guard let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(ProjectEditJSON.self, from: data) else { return nil }
            return decoded.object
        default: return nil
        }
    }

    static func isStale(_ clue: ProjectEditJSON, chapters: Set<String>) -> Bool {
        guard let unlock = idText(clue.object?["chapterId"]) else { return false }
        return !chapters.contains(unlock)
    }

    /// True when a cast member keeps a clue that unlocks in a chapter the topic no longer has.
    public static func hasStaleClue(_ draft: ProjectEditDraft) -> Bool {
        guard let object = root(draft.preserved[key]) else { return false }
        let chapters = chapterIDs(draft)
        let members = (object["cast"]?.array ?? []).compactMap(\.object)
        return members.contains { member in
            (member["clues"]?.array ?? []).contains { clue in isStale(clue, chapters: chapters) }
        }
    }

    /// The cast config without stale clues (MP `draftView`). Returns the stored value unchanged when nothing is stale.
    public static func withoutStaleClues(_ draft: ProjectEditDraft) -> ProjectEditJSON? {
        let stored = draft.preserved[key]
        guard hasStaleClue(draft), var object = root(stored) else { return stored }
        let chapters = chapterIDs(draft)
        let members: [ProjectEditJSON] = (object["cast"]?.array ?? []).map { row in
            guard var member = row.object else { return row }
            let clues = member["clues"]?.array ?? []
            member["clues"] = .array(clues.filter { clue in !isStale(clue, chapters: chapters) })
            return .object(member)
        }
        object["cast"] = .array(members)
        return .object(object)
    }
}
