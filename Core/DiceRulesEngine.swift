import Foundation

// MARK: - Theme D20 Authoring & Runtime Rules (Ported from pages/publish/fabu/theme-d20.js)

public struct DiceD20Preset: Equatable, Sendable {
    public let key: String
    public let label: String
    public let sub: String
    public let dcs: [Int]
    public let seg: Int

    public init(key: String, label: String, sub: String, dcs: [Int], seg: Int) {
        self.key = key
        self.label = label
        self.sub = sub
        self.dcs = dcs
        self.seg = seg
    }
}

public struct DiceAttrPreset: Equatable, Sendable {
    public let key: String
    public let name: String
    public let initial: Int
    public let min: Int
    public let max: Int

    public init(key: String, name: String, initial: Int, min: Int, max: Int) {
        self.key = key
        self.name = name
        self.initial = initial
        self.min = min
        self.max = max
    }
}

public struct DiceAspectPreset: Equatable, Sendable {
    public let key: String
    public let label: String
    public let desc: String

    public init(key: String, label: String, desc: String) {
        self.key = key
        self.label = label
        self.desc = desc
    }
}

public struct DiceClockKind: Equatable, Sendable {
    public let key: String
    public let label: String
    public let sub: String

    public init(key: String, label: String, sub: String) {
        self.key = key
        self.label = label
        self.sub = sub
    }
}

public struct DicePlayWindow: Equatable, Sendable {
    public let key: String
    public let label: String
    public let sub: String

    public init(key: String, label: String, sub: String) {
        self.key = key
        self.label = label
        self.sub = sub
    }
}

public struct DiceThemeAttribute: Codable, Equatable, Sendable {
    public var key: String
    public var name: String
    public var initial: Int
    public var min: Int
    public var max: Int

    public init(key: String, name: String, initial: Int = 2, min: Int = 0, max: Int = 5) {
        self.key = key
        self.name = name
        self.initial = initial
        self.min = min
        self.max = max
    }
}

public struct DiceThemeClock: Codable, Equatable, Sendable {
    public var `var`: String
    public var label: String
    public var kind: String
    public var segments: Int

    public init(variable: String, label: String, kind: String = "danger", segments: Int = 6) {
        self.var = variable
        self.label = label
        self.kind = kind
        self.segments = segments
    }
}

public struct DiceThemeAspect: Codable, Equatable, Sendable {
    public var key: String
    public var label: String
    public var desc: String

    public init(key: String, label: String, desc: String = "") {
        self.key = key
        self.label = label
        self.desc = desc
    }
}

public struct DiceThemeD20Readout: Equatable, Sendable {
    public var enabled: Bool
    public var preset: String
    public var dcs: [Int]
    public var checkEnabled: Bool
    public var attrs: [DiceThemeAttribute]
    public var clocks: [DiceThemeClock]
    public var aspects: [DiceThemeAspect]

    public init(
        enabled: Bool,
        preset: String,
        dcs: [Int],
        checkEnabled: Bool,
        attrs: [DiceThemeAttribute],
        clocks: [DiceThemeClock],
        aspects: [DiceThemeAspect]
    ) {
        self.enabled = enabled
        self.preset = preset
        self.dcs = dcs
        self.checkEnabled = checkEnabled
        self.attrs = attrs
        self.clocks = clocks
        self.aspects = aspects
    }
}

public struct DiceThemeJourneyConfig: Codable, Equatable, Sendable {
    public var stateEnabled: Bool
    public var attributes: [DiceThemeAttribute]
    public var d20Preset: String?
    public var checkEnabled: Bool?
    public var playWindow: String?
    public var prepItems: [String]?
    public var dcs: [Int]?
    public var clocks: [DiceThemeClock]
    public var aspects: [DiceThemeAspect]
    public var momentumMax: Int?

    public init(
        stateEnabled: Bool = false,
        attributes: [DiceThemeAttribute] = [],
        d20Preset: String? = nil,
        checkEnabled: Bool? = nil,
        playWindow: String? = nil,
        prepItems: [String]? = nil,
        dcs: [Int]? = nil,
        clocks: [DiceThemeClock] = [],
        aspects: [DiceThemeAspect] = [],
        momentumMax: Int? = nil
    ) {
        self.stateEnabled = stateEnabled
        self.attributes = attributes
        self.d20Preset = d20Preset
        self.checkEnabled = checkEnabled
        self.playWindow = playWindow
        self.prepItems = prepItems
        self.dcs = dcs
        self.clocks = clocks
        self.aspects = aspects
        self.momentumMax = momentumMax
    }
}

public enum DiceThemeD20Rules {
    public static let attrCeil = 20
    public static let clockSegments = [4, 6, 8]

    public static let presets: [DiceD20Preset] = [
        DiceD20Preset(key: "easy", label: W8Text.t("轻松", "Easy"), sub: W8Text.t("多数人能过，重在体验故事", "Most people pass; focus on the story"), dcs: [8, 11, 14], seg: 8),
        DiceD20Preset(key: "std", label: W8Text.t("标准", "Standard"), sub: W8Text.t("有来有回，点数与运气都算数", "Back and forth; both rolls and luck count"), dcs: [10, 13, 16], seg: 6),
        DiceD20Preset(key: "hard", label: W8Text.t("硬核", "Hardcore"), sub: W8Text.t("得靠道具、线索和队友配合", "Needs items, clues and teammates"), dcs: [12, 15, 18], seg: 4),
    ]

    public static let attrPresets: [DiceAttrPreset] = [
        DiceAttrPreset(key: "counter.observe", name: W8Text.t("观察", "Observation"), initial: 2, min: 0, max: 5),
        DiceAttrPreset(key: "counter.nerve", name: W8Text.t("胆量", "Nerve"), initial: 2, min: 0, max: 5),
        DiceAttrPreset(key: "counter.physique", name: W8Text.t("体魄", "Physique"), initial: 2, min: 0, max: 5),
        DiceAttrPreset(key: "counter.wit", name: W8Text.t("灵感", "Insight"), initial: 2, min: 0, max: 5),
        DiceAttrPreset(key: "counter.agility", name: W8Text.t("敏捷", "Agility"), initial: 2, min: 0, max: 5),
        DiceAttrPreset(key: "counter.charm", name: W8Text.t("魅力", "Charm"), initial: 2, min: 0, max: 5),
        DiceAttrPreset(key: "counter.luck", name: W8Text.t("运气", "Luck"), initial: 2, min: 0, max: 5),
    ]

    public static let clockKinds: [DiceClockKind] = [
        DiceClockKind(key: "danger", label: W8Text.t("危险钟", "Danger clock"), sub: W8Text.t("走满会触发坏事，比如巡夜人警觉", "When full, something bad happens, e.g. the night watch is alerted")),
        DiceClockKind(key: "progress", label: W8Text.t("进度钟", "Progress clock"), sub: W8Text.t("走满会解开一件事，比如破译旧海图", "When full, something unlocks, e.g. an old sea chart is deciphered")),
    ]

    public static let aspectPresets: [DiceAspectPreset] = [
        DiceAspectPreset(key: "hurt", label: W8Text.t("受了伤", "Injured"), desc: W8Text.t("体魄或敏捷检定更吃力", "Physique or Agility checks are harder")),
        DiceAspectPreset(key: "soaked", label: W8Text.t("淋湿了", "Soaked"), desc: W8Text.t("需要生火或找地方休整", "Need a fire or a place to rest")),
        DiceAspectPreset(key: "alerted", label: W8Text.t("被人盯上", "Being watched"), desc: W8Text.t("潜行与打听会更难", "Sneaking and asking around get harder")),
        DiceAspectPreset(key: "inspired", label: W8Text.t("灵光一闪", "Flash of insight"), desc: W8Text.t("下一次推理检定更有把握", "The next reasoning check is easier")),
        DiceAspectPreset(key: " disguised", label: W8Text.t("乔装打扮", "Disguised"), desc: W8Text.t("混进特定场所更顺利", "Blending into places is easier")),
        DiceAspectPreset(key: "exhausted", label: W8Text.t("精疲力竭", "Exhausted"), desc: W8Text.t("先去歇脚点恢复", "Rest at a stop first")),
    ]

    public static let windows: [DicePlayWindow] = [
        DicePlayWindow(key: "all", label: W8Text.t("全天可玩", "Playable all day"), sub: W8Text.t("不限时段", "Any time")),
        DicePlayWindow(key: "day", label: W8Text.t("白天场", "Daytime"), sub: W8Text.t("适合日间散步与门店营业时段", "Fits daytime walks and shop opening hours")),
        DicePlayWindow(key: "dusk", label: W8Text.t("傍晚场", "Dusk"), sub: W8Text.t("日落前后气氛最佳", "Best around sunset")),
        DicePlayWindow(key: "night", label: W8Text.t("夜行场", "Night"), sub: W8Text.t("入夜后体验最佳", "Best after dark")),
    ]

    public static let prepSuggestions: [String] = [
        W8Text.t("穿好走的鞋", "Wear comfortable shoes"), W8Text.t("带耳机", "Bring headphones"), W8Text.t("手机充好电", "Charge your phone"), W8Text.t("建议结伴", "Going with friends is recommended"), W8Text.t("带把伞", "Bring an umbrella"), W8Text.t("夜里注意保暖", "Dress warmly at night")
    ]

    public static func presetOf(_ dcs: [Int]?) -> String {
        guard let dcs, dcs.count == 3 else { return "std" }
        return presets.first(where: { $0.dcs == dcs })?.key ?? "std"
    }

    public static func read(_ journey: DiceThemeJourneyConfig?) -> DiceThemeD20Readout {
        let j = journey ?? DiceThemeJourneyConfig()
        let attrs = j.attributes.filter { $0.key.hasPrefix("counter.") }
        let clocks = j.clocks.map { c in
            DiceThemeClock(
                variable: c.var,
                label: c.label,
                kind: c.kind == "progress" ? "progress" : "danger",
                segments: clockSegments.contains(c.segments) ? c.segments : 6
            )
        }
        let aspects = j.aspects.map { a in
            DiceThemeAspect(key: a.key, label: a.label, desc: a.desc)
        }
        let enabled = j.stateEnabled && (!attrs.isEmpty || !clocks.isEmpty || !aspects.isEmpty || j.dcs != nil || j.d20Preset != nil)
        let preset = presets.first(where: { $0.key == j.d20Preset })?.key ?? presetOf(j.dcs)
        let dcs = (j.dcs?.count == 3 ? j.dcs : nil) ?? presets.first(where: { $0.key == preset })?.dcs ?? [10, 13, 16]
        let checkEnabled = j.checkEnabled != false
        return DiceThemeD20Readout(
            enabled: enabled,
            preset: preset,
            dcs: dcs,
            checkEnabled: checkEnabled,
            attrs: attrs,
            clocks: clocks,
            aspects: aspects
        )
    }

    public static func clampAttr(_ raw: DiceThemeAttribute) -> DiceThemeAttribute {
        let lo = max(0, min(attrCeil - 1, raw.min))
        let hi = max(lo + 1, min(attrCeil, raw.max))
        let initVal = max(lo, min(hi, raw.initial))
        return DiceThemeAttribute(
            key: raw.key,
            name: raw.name.trimmingCharacters(in: .whitespacesAndNewlines),
            initial: initVal,
            min: lo,
            max: hi
        )
    }

    public static func newAttr(presetOrName: String, existing: [DiceThemeAttribute] = []) -> DiceThemeAttribute {
        let used = Set(existing.map(\.key))
        if let preset = attrPresets.first(where: { $0.key == presetOrName || $0.name == presetOrName }), !used.contains(preset.key) {
            return DiceThemeAttribute(key: preset.key, name: preset.name, initial: preset.initial, min: preset.min, max: preset.max)
        }
        var index = existing.count + 1
        while used.contains("counter.attr_\(index)") { index += 1 }
        let trimmed = presetOrName.trimmingCharacters(in: .whitespacesAndNewlines)
        return DiceThemeAttribute(
            key: "counter.attr_\(index)",
            name: trimmed.isEmpty ? W8Text.t("属性\(index)", "Attribute \(index)") : trimmed,
            initial: 2,
            min: 0,
            max: 5
        )
    }

    public static func newClock(kind: String = "danger", existing: [DiceThemeClock] = []) -> DiceThemeClock {
        let used = Set(existing.map(\.var))
        var index = existing.count + 1
        while used.contains("counter.clock_\(index)") { index += 1 }
        let resolvedKind = kind == "progress" ? "progress" : "danger"
        return DiceThemeClock(
            variable: "counter.clock_\(index)",
            label: resolvedKind == "progress" ? W8Text.t("调查进展", "Investigation progress") : W8Text.t("巡夜人警觉", "Night watch alert"),
            kind: resolvedKind,
            segments: 6
        )
    }

    public static func newAspect(presetKey: String? = nil, existing: [DiceThemeAspect] = []) -> DiceThemeAspect {
        let used = Set(existing.map(\.key))
        let trimmedKey = presetKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedKey, let preset = aspectPresets.first(where: { $0.key.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedKey || $0.key == presetKey }),
           !used.contains(preset.key.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return DiceThemeAspect(key: preset.key.trimmingCharacters(in: .whitespacesAndNewlines), label: preset.label, desc: preset.desc)
        }
        var index = existing.count + 1
        while used.contains("aspect_\(index)") { index += 1 }
        return DiceThemeAspect(key: "aspect_\(index)", label: W8Text.t("新特质", "New trait"), desc: "")
    }

    public static func move<T>(_ list: [T], index: Int, delta: Int) -> [T] {
        let target = index + delta
        guard list.indices.contains(index), list.indices.contains(target) else { return list }
        var copy = list
        copy.swapAt(index, target)
        return copy
    }

    public static func apply(
        _ journey: DiceThemeJourneyConfig?,
        enabled: Bool,
        presetKey: String? = nil,
        attrs: [DiceThemeAttribute]? = nil,
        clocks: [DiceThemeClock]? = nil,
        aspects: [DiceThemeAspect]? = nil,
        checkEnabled: Bool? = nil
    ) -> DiceThemeJourneyConfig {
        var next = journey ?? DiceThemeJourneyConfig()
        let nonCounterAttrs = next.attributes.filter { !$0.key.hasPrefix("counter.") }
        if !enabled {
            next.attributes = nonCounterAttrs
            next.d20Preset = nil
            next.checkEnabled = nil
            next.dcs = nil
            next.clocks = []
            next.aspects = []
            next.momentumMax = nil
            next.stateEnabled = !nonCounterAttrs.isEmpty
            return next
        }
        let p = presets.first(where: { $0.key == (presetKey ?? next.d20Preset) }) ?? presets[1]
        let cur = read(next)
        let rawAttrs: [DiceThemeAttribute]
        if let attrs {
            rawAttrs = attrs
        } else if !cur.attrs.isEmpty {
            rawAttrs = cur.attrs
        } else {
            rawAttrs = Array(attrPresets.prefix(3)).map {
                DiceThemeAttribute(key: $0.key, name: $0.name, initial: $0.initial, min: $0.min, max: $0.max)
            }
        }
        let nextAttrs = rawAttrs.map(clampAttr).filter { !$0.name.isEmpty }
        let rawClocks = clocks ?? (!cur.clocks.isEmpty ? cur.clocks : [
            DiceThemeClock(variable: "counter.alarm", label: W8Text.t("巡夜人警觉", "Night watch alert"), kind: "danger", segments: p.seg)
        ])
        let nextClocks = rawClocks
            .map { c in
                DiceThemeClock(
                    variable: c.var,
                    label: c.label.trimmingCharacters(in: .whitespacesAndNewlines),
                    kind: c.kind == "progress" ? "progress" : "danger",
                    segments: clockSegments.contains(c.segments) ? c.segments : p.seg
                )
            }
            .filter { !$0.label.isEmpty }
        let rawAspects = aspects ?? cur.aspects
        let nextAspects = rawAspects
            .map { a in
                DiceThemeAspect(
                    key: a.key,
                    label: a.label.trimmingCharacters(in: .whitespacesAndNewlines),
                    desc: a.desc.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.label.isEmpty }

        next.stateEnabled = true
        next.d20Preset = p.key
        next.checkEnabled = checkEnabled != false && cur.checkEnabled
        next.attributes = nonCounterAttrs + nextAttrs
        next.dcs = p.dcs
        next.clocks = nextClocks
        next.aspects = nextAspects
        next.momentumMax = 6
        return next
    }

    public static func setCheckEnabled(_ journey: DiceThemeJourneyConfig?, checkEnabled: Bool) -> DiceThemeJourneyConfig {
        let cur = read(journey)
        guard cur.enabled else { return journey ?? DiceThemeJourneyConfig() }
        return apply(
            journey,
            enabled: true,
            presetKey: cur.preset,
            attrs: cur.attrs,
            clocks: cur.clocks,
            aspects: cur.aspects,
            checkEnabled: checkEnabled
        )
    }

    public static func summary(_ journey: DiceThemeJourneyConfig?) -> String {
        let s = read(journey)
        guard s.enabled else { return W8Text.t("未开启", "Off") }
        let p = presets.first(where: { $0.key == s.preset }) ?? presets[1]
        var parts = [p.label, W8Text.t("\(s.attrs.count) 项属性", "\(s.attrs.count) attributes")]
        if !s.clocks.isEmpty { parts.append(W8Text.t("\(s.clocks.count) 个进度钟", "\(s.clocks.count) clocks")) }
        if !s.aspects.isEmpty { parts.append(W8Text.t("\(s.aspects.count) 项特质", "\(s.aspects.count) traits")) }
        if !s.checkEnabled { parts.append(W8Text.t("仅记录数值", "Record values only")) }
        return parts.joined(separator: " · ")
    }

    public static func playWindowOf(_ journey: DiceThemeJourneyConfig?) -> String {
        let key = journey?.playWindow
        return windows.first(where: { $0.key == key })?.key ?? "all"
    }

    public static func playWindowLabel(_ journey: DiceThemeJourneyConfig?) -> String {
        let key = playWindowOf(journey)
        return windows.first(where: { $0.key == key })?.label ?? W8Text.t("全天可玩", "Playable all day")
    }

    public static func setPlayWindow(_ journey: DiceThemeJourneyConfig?, key: String) -> DiceThemeJourneyConfig {
        var next = journey ?? DiceThemeJourneyConfig()
        let w = windows.first(where: { $0.key == key })?.key ?? "all"
        next.playWindow = (w == "all") ? nil : w
        return next
    }

    public static func prepOf(_ journey: DiceThemeJourneyConfig?) -> [String] {
        guard let items = journey?.prepItems else { return [] }
        return Array(items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(6))
    }

    public static func setPrep(_ journey: DiceThemeJourneyConfig?, list: [String]) -> DiceThemeJourneyConfig {
        var next = journey ?? DiceThemeJourneyConfig()
        var clean: [String] = []
        for raw in list {
            let s = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(16))
            if !s.isEmpty && !clean.contains(s) && clean.count < 6 {
                clean.append(s)
            }
        }
        next.prepItems = clean.isEmpty ? nil : clean
        return next
    }
}

// MARK: - 3D Icosahedron D20 Geometry & Quaternion Orientation (Ported from pages/play/utils/d20-renderer.js)

public struct DiceVec3: Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var array: [Double] { [x, y, z] }

    public func dot(_ other: DiceVec3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    public func cross(_ other: DiceVec3) -> DiceVec3 {
        DiceVec3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }

    public var normalized: DiceVec3 {
        let len = (x * x + y * y + z * z).squareRoot()
        guard len > 0 else { return DiceVec3(0, 0, 1) }
        return DiceVec3(x / len, y / len, z / len)
    }
}

public struct DiceQuaternion: Equatable, Sendable {
    public var w: Double
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ w: Double, _ x: Double, _ y: Double, _ z: Double) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }

    public var normalized: DiceQuaternion {
        let len = (w * w + x * x + y * y + z * z).squareRoot()
        guard len > 0 else { return DiceQuaternion(1, 0, 0, 0) }
        return DiceQuaternion(w / len, x / len, y / len, z / len)
    }

    public func multiplied(by b: DiceQuaternion) -> DiceQuaternion {
        DiceQuaternion(
            w * b.w - x * b.x - y * b.y - z * b.z,
            w * b.x + x * b.w + y * b.z - z * b.y,
            w * b.y - x * b.z + y * b.w + z * b.x,
            w * b.z + x * b.y - y * b.x + z * b.w
        ).normalized
    }
}

public struct DiceD20Face: Equatable, Sendable {
    public let points: [DiceVec3]
    public let normal: DiceVec3
    public let up: DiceVec3
    public let value: Int
}

public enum DiceD20Geometry {
    private static let phi = (1.0 + 5.0.squareRoot()) / 2.0

    public static let rawVertices: [DiceVec3] = [
        DiceVec3(-1, phi, 0), DiceVec3(1, phi, 0), DiceVec3(-1, -phi, 0), DiceVec3(1, -phi, 0),
        DiceVec3(0, -1, phi), DiceVec3(0, 1, phi), DiceVec3(0, -1, -phi), DiceVec3(0, 1, -phi),
        DiceVec3(phi, 0, -1), DiceVec3(phi, 0, 1), DiceVec3(-phi, 0, -1), DiceVec3(-phi, 0, 1),
    ].map(\.normalized)

    public static let triangles: [(Int, Int, Int)] = [
        (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
        (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
        (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
        (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1),
    ]

    public static let faces: [DiceD20Face] = {
        let baseFaces = triangles.map { (i, j, k) -> (points: [DiceVec3], normal: DiceVec3, up: DiceVec3) in
            let pts = [rawVertices[i], rawVertices[j], rawVertices[k]]
            let centroid = DiceVec3(
                (pts[0].x + pts[1].x + pts[2].x) / 3.0,
                (pts[0].y + pts[1].y + pts[2].y) / 3.0,
                (pts[0].z + pts[1].z + pts[2].z) / 3.0
            )
            let center = centroid.normalized
            // The up vector must lie in the face plane, so measure from the raw (unnormalized) centroid.
            let u = DiceVec3(pts[0].x - centroid.x, pts[0].y - centroid.y, pts[0].z - centroid.z).normalized
            return (points: pts, normal: center, up: u)
        }
        var values = Array(repeating: 0, count: baseFaces.count)
        var next = 1
        for i in baseFaces.indices where values[i] == 0 {
            values[i] = next
            var opp = -1
            var minDot = 1.0
            for j in (i + 1)..<baseFaces.count where values[j] == 0 {
                let d = baseFaces[i].normal.dot(baseFaces[j].normal)
                if d < minDot {
                    minDot = d
                    opp = j
                }
            }
            if opp >= 0 {
                values[opp] = 21 - next
            }
            next += 1
        }
        return baseFaces.enumerated().map { idx, f in
            DiceD20Face(points: f.points, normal: f.normal, up: f.up, value: values[idx])
        }
    }()

    public static func rotate(_ q: DiceQuaternion, _ v: DiceVec3) -> DiceVec3 {
        let p = q.multiplied(by: DiceQuaternion(0, v.x, v.y, v.z))
            .multiplied(by: DiceQuaternion(q.w, -q.x, -q.y, -q.z))
        return DiceVec3(p.x, p.y, p.z)
    }

    public static func fromVectors(_ a: DiceVec3, _ b: DiceVec3) -> DiceQuaternion {
        let d = a.dot(b)
        if d < -0.999999 {
            let fallback = abs(a.x) < 0.9 ? DiceVec3(1, 0, 0) : DiceVec3(0, 1, 0)
            let ortho = a.cross(fallback).normalized
            return DiceQuaternion(0, ortho.x, ortho.y, ortho.z)
        }
        let c = a.cross(b)
        return DiceQuaternion(1.0 + d, c.x, c.y, c.z).normalized
    }

    public static func orientFace(_ value: Int) -> DiceQuaternion {
        let face = faces.first(where: { $0.value == value }) ?? faces[0]
        let q1 = fromVectors(face.normal, DiceVec3(0, 0, 1))
        let up = rotate(q1, face.up)
        let angle = atan2(up.x, up.y)
        return DiceQuaternion(cos(angle / 2.0), 0, 0, sin(angle / 2.0))
            .multiplied(by: q1)
    }

    public static func slerp(_ a: DiceQuaternion, _ bInput: DiceQuaternion, _ t: Double) -> DiceQuaternion {
        var b = bInput
        var cosHalf = a.w * b.w + a.x * b.x + a.y * b.y + a.z * b.z
        if cosHalf < 0 {
            b = DiceQuaternion(-b.w, -b.x, -b.y, -b.z)
            cosHalf = -cosHalf
        }
        if cosHalf > 0.9995 {
            return DiceQuaternion(
                a.w + (b.w - a.w) * t,
                a.x + (b.x - a.x) * t,
                a.y + (b.y - a.y) * t,
                a.z + (b.z - a.z) * t
            ).normalized
        }
        let half = acos(max(-1.0, min(1.0, cosHalf)))
        let sinHalf = (1.0 - cosHalf * cosHalf).squareRoot()
        let ra = sin((1.0 - t) * half) / sinHalf
        let rb = sin(t * half) / sinHalf
        return DiceQuaternion(
            a.w * ra + b.w * rb,
            a.x * ra + b.x * rb,
            a.y * ra + b.y * rb,
            a.z * ra + b.z * rb
        ).normalized
    }
}

public enum DiceD20Error: Error, LocalizedError, Equatable {
    case invalidFaceValue(Int)
    case canvasUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFaceValue(let v):
            return W8Text.t("D20 点数必须在 1–20 之间（收到 \(v)）", "D20 result must be between 1 and 20 (got \(v))")
        case .canvasUnavailable(let msg):
            return msg
        }
    }
}

public struct DiceD20DieRenderItem: Equatable, Sendable {
    public let index: Int
    public let centerX: Double
    public let centerY: Double
    public let radius: Double
    public let alpha: Double
    public let gold: Bool
    public let orientation: DiceQuaternion
    public let frontValue: Int?
}

/// Pure state machine matching `createD20Renderer` in `pages/play/utils/d20-renderer.js`.
public final class DiceD20RendererState {
    public struct DieState {
        public var q: DiceQuaternion
        public var from: DiceQuaternion
        public var to: DiceQuaternion
        public var value: Int?
        public var chosen: Bool
        public var gold: Bool
    }

    public let width: Double
    public let height: Double
    public let count: Int
    public private(set) var dice: [DieState]
    public private(set) var mode: String = "idle"
    public private(set) var startMs: Double = 0
    public private(set) var selectStartMs: Double = 0
    public private(set) var settled = false
    public private(set) var isDisposed = false
    public private(set) var lastRenderItems: [DiceD20DieRenderItem] = []

    public init(width: Double = 320, height: Double = 220, count: Int = 1) {
        self.width = width
        self.height = height
        self.count = count == 2 ? 2 : 1
        self.dice = (0..<self.count).map { i in
            let initial = DiceD20Geometry.orientFace(i != 0 ? 14 : 20)
            return DieState(q: initial, from: initial, to: initial, value: nil, chosen: false, gold: false)
        }
        updateRenderItems(nowMs: 0)
    }

    public func roll(reducedMotion: Bool, nowMs: Double = 0) {
        guard !isDisposed else { return }
        settled = false
        mode = reducedMotion ? "static" : "roll"
        startMs = nowMs
        for i in dice.indices {
            dice[i].chosen = false
            dice[i].gold = false
            dice[i].value = nil
        }
        updateRenderItems(nowMs: nowMs)
    }

    public func settle(values: [Int], kept: Int, immediate: Bool = false, nowMs: Double = 0) throws -> Bool {
        guard !isDisposed else { return false }
        for index in dice.indices {
            guard index < values.count else {
                throw DiceD20Error.invalidFaceValue(0)
            }
            let val = values[index]
            guard (1...20).contains(val) else {
                throw DiceD20Error.invalidFaceValue(val)
            }
        }
        let chosenIndex = values.firstIndex(of: kept) ?? 0
        for i in dice.indices {
            let v = values[i]
            dice[i].value = v
            dice[i].from = dice[i].q
            dice[i].to = DiceD20Geometry.orientFace(v)
            dice[i].chosen = (i == chosenIndex)
            dice[i].gold = (v == 20 && i == chosenIndex)
        }
        startMs = nowMs
        if immediate {
            for i in dice.indices {
                dice[i].q = dice[i].to
            }
            settled = true
            mode = "done"
            updateRenderItems(nowMs: nowMs)
            return true
        }
        mode = "settle"
        updateRenderItems(nowMs: nowMs)
        return false
    }

    /// Advances the renderer at `nowMs`. Returns `true` at the exact transition to `"done"`.
    @discardableResult
    public func step(nowMs: Double) -> Bool {
        guard !isDisposed else { return false }
        let dt = nowMs - startMs
        if mode == "roll" {
            for i in dice.indices {
                let speed = 0.0045 + Double(i) * 0.0009
                let spin = DiceQuaternion(
                    cos(dt * speed),
                    sin(dt * speed) * 0.6,
                    sin(dt * speed * 0.8) * 0.5,
                    cos(dt * speed * 0.6) * 0.4
                ).normalized
                dice[i].q = spin.multiplied(by: dice[i].from)
            }
            updateRenderItems(nowMs: nowMs)
            return false
        } else if mode == "settle" {
            let t = min(1.0, dt / 1200.0)
            let ease = 1.0 - pow(1.0 - t, 3.0)
            let spinAngle = (1.0 - ease) * .pi * 4.0
            let spin = DiceQuaternion(
                cos(spinAngle / 2.0),
                sin(spinAngle / 2.0) * 0.5,
                sin(spinAngle / 2.0) * 0.7,
                sin(spinAngle / 2.0) * 0.3
            ).normalized
            for i in dice.indices {
                dice[i].q = DiceD20Geometry.slerp(spin.multiplied(by: dice[i].from), dice[i].to, ease)
            }
            if t >= 1.0 {
                settled = true
                if count > 1 {
                    mode = "select"
                    selectStartMs = nowMs
                    updateRenderItems(nowMs: nowMs)
                    return false
                } else {
                    mode = "done"
                    updateRenderItems(nowMs: nowMs)
                    return true
                }
            }
            updateRenderItems(nowMs: nowMs)
            return false
        } else if mode == "select" {
            if nowMs - selectStartMs >= 600.0 {
                mode = "done"
                updateRenderItems(nowMs: nowMs)
                return true
            }
            updateRenderItems(nowMs: nowMs)
            return false
        }
        updateRenderItems(nowMs: nowMs)
        return false
    }

    public func dispose() {
        isDisposed = true
        mode = "idle"
    }

    private func updateRenderItems(nowMs: Double) {
        let baseRadius = min(width / Double(count), height) * (count > 1 ? 0.33 : 0.39)
        let selectT: Double
        if mode == "select" {
            selectT = min(1.0, (nowMs - selectStartMs) / 600.0)
        } else if mode == "done" && count > 1 {
            selectT = 1.0
        } else {
            selectT = 0.0
        }
        let selectEase = 1.0 - pow(1.0 - selectT, 3.0)
        var items: [DiceD20DieRenderItem] = []
        for (i, d) in dice.enumerated() {
            if count > 1 && mode == "done" && !d.chosen { continue }
            let startX = count == 1 ? width / 2.0 : width * (i == 0 ? 0.29 : 0.71)
            let cx = d.chosen && count > 1 ? startX + (width / 2.0 - startX) * selectEase : startX
            let radius = d.chosen && count > 1 ? baseRadius * (1.0 + 0.18 * selectEase) : baseRadius
            let alpha = (!d.chosen && selectT > 0) ? max(0.0, 1.0 - selectEase) : 1.0
            items.append(
                DiceD20DieRenderItem(
                    index: i,
                    centerX: cx,
                    centerY: height * 0.5,
                    radius: radius,
                    alpha: alpha,
                    gold: settled && d.gold,
                    orientation: d.q,
                    frontValue: settled ? d.value : nil
                )
            )
        }
        lastRenderItems = items
    }
}

// MARK: - D6 Pips & Playkit Dice Roll Helpers (Ported from pages/play/components/playkit-diceroll/index.js)

public struct DiceD6Placement: Equatable, Sendable {
    public let index: Int
    public let pips: [Bool]
    public let delay: Double
    public let dx: Double
}

public enum DicePlaykitRules {
    public static let d6RollDurationMs = 900
    public static let d20TimeoutMs = 8000

    private static let pipsMap: [Int: [Bool]] = [
        1: [false, false, false, false, true,  false, false, false, false],
        2: [true,  false, false, false, false, false, false, false, true],
        3: [true,  false, false, false, true,  false, false, false, true],
        4: [true,  false, true,  false, false, false, true,  false, true],
        5: [true,  false, true,  false, true,  false, true,  false, true],
        6: [true,  false, true,  true,  false, true,  true,  false, true],
    ]

    public static func pipsOf(_ n: Int) -> [Bool] {
        pipsMap[n] ?? Array(repeating: false, count: 9)
    }

    public static func taskFor(values: [Int], faces: [String]) -> String {
        guard values.count == 1 else { return "" }
        let idx = values[0] - 1
        guard faces.indices.contains(idx) else { return "" }
        return faces[idx]
    }

    public static func sumOf(_ values: [Int]) -> Int {
        values.reduce(0, +)
    }

    public static func place(count: Int, values: [Int]) -> [DiceD6Placement] {
        let n = count == 2 ? 2 : 1
        return (0..<n).map { i in
            let pipValue = i < values.count && (1...6).contains(values[i]) ? values[i] : 1
            return DiceD6Placement(
                index: i,
                pips: pipsOf(pipValue),
                delay: Double(i) * 0.06,
                dx: n == 2 ? (i != 0 ? 62.0 : -62.0) : 0.0
            )
        }
    }

    public static func subtitleForSettledD6(values: [Int], faces: [String]) -> String {
        let valid = values.filter { (1...6).contains($0) }
        guard !valid.isEmpty else { return W8Text.t("摇一摇，把骰子扔出去", "Shake and throw the dice") }
        if valid.count == 1 {
            let task = taskFor(values: valid, faces: faces)
            return task.isEmpty ? W8Text.t("摇到 \(valid[0])", "Rolled \(valid[0])") : task
        }
        return valid.map(String.init).joined(separator: " + ") + W8Text.t("，两颗只比大小", ", two dice compare only")
    }
}

// MARK: - D20 Template Validation & Sandbox Preview (Ported from advanced-game-config.js & game-preview-action.js)

public struct DiceD20TemplateConfig: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var mode: String
    public var kicker: String
    public var dc: Int?
    public var modifier: Int?
    public var rollMode: String
    public var successText: String
    public var failText: String
    public var faces: [String]
    public var diceCount: Int

    public init(
        enabled: Bool = true,
        mode: String = "d20",
        kicker: String = W8Text.t("D20 检定", "D20 check"),
        dc: Int? = 12,
        modifier: Int? = 0,
        rollMode: String = "normal",
        successText: String = "",
        failText: String = "",
        faces: [String] = [],
        diceCount: Int = 1
    ) {
        self.enabled = enabled
        self.mode = mode
        self.kicker = kicker
        self.dc = dc
        self.modifier = modifier
        self.rollMode = rollMode
        self.successText = successText
        self.failText = failText
        self.faces = faces
        self.diceCount = diceCount
    }
}

public struct DiceD20PreviewResult: Equatable, Sendable {
    public let values: [Int]
    public let kept: Int
    public let total: Int
    public let success: Bool
    public let text: String
    public let sandbox: Bool
    public let modifierSource: String
}

public enum DiceD20TemplateValidator {
    public static let validRollModes: Set<String> = ["normal", "advantage", "disadvantage"]

    public static func validate(_ config: DiceD20TemplateConfig, adoptedFromLibrary: Bool = false) -> String {
        guard config.enabled else { return "" }
        if config.mode == "d20" {
            guard let dc = config.dc, (1...40).contains(dc) else {
                return W8Text.t("D20 难度值（DC）须为 1–40 的整数", "D20 difficulty (DC) must be an integer from 1 to 40")
            }
            guard let modifier = config.modifier, (-20...20).contains(modifier) else {
                return W8Text.t("D20 调整值须为 -20 到 20 的整数", "D20 modifier must be an integer from -20 to 20")
            }
            guard validRollModes.contains(config.rollMode) else {
                return W8Text.t("D20 检定方式无效", "Invalid D20 check mode")
            }
            let successTrimmed = config.successText.trimmingCharacters(in: .whitespacesAndNewlines)
            let failTrimmed = config.failText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !adoptedFromLibrary && (successTrimmed.isEmpty || failTrimmed.isEmpty) {
                return W8Text.t("请填写成功与失败结果文案", "Enter both success and failure result text")
            }
            if successTrimmed.count > 200 || failTrimmed.count > 200 {
                return W8Text.t("D20 结果文案不能超过 200 字", "D20 result text must not exceed 200 characters")
            }
            return ""
        } else {
            let cleanFaces = config.faces.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if cleanFaces.count < 6 || cleanFaces.prefix(6).contains(where: \.isEmpty) {
                return W8Text.t("六面骰每一面不能为空", "Every face of the six-sided die needs text")
            }
            return ""
        }
    }

    /// Exact port of `previewD20Result` in `utils/game-preview-action.js`.
    public static func previewD20Result(_ config: DiceD20TemplateConfig) -> DiceD20PreviewResult {
        let values = config.rollMode == "normal" ? [12] : [12, 7]
        let kept = config.rollMode == "disadvantage" ? (values.min() ?? 7) : (values.max() ?? 12)
        let mod = config.modifier ?? 0
        let dc = config.dc ?? 10
        let total = kept + mod
        let success = total >= dc
        return DiceD20PreviewResult(
            values: values,
            kept: kept,
            total: total,
            success: success,
            text: success ? config.successText : config.failText,
            sandbox: true,
            modifierSource: "TEMPLATE_FIXED"
        )
    }
}

// MARK: - Journey Check Rules & Receipt Projection (Ported from playkit-journey-check/index.js & playkit-view.js)

public struct DiceJourneyCheckMod: Codable, Equatable, Sendable {
    public let label: String
    public let value: Int
    public let held: Bool
    public let applied: Bool

    public init(label: String, value: Int, held: Bool = false, applied: Bool = false) {
        self.label = label
        self.value = value
        self.held = held
        self.applied = applied
    }
}

public struct DiceJourneyBreakdownRow: Equatable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public struct DiceJourneyCheckReceiptView: Equatable, Sendable {
    public let detailsHidden: Bool
    public let breakdownRows: [DiceJourneyBreakdownRow]
    public let rolled: Bool
    public let tier: String
    public let dc: Int?
    public let dice: [Int]
    public let kept: Int?
    public let total: Int?
    public let success: Bool?
    public let nat: String
    public let rerolled: Bool
    public let settled: Bool
    public let text: String
    public let failCostLabel: String
    public let hp: Int?
    public let luck: Int?
    public let exhausted: Bool
    public let mods: [DiceJourneyCheckMod]
    public let canRerollFlag: Bool?
    public let rerollRemaining: Int?
    public let pending: Bool

    public init(
        detailsHidden: Bool = false,
        breakdownRows: [DiceJourneyBreakdownRow] = [],
        rolled: Bool = true,
        tier: String = "",
        dc: Int? = 0,
        dice: [Int] = [],
        kept: Int? = nil,
        total: Int? = nil,
        success: Bool? = false,
        nat: String = "",
        rerolled: Bool = false,
        settled: Bool = false,
        text: String = "",
        failCostLabel: String = "",
        hp: Int? = nil,
        luck: Int? = nil,
        exhausted: Bool = false,
        mods: [DiceJourneyCheckMod] = [],
        canRerollFlag: Bool? = nil,
        rerollRemaining: Int? = nil,
        pending: Bool = false
    ) {
        self.detailsHidden = detailsHidden
        self.breakdownRows = breakdownRows
        self.rolled = rolled
        self.tier = tier
        self.dc = dc
        self.dice = dice
        self.kept = kept
        self.total = total
        self.success = success
        self.nat = nat
        self.rerolled = rerolled
        self.settled = settled
        self.text = text
        self.failCostLabel = failCostLabel
        self.hp = hp
        self.luck = luck
        self.exhausted = exhausted
        self.mods = mods
        self.canRerollFlag = canRerollFlag
        self.rerollRemaining = rerollRemaining
        self.pending = pending
    }
}

public enum DiceJourneyCheckRules {
    public static let holdFullMs: Int = 1400

    public static func tierLabel(_ tier: String) -> String {
        switch tier {
        case "easy": return W8Text.t("轻巧（DC 10）", "Light (DC 10)")
        case "medium": return W8Text.t("吃劲（DC 13）", "Demanding (DC 13)")
        case "hard": return W8Text.t("棘手（DC 16）", "Tricky (DC 16)")
        default: return W8Text.t("检定", "Check")
        }
    }

    public static func defaultDC(for tier: String) -> Int {
        switch tier {
        case "easy": return 10
        case "hard": return 16
        default: return 13
        }
    }

    /// Ported from `canReroll(receipt, r5)` in `pages/play/components/playkit-journey-check/index.js`.
    public static func canReroll(_ receipt: DiceJourneyCheckReceiptView?, r5: Bool = false) -> Bool {
        guard let receipt else { return false }
        if r5 {
            return receipt.canRerollFlag == true && (receipt.rerollRemaining ?? 0) > 0 && !receipt.pending
        }
        return !receipt.settled && !receipt.rerolled && (receipt.luck ?? 0) > 0
    }

    /// Ported from `trackPct(n)` in `pages/play/components/playkit-journey-check/index.js`.
    public static func trackPct(_ n: Int?) -> Double {
        guard let n else { return 0 }
        return max(0.0, min(100.0, Double(n - 1) / 19.0 * 100.0))
    }

    /// Ported from `marginText(receipt)` in `pages/play/components/playkit-journey-check/index.js`.
    public static func marginText(_ receipt: DiceJourneyCheckReceiptView?) -> String {
        guard let receipt, !receipt.detailsHidden, let total = receipt.total, let dc = receipt.dc else {
            return ""
        }
        let diff = total - dc
        return diff >= 0 ? W8Text.t("过线 \(diff) 点", "Passed by \(diff)") : W8Text.t("差 \(-diff) 点", "Missed by \(-diff)")
    }

    /// Ported from `natTag(receipt)` in `pages/play/components/playkit-journey-check/index.js`.
    public static func natTag(_ receipt: DiceJourneyCheckReceiptView?) -> String {
        guard let receipt, !receipt.detailsHidden else { return "" }
        if receipt.nat == "CRIT" { return W8Text.t("天然 20", "Natural 20") }
        if receipt.nat == "FUMBLE" { return W8Text.t("天然 1 · 手滑了", "Natural 1 · fumbled") }
        return ""
    }

    /// Ported from `checkReceiptView(receipt)` in `pages/play/utils/playkit-view.js`.
    public static func receiptView(from raw: PlayWireValue) -> DiceJourneyCheckReceiptView {
        let b = raw["breakdown"]
        let hidden = raw["detailsHidden"].bool == true
            || raw["hidden"].bool == true
            || raw["redacted"].bool == true
            || b["hidden"].bool == true
            || b["redacted"].bool == true
            || b["skill"]["hidden"].bool == true
            || b["skill"]["redacted"].bool == true
            || b["situational"]["hidden"].bool == true
            || b["situational"]["redacted"].bool == true

        let settled = raw["settled"].bool == true
        if hidden {
            return DiceJourneyCheckReceiptView(
                detailsHidden: true,
                breakdownRows: [],
                rolled: true,
                tier: raw["tier"].text ?? "",
                dc: nil,
                dice: [],
                kept: nil,
                total: nil,
                success: raw["success"].bool,
                nat: "",
                rerolled: raw["rerolled"].bool == true,
                settled: settled,
                text: settled ? (raw["text"].text ?? "") : "",
                failCostLabel: settled ? (raw["failCostLabel"].text ?? "") : "",
                hp: raw["hp"].tolerantInteger,
                luck: raw["luck"].tolerantInteger,
                exhausted: raw["exhausted"].bool == true,
                mods: []
            )
        }

        func signed(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }

        let mods: [DiceJourneyCheckMod] = (raw["mods"].array ?? []).map { m in
            DiceJourneyCheckMod(
                label: m["label"].text ?? "",
                value: m["value"].tolerantInteger ?? 0,
                held: m["held"].bool == true,
                applied: m["applied"].bool == true
            )
        }

        var breakdownRows: [DiceJourneyBreakdownRow] = []
        if b.object != nil && b["hidden"].bool != true && b["redacted"].bool != true {
            if let die = b["die"].tolerantInteger {
                breakdownRows.append(DiceJourneyBreakdownRow(label: W8Text.t("骰子", "Dice"), value: "\(die)"))
            }
            let skill = b["skill"]
            if skill.object != nil {
                if skill["hidden"].bool == true || skill["redacted"].bool == true {
                    breakdownRows.append(DiceJourneyBreakdownRow(label: W8Text.t("一项隐藏的加成", "A hidden bonus"), value: W8Text.t("已计入", "Included")))
                } else if let val = skill["value"].tolerantInteger {
                    let lbl = (skill["label"].text?.isEmpty == false) ? skill["label"].text! : W8Text.t("属性", "Attribute")
                    breakdownRows.append(DiceJourneyBreakdownRow(label: lbl, value: signed(val)))
                }
            }
            let sit = b["situational"]
            if sit.object != nil && sit["hidden"].bool != true && sit["redacted"].bool != true,
               let applied = sit["applied"].tolerantInteger, applied != 0 {
                let heldMods = mods.filter { $0.applied && !$0.label.isEmpty && $0.value != 0 }
                let sumHeld = heldMods.reduce(0) { $0 + $1.value }
                if !heldMods.isEmpty && sumHeld == applied {
                    for mod in heldMods {
                        breakdownRows.append(DiceJourneyBreakdownRow(label: mod.label, value: signed(mod.value)))
                    }
                } else {
                    breakdownRows.append(DiceJourneyBreakdownRow(label: W8Text.t("条件修正", "Condition modifier"), value: signed(applied)))
                }
            }
            if let bargain = b["bargain"].tolerantInteger, bargain != 0 {
                breakdownRows.append(DiceJourneyBreakdownRow(label: W8Text.t("魔鬼交易", "Devil’s bargain"), value: signed(bargain)))
            }
            if let momentum = b["momentum"].tolerantInteger, momentum != 0 {
                breakdownRows.append(DiceJourneyBreakdownRow(label: W8Text.t("动量", "Momentum"), value: signed(momentum)))
            }
        }

        return DiceJourneyCheckReceiptView(
            detailsHidden: false,
            breakdownRows: breakdownRows,
            rolled: true,
            tier: raw["tier"].text ?? "",
            dc: raw["dc"].tolerantInteger ?? 0,
            dice: (raw["dice"].array ?? []).compactMap(\.tolerantInteger),
            kept: raw["kept"].tolerantInteger,
            total: raw["total"].tolerantInteger,
            success: raw["success"].bool == true,
            nat: raw["nat"].text ?? "",
            rerolled: raw["rerolled"].bool == true,
            settled: settled,
            text: raw["text"].text ?? "",
            failCostLabel: raw["failCostLabel"].text ?? "",
            hp: raw["hp"].tolerantInteger,
            luck: raw["luck"].tolerantInteger,
            exhausted: raw["exhausted"].bool == true,
            mods: mods,
            canRerollFlag: raw["canReroll"].bool,
            rerollRemaining: raw["rerollRemaining"].tolerantInteger,
            pending: raw["pending"].bool == true
        )
    }
}

// MARK: - DESIGNED: Deterministic Seeded Dice & Check Engine for Offline Preview & Unit Tests

/// `DESIGNED`: SplitMix64 deterministic PRNG for reproducible D20 / D6 rolls with fixed seeds.
public struct DiceSeededRNG: RandomNumberGenerator, Equatable, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Rolls an integer in `1...sides`.
    public mutating func rollDie(sides: Int = 20) -> Int {
        precondition(sides >= 2, "Die must have at least 2 sides")
        return Int(next() % UInt64(sides)) + 1
    }
}

/// `DESIGNED`: Deterministic D20 check evaluator mirroring backend/mini-program check resolution rules.
public enum DiceCheckEngine {
    public enum RollMode: String, Codable, Equatable, Sendable {
        case normal
        case advantage
        case disadvantage

        public static func resolve(advantage: Bool, disadvantage: Bool) -> RollMode {
            if advantage && !disadvantage { return .advantage }
            if disadvantage && !advantage { return .disadvantage }
            return .normal
        }
    }

    public struct CheckInput: Equatable, Sendable {
        public let tier: String
        public let dc: Int
        public let rollMode: RollMode
        public let skillLabel: String
        public let skillValue: Int
        public let mods: [DiceJourneyCheckMod]
        public let situationalCap: Int
        public let bargain: Int
        public let momentum: Int
        public let luck: Int
        public let hp: Int
        public let successText: String
        public let failText: String
        public let failCostLabel: String

        public init(
            tier: String = "medium",
            dc: Int? = nil,
            rollMode: RollMode = .normal,
            skillLabel: String = W8Text.t("观察", "Observation"),
            skillValue: Int = 0,
            mods: [DiceJourneyCheckMod] = [],
            situationalCap: Int = 4,
            bargain: Int = 0,
            momentum: Int = 0,
            luck: Int = 1,
            hp: Int = 5,
            successText: String = W8Text.t("检定通过", "Check passed"),
            failText: String = W8Text.t("检定未通过", "Check failed"),
            failCostLabel: String = ""
        ) {
            self.tier = tier
            self.dc = dc ?? DiceJourneyCheckRules.defaultDC(for: tier)
            self.rollMode = rollMode
            self.skillLabel = skillLabel
            self.skillValue = skillValue
            self.mods = mods
            self.situationalCap = situationalCap
            self.bargain = bargain
            self.momentum = momentum
            self.luck = luck
            self.hp = hp
            self.successText = successText
            self.failText = failText
            self.failCostLabel = failCostLabel
        }
    }

    public static func evaluate(input: CheckInput, rng: inout DiceSeededRNG, rerolled: Bool = false) -> DiceJourneyCheckReceiptView {
        let dice: [Int]
        let kept: Int
        switch input.rollMode {
        case .normal:
            let d1 = rng.rollDie(sides: 20)
            dice = [d1]
            kept = d1
        case .advantage:
            let d1 = rng.rollDie(sides: 20)
            let d2 = rng.rollDie(sides: 20)
            dice = [d1, d2]
            kept = max(d1, d2)
        case .disadvantage:
            let d1 = rng.rollDie(sides: 20)
            let d2 = rng.rollDie(sides: 20)
            dice = [d1, d2]
            kept = min(d1, d2)
        }

        let heldMods = input.mods.filter(\.held)
        let rawSit = heldMods.reduce(0) { $0 + $1.value }
        let cap = max(0, input.situationalCap)
        let appliedSit = max(-cap, min(cap, rawSit))
        let appliedMods = input.mods.map { mod in
            DiceJourneyCheckMod(label: mod.label, value: mod.value, held: mod.held, applied: mod.held)
        }

        let total = kept + input.skillValue + appliedSit + input.bargain + input.momentum
        let nat: String
        let success: Bool
        if kept == 20 {
            nat = "CRIT"
            success = true
        } else if kept == 1 {
            nat = "FUMBLE"
            success = false
        } else {
            nat = ""
            success = total >= input.dc
        }

        let wire: PlayWireValue = .object([
            "tier": .string(input.tier),
            "dc": .int(input.dc),
            "dice": .array(dice.map(PlayWireValue.int)),
            "kept": .int(kept),
            "total": .int(total),
            "success": .bool(success),
            "nat": .string(nat),
            "rerolled": .bool(rerolled),
            "settled": .bool(false),
            "text": .string(""),
            "failCostLabel": .string(""),
            "hp": .int(input.hp),
            "luck": .int(input.luck),
            "exhausted": .bool(input.hp <= 0),
            "mods": .array(appliedMods.map { m in
                .object([
                    "label": .string(m.label),
                    "value": .int(m.value),
                    "held": .bool(m.held),
                    "applied": .bool(m.applied),
                ])
            }),
            "breakdown": .object([
                "die": .int(kept),
                "skill": .object([
                    "label": .string(input.skillLabel),
                    "value": .int(input.skillValue),
                ]),
                "situational": .object([
                    "raw": .int(rawSit),
                    "applied": .int(appliedSit),
                    "cap": .int(cap),
                ]),
                "bargain": .int(input.bargain),
                "momentum": .int(input.momentum),
            ]),
        ])

        return DiceJourneyCheckRules.receiptView(from: wire)
    }

    public static func reroll(
        previous: DiceJourneyCheckReceiptView,
        input: CheckInput,
        rng: inout DiceSeededRNG
    ) -> DiceJourneyCheckReceiptView? {
        guard DiceJourneyCheckRules.canReroll(previous, r5: false) else { return nil }
        let updatedInput = CheckInput(
            tier: input.tier,
            dc: input.dc,
            rollMode: input.rollMode,
            skillLabel: input.skillLabel,
            skillValue: input.skillValue,
            mods: input.mods,
            situationalCap: input.situationalCap,
            bargain: input.bargain,
            momentum: input.momentum,
            luck: max(0, (previous.luck ?? input.luck) - 1),
            hp: previous.hp ?? input.hp,
            successText: input.successText,
            failText: input.failText,
            failCostLabel: input.failCostLabel
        )
        return evaluate(input: updatedInput, rng: &rng, rerolled: true)
    }

    public static func settle(
        receipt: DiceJourneyCheckReceiptView,
        input: CheckInput
    ) -> DiceJourneyCheckReceiptView {
        guard !receipt.settled else { return receipt }
        let passed = receipt.success == true
        let nextHP = passed ? receipt.hp : receipt.hp.map { max(0, $0 - (input.failCostLabel.isEmpty ? 0 : 1)) }
        return DiceJourneyCheckReceiptView(
            detailsHidden: receipt.detailsHidden,
            breakdownRows: receipt.breakdownRows,
            rolled: receipt.rolled,
            tier: receipt.tier,
            dc: receipt.dc,
            dice: receipt.dice,
            kept: receipt.kept,
            total: receipt.total,
            success: receipt.success,
            nat: receipt.nat,
            rerolled: receipt.rerolled,
            settled: true,
            text: passed ? input.successText : input.failText,
            failCostLabel: passed ? "" : input.failCostLabel,
            hp: nextHP,
            luck: receipt.luck,
            exhausted: (nextHP ?? 1) <= 0,
            mods: receipt.mods,
            canRerollFlag: false,
            rerollRemaining: 0,
            pending: false
        )
    }
}
