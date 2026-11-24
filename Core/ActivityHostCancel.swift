import Foundation
import CoreFoundation

/// Port of `scene-play-activity-detail` openCancel / submitCancel: the host previews how many paid players
/// would be refunded (`/api/activity/cancel_preview`), writes a reason (<=100 chars, shown to registrants),
/// confirms once, then `/api/activity/cancel` refunds every unredeemed registration and takes the event down.
public enum ActivityHostCancelRules {
    public static let reasonLimit = 100
    public static func trimmedReason(_ raw: String) -> String { raw.trimmingCharacters(in: .whitespacesAndNewlines) }
    public static func canSubmit(reason: String, paidPlayers: Int?) -> Bool {
        let r = trimmedReason(reason)
        return !r.isEmpty && r.count <= reasonLimit && (paidPlayers ?? -1) >= 0
    }
    /// `noticeCancelled`: the mini-program shows the server's `msg` (which carries the "N orders contain verified
    /// tickets and cannot be refunded automatically" warning) in an acknowledge-only modal. Returns that text, or nil
    /// when the server sent none so the caller shows its own default copy.
    public static func completionNotice(serverMessage: String?) -> String? {
        guard let text = serverMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
    /// Mini-program `isOwner`: the activity's member id equals the signed-in user id.
    public static func isHost(hostMemberID: Int?, accountID: Int?) -> Bool {
        guard let hostMemberID, let accountID, hostMemberID > 0 else { return false }
        return hostMemberID == accountID
    }
}
public enum ActivityHostCancelPreview: Equatable {
    case paidPlayers(Int)
    /// Server refused (no permission, already cancelled ...). Only a message and "check again".
    case blocked(String?)
    /// Preview answered 200 without a usable integer count.
    case unknownCount

    /// Display for the preview count. A missing, blocked, or negative count is an em dash.
    /// Zero stays zero. This does not invent a refund total.
    public var paidPlayerCountText: String {
        if case .paidPlayers(let count) = self, count >= 0 { return String(count) }
        return ActivityDetailPageModel.unknownDisplay
    }
}
public enum ActivityHostCancelOutcome: Equatable { case cancelled(String?), rejected(String?) }
/// `scope` request field of `/api/activity/cancel_preview` and `/api/activity/cancel`. The merchant host flow
/// (`subpackageA/pages/myproject`) sends `'MERCHANT'`; the club-host flow (`scene-play-activity-detail`) sends no scope.
public enum ActivityHostCancelScope: String, Equatable { case merchant = "MERCHANT" }
public enum ActivityHostCancelFailure: Error, Equatable { case disabled, invalid, network, unauthorized }

@MainActor public protocol ActivityHostCancelAccess: AnyObject {
    var enabled: Bool { get }
    var accountID: Int? { get }
    func preview(activityID: Int) async throws -> ActivityHostCancelPreview
    func cancel(activityID: Int, reason: String) async throws -> ActivityHostCancelOutcome
}

@MainActor public final class ActivityHostCancelHTTPAccess: ActivityHostCancelAccess {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let session: @MainActor () -> (accountID: Int, token: String)?
    private let isEnabled: @MainActor () -> Bool
    /// Opt-in merchant scope. nil (default) = club-host flow, no `scope` field, exactly like `scene-play-activity-detail`.
    public var operationScope: ActivityHostCancelScope?
    public var enabled: Bool { isEnabled() }
    public var accountID: Int? { session()?.accountID }
    public init(configuration: APIConfiguration, transport: any HTTPTransport, enabled: @escaping @MainActor () -> Bool,
                session: @escaping @MainActor () -> (accountID: Int, token: String)?) {
        self.configuration = configuration; self.transport = transport; self.isEnabled = enabled; self.session = session
    }
    private func post(_ path: String, _ body: [String: Any]) async throws -> (code: Int, msg: String?, data: Any?) {
        guard enabled else { throw ActivityHostCancelFailure.disabled }
        var body = body
        if let operationScope { body["scope"] = operationScope.rawValue }
        guard let token = session()?.token, AuthRequestBuilder.isValidToken(token) else { throw ActivityHostCancelFailure.unauthorized }
        var r = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        r.httpMethod = "POST"; r.timeoutInterval = 20; r.cachePolicy = .reloadIgnoringLocalCacheData
        r.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        r.setValue(token, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data, status: Int
        do { (data, status) = try await transport.send(r) } catch is CancellationError { throw CancellationError() }
        catch { throw ActivityHostCancelFailure.network }
        guard (200..<300).contains(status), let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = MoneyHostCancelParity.responseCode(o["code"]) else { throw ActivityHostCancelFailure.network }
        return (code, o["msg"] as? String, o["data"])
    }
    public func preview(activityID: Int) async throws -> ActivityHostCancelPreview {
        guard activityID > 0 else { throw ActivityHostCancelFailure.invalid }
        let r = try await post("api/activity/cancel_preview", ["id": activityID])
        guard r.code == 200 else { return .blocked(r.msg) }
        if let count = MoneyHostCancelParity.paidPlayers((r.data as? [String: Any])?["paidPlayers"]) { return .paidPlayers(count) }
        return .unknownCount
    }
    public func cancel(activityID: Int, reason: String) async throws -> ActivityHostCancelOutcome {
        let text = ActivityHostCancelRules.trimmedReason(reason)
        guard activityID > 0, !text.isEmpty, text.count <= ActivityHostCancelRules.reasonLimit else { throw ActivityHostCancelFailure.invalid }
        // Host-cancel refunds are money. Off unless a TEST derivation opens this kind. Preview stays a read.
        guard ReleaseMoneyWriteSwitch.isEnabled(.hostCancelRefund) else { throw ActivityHostCancelFailure.disabled }
        let r = try await post("api/activity/cancel", ["id": activityID, "reason": text])
        return r.code == 200 ? .cancelled(r.msg) : .rejected(r.msg)
    }
}
