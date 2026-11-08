#if canImport(QuestifyCore)
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// pages im/chat ordinary 1:1 text send recovery: POST /api/im/send-receipt reads the ORIGINAL request only.
final class OrdinaryIMSendReceiptTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var status = 200
        var body = ""
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (Data(body.utf8), status) }
    }
    private let clientID = String(repeating: "ab", count: 16)
    private func intent() throws -> MessageTextIntent { try MessageTextIntent(conversationID: 5, content: "hello", clientMessageID: clientID) }
    private func receipt(_ wire: Wire) throws -> OrdinaryIMSendReceipt {
        OrdinaryIMSendReceipt(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/")!), transport: wire)
    }
    private func found(sender: Int = 7, content: String = "hello", client: String? = nil, type: Int = 1, conversation: Int = 5) -> String {
        #"{"code":200,"data":{"found":true,"message":{"id":90,"conversationId":\#(conversation),"senderId":\#(sender),"msgType":\#(type),"content":"\#(content)","status":0,"clientMessageId":"\#(client ?? clientID)"}}}"#
    }
    func testRequestUsesReceiptPathAndOnlyConversationAndClientID() async throws {
        let wire = Wire(); wire.body = #"{"code":200,"data":{"found":false,"message":null}}"#
        _ = try await receipt(wire).read(try intent(), accountID: 7, token: "synthetic-token")
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(request.url?.path, "/api/im/send-receipt"); XCTAssertEqual(request.httpMethod, "POST")
        let text = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("name=\"conversation_id\"")); XCTAssertTrue(text.contains("name=\"client_message_id\""))
        XCTAssertTrue(text.contains(clientID)); XCTAssertFalse(text.contains("name=\"content\"")); XCTAssertEqual(wire.requests.count, 1)
    }
    func testNotFoundIsOnlyAnExplicitFoundFalseWithNullMessage() async throws {
        let wire = Wire(); wire.body = #"{"code":200,"data":{"found":false,"message":null}}"#
        let result = try await receipt(wire).read(try intent(), accountID: 7, token: "synthetic-token")
        XCTAssertEqual(result, .notFound)
    }
    func testFoundRequiresMatchingClientIDSenderConversationTypeAndContent() async throws {
        let wire = Wire(); wire.body = found()
        let result = try await receipt(wire).read(try intent(), accountID: 7, token: "synthetic-token")
        guard case .found(let message) = result else { return XCTFail("expected found") }
        XCTAssertEqual(message.id, 90); XCTAssertEqual(message.senderID, 7)
        for bad in [found(sender: 8), found(content: "other"), found(client: String(repeating: "cd", count: 16)), found(type: 2), found(conversation: 6)] {
            wire.body = bad
            do { _ = try await receipt(wire).read(try intent(), accountID: 7, token: "synthetic-token"); XCTFail("must reject mismatch") }
            catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
        }
    }
    func testMissingMessageKeyAndGarbageAreMalformedNeverNotFound() async throws {
        let wire = Wire()
        for body in [#"{"code":200,"data":{"found":false}}"#, "not json", #"{"code":200,"data":{"found":true,"message":null}}"#] {
            wire.body = body
            do { let result = try await receipt(wire).read(try intent(), accountID: 7, token: "synthetic-token"); XCTFail("unexpected \(result)") }
            catch { XCTAssertEqual(error as? APIError, .malformedResponse, body) }
        }
    }
    func testHTTPAndBusinessFailuresSurfaceAsReadFailuresAndRevokeOnlyTheExactSet() async throws {
        let wire = Wire(); wire.status = 403; wire.body = #"{"code":403,"msg":"no"}"#
        do { _ = try await receipt(wire).read(try intent(), accountID: 7, token: "synthetic-token"); XCTFail() }
        catch {
            let failure = try XCTUnwrap(error as? MessagingReadFailure)
            XCTAssertEqual(failure.httpStatus, 403); XCTAssertTrue(OrdinaryIMSendReceipt.revokesRead(failure))
        }
        wire.status = 200; wire.body = #"{"code":500,"msg":"busy"}"#
        do { _ = try await receipt(wire).read(try intent(), accountID: 7, token: "synthetic-token"); XCTFail() }
        catch {
            let failure = try XCTUnwrap(error as? MessagingReadFailure)
            XCTAssertEqual(failure.code, 500); XCTAssertFalse(OrdinaryIMSendReceipt.revokesRead(failure))
        }
        wire.body = #"{"code":200,"data":{"found":false,"message":null}}"#
        do { _ = try await receipt(wire).read(try intent(), accountID: 0, token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .invalidRequest) }
    }
}
#endif
