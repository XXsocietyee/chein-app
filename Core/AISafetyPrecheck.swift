import Foundation

/// Planning audit H-08b: the pre-publish AI safety precheck, `POST api/ai/safety/precheck`, JSON exactly the backend
/// `AiSafetyPrecheckReq {title, subtitle, description, nodes:[{name, task, hint1, hint2}]}` (us/r3-functional
/// `ApiAiController.java:383-399`). The old `{content, scene}` body did not match the DTO.
public enum AISafetyPrecheckRequest {
    public static let path = "api/ai/safety/precheck"
    public static let fieldKeys: Set<String> = ["title", "subtitle", "description", "nodes"]
    public static let nodeKeys: Set<String> = ["name", "task", "hint1", "hint2"]

    /// MP `pages/publish/fabu/index.js` `_buildPrecheckReq`: the topic copy, then every chapter's stops in order.
    public static func fields(for draft: ProjectEditDraft) -> [String: ProjectEditJSON] {
        let stops: [ProjectEditNode] = draft.chapters.flatMap { $0.nodes }
        let nodes: [ProjectEditJSON] = stops.map { node in
            ProjectEditJSON.object([
                "name": .string(node.name),
                "task": .string(taskText(node)),
                "hint1": .string(metadataText(node, "hint1")),
                "hint2": .string(metadataText(node, "hint2"))
            ])
        }
        return ["title": .string(draft.name), "subtitle": .string(draft.subtitle),
                "description": .string(draft.description), "nodes": .array(nodes)]
    }

    /// One free text (a post, a comment) in the same DTO: the text is the description, with no stops.
    public static func fields(text: String) -> [String: ProjectEditJSON] {
        ["title": .string(""), "subtitle": .string(""), "description": .string(text), "nodes": .array([])]
    }

    /// The exact shape the backend DTO binds: only the four keys, strings, and stops with only the four stop keys.
    public static func validates(_ fields: [String: ProjectEditJSON]) -> Bool {
        guard Set(fields.keys).isSubset(of: fieldKeys) else { return false }
        for key in ["title", "subtitle", "description"] {
            if let value = fields[key], value.text == nil { return false }
        }
        guard let nodes = fields["nodes"] else { return true }
        guard let list = nodes.array else { return false }
        for item in list {
            guard let object = item.object, Set(object.keys).isSubset(of: nodeKeys),
                  object.values.allSatisfy({ $0.text != nil }) else { return false }
        }
        return true
    }

    /// MP: the rule text, else the question, else the stop description.
    static func taskText(_ node: ProjectEditNode) -> String {
        for key in ["ruleInstructions", "questionName"] {
            let value = metadataText(node, key)
            if !value.isEmpty { return value }
        }
        return node.description
    }

    static func metadataText(_ node: ProjectEditNode, _ key: String) -> String {
        if let value = node.localMetadata["templateInfo"]?.object?[key]?.text { return value }
        return node.localMetadata[key]?.text ?? ""
    }
}

/// The precheck result the publish step acts on. MP `fabu/index.js` `_classifyAiIssues` / `_afterPrecheck`:
/// - `level == "error"` blocks, except `parse_error` (the model failed, not the content) and `timeline_conflict`
///   (opening hours / crowds are advisory only);
/// - `missing_cover` is dropped: the model never sees the cover, so it is always a false positive;
/// - any non-200, rate limit, role gate or transport failure degrades to pass with a skip notice (AI must never block
///   the publish path).
public struct AISafetyPrecheckVerdict: Equatable {
    public enum Skip: Equatable {
        /// MP 「AI 次数已用完，本次跳过安全预检(不影响发布)」.
        case quota
        /// MP 「安全预检暂不可用，本次跳过(不影响发布)」 (also the player role gate: the backend runs the
        /// precheck for club hosts only).
        case unavailable
    }
    public let blocking: [PublishingSafetyIssue]
    public let advisory: [PublishingSafetyIssue]
    public let skip: Skip?

    public static let blindTypes: Set<String> = ["missing_cover"]
    public static let advisoryTypes: Set<String> = ["timeline_conflict", "parse_error"]
    /// The only server message that skips the precheck as quota. A longer sentence that merely contains it does not.
    public static let quotaHint = "今日AI次数已用完"
    /// Backend role gate (`gateRole` / template-fill 403). It must not contain `quotaHint`, or a quota skip would hide it.
    public static let roleGate = "当前身份暂不支持AI创作"

    public init(blocking: [PublishingSafetyIssue], advisory: [PublishingSafetyIssue], skip: Skip?) {
        self.blocking = blocking
        self.advisory = advisory
        self.skip = skip
    }

    public static func issues(_ issues: [PublishingSafetyIssue]) -> Self {
        let seen = issues.filter { !blindTypes.contains($0.type) }
        let blocking = seen.filter { $0.level == "error" && !advisoryTypes.contains($0.type) }
        let advisory = seen.filter { !blocking.contains($0) }
        return Self(blocking: blocking, advisory: advisory, skip: nil)
    }

    public static func skipped(message: String?) -> Self {
        let quota = message == quotaHint
        return Self(blocking: [], advisory: [], skip: quota ? .quota : .unavailable)
    }

    /// The publish step continues on its own when nothing blocks (the MP publishes directly in that case).
    public var allowsPublish: Bool { blocking.isEmpty }
    /// Passed = the AI read the copy and reported nothing; a skip is never "passed".
    public var passed: Bool { skip == nil && blocking.isEmpty && advisory.isEmpty }
}

/// Runs one precheck through the approved `.publishingAISafety` auxiliary service. Every path that does not end in a
/// read server answer degrades to a skip (MP: 降级放行), so the caller can always continue to the publish step.
@MainActor public final class AISafetyPrecheckRunner {
    private let service: PublishingAuxiliaryService
    private let session: () -> PublishingSession?
    private var running = false

    public init(service: PublishingAuxiliaryService, session: @escaping () -> PublishingSession?) {
        self.service = service
        self.session = session
    }

    /// MP `_prechecking`: a second tap while one runs does not burn another AI call; it reads as a skip.
    public func run(_ fields: [String: ProjectEditJSON]) async -> AISafetyPrecheckVerdict {
        guard !running, AISafetyPrecheckRequest.validates(fields), let account = session() else { return .skipped(message: nil) }
        running = true
        defer { running = false }
        let review: PublishingAuxiliaryReview
        do {
            review = try service.prepare(.safety(fields), session: account)
        } catch {
            return .skipped(message: nil)
        }
        let outcome = await service.confirm(review)
        return Self.verdict(outcome)
    }

    public static func verdict(_ outcome: PublishingAuxiliaryOutcome) -> AISafetyPrecheckVerdict {
        switch outcome {
        case .acknowledged(let data):
            guard let issues = try? PublishingSafetyIssue.decode(data) else { return .skipped(message: nil) }
            return .issues(issues)
        case .unavailable(let message), .rejected(let message):
            return .skipped(message: message)
        case .notSent, .unknown:
            return .skipped(message: nil)
        }
    }
}
