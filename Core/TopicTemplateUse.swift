import Foundation

// MARK: - "Use this topic template" (injected writer, gated by default)
// Request shape matches pages/templatedetail/topic-detail/index.js `useTemplate`:
// POST /api/template/topic-template/use { id, scope? } -> data.topicId (a fresh draft copy).
// The backend copies the whole template on every call, so a second tap while one is in flight is dropped.

public struct TopicTemplateUseRequest: Equatable {
    public let path: String
    public let body: [String: PlayWireValue]

    public init(id: Int, scope: String?) {
        path = "/api/template/topic-template/use"
        var fields: [String: PlayWireValue] = ["id": .int(id)]
        if let scope, !scope.isEmpty { fields["scope"] = .string(scope) }
        body = fields
    }
}

public enum TopicTemplateUseOutcome: Equatable {
    /// Server code 200 with `data.topicId`.
    case copied(topicId: Int)
    case failed(message: String)
    /// No write route or grant in this build.
    case unavailable
}

@MainActor public protocol TopicTemplateUsing {
    func use(_ request: TopicTemplateUseRequest) async -> TopicTemplateUseOutcome
}

public struct GatedTopicTemplateUser: TopicTemplateUsing {
    public init() {}
    public func use(_ request: TopicTemplateUseRequest) async -> TopicTemplateUseOutcome { .unavailable }
}

public enum TopicTemplateUseState: Equatable {
    case idle
    case using
    case copied(topicId: Int)
    case failed(String)
    case unavailable
    case readOnly
}

@MainActor public final class TopicTemplateUseModel: ObservableObject {
    @Published public private(set) var state: TopicTemplateUseState = .idle
    private let writer: TopicTemplateUsing
    private let readOnly: Bool

    public init(writer: TopicTemplateUsing, readOnly: Bool) {
        self.writer = writer
        self.readOnly = readOnly
    }

    public func use(id: Int, scope: String?) async {
        guard state != .using else { return }
        guard !readOnly else { state = .readOnly; return }
        guard id > 0 else { state = .failed(W8Text.t("模板编号无效", "Invalid template")); return }
        state = .using
        switch await writer.use(TopicTemplateUseRequest(id: id, scope: scope)) {
        case .copied(let topicId):
            state = topicId > 0 ? .copied(topicId: topicId) : .failed(W8Text.t("使用模板失败", "Could not use this template"))
        case .failed(let message):
            state = .failed(message.isEmpty ? W8Text.t("使用模板失败", "Could not use this template") : message)
        case .unavailable:
            state = .unavailable
        }
    }

    public static func message(for state: TopicTemplateUseState) -> String? {
        switch state {
        case .idle, .using, .copied: return nil
        case .failed(let message): return message
        case .unavailable: return W8Text.t("暂未开放：此版本暂时无法直接使用模板，请在城瘾小程序中操作。", "Not available yet: using a template isn't supported in this version.")
        case .readOnly: return W8Text.t("当前岗位仅可浏览模板", "Your role can only browse templates")
        }
    }
}
