import XCTest

/// K26: mount the 40 most-used player screens at AX-XXXL
/// (`UICTContentSizeCategoryAccessibilityXXXL`, SwiftUI `.accessibility5`).
/// Each launch is an existing DEBUG fixture. The test records a screenshot and checks the
/// process is in the foreground. It does not judge pixels. This workspace has no simulator,
/// so the method is authored and not executed here.
final class DynamicTypeAX5ScreenPassUITests: XCTestCase {
    /// Fixture id, owning lane, screen. Order is the pass order.
    private let screens: [(fixture: String, lane: String, screen: String)] = [
        ("d2-home", "mp-home", "Home feed"),
        ("d2-search", "mp-home", "Home search"),
        ("e1-topic-detail", "mp-home", "Topic detail"),
        ("e1-official", "mp-home", "Official events"),
        ("d6-search", "mp-home", "Map search"),
        ("d2-roam", "mp-roam", "Roam map home"),
        ("d6-real-live", "mp-roam", "Live roam"),
        ("d2-city", "mp-roam", "City roam"),
        ("r3-roam-history", "mp-roam", "Roam history"),
        ("e5b-stamp", "mp-roam", "Stamp collected"),
        ("d4-stamps", "mp-roam", "Stamp album"),
        ("r3-roam-nearby", "mp-roam", "Nearby teams"),
        ("r3-roam-poi", "mp-roam", "Place detail"),
        ("r3-roam-tasks", "mp-roam", "Official tasks"),
        ("template-topics", "mp-publish", "Publish shelf"),
        ("template-detail", "mp-publish", "Template detail"),
        ("t11-fabu", "mp-publish", "Project editor"),
        ("d2-square", "mp-publish", "Square"),
        ("d4-directory", "mp-club", "Club home"),
        ("d4-detail", "mp-club", "Club detail"),
        ("d4-tab-posts", "mp-club", "Club posts"),
        ("d4-channel-chat", "mp-club", "Club channel chat"),
        ("d4-members", "mp-club", "Club members"),
        ("welcome", "mp-mine", "Welcome"),
        ("onboarding-1", "mp-mine", "Onboarding"),
        ("d2-me", "mp-mine", "Me"),
        ("ia-passport", "mp-mine", "Passport"),
        ("d4-badges", "mp-mine", "Badge wall"),
        ("d4-settings", "mp-mine", "Settings"),
        ("d4-growth", "mp-mine", "Growth"),
        ("d4-leaderboard", "mp-mine", "Leaderboard"),
        ("wallet", "mp-mine", "Wallet"),
        ("login-player", "mp-nav", "Login"),
        ("e4-auth-phone", "mp-nav", "Phone sign-in"),
        ("d2-inbox", "mp-nav", "IM inbox"),
        ("e1-activity-detail", "mp-activity", "Activity detail"),
        ("e1-ticket-holder", "mp-activity", "Ticket wallet"),
        ("t5-pass-market", "mp-activity", "Pass market"),
        ("d2-play", "mp-journey", "Play"),
        ("d2-npc", "mp-journey", "NPC"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testFortyMostUsedScreensMountAtAccessibilityXXXL() {
        XCTAssertEqual(screens.count, 40)
        for screen in screens {
            let app = XCUIApplication()
            app.launchArguments = [
                "--uitesting-reset-language",
                "-AppleLanguages", "(en)",
                "-AppleLocale", "en_US",
                "--uitesting-max-text",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                "--design-fixture", screen.fixture,
            ]
            app.launch()
            XCTAssertEqual(app.state, .runningForeground, "\(screen.lane) \(screen.screen) (\(screen.fixture))")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "ax-xxxl-\(screen.fixture)"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
    }
}
