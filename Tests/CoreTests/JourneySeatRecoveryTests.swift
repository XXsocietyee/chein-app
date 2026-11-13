import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Seat invite, cancel, and claim keep one request id. An unconfirmed answer is re-read with that same id.
final class JourneySeatRecoveryTests: XCTestCase {
    func testInviteSavesTheRequestIdBeforeSendAndClearsItWhenTheServerAnswers() async throws {
        let store = JourneyMemoryRequestStore()
        let wire = Wire(body: Data(#"{"code":200,"data":{"invitationId":8,"token":"share-token","replayed":false}}"#.utf8))
        let source = try make(wire, store: store)
        let key = JourneyRequestKey.seatInvite("15")
        wire.onSend = { XCTAssertEqual(store.read(key), "seatinv-loyw3v28-abcd1234") }
        let result = try await source.seatInvite(registrationID: "15", token: "session-token")
        XCTAssertTrue(result.ok)
        XCTAssertFalse(result.receiptReread)
        XCTAssertNil(store.read(key))
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/play/seat-invitations/invite")
        XCTAssertEqual(json(wire.requests[0]), ["registrationId": "15", "requestId": "seatinv-loyw3v28-abcd1234"])
        XCTAssertEqual(wire.requests[0].value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testUnconfirmedInviteKeepsTheIdAndTheRereadPostsThatSameId() async throws {
        let store = JourneyMemoryRequestStore()
        let wire = Wire(statuses: [503, 503, 200], bodies: [
            Data(#"{"code":503,"msg":"busy"}"#.utf8),
            Data(#"{"code":503,"msg":"busy"}"#.utf8),
            Data(#"{"code":200,"data":{"invitationId":8,"token":"share-token","replayed":true}}"#.utf8)
        ])
        let source = try make(wire, store: store)
        let key = JourneyRequestKey.seatInvite("15")
        let first = try await source.seatInvite(registrationID: "15", token: "session-token")
        XCTAssertTrue(first.unconfirmed)
        XCTAssertFalse(first.receiptReread)
        let saved = store.read(key)
        XCTAssertEqual(saved, "seatinv-loyw3v28-abcd1234")

        let again = try await source.seatInvite(registrationID: "15", token: "session-token")
        XCTAssertEqual(json(wire.requests[1])["requestId"], saved)
        XCTAssertTrue(again.unconfirmed)
        XCTAssertEqual(store.read(key), saved)

        let receipt = try await source.rereadSeatInvite(registrationID: "15", token: "session-token")
        XCTAssertTrue(receipt.ok)
        XCTAssertTrue(receipt.receiptReread)
        XCTAssertEqual(json(wire.requests[2])["requestId"], saved)
        XCTAssertEqual(wire.requests.map(\.url?.path), Array(repeating: "/api/play/seat-invitations/invite", count: 3))
        XCTAssertNil(store.read(key))
    }

    func testTransportFailureKeepsTheIdAndAConflictClearsIt() async throws {
        let store = JourneyMemoryRequestStore()
        let wire = Wire(); wire.failFirst = true
        let source = try make(wire, store: store)
        let key = JourneyRequestKey.seatClaim("seat-token-value")
        let failed = try await source.seatClaim(token: "seat-token-value", sessionToken: "session-token")
        XCTAssertTrue(failed.netFail)
        XCTAssertEqual(failed.code, "fail")
        XCTAssertEqual(failed.message, "网络异常，请重试")
        XCTAssertEqual(store.read(key), "seat-loyw3v28-abcd1234")
        XCTAssertEqual(wire.requests[0].url?.path, "/api/play/seat-invitations/claim")
        XCTAssertEqual(json(wire.requests[0])["token"], "seat-token-value")

        wire.failFirst = false
        wire.body = Data(#"{"code":409,"msg":"席位邀请已过期"}"#.utf8)
        let conflict = try await source.rereadSeatClaim(token: "seat-token-value", sessionToken: "session-token")
        XCTAssertFalse(conflict.unconfirmed)
        XCTAssertTrue(conflict.receiptReread)
        XCTAssertEqual(json(wire.requests[1])["requestId"], "seat-loyw3v28-abcd1234")
        XCTAssertNil(store.read(key))
    }

    func testRereadWithoutASavedIdSendsNothing() async throws {
        let wire = Wire()
        let source = try make(wire, store: JourneyMemoryRequestStore())
        do {
            _ = try await source.rereadSeatCancel(invitationID: "44", token: "session-token")
            XCTFail("missing id")
        } catch JourneyRefusal.noSavedRequest {}
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testCancelUsesTheSavedIdInThePathAndBody() async throws {
        let store = JourneyMemoryRequestStore()
        let wire = Wire(body: Data(#"{"code":"200","data":{"invitationId":44}}"#.utf8))
        let source = try make(wire, store: store)
        let key = JourneyRequestKey.seatCancel("44")
        store.write(key, "seatcxl-kept-id")
        let result = try await source.seatCancel(invitationID: "44", token: "session-token")
        XCTAssertTrue(result.ok)
        XCTAssertNil(store.read(key))
        XCTAssertEqual(wire.requests[0].url?.path, "/api/play/seat-invitations/44/cancel")
        XCTAssertEqual(json(wire.requests[0]), ["requestId": "seatcxl-kept-id"])
    }

    func testClaimKeyUsesTheLastTwentyFourCharacters() async throws {
        let store = JourneyMemoryRequestStore()
        let wire = Wire(statuses: [500], bodies: [Data(#"{"code":500}"#.utf8)])
        let source = try make(wire, store: store)
        let token = String(repeating: "a", count: 30) + "TAIL"
        let first = try await source.seatClaim(token: token, sessionToken: "session-token")
        XCTAssertTrue(first.unconfirmed)
        let suffix = String(token.suffix(24))
        XCTAssertEqual(suffix.count, 24)
        XCTAssertNotNil(store.read(JourneyRequestKey.seatClaim(token)))
        XCTAssertEqual(JourneyRequestKey.seatClaim(token), "journey-claim:seat:" + suffix)
        let other = String(repeating: "z", count: 10) + suffix
        XCTAssertEqual(store.read(JourneyRequestKey.seatClaim(other)), store.read(JourneyRequestKey.seatClaim(token)))
    }

    func testABadRegistrationDoesNotSaveOrSend() async throws {
        let store = JourneyMemoryRequestStore()
        let wire = Wire()
        let source = try make(wire, store: store)
        do {
            _ = try await source.seatInvite(registrationID: "0", token: "session-token")
            XCTFail("zero")
        } catch JourneyRefusal.invalidRequest {}
        do {
            _ = try await source.seatCancel(invitationID: "44/1", token: "session-token")
            XCTFail("slash")
        } catch JourneyRefusal.invalidRequest {}
        XCTAssertTrue(wire.requests.isEmpty)
        XCTAssertNil(store.read(JourneyRequestKey.seatInvite("0")))
        XCTAssertNil(store.read(JourneyRequestKey.seatCancel("44/1")))
    }

    private func make(_ wire: Wire, store: JourneyMemoryRequestStore) throws -> JourneyLoopSource {
        try JourneyLoopSource(configuration: APIConfiguration(baseURL: URL(string: "https://example.test")!),
                              transport: wire, store: store, nowMillis: { 1_700_000_000_000 }, entropy: { "abcd1234" })
    }

    private func json(_ request: URLRequest) -> [String: String] {
        guard let data = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: data) else { return [:] }
        return object as? [String: String] ?? [:]
    }

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var bodies: [Data]
        var statuses: [Int]
        var body: Data
        var failFirst = false
        var onSend: () -> Void = {}
        init(body: Data = Data(#"{"code":200}"#.utf8), statuses: [Int] = [], bodies: [Data] = []) {
            self.body = body
            self.statuses = statuses
            self.bodies = bodies
        }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            onSend()
            if failFirst { failFirst = false; throw URLError(.timedOut) }
            let status = statuses.isEmpty ? 200 : statuses.removeFirst()
            let payload = bodies.isEmpty ? body : bodies.removeFirst()
            return (payload, status)
        }
    }
}
