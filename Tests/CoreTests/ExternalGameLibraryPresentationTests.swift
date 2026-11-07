import XCTest
@testable import QuestifyCore

final class ExternalGameLibraryPresentationTests: XCTestCase {
    func testLinkCheckClassifiesInput() {
        XCTAssertEqual(ExternalGameLibraryPresentation.checkLink("   "), .empty)
        XCTAssertEqual(ExternalGameLibraryPresentation.checkLink("http://assets.example.com/g.json"), .invalid)
        XCTAssertEqual(ExternalGameLibraryPresentation.checkLink("https://user:pw@assets.example.com/g.json"), .invalid)
        XCTAssertEqual(ExternalGameLibraryPresentation.checkLink("not a url"), .invalid)
        XCTAssertEqual(ExternalGameLibraryPresentation.checkLink(" https://assets.example.com/g.json "), .validButNotDownloadable)
    }

    func testValidLinkNeverImpliesADownloadHappened() {
        XCTAssertFalse(ExternalGameLibraryPresentation.linkDownloadAvailable)
        for check in [ExternalGameLinkCheck.empty, .invalid, .validButNotDownloadable] {
            XCTAssertFalse(ExternalGameLibraryPresentation.message(for: check).isEmpty)
        }
    }

    func testFeatureStaysOffUnlessFlagIsOn() {
        XCTAssertFalse(ExternalGameLibraryPresentation.isEnabled(flags: .allOff))
        XCTAssertTrue(LaunchFeatureFlags.knownKeys.contains(ExternalGameLibraryPresentation.launchFlagKey))
        let on = LaunchFeatureFlags(enabled: [ExternalGameLibraryPresentation.launchFlagKey])
        XCTAssertTrue(ExternalGameLibraryPresentation.isEnabled(flags: on))
        XCTAssertFalse(ExternalGameLibraryPresentation.isEnabled(flags: LaunchFeatureFlags(enabled: ["drops"])))
    }
}
