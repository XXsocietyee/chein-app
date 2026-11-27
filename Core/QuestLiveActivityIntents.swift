import Foundation
#if canImport(ActivityKit) && canImport(AppIntents) && os(iOS)
import AppIntents
#endif

/// Components r1 C1: what a Live Activity button asks the app to do. Compiled into the app and the
/// `QuestifyLiveActivity` extension (`tools/generate_project.py` shares this file), like `QuestLiveActivityContent`.
/// Each action re-enters the same app code path as the in-app button: pause / resume call the run's own
/// pause / start, check-in opens the current stop's punch sheet. Nothing here writes to the server by itself.
public enum QuestLiveActivityAction: String, Codable, Hashable, Sendable {
    case pause, resume, checkIn
}

/// Hands intent actions to the app. The app (`QuestLiveActivityCenter`) installs `handler` at launch; the widget
/// extension never does, so an action performed there is dropped. A check-in that arrives before the run screen
/// is up waits in `pending` until a handler takes it (the intent opens the app first).
@MainActor public enum QuestLiveActivityActionRouter {
    /// Returns true when the action was taken.
    public static var handler: ((QuestLiveActivityAction, QuestLiveActivityKind) -> Bool)?
    public private(set) static var pending: (action: QuestLiveActivityAction, kind: QuestLiveActivityKind)?

    @discardableResult
    public static func route(_ action: QuestLiveActivityAction, kind: QuestLiveActivityKind) -> Bool {
        if handler?(action, kind) == true { pending = nil; return true }
        // Only a check-in survives a launch: a pause or resume that cannot be applied now would be stale later.
        pending = action == .checkIn ? (action, kind) : nil
        return false
    }

    /// The pending action, once. Called when a screen that can apply it appears.
    public static func takePending() -> (action: QuestLiveActivityAction, kind: QuestLiveActivityKind)? {
        defer { pending = nil }
        return pending
    }
}

#if canImport(ActivityKit) && canImport(AppIntents) && os(iOS)
/// Pause or resume a roam walk or play run from the Lock Screen / Dynamic Island. `LiveActivityIntent` runs in
/// the app's process without bringing it to the foreground.
public struct QuestLiveActivityRunToggleIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "liveActivity.intent.toggle"
    public static var description = IntentDescription("liveActivity.intent.toggle.description")
    public static var isDiscoverable: Bool = false
    @Parameter(title: "liveActivity.intent.kind") public var kind: String
    @Parameter(title: "liveActivity.intent.pause") public var pause: Bool

    public init() {}
    public init(kind: QuestLiveActivityKind, pause: Bool) {
        self.kind = kind.rawValue
        self.pause = pause
    }

    @MainActor public func perform() async throws -> some IntentResult {
        if let target = QuestLiveActivityKind(rawValue: kind) {
            QuestLiveActivityActionRouter.route(pause ? .pause : .resume, kind: target)
        }
        return .result()
    }
}

/// 打卡 at the current stop: opens the app on the run's punch sheet (scan / photo evidence stays in the app).
public struct QuestLiveActivityCheckInIntent: AppIntent {
    public static var title: LocalizedStringResource = "liveActivity.intent.checkIn"
    public static var description = IntentDescription("liveActivity.intent.checkIn.description")
    public static var isDiscoverable: Bool = false
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor public func perform() async throws -> some IntentResult {
        QuestLiveActivityActionRouter.route(.checkIn, kind: .play)
        return .result()
    }
}
#endif
