import Foundation

/// fix/1128c-ai-showcase (planning audit H-08a): "Fill template with AI" for club hosts, `POST api/ai/template/fill`
/// JSON `{shopName, extraNote, category?, reward?, playStyle?}` (backend `AiTemplateFillReq`, the non-merchant path:
/// no `merchantFacts` / `merchantConstraints`). The answer `{traceId, template: AiTemplateContent}` is a suggestion
/// the host reviews; it fills only the 互动 template editor's copy fields and never sends anything by itself.
public struct AITemplateFillRequest: Equatable, Sendable {
    public var venue: String
    public var idea: String
    public var category: String
    public var reward: String
    public var playStyle: String

    public init(venue: String = "", idea: String = "", category: String = "", reward: String = "", playStyle: String = "") {
        self.venue = venue
        self.idea = idea
        self.category = category
        self.reward = reward
        self.playStyle = playStyle
    }

    /// The backend refuses an empty 店名 (`请先填写店名`); the AI also needs the idea.
    public var isComplete: Bool {
        !venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var assistance: PublishingAssistance {
        func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
        return .template(shopName: trimmed(venue), extraNote: trimmed(idea), category: trimmed(category),
                         reward: trimmed(reward), playStyle: trimmed(playStyle), validationMethod: nil)
    }
}

public struct AITemplateFillRow: Identifiable, Equatable, Sendable {
    public let key: String
    public let value: String
    public var id: String { key }
}

/// The reviewed suggestion. Only non-empty text fields are kept; nothing else of the answer reaches the editor.
public struct AITemplateFillSuggestion: Equatable, Sendable {
    public static let fields = ["title", "description", "ruleInstructions", "questionName", "questionAnswer",
                                "hint1", "hint2", "storyText", "feedbackText", "medalName"]
    public let traceID: String?
    public let values: [String: String]

    public init(values: [String: String], traceID: String? = nil) {
        self.values = values
        self.traceID = traceID
    }

    public init(_ data: ProjectEditJSON) throws {
        let result = try MerchantTemplateAssistResult(data)
        var kept: [String: String] = [:]
        for key in Self.fields {
            if let value = result.text(key) { kept[key] = value }
        }
        guard !kept.isEmpty else { throw MerchantTemplateAssistFailure.malformed }
        values = kept
        traceID = data.object?["traceId"]?.text
    }

    /// Ordered rows for the review list.
    public var rows: [AITemplateFillRow] {
        Self.fields.compactMap { key in values[key].map { AITemplateFillRow(key: key, value: $0) } }
    }

    /// Fills the editor copy; fields the AI left empty keep the host's text.
    public func applied(to draft: TemplateAuthoringDraft) -> TemplateAuthoringDraft {
        var next = draft
        if let value = values["title"] { next.title = value }
        if let value = values["description"] { next.description = value }
        if let value = values["ruleInstructions"] { next.ruleInstructions = value }
        if let value = values["questionName"] { next.questionName = value }
        if let value = values["questionAnswer"] { next.questionAnswer = value }
        if let value = values["hint1"] { next.hint1 = value }
        if let value = values["hint2"] { next.hint2 = value }
        if let value = values["storyText"] { next.storyText = value }
        if let value = values["feedbackText"] { next.feedbackText = value }
        if let value = values["medalName"] { next.medalName = value }
        return next
    }
}

@MainActor public final class AITemplateFillRunner {
    public enum Outcome: Equatable {
        case suggestion(AITemplateFillSuggestion)
        /// The server's own words (quota, role gate, provider message).
        case refused(String)
        /// Not sent, or no readable answer: the host can try again.
        case failed
    }
    private let service: PublishingAuxiliaryService
    private let session: () -> PublishingSession?

    public init(service: PublishingAuxiliaryService, session: @escaping () -> PublishingSession?) {
        self.service = service
        self.session = session
    }

    public var isConfigured: Bool { service.templateConfigured }

    public func run(_ request: AITemplateFillRequest) async -> Outcome {
        guard request.isComplete, let account = session() else { return .failed }
        let review: PublishingAuxiliaryReview
        do {
            review = try service.prepare(request.assistance, session: account)
        } catch {
            return .failed
        }
        return Self.outcome(await service.confirm(review))
    }

    public func cancel() { service.invalidate() }

    public static func outcome(_ outcome: PublishingAuxiliaryOutcome) -> Outcome {
        switch outcome {
        case .acknowledged(let data):
            guard let suggestion = try? AITemplateFillSuggestion(data) else { return .failed }
            return .suggestion(suggestion)
        case .rejected(let message), .unavailable(let message):
            let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? .failed : .refused(text)
        case .notSent, .unknown:
            return .failed
        }
    }
}
