import AppIntents
import Foundation

/// Design P1 L9 (P-016 / G-089): Siri, Spotlight and Shortcuts entries — 开始漫游, 继续故事, 打开城市护照.
/// Each intent only opens the app on a reviewed mini-program page through the same router a notification tap uses
/// (`MPNotificationTapRouter.open(pagePath:)`; it waits for the session when the intent launches the app).
/// Opening a page starts, claims or pays nothing and sends no request of its own; the page keeps its sign-in gating.
enum QuestAppIntentRoute {
    /// Roam home (`pages/roam/index`); the walk itself starts from there with its usual consent and location prompts.
    static let roam = "pages/roam/index"
    /// The stories I joined (`subpackageMember/mycanyu/mycanyu`), where a story is picked up again.
    static let stories = "subpackageMember/mycanyu/mycanyu"
    /// City passport / stamp album (`subpackageP3/pages/stamp-album/index/index`).
    static let passport = "subpackageP3/pages/stamp-album/index/index"

    @MainActor static func open(_ pagePath: String) {
        MPNotificationTapRouter.shared.open(pagePath: pagePath)
    }
}

struct StartRoamIntent: AppIntent {
    static let title: LocalizedStringResource = "appIntent.roam.title"
    static let description: IntentDescription? = IntentDescription("appIntent.roam.description")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuestAppIntentRoute.open(QuestAppIntentRoute.roam)
        return .result()
    }
}

struct ContinueStoryIntent: AppIntent {
    static let title: LocalizedStringResource = "appIntent.story.title"
    static let description: IntentDescription? = IntentDescription("appIntent.story.description")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuestAppIntentRoute.open(QuestAppIntentRoute.stories)
        return .result()
    }
}

struct OpenPassportIntent: AppIntent {
    static let title: LocalizedStringResource = "appIntent.passport.title"
    static let description: IntentDescription? = IntentDescription("appIntent.passport.description")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuestAppIntentRoute.open(QuestAppIntentRoute.passport)
        return .result()
    }
}

/// App Shortcuts (no setup needed). Phrases are translated in `Resources/AppShortcuts.xcstrings`.
struct QuestAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartRoamIntent(),
                    phrases: ["Start a roam in \(.applicationName)", "\(.applicationName) start roaming"],
                    shortTitle: "appIntent.roam.short", systemImageName: "figure.walk")
        AppShortcut(intent: ContinueStoryIntent(),
                    phrases: ["Continue my story in \(.applicationName)", "\(.applicationName) continue story"],
                    shortTitle: "appIntent.story.short", systemImageName: "book")
        AppShortcut(intent: OpenPassportIntent(),
                    phrases: ["Open my passport in \(.applicationName)", "\(.applicationName) open passport"],
                    shortTitle: "appIntent.passport.short", systemImageName: "book.closed")
    }
}
