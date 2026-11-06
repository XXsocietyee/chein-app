import Foundation

/// Original theme envelope only. No new scene, node, template binding, checkId or source writer.
public enum NativeComponentAuthorDraft {
    public static let checkFields: Set<String> = ["skill", "category", "tier", "kind", "mods", "advantageIf", "disadvantageIf", "retryIf",
        "successText", "failText", "successEffects", "failEffects", "critEffects", "fumbleEffects", "failCostTag"]
    public struct Slot: Identifiable {
        public let id: String
        public let sceneID: String
        public let nodeID: Int
        public let title: String
        public let field: String
        public let surface: NativeConditionAuthorDocument.Surface
        public let parent: NativeConditionAuthorPath
    }
    public static func theme(_ draft: ProjectEditDraft) throws -> ProjectEditJSON {
        guard let text = draft.preserved["themeRuntimeConfig"]?.text, text.utf8.count <= 2 * 1024 * 1024 else { throw NativeConditionAuthorError.invalidJSON }
        let value = try NativeAttributeAuthorWire.decode(Data(text.utf8))
        guard value.object != nil, let scenes = value.object?["scenes"]?.array, scenes.count <= 50 else { throw NativeConditionAuthorError.invalidJSON }
        return value
    }
    public static func slots(draft: ProjectEditDraft, catalog: NativeComponentAuthorCatalog) throws -> [Slot] {
        let theme = try theme(draft)
        guard let scenes = theme.object?["scenes"]?.array else { throw NativeConditionAuthorError.invalidJSON }
        var seen = Set<String>(), result: [Slot] = []
        for (index, raw) in scenes.enumerated() {
            guard let scene = raw.object, let id = scene["id"]?.text, seen.insert(id).inserted,
                  let declarations = catalog.scenes.first(where: { $0.id.utf8.elementsEqual(id.utf8) }) else { throw NativeConditionAuthorError.staleEditor }
            let blocks: [String: ProjectEditJSON]
            if let value = scene["nodeConfigs"] { guard let object = value.object else { throw NativeConditionAuthorError.invalidJSON }; blocks = object }
            else { blocks = [:] }
            var nodes = Set<Int>()
            for key in blocks.keys.sorted() {
                guard let nodeID = Int(key), nodeID > 0, String(nodeID) == key, declarations.components.contains(nodeID),
                      nodes.insert(nodeID).inserted, let block = blocks[key]?.object, block["schemaVersion"] == .number(1) else { throw NativeConditionAuthorError.staleEditor }
                let parent = NativeConditionAuthorPath().field("scenes").index(index).field("nodeConfigs").field(key)
                let title = declarations.label + " · 节点 " + key
                for (field, surface) in [("requires", NativeConditionAuthorDocument.Surface.componentCondition), ("effects", .componentEffects)] {
                    // Null is not silently reinterpreted as an empty authored program.
                    if let value = block[field], value.array == nil && (surface != .componentCondition || value.object == nil) { continue }
                    result.append(.init(id: id + "/" + key + "/" + field, sceneID: id, nodeID: nodeID,
                        title: title + (field == "requires" ? " · 原前置条件" : " · 原完成效果"), field: field, surface: surface, parent: parent))
                }
                if let check = block["check"]?.object, check["enabled"] == .bool(true) {
                    result.append(.init(id: id + "/" + key + "/check", sceneID: id, nodeID: nodeID,
                        title: title + " · 原检定/修正/结果效果", field: "check", surface: .componentCheck, parent: parent))
                }
            }
            guard nodes == declarations.components else { throw NativeConditionAuthorError.staleEditor }
        }
        guard seen == Set(catalog.scenes.map(\.id)) else { throw NativeConditionAuthorError.staleEditor }
        return result
    }
    public static func value(draft: ProjectEditDraft, slot: Slot) throws -> ProjectEditJSON {
        guard let parent = NativeConditionAuthorTree.value(try theme(draft), at: slot.parent)?.object else { throw NativeConditionAuthorError.staleEditor }
        if let value = parent[slot.field] { return value }
        guard slot.surface != .componentCheck else { throw NativeConditionAuthorError.staleEditor }
        return .array([]) // An absent optional slot is created only after an explicit edit and original local save.
    }
    public static func raw(draft: ProjectEditDraft, slot: Slot) throws -> String {
        String(decoding: try NativeAttributeAuthorWire.encode(value(draft: draft, slot: slot)), as: UTF8.self)
    }
    public static func applying(_ raw: String, to draft: ProjectEditDraft, slot: Slot, expected: String) throws -> ProjectEditDraft {
        guard try self.raw(draft: draft, slot: slot).utf8.elementsEqual(expected.utf8) else { throw NativeConditionAuthorError.staleEditor }
        let original = try theme(draft), replacement = try NativeAttributeAuthorWire.decode(Data(raw.utf8))
        guard let parent = NativeConditionAuthorTree.value(original, at: slot.parent), var object = parent.object else { throw NativeConditionAuthorError.staleEditor }
        object[slot.field] = replacement
        let updated = try NativeConditionAuthorTree.replacing(original, at: slot.parent, expected: parent, with: .object(object))
        let data = try NativeAttributeAuthorWire.encode(updated)
        guard data.count <= 2 * 1024 * 1024, String(decoding: data, as: UTF8.self).utf16.count <= 200_000 else { throw NativeConditionAuthorError.invalidEdit }
        var next = draft; next.preserved["themeRuntimeConfig"] = .string(String(decoding: data, as: UTF8.self))
        guard try sourceMaterials(next) == sourceMaterials(draft) else { throw NativeConditionAuthorError.staleEditor }
        return next
    }
    /// These original fields cannot change declarations. Keep scene/node/check identity,
    /// specialized consumers, rules, graph, template IDs and all other bytes in the proof.
    public static func sourceMaterials(_ draft: ProjectEditDraft) throws -> Data {
        var source = try theme(draft)
        guard var object = source.object, var scenes = object["scenes"]?.array else { throw NativeConditionAuthorError.invalidJSON }
        for index in scenes.indices {
            guard var scene = scenes[index].object else { throw NativeConditionAuthorError.invalidJSON }
            if let raw = scene["nodeConfigs"] {
                guard var blocks = raw.object else { throw NativeConditionAuthorError.invalidJSON }
                for key in blocks.keys {
                    guard var block = blocks[key]?.object else { throw NativeConditionAuthorError.invalidJSON }
                    block.removeValue(forKey: "requires"); block.removeValue(forKey: "effects")
                    if var check = block["check"]?.object, check["enabled"] == .bool(true) {
                        for field in checkFields { check.removeValue(forKey: field) }; block["check"] = .object(check)
                    }
                    blocks[key] = .object(block)
                }
                scene["nodeConfigs"] = .object(blocks)
            }
            scenes[index] = .object(scene)
        }
        object["scenes"] = .array(scenes); source = .object(object)
        var projection = draft
        projection.preserved["themeRuntimeConfig"] = .string(String(decoding: try NativeAttributeAuthorWire.encode(source), as: UTF8.self))
        let common = try NativeConditionAuthorOriginalCatalog.sourceMaterials(projection)
        guard let graph = draft.preserved["routeGraphJson"]?.text else { throw NativeConditionAuthorError.invalidJSON }
        return try NativeAttributeAuthorWire.encode(.object(["originalMaterials": .string(common.base64EncodedString()), "routeGraph": .string(graph)]))
    }
}
