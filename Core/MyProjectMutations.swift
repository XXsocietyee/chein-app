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
    /// POST `api/activity/cancel_preview` `{id, scope}`. Nil means the confirm must not open.
    func previewActivityCancel(id: Int, scope: String) async -> Int?
}

public extension MyProjectMutating {
    func previewActivityCancel(id: Int, scope: String) async -> Int? { nil }
}

public struct GatedMyProjectMutator: MyProjectMutating {
    public init() {}
    public func perform(_ request: MyProjectMutationRequest) async -> MyProjectMutationOutcome { .unavailable }
}

/// Live HTTP mutator for my-project list actions (`subpackageA/pages/myproject/index.js`).
/// Canceling an activity triggers automatic refunds on the backend and is gated behind `allowsCancelActivity`.
public struct MyProjectHTTPMutator: MyProjectMutating {
    private let configuration: @Sendable () async -> APIConfiguration?
    private let transport: any HTTPTransport
    private let tokenProvider: @Sendable () async -> String?
    private let allowsCancelActivity: @Sendable () async -> Bool

    public init(
        configuration: @escaping @Sendable () async -> APIConfiguration?,
        transport: any HTTPTransport,
        tokenProvider: @escaping @Sendable () async -> String?,
        allowsCancelActivity: @escaping @Sendable () async -> Bool = { true }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.allowsCancelActivity = allowsCancelActivity
    }

    public func perform(_ request: MyProjectMutationRequest) async -> MyProjectMutationOutcome {
        let relativePath = request.path.hasPrefix("/") ? String(request.path.dropFirst()) : request.path
        if relativePath == "api/activity/cancel" {
            guard await allowsCancelActivity(), ReleaseMoneyWriteSwitch.isEnabled(.hostCancelRefund) else {
                return .unavailable
            }
        }
        guard let config = await configuration(), let rawToken = await tokenProvider() else {
            return .unavailable
        }
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return .unavailable }

        var fields: [String: String] = [:]
        for (key, value) in request.body {
            // Backend ApiTemplateController#updateLibraryStatus expects `status` (`1` = publish, `3` = unpublish).
            if relativePath == "api/template/updateLibraryStatus", key == "publish_status",
               let statusInt = value.tolerantInteger {
                fields["status"] = statusInt == 1 ? "1" : "3"
                continue
            }
            if let text = value.text {
                fields[key] = text
            } else if let integer = value.tolerantInteger {
                fields[key] = String(integer)
            } else if let bool = value.bool {
                fields[key] = bool ? "true" : "false"
            }
        }

        let urlRequest: URLRequest
        do {
            urlRequest = try AuthRequestBuilder.makeFormRequest(
                url: config.baseURL.appendingPathComponent(relativePath),
                fields: fields,
                token: token
            )
        } catch {
            return .unavailable
        }

        do {
            let (data, httpStatus) = try await transport.send(urlRequest)
            guard let root = try? JSONDecoder().decode(PlayWireValue.self, from: data) else {
                return .failed(message: W8Text.t("操作失败，请稍后重试", "Action failed. Please try again."))
            }
            let code = root["code"].tolerantInteger
            let msg = root["msg"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
            if (200...299).contains(httpStatus), code == 200 {
                return .done
            }
            let cleanMsg = msg?.isEmpty == false ? msg! : nil
            return .failed(message: cleanMsg ?? W8Text.t("操作失败，请稍后重试", "Action failed. Please try again."))
        } catch {
            return .failed(message: W8Text.t("网络异常，请重试", "Network error. Please retry."))
        }
    }

    /// Form body, matching myproject `paidPlayersOrToast`. A non-200 or a non-integer count returns nil.
    public func previewActivityCancel(id: Int, scope: String) async -> Int? {
        guard id > 0, let config = await configuration(), let rawToken = await tokenProvider() else { return nil }
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return nil }
        let request: URLRequest
        do {
            request = try AuthRequestBuilder.makeFormRequest(
                url: config.baseURL.appendingPathComponent("api/activity/cancel_preview"),
                fields: ["id": String(id), "scope": scope],
                token: token
            )
        } catch { return nil }
        do {
            let (data, httpStatus) = try await transport.send(request)
            guard (200...299).contains(httpStatus),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (root["code"] as? Int) == 200,
                  let payload = root["data"] as? [String: Any] else { return nil }
            if let count = payload["paidPlayers"] as? Int, count >= 0 { return count }
            if let count = payload["paidPlayers"] as? String, let value = Int(count), value >= 0 { return value }
            return nil
        } catch { return nil }
    }
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
    /// Refund count copy from `cancel_preview`. The generic `confirmationMessage` stays for other actions.
    @Published public private(set) var confirmationText: String?
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
        confirmationText = nil
        if mutation.needsConfirmation {
            state = .awaitingConfirmation(mutation)
        } else {
            await send(mutation)
        }
    }

    /// myproject cancel: preview paid players first. A missing count does not open confirm and does not cancel.
    public func beginActivityCancel(id: Int, title: String) async {
        if case .working = state { return }
        let mutation = MyProjectMutation.cancelActivity(id: id)
        guard let count = await writer.previewActivityCancel(id: id, scope: scope), count >= 0 else {
            confirmationText = nil
            state = .failed(mutation, W8Text.t("暂时算不出退款人数，请稍后重试", "The refund count isn't available yet. Try again."))
            return
        }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "这场活动" : name
        confirmationText = W8Text.t(
            "确定取消「\(label)」吗？将给 \(count) 位已付款玩家全额退款。此操作不可撤销。",
            "Cancel “\(label)”? \(count) paid players will be refunded in full. This can't be undone."
        )
        state = .awaitingConfirmation(mutation)
    }

    public func confirm() async {
        guard case .awaitingConfirmation(let mutation) = state else { return }
        await send(mutation)
    }

    public func dismiss() {
        if case .working = state { return }
        confirmationText = nil
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
