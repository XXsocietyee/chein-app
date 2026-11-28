import Foundation

/// First-chapter UI for the existing topic-level journeyRules. Never edits thought/attribute definitions.
public struct ProjectInitialState {
    public enum Kind: String, CaseIterable, Hashable { case hp, luck }
    public struct Resource: Equatable {
        public var enabled: Bool
        public var initial: String
        public var maximum: String
    }
    public struct RecoveryChange: Identifiable, Equatable {
        public let key: String
        public let before: Int
        public let after: Int
        public var id: String { key }
    }
    /// MP `theme-initial-carry.js` 开局带着: `attributes` rows keyed `clue.*` / `tag.*` with initial 1.
    public struct CarryRow: Identifiable, Equatable {
        public let key: String
        public let label: String
        public let isClue: Bool
        public var id: String { key }
    }
    /// MP `customInitialValues`: one card per `counter.*` attribute row (title, `min 至 max`, 开局 stepper).
    public struct CounterRow: Identifiable, Equatable {
        public let key: String
        public let label: String
        public let initial: Int?
        public let minimum: Int
        public let maximum: Int
        public var id: String { key }
        /// MP `invalidInitial`: empty, not an integer, or outside min…max.
        public var invalid: Bool { initial.map { $0 < minimum || $0 > maximum } ?? true }
    }
    public private(set) var readOnly = false
    private var attributeRows: [ProjectEditJSON]?
    private var carryEdited = false
    private var carryAdded = false
    public var hp = Resource(enabled: false, initial: "10", maximum: "10")
    public var luck = Resource(enabled: false, initial: "3", maximum: "3")
    private var originalHP = Resource(enabled: false, initial: "10", maximum: "10")
    private var originalLuck = Resource(enabled: false, initial: "3", maximum: "3")
    private let raw: ProjectEditJSON?
    private var root: [String: ProjectEditJSON] = [:]
    private static let recoveryDefaults = ["stationEndIfHurt": 2, "stageRestHpFloor": 6, "stageRestLuckFloor": 1, "exhaustRestHp": 5]
    public init(raw: ProjectEditJSON?) {
        self.raw = raw
        do {
            let fresh: Bool
            if raw == nil || raw == .null { fresh = true }
            else if let text = raw?.text {
                fresh = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if !fresh {
                    let bytes = Data(text.utf8); guard bytes.count <= 16 * 1024 else { throw ProjectEditError.invalidDraft }
                    root = try ApprovedTopicReleaseWire.envelope(bytes)
                }
            } else { throw ProjectEditError.invalidDraft }
            if let version = root["schemaVersion"], version != .null, version.integer != 1 { throw ProjectEditError.invalidDraft }
            _ = try Self.boolean(root["stateEnabled"], fallback: false)
            if let attributes = root["attributes"], attributes != .null, attributes.array == nil { throw ProjectEditError.invalidDraft }
            hp = try Self.resource(root["hp"], fallback: .init(enabled: !fresh, initial: "10", maximum: "10"))
            luck = try Self.resource(root["luck"], fallback: .init(enabled: !fresh, initial: "3", maximum: "3"))
            let recovery = try Self.object(root["recovery"])
            for (key, fallback) in Self.recoveryDefaults { _ = try Self.integer(recovery[key], fallback: fallback) }
            attributeRows = root["attributes"]?.array
            originalHP = hp; originalLuck = luck
        } catch { readOnly = true }
    }
    public mutating func setEnabled(_ enabled: Bool, kind: Kind) {
        guard !readOnly else { return }
        switch kind {
        case .hp: if !enabled { hp = originalHP }; hp.enabled = enabled
        case .luck: if !enabled { luck = originalLuck }; luck.enabled = enabled
        }
    }
    /// MP `_carryLocked`: a bound attribute registry owns the rows, so 开局带着 is read-only there.
    public var carryLocked: Bool { readOnly || (root["attributeBinding"].map { $0 != .null } ?? false) }
    public var carry: [CarryRow] {
        (attributeRows ?? []).compactMap { row -> CarryRow? in
            guard let object = row.object, let key = object["key"]?.text else { return nil }
            let isClue = key.hasPrefix("clue."), isTag = key.hasPrefix("tag.")
            guard isClue || isTag, Self.carryInitial(object["initial"]) == 1 else { return nil }
            return .init(key: key, label: object["label"]?.text ?? key, isClue: isClue)
        }
    }
    /// MP `removeCarry`: drops the attribute row for that key.
    public mutating func removeCarry(_ key: String) {
        guard !carryLocked, let rows = attributeRows else { return }
        let next = rows.filter { $0.object?["key"]?.text != key }
        guard next.count != rows.count else { return }
        attributeRows = next; carryEdited = true
    }
    public var counters: [CounterRow] {
        (attributeRows ?? []).compactMap { row -> CounterRow? in
            guard let object = row.object, let key = object["key"]?.text,
                  key.range(of: Self.counterPattern, options: .regularExpression) != nil else { return nil }
            let minimum = Self.carryInitial(object["min"]) ?? 0
            let maximum = Self.carryInitial(object["max"]) ?? minimum
            return .init(key: key, label: object["label"]?.text ?? key, initial: Self.carryInitial(object["initial"]),
                         minimum: minimum, maximum: maximum)
        }
    }
    /// MP `onInitialStateField` `attribute.initial`: a bound registry owns the values (初值由注册定义管理).
    public mutating func setCounterInitial(_ key: String, value: Int) {
        guard !carryLocked, let rows = attributeRows else { return }
        var changed = false
        let next = rows.map { row -> ProjectEditJSON in
            guard var object = row.object, object["key"]?.text == key,
                  key.range(of: Self.counterPattern, options: .regularExpression) != nil,
                  Self.carryInitial(object["initial"]) != value else { return row }
            object["initial"] = .number(Decimal(value)); changed = true
            return .object(object)
        }
        guard changed else { return }
        attributeRows = next; carryEdited = true
    }
    static let counterPattern = "^counter\\.[a-z][a-z0-9_]{0,47}$"
    /// MP `confirmCarryPicker` limit: `journeyRules.attributes` holds at most 32 rows.
    public static let maxAttributeRows = 32
    /// MP `confirmCarryPicker`: picked keys already in `attributes` get initial 1; new ones are appended as
    /// `{key, label, initial: 1, min: 0, max: 1, visible: true}`, and the state switches on. Returns false (nothing
    /// changes) past 32 rows, where the MP shows 最多 32 项.
    @discardableResult public mutating func addCarry(_ picks: [(key: String, label: String)]) -> Bool {
        guard !carryLocked, !picks.isEmpty else { return false }
        let picked = Set(picks.map { $0.key })
        var rows = (attributeRows ?? []).map { row -> ProjectEditJSON in
            guard var object = row.object, let key = object["key"]?.text, picked.contains(key) else { return row }
            object["initial"] = .number(1)
            return .object(object)
        }
        var present = Set(rows.compactMap { $0.object?["key"]?.text })
        for pick in picks where !present.contains(pick.key) && (pick.key.hasPrefix("clue.") || pick.key.hasPrefix("tag.")) {
            rows.append(.object(["key": .string(pick.key), "label": .string(pick.label), "initial": .number(1),
                                 "min": .number(0), "max": .number(1), "visible": .bool(true)]))
            present.insert(pick.key)
        }
        guard rows.count <= Self.maxAttributeRows else { return false }
        attributeRows = rows; carryEdited = true; carryAdded = true
        return true
    }
    private static func carryInitial(_ raw: ProjectEditJSON?) -> Int? {
        if let value = raw?.integer { return value }
        if let text = raw?.text { return Int(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
    private static func object(_ raw: ProjectEditJSON?) throws -> [String: ProjectEditJSON] {
        guard let raw, raw != .null else { return [:] }
        guard let object = raw.object else { throw ProjectEditError.invalidDraft }; return object
    }
    private static func boolean(_ raw: ProjectEditJSON?, fallback: Bool) throws -> Bool {
        guard let raw, raw != .null else { return fallback }
        guard case .bool(let value) = raw else { throw ProjectEditError.invalidDraft }; return value
    }
    private static func integer(_ raw: ProjectEditJSON?, fallback: Int) throws -> Int {
        guard let raw, raw != .null else { return fallback }
        guard let value = raw.integer else { throw ProjectEditError.invalidDraft }; return value
    }
    private static func resource(_ raw: ProjectEditJSON?, fallback: Resource) throws -> Resource {
        let object = try object(raw)
        return try .init(enabled: boolean(object["enabled"], fallback: fallback.enabled),
                         initial: String(integer(object["init"], fallback: Int(fallback.initial)!)),
                         maximum: String(integer(object["max"], fallback: Int(fallback.maximum)!)))
    }
    private static func same(_ lhs: Resource, _ rhs: Resource) -> Bool {
        lhs.enabled == rhs.enabled && Int(lhs.initial) == Int(rhs.initial) && Int(lhs.maximum) == Int(rhs.maximum)
    }
    public var isUnchanged: Bool { !carryEdited && Self.same(hp, originalHP) && Self.same(luck, originalLuck) }
    private func values() throws -> (hpInitial: Int, hpMax: Int, luckInitial: Int, luckMax: Int) {
        guard !readOnly, let hpMax = Int(hp.maximum), (1...20).contains(hpMax),
              let hpInitial = Int(hp.initial), (1...hpMax).contains(hpInitial),
              let luckMax = Int(luck.maximum), (0...5).contains(luckMax),
              let luckInitial = Int(luck.initial), (0...luckMax).contains(luckInitial) else { throw ProjectEditError.invalidDraft }
        return (hpInitial, hpMax, luckInitial, luckMax)
    }
    private func recovery(values: (hpInitial: Int, hpMax: Int, luckInitial: Int, luckMax: Int)) throws -> [String: ProjectEditJSON] {
        var recovery = try Self.object(root["recovery"])
        for (key, fallback) in Self.recoveryDefaults {
            let old = try Self.integer(recovery[key], fallback: fallback)
            guard old >= 0 else { throw ProjectEditError.invalidDraft }
            recovery[key] = .number(Decimal(min(old, key == "stageRestLuckFloor" ? values.luckMax : values.hpMax)))
        }
        return recovery
    }
    public var recoveryChanges: [RecoveryChange] { recoveryChanges(includeUnchanged: false) }
    public var associatedRecoveryChanges: [RecoveryChange] { recoveryChanges(includeUnchanged: true) }
    private func recoveryChanges(includeUnchanged: Bool) -> [RecoveryChange] {
        guard !readOnly, includeUnchanged || !isUnchanged, let values = try? values(), let old = try? Self.object(root["recovery"]),
              let next = try? recovery(values: values) else { return [] }
        return Self.recoveryDefaults.keys.sorted().compactMap { key in
            guard let before = try? Self.integer(old[key], fallback: Self.recoveryDefaults[key]!),
                  let after = next[key]?.integer, before != after else { return nil }
            return .init(key: key, before: before, after: after)
        }
    }
    public func serialized(matching original: ProjectEditJSON?) throws -> ProjectEditJSON? {
        try serialized(matching: original, thoughtReplacement: nil)
    }
    /// Explicit associated edit, sharing the same source-safe defaults and recovery policy.
    public func serialized(replacingThoughts thoughts: [ProjectEditJSON], matching original: ProjectEditJSON?) throws -> ProjectEditJSON? {
        try serialized(matching: original, thoughtReplacement: thoughts)
    }
    private func serialized(matching original: ProjectEditJSON?, thoughtReplacement: [ProjectEditJSON]?) throws -> ProjectEditJSON? {
        let sourceEncoder = JSONEncoder(); sourceEncoder.outputFormatting = [.sortedKeys]
        let sourceBytes = try sourceEncoder.encode(raw.map { ["raw": $0] } ?? [:])
        let currentBytes = try sourceEncoder.encode(original.map { ["raw": $0] } ?? [:])
        guard !readOnly, sourceBytes == currentBytes else { throw ProjectEditError.invalidDraft }
        if isUnchanged && thoughtReplacement == nil { return raw } // Opening, cancel and numeric no-op never normalize the imported string.
        let values = try values()
        // MP `serialize` runs `values.attribute` on every counter row: 开局值 must sit inside its range.
        guard !counters.contains(where: { $0.invalid }) else { throw ProjectEditError.invalidDraft }
        var next = root, hpObject = try Self.object(root["hp"]), luckObject = try Self.object(root["luck"])
        hpObject["enabled"] = .bool(hp.enabled); hpObject["init"] = .number(Decimal(values.hpInitial)); hpObject["max"] = .number(Decimal(values.hpMax))
        luckObject["enabled"] = .bool(luck.enabled); luckObject["init"] = .number(Decimal(values.luckInitial)); luckObject["max"] = .number(Decimal(values.luckMax))
        next["hp"] = .object(hpObject); next["luck"] = .object(luckObject); next["schemaVersion"] = .number(1)
        if carryEdited, let attributeRows { next["attributes"] = .array(attributeRows) }
        let hasAttributes = next["attributes"]?.array?.isEmpty == false
        next["stateEnabled"] = .bool(thoughtReplacement != nil ? root["stateEnabled"] == .bool(true) :
            hp.enabled || luck.enabled || (carryAdded && hasAttributes) || (root["stateEnabled"] == .bool(true) && hasAttributes))
        next["recovery"] = .object(try recovery(values: values))
        if let thoughtReplacement { next["thoughts"] = thoughtReplacement.isEmpty ? nil : .array(thoughtReplacement) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let bytes = try encoder.encode(ProjectEditJSON.object(next))
        guard bytes.count <= 16 * 1024 else { throw ProjectEditError.invalidDraft }
        return .string(String(decoding: bytes, as: UTF8.self))
    }
}
