import XCTest

/// Lane CB702. Offline `--design-fixture d2-city` in English and Simplified Chinese.
/// The screen must render, stay up, and must not show an unknown-fixture fallback,
/// a raw dotted localization key, or the product name Questify outside a DEBUG label.
final class Fixture_d2_cityTests: XCTestCase {
    private let rawDottedKey = try! NSRegularExpression(
        pattern: #"^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+$"#
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testD2CityEnglish() {
        launch(language: "en", attachmentName: "d2-city-en")
    }

    func testD2CitySimplifiedChinese() {
        launch(language: "zh-Hans", attachmentName: "d2-city-zh")
    }

    private func launch(language: String, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d2-city", "-preferences.language", language]
        app.launch()
        defer { app.terminate() }

        waitForFirstHittableElement(in: app)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = attachmentName
        shot.lifetime = .keepAlways
        add(shot)

        let unknown = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        )
        XCTAssertEqual(unknown.count, 0, app.debugDescription)

        let rawKeys = app.staticTexts.allElementsBoundByIndex.filter { isRawDottedKey($0.label) }
        XCTAssertEqual(rawKeys.count, 0, rawKeys.map(\.label).joined(separator: ", "))

        let questify = app.descendants(matching: .any).allElementsBoundByIndex.filter {
            $0.label.contains("Questify")
        }
        for element in questify {
            XCTAssertTrue(
                element.label.contains("DEBUG"),
                "Questify outside DEBUG labels: \(element.label)"
            )
        }

        XCTAssertEqual(app.state, .runningForeground, "App is not still running")
    }

    /// The first element that is hittable, not merely the first element in the tree.
    private func waitForFirstHittableElement(in app: XCUIApplication) {
        let query = app.descendants(matching: .any).matching(NSPredicate(format: "isHittable == true"))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let first = query.firstMatch
            return first.exists && first.isHittable
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed, app.debugDescription)
        XCTAssertTrue(query.firstMatch.isHittable, app.debugDescription)
    }

    private func isRawDottedKey(_ label: String) -> Bool {
        let range = NSRange(label.startIndex..., in: label)
        return rawDottedKey.firstMatch(in: label, range: range) != nil
    }
}
