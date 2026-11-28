import Foundation

/// 主题详情 → 线索与物品 (MP `pages/publishkit/components/topic-state-keys` + `pages/publish/fabu/theme-keys-items.js`).
/// Three groups in MP order: 线索 (`clue.*` state keys) → 物品 (`themeRuntimeConfig.items`, kind ITEM) → 标签 (`tag.*`).
/// Clues and tags are server rows (`TopicCreatorEditorService`); items live in the topic's runtime config, so their
/// edits change the draft and the topic save carries them (MP `_saveRuntime`).
public enum ProjectEditTopicKeys {
    /// MP group order and labels (`_view`: 线索 → 物品 → 标签).
    public enum Kind: String, CaseIterable, Identifiable, Sendable {
        case clue, item, tag
        public var id: String { rawValue }
        public var labelKey: String { "mpPublish.keys.group." + rawValue }
        public var addKey: String { "mpPublish.keys.add." + rawValue }
    }

    /// MP `nameError`: at most 24 characters, no duplicate inside the same group.
    public enum NameIssue: Equatable, Sendable {
        case tooLong
        case taken(Kind)
    }

    public static let maxNameLength = 24

    public static func nameIssue(_ name: String, taken: [String], kind: Kind) -> NameIssue? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.count > maxNameLength { return .tooLong }
        if taken.contains(trimmed) { return .taken(kind) }
        return nil
    }

    /// Where an item is used (MP `itemUsedIn`); shown to the author as places, never as ids.
    public enum Place: Equatable, Hashable, Sendable {
        case completionReward
        case themeGrant
        case chapterGrant(Int)
        case chapterEgg(Int, String)
        case ration
        case facility(String)
    }

    public struct Item: Equatable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let usedIn: [Place]
    }

    /// MP `_syncKeysItems`: `items` rows with kind ITEM and an id; a blank name shows as 物品 in the view.
    public static func items(in draft: ProjectEditDraft) -> [Item] {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return [] }
        return (theme["items"]?.array ?? []).compactMap { value in
            guard let row = value.object, row["kind"]?.text == "ITEM", let id = Self.itemID(row["id"]) else { return nil }
            let name = (row["name"]?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return Item(id: id, name: name, usedIn: usedIn(theme, itemID: id))
        }
    }

    /// MP `itemUsedIn`, in MP order, without duplicates.
    static func usedIn(_ theme: [String: ProjectEditJSON], itemID id: String) -> [Place] {
        var out: [Place] = []
        func add(_ place: Place) { if !out.contains(place) { out.append(place) } }
        func refers(_ value: ProjectEditJSON) -> Bool { Self.itemID(value.object?["itemId"]) == id }
        for grant in theme["grants"]?.array ?? [] where refers(grant) {
            add(grant.object?["id"]?.text == "completion_material" ? .completionReward : .themeGrant)
        }
        for chapter in theme["chapters"]?.array ?? [] {
            guard let row = chapter.object else { continue }
            let number = (row["index"]?.integer ?? 0) + 1
            if (row["grants"]?.array ?? []).contains(where: refers) { add(.chapterGrant(number)) }
            for egg in row["eggs"]?.array ?? [] {
                guard let eggRow = egg.object, (eggRow["rewards"]?.array ?? []).contains(where: refers) else { continue }
                add(.chapterEgg(number, eggRow["name"]?.text ?? ""))
            }
        }
        let game = theme["gameplayRuntime"]?.object ?? [:]
        if (game["survival"]?.object?["rations"]?.array ?? []).contains(where: refers) { add(.ration) }
        for facility in game["facilities"]?.array ?? [] {
            guard let row = facility.object, (row["when"]?.array ?? []).contains(where: refers) else { continue }
            add(.facility(row["name"]?.text ?? ""))
        }
        return out
    }

    /// MP `onKeysItemChange` action `add`: a new ITEM row with a generated id and no image.
    public static func addItem(named name: String, id: String, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxNameLength else { return draft }
        var theme = try ProjectEditThemeRules.readable(draft)
        if theme.isEmpty { theme = ProjectEditThemeRules.defaults }
        var rows = theme["items"]?.array ?? []
        rows.append(.object(["id": .string(id), "kind": .string("ITEM"), "name": .string(trimmed), "image": .string("")]))
        theme["items"] = .array(rows)
        return try ProjectEditThemeRules.write(theme, into: draft)
    }

    /// MP action `rename`: only the matching ITEM row's name changes.
    public static func renameItem(_ id: String, to name: String, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxNameLength else { return draft }
        var theme = try ProjectEditThemeRules.readable(draft)
        var rows = theme["items"]?.array ?? []
        guard let index = itemIndex(id, in: rows), var row = rows[index].object else { return draft }
        row["name"] = .string(trimmed)
        rows[index] = .object(row)
        theme["items"] = .array(rows)
        return try ProjectEditThemeRules.write(theme, into: draft)
    }

    /// MP action `delete`: refused while the item is used (MP toast 物品正在用于：…); the caller shows the places.
    public static func deleteItem(_ id: String, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var theme = try ProjectEditThemeRules.readable(draft)
        var rows = theme["items"]?.array ?? []
        guard let index = itemIndex(id, in: rows) else { return draft }
        guard usedIn(theme, itemID: id).isEmpty else { return draft }
        rows.remove(at: index)
        theme["items"] = .array(rows)
        return try ProjectEditThemeRules.write(theme, into: draft)
    }

    /// MP new item id: `i` + base-36 time + 4 random characters.
    public static func newItemID(now: Date = Date()) -> String {
        let millis = Int64(now.timeIntervalSince1970 * 1000)
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(4))
        return "i" + String(millis, radix: 36) + suffix
    }

    /// MP `parseUsedIn`: a refused delete answers `…引用位置：A、B`; only the places are kept.
    public static func usedIn(fromRefusal message: String) -> [String] {
        guard let range = message.range(of: "引用位置[:：]", options: .regularExpression) else { return [] }
        return message[range.upperBound...].split(separator: "、").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func itemIndex(_ id: String, in rows: [ProjectEditJSON]) -> Int? {
        rows.firstIndex { $0.object?["kind"]?.text == "ITEM" && Self.itemID($0.object?["id"]) == id }
    }

    /// Item ids are strings in new configs and may be numbers in old ones; both compare as text.
    private static func itemID(_ value: ProjectEditJSON?) -> String? {
        switch value {
        case .string(let text)?: return text.isEmpty ? nil : text
        case .number(let number)?: return NSDecimalNumber(decimal: number).stringValue
        default: return nil
        }
    }
}
