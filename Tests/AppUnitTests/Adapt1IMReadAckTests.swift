import Foundation
import XCTest
@testable import Questify

final class Adapt1IMReadAckTests: XCTestCase {
    private let ackID = "ack-cursor-00000001"
    private let paths: Set<String> = [Adapt1IMPath.read, Adapt1IMPath.conversations]

    func testReadCursorSendsReadToNotLastMessageIdAndReadsBackUnread() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.bareSuccess, 200), (Adapt1Fixture.conversations(unread: 2), 200)])
        let outcome = try await adapt1Adapter(transport, paths: paths).readCursor(conversationID: 9, readTo: 4, requestID: ackID, token: "tok")
        XCTAssertEqual(outcome, .acceptedUnverified(unreadAfter: 2))
        let write = transport.requests[0]
        XCTAssertEqual(write.url?.path, "/prod-api/api/im/read")
        XCTAssertEqual(write.httpMethod, "POST")
        XCTAssertEqual(adapt1Fields(write), ["conversation_id": "9", "read_to": "4", "request_id": ackID])
        XCTAssertNil(adapt1Fields(write)["last_message_id"])
        XCTAssertTrue(write.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
        XCTAssertEqual(transport.requests[1].url?.path, "/prod-api/api/im/conversations")
    }

    func testReadCursorZeroIsAllowedAndRowOrUnreadMissingIsUnknown() async throws {
        let ok = Adapt1FakeTransport([(Adapt1Fixture.bareSuccess, 200), (Adapt1Fixture.conversations(unread: 0), 200)])
        let outcome = try await adapt1Adapter(ok, paths: paths).readCursor(conversationID: 9, readTo: 0, requestID: ackID, token: "tok")
        XCTAssertEqual(outcome, .acceptedUnverified(unreadAfter: 0))
        for body in [Adapt1Fixture.emptyConversations, Adapt1Fixture.conversations(id: 12), Adapt1Fixture.businessError] {
            let transport = Adapt1FakeTransport([(Adapt1Fixture.bareSuccess, 200), (body, 200)])
            do { _ = try await adapt1Adapter(transport, paths: paths).readCursor(conversationID: 9, readTo: 4, requestID: ackID, token: "tok"); XCTFail() }
            catch { XCTAssertEqual(error as? IMCapabilityGap, .unknownOutcome) }
        }
    }

    func testInvalidInputsAndClosedGatesSendNothing() async throws {
        let transport = Adapt1FakeTransport()
        let adapter = try adapt1Adapter(transport, paths: paths)
        for (id, to, key) in [(0, 1, ackID), (9, -1, ackID), (9, 1, "short")] {
            do { _ = try await adapter.readCursor(conversationID: id, readTo: to, requestID: key, token: "tok"); XCTFail() }
            catch { XCTAssertEqual(error as? APIError, .invalidRequest) }
        }
        let off = Adapt1IMBackendAdapter(configuration: try APIConfiguration(baseURL: URL(string: "https://api.example.test/prod-api")!), transport: transport)
        do { _ = try await off.readCursor(conversationID: 9, readTo: 1, requestID: ackID, token: "tok"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testBusinessErrorOnReadSurfacesAndSkipsReadback() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.businessError, 200)])
        do { _ = try await adapt1Adapter(transport, paths: paths).readCursor(conversationID: 9, readTo: 4, requestID: ackID, token: "tok"); XCTFail() }
        catch let failure as MessagingReadFailure { XCTAssertEqual(failure.code, 500) }
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testNotificationAckIsResentAsFormNotJSON() async throws {
        let command = try NativeChannelNotificationCommand(ackChannelID: 9, lastMessageID: 4, requestID: ackID)
        XCTAssertNotNil(String(data: command.body, encoding: .utf8)?.range(of: "last_message_id"), "existing command keeps its JSON body")
        let transport = Adapt1FakeTransport([(Adapt1Fixture.bareSuccess, 200), (Adapt1Fixture.conversations(unread: 1), 200)])
        let outcome = try await adapt1Adapter(transport, paths: paths).ack(command, token: "tok")
        XCTAssertEqual(outcome, .acceptedUnverified(unreadAfter: 1))
        let write = transport.requests[0]
        XCTAssertEqual(write.url?.path, "/prod-api/api/im/read")
        XCTAssertEqual(adapt1Fields(write), ["conversation_id": "9", "read_to": "4", "request_id": ackID])
        XCTAssertNotEqual(write.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testOnlyAckCommandsAreAdapted() async throws {
        let mute = try NativeChannelNotificationCommand(scope: NativeChannelNotificationScope(type: 1, value: "9"), minutes: 30, requestID: ackID)
        let transport = Adapt1FakeTransport()
        do { _ = try await adapt1Adapter(transport, paths: paths).ack(mute, token: "tok"); XCTFail("timed mute has no backend duration") } catch { }
        XCTAssertTrue(transport.requests.isEmpty)
    }
}
