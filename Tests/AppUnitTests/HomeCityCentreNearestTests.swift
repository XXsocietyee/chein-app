import XCTest
@testable import Questify

final class HomeCityCentreNearestTests: XCTestCase {
    func testFixInsideShanghaiMatchesShanghai() {
        let point = RoamCoordinate(latitude: 31.2397, longitude: 121.4998)!
        XCTAssertEqual(HomeCityCentre.nearest(to: point), "上海")
    }

    func testFixNearHangzhouMatchesHangzhouNotShanghai() {
        let point = RoamCoordinate(latitude: 30.25, longitude: 120.17)!
        XCTAssertEqual(HomeCityCentre.nearest(to: point), "杭州")
    }

    func testFixFarFromEverySupportedCityKeepsTheLabel() {
        let point = RoamCoordinate(latitude: 40.7128, longitude: -74.0060)!
        XCTAssertNil(HomeCityCentre.nearest(to: point))
    }
}
