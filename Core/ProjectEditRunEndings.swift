import Foundation

/// 运行结局 on `themeRuntimeConfig.endings[]` (`{id, title, summary, fallback}`).
/// Mini-program: `pages/publish/fabu/runtime-structure-editor.wxml:35-52` kind `endings` +
/// `theme-runtime-structure.js` `validate` (endings part, :126-144), `addStructureEnding`, `onStructureEnding`,
/// `chooseStructureFallbackEnding`, `removeStructureEnding`, `saveStructure`. The MP opens this editor only from
/// the publish-check locator (`locatePublishIssue` → `_locateStructureIssue('endings')`), so the native entry
/// shows only while there is an endings problem. This does not post; the topic save carries `themeRuntimeConfig`.
public enum ProjectEditRunEndings {
    public enum Copy {
        public static let tooMany = "projectRunEndings.issue.tooMany"
        public static let invalidID = "projectRunEndings.issue.invalidID"
        public static let fields = "projectRunEndings.issue.fields"
        public static let fallbackCount = "projectRunEndings.issue.fallbackCount"
        public static let planEnding = "projectRunEndings.issue.planEnding"
        public static let inUse = "projectRunEndings.issue.inUse"
        public static let unreadable = "mpPublish.rules.unreadable"
    }

    public static let limit = 30
    public static let titleLimit = 80
    public static let summaryLimit = 2000

    /// One 结局 card. `extra` keeps any other keys of the stored row (MP `copy` keeps them).
    public struct Row: Identifiable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var summary: String
        public var fallback: Bool
        var extra: [String: ProjectEditJSON]
        public init(id: String, title: String = "", summary: String = "", fallback: Bool = false) {
            self.id = id
            self.title = title
            self.summary = summary
            self.fallback = fallback
            extra = [:]
        }
    }

    /// The stored rows, in stored order; an unreadable config reads as no rows.
    public static func rows(in draft: ProjectEditDraft) -> [Row] {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return [] }
        return rows(theme)
    }

    static func rows(_ theme: [String: ProjectEditJSON]) -> [Row] {
        (theme["endings"]?.array ?? []).compactMap { value -> Row? in
            guard var object = value.object else { return nil }
            var row = Row(id: object["id"]?.text ?? "", title: object["title"]?.text ?? "",
                          summary: object["summary"]?.text ?? "", fallback: object["fallback"] == .bool(true))
            for key in ["id", "title", "summary", "fallback"] { object.removeValue(forKey: key) }
            row.extra = object
            return row
        }
    }

    /// The MP endings problem the publish check would block on (`validate` → `field: 'endings'`), or nil.
    public static func issueKey(in draft: ProjectEditDraft) -> String? {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return nil }
        return issueKey(rows(theme), theme: theme, draft: draft)
    }

    /// MP `validate` endings part, then the terminal-plan check (`表决方案须选择本主题已保存的结局章`).
    public static func issueKey(_ rows: [Row], in draft: ProjectEditDraft) -> String? {
        let theme = (try? NativeRuntimeStructureAuthorDraft.readTheme(draft)) ?? [:]
        return issueKey(rows, theme: theme, draft: draft)
    }

    static func issueKey(_ rows: [Row], theme: [String: ProjectEditJSON], draft: ProjectEditDraft) -> String? {
        if !rows.isEmpty {
            if rows.count > limit { return Copy.tooMany }
            var seen = Set<String>()
            for row in rows {
                if !validID(row.id) || seen.contains(row.id) { return Copy.invalidID }
                seen.insert(row.id)
                let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if title.isEmpty || row.title.utf16.count > titleLimit || row.summary.utf16.count > summaryLimit { return Copy.fields }
            }
            if rows.filter(\.fallback).count != 1 { return Copy.fallbackCount }
        }
        let chapterIDs = Set(draft.chapters.compactMap { $0.preserved["id"]?.integer })
        for value in theme["gameplayRuntime"]?.object?["plans"]?.array ?? [] {
            guard let plan = value.object, plan["terminal"] != .bool(false) else { continue }
            if storyEnding(plan["storyEndingId"]), let chapter = plan["endingChapterId"]?.integer, chapterIDs.contains(chapter) { continue }
            if !rows.contains(where: { $0.id == plan["endingKey"]?.text }) { return Copy.planEnding }
        }
        return nil
    }

    private static func storyEnding(_ value: ProjectEditJSON?) -> Bool {
        switch value {
        case .string(let text)?: return !text.isEmpty
        case .number(let number)?: return number != 0
        case .bool(let flag)?: return flag
        default: return false
        }
    }

    static func validID(_ id: String) -> Bool {
        id.range(of: "^[a-z][a-z0-9_]{0,31}$", options: .regularExpression) != nil
    }

    /// MP `addStructureEnding`: next free `ending_N`; the first row becomes the default 收尾.
    public static func adding(to rows: [Row]) throws -> [Row] {
        guard rows.count < limit else { throw ProjectEditRuntimeActsError.refused(Copy.tooMany) }
        var number = 1
        while rows.contains(where: { $0.id == "ending_\(number)" }) { number += 1 }
        return rows + [Row(id: "ending_\(number)", fallback: rows.isEmpty)]
    }

    /// MP `chooseStructureFallbackEnding`: exactly the chosen row is the default 收尾.
    public static func choosingFallback(_ id: String, in rows: [Row]) -> [Row] {
        guard rows.contains(where: { $0.id == id }) else { return rows }
        return rows.map { row in
            var next = row
            next.fallback = row.id == id
            return next
        }
    }

    /// MP `removeStructureEnding`: refused while a 表决方案 of this theme still ends on it.
    /// (The MP also checks node-template plans, whose details this editor does not read; the save-time
    /// plan check above still refuses a dangling theme plan.)
    public static func removing(_ id: String, from rows: [Row], in draft: ProjectEditDraft) throws -> [Row] {
        let theme = (try? NativeRuntimeStructureAuthorDraft.readTheme(draft)) ?? [:]
        let plans = theme["gameplayRuntime"]?.object?["plans"]?.array ?? []
        if plans.contains(where: { $0.object?["endingKey"]?.text == id }) { throw ProjectEditRuntimeActsError.refused(Copy.inUse) }
        return rows.filter { $0.id != id }
    }

    /// MP `saveStructure` for kind `endings`: fill `schemaVersion`/`capacity` when missing, validate, write back.
    public static func save(_ rows: [Row], in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var theme = try ProjectEditThemeRules.readable(draft)
        if theme["schemaVersion"] == nil {
            theme["schemaVersion"] = .number(1)
            theme["capacity"] = .number(0)
        }
        if let key = issueKey(rows, theme: theme, draft: draft) { throw ProjectEditRuntimeActsError.refused(key) }
        theme["endings"] = .array(rows.map { row in
            var object = row.extra
            object["id"] = .string(row.id)
            object["title"] = .string(row.title)
            object["summary"] = .string(row.summary)
            object["fallback"] = .bool(row.fallback)
            return .object(object)
        })
        return try ProjectEditThemeRules.write(theme, into: draft)
    }
}
