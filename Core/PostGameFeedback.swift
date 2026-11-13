import Foundation

// §九 U08-02 post-game problem feedback: `POST /api/play/feedback/submit`
// (hengyin `ApiPlayFeedbackController` + `PlayRunFeedbackService`, integration/backend-app-20261112).
// JSON {runId, nodeId?, category, content, requestId}. The server reads the run as the caller's own and traces topic,
// activity, frozen config version and content revision from the run, never from the client.
// Same requestId + same content replays the original receipt; different content is 409.
// It is not a content report: no review queue, no visibility change.
// The mini-program has no caller yet; the App puts it in the battle report container (MP-19 / §25.2 "报告问题").

public enum PostGameFeedbackCategory: String, CaseIterable, Equatable, Sendable {
    case place = "PLACE"
    case question = "QUESTION"
    case other = "OTHER"
}

public struct PostGameFeedbackDraft: Equatable, Sendable {
    public static let maxContent = 500

    public let runID: String
    /// Nil: not tied to one stop. Must belong to the run's topic (server checks).
    public let nodeID: String?
    public let category: PostGameFeedbackCategory
    public let content: String

    public init(runID: String, nodeID: String?, category: PostGameFeedbackCategory, content: String) {
        self.runID = runID
        self.nodeID = nodeID
        self.category = category
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public enum Problem: Equatable, Sendable { case noRun, empty, tooLong, badNode }

    /// Server limits: content counted in code points, 1...500.
    public var problem: Problem? {
        guard JourneyLoopSource.isID(runID) else { return .noRun }
        if let nodeID, !JourneyLoopSource.isID(nodeID) { return .badNode }
        if content.isEmpty { return .empty }
        if content.unicodeScalars.count > Self.maxContent { return .tooLong }
        return nil
    }

    func body(requestID: String) -> [String: String] {
        var body = ["runId": runID, "category": category.rawValue, "content": content, "requestId": requestID]
        if let nodeID { body["nodeId"] = nodeID }
        return body
    }
}

public struct PostGameFeedbackReceipt: Equatable, Sendable {
    public let feedbackID: String
    public let runID: String?
    public let nodeID: String?
    public let category: String?
    /// Nil when the run's frozen snapshot matched no stored revision (unknown, not "none").
    public let contentRevisionID: String?
    /// True when the server returned the original receipt for a retried request id.
    public let replayed: Bool
}

public enum PostGameFeedbackOutcome: Equatable, Sendable {
    /// `state == RECEIVED` with a feedback id. Only this is shown as sent.
    case received(PostGameFeedbackReceipt)
    /// Timeout, transport failure, 5xx or an unreadable 2xx. The request id stays; only the same request is re-sent.
    case unconfirmed
    /// A finished refusal (4xx business code): 401 sign in, 404 not this player's run, 409 request id reused with other text.
    case refused(code: String?, message: String?)

    public static func classify(_ envelope: JourneyEnvelope) -> PostGameFeedbackOutcome {
        if envelope.unconfirmed { return .unconfirmed }
        guard envelope.ok else { return .refused(code: envelope.code, message: envelope.message) }
        guard let object = PostGameJSON.object(envelope.dataJSON),
              PostGameJSON.string(object["state"]) == "RECEIVED",
              let id = PostGameJSON.id(object["feedbackId"]) else { return .unconfirmed }
        return .received(PostGameFeedbackReceipt(
            feedbackID: id, runID: PostGameJSON.id(object["runId"]), nodeID: PostGameJSON.id(object["nodeId"]),
            category: PostGameJSON.string(object["category"]), contentRevisionID: PostGameJSON.id(object["contentRevisionId"]),
            replayed: (object["replayed"] as? Bool) == true))
    }
}
