import Foundation

/// A play template is a single interaction. It is never a topic template, route or activity.
public struct AuthoringPlayTemplateID: RawRepresentable, Codable, Hashable {
    public let rawValue: Int
    public init?(rawValue: Int) { guard rawValue > 0 else { return nil }; self.rawValue = rawValue }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer(); let raw = try c.decode(Int.self)
        guard let value = Self(rawValue: raw) else { throw TemplateAuthoringError.invalidContract }; self = value
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum TemplateAuthoringJSON: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), array([Self]), object([String: Self]), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([Self].self) { self = .array(v) }
        else { self = .object(try c.decode([String: Self].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .string(let v): try c.encode(v); case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v); case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v); case .null: try c.encodeNil() }
    }
    public var string: String? { if case .string(let v) = self { return v }; return nil }
    public var object: [String: Self]? { if case .object(let v) = self { return v }; return nil }
    public var array: [Self]? { if case .array(let v) = self { return v }; return nil }
    public var bool: Bool { if case .bool(let v) = self { return v }; return false }
    public var number: Double? {
        if case .number(let v) = self { return v }
        if case .string(let v) = self { let s = v.trimmingCharacters(in: .whitespacesAndNewlines); return s.isEmpty ? 0 : Double(s) }
        return nil
    }
    public var integer: Int? { guard let v = number, v.isFinite, v.rounded() == v, v > Double(Int.min), v < Double(Int.max) else { return nil }; return Int(v) }
}
/// Mini-program `node-game-catalog.js` picker categories. Sort, match, and classify stay the existing advanced sections.
public enum TemplateAuthoringGameplayCatalog {
    public static let categories = ["全部", "问答", "推理", "互动", "挑战"]
    public struct Game: Equatable, Sendable {
        public let key: String
        public let label: String
        public let category: String
        public let section: String
        public init(key: String, label: String, category: String, section: String) {
            self.key = key; self.label = label; self.category = category; self.section = section
        }
    }
    public static let inference: [Game] = [
        .init(key: "sort", label: "排序", category: "推理", section: "sort"),
        .init(key: "match", label: "连线", category: "推理", section: "match"),
        .init(key: "classify", label: "分类", category: "推理", section: "classify")
    ]
}

/// Loading and failure for `GET /api/play/theme/support-matrix`, and an adoption that has not been confirmed.
public enum TemplateAuthoringSupportPhase: Equatable, Sendable {
    case idle, loading, ready, failed
    public var loadingMessage: String? { self == .loading ? TemplateAuthoringExtraCopy.supportMatrixLoading : nil }
}

public enum TemplateAdoptionConfirmation: Equatable, Sendable {
    case confirmed, pending
    public var message: String? { self == .pending ? TemplateAuthoringExtraCopy.loadFailedAdoptUnconfirmed : nil }
}

public enum TemplateAuthoringError: Error, Equatable {
    case invalidDraft, invalidContract, unavailable, changedSession, storageUnavailable, uncertain, staleReview
}
public enum TemplateAuthoringMethod: Int, Codable, CaseIterable, Identifiable {
    case manual = 0, text = 1, photo = 2, choice = 3, scan = 4, gps = 5, preference = 6, sensor = 7
    public var isLocalConfigurationOnly: Bool { self == .preference || self == .sensor }
    public var id: Int { rawValue }
    public var labelKey: String { "templateAuthor.method.\(rawValue)" }
}
public struct TemplateStoryBeat: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var text = ""
    public var tag = ""
    public var imgs: [String] = []
    public init(text: String = "", tag: String = "", imgs: [String] = []) { self.text = text; self.tag = tag; self.imgs = imgs }
    public var wire: TemplateAuthoringJSON { .object(["text": .string(text), "tag": .string(tag), "imgs": .array(imgs.map { .string($0) })]) }
}
public struct TemplateAuthoringDraft: Codable, Equatable {
    public var id: AuthoringPlayTemplateID?
    public var originalTemplateID: AuthoringPlayTemplateID?
    public var title = ""
    public var description = ""
    public var isSync = 1
    public var finishEnabled = true
    public var validationMethod: TemplateAuthoringMethod = .manual {
        didSet {
            // An explicit method change disables hints without destroying retained text.
            // Synthesized decoding does not invoke this observer on historical drafts.
            if validationMethod != oldValue && !validationMethod.supportsLegacyHints { legacyHintsEnabled = false }
        }
    }
    public var photoReview = 0
    public var rewardEnabled = true
    public var storyEnabled = false
    public var voiceEnabled = false
    public var advanced = TemplateAdvancedDraft()
    public var imgUrl: String?
    public var players: String?
    public var difficulty: String?
    public var usageLocation: String?
    public var requiredMaterials: String?
    public var ruleInstructions: String?
    public var activityCategoryids: String?
    public var questionName: String?
    public var questionAnswer: String?
    public var questionA: String?
    public var questionB: String?
    public var questionC: String?
    public var questionD: String?
    public var correctAnswer: String?
    public var questionImg: String?
    public var questionAudio: String?
    public var questionOptionMediaJson: String?
    public var hint1: String?
    public var hint2: String?
    public var answerReveal: String?
    /// Local editor intent only. Absence infers the old draft's nonempty hint strings.
    public var legacyHintsEnabled: Bool?
    public var photoRequireDesc: String?
    public var feedbackText: String?
    public var medalImg: String?
    public var medalName: String?
    public var medalStyle: String?
    /// Exact source text, including unknown keys; no normalization on save/reopen.
    public var preferenceJson: String?
    /// Optional local-only sensor configuration. Old envelopes decode without it.
    public var sensorDraft: TemplateSensorDraft?
    /// Local-only explicit-edit marker; absent in historical envelopes and never sent on the wire.
    public var storyTimelineEdited: Bool?
    public var storyText: String?
    public var storyImg: String?
    public var storyJson: String?
    public var audioUrl: String?
    public var duration: Int?
    public var categoryId: Int?
    public var couponId: Int?
    public var audioDuration: Int?
    /// MP `formData.scope`. Only `MERCHANT` is written on draft and publish. A player omits it.
    public var operationScope: String?
    /// MP `temp/index.js` `from`. Only `citynode` changes the editor. It is not a personal template field.
    public var authoringFrom: String?
    /// MP `interactionType` (`cms_member_template.interaction_type`). `payload` never sends it.
    /// `TemplateAuthoringContract.cityNodeBody` is the only writer, and only for a future city-node submit.
    public var interactionType: String?
    public init(title: String = "") { self.title = title; self.medalStyle = "glow" }
    public var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var publishIssues: [String] {
        func blank(_ v: String?) -> Bool { (v ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var result: [String] = []
        func need(_ condition: Bool, _ key: String) { if !condition { result.append("templateAuthor.validation." + key) } }
        need(canSave, "title"); need(!blank(description), "description")
        // Dart String.length counts UTF-16 units, not user-perceived graphemes.
        need(description.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count <= 30, "descriptionLength")
        need(!blank(players), "players"); need(duration.map { $0 > 0 } ?? false, "duration")
        need(!blank(activityCategoryids) || categoryId != nil, "category"); need(finishEnabled, "finish")
        // The mini editor keeps selected QA content in advancedConfigJson.qa, not
        // the legacy question fields. Only the matching QA mode owns this answer.
        let advancedQAOwnsAnswer = advanced.enabled("qa") && (
            (validationMethod == .text && advanced.text("qa", "mode") == "TYPE") ||
            (validationMethod == .choice && advanced.text("qa", "mode") == "PICK"))
        if validationMethod == .text && !advancedQAOwnsAnswer { need(!blank(questionName) && !blank(questionAnswer), "answer") }
        if validationMethod == .choice && !advancedQAOwnsAnswer {
            need(!blank(questionName), "question")
            need([questionA, questionB, questionC, questionD].filter { !blank($0) }.count >= 2, "choices")
            need(!blank(correctAnswer), "correctAnswer")
            // Native safeguard: do not submit a correct option which was removed.
            let options = ["A": questionA, "B": questionB, "C": questionC, "D": questionD]
            need(options[correctAnswer ?? ""].map { !blank($0) } ?? false, "correctAnswer")
        }
        if rewardEnabled {
            need((couponId ?? 0) > 0 || !blank(feedbackText) || !blank(medalImg) || !blank(medalName), "reward")
            need(blank(medalImg) == blank(medalName), "medal")
        }
        if voiceEnabled { need(!blank(audioUrl), "audio") }
        if authoringFrom == "citynode" { need(TemplateAuthoringContract.TemplateCityNodeInteraction(rawValue: interactionType ?? "") != nil, "citynodeInteraction") }
        if finishEnabled { result += advanced.issues }
        if let issue = storyProjectionIssue { result.append(issue) }
        var unique: [String] = []; for key in result where !unique.contains(key) { unique.append(key) }; return unique
    }
    public mutating func setStory(_ beats: [TemplateStoryBeat]) throws {
        let original = try TemplateAuthoringStory.editableBeats(raw: storyJson)
        try TemplateAuthoringStory.validateImageEdits(beats, original: original)
        let rows = beats.filter { !TemplateAuthoringStory.sourceTrim($0.text).isEmpty || !$0.imgs.isEmpty }.map(\.wire)
        let encoded = rows.isEmpty ? "" : String(decoding: try JSONEncoder().encode(rows), as: UTF8.self)
        storyJson = encoded; storyTimelineEdited = true
    }
    public func storyBeats() throws -> [TemplateStoryBeat] {
        guard let storyJson, !storyJson.isEmpty else { return [] }
        let rows = try JSONDecoder().decode([TemplateAuthoringJSON].self, from: Data(storyJson.utf8))
        return try rows.map { value in
            guard let row = value.object, let text = row["text"]?.string,
                  let tag = row["tag"]?.string, let images = row["imgs"]?.array else { throw TemplateAuthoringError.invalidContract }
            return try .init(text: text, tag: tag, imgs: images.map { guard let v = $0.string else { throw TemplateAuthoringError.invalidContract }; return v })
        }
    }
    /// Only public fields known in template_detail_page.dart are adopted. No answer reconstruction.
    public static func adopt(_ template: DiscoveryPlayTemplate) throws -> Self {
        guard let source = AuthoringPlayTemplateID(rawValue: template.id) else { throw TemplateAuthoringError.invalidContract }
        var d = Self(title: template.title); d.originalTemplateID = source
        d.description = template.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        d.imgUrl = template.imgUrl; d.players = template.players; d.duration = template.duration
        d.difficulty = template.difficulty; d.usageLocation = template.usageLocation
        d.requiredMaterials = template.requiredMaterials; d.ruleInstructions = template.ruleInstructions
        d.categoryId = template.categoryId
        return d
    }
}

/// Read-only phase for the node-template editor. A missing read stays hidden.
/// Unknown counts are an em dash. A literal zero stays "0". No route is added or sent.
public struct TemplateAuthoringPageReadiness: Equatable {
    public enum Phase: Equatable { case loading, empty, error, unknown, ready }
    public static let unknownNumber = "—"
    public let hidden: Bool
    public let phase: Phase?
    public let durationText: String
    public let useCountText: String
    public let title: String?
    public static func text(_ value: Int?) -> String { value.map(String.init) ?? unknownNumber }
    public static func editor(sessionPresent: Bool, submitting: Bool, blocked: Bool, uncertain: Bool, draft: TemplateAuthoringDraft, messageKey: String?) -> Self {
        guard sessionPresent else { return .hidden() }
        let duration = draft.duration
        let shown = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = shown.isEmpty ? nil : shown
        if submitting { return .init(hidden: false, phase: .loading, duration: duration, uses: nil, title: title) }
        if blocked || errorKeys.contains(messageKey ?? "") { return .init(hidden: false, phase: .error, duration: duration, uses: nil, title: title) }
        if uncertain || unknownKeys.contains(messageKey ?? "") { return .init(hidden: false, phase: .unknown, duration: duration, uses: nil, title: title) }
        let players = (draft.players ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if title == nil && description.isEmpty && players.isEmpty && duration == nil {
            return .init(hidden: false, phase: .empty, duration: nil, uses: nil, title: nil)
        }
        return .init(hidden: false, phase: .ready, duration: duration, uses: nil, title: title)
    }
    public static func libraryInfo(data: Data?, httpStatus: Int?, readable: Bool, inFlight: Bool) -> Self {
        guard readable else { return .hidden() }
        guard let data else {
            if inFlight && httpStatus == nil { return .init(hidden: false, phase: .loading, duration: nil, uses: nil, title: nil) }
            return httpStatus == nil
                ? .init(hidden: false, phase: .unknown, duration: nil, uses: nil, title: nil)
                : .init(hidden: false, phase: .error, duration: nil, uses: nil, title: nil)
        }
        if let httpStatus, !(200..<300).contains(httpStatus) {
            return .init(hidden: false, phase: .error, duration: nil, uses: nil, title: nil)
        }
        guard let envelope = try? JSONDecoder().decode(LibraryInfoEnvelope.self, from: data) else {
            return .init(hidden: false, phase: .error, duration: nil, uses: nil, title: nil)
        }
        guard let code = count(envelope.code) else {
            return .init(hidden: false, phase: .unknown, duration: nil, uses: nil, title: nil)
        }
        guard code == 200 else { return .init(hidden: false, phase: .error, duration: nil, uses: nil, title: nil) }
        switch envelope.data {
        case .none:
            return .init(hidden: false, phase: .unknown, duration: nil, uses: nil, title: nil)
        case .some(.null):
            return .init(hidden: false, phase: .empty, duration: nil, uses: nil, title: nil)
        case .some(.array(let rows)):
            return .init(hidden: false, phase: rows.isEmpty ? .empty : .unknown, duration: nil, uses: nil, title: nil)
        case .some(.object(let fields)):
            if fields.isEmpty { return .init(hidden: false, phase: .empty, duration: nil, uses: nil, title: nil) }
            guard let id = count(fields["id"]), id > 0 else {
                return .init(hidden: false, phase: .unknown, duration: nil, uses: nil, title: nil)
            }
            let rawTitle = fields["title"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = (rawTitle?.isEmpty == false) ? rawTitle : nil
            return .init(hidden: false, phase: .ready, duration: count(fields["duration"]), uses: count(fields["useNum"]), title: title)
        case .some(.string(_)), .some(.number(_)), .some(.bool(_)):
            return .init(hidden: false, phase: .error, duration: nil, uses: nil, title: nil)
        }
    }
    private static let errorKeys: Set<String> = ["templateAuthor.storageFailed", "templateAuthor.unavailable", "templateAuthor.listUnavailable"]
    private static let unknownKeys: Set<String> = ["templateAuthor.uncertain", "templateAuthor.shelf.unknown"]
    private static func hidden() -> Self { .init(hidden: true, phase: nil, duration: nil, uses: nil, title: nil) }
    private init(hidden: Bool, phase: Phase?, duration: Int?, uses: Int?, title: String?) {
        self.hidden = hidden
        self.phase = hidden ? nil : phase
        self.durationText = hidden ? Self.unknownNumber : Self.text(duration)
        self.useCountText = hidden ? Self.unknownNumber : Self.text(uses)
        self.title = hidden ? nil : title
    }
    /// Exact non-negative integers only. An empty string, a bool, and a fraction are unknown, not 0.
    private static func count(_ value: TemplateAuthoringJSON?) -> Int? {
        switch value {
        case .some(.number(let raw)):
            guard raw.isFinite, raw >= 0, raw < Double(Int.max), raw.rounded() == raw else { return nil }
            return Int(raw)
        case .some(.string(let raw)):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let parsed = Int(trimmed), parsed >= 0, String(parsed) == trimmed else { return nil }
            return parsed
        case .none, .some(.bool), .some(.array), .some(.object), .some(.null):
            return nil
        }
    }
    private struct LibraryInfoEnvelope: Decodable {
        var code: TemplateAuthoringJSON?
        var data: TemplateAuthoringJSON?
        private enum CodingKeys: String, CodingKey { case code, data }
        /// A synthesized optional maps an explicit `"data":null` to nil, which reads as a missing field (unknown).
        /// Keep the two apart: missing stays nil, explicit null is the server's empty answer.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            code = try c.decodeIfPresent(TemplateAuthoringJSON.self, forKey: .code)
            if !c.contains(.data) { data = nil }
            else if try c.decodeNil(forKey: .data) { data = .null }
            else { data = try c.decode(TemplateAuthoringJSON.self, forKey: .data) }
        }
    }
}

/// MP `pages/publish/utils/publish/node-outcome-contract.js` `extract`.
/// This is the temp editor's 可触发的结果 list (`temp/index.wxml` outcomePreview), not `outcomeRules`.
public enum TemplateTriggerableOutcomes {
    public enum Label: Equatable, Sendable {
        case authored(String)
        case completed, d20Success, d20Failure, unnamed
    }
    public struct Item: Equatable, Identifiable, Sendable {
        public let triggerType: String
        public let code: String
        public let label: Label
        public let source: String
        public let sourceKey: String
        public let id: String
    }
    public struct Issue: Equatable, Identifiable, Sendable {
        public enum Code: String, Sendable { case invalidCode = "INVALID_CODE", duplicateCode = "DUPLICATE_CODE" }
        public let code: Code
        public let source: String
        public let sourceKey: String
        public var id: String { code.rawValue + ":" + source + ":" + sourceKey }
        public var labelKey: String {
            switch code {
            case .invalidCode: return "templateAuthor.outcome.invalidCode"
            case .duplicateCode: return "templateAuthor.outcome.duplicateCode"
            }
        }
    }
    public struct Result: Equatable, Sendable {
        public var items: [Item]
        public var issues: [Issue]
    }
    public static func extract(_ draft: TemplateAuthoringDraft) -> Result {
        var items: [Item] = []
        func append(_ trigger: String, _ code: String, _ label: Label, _ source: String, _ sourceKey: String) {
            items.append(.init(triggerType: trigger, code: code, label: label, source: source, sourceKey: sourceKey, id: "\(items.count):\(source):\(sourceKey)"))
        }
        if draft.validationMethod == .preference, let results = jsonObject(draft.preferenceJson)?["results"]?.object {
            for code in results.keys.sorted() {
                let title = results[code]?.object?["title"]?.string
                append("PREFERENCE_RESULT", code, .authored(nonempty(title) ?? code), "preference", code)
            }
        }
        let advanced = draft.advanced.value
        if let branch = advanced["branch"]?.object, branch["enabled"]?.bool == true {
            for raw in branch["steps"]?.array ?? [] {
                guard let step = raw.object, step["terminal"]?.bool == true else { continue }
                let code = step["outcomeCode"]?.string ?? ""
                let authored = nonempty(step["outcomeLabel"]?.string) ?? nonempty(step["title"]?.string) ?? nonempty(code)
                append("ADVANCED_RESULT", code, authored.map(Label.authored) ?? .unnamed, "advanced", step["id"]?.string ?? "")
            }
        }
        if items.isEmpty, let dice = advanced["diceRoll"]?.object, dice["enabled"]?.bool == true, dice["mode"]?.string == "d20" {
            append("ADVANCED_RESULT", "D20_SUCCESS", .d20Success, "advanced", "D20_SUCCESS")
            append("ADVANCED_RESULT", "D20_FAILURE", .d20Failure, "advanced", "D20_FAILURE")
        }
        if items.isEmpty { append("CHOICE", "COMPLETED", .completed, "default", "COMPLETED") }
        var seen = Set<String>()
        var issues: [Issue] = []
        for item in items {
            if item.code.range(of: #"^[A-Za-z0-9_-]{1,64}$"#, options: .regularExpression) == nil {
                issues.append(.init(code: .invalidCode, source: item.source, sourceKey: item.sourceKey))
            } else if !seen.insert(item.code).inserted {
                issues.append(.init(code: .duplicateCode, source: item.source, sourceKey: item.sourceKey))
            }
        }
        return .init(items: items, issues: issues)
    }
    private static func nonempty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
    private static func jsonObject(_ raw: String?) -> [String: TemplateAuthoringJSON]? {
        guard let raw, let data = raw.data(using: .utf8),
              let value = try? JSONDecoder().decode(TemplateAuthoringJSON.self, from: data) else { return nil }
        return value.object
    }
}
