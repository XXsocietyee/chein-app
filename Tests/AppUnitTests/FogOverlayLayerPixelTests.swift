import XCTest
import SwiftUI
import UIKit
@testable import Questify

/// Roam fog spec §1e: the overlay layer rendered alone through `ImageRenderer` at scale 1 (no MapKit tiles, deterministic),
/// driven by a real `FogCellBitmap` from the Shanghai fixture walk, plus the rebuild gate and geometry it relies on.
@MainActor final class FogOverlayLayerPixelTests: XCTestCase {
    private let size = CGSize(width: 400, height: 400)
    private let center = RoamCoordinate(latitude: 31.2304, longitude: 121.4777)!
    /// 4 ground meters per point: one geohash-7 cell is ~38 pt wide.
    private let groundPerPoint = 4.0

    private var viewport: FogMercatorWindow { FogWindowGeometry.viewport(center: center, pointSize: size, groundMetersPerPoint: groundPerPoint) }
    private func walk() throws -> FogCellBitmap { try FogFixtures.bitmap(FogFixtures.revealedCodes(FogFixtures.shanghaiPeoplesSquareWalk)) }

    private struct Pixels {
        let width: Int, height: Int, bytes: [UInt8]
        func rgba(_ x: Int, _ y: Int) -> [UInt8] { let i = (y * width + x) * 4; return Array(bytes[i..<(i + 4)]) }
        func alpha(_ x: Int, _ y: Int) -> Int { Int(bytes[(y * width + x) * 4 + 3]) }
    }

    private func render(_ mask: FogMask, appearance: MapAppearance, softEdge: CGFloat = 0) throws -> Pixels {
        let rect = FogWindowGeometry.rect(of: mask.window, in: viewport, pointSize: size)
        let layer = FogOverlayLayer(mask: mask, images: FogMaskImages.make(mask), windowRect: rect, appearance: appearance, softEdgeRadius: softEdge)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: layer)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        try bytes.withUnsafeMutableBytes { pointer in
            let context = try XCTUnwrap(CGContext(data: pointer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return Pixels(width: w, height: h, bytes: bytes)
    }

    private func mask(confirmed: FogCellBitmap, pending: FogCellBitmap = FogCellBitmap(), soften: Bool = false) -> FogMask {
        FogMaskRasterizer.rasterize(confirmed: confirmed, pending: pending, window: viewport, lod: .cell7, soften: soften, revision: 1)
    }

    private func screenPoint(latitude: Double, longitude: Double) -> (x: Int, y: Int) {
        let p = FogWindowGeometry.point(latitude: latitude, longitude: longitude, in: viewport, pointSize: size)
        return (Int(p.x.rounded()), Int(p.y.rounded()))
    }

    private func centre(of code: String) throws -> (latitude: Double, longitude: Double) {
        let b = try XCTUnwrap(FogGeohash.bounds(of: code))
        return ((b.south + b.north) / 2, (b.west + b.east) / 2)
    }

    // MARK: Pixels

    func testHiddenGroundCarriesTheFogOverlayTokenInBothAppearances() throws {
        let bitmap = try walk()
        for appearance in MapAppearance.allCases {
            let pixels = try render(mask(confirmed: bitmap), appearance: appearance)
            let expected = MapVisualStyleManifest.candidate.color(.fogOverlay, appearance).opacity * 255
            XCTAssertEqual(Double(pixels.alpha(6, 6)), expected, accuracy: 2, "\(appearance)")
            XCTAssertEqual(Double(pixels.alpha(393, 393)), expected, accuracy: 2, "\(appearance)")
        }
    }

    func testConfirmedCellCentresAreCutOut() throws {
        let codes = FogFixtures.revealedCodes(FogFixtures.shanghaiPeoplesSquareWalk)
        let pixels = try render(mask(confirmed: try walk()), appearance: .night)
        for code in [codes[0], codes[4], codes[9]] {
            let c = try centre(of: code)
            let p = screenPoint(latitude: c.latitude, longitude: c.longitude)
            XCTAssertLessThanOrEqual(pixels.alpha(p.x, p.y), 2, code)
        }
    }

    func testPendingCellsAreHatchedAndOnlyPartlyCutOut() throws {
        let pendingCode = try XCTUnwrap(RoamCoordinate(latitude: 31.2304, longitude: 121.4856).flatMap { RoamExperienceMath.tileKey($0) })
        let pending = try FogFixtures.bitmap([pendingCode])
        let pixels = try render(mask(confirmed: try walk(), pending: pending), appearance: .night)
        let c = try centre(of: pendingCode)
        let p = screenPoint(latitude: c.latitude, longitude: c.longitude)
        var alphas: [Int] = []
        for dy in -8...8 { for dx in -8...8 { alphas.append(pixels.alpha(p.x + dx, p.y + dy)) } }
        XCTAssertGreaterThan(alphas.min() ?? 0, 0, "pending ground is never fully revealed")
        XCTAssertGreaterThan((alphas.max() ?? 0) - (alphas.min() ?? 0), 20, "hatch lines must be visible, state is not colour-only")
        let mean = Double(alphas.reduce(0, +)) / Double(alphas.count)
        XCTAssertLessThan(mean, 89, "pending reads lighter than hidden fog")
    }

    func testSoftEdgeRollsOffMonotonicallyAcrossTheBoundary() throws {
        let bitmap = try walk()
        let eastCell = try XCTUnwrap(RoamCoordinate(latitude: 31.2304, longitude: 121.4818).flatMap { RoamExperienceMath.tileKey($0) })
        let c = try centre(of: eastCell)
        let start = screenPoint(latitude: c.latitude, longitude: c.longitude)
        let pixels = try render(mask(confirmed: bitmap, soften: true), appearance: .night, softEdge: 3)
        let row = (start.x..<min(start.x + 100, pixels.width)).map { pixels.alpha($0, start.y) }
        XCTAssertLessThanOrEqual(row.first ?? 255, 6)
        XCTAssertEqual(Double(row.last ?? 0), 89, accuracy: 3)
        for pair in zip(row, row.dropFirst()) { XCTAssertGreaterThanOrEqual(pair.1 + 1, pair.0, "alpha must not dip across the edge") }
        XCTAssertGreaterThan(Set(row).count, 4, "the edge is soft, not a one-pixel step")
    }

    // MARK: Geometry

    func testViewportCentreMapsToViewCentreAndWindowFillsView() {
        let v = viewport
        let p = FogWindowGeometry.point(latitude: center.latitude, longitude: center.longitude, in: v, pointSize: size)
        XCTAssertEqual(Double(p.x), 200, accuracy: 0.5); XCTAssertEqual(Double(p.y), 200, accuracy: 0.5)
        let r = FogWindowGeometry.rect(of: v, in: v, pointSize: size)
        XCTAssertEqual(r, CGRect(origin: .zero, size: size))
        let nw = RoamCoordinate(latitude: FogWindowGeometry.latitude(y: v.maxY), longitude: FogWindowGeometry.longitude(x: v.minX))!
        let se = RoamCoordinate(latitude: FogWindowGeometry.latitude(y: v.minY), longitude: FogWindowGeometry.longitude(x: v.maxX))!
        let back = FogWindowGeometry.viewport(northWest: nw, southEast: se, pointSize: size)
        XCTAssertEqual(back?.metersPerPixel ?? 0, groundPerPoint, accuracy: 0.05)
    }

    // MARK: Rebuild gate

    func testMaskRebuildsOnlyOnBitmapWindowOrLevelOfDetailChange() throws {
        let bitmap = try walk()
        let cache = FogMaskCache()
        func resolve(_ v: FogMercatorWindow, revision: Int = 1, constrained: Bool = false) -> FogMask {
            cache.resolve(confirmed: bitmap, pending: FogCellBitmap(), revision: revision, viewport: v, constrained: constrained).mask
        }
        let first = resolve(viewport)
        XCTAssertEqual(cache.rebuildCount, 1)
        XCTAssertEqual(first.lod, .cell7)
        _ = resolve(viewport)
        XCTAssertEqual(cache.rebuildCount, 1, "same viewport and bitmap: no rebuild")
        let nudged = FogWindowGeometry.viewport(center: RoamCoordinate(latitude: center.latitude, longitude: center.longitude + 0.0005)!, pointSize: size, groundMetersPerPoint: groundPerPoint)
        _ = resolve(nudged)
        XCTAssertEqual(cache.rebuildCount, 1, "a pan inside the 25 % margin is a camera tick only")
        _ = resolve(nudged, revision: 2)
        XCTAssertEqual(cache.rebuildCount, 2, "bitmap change")
        let far = FogWindowGeometry.viewport(center: RoamCoordinate(latitude: center.latitude, longitude: center.longitude + 0.03)!, pointSize: size, groundMetersPerPoint: groundPerPoint)
        _ = resolve(far, revision: 2)
        XCTAssertEqual(cache.rebuildCount, 3, "window left the margin")
        let farOut = FogWindowGeometry.viewport(center: center, pointSize: size, groundMetersPerPoint: 100)
        let summary = resolve(farOut, revision: 2)
        XCTAssertEqual(cache.rebuildCount, 4, "level of detail change")
        XCTAssertEqual(summary.lod, .summary)
        XCTAssertNil(cache.images, "summary level carries no mask pixels")
        _ = resolve(farOut, revision: 2, constrained: true)
        XCTAssertEqual(cache.rebuildCount, 5, "power constraint flips the soften pass")
    }

    // MARK: Coverage readout

    func testEveryUnknownCoveragePrintsAnEmDashNeverZero() {
        for reason in FogCoverageReading.UnknownReason.allCases {
            let core = FogCoverageReading.unknown(reason)
            XCTAssertEqual(core.displayText, "—")
            XCTAssertEqual(CYFogCoverageReading(core).percentText, "—")
            XCTAssertEqual(CYFogCoverageReading(core).pending, 0)
        }
        let known = CYFogCoverageReading(.known(confirmed: 37, pending: 4, areaCells: 100))
        XCTAssertEqual(known.percentText, "37%")
        XCTAssertEqual(known.pending, 4)
    }
}
