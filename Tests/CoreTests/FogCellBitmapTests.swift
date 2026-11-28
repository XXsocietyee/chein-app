import XCTest
@testable import QuestifyCore

final class FogCellBitmapTests: XCTestCase {
    private func cell(_ code: String) throws -> FogCell { try FogCell(grid: .legacyRoamTile, code: code) }

    /// Literal expectation for `FogFixtures.shanghaiPeoplesSquareWalk` (computed offline with the same geohash and
    /// distance rules): 26 samples -> 15 cells; 2 jumps, 2 low-accuracy and 1 stale fix reveal nothing.
    static let expectedWalkCells = ["wtw3egm", "wtw3egq", "wtw3egr", "wtw3sjq", "wtw3sjr", "wtw3sm2", "wtw3sm3", "wtw3sm6",
                                    "wtw3sm7", "wtw3smk", "wtw3smm", "wtw3spq", "wtw3spw", "wtw3spy", "wtw3u0n"]

    func testEveryChildIndexRoundTripsOverTheAlphabet() throws {
        let parent = FogCellBitmap.ParentKey(geohash5: "wtw3s")
        var seen = Set<Int>()
        for a in FogCellBitmap.alphabet { for b in FogCellBitmap.alphabet {
            let code = "wtw3s\(a)\(b)"
            let slot = try XCTUnwrap(FogCellBitmap.index(of: code))
            XCTAssertEqual(slot.parent, parent)
            XCTAssertEqual(FogCellBitmap.code(parent: parent, bit: slot.bit), code)
            seen.insert(slot.bit)
        } }
        XCTAssertEqual(seen, Set(0..<1024))
    }

    func testRejectsNonPrecisionSevenAndBadCharacters() throws {
        XCTAssertNil(FogCellBitmap.index(of: "wtw3s"))
        XCTAssertNil(FogCellBitmap.index(of: "wtw3sjqx"))
        XCTAssertNil(FogCellBitmap.index(of: "wtw3sja"))
        var bitmap = FogCellBitmap()
        XCTAssertThrowsError(try bitmap.insert(cell("wtw3sj"))) { XCTAssertEqual($0 as? PersonalFogFailure, .invalidCell) }
        XCTAssertTrue(bitmap.isEmpty)
    }

    func testTileKeysFromRoamMathRoundTrip() throws {
        var bitmap = FogCellBitmap()
        for i in 0..<200 {
            let point = try XCTUnwrap(RoamCoordinate(latitude: 31.2 + Double(i) * 0.0011, longitude: 121.4 + Double(i % 17) * 0.0013))
            let key = try XCTUnwrap(RoamExperienceMath.tileKey(point))
            try bitmap.insert(cell(key))
            XCTAssertTrue(bitmap.contains(try cell(key)))
        }
    }

    func testUnionPopcountAndSubtract() throws {
        var a = FogCellBitmap(), b = FogCellBitmap()
        for code in ["wtw3sjq", "wtw3sjr", "wtw3egm"] { try a.insert(cell(code)) }
        for code in ["wtw3sjr", "wtw3sm2"] { try b.insert(cell(code)) }
        XCTAssertEqual(a.count, 3); XCTAssertEqual(b.count, 2)
        var merged = a; merged.formUnion(b)
        XCTAssertEqual(merged.count, 4)
        var again = merged; again.formUnion(b); again.formUnion(a)
        XCTAssertEqual(again, merged, "union is idempotent and order independent")
        var other = b; other.formUnion(a)
        XCTAssertEqual(other, merged)
        merged.subtract(b)
        XCTAssertEqual(merged.count, 2)
        XCTAssertFalse(merged.contains(try cell("wtw3sjr")))
        XCTAssertTrue(merged.contains(try cell("wtw3sjq")))
    }

    func testUnionIgnoresOtherGrid() throws {
        var a = FogCellBitmap()
        try a.insert(cell("wtw3sjq"))
        a.formUnion(FogCellBitmap(grid: FogGridVersion(id: "h3-r9")))
        XCTAssertEqual(a.count, 1)
    }

    func testCoverageCountsChildrenPerGeohash6() throws {
        var bitmap = FogCellBitmap()
        // wtw3sj has children wtw3sj0...wtw3sjz; reveal 3 of them, plus one under wtw3sk.
        for code in ["wtw3sj0", "wtw3sjq", "wtw3sjz", "wtw3sk0"] { try bitmap.insert(cell(code)) }
        XCTAssertEqual(bitmap.coverage(geohash6: "wtw3sj"), 3)
        XCTAssertEqual(bitmap.coverage(geohash6: "wtw3sk"), 1)
        XCTAssertEqual(bitmap.coverage(geohash6: "wtw3sm"), 0)
        XCTAssertEqual(bitmap.coverage(geohash6: "bad"), 0)
        for a in FogCellBitmap.alphabet { try bitmap.insert(cell("wtw3sk\(a)")) }
        XCTAssertEqual(bitmap.coverage(geohash6: "wtw3sk"), 32)
    }

    func testShanghaiFixtureWalkYieldsTheLiteralCellSet() throws {
        XCTAssertEqual(FogFixtures.shanghaiPeoplesSquareWalk.count, 26)
        let codes = FogFixtures.revealedCodes(FogFixtures.shanghaiPeoplesSquareWalk)
        XCTAssertEqual(codes.sorted(), Self.expectedWalkCells)
        let bitmap = try FogFixtures.bitmap(codes)
        XCTAssertEqual(bitmap.count, 15)
        XCTAssertEqual(Set(bitmap.parents.keys.map(\.geohash5)), ["wtw3e", "wtw3s", "wtw3u"])
        // The first fix (31.2304, 121.4737) is in wtw3sjq.
        XCTAssertTrue(bitmap.contains(try cell("wtw3sjq")))
    }

    func testEnvelopeRoundTripOwnerAndVersionChecks() throws {
        let bitmap = try FogFixtures.bitmap(Self.expectedWalkCells)
        let data = try bitmap.envelopeData(owner: "acct-1")
        XCTAssertLessThan(data.count, FogCellBitmap.maxEnvelopeBytes)
        XCTAssertEqual(try FogCellBitmap.decode(data, owner: "acct-1"), bitmap)
        XCTAssertEqual(data, try bitmap.envelopeData(owner: "acct-1"), "deterministic bytes")
        XCTAssertThrowsError(try FogCellBitmap.decode(data, owner: "acct-2")) { XCTAssertEqual($0 as? FogCellBitmap.EnvelopeFailure, .ownerMismatch) }
        XCTAssertThrowsError(try FogCellBitmap.decode(Data("{}".utf8), owner: "acct-1")) { XCTAssertEqual($0 as? FogCellBitmap.EnvelopeFailure, .malformed) }
        XCTAssertThrowsError(try FogCellBitmap.decode(Data(count: FogCellBitmap.maxEnvelopeBytes + 1), owner: "acct-1")) { XCTAssertEqual($0 as? FogCellBitmap.EnvelopeFailure, .tooLarge) }
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("time"), "no timestamps in the envelope")
    }

    func testBoundsContainTheirOwnPoint() throws {
        let point = try XCTUnwrap(RoamCoordinate(latitude: 31.2304, longitude: 121.4737))
        let key = try XCTUnwrap(RoamExperienceMath.tileKey(point))
        let b = try XCTUnwrap(FogGeohash.bounds(of: key))
        XCTAssertTrue(b.south <= 31.2304 && 31.2304 < b.north && b.west <= 121.4737 && 121.4737 < b.east)
        XCTAssertEqual(b.north - b.south, 180.0 / 131072.0, accuracy: 1e-9)
    }

    func testFixStreamGateFollowsTheLiveRevealSwitch() {
        // Gap #24 (1128 plan R-02d): the live fog reveal is on in every build; the gate still needs permission and foreground.
        XCTAssertTrue(PersonalFogFeature.liveRevealEnabled)
        XCTAssertEqual(RoamFixStreamGate.decide(authorization: .authorized, appActive: true), .allowed)
        XCTAssertEqual(RoamFixStreamGate.decide(authorization: .authorized, appActive: true, liveRevealEnabled: false), .blocked(.featureOff))
        XCTAssertEqual(RoamFixStreamGate.decide(authorization: .authorized, appActive: true, liveRevealEnabled: true), .allowed)
        XCTAssertEqual(RoamFixStreamGate.decide(authorization: .denied, appActive: true, liveRevealEnabled: true), .blocked(.permissionMissing))
        XCTAssertEqual(RoamFixStreamGate.decide(authorization: .notDetermined, appActive: true, liveRevealEnabled: true), .blocked(.permissionNotDetermined))
        XCTAssertEqual(RoamFixStreamGate.decide(authorization: .authorized, appActive: false, liveRevealEnabled: true), .blocked(.appInactive))
    }
}

final class FogCoverageReadingTests: XCTestCase {
    func testEveryUnknownReasonPrintsAnEmDashNeverZero() {
        for reason in FogCoverageReading.UnknownReason.allCases {
            let reading = FogCoverageReading.unknown(reason)
            XCTAssertNil(reading.percent); XCTAssertNil(reading.percentText); XCTAssertNil(reading.pendingCount)
            XCTAssertEqual(reading.displayText, "—")
        }
    }
    func testKnownReadings() {
        XCTAssertEqual(FogCoverageReading.known(confirmed: 15, pending: 2, areaCells: 60).displayText, "25%")
        XCTAssertEqual(FogCoverageReading.known(confirmed: 0, pending: 0, areaCells: 60).displayText, "0%", "a loaded empty fog is a real 0")
        XCTAssertEqual(FogCoverageReading.known(confirmed: 99, pending: 0, areaCells: 60).displayText, "100%")
        XCTAssertEqual(FogCoverageReading.known(confirmed: 1, pending: 0, areaCells: 0).displayText, "—", "no denominator is unknown")
        XCTAssertEqual(FogCoverageReading.known(confirmed: 1, pending: 3, areaCells: 10).pendingCount, 3)
    }
    func testReaderMapsMissingInputsToUnknown() throws {
        let bitmap = try FogFixtures.bitmap(["wtw3sjq", "wtw3sjr"])
        let area: Set<String> = ["wtw3sjq", "wtw3sjr", "wtw3sjw", "wtw3sjx"]
        XCTAssertEqual(FogCoverageReader.reading(confirmed: bitmap, pending: nil, areaCells: area, owner: nil, permissionGranted: true), .unknown(.noIdentity))
        XCTAssertEqual(FogCoverageReader.reading(confirmed: bitmap, pending: nil, areaCells: area, owner: "a", permissionGranted: false), .unknown(.permissionMissing))
        XCTAssertEqual(FogCoverageReader.reading(confirmed: bitmap, pending: nil, areaCells: nil, owner: "a", permissionGranted: true), .unknown(.noAreaSelected))
        XCTAssertEqual(FogCoverageReader.reading(confirmed: nil, pending: nil, areaCells: area, owner: "a", permissionGranted: true), .unknown(.notLoaded))
        XCTAssertEqual(FogCoverageReader.reading(confirmed: bitmap, pending: try FogFixtures.bitmap(["wtw3sjw"]), areaCells: area, owner: "a", permissionGranted: true),
                       .known(confirmed: 2, pending: 1, areaCells: 4))
    }
}

final class RoamLocationPrimerStepTests: XCTestCase {
    func testPrimingShowsOnceBeforeTheSystemPrompt() {
        XCTAssertEqual(RoamLocationPrimerStep.resolve(authorization: .notDetermined, primerSeen: false), .priming)
        XCTAssertNil(RoamLocationPrimerStep.resolve(authorization: .notDetermined, primerSeen: true))
        XCTAssertFalse(RoamLocationPrimerStep.mayRequestSystemPrompt(authorization: .notDetermined, primerSeen: false))
        XCTAssertTrue(RoamLocationPrimerStep.mayRequestSystemPrompt(authorization: .notDetermined, primerSeen: true))
    }
    func testDeniedAlwaysShowsSettingsCardAndAuthorizedShowsNothing() {
        for seen in [false, true] {
            XCTAssertEqual(RoamLocationPrimerStep.resolve(authorization: .denied, primerSeen: seen), .denied)
            XCTAssertNil(RoamLocationPrimerStep.resolve(authorization: .authorized, primerSeen: seen))
            XCTAssertFalse(RoamLocationPrimerStep.mayRequestSystemPrompt(authorization: .denied, primerSeen: seen))
        }
    }
}
