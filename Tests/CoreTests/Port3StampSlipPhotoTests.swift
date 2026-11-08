import XCTest
@testable import QuestifyCore

final class Port3StampSlipPhotoTests: XCTestCase {
    func testAcceptsPlainHTTPSWithHost() {
        XCTAssertEqual(RoamStampSlipPhotoPort.displayURL(" https://cdn.example.com/a.jpg ")?.absoluteString, "https://cdn.example.com/a.jpg")
    }
    func testRejectsNonHTTPSMissingHostAndCredentials() {
        XCTAssertNil(RoamStampSlipPhotoPort.displayURL(nil))
        XCTAssertNil(RoamStampSlipPhotoPort.displayURL(""))
        XCTAssertNil(RoamStampSlipPhotoPort.displayURL("   "))
        XCTAssertNil(RoamStampSlipPhotoPort.displayURL("http://cdn.example.com/a.jpg"))
        XCTAssertNil(RoamStampSlipPhotoPort.displayURL("file:///tmp/a.jpg"))
        XCTAssertNil(RoamStampSlipPhotoPort.displayURL("https:///a.jpg"))
        XCTAssertNil(RoamStampSlipPhotoPort.displayURL("https://user:pw@cdn.example.com/a.jpg"))
    }
    func testPhotoBlockOnlyForSuccessfulExchange() {
        XCTAssertTrue(RoamStampSlipPhotoPort.shouldShowPhotoBlock(got: true))
        XCTAssertFalse(RoamStampSlipPhotoPort.shouldShowPhotoBlock(got: false))
    }
}
