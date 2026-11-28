import XCTest

/// mp-home r3 (Next round: all states). DEBUG launch of the `d2-search-empty` design fixture.
/// English and zh-Hans each get one screenshot. App views are not changed here.
final class Fixture_d2_search_emptyTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testD2SearchEmptyEnglish() {
        assertDesignFixture(language: "en", screenshotName: "d2-search-empty-en")
    }

    func testD2SearchEmptyZhHans() {
        assertDesignFixture(language: "zh-Hans", screenshotName: "d2-search-empty-zh")
    }

    private func assertDesignFixture(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = [
            "--design-fixture", "d2-search-empty",
            "-preferences.language", language,
        ]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        let appeared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: firstHittable
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [appeared], timeout: 20),
            .completed,
            "Expected the first hittable element for d2-search-empty (\(language))"
        )

        let labels = visibleLabels(in: app)
        let unknown = labels.filter { $0.contains("Unknown design fixture") }
        XCTAssertEqual(unknown, [], "Unknown design fixture is on screen: \(unknown)")

        let rawKeys = app.staticTexts.allElementsBoundByIndex.map(\.label).filter(Self.isRawDottedKey)
        XCTAssertEqual(rawKeys, [], "A staticText is a raw dotted key: \(rawKeys)")

        XCTAssertTrue(
            app.state == .runningForeground || app.state == .runningBackground,
            "App is not running (state \(app.state.rawValue))"
        )

        let questify = labels.filter { label in
            label.contains("Questify") && !label.contains("DEBUG")
        }
        XCTAssertEqual(questify, [], "Questify appears outside a DEBUG label: \(questify)")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = screenshotName
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func visibleLabels(in app: XCUIApplication) -> [String] {
        let types: [XCUIElement.ElementType] = [
            .staticText, .button, .textField, .textView, .searchField, .navigationBar, .link,
        ]
        return types.flatMap { type in
            app.descendants(matching: type).allElementsBoundByIndex.map(\.label)
        }
    }

    /// A catalogue key left untranslated, such as `searchMap.title`, not a sentence.
    private static func isRawDottedKey(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy(isKeySegment)
    }

    private static func isKeySegment(_ part: Substring) -> Bool {
        guard let first = part.unicodeScalars.first else { return false }
        let scalars = part.unicodeScalars
        func isDigit(_ value: UInt32) -> Bool { value >= 48 && value <= 57 }
        func isLetter(_ value: UInt32) -> Bool {
            (value >= 65 && value <= 90) || (value >= 97 && value <= 122)
        }
        guard isLetter(first.value) else { return false }
        return scalars.allSatisfy { isDigit($0.value) || isLetter($0.value) }
    }
}
