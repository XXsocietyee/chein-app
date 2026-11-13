import Foundation

/// The authorized runtime chapter, not public topic/chapter marketing detail.
public struct ChapterStoryDocument: Equatable {
    public let chapterID: Int
    public let title: String?
    public let cover: String?
    public let description: String?
    public let blocks: [PlayWireValue]
    /// `cap` blocks (open / end): the chapter's opening line and closing line, shown on the
    /// chapter gate and end card rather than in the flow (mini-program l-editor v2).
    public var openingLine: String? { capLine("open") }
    public var closingLine: String? { capLine("end") }
    private func capLine(_ kind: String) -> String? {
        blocks.last { $0["type"].text == "cap" && $0["cap"].text == kind }.flatMap { ParticipationRecord.text($0["content"]) }
    }
    public init(raw: PlayWireValue) throws {
        guard let id = raw["chapterId"].tolerantInteger, id > 0 else { throw APIError.malformedResponse }
        chapterID = id
        title = ParticipationRecord.text(raw["title"]) ?? ParticipationRecord.text(raw["name"])
        cover = ParticipationRecord.text(raw["imgArr"]).flatMap { $0.components(separatedBy: ",").first }.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        description = ParticipationRecord.text(raw["description"])
        if raw["blocks"] == .null { blocks = [] }
        else {
            guard let blocks = raw["blocks"].array, blocks.allSatisfy({ $0.object != nil }) else { throw APIError.malformedResponse }
            self.blocks = blocks
        }
    }
}
public struct ChapterStorySegment: Equatable, Identifiable {
    public enum Content: Equatable {
        case text(String), image(String), audio(String), voice(speaker: String, text: String)
        case reveal(speaker: String, lines: [String]), dream(title: String?, images: [ChapterStoryDreamImage])
        case thought(name: String, description: String?), game(nodeID: Int)
        /// Author divider: one thin rule.
        case divider
        /// A block this build has no renderer for. Its content is never shown; the reader is told
        /// that part of the chapter needs another version instead of the flow silently skipping it.
        case unsupported
    }
    public let id: String
    public let content: Content
    public let mood: String?
    public let odd: Int
    /// Author alt text: image accessibility label, or the same-version transcript of an audio block.
    public var alt: String? = nil
}
public struct ChapterStoryDreamImage: Equatable { public let url: String; public let line: String? }

public enum ChapterStoryProjection {
    /// Scalar replacement only. Missing variables keep the authored token unless a fallback exists.
    public static func substitute(_ text: String, variables: [String: PlayWireValue]) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\{([a-zA-Z][a-zA-Z0-9_]{0,15})(?:\|([^}]{0,20}))?\}"#) else { return text }
        var output = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let full = Range(match.range, in: text), let key = Range(match.range(at: 1), in: text) else { continue }
            let name = String(text[key]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value: String?
            switch variables[name] {
            case .string(let s): value = s.isEmpty ? nil : s
            case .integer(let n): value = String(n)
            case .number(let n): value = n.isFinite ? String(n) : nil
            case .bool(let b): value = b ? "true" : "false"
            default: value = nil
            }
            let fallback = Range(match.range(at: 2), in: text).map { String(text[$0]) }
            if let replacement = value ?? fallback, !replacement.isEmpty { output.replaceSubrange(full, with: replacement) }
        }
        return output
    }
    /// U04-02: the stop where the flow ended because the server locked it (not merely incomplete),
    /// so the reader sees the server's lock reason instead of a silent end. Nothing past it is read.
    public static func lockedStop(chapter: ChapterStoryDocument, snapshot: PlaySnapshot) -> PlayNode? {
        for block in chapter.blocks where block["type"].text == "node" {
            guard let nodeID = block["nodeId"].tolerantInteger,
                  let node = snapshot.visibleNodes.first(where: { $0.id == nodeID && $0.chapterID == chapter.chapterID }) else { return nil }
            if snapshot.isLocked(node) { return node }
            if !snapshot.isDone(node) { return nil }
        }
        return nil
    }
    /// Client rendering never reveals a block beyond the first incomplete OR unknown node.
    /// Backend projection is an independent security boundary; this is a spoiler guard.
    public static func segments(chapter: ChapterStoryDocument, snapshot: PlaySnapshot,
                                variables: [String: PlayWireValue], thoughts: [PlayWireValue] = [],
                                storyVoices: [String: PlayWireValue] = [:], activeInlineNodeID: Int? = nil) -> [ChapterStorySegment] {
        var result: [ChapterStorySegment] = []
        var mood: String?
        var odd = 0
        func append(_ content: ChapterStorySegment.Content, id: String, alt: String? = nil) {
            result.append(.init(id: id, content: content, mood: mood, odd: odd, alt: alt))
        }
        func paragraphs(_ raw: String?, prefix: String) {
            guard let raw else { return }
            for (index, value) in raw.components(separatedBy: .newlines).enumerated() {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { append(.text(substitute(trimmed, variables: variables)), id: "\(prefix).\(index)") }
            }
        }
        func altText(_ raw: PlayWireValue) -> String? { ParticipationRecord.text(raw["altText"]) }
        func voices(_ nodeID: Int, prefix: String) {
            for (index, voice) in (storyVoices[String(nodeID)]?.array ?? []).enumerated() {
                if let text = ParticipationRecord.text(voice["text"]) {
                    append(.voice(speaker: voice["who"].text ?? "", text: substitute(text, variables: variables)), id: "\(prefix).voice.\(index)")
                }
            }
        }
        if let cover = chapter.cover { append(.image(cover), id: "cover") }
        if chapter.blocks.isEmpty {
            paragraphs(chapter.description, prefix: "legacy")
            for node in snapshot.visibleNodes where node.chapterID == chapter.chapterID && snapshot.isDone(node) && !snapshot.isLocked(node) {
                if activeInlineNodeID == node.id { append(.game(nodeID: node.id), id: "game.\(node.id)") }
                voices(node.id, prefix: "legacy.\(node.id)")
                paragraphs(node.storyText, prefix: "note.\(node.id)")
            }
            if let node = snapshot.visibleNodes.first(where: { $0.chapterID == chapter.chapterID && !snapshot.isDone($0) && !snapshot.isLocked($0) }) {
                append(.game(nodeID: node.id), id: "game.\(node.id)")
            }
            return result
        }
        for (index, block) in chapter.blocks.enumerated() {
            let id = "block.\(index)"
            switch block["type"].text {
            case "node":
                guard let nodeID = block["nodeId"].tolerantInteger,
                      let node = snapshot.visibleNodes.first(where: { $0.id == nodeID && $0.chapterID == chapter.chapterID }),
                      !snapshot.isLocked(node) else { return result }
                if !snapshot.isDone(node) {
                    append(.game(nodeID: nodeID), id: id)
                    voices(nodeID, prefix: id)
                    return result
                }
                if activeInlineNodeID == nodeID { append(.game(nodeID: nodeID), id: id + ".game") }
                voices(nodeID, prefix: id)
                paragraphs(node.storyText, prefix: id + ".note")
            case "text":
                // Mini-program: a speaker prefixes the line, and `level` bends only this block.
                let previousOdd = odd
                if let level = block["level"].tolerantInteger { odd = max(0, min(3, level)) }
                let body = block["content"].text
                if let who = ParticipationRecord.text(block["who"]), let body { paragraphs(who + "：" + body, prefix: id) }
                else { paragraphs(body, prefix: id) }
                odd = previousOdd
            case "image": if let url = ParticipationRecord.text(block["url"]) { append(.image(url), id: id, alt: altText(block)) }
            case "audio": if let url = ParticipationRecord.text(block["url"]) { append(.audio(url), id: id, alt: altText(block)) }
            case "gallery":
                // l-editor gallery: one image segment per picture, block alt text on the first (mini-program).
                for (offset, image) in (block["images"].array ?? []).enumerated() {
                    guard let url = ParticipationRecord.text(image["url"]) else { continue }
                    append(.image(url), id: "\(id).\(offset)", alt: altText(image) ?? (offset == 0 ? altText(block) : nil))
                }
            case "divider": append(.divider, id: id)
            case "cap": break // Opening and closing lines belong to the gate and end card.
            case "voice":
                if let text = ParticipationRecord.text(block["content"]) {
                    append(.voice(speaker: block["who"].text ?? "", text: substitute(text, variables: variables)), id: id)
                }
            case "reveal":
                let lines = (block["content"].text ?? "").components(separatedBy: .newlines).compactMap { value -> String? in
                    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : substitute(value, variables: variables)
                }
                if !lines.isEmpty { append(.reveal(speaker: block["who"].text ?? "", lines: lines), id: id) }
            case "dream":
                let images = (block["images"].array ?? []).compactMap { raw -> ChapterStoryDreamImage? in
                    guard let url = ParticipationRecord.text(raw["url"]) else { return nil }
                    return .init(url: url, line: raw["line"].text.map { substitute($0, variables: variables) })
                }
                if !images.isEmpty { append(.dream(title: block["title"].text, images: images), id: id) }
            case "thought":
                if let key = block["thoughtKey"].text, let thought = thoughts.first(where: { $0["key"].text == key }),
                   let name = ParticipationRecord.text(thought["name"]) {
                    append(.thought(name: name, description: thought["desc"].text), id: id)
                } // Unknown thoughts never expose an authored name or trigger an implicit claim.
            case "mood": mood = block["mood"].text
            case "odd": odd = max(0, min(3, block["level"].tolerantInteger ?? 0))
            default: append(.unsupported, id: id) // includes `branch`: no native branch-choice sheet yet
            }
        }
        return result
    }
}
