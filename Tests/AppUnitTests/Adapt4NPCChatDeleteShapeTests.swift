import XCTest
@testable import Questify

/// ADAPT-4 group 2. The "/api/npc/chat/delete" row is an audit/allowlist LABEL, not an HTTP route. The live call
/// (NPCChatLogDeletion) already targets ApiAiNpcController `@RequestMapping("/api/ai/npc")` + `@PostMapping("/chat/data/delete")`
/// (hengyin@4ac8c249). Existing tests pin the legacy label string exactly, so it is deliberately NOT renamed; these tests pin
/// the live path and the backend response shapes instead.
final class Adapt4NPCChatDeleteShapeTests: XCTestCase {
    func testLivePathIsTheBackendRouteNotTheAuditLabel() {
        XCTAssertEqual(NPCChatLogDeletion.path, "api/ai/npc/chat/data/delete")
        XCTAssertNotEqual("/" + NPCChatLogDeletion.path, NPCChatAndSceneAISafetyAudit.remoteChatDeleteRoute,
                          "label and live route intentionally differ; see docs/release/gap345/adapt-4-report.md")
    }
    // Backend: success(Collections.singletonMap("deleted", n)) -> {"msg":"操作成功","code":200,"data":{"deleted":n}}.
    func testConfirmedCountDecodesIncludingConfirmedZero() throws {
        XCTAssertEqual(try NPCChatLogDeletion.decode(Data(#"{"msg":"操作成功","code":200,"data":{"deleted":12}}"#.utf8)), .deleted(count: 12))
        XCTAssertEqual(try NPCChatLogDeletion.decode(Data(#"{"msg":"操作成功","code":200,"data":{"deleted":0}}"#.utf8)), .deleted(count: 0))
    }
    // Backend: error(...) -> code 500 with HTTP 200 -> definite rejection.
    func testBusinessErrorIsDefiniteRejection() {
        XCTAssertThrowsError(try NPCChatLogDeletion.decode(Data(#"{"msg":"请先登录","code":500}"#.utf8))) {
            XCTAssertEqual($0 as? NPCChatDataFailure, .rejected)
        }
    }
    func testSuccessWithoutCountOrWithNegativeCountIsUnknownNeverAGuessedZero() throws {
        XCTAssertEqual(try NPCChatLogDeletion.decode(Data(#"{"msg":"操作成功","code":200}"#.utf8)), .unknown)
        XCTAssertEqual(try NPCChatLogDeletion.decode(Data(#"{"msg":"操作成功","code":200,"data":{"deleted":-1}}"#.utf8)), .unknown)
    }
}
