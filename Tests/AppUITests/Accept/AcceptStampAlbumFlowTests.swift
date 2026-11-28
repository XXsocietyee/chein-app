import XCTest

/// Stamp album. Design fixture `d4-stamps`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptStampAlbumFlowTests: XCTestCase {
    func testStampAlbumFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d4-stamps", markers: ["roam.experience.album"], en: "Stamp album", zh: "集邮册")
    }
}
