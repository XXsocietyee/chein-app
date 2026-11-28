import XCTest

/// K24 xcui-smoke. One launch per design fixture, in English and in Simplified Chinese.
///
/// Intended simulator: Questify-iPhone17-Lane2 (`2337B386-AC5F-4417-B8B8-012A8DB888BD`).
/// This file does not boot a simulator. A Mac with that simulator runs:
/// `xcodebuild test -project Questify.xcodeproj -scheme Questify -destination 'platform=iOS Simulator,id=2337B386-AC5F-4417-B8B8-012A8DB888BD' -only-testing:QuestifyUITests/<Class>`
enum XCUIAcceptLanguage: String {
    case en
    case zhHans = "zh-Hans"

    var appleLanguages: String { self == .en ? "(en)" : "(zh-Hans)" }
    var appleLocale: String { self == .en ? "en_US" : "zh_CN" }
}

enum XCUIAcceptSmoke {
    /// Launches `--design-fixture` for `en` and `zh-Hans`, then checks one existing identifier and one translated label.
    static func cover(_ test: XCTestCase, fixture: String, markers: [String], en: String, zh: String,
                      file: StaticString = #filePath, line: UInt = #line) {
        launch(test, fixture: fixture, markers: markers, language: .en, copy: en, file: file, line: line)
        launch(test, fixture: fixture, markers: markers, language: .zhHans, copy: zh, file: file, line: line)
    }

    private static func launch(_ test: XCTestCase, fixture: String, markers: [String], language: XCUIAcceptLanguage, copy: String,
                               file: StaticString, line: UInt) {
        let app = XCUIApplication()
        app.launchArguments = [
            "--design-fixture", fixture,
            "-preferences.language", language.rawValue,
            "-AppleLanguages", language.appleLanguages,
            "-AppleLocale", language.appleLocale,
        ]
        app.launch()
        defer {
            attachFailureScreenshot(test, app: app)
            app.terminate()
        }

        let ready = wait(seconds: 25) {
            if unknownFixture(in: app) { return true }
            return markers.contains { element(app, $0).exists } && labeled(app, copy).exists
        }
        XCTAssertTrue(ready, "\(fixture) (\(language.rawValue)) did not settle", file: file, line: line)
        XCTAssertFalse(unknownFixture(in: app), "Unknown design fixture \(fixture)", file: file, line: line)
        XCTAssertTrue(markers.contains { element(app, $0).exists },
                      "\(fixture) (\(language.rawValue)) missing \(markers)", file: file, line: line)
        XCTAssertTrue(labeled(app, copy).exists,
                      "\(fixture) (\(language.rawValue)) missing \(copy)", file: file, line: line)
        let rawKeys = app.staticTexts.allElementsBoundByIndex.map(\.label).filter(isRawDottedKey)
        XCTAssertEqual(rawKeys, [], "\(fixture) shows a raw key: \(rawKeys)", file: file, line: line)
        XCTAssertEqual(app.state, .runningForeground, "\(fixture) is not in the foreground", file: file, line: line)
        attachFixtureScreenshot(test, app: app, name: "accept-\(fixture)-\(language.rawValue)")
    }

    private static func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private static func labeled(_ app: XCUIApplication, _ copy: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", copy)).firstMatch
    }

    private static func unknownFixture(in app: XCUIApplication) -> Bool {
        let unknown = NSPredicate(format: "label BEGINSWITH 'Unknown design fixture' OR label BEGINSWITH 'Unknown fixture'")
        return app.staticTexts.matching(unknown).firstMatch.exists
    }

    private static func wait(seconds: TimeInterval, until ready: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if ready() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return ready()
    }

    /// A catalogue key left on screen, such as `searchMap.title`, not a sentence.
    private static func isRawDottedKey(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, parts.count <= 6 else { return false }
        return parts.allSatisfy(isKeySegment)
    }

    private static func isKeySegment(_ part: Substring) -> Bool {
        guard let first = part.unicodeScalars.first else { return false }
        func isDigit(_ value: UInt32) -> Bool { value >= 48 && value <= 57 }
        func isLetter(_ value: UInt32) -> Bool {
            (value >= 65 && value <= 90) || (value >= 97 && value <= 122)
        }
        guard isLetter(first.value) else { return false }
        return part.unicodeScalars.allSatisfy { isDigit($0.value) || isLetter($0.value) }
    }
}
