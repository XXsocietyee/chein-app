#if canImport(AppIntents) && os(iOS)
import AppIntents
import Foundation

/// Components r1 (C2): the action behind the iOS 18 Control Center / Lock Screen controls (开始漫游, 签到).
/// Compiled into the app and the widget extension so the system can run it in the app (`openAppWhenRun`).
/// In the app `handler` routes at once (set by `QuestWidgetBoardPublisher`); in the extension it parks the
/// page in the App Group (`QuestWidgetStore.pendingRouteKey`) and the app opens it when it becomes active.
/// Opening a page starts, claims or pays nothing; the page keeps its own sign-in and consent gating.
public enum QuestControlRoute: String, AppEnum {
    case roam
    case checkIn

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "widget.control.route"
    public static let caseDisplayRepresentations: [QuestControlRoute: DisplayRepresentation] = [
        .roam: "widget.control.roam",
        .checkIn: "widget.control.checkIn",
    ]

    /// MP page: roam home (`pages/roam/index`) and the activity list whose 我的 bucket holds the joined activities and
    /// their tickets, where 签到 happens (`pages/activity/list/index`).
    public var pagePath: String {
        switch self {
        case .roam: return "pages/roam/index"
        case .checkIn: return "subpackageMember/signup/index"
        }
    }
}

public struct QuestControlRouteIntent: AppIntent {
    public static let title: LocalizedStringResource = "widget.control.open"
    public static let openAppWhenRun = true
    public static let isDiscoverable = false

    /// Set by the app at launch; nil inside the widget extension.
    @MainActor public static var handler: (@MainActor (String) -> Void)?

    @Parameter(title: "widget.control.route")
    public var route: QuestControlRoute

    public init() {}

    public init(route: QuestControlRoute) {
        self.route = route
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let handler = Self.handler {
            handler(route.pagePath)
        } else {
            QuestWidgetStore.setPendingRoute(route.pagePath)
        }
        return .result()
    }
}
#endif
