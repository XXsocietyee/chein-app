import XCTest

/// Lane CB713. Launches the DEBUG design fixture `d4-badges-empty` in English and Simplified Chinese.
final class Fixture_d4_badges_emptyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testEnglish() {
        exercise(language: "en", screenshotName: "d4-badges-empty-en")
    }

    func testSimplifiedChinese() {
        exercise(language: "zh-Hans", screenshotName: "d4-badges-empty-zh")
    }

    private func exercise(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-badges-empty", "-preferences.language", language]
        app.launch()
        defer { app.terminate() }

        waitForFirstHittableElement(in: app)
        assertNoUnknownDesignFixture(in: app)
        assertNoRawDottedKeyStaticText(in: app)
        assertAppStillRunning(app)
        assertNoQuestifyOutsideDebugLabels(in: app)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = screenshotName
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForFirstHittableElement(in app: XCUIApplication, timeout: TimeInterval = 20) {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if firstHittableElement(in: app) != nil { return }
            if Date() >= deadline { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        XCTFail("Timed out waiting for the first hittable element")
    }

    private func firstHittableElement(in app: XCUIApplication) -> XCUIElement? {
        let types: [XCUIElement.ElementType] = [.button, .staticText, .cell, .link, .switch, .textField, .image]
        for type in types {
            for element in app.descendants(matching: type).allElementsBoundByIndex where element.isHittable {
                return element
            }
        }
        return nil
    }

    private func assertNoUnknownDesignFixture(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let unknown = NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        let types: [XCUIElement.ElementType] = [.staticText, .button, .textView, .other, .navigationBar]
        for type in types {
            let match = app.descendants(matching: type).matching(unknown).firstMatch
            XCTAssertFalse(match.exists, "Unexpected text Unknown design fixture", file: file, line: line)
        }
    }

    private func assertNoRawDottedKeyStaticText(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let offenders = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { isRawDottedKey($0) }
        XCTAssertTrue(offenders.isEmpty, "Raw dotted key staticText: \(offenders)", file: file, line: line)
    }

    /// A raw dotted key is the whole label: two or more identifier segments joined by dots.
    private func isRawDottedKey(_ label: String) -> Bool {
        let parts = label.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        let identifier = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_")
        let starters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_")
        return parts.allSatisfy { part in
            guard let first = part.unicodeScalars.first, starters.contains(first) else { return false }
            return part.unicodeScalars.allSatisfy { identifier.contains($0) }
        }
    }

    private func assertAppStillRunning(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let state = app.state
        XCTAssertTrue(
            state == .runningForeground || state == .runningBackground,
            "App is not running (\(state))",
            file: file,
            line: line
        )
    }

    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let types: [XCUIElement.ElementType] = [
            .staticText, .button, .navigationBar, .textView, .textField, .link, .image, .cell, .other
        ]
        let questify = NSPredicate(format: "label CONTAINS %@", "Questify")
        var leaks: [String] = []
        for type in types {
            let matches = app.descendants(matching: type).matching(questify)
            for element in matches.allElementsBoundByIndex where !element.label.contains("DEBUG") {
                leaks.append(element.label)
            }
        }
        XCTAssertTrue(leaks.isEmpty, "Questify appears outside DEBUG labels: \(leaks)", file: file, line: line)
    }
}
