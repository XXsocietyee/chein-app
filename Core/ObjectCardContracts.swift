import Foundation

public enum ObjectCardCategory: String, CaseIterable, Identifiable {
    case all = "", electronics = "电子产品", clothing = "服饰", bags = "鞋包"
    case food = "食物饮料", books = "书籍文具", toys = "玩具摆件", household = "日用杂物", other = "其他"
    public var id: String { rawValue }
    public var localizationKey: String { "objects.category.\(Self.allCases.firstIndex(of: self)!)" }
}

public struct ObjectCard: Decodable, Equatable, Identifiable {
    public let id: String
    public let title, sourceURL, cutoutURL, caption, category, place, cardStyle, generationStatus: String
    public let frames: [String]
    public let cutoutBox: [Double]?
    public var generating: Bool { ["QUEUED", "GENERATING"].contains(generationStatus) }
    public var thumbnail: String { !cutoutURL.isEmpty ? cutoutURL : !sourceURL.isEmpty ? sourceURL : frames.first ?? "" }
    public var hasRotationFrames: Bool { frames.count > 1 }
    public func frame(at index: Int) -> String {
        guard hasRotationFrames else { return cutoutURL.isEmpty ? frames.first ?? "" : cutoutURL }
        return frames[((index % frames.count) + frames.count) % frames.count]
    }
    private enum CodingKeys: String, CodingKey { case id, title, sourceUrl, cutoutUrl, caption, category, place, cardStyle, genStatus, frames, cutoutBox }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? c.decode(String.self, forKey: .id) { id = text }
        else if let number = try? c.decode(Int.self, forKey: .id) { id = String(number) }
        else { throw APIError.malformedResponse }
        title = try c.decode(String.self, forKey: .title)
        func text(_ key: CodingKeys) -> String { (try? c.decode(String.self, forKey: key)) ?? "" }
        sourceURL = text(.sourceUrl); cutoutURL = text(.cutoutUrl); caption = text(.caption)
        category = text(.category); place = text(.place); generationStatus = text(.genStatus)
        cardStyle = text(.cardStyle) == "plain" ? "plain" : "foil"
        // Lossy string extraction matches source; a malformed frame element is not a model URL.
        let raw = (try? c.decode([ObjectCardFrame].self, forKey: .frames)) ?? []
        let valid = raw.compactMap(\.value).filter { !$0.isEmpty }
        frames = valid.isEmpty ? [sourceURL] : valid
        if let box = try? c.decode([Double].self, forKey: .cutoutBox), box.count == 4,
           box.allSatisfy(\.isFinite), box[0] >= 0, box[1] >= 0, box[2] > 0, box[3] > 0,
           box[0] + box[2] <= 1.0001, box[1] + box[3] <= 1.0001 { cutoutBox = box }
        else { cutoutBox = nil }
    }
}
private struct ObjectCardFrame: Decodable {
    let value: String?
    init(from decoder: Decoder) throws { value = try? decoder.singleValueContainer().decode(String.self) }
}
public struct ObjectCardCollection: Decodable, Equatable {
    public let cards: [ObjectCard]
    public let total: Int
    public var isTruncated: Bool { total > cards.count }
    private enum CodingKeys: String, CodingKey { case list, total }
    public init(cards: [ObjectCard], total: Int) throws {
        guard total >= 0 else { throw APIError.malformedResponse }
        self.cards = cards
        self.total = total
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cards = try c.decode([ObjectCard].self, forKey: .list)
        total = try c.decode(Int.self, forKey: .total)
        guard total >= 0 else { throw APIError.malformedResponse }
    }
}
/// Query metadata only: source does not provide a model URL, 3D mesh, or owned-detail API.
public struct ObjectBadgeDetailParameters: Equatable {
    public let name, subtitle, image: String
    public let style: String
    public let rarity: Int
    public let glyph: String
    public init(query: [String: String], fallbackName: String) {
        let raw = query["name"] ?? ""
        name = raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackName : raw
        subtitle = query["sub"] ?? ""
        let candidate = query["img"] ?? ""
        image = ObjectCardMediaPolicy.origin(candidate) == nil ? "" : candidate
        // Source badge-3d/index.js: glow / pin / enamel (default). pin is the wall's enamel pin.
        style = query["style"] == "glow" ? "glow" : (query["style"] == "pin" ? "pin" : "enamel")
        rarity = min(4, max(0, Int(query["rarity"] ?? "") ?? 0))
        // Source: /^[A-Za-z]{1,24}$/ else DEFAULT.
        let rawGlyph = query["glyph"] ?? ""
        glyph = !rawGlyph.isEmpty && rawGlyph.utf8.count <= 24 && rawGlyph.utf8.allSatisfy({ ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) })
            ? rawGlyph : "DEFAULT"
    }
}

/// Native stand-in for the mini-program's xr-badge turntable: drag rotates the artwork around its
/// vertical axis, a tap on a `pin` badge spins it once. Reduced motion keeps it static, like the source.
public struct ObjectBadgeTurntable: Equatable {
    public static let degreesPerPoint = 0.5
    public private(set) var committedAngle = 0.0
    public private(set) var liveTranslation = 0.0
    public let style: String
    public let reducedMotion: Bool
    public init(style: String, reducedMotion: Bool) { self.style = style; self.reducedMotion = reducedMotion }

    public var angle: Double { reducedMotion ? 0 : committedAngle + liveTranslation * Self.degreesPerPoint }
    public mutating func drag(translationWidth: Double) {
        guard !reducedMotion, style != "glow", translationWidth.isFinite else { return }
        liveTranslation = translationWidth
    }
    public mutating func endDrag() {
        committedAngle = angle.truncatingRemainder(dividingBy: 360); liveTranslation = 0
    }
    /// Pin badges turn a full circle on tap; other styles ignore taps.
    public mutating func tap() {
        guard !reducedMotion, style == "pin" else { return }
        committedAngle += 360
    }
    /// Source hint line under the badge (nil = no hint, e.g. the glow style).
    public var hintKey: String? {
        if reducedMotion { return "objects.badge3d.hint.reduced" }
        switch style {
        case "pin": return "objects.badge3d.hint.pin"
        case "glow": return nil
        default: return "objects.badge3d.hint.drag"
        }
    }
}
