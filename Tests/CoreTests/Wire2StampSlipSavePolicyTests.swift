import XCTest
@testable import QuestifyCore

final class Wire2StampSlipSavePolicyTests: XCTestCase {
    func testTearComesFirst() {
        XCTAssertEqual(RoamStampSlipSavePolicy.decide(torn: false, pictureURL: "https://cdn.example.com/a.jpg"), .needsTear)
        XCTAssertEqual(RoamStampSlipSavePolicy.decide(torn: false, pictureURL: nil), .needsTear)
    }
    func testMissingOrUnusablePicture() {
        XCTAssertEqual(RoamStampSlipSavePolicy.decide(torn: true, pictureURL: nil), .noPicture)
        XCTAssertEqual(RoamStampSlipSavePolicy.decide(torn: true, pictureURL: "http://cdn.example.com/a.jpg"), .noPicture)
    }
    func testReadyCarriesTrimmedHTTPSURL() {
        XCTAssertEqual(RoamStampSlipSavePolicy.decide(torn: true, pictureURL: " https://cdn.example.com/a.jpg "),
                       .ready(URL(string: "https://cdn.example.com/a.jpg")!))
    }
}
