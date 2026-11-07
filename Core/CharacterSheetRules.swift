import Foundation

// MARK: - Character Sheet & RPG Status Rules (Ported from subpackageMember/character/index.js & utils/user-character.js)

public struct CharacterAttributeLevel: Equatable, Sendable {
    public let at: Int
    public let label: String

    public init(at: Int, label: String) {
        self.at = at
        self.label = label
    }
}

public struct CharacterStarPip: Equatable, Identifiable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let filled: Bool

    public init(index: Int, filled: Bool) {
        self.index = index
        self.filled = filled
    }
}

extension CharacterCardAttribute {
    public init(
        stateKey: String,
        label: String,
        value: Int,
        min: Int,
        max: Int,
        displayType: String,
        persistScope: String,
        levels: [CharacterAttributeLevel]
    ) {
        self.init(
            stateKey: stateKey,
            label: label,
            value: value,
            min: min,
            max: max,
            displayType: displayType,
            persistScope: persistScope
        )
    }

    public func levelLabel(levels: [CharacterAttributeLevel] = []) -> String {
        let sorted = levels.filter { !$0.label.isEmpty }.sorted { $0.at < $1.at }
        var matched = ""
        for level in sorted where value >= level.at {
            matched = level.label
        }
        return matched
    }

    public var scopeText: String {
        switch persistScope {
        case "topic": return "同主题跨局保留"
        case "run": return "每局重置"
        default: return "保留范围未记录"
        }
    }

    public var rangeText: String {
        "范围 \(min)–\(max)"
    }

    public var percent: Int {
        guard max > min else { return 0 }
        let raw = Double(value - min) / Double(max - min) * 100.0
        return Swift.max(0, Swift.min(100, Int(raw.rounded())))
    }

    public var stars: [CharacterStarPip] {
        guard displayType == "stars", min == 0, max > 0, max <= 10 else { return [] }
        return (0..<max).map { idx in
            CharacterStarPip(index: idx, filled: idx < value)
        }
    }
}

public struct CharacterRpgMomentum: Equatable, Sendable {
    public let value: Int
    public let max: Int
    public let percent: Int

    public init(value: Int, max: Int) {
        let clampedMax = Swift.max(1, max)
        let clampedVal = Swift.max(0, Swift.min(clampedMax, value))
        self.value = clampedVal
        self.max = clampedMax
        self.percent = Int((Double(clampedVal) / Double(clampedMax) * 100.0).rounded())
    }
}

public struct CharacterRpgClock: Equatable, Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let label: String
    public let value: Int
    public let segments: Int
    public let percent: Int

    public init(key: String, label: String, value: Int, segments: Int) {
        let seg = Swift.max(1, segments)
        let val = Swift.max(0, Swift.min(seg, value))
        self.key = key
        self.label = label
        self.value = val
        self.segments = seg
        self.percent = Int((Double(val) / Double(seg) * 100.0).rounded())
    }
}

public struct CharacterRpgTrait: Equatable, Identifiable, Sendable {
    public var id: String { "\(tag):\(key)" }
    public let key: String
    public let label: String
    public let desc: String
    public let tag: String

    public init(key: String, label: String, desc: String, tag: String) {
        self.key = key
        self.label = label
        self.desc = desc
        self.tag = tag
    }
}

public struct CharacterRpgSheet: Equatable, Sendable {
    public let momentum: CharacterRpgMomentum?
    public let clocks: [CharacterRpgClock]
    public let facets: [CharacterRpgTrait]
    public let aspects: [CharacterRpgTrait]

    public init(
        momentum: CharacterRpgMomentum?,
        clocks: [CharacterRpgClock],
        facets: [CharacterRpgTrait],
        aspects: [CharacterRpgTrait]
    ) {
        self.momentum = momentum
        self.clocks = clocks
        self.facets = facets
        self.aspects = aspects
    }

    public static func read(_ raw: PlayWireValue) -> CharacterRpgSheet? {
        guard raw.object != nil, raw["enabled"].bool == true else { return nil }
        let momentum: CharacterRpgMomentum?
        if let mVal = raw["momentum"].integer, let mMax = raw["momentumMax"].integer, mMax > 0 {
            momentum = CharacterRpgMomentum(value: mVal, max: mMax)
        } else {
            momentum = nil
        }
        let clocks: [CharacterRpgClock] = (raw["clocks"].array ?? []).enumerated().compactMap { idx, c in
            guard c.object != nil,
                  let val = c["value"].integer,
                  let seg = c["segments"].integer, seg > 0 else { return nil }
            let key = c["var"].text ?? "clock-\(idx)"
            let label = (c["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? key
            return CharacterRpgClock(key: key, label: label, value: val, segments: seg)
        }
        let facets: [CharacterRpgTrait] = (raw["facets"].array ?? []).enumerated().compactMap { idx, f in
            guard f.object != nil,
                  let label = f["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else { return nil }
            let key = f["key"].text ?? "facet-\(idx)"
            let desc = f["desc"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return CharacterRpgTrait(key: key, label: label, desc: desc, tag: "侧面")
        }
        let aspects: [CharacterRpgTrait] = (raw["aspects"].array ?? []).enumerated().compactMap { idx, a in
            guard a.object != nil,
                  let label = a["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else { return nil }
            let key = a["key"].text ?? "aspect-\(idx)"
            let desc = a["desc"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return CharacterRpgTrait(key: key, label: label, desc: desc, tag: "本局特质")
        }
        if momentum == nil && clocks.isEmpty && facets.isEmpty && aspects.isEmpty {
            return nil
        }
        return CharacterRpgSheet(momentum: momentum, clocks: clocks, facets: facets, aspects: aspects)
    }
}

extension CharacterCard {
    public var heading: String {
        created ? "本人角色卡" : "角色模板"
    }

    public var statusText: String {
        if created {
            return running ? "本局进行中" : "已建立"
        }
        return "尚未建卡"
    }

    public func definitionNote(for definitionSource: String? = nil) -> String {
        switch definitionSource {
        case "SESSION_SNAPSHOT_PARTIAL":
            return "部分跨局属性展示当前主题定义，不代表建卡时原始区间。"
        case "SESSION_SNAPSHOT_V1":
            return "展示本局开始时的角色属性定义。"
        case "LEGACY_LIVE":
            return "历史角色未保存建卡快照，当前按主题最新规则展示。"
        default:
            return created
                ? "仅展示服务端已记录的本人角色数值。"
                : "当前尚未建立本人角色，以下为主题属性模板与初始值。"
        }
    }
}

/// Ported from `utils/user-character.js` for character sheet & topic relation checks.
public enum CharacterSheetPresenter {
    public struct FailureView: Equatable, Sendable {
        public let state: String
        public let error: String
        public let canRetry: Bool
    }

    public static func exactId(_ value: String?) -> String {
        let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: "^[1-9]\\d*$", options: .regularExpression) != nil else { return "" }
        return text
    }

    public static func exactId(_ value: Int?) -> String {
        guard let value, value > 0 else { return "" }
        return String(value)
    }

    public static func registrationTopic(_ item: PlayWireValue) -> (topicId: String, activityId: String)? {
        guard item.object != nil else { return nil }
        let topicId = exactId(item["topicId"].text ?? item["topicId"].integer.map(String.init))
            .isEmpty ? exactId(item["ownerType"].integer == 1 ? (item["ownerId"].text ?? item["ownerId"].integer.map(String.init)) : nil)
            : exactId(item["topicId"].text ?? item["topicId"].integer.map(String.init))
        guard !topicId.isEmpty else { return nil }
        let actRaw = item["activityId"].text ?? item["activityId"].integer.map(String.init)
        let ownerActRaw = item["ownerType"].integer == 0 ? (item["ownerId"].text ?? item["ownerId"].integer.map(String.init)) : nil
        let activityId = !exactId(actRaw).isEmpty ? exactId(actRaw) : exactId(ownerActRaw)
        return (topicId: topicId, activityId: activityId)
    }

    public static func hasTopicRelation(rows: [PlayWireValue], topicID: String) -> Bool {
        let target = exactId(topicID)
        guard !target.isEmpty else { return false }
        return rows.contains { registrationTopic($0)?.topicId == target }
    }

    public static func failure(code: Int?, message: String?) -> FailureView {
        if code == 401 {
            return FailureView(state: "unauthorized", error: "请先登录后查看角色卡", canRetry: false)
        }
        let msg = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if code == 403 || msg.contains("无权") {
            return FailureView(state: "forbidden", error: msg.isEmpty ? "无权查看该角色卡" : msg, canRetry: false)
        }
        return FailureView(state: "error", error: msg.isEmpty ? "角色卡加载失败，请稍后重试" : msg, canRetry: true)
    }
}
