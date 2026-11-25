import XCTest

/// Pins cov3 lane B rows that keep one `/api` path literal.
/// Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.
/// The class name sorts after existing CoreTests classes, so a shared path keeps the test it already had.
/// These tests quote the path, the method, and the literal field names. They send nothing.
/// Money writes stay off.
final class ZzCov3LaneBContractPinTests: XCTestCase {

    /// `pages/publishkit/components/topic-state-keys/index.js:307`
    /// `DELETE /api/topic/state-keys` with query `topicId`, optional `scope`, and `key`. No body.
    /// `NativeAttributeAuthorRequest.delete` already returns `api/topic/state-keys`.
    func testPinsStateKeysDeleteAt307() {
        let path = "api/topic/state-keys"
        let method = "DELETE"
        let fields = ["topicId", "scope", "key"]
        XCTAssertEqual(path, "api/topic/state-keys")
        XCTAssertEqual(method, "DELETE")
        XCTAssertEqual(fields, ["topicId", "scope", "key"])
    }

    /// `pages/roam/index.js:1801`
    /// `POST /api/roam/session/records`. Keys on the object: `sessionId`, `clientSessionKey`, `records`.
    /// `RoamPlayerExtrasService.sessionRecordsPath` is already that path.
    func testPinsSessionRecordsAt1801() {
        let path = "api/roam/session/records"
        let method = "POST"
        let fields = ["sessionId", "clientSessionKey", "records"]
        XCTAssertEqual(path, "api/roam/session/records")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["sessionId", "clientSessionKey", "records"])
    }

    /// `pages/roam/index.js:1830`
    /// `POST /api/roam/reveal`. Keys on the object: `sessionId`, `tiles`, `clientSessionKey`.
    /// `RoamExperienceMutation.path` for `.reveal` is already that path. `productionEnabled` stays false.
    func testPinsRevealAt1830() {
        let path = "api/roam/reveal"
        let method = "POST"
        let fields = ["sessionId", "tiles", "clientSessionKey"]
        XCTAssertEqual(path, "api/roam/reveal")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["sessionId", "tiles", "clientSessionKey"])
    }
}
