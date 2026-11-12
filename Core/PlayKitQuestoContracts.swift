import Foundation

/// Mini-program pages/play/utils/playkit-questo.js and playkit-r5-segments.js albumKit.
/// These only carry server facts to a screen. They never judge an answer, store one,
/// or infer an early or successful close. UG-01 and UG-03 writes stay NOT_RUN in Core:
/// a host passes a write binding, and without one the screen shows why it cannot send.

// MARK: - UG-01 hangman

public struct PlayKitHangmanSlot: Equatable, Identifiable {
    public enum Kind: String { case separator = "SEPARATOR", prefilled = "PREFILLED", filled = "FILLED", blank = "BLANK" }
    public let index: Int
    public let kind: Kind
    /// Empty for a blank slot. The answer is never in the projection.
    public let character: String
    public var id: Int { index }
    public var isEditable: Bool { kind == .filled || kind == .blank }
}

public struct PlayKitHangmanCell: Equatable, Identifiable {
    public let slot: PlayKitHangmanSlot
    /// Position among editable cells (the n-th typed character), nil for given cells.
    public let order: Int?
    public let character: String
    public var id: Int { slot.index }
}

/// A word of cells, or a visible separator between words. A word never wraps inside itself.
public struct PlayKitHangmanGroup: Equatable, Identifiable {
    public let id: String
    public let separator: String?
    public let cells: [PlayKitHangmanCell]
}

public struct PlayKitHangmanProjection: Equatable {
    public let title: String
    public let slots: [PlayKitHangmanSlot]
    public let solved: Bool
    /// Shown only after the server says solved.
    public let display: String

    public init(segment: PlayWireValue) {
        title = segment["title"].text ?? ""
        slots = (segment["slots"].array ?? []).enumerated().map { offset, row in
            let kind = PlayKitHangmanSlot.Kind(rawValue: row["kind"].text ?? "") ?? .blank
            let index = row["i"].integer ?? offset
            return PlayKitHangmanSlot(index: index, kind: kind, character: kind == .blank ? "" : (row["ch"].text ?? ""))
        }
        solved = segment["solved"].bool == true
        display = solved ? (segment["display"].text ?? "") : ""
    }

    public var editable: [PlayKitHangmanSlot] { slots.filter(\.isEditable) }
    public var blankCount: Int { editable.count }

    /// Code points, one per cell (a supplementary-plane character fills one cell).
    public static func codePoints(_ text: String) -> [String] {
        text.unicodeScalars.map { String($0) }
    }

    /// Typed text to cell characters: whitespace dropped, one character per editable cell in order, extra dropped.
    public func distribute(_ text: String) -> [Int: String] {
        let characters = Self.codePoints(text).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var typed: [Int: String] = [:]
        for (n, slot) in editable.enumerated() where n < characters.count { typed[slot.index] = characters[n] }
        return typed
    }

    /// Server-recorded FILLED cells as the field's first value: the leading run without a gap.
    public var initialText: String {
        var out = ""
        for slot in editable {
            if slot.character.isEmpty { break }
            out += slot.character
        }
        return out
    }

    public func cells(typed: [Int: String]) -> [PlayKitHangmanCell] {
        var n = 0
        return slots.map { slot in
            guard slot.isEditable else { return PlayKitHangmanCell(slot: slot, order: nil, character: slot.character) }
            defer { n += 1 }
            let local = typed[slot.index] ?? ""
            return PlayKitHangmanCell(slot: slot, order: n, character: local.isEmpty ? (slot.kind == .filled ? slot.character : "") : local)
        }
    }

    public func groups(typed: [Int: String]) -> [PlayKitHangmanGroup] {
        var groups: [PlayKitHangmanGroup] = []
        var current: [PlayKitHangmanCell] = []
        for cell in cells(typed: typed) {
            if cell.slot.kind == .separator {
                if let first = current.first { groups.append(.init(id: "g\(first.slot.index)", separator: nil, cells: current)) }
                current = []
                if !cell.character.isEmpty, cell.character != " " {
                    groups.append(.init(id: "s\(cell.slot.index)", separator: cell.character, cells: []))
                }
                continue
            }
            current.append(cell)
        }
        if let first = current.first { groups.append(.init(id: "g\(first.slot.index)", separator: nil, cells: current)) }
        return groups
    }

    /// Slot index of the n-th editable cell, nil past the end.
    public func editableIndex(at n: Int) -> Int? {
        let list = editable
        return n >= 0 && n < list.count ? list[n].index : nil
    }

    /// SUBMIT_HANGMAN `{slots: {"i": ch}}` once every editable cell has a character, otherwise nil.
    public func payload(typed: [Int: String]) -> [String: PlayWireValue]? {
        var out: [String: PlayWireValue] = [:]
        for slot in editable {
            let local = typed[slot.index] ?? ""
            let character = local.isEmpty ? (slot.kind == .filled ? slot.character : "") : local
            if character.isEmpty { return nil }
            out[String(slot.index)] = .string(character)
        }
        return out.isEmpty ? nil : ["slots": .object(out)]
    }
}

// MARK: - UG-03 / UG-04 accusation

public struct PlayKitAccusationProjection: Equatable {
    public enum Block: Equatable {
        case text(String)
        case image(url: String, alt: String)
    }
    public enum Outcome: String, Equatable {
        case solved = "SOLVED", early = "EARLY", failed = "FAILED", wrong = "WRONG"
    }
    public struct Suspect: Equatable, Identifiable {
        public let id: String
        public let name: String
        public let identity: String
        public let avatar: String?
        public let testimony: [String]
        /// First character of the name, for the avatar placeholder.
        public var initial: String { name.first.map { String($0) } ?? "" }
    }
    public struct Clue: Equatable, Identifiable {
        public let id: String
        /// Empty when the server gave no name; the screen shows the localized word for clue.
        public let name: String
        public let text: String
        public let image: String?
    }

    public let title: String
    public let boardImage: String?
    public let boardAlt: String
    public let intro: [Block]
    public let suspects: [Suspect]
    public let clues: [Clue]
    public let outcome: Outcome?
    /// The qa answer is in but the server has not given a result yet.
    public let pending: Bool
    public let wrongAttempt: Bool
    public let retryNote: String
    public let screen: [Block]

    /// The mini-program draws at most six notes on the board.
    public static let maxPins = 6

    /// Non-nil only for a PICK qa segment whose node turned accusation on. readyForBase is never read:
    /// it is also true when limited wrong attempts ran out.
    public static func project(state: PlayAdvancedState) -> Self? {
        let qa = state.playKit["qa"]
        guard qa.object != nil, qa["mode"].text == "PICK", state.accusation["enabled"].bool == true else { return nil }
        return Self(accusation: state.accusation, qa: qa, clues: state.clues)
    }

    public init(accusation acc: PlayWireValue, qa: PlayWireValue, clues rawClues: [PlayWireValue]) {
        var labels: [String: String] = [:]
        for option in qa["options"].array ?? [] { if let id = option["id"].text, !id.isEmpty { labels[id] = option["label"].text ?? "" } }
        suspects = (acc["suspects"].array ?? []).compactMap { row in
            guard let id = row["id"].text, !id.isEmpty else { return nil }
            let testimony = (row["testimony"].array ?? []).compactMap { $0["text"].text }.filter { !$0.isEmpty }
            return Suspect(id: id, name: row["name"].text ?? labels[id] ?? "", identity: row["identity"].text ?? "",
                           avatar: Self.displayable(row["avatar"].text), testimony: testimony)
        }
        let board = acc["corkboardImage"]
        boardImage = Self.displayable(board.text ?? board["img"].text)
        boardAlt = board["alt"].text ?? ""
        intro = Self.blocks(acc["introScreens"])
        clues = rawClues.compactMap { row in
            guard row["id"] != .null else { return nil }
            var texts: [String] = []
            var image: String?
            for source in row["sources"].array ?? [] {
                for block in source["blocks"].array ?? [] {
                    if let text = block["text"].text, !text.isEmpty { texts.append(text) }
                    if image == nil { image = (block["images"].array ?? []).lazy.compactMap { Self.displayable($0.text) }.first }
                }
            }
            let id = (row["id"].text ?? row["id"].integer.map(String.init) ?? "") + ":" + (row["scope"].text ?? "")
            return Clue(id: id, name: row["name"].text ?? "", text: texts.joined(separator: "\n"), image: image)
        }.prefix(Self.maxPins).map { $0 }
        let result = acc["result"]
        switch result["verdict"].text {
        case "CORRECT": outcome = result["early"].bool == true ? .early : .solved
        case "FAILED": outcome = .failed
        case "WRONG": outcome = .wrong
        default: outcome = nil
        }
        let hasResult = result.object != nil
        pending = !hasResult && qa["finished"].bool == true
        let wrong = outcome == .wrong || (!hasResult && (qa["attempts"].integer ?? 0) > 0 && qa["finished"].bool != true && qa["passed"].bool != true)
        wrongAttempt = wrong
        retryNote = wrong ? (qa["lastFeedback"].text ?? "") : ""
        screen = result["terminal"].bool == true ? Self.blocks(acc["screen"]) : []
        title = qa["title"].text ?? ""
    }

    /// The end screen covers the suspects once the server has a verdict other than "keep investigating".
    public var showsEnding: Bool { (outcome != nil && outcome != .wrong) || pending }

    /// Only https addresses are drawn. media-asset, http and data references fall back to text.
    static func displayable(_ raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), value.hasPrefix("https://") else { return nil }
        return value
    }

    /// Author screens: text and displayable images in source order, without guessing structure.
    static func blocks(_ node: PlayWireValue) -> [Block] {
        var out: [Block] = []
        func visit(_ node: PlayWireValue) {
            if let text = node.text {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { out.append(.text(trimmed)) }
                return
            }
            if let rows = node.array { rows.forEach(visit); return }
            guard node.object != nil else { return }
            for key in ["img", "image", "imageUrl"] {
                if let url = displayable(node[key].text) { out.append(.image(url: url, alt: node["alt"].text ?? "")) }
            }
            for key in ["title", "text", "body", "content", "caption"] {
                if let text = node[key].text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { out.append(.text(text)) }
            }
        }
        visit(node)
        return out
    }
}

// MARK: - Album

public struct PlayKitAlbumProjection: Equatable {
    public struct Photo: Equatable, Identifiable {
        public let id: Int
        public let url: String
        /// Caption under the card. Empty when the author wrote none.
        public let line: String
    }
    /// Empty when the segment has no title; the screen shows the localized word for album.
    public let title: String
    public let photos: [Photo]
    public let done: Bool
    /// R5 outcome rules let the player finish the album with a photo. Earlier rules only show it.
    public let completionEnabled: Bool

    public init?(state: PlayAdvancedState) {
        let segment = state.playKit["album"]
        guard segment.object != nil else { return nil }
        self.init(segment: segment, outcomeRulesVersion: state.config["outcomeRulesVersion"].integer)
    }

    public init(segment: PlayWireValue, outcomeRulesVersion: Int?) {
        let r5 = outcomeRulesVersion == 1
        done = segment["done"].bool == true
        completionEnabled = r5
        title = segment["title"].text ?? ""
        // Before completion, R5 images are author art; only the completion receipt is player evidence.
        let rows = r5 && !done ? [] : (segment["images"].array ?? [])
        photos = rows.enumerated().compactMap { offset, row in
            let url = row.text ?? row["url"].text ?? ""
            guard !url.isEmpty else { return nil }
            return Photo(id: offset, url: url, line: row["line"].text ?? "")
        }
    }
}
