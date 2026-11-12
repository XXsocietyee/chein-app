import XCTest

/// DEBUG design-fixture smoke for the player inbox (`--design-fixture d2-inbox`).
/// Launches once in English and once in Simplified Chinese. Does not change App views.
final class Fixture_d2_inboxTests: XCTestCase {
    private static let rawDottedKey = try! NSRegularExpression(
        pattern: #"^[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*)+$"#
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testD2InboxEnglish() {
        launchAndAssert(language: "en", screenshotName: "d2-inbox-en")
    }

    func testD2InboxSimplifiedChinese() {
        launchAndAssert(language: "zh-Hans", screenshotName: "d2-inbox-zh")
    }

    private func launchAndAssert(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d2-inbox", "-preferences.language", language]
        app.launch()

        waitForFirstHittableElement(in: app)
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = screenshotName
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let unknown = NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        XCTAssertEqual(app.staticTexts.matching(unknown).count, 0)
        XCTAssertEqual(app.descendants(matching: .any).matching(unknown).count, 0)

        let leakedKeys = rawDottedKeyStaticTexts(in: app)
        XCTAssertTrue(leakedKeys.isEmpty, "Raw dotted key staticText: \(leakedKeys.joined(separator: ", "))")

        assertNoQuestifyOutsideDebugLabels(in: app)
        XCTAssertNotEqual(app.state, .notRunning)
        XCTAssertNotEqual(app.state, .unknown)
    }

    /// The first element that can take a tap. Status-bar chrome is skipped so a
    /// clock does not count as the fixture having rendered.
    private func waitForFirstHittableElement(in app: XCUIApplication, timeout: TimeInterval = 20) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.state == .notRunning {
                XCTFail("App stopped before a hittable element appeared")
                return
            }
            let elements = app.descendants(matching: .any).allElementsBoundByIndex
            if let hit = elements.first(where: { element in
                element.exists && element.isHittable && !element.frame.isEmpty && !isStatusBarChrome(element, in: app)
            }) {
                XCTAssertTrue(hit.isHittable)
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("Timed out waiting for the first hittable element")
    }

    private func isStatusBarChrome(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard app.statusBars.firstMatch.exists else { return false }
        let statusBar = app.statusBars.firstMatch.frame
        return statusBar.intersects(element.frame) && element.frame.maxY <= statusBar.maxY + 1
    }

    private func rawDottedKeyStaticTexts(in app: XCUIApplication) -> [String] {
        app.staticTexts.allElementsBoundByIndex.compactMap { element in
            let label = element.label
            guard label.contains(".") else { return nil }
            let range = NSRange(label.startIndex..<label.endIndex, in: label)
            return Self.rawDottedKey.firstMatch(in: label, range: range) == nil ? nil : label
        }
    }

    /// Product name may appear only on an explicit DEBUG label, never as player-facing copy.
    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication) {
        let predicate = NSPredicate(format: "label CONTAINS %@", "Questify")
        let queries = [
            app.staticTexts.matching(predicate),
            app.buttons.matching(predicate),
            app.textFields.matching(predicate),
            app.textViews.matching(predicate),
            app.links.matching(predicate),
            app.navigationBars.matching(predicate)
        ]
        for query in queries {
            for index in 0..<query.count {
                let label = query.element(boundBy: index).label
                XCTAssertTrue(label.contains("DEBUG"), "Questify outside a DEBUG label: \(label)")
            }
        }
    }
}
