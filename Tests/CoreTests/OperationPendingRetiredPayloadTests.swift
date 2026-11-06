import Foundation
import XCTest
@testable import QuestifyCore

final class OperationPendingRetiredPayloadTests: XCTestCase {
    private let retiredKeys = ["merchantNPCSave", "themeItemUse", "sideQuestPlayer", "merchantSideQuestPublishing"]

    func testCurrentRecordRoundTripsWithoutRetiredKeys() throws {
        let record = OperationPendingRecord(ownerKey: "owner", targetKey: "target", acknowledgedSteps: 1)
        let data = try JSONEncoder().encode(record)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["operationID", "ownerKey", "targetKey", "acknowledgedSteps"])
        XCTAssertEqual(try JSONDecoder().decode(OperationPendingRecord.self, from: data), record)
    }

    func testEveryNonNullRetiredPayloadIsRejected() throws {
        let record = OperationPendingRecord(ownerKey: "owner", targetKey: "target")
        let data = try JSONEncoder().encode(record)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in retiredKeys {
            for payload: Any in [[:], ["old": true], "old", true, 1] {
                var object = original
                object[key] = payload
                let raw = try JSONSerialization.data(withJSONObject: object)
                XCTAssertThrowsError(try JSONDecoder().decode(OperationPendingRecord.self, from: raw), key)
            }
        }
    }

    func testNullSlotsAndUnrelatedMetadataRemainCompatible() throws {
        let record = OperationPendingRecord(ownerKey: "owner", targetKey: "target", acknowledgedSteps: 1)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        for key in retiredKeys { object[key] = NSNull() }
        object["futureMetadata"] = ["version": 2]
        let raw = try JSONSerialization.data(withJSONObject: object)
        XCTAssertEqual(try JSONDecoder().decode(OperationPendingRecord.self, from: raw), record)
    }

    @MainActor func testRejectedJournalReadRetainsOriginalBytes() async throws {
        let suite = "retired-operation-payload-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let journal = OperationDefaultsJournal(defaults: defaults)
        let record = OperationPendingRecord(ownerKey: "owner", targetKey: "target")
        try journal.write(record)
        let key = "questify.operations.pending.v1." + Data("5:owner:target".utf8).base64EncodedString()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: key))) as? [String: Any])
        object[retiredKeys[0]] = ["old": true]
        let raw = try JSONSerialization.data(withJSONObject: object)
        defaults.set(raw, forKey: key)
        XCTAssertThrowsError(try journal.pending(ownerKey: "owner", targetKey: "target"))
        XCTAssertThrowsError(try journal.pendingRecords(ownerKey: "owner"))
        XCTAssertThrowsError(try journal.write(record))
        XCTAssertEqual(defaults.data(forKey: key), raw)
    }
}
