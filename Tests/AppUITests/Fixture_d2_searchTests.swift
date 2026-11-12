import XCTest

/// DEBUG `--design-fixture d2-search` in English and Simplified Chinese.
@MainActor
final class Fixture_d2_searchTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testD2SearchEnglish() {
        assertDesignFixture(language: "en", attachmentName: "d2-search-en")
    }

    func testD2SearchChinese() {
        assertDesignFixture(language: "zh-Hans", attachmentName: "d2-search-zh")
    }

    private func assertDesignFixture(language: String, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d2-search", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(
            firstHittable.waitForExistence(timeout: 20),
            "Timed out waiting for the first hittable element"
        )

        let unknown = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        )
        XCTAssertEqual(unknown.count, 0, "Unexpected text Unknown design fixture")

        assertNoRawDottedKeyStaticText(in: app)
        assertNoQuestifyOutsideDebugLabels(in: app)
        XCTAssertTrue(
            app.state == .runningForeground || app.state == .runningBackground,
            "App is not running (\(app.state))"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A static text whose entire label is an unresolved catalogue key, such as `searchMap.title`.
    private func assertNoRawDottedKeyStaticText(in app: XCUIApplication) {
        let rawDottedKey = #"^[a-z][A-Za-z0-9_]*(\.[a-z][A-Za-z0-9_]*)+$"#
        let matches = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", rawDottedKey))
        let labels = matches.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.isEmpty, "Raw dotted key staticText: \(labels)")
    }

    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication) {
        let types: [XCUIElement.ElementType] = [
            .staticText, .button, .textView, .textField, .navigationBar, .link
        ]
        var leaks: [String] = []
        for type in types {
            for element in app.descendants(matching: type).allElementsBoundByIndex {
                let value = element.value as? String ?? ""
                let text = element.label + "\n" + value
                guard text.contains("Questify") else { continue }
                if text.contains("DEBUG") { continue }
                leaks.append(element.label.isEmpty ? value : element.label)
            }
        }
        XCTAssertTrue(leaks.isEmpty, "Questify outside DEBUG labels: \(leaks)")
    }
}
