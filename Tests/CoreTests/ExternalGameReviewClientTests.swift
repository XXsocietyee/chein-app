import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class ExternalGameReviewClientTests: XCTestCase {
    func testCatalogDownloadAndUnknownSubmitKeepsTheRequestID() async throws {
        let wire = ExternalGameWire()
        wire.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/signing-key") {
                let raw = Data(repeating: 7, count: 32).base64EncodedString()
                let body = #"{"code":200,"data":{"keyId":"ed25519-1","algorithm":"Ed25519","configured":true,"publicKeyRaw":"\#(raw)"}}"#
                return (Data(body.utf8), 200)
            }
            if path.hasSuffix("/catalog") {
                let body = #"{"code":200,"data":{"items":[{"submissionId":9,"gameId":"rpg.one","version":"1.0.0","name":"One","contentRating":"4+","sha256":"abc","monetization":"NONE","permissions":["storage"],"allowedDomains":[]}],"hasMore":false,"nextCursor":null}}"#
                return (Data(body.utf8), 200)
            }
            if request.httpMethod == "POST" { throw URLError(.timedOut) }
            return (Data("{}".utf8), 500)
        }
        let client = try make(wire)
        let key = await client.signingKey(token: "session-token")
        XCTAssertEqual(key?.algorithm, "Ed25519")
        XCTAssertEqual(key?.publicKeyRaw?.count, 32)
        let catalog = await client.catalog(token: "session-token")
        guard case .loaded(let rows) = catalog else { return XCTFail("catalog failed") }
        XCTAssertEqual(rows.map(\.gameID), ["rpg.one"])
        XCTAssertEqual(rows.first?.author, nil)
        let archive = Data(#"{"manifest":{"id":"rpg.one"},"files":{"index.html":"aGkh"}}"#.utf8)
        let first = await client.submit(archive: archive, token: "session-token")
        guard case .unknown(let requestID) = first else { return XCTFail("expected unknown") }
        XCTAssertFalse(requestID.isEmpty)
        let second = await client.submit(archive: archive, token: "session-token")
        guard case .unknown(let again) = second else { return XCTFail("expected unknown") }
        XCTAssertEqual(again, requestID)
        let posted = wire.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posted.count, 2)
        let body = String(decoding: posted[0].httpBody ?? Data(), as: UTF8.self)
        XCTAssertTrue(body.contains("name=\"monetization\""))
        XCTAssertTrue(body.contains("NONE"))
        XCTAssertTrue(body.contains(requestID))
        XCTAssertFalse(ExternalGameReviewClient.bridgeActions.contains("requestPayment"))
    }

    func testConfirmedRejectIsNotSuccessAndZipIsNotSubmitted() async throws {
        let wire = ExternalGameWire()
        wire.handler = { _ in (Data(#"{"code":409,"msg":"GAME_ID_TAKEN"}"#.utf8), 409) }
        let client = try make(wire)
        let archive = Data(#"{"manifest":{"id":"rpg.one"},"files":{}}"#.utf8)
        let outcome = await client.submit(archive: archive, token: "session-token")
        guard case .refused(let message, let requestID) = outcome else { return XCTFail("expected refusal") }
        XCTAssertEqual(message, "GAME_ID_TAKEN")
        XCTAssertFalse(requestID.isEmpty)
        XCTAssertTrue(ExternalGameReviewClient.workshopBinaryIsNotThisAPI(Data([0x50, 0x4b, 0x03, 0x04])))
        let zip = await client.submit(archive: Data([0x50, 0x4b, 0x03, 0x04]), token: "session-token")
        guard case .refused = zip else { return XCTFail("zip must not be sent") }
        XCTAssertFalse(wire.requests.contains { $0.httpMethod == "POST" && ($0.httpBody ?? Data()).starts(with: [0x50, 0x4b]) })
    }

    func testGrantKeyFoldsTheCatalogGameID() {
        XCTAssertEqual(
            ChinaReviewedRouteCapability.externalGameGrantKey("/api/external-game/catalog/rpg.one/package"),
            "/api/external-game/catalog/{}/package")
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/external-game/reports"))
        XCTAssertTrue(ChinaReviewedRouteCapability.externalGameOwnerGrant.contains("/api/external-game/signing-key"))
    }

    private func make(_ wire: ExternalGameWire) throws -> ExternalGameReviewClient {
        let configuration = try APIConfiguration(baseURL: URL(string: "https://example.test/")!)
        return ExternalGameReviewClient(configuration: configuration, transport: wire, nowMillis: { 1_700_000_000_000 }, entropy: { "abcd1234" })
    }
}

private final class ExternalGameWire: HTTPTransport {
    var requests: [URLRequest] = []
    var handler: (URLRequest) throws -> (Data, Int) = { _ in (Data("{}".utf8), 500) }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return try handler(request)
    }
}
