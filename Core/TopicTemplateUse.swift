import Foundation

// MARK: - "Use this topic template" (injected writer, gated by default)
// Request shape matches pages/templatedetail/topic-detail/index.js `useTemplate` + utils/topic-adoption.js `usePayload`:
// POST /api/template/topic-template/use { id, scope?, bindingIntent?, sourceContentRevisionId?, requestId }
// -> data.topicId (a fresh draft copy) plus the B2 increment (bindingIssues, pendingRebindSlotKeys, source ids).
// The backend copies the whole template on every new requestId, so a second tap while one is in flight is dropped,
// an unknown result keeps the same requestId (the server replays the original receipt), and a confirmed copy
// is reopened instead of copied again (mini k9 / p3 N6).

public struct TopicTemplateUseRequest: Equatable {
    public let path: String
    public let body: [String: PlayWireValue]

    public init(id: Int, scope: String?, bindingIntent: TopicTemplateBindingIntent? = nil,
                sourceContentRevisionId: String? = nil, requestId: String? = nil) {
        path = "/api/template/topic-template/use"
        var fields: [String: PlayWireValue] = ["id": .int(id)]
        if let scope, !scope.isEmpty { fields["scope"] = .string(scope) }
        if let bindingIntent { fields["bindingIntent"] = .string(bindingIntent.rawValue) }
        if let sourceContentRevisionId, !sourceContentRevisionId.isEmpty { fields["sourceContentRevisionId"] = .string(sourceContentRevisionId) }
        if let requestId, AuthorWriteRequestID.isValid(requestId) { fields["requestId"] = .string(requestId) }
        body = fields
    }

    /// Form fields for the multipart POST (the controller reads plain request params).
    public var formFields: [String: String] {
        body.compactMapValues { value in
            switch value {
            case .integer(let number): return String(number)
            case .string(let text): return text
            default: return nil
            }
        }
    }
}

public enum TopicTemplateUseOutcome: Equatable {
    /// Server code 200 with `data.topicId`.
    case copied(TopicTemplateUseReceipt)
    /// Definite server refusal; message shown verbatim.
    case failed(message: String)
    /// Timeout, transport loss, 5xx or an unreadable 200: the copy may exist. Retry with the same requestId.
    case unknown
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
    case copied(TopicTemplateUseReceipt)
    case failed(String)
    /// Result not confirmed. The next tap re-asks with the same requestId; it never mints a new one.
    case unknown
    case unavailable
    case readOnly
}

@MainActor public final class TopicTemplateUseModel: ObservableObject {
    public struct OpenRequest: Equatable {
        public let topicId: Int
        public let sequence: Int
    }
    @Published public private(set) var state: TopicTemplateUseState = .idle
    /// Bumped on every confirmed copy and on every reopen of that copy; the host navigates on change.
    @Published public private(set) var openRequest: OpenRequest?
    /// The requestId of the attempt whose result is not yet confirmed.
    public private(set) var pendingRequestId: String?
    private let writer: TopicTemplateUsing
    private let readOnly: Bool
    private let makeRequestId: () -> String

    public init(writer: TopicTemplateUsing, readOnly: Bool,
                makeRequestId: @escaping () -> String = { AuthorWriteRequestID.make(prefix: "tpluse") }) {
        self.writer = writer
        self.readOnly = readOnly
        self.makeRequestId = makeRequestId
    }

    public var copiedReceipt: TopicTemplateUseReceipt? {
        if case .copied(let receipt) = state { return receipt }
        return nil
    }

    public func use(id: Int, scope: String?, plan: TopicTemplateAdoptionPlan? = nil) async {
        guard state != .using else { return }
        guard !readOnly else { state = .readOnly; return }
        guard id > 0 else { state = .failed(W8Text.t("模板编号无效", "Invalid template")); return }
        if let receipt = copiedReceipt { open(receipt.topicId); return }
        let requestId = pendingRequestId ?? makeRequestId()
        pendingRequestId = requestId
        state = .using
        let request = TopicTemplateUseRequest(id: id, scope: scope, bindingIntent: plan?.bindingIntent,
                                              sourceContentRevisionId: plan?.sourceContentRevisionId, requestId: requestId)
        switch await writer.use(request) {
        case .copied(let receipt):
            pendingRequestId = nil
            state = .copied(receipt)
            open(receipt.topicId)
        case .failed(let message):
            // A refused first attempt is rolled back server-side; a later tap is a new attempt.
            pendingRequestId = nil
            state = .failed(message.isEmpty ? W8Text.t("使用模板失败", "Could not use this template") : message)
        case .unknown:
            state = .unknown
        case .unavailable:
            pendingRequestId = nil
            state = .unavailable
        }
    }

    private func open(_ topicId: Int) {
        openRequest = OpenRequest(topicId: topicId, sequence: (openRequest?.sequence ?? 0) + 1)
    }

    public static func message(for state: TopicTemplateUseState) -> String? {
        switch state {
        case .idle, .using: return nil
        case .copied(let receipt):
            var parts = [W8Text.t("已复制为你的草稿", "Copied to your drafts")]
            if receipt.blockingCount > 0 {
                parts.append(W8Text.t("\(receipt.blockingCount) 个地点需重新确认后才能发布", receipt.blockingCount == 1 ? "1 place must be reconfirmed before publishing" : "\(receipt.blockingCount) places must be reconfirmed before publishing"))
            } else if !receipt.pendingRebindSlotKeys.isEmpty {
                parts.append(W8Text.t("\(receipt.pendingRebindSlotKeys.count) 个地点待确认", receipt.pendingRebindSlotKeys.count == 1 ? "1 place to confirm" : "\(receipt.pendingRebindSlotKeys.count) places to confirm"))
            } else if receipt.warningCount > 0 {
                parts.append(W8Text.t("\(receipt.warningCount) 个地点建议复核", receipt.warningCount == 1 ? "1 place worth reviewing" : "\(receipt.warningCount) places worth reviewing"))
            }
            return parts.joined(separator: " · ")
        case .failed(let message): return message
        case .unknown:
            return W8Text.t("结果未确认：可能已经复制。再点一次会查询这次操作的结果，不会多复制一份。",
                            "Result not confirmed: the copy may already exist. Tap again to check this same request; it won't make a second copy.")
        case .unavailable: return W8Text.t("暂未开放：此版本暂时无法直接使用模板，请在城瘾小程序中操作。", "Not available yet: using a template isn't supported in this version.")
        case .readOnly: return W8Text.t("当前岗位仅可浏览模板", "Your role can only browse templates")
        }
    }
}
