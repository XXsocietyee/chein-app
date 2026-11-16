import XCTest

/// Golden path for the four player tab roots (docs/release/page-flow.md, J1/J10): launch, skip onboarding, browse as a guest,
/// then walk Explore -> Roam -> Clubs -> Passport and back to Explore. Each root is identified by an identifier that its
/// current state always carries (unconfigured test build, signed out), so the walk does not depend on live data.
final class PageFlowGoldenPathTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        skipOnboardingIfPresent(in: app)
    }
    override func tearDownWithError() throws { attachFailureScreenshot(self, app: app); app.terminate(); app = nil }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    /// Selects `tab` and waits for any of `rootIdentifiers` (a root renders one of them per state: unavailable, error, loaded).
    private func openTab(_ tab: String, root rootIdentifiers: [String], file: StaticString = #filePath, line: UInt = #line) {
        let button = app.tabBars.buttons[tab]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "\(tab) tab missing", file: file, line: line)
        button.tap()
        XCTAssertTrue(button.isSelected, "\(tab) tab not selected", file: file, line: line)
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline, !rootIdentifiers.contains(where: { element($0).exists }) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(rootIdentifiers.contains(where: { element($0).exists }), "\(tab) root identifier missing: \(rootIdentifiers)", file: file, line: line)
    }

    func testGuestWalksFourTabRootsAndBack() {
        let browse = app.buttons["welcome.browse"]
        XCTAssertTrue(browse.waitForExistence(timeout: 10))
        if !browse.isHittable { app.swipeUp() }
        browse.tap()
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["Home", "Roam", "Publish", "Clubs", "Me"])

        let explore = ["homeFeed.configurationUnavailable", "homeFeed.openGlobalSearch", "homeFeed.kind", "homeFeed.empty"]
        let roam = ["roam.error", "roam.content", "roam.go", "roam.home.tabs"]
        let clubs = ["club.home.unavailable", "club.home.error", "club.home.signIn", "club.home.retry", "clubTab.topTabs"]
        let passport = ["welcome.player"] // a guest's Passport tab is the sign-in entry

        openTab("Home", root: explore)
        openTab("Roam", root: roam)
        openTab("Clubs", root: clubs)
        openTab("Me", root: passport)
        openTab("Home", root: explore)
    }
}
