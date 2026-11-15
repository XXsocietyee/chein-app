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

    func testUncoveredReadsPinGetPaths() async throws {
        let wire = ExternalGameWire()
        wire.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/submissions/mine") { return (Data(Self.routeAbsent.utf8), 404) }
            return (Data(), 500)
        }
        let client = try make(wire)
        let mine = await client.submissions(token: "session-token")
        XCTAssertNil(mine)
        let detail = await client.downloadApproved(gameID: "rpg.one", token: "session-token")
        XCTAssertNil(detail)
        let package = await client.downloadPackage(downloadPath: "/api/external-game/catalog/rpg.one/package?sourceVersion=1", token: "session-token")
        XCTAssertNil(package)
        XCTAssertEqual(wire.requests.map(\.httpMethod), ["GET", "GET", "GET"])
        XCTAssertEqual(wire.requests[0].url?.path, "/api/external-game/submissions/mine")
        XCTAssertEqual(wire.requests[0].url?.query, "limit=20")
        XCTAssertEqual(wire.requests[1].url?.path, "/api/external-game/catalog/rpg.one")
        XCTAssertEqual(wire.requests[2].url?.path, "/api/external-game/catalog/rpg.one/package")
        XCTAssertEqual(wire.requests[2].url?.query, "sourceVersion=1")
    }

    func testCancelResubmitAndReportPinPostPaths() async throws {
        let wire = ExternalGameWire()
        wire.handler = { _ in (Data(), 500) }
        let client = try make(wire)
        let archive = Data(#"{"manifest":{"id":"rpg.one"},"files":{"index.html":"aGkh"}}"#.utf8)
        let cancelled = await client.cancel(submissionID: "9", token: "session-token")
        guard case .unknown = cancelled else { return XCTFail("lost cancel stays unknown") }
        let resubmitted = await client.resubmit(submissionID: "9", archive: archive, token: "session-token")
        guard case .unknown = resubmitted else { return XCTFail("lost resubmit stays unknown") }
        let draft = ExternalGameReportDraft(gameID: "rpg.one", version: nil, sha256: nil, reasonCode: "BROKEN", detail: nil, blocked: false)
        let reported = await client.report(draft, token: "session-token")
        guard case .unknown = reported else { return XCTFail("lost report stays unknown") }
        XCTAssertEqual(wire.requests.map(\.httpMethod), ["POST", "POST", "POST"])
        XCTAssertEqual(wire.requests[0].url?.path, "/api/external-game/submissions/9/cancel")
        XCTAssertEqual(wire.requests[1].url?.path, "/api/external-game/submissions/9/resubmit")
        XCTAssertEqual(wire.requests[2].url?.path, "/api/external-game/reports")
    }

    /// Captured TEST 8120 body, not a success payload.
    /// `docs/release/e2e/20261113b/requests.batch1.log` lines 5, 8 and 11.
    func testCapturedRouteAbsentBodyDoesNotDecodeAGame() {
        let data = Data(Self.routeAbsent.utf8)
        let key = ExternalGameReviewClient.signingKey(from: data)
        XCTAssertEqual(key?.configured, false)
        XCTAssertNil(key?.publicKeyRaw)
        XCTAssertNil(ExternalGameReviewClient.catalogPage(from: data))
        XCTAssertNil(ExternalGameReviewClient.catalogFact(from: data))
        XCTAssertNil(ExternalGameReviewClient.submissionFact(from: data))
    }

    private static let routeAbsent = #"{"msg":"请求路径不存在","code":404}"#

    func testGrantKeyFoldsTheCatalogGameID() {
        XCTAssertEqual(
            ChinaReviewedRouteCapability.externalGameGrantKey("/api/external-game/catalog/rpg.one/package"),
            "/api/external-game/catalog/{}/package")
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/external-game/reports"))
        XCTAssertTrue(ChinaReviewedRouteCapability.externalGameOwnerGrant.contains("/api/external-game/signing-key"))
        XCTAssertEqual(
            ChinaReviewedRouteCapability.externalGameGrantKey("/api/external-game/sessions/EGS_abc/result"),
            "/api/external-game/sessions/{}/result")
    }

    func testSignedSessionResultAndMoneyGateForOrders() async throws {
        let wire = ExternalGameWire()
        wire.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/sessions/start") {
                let body = #"{"code":200,"data":{"sessionId":"EGS_01","gameId":"rpg.one","nodeId":501,"nonce":"nonce99","issuedAtMs":1700000000000,"sessionSignature":"deadbeef"}}"#
                return (Data(body.utf8), 200)
            }
            if path.hasSuffix("/sessions/EGS_01/result") {
                let body = #"{"code":200,"data":{"sessionId":"EGS_01","gameId":"rpg.one","nodeId":501,"passed":true,"score":92,"xpAwarded":35,"medalRank":1,"nodeCompleted":true,"trafficEligible":true,"replayed":false}}"#
                return (Data(body.utf8), 200)
            }
            if path.hasSuffix("/orders") {
                let body = #"{"code":200,"data":{"orderNo":"EGO_01","gameId":"rpg.one","amountFen":1990,"creatorShareBps":7000,"channelFeeBearer":0,"channelFeeFen":12,"creatorNetFen":1381,"platformShareFen":597,"provider":"TEST_WALLET","state":"PAID","licenseStatus":"ACTIVE"}}"#
                return (Data(body.utf8), 200)
            }
            return (Data("{}".utf8), 500)
        }
        let client = try make(wire)
        let ticket = await client.startSession(gameID: "rpg.one", nodeID: 501, token: "session-token")
        XCTAssertEqual(ticket?.sessionID, "EGS_01")
        XCTAssertEqual(ticket?.nonce, "nonce99")
        guard let ticket else { return XCTFail("expected ticket") }
        let outcome = await client.submitSignedResult(ticket: ticket, passed: true, score: 92, durationMs: 12000, digest: "dig1", token: "session-token")
        XCTAssertEqual(outcome?.xpAwarded, 35)
        XCTAssertEqual(outcome?.medalRank, 1)
        XCTAssertEqual(outcome?.nodeCompleted, true)

        // Orders fail closed when ReleaseMoneyWriteSwitch is off (default)
        let previousDerivation = ReleaseMoneyWriteSwitch.testDerivation
        defer { ReleaseMoneyWriteSwitch.testDerivation = previousDerivation }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        let closedOrder = await client.purchaseGame(gameID: "rpg.one", token: "session-token")
        XCTAssertNil(closedOrder)
        XCTAssertFalse(wire.requests.contains { $0.url?.path.hasSuffix("/orders") == true })

        // With TEST payment derivation enabled, purchase hits /orders on non-production host
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let paidOrder = await client.purchaseGame(gameID: "rpg.one", token: "session-token")
        XCTAssertEqual(paidOrder?.orderNo, "EGO_01")
        XCTAssertEqual(paidOrder?.creatorNetFen, 1381)
    }

    func testBridgeHandlerAndPlayNodeExternalGameBindingDecode() throws {
        var progress: [String: String] = [:]
        let manifest = ExternalGameManifest(
            id: "rpg.one",
            name: "One",
            version: "1.0.0",
            entry: "index.html",
            permissions: ["storage"],
            sha256: String(repeating: "a", count: 64),
            signature: "sig"
        )
        let req = Data(#"{"apiVersion":"1.0","action":"submitResult","payload":{"passed":"true","score":"96","digest":"d1"}}"#.utf8)
        let resp = ExternalGameBridgeHandler.handle(rawJSON: req, manifest: manifest, progressStore: &progress)
        XCTAssertTrue(resp.ok)
        XCTAssertEqual(resp.data?["passed"], "true")
        XCTAssertEqual(resp.data?["score"], "96")

        let nodeJSON = Data(#"{"nodeId":501,"name":"港口小游戏","externalGame":{"gameId":"rpg.one","gameName":"One","version":"1.0.0","minScore":80,"requirePass":true}}"#.utf8)
        let node = try JSONDecoder().decode(PlayNode.self, from: nodeJSON)
        XCTAssertEqual(node.externalGame?.gameID, "rpg.one")
        XCTAssertEqual(node.externalGame?.minScore, 80)
        XCTAssertEqual(node.externalGame?.requirePass, true)
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
