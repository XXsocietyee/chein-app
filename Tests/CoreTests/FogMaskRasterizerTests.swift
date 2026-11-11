import XCTest
@testable import QuestifyCore

final class FogMaskRasterizerTests: XCTestCase {
    private func bitmap(_ codes: [String]) throws -> FogCellBitmap { try FogFixtures.bitmap(codes) }
    private func center(_ code: String) throws -> (lat: Double, lng: Double) {
        let b = try XCTUnwrap(FogGeohash.bounds(of: code))
        return ((b.south + b.north) / 2, (b.west + b.east) / 2)
    }
    private func alpha(_ mask: FogMask, at code: String) throws -> UInt8 {
        let c = try center(code)
        let p = try XCTUnwrap(mask.pixel(latitude: c.lat, longitude: c.lng), "\(code) outside mask")
        return mask.alpha(x: p.x, y: p.y)
    }
    private let street = FogMercatorWindow(south: 31.2200, west: 121.4700, north: 31.2400, east: 121.4900, metersPerPixel: 10)

    func testCellCentresAreExactlyConfirmedPendingOrHidden() throws {
        let confirmed = try bitmap(["wtw3sjq", "wtw3sjr", "wtw3sm2"])
        let pending = try bitmap(["wtw3sm3", "wtw3sjq"]) // sjq overlaps confirmed: confirmed wins
        let mask = FogMaskRasterizer.rasterize(confirmed: confirmed, pending: pending, window: street, lod: .cell7, soften: false, revision: 7)
        XCTAssertEqual(mask.revision, 7); XCTAssertEqual(mask.lod, .cell7)
        XCTAssertLessThanOrEqual(max(mask.width, mask.height), FogMaskRasterizer.maxSide)
        XCTAssertEqual(mask.alpha.count, mask.width * mask.height)
        XCTAssertEqual(try alpha(mask, at: "wtw3sjq"), 255)
        XCTAssertEqual(try alpha(mask, at: "wtw3sjr"), 255)
        XCTAssertEqual(try alpha(mask, at: "wtw3sm2"), 255)
        XCTAssertEqual(try alpha(mask, at: "wtw3sm3"), 128)
        XCTAssertEqual(try alpha(mask, at: "wtw3sm6"), 0)
        XCTAssertEqual(mask.alpha(x: 0, y: 0), 0)
        XCTAssertEqual(mask.alpha(x: -1, y: 0), 0)
    }

    func testEmptyBitmapsGiveAnAllHiddenMask() {
        let mask = FogMaskRasterizer.rasterize(confirmed: FogCellBitmap(), pending: FogCellBitmap(), window: street, lod: .cell7, soften: false, revision: 1)
        XCTAssertGreaterThan(mask.width, 0)
        XCTAssertTrue(mask.alpha.allSatisfy { $0 == 0 })
    }

    func testFixtureWalkMasksEveryRevealedCentreAndNoneOfTheRejectedFixes() throws {
        let codes = FogFixtures.revealedCodes(FogFixtures.shanghaiPeoplesSquareWalk)
        let window = FogMercatorWindow(south: 31.2150, west: 121.4550, north: 31.2500, east: 121.4900, metersPerPixel: 10)
        let mask = FogMaskRasterizer.rasterize(confirmed: try bitmap(codes), pending: FogCellBitmap(), window: window, lod: .cell7, soften: false, revision: 1)
        for code in codes { XCTAssertEqual(try alpha(mask, at: code), 255, code) }
        let lit = mask.alpha.filter { $0 == 255 }.count
        XCTAssertGreaterThan(lit, 0)
        // The 200 m accuracy fix at (31.23, 121.47) is rejected, so its cell stays dark.
        let rejected = try XCTUnwrap(RoamExperienceMath.tileKey(XCTUnwrap(RoamCoordinate(latitude: 31.23, longitude: 121.47))))
        XCTAssertFalse(codes.contains(rejected))
        XCTAssertEqual(try alpha(mask, at: rejected), 0)
    }

    func testCell6CoverageScalesAlphaAndSummaryHasNoMask() throws {
        var codes: [String] = []
        for a in FogCellBitmap.alphabet.prefix(16) { codes.append("wtw3sj\(a)") } // 16 of 32 children
        let confirmed = try bitmap(codes)
        let window = FogMercatorWindow(south: 31.20, west: 121.44, north: 31.26, east: 121.50, metersPerPixel: 40)
        let mask = FogMaskRasterizer.rasterize(confirmed: confirmed, pending: FogCellBitmap(), window: window, lod: .cell6, soften: false, revision: 2)
        XCTAssertEqual(try alpha(mask, at: "wtw3sj0"), UInt8(255 * 16 / 32))
        XCTAssertEqual(try alpha(mask, at: "wtw3sm0"), 0)
        let summary = FogMaskRasterizer.rasterize(confirmed: confirmed, pending: FogCellBitmap(), window: window, lod: .summary, soften: false, revision: 3)
        XCTAssertEqual(summary.width, 0); XCTAssertTrue(summary.alpha.isEmpty)
    }

    func testSoftenOnlyBlursAndStaysInRange() throws {
        let confirmed = try bitmap(["wtw3sjq"])
        let hard = FogMaskRasterizer.rasterize(confirmed: confirmed, pending: FogCellBitmap(), window: street, lod: .cell7, soften: false, revision: 1)
        let soft = FogMaskRasterizer.rasterize(confirmed: confirmed, pending: FogCellBitmap(), window: street, lod: .cell7, soften: true, revision: 1)
        XCTAssertEqual(try alpha(soft, at: "wtw3sjq"), 255)
        XCTAssertTrue(soft.alpha.contains { $0 != 0 && $0 != 255 })
        XCTAssertGreaterThanOrEqual(soft.alpha.filter { $0 > 0 }.count, hard.alpha.filter { $0 > 0 }.count)
    }

    func testLargeWindowIsCappedAtMaxSide() {
        let window = FogMercatorWindow(south: 30, west: 120, north: 32, east: 122, metersPerPixel: 5)
        let mask = FogMaskRasterizer.rasterize(confirmed: FogCellBitmap(), pending: FogCellBitmap(), window: window, lod: .cell7, soften: false, revision: 1)
        XCTAssertLessThanOrEqual(mask.width, 512); XCTAssertLessThanOrEqual(mask.height, 512)
    }

    func testLevelOfDetailThresholdsAndHysteresis() {
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 6), .cell7)
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 5.9), .cell6)
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 2), .cell6)
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 1.9), .summary)
        // From cell6, 6...7.19 px stays cell6 (needs +20 %); 7.2 switches finer.
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 7.0, previous: .cell6), .cell6)
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 7.2, previous: .cell6), .cell7)
        // From cell7, 4.8...6 px stays cell7; below 4.8 drops.
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 5.0, previous: .cell7), .cell7)
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 4.7, previous: .cell7), .cell6)
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 2.3, previous: .summary), .summary)
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 2.4, previous: .summary), .cell6)
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 1.7, previous: .cell6), .cell6)
        XCTAssertEqual(FogLevelOfDetail.resolve(cellPixels: 1.5, previous: .cell6), .summary)
        XCTAssertEqual(FogLevelOfDetail.cellPixels(metersPerPixel: 0), 0, "unusable scale never divides by zero")
    }

    func testNeedsRebuildOnRevisionWindowExitAndLodOnly() throws {
        let viewport = FogMercatorWindow(south: 31.225, west: 121.475, north: 31.235, east: 121.485, metersPerPixel: 10)
        XCTAssertTrue(FogMaskRasterizer.needsRebuild(current: nil, viewport: viewport, bitmapRevision: 1))
        let mask = FogMaskRasterizer.rasterize(confirmed: FogCellBitmap(), pending: FogCellBitmap(), window: viewport.expanded(by: FogMaskRasterizer.margin),
                                               lod: .cell7, soften: false, revision: 1)
        XCTAssertFalse(FogMaskRasterizer.needsRebuild(current: mask, viewport: viewport, bitmapRevision: 1))
        XCTAssertTrue(FogMaskRasterizer.needsRebuild(current: mask, viewport: viewport, bitmapRevision: 2))
        // Small pan inside the 25 % margin: no rebuild. Pan beyond it: rebuild.
        let dx = viewport.width * 0.2
        let inside = FogMercatorWindow(minX: viewport.minX + dx, minY: viewport.minY, maxX: viewport.maxX + dx, maxY: viewport.maxY, metersPerPixel: 10)
        XCTAssertFalse(FogMaskRasterizer.needsRebuild(current: mask, viewport: inside, bitmapRevision: 1))
        let far = FogMercatorWindow(minX: viewport.minX + dx * 2, minY: viewport.minY, maxX: viewport.maxX + dx * 2, maxY: viewport.maxY, metersPerPixel: 10)
        XCTAssertTrue(FogMaskRasterizer.needsRebuild(current: mask, viewport: far, bitmapRevision: 1))
        // Zoom out far enough to change LOD.
        let zoomed = FogMercatorWindow(minX: viewport.minX, minY: viewport.minY, maxX: viewport.maxX, maxY: viewport.maxY, metersPerPixel: 60)
        XCTAssertTrue(FogMaskRasterizer.needsRebuild(current: mask, viewport: zoomed, bitmapRevision: 1))
    }

    func testCellsInWindowFiltersByIntersection() throws {
        let all = try bitmap(FogFixtures.revealedCodes(FogFixtures.shanghaiPeoplesSquareWalk))
        let near = FogMercatorWindow(south: 31.2290, west: 121.4730, north: 31.2320, east: 121.4790, metersPerPixel: 5)
        let cells = all.cells(in: near)
        XCTAssertFalse(cells.isEmpty); XCTAssertLessThan(cells.count, all.count)
        XCTAssertTrue(cells.allSatisfy { $0.datum == .gcj02 && $0.state == .confirmed })
        XCTAssertEqual(cells.map(\.code), cells.map(\.code).sorted())
    }
}
