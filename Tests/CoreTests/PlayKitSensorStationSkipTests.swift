import XCTest
@testable import QuestifyCore

/// MP `playkit-view.js` P-23 / round 11 i1 (`tests/unit/r11-i1-sensor-skip.test.js`): the four sensor kits
/// report a failed read and ask to skip with `{game}` only; skip follows the server's `canSkip`.
final class PlayKitSensorStationSkipTests: XCTestCase {
    private func wire(_ text: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(text.utf8)) }

    func testReportAndSkipCarryOnlyTheGame() throws {
        for kind in ["compass", "ballShake", "quietHold", "shout"] {
            XCTAssertTrue(PlayKitActionCatalog.actions[kind]!.contains("REPORT_SENSOR_FAILURE"), kind)
            XCTAssertTrue(PlayKitActionCatalog.actions[kind]!.contains("SKIP_SENSOR_STATION"), kind)
            XCTAssertEqual(try PlayKitActionCatalog.payload(kind: kind, action: "REPORT_SENSOR_FAILURE", detail: ["denied": .bool(false), "x": .integer(1)]),
                           ["game": .string(kind)], kind)
            XCTAssertEqual(try PlayKitActionCatalog.payload(kind: kind, action: "REPORT_SENSOR_FAILURE", detail: ["denied": .bool(true)]),
                           ["game": .string(kind), "denied": .bool(true)], kind)
            XCTAssertEqual(try PlayKitActionCatalog.payload(kind: kind, action: "SKIP_SENSOR_STATION", detail: ["denied": .bool(true)]),
                           ["game": .string(kind)], kind)
        }
        XCTAssertThrowsError(try PlayKitActionCatalog.payload(kind: "reaction", action: "SKIP_SENSOR_STATION", detail: [:]))
    }

    func testSkipOnlyWhenTheServerSaysCanSkip() throws {
        let skip = ["game": PlayWireValue.string("ballShake")]
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "ballShake", action: "SKIP_SENSOR_STATION", payload: skip,
                                                               segment: wire(#"{"goal":5,"failedReads":2}"#)))
        XCTAssertNoThrow(try PlayKitInputContract.validate(kind: "ballShake", action: "SKIP_SENSOR_STATION", payload: skip,
                                                           segment: wire(#"{"goal":5,"canSkip":true}"#)))
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "ballShake", action: "SKIP_SENSOR_STATION", payload: skip,
                                                               segment: wire(#"{"goal":5,"canSkip":true,"skipped":true}"#)))
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "ballShake", action: "SKIP_SENSOR_STATION",
                                                               payload: ["game": .string("shout")], segment: wire(#"{"canSkip":true}"#)))
    }

    func testReportShapeAndSkippedStationIsFinished() throws {
        let segment = try wire(#"{"seconds":5}"#)
        XCTAssertNoThrow(try PlayKitInputContract.validate(kind: "shout", action: "REPORT_SENSOR_FAILURE",
                                                           payload: ["game": .string("shout")], segment: segment))
        XCTAssertNoThrow(try PlayKitInputContract.validate(kind: "shout", action: "REPORT_SENSOR_FAILURE",
                                                           payload: ["game": .string("shout"), "denied": .bool(true)], segment: segment))
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "shout", action: "REPORT_SENSOR_FAILURE",
                                                               payload: ["game": .string("shout"), "denied": .bool(false)], segment: segment))
        for kind in [PlayKitScreenKind.compass, .ballShake, .quietHold, .shout] {
            XCTAssertTrue(PlayKitScreenProjection(kind: kind, segment: try wire(#"{"skipped":true}"#)).complete, kind.rawValue)
            XCTAssertFalse(PlayKitSensorStation.offersSkip(try wire(#"{"canSkip":true,"skipped":true}"#)))
        }
        XCTAssertFalse(PlayKitScreenProjection(kind: .reaction, segment: try wire(#"{"skipped":true}"#)).complete)
    }
}
