import XCTest

/// Smoke the DEBUG `--design-fixture d2-roam` host. English and Simplified Chinese
/// each get one launch. The Apple runner executes it; this file is parse-checked on Linux.
final class Fixture_d2_roamTests: XCTestCase {
    private var runningApp: XCUIApplication?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        runningApp?.terminate()
        runningApp = nil
        super.tearDown()
    }

    func testD2RoamEnglish() {
        assertDesignFixture(language: "en", screenshotName: "d2-roam-en")
    }

    func testD2RoamSimplifiedChinese() {
        assertDesignFixture(language: "zh-Hans", screenshotName: "d2-roam-zh")
    }

    private func assertDesignFixture(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d2-roam", "-preferences.language", language]
        runningApp = app
        app.launch()

        let hittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        let appeared = hittable.waitForExistence(timeout: 20)
        if app.state == .runningForeground || app.state == .runningBackground {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = screenshotName
            shot.lifetime = .keepAlways
            add(shot)
        }
        XCTAssertTrue(appeared, "Timed out waiting for the first hittable element. \(app.debugDescription)")

        let unknown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
        XCTAssertEqual(unknown.count, 0, "Unknown design fixture is visible. \(app.debugDescription)")

        let dottedKeys = app.staticTexts.allElementsBoundByIndex.map(\.label).filter(isRawDottedKey)
        XCTAssertTrue(
            dottedKeys.isEmpty,
            "Raw dotted key staticText: \(dottedKeys.prefix(12).joined(separator: ", "))"
        )

        XCTAssertEqual(
            app.state,
            .runningForeground,
            "Expected the app to still be running, state \(app.state.rawValue)"
        )

        let questify = questifyOutsideDebugLabels(in: app)
        XCTAssertTrue(
            questify.isEmpty,
            "Questify outside DEBUG labels: \(questify.prefix(8).joined(separator: " | "))"
        )
    }

    /// A catalogue key shown as the whole static text, such as `roam.home.title`.
    private func isRawDottedKey(_ label: String) -> Bool {
        let text = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = text.first, first.isASCII, first.isLowercase, text.contains(".") else { return false }
        var segmentStart = true
        var sawDot = false
        for character in text {
            if character == "." {
                if segmentStart { return false }
                sawDot = true
                segmentStart = true
                continue
            }
            let allowed = character.isASCII && (character.isLetter || character.isNumber || character == "_")
            if !allowed { return false }
            segmentStart = false
        }
        return sawDot && !segmentStart
    }

    /// Visible labels may say Questify only when that same label is a DEBUG label.
    private func questifyOutsideDebugLabels(in app: XCUIApplication) -> [String] {
        var seen: [String] = []
        for element in app.descendants(matching: .any).allElementsBoundByIndex {
            let label = element.label
            guard label.range(of: "Questify", options: .caseInsensitive) != nil else { continue }
            guard label.range(of: "DEBUG", options: .caseInsensitive) == nil else { continue }
            if !seen.contains(label) { seen.append(label) }
        }
        return seen
    }
}
