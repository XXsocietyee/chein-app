import Foundation

/// Node row「到达与引导」on `themeRuntimeConfig.gameplayRuntime.quests[]` (one quest per saved node).
/// Mini-program: `pages/publish/fabu/index.wxml:1022` row + `runtime-structure-editor.wxml` kind `quests`
/// + `theme-runtime-structure.js` `openStructure` / `onStructureLocation` / `onStructureGuide` /
/// `toggleStructureFallback` / `saveStructure` / `_refreshStructureSummary` (`nodeStructureSummary`).
/// The MP syncs chapters first, edits this node's quest (到达地点 · 工作人员引导答题 · 备用节点), then
/// validates the whole runtime config. This does not post; the topic save already carries `themeRuntimeConfig`.
/// 找不到时换个方式 keeps its own server write (`api/orient/task/alternative`, `OrientAlternativeEditorSection`).
public enum ProjectEditNodeArrival {
    public enum Copy {
        public static let unset = "projectNodeArrival.summary.unset"
        public static let reselect = "projectNodeArrival.summary.reselect"
        public static let unreadable = "mpPublish.rules.unreadable"
        public static let saveNode = "projectNodeArrival.refuse.saveNode"
        public static let challenge = "projectNodeArrival.refuse.challenge"
        public static let guideNotAllowed = "projectNodeArrival.refuse.guide"
        public static let fallbackLimit = "projectNodeArrival.refuse.fallbackLimit"
    }

    /// One 到达地点 choice: a saved node of this topic, or a shared place key another quest already uses.
    public struct Place: Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String
        /// Set for a node place; nil for a shared place kept from existing data.
        public let nodeNumber: Int?
    }

    /// One 备用节点 row (another saved node of this topic).
    public struct Stop: Identifiable, Equatable, Sendable {
        public let id: Int
        public let name: String
    }

    /// What the arrival page shows for one node. `refusalKey` set = nothing to edit yet (MP error line).
    public struct State: Equatable, Sendable {
        public let refusalKey: String?
        public let places: [Place]
        public let placeKey: String?
        public let guide: Bool
        public let stops: [Stop]
        public let fallbackIDs: [Int]
    }

    /// MP `nodeStructureSummary`: 未配置 without a quest, else the place name, or 需重选 when the place is gone.
    public enum Summary: Equatable, Sendable {
        case key(String)
        case place(Place)
    }

    public static let fallbackLimit = 20

    public static func summary(nodeID: Int, in draft: ProjectEditDraft) -> Summary {
        guard let author = try? NativeRuntimeStructureAuthorDraft(draft: draft),
              let quest = author.quest(nodeID: nodeID) else { return .key(Copy.unset) }
        guard let key = quest["locationKey"]?.text,
              let place = places(author).first(where: { $0.id == key }) else { return .key(Copy.reselect) }
        return .place(place)
    }

    public static func state(nodeID: Int, in draft: ProjectEditDraft) -> State {
        guard var author = try? NativeRuntimeStructureAuthorDraft(draft: draft) else { return refused(Copy.unreadable) }
        if let blocked = ProjectEditRuntimeActs.refusalBeforeSync(author) { return refused(blocked) }
        do { try author.synchronizeChapters() } catch { return refused(Copy.unreadable) }
        guard nodeID > 0 else { return refused(Copy.saveNode) }
        guard let quest = author.quest(nodeID: nodeID) else {
            return refused(author.challengeIDs.contains(nodeID) ? Copy.challenge : Copy.saveNode)
        }
        let stops = author.savedNodes.compactMap { node -> Stop? in
            guard let id = node.localMetadata["id"]?.integer, id > 0, id != nodeID else { return nil }
            return Stop(id: id, name: node.name)
        }
        let known = Set(stops.map(\.id))
        let chosen = (quest["approvedFallbackNodeIds"]?.array ?? []).compactMap(\.integer).filter { known.contains($0) }
        return State(refusalKey: nil, places: places(author), placeKey: quest["locationKey"]?.text,
                     guide: quest["guideKey"] != nil && quest["guideKey"] != .null, stops: stops, fallbackIDs: chosen)
    }

    /// MP `structureGuideAllowed`: the node's gameplay has an objective-question main row (support matrix read).
    public static func guideAllowed(nodeID: Int, in draft: ProjectEditDraft, inputs: NativeRuntimeStructureAuthorInputs?) -> Bool {
        guard let inputs, let author = try? NativeRuntimeStructureAuthorDraft(draft: draft),
              let node = author.savedNodes.first(where: { $0.localMetadata["id"]?.integer == nodeID }) else { return false }
        return inputs.guideAllowed(node, theme: author.theme)
    }

    /// MP `saveStructure` for kind `quests`: sync chapters, write this node's quest, validate the config.
    /// Turning the guide on needs the support matrix (MP `structureGuideAllowed`); turning it off never does.
    public static func save(nodeID: Int, placeKey: String, guide: Bool, fallbackIDs: [Int],
                            in draft: ProjectEditDraft, inputs: NativeRuntimeStructureAuthorInputs?) throws -> ProjectEditDraft {
        var author = try readable(draft)
        if let blocked = ProjectEditRuntimeActs.refusalBeforeSync(author) { throw ProjectEditRuntimeActsError.refused(blocked) }
        try author.synchronizeChapters()
        guard let quest = author.quest(nodeID: nodeID) else {
            throw ProjectEditRuntimeActsError.refused(author.challengeIDs.contains(nodeID) ? Copy.challenge : Copy.saveNode)
        }
        guard fallbackIDs.count <= fallbackLimit, Set(fallbackIDs).count == fallbackIDs.count else {
            throw ProjectEditRuntimeActsError.refused(Copy.fallbackLimit)
        }
        if quest["locationKey"]?.text != placeKey { try author.location(nodeID: nodeID, key: placeKey) }
        let hasGuide = quest["guideKey"] != nil && quest["guideKey"] != .null
        if guide != hasGuide {
            if guide {
                guard let inputs, let node = author.savedNodes.first(where: { $0.localMetadata["id"]?.integer == nodeID }),
                      inputs.guideAllowed(node, theme: author.theme) else { throw ProjectEditRuntimeActsError.refused(Copy.guideNotAllowed) }
                try author.guide(nodeID: nodeID, enabled: true, inputs: inputs)
            } else {
                try author.clearGuide(nodeID: nodeID)
            }
        }
        let current = (quest["approvedFallbackNodeIds"]?.array ?? []).compactMap(\.integer)
        let saved = Set(author.savedNodes.compactMap { $0.localMetadata["id"]?.integer })
        for other in current where !fallbackIDs.contains(other) {
            if saved.contains(other) { try author.fallback(nodeID: nodeID, other: other, selected: false) }
            else { try author.removeStaleFallback(nodeID: nodeID, other: other) }
        }
        for other in fallbackIDs where !current.contains(other) {
            try author.fallback(nodeID: nodeID, other: other, selected: true)
        }
        if let issue = author.issues.first { throw ProjectEditNodeArrivalError.issue(issue) }
        return try ProjectEditThemeRules.write(author.theme, into: draft)
    }

    private static func readable(_ draft: ProjectEditDraft) throws -> NativeRuntimeStructureAuthorDraft {
        do { return try NativeRuntimeStructureAuthorDraft(draft: draft) } catch { throw ProjectEditRuntimeActsError.refused(Copy.unreadable) }
    }

    private static func refused(_ key: String) -> State {
        State(refusalKey: key, places: [], placeKey: nil, guide: false, stops: [], fallbackIDs: [])
    }

    /// Same list as `NativeRuntimeStructureAuthorDraft.locations`, without the Chinese display text.
    private static func places(_ author: NativeRuntimeStructureAuthorDraft) -> [Place] {
        var result: [Place] = author.savedNodes.compactMap { node -> Place? in
            guard let id = node.localMetadata["id"]?.integer else { return nil }
            return Place(id: "node_\(id)", name: node.name, nodeNumber: id)
        }
        for quest in author.quests {
            if let key = quest["locationKey"]?.text, !result.contains(where: { $0.id == key }) {
                result.append(Place(id: key, name: "", nodeNumber: nil))
            }
        }
        return result
    }
}

/// A whole-config check failed after the change (MP `validate` sentence, shown as is).
public enum ProjectEditNodeArrivalError: Error, Equatable {
    case issue(String)
}
