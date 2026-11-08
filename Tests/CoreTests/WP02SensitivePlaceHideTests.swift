import XCTest
@testable import QuestifyCore

final class WP02SensitivePlaceHideTests: XCTestCase {
    private func renderer(places: [PersonalLocationShareSensitivePlace] = []) throws -> PersonalLocationShareFixRenderer {
        try .init(latitudeStep: 0.1, longitudeStep: 0.1, sensitivePlaces: .init(places: places))
    }
    func testHiddenPlaceCollapsesToCoarseForStrangers() throws {
        let home = try PersonalLocationShareSensitivePlace(id: "home", latitude: 31.2304, longitude: 121.4737, radiusMeters: 300)
        let r = try renderer(places: [home])
        XCTAssertTrue(r.sensitivePlaces.hides(latitude: 31.2310, longitude: 121.4740))
        XCTAssertFalse(r.sensitivePlaces.hides(latitude: 31.30, longitude: 121.60))
        let inside = r.render(latitude: 31.2310, longitude: 121.4740, mode: .exact, layer: .stranger)
        let nearby = r.render(latitude: 31.2330, longitude: 121.4790, mode: .exact, layer: .stranger)
        guard case let .coarse(lat, lon) = inside else { return XCTFail("\(inside)") }
        XCTAssertNotEqual(lat, 31.2310); XCTAssertNotEqual(lon, 121.4740)
        XCTAssertEqual(inside, nearby, "every fix in the cell renders identically")
        // A friend also gets the coarse collapse inside a hidden place, but exact elsewhere.
        guard case .coarse = r.render(latitude: 31.2310, longitude: 121.4740, mode: .exact, layer: .friend) else { return XCTFail("hidden place leaked to friend") }
        XCTAssertEqual(r.render(latitude: 31.30, longitude: 121.60, mode: .exact, layer: .friend), .exact(latitude: 31.30, longitude: 121.60))
        XCTAssertThrowsError(try PersonalLocationShareSensitivePlace(id: "", latitude: 0, longitude: 0, radiusMeters: 10))
        XCTAssertThrowsError(try PersonalLocationShareSensitivePlace(id: "x", latitude: 91, longitude: 0, radiusMeters: 10))
        XCTAssertThrowsError(try PersonalLocationShareSensitivePlace(id: "x", latitude: 0, longitude: 0, radiusMeters: 0))
    }
    func testStrangerLayerNeverRendersExactFix() throws {
        let r = try renderer()
        for mode in [PersonalLocationShareMode.exact, .coarse] {
            for (la, lo) in [(0.0, 0.0), (31.2304, 121.4737), (-89.99, 179.99), (90, 180), (-90, -180)] {
                switch r.render(latitude: la, longitude: lo, mode: mode, layer: .stranger) {
                case .exact: XCTFail("stranger saw an exact fix at \(la),\(lo)")
                case let .coarse(clat, clon): XCTAssertTrue((-90...90).contains(clat) && (-180...180).contains(clon))
                case .withheld: break
                }
            }
        }
        XCTAssertEqual(r.render(latitude: .nan, longitude: 0, mode: .exact, layer: .stranger), .withheld)
        XCTAssertEqual(r.render(latitude: 0, longitude: 200, mode: .exact, layer: .friend), .withheld)
        XCTAssertThrowsError(try PersonalLocationShareFixRenderer(latitudeStep: 0, longitudeStep: 0.1, sensitivePlaces: .init(places: [])))
        // A server-coarse fix is never upgraded to exact for a friend.
        guard case .coarse = r.render(latitude: 31.2, longitude: 121.4, mode: .coarse, layer: .friend) else { return XCTFail("coarse upgraded") }
    }
}
