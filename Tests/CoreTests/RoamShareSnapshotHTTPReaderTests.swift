#if canImport(QuestifyCore)
import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor final class RoamShareSnapshotHTTPReaderTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var reply: Result<(Data, Int), Error> = .success((Data(), 200))
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return try reply.get() }
    }
    private let base = URL(string: "https://example.invalid/base/")!
    private func token() throws -> RoamShareToken { try XCTUnwrap(RoamShareToken(RoamShareSnapshotFixtureReader.readyToken)) }

    func testUnapprovedReaderIsUnavailableAndSendsNothing() async throws {
        let wire = Wire()
        let reader = RoamShareSnapshotHTTPReader(baseURL: base, transport: wire, isApproved: { false })
        let outcome = await reader.snapshot(try token())
        XCTAssertEqual(outcome, .unavailable)
        XCTAssertTrue(wire.requests.isEmpty)
    }
    func testApprovedReaderSendsAnonymousGetAndResolvesReady() async throws {
        let wire = Wire()
        wire.reply = .success((Data(RoamShareSnapshotFixtureReader.readyBody.utf8), 200))
        let reader = RoamShareSnapshotHTTPReader(baseURL: base, transport: wire, isApproved: { true })
        let outcome = await reader.snapshot(try token())
        guard case .ready(let snapshot) = outcome else { return XCTFail("expected ready") }
        XCTAssertEqual(snapshot.routeName, "Demo lane footprints")
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].httpMethod, "GET")
        XCTAssertEqual(wire.requests[0].url?.absoluteString, "https://example.invalid/base/api/roam/share/snapshot?token=" + (try token()).value)
        XCTAssertNil(wire.requests[0].value(forHTTPHeaderField: "Authorization"))
        XCTAssertFalse(wire.requests[0].httpShouldHandleCookies)
    }
    func testGoneAndRetryableOutcomes() async throws {
        let wire = Wire()
        let reader = RoamShareSnapshotHTTPReader(baseURL: base, transport: wire, isApproved: { true })
        wire.reply = .success((Data(#"{"code":500,"msg":"gone"}"#.utf8), 200))
        let gone = await reader.snapshot(try token())
        XCTAssertEqual(gone, .gone)
        wire.reply = .success((Data(), 502))
        let badGateway = await reader.snapshot(try token())
        XCTAssertEqual(badGateway, .error)
        wire.reply = .failure(URLError(.notConnectedToInternet))
        let offline = await reader.snapshot(try token())
        XCTAssertEqual(offline, .error)
    }
    func testGrantRevokedMidFlightDropsTheResponse() async throws {
        let wire = Wire()
        wire.reply = .success((Data(RoamShareSnapshotFixtureReader.readyBody.utf8), 200))
        var approved = true
        let reader = RoamShareSnapshotHTTPReader(baseURL: base, transport: wire, isApproved: { approved })
        let first = await reader.snapshot(try token())
        guard case .ready = first else { return XCTFail("expected ready") }
        approved = false
        let second = await reader.snapshot(try token())
        XCTAssertEqual(second, .unavailable)
        XCTAssertEqual(wire.requests.count, 1)
    }
}
#endif
