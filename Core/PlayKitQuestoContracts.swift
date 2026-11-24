import Foundation

/// Mini-program pages/play/utils/playkit-questo.js and playkit-r5-segments.js albumKit.
/// These only carry server facts to a screen. They never judge an answer, store one,
/// or infer an early or successful close. Hangman and album publish through
/// `/api/play/advanced/action`. Accusation publishes as SUBMIT_QA.

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
    public enum InputMode: String, Equatable { case keyboard, pool }
    public static let maximumPool = 30
    public let title: String
    public let slots: [PlayKitHangmanSlot]
    public let solved: Bool
    /// Shown only after the server says solved.
    public let display: String
    /// Server feedback on the kit. Empty unless solved. Station `passText` is a separate fallback.
    public let feedback: String
    /// `.pool` arranges server candidates. Keyboard stays the default. There is no second hangman screen.
    public let inputMode: InputMode
    /// Visible candidates in server order. Empty in keyboard mode.
    public let pool: [String]
    /// Decoys removed by POOL_TRIM hints (0 when none).
    public let poolRemoved: Int
    /// CG-01-P2-5: the author's "how to fill" note. Nil hides the entry.
    public let howTo: String?
    public let caseSensitive: Bool
    /// Pool mode was requested but the candidate list cannot be used.
    public let poolMalformed: Bool

    public init(segment: PlayWireValue) {
        title = segment["title"].text ?? ""
        slots = (segment["slots"].array ?? []).enumerated().map { offset, row in
            let kind = PlayKitHangmanSlot.Kind(rawValue: row["kind"].text ?? "") ?? .blank
            let index = row["i"].integer ?? offset
            return PlayKitHangmanSlot(index: index, kind: kind, character: kind == .blank ? "" : (row["ch"].text ?? ""))
        }
        solved = segment["solved"].bool == true
        display = solved ? (segment["display"].text ?? "") : ""
        let rawFeedback = segment["feedback"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        feedback = solved ? rawFeedback : ""
        caseSensitive = segment["caseSensitive"].bool == true
        let note = segment["howTo"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
        howTo = note?.isEmpty == false ? note : nil
        switch segment["inputMode"].text {
        case nil, "keyboard":
            inputMode = .keyboard; pool = []; poolRemoved = 0; poolMalformed = false
        case "pool":
            inputMode = .pool
            if let parsed = Self.poolFields(segment) {
                pool = parsed.chars; poolRemoved = parsed.removed; poolMalformed = false
            } else {
                pool = []; poolRemoved = 0; poolMalformed = true
            }
        default:
            inputMode = .keyboard; pool = []; poolRemoved = 0; poolMalformed = true
        }
    }

    /// Strict read used by the pool contract. A bad slot, mode or candidate list throws.
    public init(validated segment: PlayWireValue) throws {
        guard segment.object != nil, let rows = segment["slots"].array, !rows.isEmpty else { throw PlayExperienceError.malformed }
        var parsed: [PlayKitHangmanSlot] = []
        for (position, row) in rows.enumerated() {
            guard let index = row["i"].integer, index == position,
                  let rawKind = row["kind"].text, let kind = PlayKitHangmanSlot.Kind(rawValue: rawKind) else { throw PlayExperienceError.malformed }
            let character = row["ch"].text
            switch kind {
            case .separator, .prefilled, .filled:
                guard let character, character.unicodeScalars.count == 1 else { throw PlayExperienceError.malformed }
                parsed.append(.init(index: index, kind: kind, character: character))
            case .blank:
                guard row["ch"] == .null else { throw PlayExperienceError.malformed }
                parsed.append(.init(index: index, kind: kind, character: ""))
            }
        }
        guard parsed.contains(where: \.isEditable) else { throw PlayExperienceError.malformed }
        if segment["length"] != .null { guard segment["length"].integer == parsed.count else { throw PlayExperienceError.malformed } }
        title = segment["title"].text ?? ""
        slots = parsed
        solved = segment["solved"].bool == true
        display = solved ? (segment["display"].text ?? "") : ""
        let rawFeedback = segment["feedback"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        feedback = solved ? rawFeedback : ""
        caseSensitive = segment["caseSensitive"].bool == true
        let note = segment["howTo"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
        howTo = note?.isEmpty == false ? note : nil
        switch segment["inputMode"] {
        case .null: inputMode = .keyboard
        case .string(let value):
            guard let mode = InputMode(rawValue: value) else { throw PlayExperienceError.malformed }
            inputMode = mode
        default: throw PlayExperienceError.malformed
        }
        if inputMode == .pool {
            guard let fields = Self.poolFields(segment) else { throw PlayExperienceError.malformed }
            pool = fields.chars; poolRemoved = fields.removed; poolMalformed = false
        } else {
            pool = []; poolRemoved = 0; poolMalformed = false
        }
    }

    private static func poolFields(_ segment: PlayWireValue) -> (chars: [String], removed: Int)? {
        guard let candidates = segment["pool"].array, candidates.count <= maximumPool else { return nil }
        let values = candidates.compactMap(\.text)
        guard values.count == candidates.count, values.allSatisfy({ $0.unicodeScalars.count == 1 }) else { return nil }
        let removed: Int
        if segment["poolRemoved"] == .null { removed = 0 }
        else if let value = segment["poolRemoved"].integer, value >= 0 { removed = value }
        else { return nil }
        return (values, removed)
    }

    /// `hangmanStationText`: station question, else kit title, else the place name. Empty stays empty.
    public func stationTitle(question: String?, placeName: String?) -> String {
        let asked = question?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !asked.isEmpty { return asked }
        let kit = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !kit.isEmpty { return kit }
        return placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Solved feedback: kit text, else the station pass line. Unsolved stays blank. The server still judges.
    public func stationFeedback(passText: String?) -> String {
        guard solved else { return "" }
        if !feedback.isEmpty { return feedback }
        return passText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

    /// SUBMIT_HANGMAN `{input: "整词"}`: the whole word as typed. The server ignores spaces and rebuilds the
    /// answer itself; nothing is cut or completed here. Nil when only whitespace was typed.
    public static func wholeWordPayload(_ text: String) -> [String: PlayWireValue]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.unicodeScalars.count <= wholeWordLimit else { return nil }
        return ["input": .string(trimmed)]
    }
    public static let wholeWordLimit = 64

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

    public var fillableSlots: [PlayKitHangmanSlot] { editable }

    /// Keyboard mode: typed characters fill BLANK/FILLED slots in order. Nil until every slot is covered.
    public func keyboardPayload(_ typed: String) -> [String: PlayWireValue]? {
        let characters = typed.filter { !$0.isWhitespace }.map(String.init)
        let targets = fillableSlots
        guard characters.count == targets.count, characters.allSatisfy({ $0.unicodeScalars.count == 1 }) else { return nil }
        var payload: [String: PlayWireValue] = [:]
        for (slot, character) in zip(targets, characters) { payload[String(slot.index)] = .string(character) }
        return ["slots": .object(payload)]
    }

    /// Keyboard mode starts from the characters the server kept in FILLED slots.
    public var keyboardDraft: String { initialText }

    /// SUBMIT_HANGMAN slots: fillable indices only, one character each. Pool mode may only use visible candidates.
    /// A FILLED slot the server already holds may be omitted.
    public func validate(_ payload: [String: PlayWireValue]) throws {
        guard Set(payload.keys) == ["slots"], let submitted = payload["slots"]?.object, !submitted.isEmpty else { throw PlayExperienceError.invalidAction }
        var fillable: [Int: PlayKitHangmanSlot] = [:]
        for slot in fillableSlots {
            guard fillable[slot.index] == nil else { throw PlayExperienceError.invalidAction }
            fillable[slot.index] = slot
        }
        var used: [String] = []
        for (key, value) in submitted {
            guard let index = Int(key), String(index) == key, fillable[index] != nil,
                  let character = value.text, character.unicodeScalars.count == 1 else { throw PlayExperienceError.invalidAction }
            used.append(character)
        }
        guard fillableSlots.allSatisfy({ submitted[String($0.index)] != nil || $0.kind == .filled }) else { throw PlayExperienceError.invalidAction }
        if inputMode == .pool, !LetterPoolState.fits(used, in: pool) { throw PlayExperienceError.invalidAction }
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

/// Names for the three play writes. Accusation reuses SUBMIT_QA.
public enum PlayKitPublishedWrites {
    public static let hangmanKind = "hangman"
    public static let hangmanAction = "SUBMIT_HANGMAN"
    public static let accusationKind = "qa"
    public static let accusationAction = "SUBMIT_QA"
    public static func accusationDetail(optionID: String) -> [String: PlayWireValue] {
        ["optionId": .string(optionID)]
    }
    public static let albumKind = "album"
    public static let albumAction = "SUBMIT_ALBUM"
    /// One uploaded https URL. This is not a price, order, or payment.
    public static func albumDetail(imageURL: String) -> [String: PlayWireValue] {
        ["imageUrls": .array([.string(imageURL)])]
    }
}

/// Photo upload outcome for album completion. Failure stays failed and does not mint a request id.
public enum PlayAlbumUploadOutcome: Equatable, Sendable {
    case failed
    case ready(String)

    public static func resolve(url: String?, issue: PlayExperienceError?) -> Self {
        guard issue == nil, let url, PlayExperienceService.validHTTPS(url) else { return .failed }
        return .ready(url)
    }
}

// MARK: - UG-02 image options

/// A PICK option with its picture (mini-program playkit-questo.js qaOptions). Only an https picture is kept;
/// `media-asset:`, http, data and protocol-relative references fall back to text. Correctness and feedback are
/// never read; the submit still carries the original option id.
public struct PlayKitImageOption: Equatable, Identifiable {
    public let id: String
    /// A, B, C, D, then the 1-based position.
    public let key: String
    public let label: String
    public let image: String?
    /// Author alt text, read only when the picture is kept. Empty when the author wrote none.
    public let alt: String

    /// The accessibility name: label first, then the alt text when it adds something.
    public var spokenDescription: String {
        let extra = alt.trimmingCharacters(in: .whitespacesAndNewlines)
        return extra.isEmpty || extra == label ? label : label + "，" + extra
    }

    static let keys = ["A", "B", "C", "D"]

    /// Row letter. Past D the mini-program uses the 1-based index, which is not stripped.
    public static func letter(at index: Int) -> String {
        index >= 0 && index < keys.count ? keys[index] : String(index + 1)
    }

    /// `stripOptionKey`: the row already draws this letter, so a matching author prefix is not drawn twice.
    /// A strip that would leave no words keeps the original text.
    public static func stripDuplicateKey(_ text: String, key: String) -> String {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard k.range(of: "^[A-Za-z]$", options: .regularExpression) != nil else { return text }
        let pattern = "^\\s*[(（]?" + NSRegularExpression.escapedPattern(for: k) + "(?:[)）.．、:：]\\s*|\\s+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, options: [], range: whole), match.range.location == 0 else { return text }
        let rest = ns.substring(from: match.range.length)
        return rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text : rest
    }

    /// Nil unless at least one option has a picture this build can show: text-only questions keep the plain rows.
    public static func read(_ segment: PlayWireValue) -> [PlayKitImageOption]? {
        var seen = Set<String>()
        let rows: [PlayKitImageOption] = (segment["options"].array ?? []).enumerated().compactMap { offset, row in
            guard let id = row["id"].text, !id.isEmpty, seen.insert(id).inserted else { return nil }
            let image = PlayKitAccusationProjection.displayable(row["img"].text)
            let key = offset < keys.count ? keys[offset] : String(offset + 1)
            let rawLabel = row["label"].text ?? row["t"].text ?? id
            return PlayKitImageOption(id: id, key: key, label: stripDuplicateKey(rawLabel, key: key), image: image,
                                      alt: image == nil ? "" : (row["alt"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return rows.contains { $0.image != nil } ? rows : nil
    }
}
