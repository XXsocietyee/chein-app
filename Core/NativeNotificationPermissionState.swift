import Foundation
import Observation

public enum NativeNotificationPermissionAuthorization: Equatable {
    case notDetermined, denied, authorized, provisional, ephemeral, unknown(Int)
    public var label: String {
        switch self {
        case .notDetermined: return W8Text.t("尚未选择", "Not chosen yet")
        case .denied: return W8Text.t("系统通知已关闭", "Notifications are off in Settings")
        case .authorized: return W8Text.t("系统允许通知", "Notifications are allowed")
        case .provisional: return W8Text.t("允许安静送达", "Quiet delivery allowed")
        case .ephemeral: return W8Text.t("临时授权", "Temporary authorization")
        case .unknown: return W8Text.t("系统权限状态未知", "Notification permission status unknown")
        }
    }
}
public enum NativeNotificationPermissionSetting: Equatable { case enabled, disabled, unsupported, unknown(Int) }
public struct NativeNotificationPermissionSnapshot: Equatable {
    public let authorization: NativeNotificationPermissionAuthorization
    public let alerts: NativeNotificationPermissionSetting
    public let sounds: NativeNotificationPermissionSetting
    public let badges: NativeNotificationPermissionSetting
    public init(authorization: NativeNotificationPermissionAuthorization, alerts: NativeNotificationPermissionSetting,
                sounds: NativeNotificationPermissionSetting, badges: NativeNotificationPermissionSetting) {
        self.authorization = authorization; self.alerts = alerts; self.sounds = sounds; self.badges = badges
    }
}
@MainActor public protocol NativeNotificationPermissionProviding: AnyObject {
    func read() async throws -> NativeNotificationPermissionSnapshot
    func requestFromUserAction() async throws
    func openSettingsFromUserAction() async throws
}

/// OS authorization never writes service preferences or device bindings.
@MainActor @Observable public final class NativeNotificationPermissionState {
    private let provider: any NativeNotificationPermissionProviding
    private var generation: UInt64 = 0
    private var pendingRefresh: UInt64?
    @ObservationIgnored private var deferredRefresh: Task<Void, Never>?
    /// Capture when queuing a view gesture; a retired destination cannot authorize it.
    public var revision: UInt64 { generation }
    public private(set) var snapshot: NativeNotificationPermissionSnapshot?
    public private(set) var busy = false
    public private(set) var issue: String?
    public init(provider: any NativeNotificationPermissionProviding) { self.provider = provider }
    public func retire() {
        generation &+= 1; pendingRefresh = nil; deferredRefresh?.cancel(); deferredRefresh = nil
        snapshot = nil; issue = nil
        // Keep the physical OS operation serialized until it returns. A new
        // destination may queue its own read, but cannot race another prompt.
    }
    private func accepts(_ expectedRevision: UInt64?) -> Bool {
        !Task.isCancelled && (expectedRevision == nil || expectedRevision == generation)
    }
    private func complete() {
        busy = false
        guard let requested = pendingRefresh else { return }
        pendingRefresh = nil
        guard requested == generation else { return }
        deferredRefresh = Task { [weak self] in await self?.refresh(expectedRevision: requested) }
    }
    public func refresh(expectedRevision: UInt64? = nil) async {
        guard accepts(expectedRevision) else { return }
        if busy { pendingRefresh = generation; return }
        let ticket = generation; busy = true
        defer { complete() }
        do {
            let value = try await provider.read()
            guard ticket == generation, !Task.isCancelled else { return }
            snapshot = value; issue = nil
        } catch { if ticket == generation, !Task.isCancelled { snapshot = nil; issue = W8Text.t("无法读取系统通知权限，请重试。", "Couldn’t read the notification permission. Try again.") } }
    }
    public func requestFromUserAction(expectedRevision: UInt64? = nil) async {
        guard accepts(expectedRevision), !busy, snapshot?.authorization == .notDetermined else { return }
        let ticket = generation; busy = true
        snapshot = nil; issue = nil
        defer { complete() }
        do {
            try await provider.requestFromUserAction()
            guard ticket == generation, !Task.isCancelled else { return }
            let value = try await provider.read()
            guard ticket == generation, !Task.isCancelled else { return }
            snapshot = value
            issue = nil
        } catch { if ticket == generation, !Task.isCancelled { snapshot = nil; issue = W8Text.t("系统授权操作未完成，请重新读取权限状态。", "The system authorization did not finish. Read the permission status again.") } }
    }
    public func openSettingsFromUserAction(expectedRevision: UInt64? = nil) async {
        guard accepts(expectedRevision), !busy, let authorization = snapshot?.authorization, authorization != .notDetermined else { return }
        let ticket = generation; busy = true
        defer { complete() }
        var opened = false
        do {
            try await provider.openSettingsFromUserAction()
            opened = true
            guard ticket == generation, !Task.isCancelled else { return }
            // Opening Settings proves no permission change. Read the OS result;
            // a foreground refresh received while busy is also drained afterward.
            snapshot = nil
            let value = try await provider.read()
            guard ticket == generation, !Task.isCancelled else { return }
            snapshot = value; issue = nil
        }
        catch { if ticket == generation, !Task.isCancelled { issue = opened ? W8Text.t("无法读取系统通知权限，请重试。", "Couldn’t read the notification permission. Try again.") : W8Text.t("无法打开系统设置，请稍后重试。", "Couldn’t open Settings. Try again later.") } }
    }
}
