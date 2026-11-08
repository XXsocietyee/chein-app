import XCTest
@testable import QuestifyCore

final class WP10OfflinePackHashRejectionTests: XCTestCase {
    private let later = Date(timeIntervalSince1970: 2_000_000_000)
    private var base: [String: String] {
        ["packID": "pack-a", "operationID": "op-1", "version": "v1",
         "checksum": String(repeating: "a", count: 64), "byteSize": "10"]
    }
    func testCodeHashFieldRejected() {
        var object = base
        object["codeHash"] = "deadbeef"
        XCTAssertThrowsError(try OfflinePackOperation.inspect(object)) {
            XCTAssertEqual($0 as? OfflinePackFailure, .answersOrHiddenCoordinatesForbidden)
        }
        XCTAssertThrowsError(try OfflinePackOperation.decodeManifest(object, publicPlaceIDs: [1], expiresAt: later))
    }
    func testSnakeCaseCodeHashRejected() {
        var object = base
        object["code_hash"] = "deadbeef"
        XCTAssertThrowsError(try OfflinePackOperation.inspect(object)) {
            XCTAssertEqual($0 as? OfflinePackFailure, .answersOrHiddenCoordinatesForbidden)
        }
    }
    func testAnswersStillRejected() {
        var object = base
        object["answers"] = "x"
        XCTAssertThrowsError(try OfflinePackOperation.inspect(object)) {
            XCTAssertEqual($0 as? OfflinePackFailure, .answersOrHiddenCoordinatesForbidden)
        }
        XCTAssertNoThrow(try OfflinePackOperation.inspect(base))
    }
}
