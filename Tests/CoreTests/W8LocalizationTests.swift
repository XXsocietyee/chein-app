import XCTest
@testable import QuestifyCore

/// Guards the W8 play/RPG rule copy: every user-visible rule string must have an English and a Chinese form.
final class W8LocalizationTests: XCTestCase {
    override func tearDown() {
        W8Text.languageOverride = nil
        super.tearDown()
    }

    func testHelperSwitchesLanguage() {
        W8Text.languageOverride = "en"
        XCTAssertEqual(W8Text.t("重试", "Retry"), "Retry")
        W8Text.languageOverride = "zh-Hans"
        XCTAssertEqual(W8Text.t("重试", "Retry"), "重试")
    }

    func testExternalGameErrorsAreEnglishInEnglishMode() {
        W8Text.languageOverride = "en"
        let errors: [ExternalGameValidationError] = [
            .unsignedManifest, .invalidSignature, .invalidAllowedDomain("bad domain"),
            .tooManyAllowedDomains(11), .paymentOrIAPDetected("payment"), .malformedArchive
        ]
        for error in errors {
            let text = error.errorDescription ?? ""
            XCTAssertFalse(text.isEmpty)
            XCTAssertNil(text.range(of: "\\p{Han}", options: .regularExpression), "Chinese text leaked in English mode: \(text)")
        }
    }

    func testCharacterAttributeCopyIsEnglishInEnglishMode() {
        W8Text.languageOverride = "en"
        let attribute = CharacterCardAttribute(stateKey: "hp", label: "HP", value: 3, min: 0, max: 10, displayType: "bar", persistScope: "run")
        XCTAssertNil(attribute.scopeText.range(of: "\\p{Han}", options: .regularExpression))
        XCTAssertNil(attribute.rangeText.range(of: "\\p{Han}", options: .regularExpression))
        W8Text.languageOverride = "zh-Hans"
        XCTAssertNotNil(attribute.scopeText.range(of: "\\p{Han}", options: .regularExpression))
    }
}
