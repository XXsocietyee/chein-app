import Foundation

/// 运行结局 on `themeRuntimeConfig.endings[]` (`{id, title, summary, fallback}`).
/// Mini-program: `pages/publish/fabu/runtime-structure-editor.wxml` kind `endings` + `theme-runtime-structure.js`
/// `addStructureEnding` / `onStructureEnding` / `chooseStructureFallbackEnding` / `removeStructureEnding` /
/// `saveStructure` and the `endings` part of `validate`. The MP opens this editor only from the publish check
/// (`locatePublishIssue` → `_locateStructureIssue('endings')`), never from a row; a cloud draft skips the check
/// (`index.js:7743`). This does not post; the topic save already carries `themeRuntimeConfig`.
public enum ProjectEditRuntimeEndings {
    public enum Copy {
        public static let tooMany = "projectEdit.validation.runtimeEndings.tooMany"
        public static let badID = "projectEdit.validation.runtimeEndings.badID"
        public static let fields = "projectEdit.validation.runtimeEndings.fields"
        public static let fallback = "projectEdit.validation.runtimeEndings.fallback"
        public static let plan = "projectEdit.validation.runtimeEndings.plan"
        public static let inUse = "projectEdit.validation.runtimeEndings.inUse"
        public static let unreadable = "mpPublish.rules.unreadable"
    }

    /// Issue id in `ProjectEditValidation.issues`, and the root anchor the issue row opens.
    public static let issueID = "runtimeEndings"
    public static let anchor = "project-issue-anchor-runtimeEndings"
    public static let maxCount = 30
    public static let titleLimit = 80
    public static let summaryLimit = 2000

    /// One ending row. Keys other than the four the editor writes are kept as they were.
    public struct Row: Identifiable, Equatable, Sendable {
        public let id: String
        public var title: String
        public var summary: String
        public var fallback: Bool
        let extra: [String: ProjectEditJSON]

        public init(id: String, title: String = "", summary: String = "", fallback: Bool = false) {
            self.id = id; self.title = title; self.summary = summary; self.fallback = fallback; extra = [:]
        }

        init(_ object: [String: ProjectEditJSON]) {
            id = object["id"]?.text ?? ""
            title = object["title"]?.text ?? ""
            summary = object["summary"]?.text ?? ""
            fallback = object["fallback"] == .bool(true)
            var rest = object
            for key in ["id", "title", "summary", "fallback"] { rest[key] = nil }
            extra = rest
        }

        var json: ProjectEditJSON {
            var object = extra
            object["id"] = .string(id)
            object["title"] = .string(title)
            object["summary"] = .string(summary)
            object["fallback"] = .bool(fallback)
            return .object(object)
        }
    }

    /// The saved rows (MP `structureDraft.endings`); empty when none or the config cannot be read.
    public static func rows(in draft: ProjectEditDraft) -> [Row] {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return [] }
        return (theme["endings"]?.array ?? []).compactMap(\.object).map(Row.init)
    }

    /// MP `addStructureEnding`: next free `ending_N`; the first row becomes the default ending.
    public static func adding(to rows: [Row]) throws -> [Row] {
        guard rows.count < maxCount else { throw ProjectEditRuntimeActsError.refused(Copy.tooMany) }
        var number = 1
        while rows.contains(where: { $0.id == "ending_" + String(number) }) { number += 1 }
        return rows + [Row(id: "ending_" + String(number), fallback: rows.isEmpty)]
    }

    /// MP `chooseStructureFallbackEnding`: exactly the chosen row is the default ending.
    public static func choosingFallback(_ index: Int, in rows: [Row]) -> [Row] {
        guard rows.indices.contains(index) else { return rows }
        return rows.enumerated().map { offset, row in
            var next = row
            next.fallback = offset == index
            return next
        }
    }

    /// MP `removeStructureEnding`: refused while a 表决方案 of the theme still ends in this row.
    /// (Plans inside a node's own template config are read by the server check; the editor has no template details.)
    public static func removing(_ index: Int, from rows: [Row], in draft: ProjectEditDraft) throws -> [Row] {
        guard rows.indices.contains(index) else { return rows }
        let theme = (try? NativeRuntimeStructureAuthorDraft.readTheme(draft)) ?? [:]
        let plans = (theme["gameplayRuntime"]?.object?["plans"]?.array ?? []).compactMap(\.object)
        if plans.contains(where: { $0["endingKey"]?.text == rows[index].id }) {
            throw ProjectEditRuntimeActsError.refused(Copy.inUse)
        }
        var next = rows
        next.remove(at: index)
        return next
    }

    /// MP `saveStructure` for kind `endings`: writes the rows, adds `schemaVersion 1 · capacity 0` to a new config,
    /// validates, and refuses with the first MP error.
    public static func save(_ rows: [Row], into draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var theme: [String: ProjectEditJSON]
        do { theme = try NativeRuntimeStructureAuthorDraft.readTheme(draft) } catch {
            throw ProjectEditRuntimeActsError.refused(Copy.unreadable)
        }
        if rows.isEmpty && theme["endings"] == nil { return draft }
        theme["endings"] = .array(rows.map(\.json))
        if theme["schemaVersion"] == nil {
            theme["schemaVersion"] = .number(1)
            theme["capacity"] = .number(0)
        }
        let next = try ProjectEditThemeRules.write(theme, into: draft)
        if let key = issueKey(in: next) { throw ProjectEditRuntimeActsError.refused(key) }
        return next
    }

    /// The `endings` part of MP `validate`, in MP order. Nil when there is no `gameplayRuntime` (MP returns early)
    /// or the config cannot be read (other checks report that).
    public static func issueKey(in draft: ProjectEditDraft) -> String? {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft),
              let game = theme["gameplayRuntime"]?.object else { return nil }
        let endings = (theme["endings"]?.array ?? []).map { $0.object ?? [:] }
        if !endings.isEmpty {
            if endings.count > maxCount { return Copy.tooMany }
            var seen = Set<String>()
            for row in endings {
                let id = row["id"]?.text ?? ""
                if id.range(of: "^[a-z][a-z0-9_]{0,31}$", options: .regularExpression) == nil || seen.contains(id) { return Copy.badID }
                seen.insert(id)
                let title = row["title"]?.text ?? "", summary = row["summary"]?.text ?? ""
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.utf16.count > titleLimit
                    || summary.utf16.count > summaryLimit { return Copy.fields }
            }
            if endings.filter({ $0["fallback"] == .bool(true) }).count != 1 { return Copy.fallback }
        }
        let chapterIDs = ProjectEditCastClues.chapterIDs(draft)
        let endingIDs = Set(endings.compactMap { $0["id"]?.text })
        for plan in (game["plans"]?.array ?? []).compactMap(\.object) {
            if plan["terminal"] == .bool(false) { continue }
            if truthy(plan["storyEndingId"]), let chapter = ProjectEditCastClues.idText(plan["endingChapterId"]),
               chapterIDs.contains(chapter) { continue }
            if !endingIDs.contains(plan["endingKey"]?.text ?? "") { return Copy.plan }
        }
        return nil
    }

    private static func truthy(_ value: ProjectEditJSON?) -> Bool {
        switch value {
        case .none, .some(.null), .some(.bool(false)): return false
        case .some(.string(let text)): return !text.isEmpty
        case .some(.number(let number)): return number != 0
        default: return true
        }
    }
}
