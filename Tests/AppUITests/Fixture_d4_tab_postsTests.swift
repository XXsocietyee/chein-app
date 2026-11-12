import XCTest

/// Offline smoke for the DEBUG design fixture `d4-tab-posts`.
/// Launches English and Simplified Chinese only. Not executed on Linux.
final class Fixture_d4_tab_postsTests: XCTestCase {
    func testEnglish() {
        launchAndAssert(language: "en", screenshotName: "d4-tab-posts-en")
    }

    func testSimplifiedChinese() {
        launchAndAssert(language: "zh-Hans", screenshotName: "d4-tab-posts-zh")
    }

    private func launchAndAssert(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-tab-posts", "-preferences.language", language]
        app.launch()
        defer {
            if app.state == .runningForeground || app.state == .runningBackground {
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = screenshotName
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            app.terminate()
        }

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(firstHittable.waitForExistence(timeout: 10),
                      "Timed out waiting for the first hittable element")
        XCTAssertTrue(firstHittable.isHittable)

        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground,
                      "App is not running (\(app.state))")
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
                .firstMatch
                .exists,
            "Unknown design fixture is visible"
        )
        assertNoRawDottedKeys(in: app)
        assertNoQuestifyOutsideDebugLabels(in: app)
    }

    /// A raw dotted key is the whole visible label, such as `club.detail.tab.posts`.
    private func assertNoRawDottedKeys(in app: XCUIApplication) {
        let pattern = #"^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            XCTFail("Dotted-key pattern did not compile")
            return
        }
        let leaked = app.staticTexts.allElementsBoundByIndex.compactMap { element -> String? in
            let label = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            let range = NSRange(label.startIndex..<label.endIndex, in: label)
            return expression.firstMatch(in: label, range: range) == nil ? nil : label
        }
        XCTAssertEqual(leaked, [], "Raw dotted key static text: \(leaked)")
    }

    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication) {
        let leaked = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Questify"))
            .allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.contains("DEBUG") }
        XCTAssertEqual(leaked, [], "Questify appeared outside a DEBUG label: \(leaked)")
    }
}
