import XCTest

/// DEBUG launch of the wired `d4-settings` design fixture (Settings).
/// English and Simplified Chinese. Does not open rows or leave the fixture.
final class Fixture_d4_settingsTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testEnglish() {
        assertDesignFixture(language: "en", screenshotName: "d4-settings-en")
    }

    func testSimplifiedChinese() {
        assertDesignFixture(language: "zh-Hans", screenshotName: "d4-settings-zh")
    }

    private func assertDesignFixture(language: String, screenshotName: String) {
        let app = XCUIApplication()
        self.app = app
        app.launchArguments = ["--design-fixture", "d4-settings", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .element(boundBy: 0)
        let appeared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: firstHittable
        )
        XCTAssertEqual(XCTWaiter.wait(for: [appeared], timeout: 20), .completed, app.debugDescription)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = screenshotName
        shot.lifetime = .keepAlways
        add(shot)

        let unknown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
        XCTAssertEqual(unknown.count, 0, app.debugDescription)

        let rawKey = NSPredicate(
            format: "label MATCHES %@",
            "^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$"
        )
        let rawKeys = app.staticTexts.matching(rawKey)
        XCTAssertEqual(rawKeys.count, 0, rawKeys.allElementsBoundByIndex.map(\.label).joined(separator: "\n"))

        var questifyOutsideDebug: [String] = []
        for element in app.descendants(matching: .any).allElementsBoundByIndex {
            let label = element.label
            let value = element.value as? String ?? ""
            let combined = label + "\n" + value
            guard combined.localizedCaseInsensitiveContains("Questify") else { continue }
            if !combined.localizedCaseInsensitiveContains("DEBUG") {
                questifyOutsideDebug.append(combined)
            }
        }
        XCTAssertEqual(questifyOutsideDebug, [], "Questify outside a DEBUG label")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
