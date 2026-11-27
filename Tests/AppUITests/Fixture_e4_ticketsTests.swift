import XCTest

/// Launch smoke for `--design-fixture e4-tickets` (18:15 sweep: the app quit right after launch because the
/// ticket wallet reads `@EnvironmentObject AppSession` and the fixture host injected none).
final class Fixture_e4_ticketsTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testE4TicketsStaysRunningEnglish() {
        launchAndAssert(language: "en")
    }

    func testE4TicketsStaysRunningZhHans() {
        launchAndAssert(language: "zh-Hans")
    }

    private func launchAndAssert(language: String) {
        app.launchArguments = [
            "--design-fixture", "e4-tickets",
            "-preferences.language", language,
        ]
        app.launch()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "ticketWallet.row."))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(app.state, .runningForeground)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "e4-tickets-\(language)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
