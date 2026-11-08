import Foundation

// MARK: - My-project list mutations (injected writer, gated by default)
// Request shapes match subpackageA/pages/myproject/index.js:
//   toggle topic     POST /api/topic/update_user_status      { id, scope, expectedUserStatus }
//   toggle activity  POST /api/activity/update_publish_status { id, scope }
//   cancel activity  POST /api/activity/cancel               { id, reason, scope }
//   delete topic     POST /api/topic/delete                  { id, scope }
//   delete activity  POST /api/activity/delete               { id, scope }
//   delete template  POST /api/template/delete               { template_id, scope }
//   template library POST /api/template/updateLibraryStatus  { template_id, publish_status, scope }
// Topic cancellation needs a refund preview plus a persisted cancellation epoch in the mini; it is not
// modelled here and stays unavailable. Destructive actions need an explicit confirm step first, and the
// list may only be refreshed (never edited locally) after the server says done.

public enum MyProjectBiz: String, Equatable, Sendable { case topic, activity }

public enum MyProjectMutation: Equatable, Hashable {
    case toggleOnline(biz: MyProjectBiz, id: Int, currentlyOnline: Bool)
    case cancelActivity(id: Int)
    case delete(biz: MyProjectBiz, id: Int)
    case deleteTemplate(id: Int)
    case setTemplateLibrary(id: Int, published: Bool)

    /// Destructive actions go through the confirm step; plain toggles run immediately like the mini.
    public var needsConfirmation: Bool {
        switch self {
        case .cancelActivity, .delete, .deleteTemplate: return true
        case .toggleOnline, .setTemplateLibrary: return false
        }
    }

    public var confirmationMessage: String? {
        switch self {
        case .cancelActivity: return W8Text.t("确定取消这场活动吗？此操作不可撤销。", "Cancel this activity? This can't be undone.")
        case .delete: return W8Text.t("确定删除吗？此操作不可撤销，也可以改为下架。", "Delete this item? This can't be undone. You can take it offline instead.")
        case .deleteTemplate: return W8Text.t("确定删除这个模板吗？此操作不可撤销。", "Delete this template? This can't be undone.")
        case .toggleOnline, .setTemplateLibrary: return nil
        }
    }
}

public struct MyProjectMutationRequest: Equatable {
    public let path: String
    public let body: [String: PlayWireValue]
}

public enum MyProjectMutationBuilder {
    public static func request(for mutation: MyProjectMutation, scope: String) -> MyProjectMutationRequest {
        let scopeValue = PlayWireValue.string(scope)
        switch mutation {
        case .toggleOnline(let biz, let id, let online):
            if biz == .activity {
                return .init(path: "/api/activity/update_publish_status", body: ["id": .int(id), "scope": scopeValue])
            }
            return .init(path: "/api/topic/update_user_status",
                         body: ["id": .int(id), "scope": scopeValue, "expectedUserStatus": .int(online ? 1 : 0)])
        case .cancelActivity(let id):
            return .init(path: "/api/activity/cancel", body: ["id": .int(id), "reason": .string("主办方取消活动"), "scope": scopeValue])
        case .delete(let biz, let id):
            return .init(path: biz == .activity ? "/api/activity/delete" : "/api/topic/delete", body: ["id": .int(id), "scope": scopeValue])
        case .deleteTemplate(let id):
            return .init(path: "/api/template/delete", body: ["template_id": .int(id), "scope": scopeValue])
        case .setTemplateLibrary(let id, let published):
            return .init(path: "/api/template/updateLibraryStatus",
                         body: ["template_id": .int(id), "publish_status": .int(published ? 1 : 0), "scope": scopeValue])
        }
    }
}

public enum MyProjectMutationOutcome: Equatable {
    case done
    case failed(message: String)
    case unavailable
}

@MainActor public protocol MyProjectMutating {
    func perform(_ request: MyProjectMutationRequest) async -> MyProjectMutationOutcome
}

public struct GatedMyProjectMutator: MyProjectMutating {
    public init() {}
    public func perform(_ request: MyProjectMutationRequest) async -> MyProjectMutationOutcome { .unavailable }
}

public enum MyProjectMutationState: Equatable {
    case idle
    case awaitingConfirmation(MyProjectMutation)
    case working(MyProjectMutation)
    case done(MyProjectMutation)
    case failed(MyProjectMutation, String)
    case unavailable(MyProjectMutation)
}

@MainActor public final class MyProjectMutationModel: ObservableObject {
    @Published public private(set) var state: MyProjectMutationState = .idle
    /// Bumps after every server-confirmed mutation; the host re-reads the list when it changes.
    @Published public private(set) var reloadToken = 0
    private let writer: MyProjectMutating
    private let scope: String

    public init(writer: MyProjectMutating, scope: String) {
        self.writer = writer
        self.scope = scope
    }

    /// Starts an action: destructive ones wait for `confirm()`, plain toggles are sent now.
    public func begin(_ mutation: MyProjectMutation) async {
        if case .working = state { return }
        if mutation.needsConfirmation {
            state = .awaitingConfirmation(mutation)
        } else {
            await send(mutation)
        }
    }

    public func confirm() async {
        guard case .awaitingConfirmation(let mutation) = state else { return }
        await send(mutation)
    }

    public func dismiss() {
        if case .working = state { return }
        state = .idle
    }

    private func send(_ mutation: MyProjectMutation) async {
        state = .working(mutation)
        switch await writer.perform(MyProjectMutationBuilder.request(for: mutation, scope: scope)) {
        case .done:
            state = .done(mutation)
            reloadToken += 1
        case .failed(let message):
            state = .failed(mutation, message.isEmpty ? W8Text.t("操作失败", "The action failed") : message)
        case .unavailable:
            state = .unavailable(mutation)
        }
    }
}
