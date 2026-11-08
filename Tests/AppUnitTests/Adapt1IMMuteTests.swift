import Foundation
import XCTest
@testable import Questify

final class Adapt1IMMuteTests: XCTestCase {
    private let requestID = "11111111-2222-3333-4444-555555555555"
    private let paths: Set<String> = [Adapt1IMPath.mute, Adapt1IMPath.conversations]

    private func intent(muted: Bool) throws -> OrdinaryIMMuteIntent {
        try OrdinaryIMMuteIntent(scope: adapt1Scope(), requestID: requestID, muted: muted)
    }

    func testDefaultsAreOffAndSendNothing() async throws {
        let transport = Adapt1FakeTransport()
        let off = Adapt1IMBackendAdapter(configuration: try APIConfiguration(baseURL: URL(string: "https://api.example.test/prod-api")!), transport: transport)
        do { _ = try await off.setMute(intent(muted: true), token: "tok"); XCTFail() } catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        do { _ = try await off.muteState(scope: adapt1Scope(), token: "tok"); XCTFail() } catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        let noWrites = try adapt1Adapter(transport, writes: false, paths: paths)
        do { _ = try await noWrites.setMute(intent(muted: true), token: "tok"); XCTFail() } catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testAllowlistIsExactAndCannotBeExtended() async throws {
        let transport = Adapt1FakeTransport()
        let adapter = try adapt1Adapter(transport, paths: [Adapt1IMPath.mute, "api/im/mute-state", "api/im/mute/", "api/im/delete"])
        do { _ = try await adapter.setMute(intent(muted: true), token: "tok"); XCTFail("conversations readback not enabled") }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(Adapt1IMPath.all, ["api/im/conversations", "api/im/read", "api/im/mute", "api/im/report", "api/im/send"])
    }

    func testBackendBodyWithoutDataIsAcceptedThenConfirmedByReadback() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.bareSuccess, 200), (Adapt1Fixture.conversations(muted: 1), 200)])
        let result = try await adapt1Adapter(transport, paths: paths).setMute(intent(muted: true), token: "tok")
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(transport.requests.count, 2)
        let write = transport.requests[0]
        XCTAssertEqual(write.url?.path, "/prod-api/api/im/mute")
        XCTAssertEqual(write.httpMethod, "POST")
        XCTAssertEqual(write.value(forHTTPHeaderField: "Authorization"), "tok")
        XCTAssertTrue(write.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
        XCTAssertEqual(adapt1Fields(write), ["conversation_id": "9", "muted": "1", "request_id": requestID])
        XCTAssertEqual(transport.requests[1].url?.path, "/prod-api/api/im/conversations")
    }

    func testUnmuteRequestedWritesZero() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.bareSuccess, 200), (Adapt1Fixture.conversations(muted: 0), 200)])
        let result = try await adapt1Adapter(transport, paths: paths).setMute(intent(muted: false), token: "tok")
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(adapt1Fields(transport.requests[0])["muted"], "0")
    }

    func testReadbackMismatchRowMissingAbsentFieldAndFailureAreUnknownOutcome() async throws {
        let cases: [[(body: String, status: Int)]] = [
            [(Adapt1Fixture.bareSuccess, 200), (Adapt1Fixture.conversations(muted: 0), 200)],
            [(Adapt1Fixture.bareSuccess, 200), (Adapt1Fixture.conversations(id: 10, muted: 1), 200)],
            [(Adapt1Fixture.bareSuccess, 200), (Adapt1Fixture.emptyConversations, 200)],
            [(Adapt1Fixture.bareSuccess, 200), (Adapt1Fixture.conversations(muted: nil), 200)],
            [(Adapt1Fixture.bareSuccess, 200), (Adapt1Fixture.businessError, 200)],
            [(Adapt1Fixture.bareSuccess, 200), ("<html>", 502)]
        ]
        for script in cases {
            let transport = Adapt1FakeTransport(script)
            do { _ = try await adapt1Adapter(transport, paths: paths).setMute(intent(muted: true), token: "tok"); XCTFail("must not report applied") }
            catch { XCTAssertEqual(error as? IMCapabilityGap, .unknownOutcome) }
            XCTAssertEqual(transport.requests.count, 2, "no retry of the write")
        }
    }

    func testBusinessErrorOnWriteSurfacesCodeAndSkipsReadback() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.error("无权操作该会话"), 200)])
        do { _ = try await adapt1Adapter(transport, paths: paths).setMute(intent(muted: true), token: "tok"); XCTFail() }
        catch let failure as MessagingReadFailure { XCTAssertEqual(failure.code, 500); XCTAssertEqual(failure.message, "无权操作该会话") }
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testUnauthorizedCodeIsClassified() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.error("认证失败", code: 401), 200)])
        do { _ = try await adapt1Adapter(transport, paths: paths).setMute(intent(muted: true), token: "tok"); XCTFail() }
        catch let failure as MessagingReadFailure { XCTAssertTrue(failure.isUnauthorized) }
    }

    func testMuteStateIsDerivedFromConversationsRowWithAppSideSource() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.conversations(type: 2, muted: 1, extraRows: [30]), 200)])
        let state = try await adapt1Adapter(transport, writes: false, paths: [Adapt1IMPath.conversations]).muteState(scope: adapt1Scope(), token: "tok")
        XCTAssertEqual(state, Adapt1MuteCurrent(source: "app-derived-im-conversations-v1", ownerMemberID: "7", conversationID: 9, conversationType: 2, muted: true))
        XCTAssertNotEqual(state.source, "original-ordinary-im-mute-state-v1")
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests[0].url?.path, "/prod-api/api/im/conversations")
    }

    func testMuteStateMissingRowOrMutedIsMalformed() async throws {
        for body in [Adapt1Fixture.emptyConversations, Adapt1Fixture.conversations(id: 10), Adapt1Fixture.conversations(muted: nil), Adapt1Fixture.conversations(type: 9)] {
            let transport = Adapt1FakeTransport([(body, 200)])
            do { _ = try await adapt1Adapter(transport, writes: false, paths: [Adapt1IMPath.conversations]).muteState(scope: adapt1Scope(), token: "tok"); XCTFail() }
            catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
        }
    }

    func testExistingStrictMuteContractIsUnchangedAndStillRejectsTheBareBackendBody() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.bareSuccess, 200)])
        let strict = try IMExpandedService(configuration: APIConfiguration(baseURL: URL(string: "https://api.example.test/prod-api")!),
            transport: transport, approvedMediaOrigins: [], writesEnabled: true, enabledPaths: ["api/im/mute"], ordinaryMuteRequestEnabled: true)
        do { _ = try await strict.performOrdinaryMute(intent(muted: true), token: "tok"); XCTFail("strict contract needs data receipt") } catch { }
    }
}
