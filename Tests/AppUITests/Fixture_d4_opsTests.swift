import XCTest

/// Offline smoke for the DEBUG design fixture `d4-ops` (club operations workspace).
/// Launches the real host only. No network and no production view changes.
final class Fixture_d4_opsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testD4OpsEnglish() {
        assertDesignFixture(language: "en", attachmentName: "d4-ops-en")
    }

    func testD4OpsZhHans() {
        assertDesignFixture(language: "zh-Hans", attachmentName: "d4-ops-zh")
    }

    private func assertDesignFixture(language: String, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-ops", "-preferences.language", language]
        app.launch()
        defer { app.terminate() }

        let firstHittable = app.descendants(matching: .any).matching(NSPredicate(format: "hittable == true")).firstMatch
        let appeared = firstHittable.waitForExistence(timeout: 20)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(appeared, "Expected the first hittable element. " + app.debugDescription)
        XCTAssertTrue(firstHittable.isHittable)

        let unknown = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
        XCTAssertEqual(unknown.count, 0, app.debugDescription)

        let rawKeys = app.staticTexts.allElementsBoundByIndex.map(\.label).filter(Self.isRawDottedKey)
        XCTAssertTrue(rawKeys.isEmpty, "Raw dotted key on screen: \(rawKeys.joined(separator: ", "))")

        XCTAssertEqual(app.state, .runningForeground)

        let questifyOutsideDebug = app.descendants(matching: .any).allElementsBoundByIndex.filter { element in
            element.label.contains("Questify") && !element.label.contains("DEBUG")
        }
        XCTAssertTrue(
            questifyOutsideDebug.isEmpty,
            "Questify outside DEBUG labels: \(questifyOutsideDebug.map(\.label).joined(separator: " | "))"
        )
    }

    /// A catalogue key left unresolved, such as `club.ops.manage`. Visible copy and sentences are not keys.
    private static func isRawDottedKey(_ label: String) -> Bool {
        let parts = label.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, !label.contains(where: \.isWhitespace) else { return false }
        let head = CharacterSet.letters.union(CharacterSet(charactersIn: "_"))
        let body = head.union(.decimalDigits)
        return parts.allSatisfy { part in
            guard let first = part.unicodeScalars.first, head.contains(first) else { return false }
            return part.unicodeScalars.allSatisfy { body.contains($0) }
        }
    }
}
