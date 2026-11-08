import Foundation

/// WIRE-2: pure projections of the already-read merchantinfo topic object, mirroring
/// `buildTopicStatBar` (pages/topic/utils/topic-detail-facts.js), the "节点介绍" template shelf,
/// and the per-chapter meta line / node gallery of the guide tab. Reads nothing, writes nothing.
public struct MerchantTopicStatCell: Equatable {
    public enum Kind: Equatable { case hours, openRange, mileage }
    public let kind: Kind
    public let value: String
    public init(kind: Kind, value: String) { self.kind = kind; self.value = value }
}

public struct MerchantTopicNodeTemplate: Equatable {
    public let id: Int?
    public let title: String
    public let imageURL: URL?
    public let players: String?
    public let durationMinutes: Int?
}

public struct MerchantTopicChapterFacts: Equatable {
    public struct Node: Equatable {
        public let step: Int
        public let title: String
        public let description: String
        public let images: [URL]
    }
    public let name: String?
    /// nil when the chapter carries no time, mirroring `metaTime` (the source never writes a zero).
    public let totalSeconds: Int?
    public let nodeCount: Int
    public let playCount: Int
    public let nodes: [Node]
    public var hasMeta: Bool { totalSeconds != nil || nodeCount > 0 || playCount > 0 }
}

public struct MerchantTopicDetailFacts: Equatable {
    public let statBar: [MerchantTopicStatCell]
    public let nodeTemplates: [MerchantTopicNodeTemplate]
    public let chapters: [MerchantTopicChapterFacts]

    private static func number(_ value: MerchantContentValue) -> Double? {
        guard let text = value.display?.trimmingCharacters(in: .whitespaces), let n = Double(text), n.isFinite else { return nil }
        return n
    }
    private static func positive(_ value: MerchantContentValue) -> Double? {
        guard let n = number(value), n > 0 else { return nil }
        return n
    }
    private static func trimmed(_ value: MerchantContentValue) -> String? {
        guard let t = value.display?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, t != "null" else { return nil }
        return t
    }
    /// `formatDateMd`: "2026-07-04 …" -> "7.4". Empty/unparseable -> nil.
    static func monthDay(_ raw: MerchantContentValue) -> String? {
        guard let text = trimmed(raw) else { return nil }
        let parts = text.prefix(10).split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        return "\(month).\(day)"
    }
    /// Plain https only (same rule as the slip photo); a bad URL is dropped, not shown broken.
    static func httpsURL(_ raw: String) -> URL? { RoamStampSlipPhotoPort.displayURL(raw) }
    static func imageList(_ raw: MerchantContentValue) -> [URL] {
        (raw.display ?? "").split(whereSeparator: { $0 == ";" || $0 == "," }).compactMap { httpsURL(String($0)) }
    }

    public init(topic: MerchantContentValue) {
        var cells: [MerchantTopicStatCell] = []
        // The recruit view drops rating and merchant-count cells (项目事实 only).
        if let seconds = Self.positive(topic["totalTime"]), seconds / 3600 >= 0.1 {
            let hours = seconds / 3600
            let rounded = hours.truncatingRemainder(dividingBy: 1) == 0 ? hours : (hours * 10).rounded() / 10
            let text = rounded.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(rounded)) : String(rounded)
            cells.append(.init(kind: .hours, value: text + "+"))
        }
        if let start = Self.monthDay(topic["startDate"]), let end = Self.monthDay(topic["endDate"]) {
            cells.append(.init(kind: .openRange, value: start + "-" + end))
        }
        if let km = Self.positive(topic["totalMileage"]) {
            cells.append(.init(kind: .mileage, value: km.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(km)) : String(km)))
        }
        statBar = cells

        var templates: [MerchantTopicNodeTemplate] = []
        var chapterFacts: [MerchantTopicChapterFacts] = []
        for chapter in topic["chaptersList"].array ?? [] {
            let nodes = chapter["nodes"].array ?? []
            var nodeFacts: [MerchantTopicChapterFacts.Node] = []
            for node in nodes {
                let template = node["cmsMemberTemplate"]
                if template.object != nil {
                    templates.append(.init(
                        id: template["id"].integer,
                        title: Self.trimmed(template["title"]) ?? "",
                        imageURL: Self.trimmed(template["imgUrl"]).flatMap(Self.httpsURL),
                        players: Self.trimmed(template["players"]),
                        durationMinutes: Self.number(template["duration"]).map { Int($0) }))
                }
                nodeFacts.append(.init(step: nodeFacts.count + 1,
                                       title: Self.trimmed(node["name"]) ?? Self.trimmed(node["address"]) ?? "",
                                       description: Self.trimmed(node["description"]) ?? "",
                                       images: Self.imageList(node["imgUrl"])))
            }
            let seconds = Self.positive(chapter["totalTime"]).map { Int($0) }
            let count = nodes.isEmpty ? Int(Self.positive(chapter["locationCount"]) ?? 0) : nodes.count
            chapterFacts.append(.init(name: Self.trimmed(chapter["name"]), totalSeconds: seconds, nodeCount: count,
                                      playCount: Int(Self.positive(chapter["templateCount"]) ?? 0), nodes: nodeFacts))
        }
        nodeTemplates = templates
        chapters = chapterFacts
    }
}
