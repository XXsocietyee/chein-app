import XCTest

/// Offline smoke for the DEBUG design fixture `d4-channel-chat`.
/// The host is synthetic channel data. These checks only confirm the screen comes up
/// in English and Simplified Chinese without a missing fixture, a raw catalog key,
/// or the Questify name outside a DEBUG label.
final class Fixture_d4_channel_chatTests: XCTestCase {
    private static let dottedKey = try! NSRegularExpression(
        pattern: #"^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$"#
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    func testEnglishDesignFixture() throws {
        try assertDesignFixture(language: "en", attachmentName: "d4-channel-chat-en")
    }

    func testSimplifiedChineseDesignFixture() throws {
        try assertDesignFixture(language: "zh-Hans", attachmentName: "d4-channel-chat-zh")
    }

    private func assertDesignFixture(language: String, attachmentName: String) throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--design-fixture", "d4-channel-chat",
            "-preferences.language", language
        ]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(
            firstHittable.waitForExistence(timeout: 15),
            "Timed out waiting for the first hittable element. \(app.debugDescription)"
        )
        XCTAssertTrue(firstHittable.isHittable, app.debugDescription)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = attachmentName
        shot.lifetime = .keepAlways
        add(shot)

        let unknown = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        )
        XCTAssertEqual(unknown.count, 0, "Unknown design fixture is on screen. \(app.debugDescription)")

        let rawKeys = app.staticTexts.allElementsBoundByIndex.map(\.label).filter(Self.isRawDottedKey)
        XCTAssertTrue(rawKeys.isEmpty, "staticText is a raw dotted key: \(rawKeys). \(app.debugDescription)")

        XCTAssertEqual(app.state, .runningForeground, "App is no longer running")

        let questify = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Questify")
        )
        for index in 0..<questify.count {
            let label = questify.element(boundBy: index).label
            XCTAssertTrue(
                label.contains("DEBUG"),
                "Questify appears outside a DEBUG label: \(label). \(app.debugDescription)"
            )
        }
    }

    private static func isRawDottedKey(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return dottedKey.firstMatch(in: trimmed, range: range) != nil
    }
}
