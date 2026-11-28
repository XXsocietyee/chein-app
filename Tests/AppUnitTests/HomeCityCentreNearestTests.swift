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

    func testEveryMenuCityCentreMapsToItself() {
        XCTAssertEqual(HomeHeroCityNames.manualOptions.count, 20)
        for city in HomeHeroCityNames.manualOptions {
            guard let point = HomeCityCentre.coordinate(for: city) else {
                XCTFail("missing centre \(city)")
                continue
            }
            XCTAssertEqual(HomeCityCentre.nearest(to: point), city, city)
        }
    }

    func testSuzhouCentreStaysSuzhouAndNanjingIsNowACity() {
        let suzhou = HomeCityCentre.coordinate(for: "苏州")!
        XCTAssertEqual(HomeCityCentre.nearest(to: suzhou), "苏州")
        let nanjing = HomeCityCentre.coordinate(for: "南京")!
        XCTAssertEqual(HomeCityCentre.nearest(to: nanjing), "南京")
    }
}
