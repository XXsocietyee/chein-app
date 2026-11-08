import XCTest
@testable import QuestifyCore

final class WP10ClientOperationIDTests: XCTestCase {
    private let body = Data("{\"a\":1}".utf8)
    func testIDBoundToSubjectObjectAndBodyHash() throws {
        let store = InMemoryClientOperationIDStore()
        let id = try store.operationID(subject: "member-1", object: "order/9", body: body)
        XCTAssertEqual(id.subject, "member-1")
        XCTAssertEqual(id.object, "order/9")
        XCTAssertEqual(id.bodyHash, ClientOperationID.hash(of: body))
        XCTAssertFalse(id.value.isEmpty)
        XCTAssertThrowsError(try store.operationID(subject: " ", object: "o", body: body))
        XCTAssertThrowsError(try store.operationID(subject: "m", object: "", body: body))
    }
    func testResumeReusesOriginalID() throws {
        let store = InMemoryClientOperationIDStore()
        let first = try store.operationID(subject: "m", object: "o", body: body)
        let again = try store.operationID(subject: "m", object: "o", body: body)
        XCTAssertEqual(first, again)
        store.complete(first)
        XCTAssertNil(store.existing(subject: "m", object: "o", body: body))
    }
    func testDifferentBodyYieldsDifferentID() throws {
        let store = InMemoryClientOperationIDStore()
        let a = try store.operationID(subject: "m", object: "o", body: body)
        let b = try store.operationID(subject: "m", object: "o", body: Data("{\"a\":2}".utf8))
        XCTAssertNotEqual(a.value, b.value)
    }
    func testAccountSwitchNeverReusesID() throws {
        let store = InMemoryClientOperationIDStore()
        let a = try store.operationID(subject: "m1", object: "o", body: body)
        let b = try store.operationID(subject: "m2", object: "o", body: body)
        XCTAssertNotEqual(a.value, b.value)
        XCTAssertNil(store.existing(subject: "m3", object: "o", body: body))
    }
    func testFileJournalSurvivesReload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wp10-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let first = try FileClientOperationIDStore(fileURL: url).operationID(subject: "m", object: "o", body: body)
        let reloaded = try FileClientOperationIDStore(fileURL: url).operationID(subject: "m", object: "o", body: body)
        XCTAssertEqual(first, reloaded)
    }
}
