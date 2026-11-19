import XCTest
import SwiftUI
import CoreLocation
@testable import Questify
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// ui/h-code-r3-player: the one motion token set (xrefs-1 B.0), the in-place result phases and the overlapping-pin
/// grouping on the 漫游 map.
@MainActor final class R3PlayerMotionTests: XCTestCase {
    func testCityTokensAliasTheOneMotionSet() {
        XCTAssertEqual(CityTokens.pressSpring, CYMotion.release, "the City press is the app's release spring")
        XCTAssertEqual(CityTokens.sheetSpring, CYMotion.sheet)
        XCTAssertEqual(CityTokens.deedSpring, CYMotion.moment)
        XCTAssertEqual(CityTokens.sealSpring, CYMotion.seal)
        XCTAssertEqual(CityTokens.heroSpring, CYMotion.hero)
        XCTAssertEqual(CityTokens.reducedFade, CYMotion.reduced)
    }

    func testStaggersAreNonUniformAndExitsAreShorter() {
        XCTAssertEqual(CYMotion.Stagger.chips, [0, 0.05, 0.09])
        XCTAssertEqual(CYMotion.Stagger.delay(1), 0.05)
        XCTAssertEqual(CYMotion.Stagger.delay(7), 0.09, "past the list the last delay repeats")
        XCTAssertLessThan(CYMotion.Duration.hide, CYMotion.Duration.standard)
        XCTAssertEqual(CYMotion.Delay.momentDeed, 0.35); XCTAssertEqual(CYMotion.Delay.heroBand, 0.25)
        XCTAssertEqual(CYMotion.Scale.press, 0.97); XCTAssertEqual(CYMotion.Scale.pinSelected, 1.15)
    }

    private func place(_ id: String, _ lat: Double, _ lng: Double) -> CityPlace {
        CityPlace(id: id, title: id, coordinate: RoamCoordinate(latitude: lat, longitude: lng)!, ownership: .open)
    }

    func testOverlappingPinsClusterWhenZoomedOutAndFanOutWhenZoomedIn() {
        let places = [place("a", 31.2300, 121.4700), place("b", 31.23001, 121.47001), place("c", 31.2600, 121.5100)]
        // 0.05° across 393 pt: a and b are a hair apart, so they share one bubble; c stands alone.
        let out = CityPinGroup.make(places, longitudeSpan: 0.05, widthPoints: 393)
        XCTAssertEqual(out.count, 2)
        let pair = out.first { $0.members.count == 2 }
        XCTAssertNotNil(pair); XCTAssertEqual(pair?.fanned, false)
        // Zoomed in past the fan-out span, the same two still overlap: they fan out on a ring instead.
        let near = CityPinGroup.make(places, longitudeSpan: 0.002, widthPoints: 393)
        let fanned = near.first { $0.members.count == 2 }
        XCTAssertEqual(fanned?.fanned, true)
        let coordinates = fanned?.members.map(\.coordinate) ?? []
        XCTAssertEqual(coordinates.count, 2)
        if coordinates.count == 2 {
            XCTAssertGreaterThan(abs(coordinates[0].latitude - coordinates[1].latitude) + abs(coordinates[0].longitude - coordinates[1].longitude), 0.00001)
        }
    }

    func testSinglePinsStayPlain() {
        let groups = CityPinGroup.make([place("x", 31.2, 121.4)], longitudeSpan: 0.01, widthPoints: 393)
        XCTAssertEqual(groups.count, 1); XCTAssertEqual(groups.first?.members.count, 1); XCTAssertEqual(groups.first?.fanned, false)
    }
}
