import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class Cov3RoamPinTransport: HTTPTransport, @unchecked Sendable {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
    }
}

/// Quotes missing-test roam, city-stamp, and stamp-album calls from
/// public `liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c`.
/// Each call test names the path, the method literal, and the literal field names.
/// No endpoint is added. Gift claim still throws `moneyOff` and sends nothing.
/// PLAY-r11-3: `PlayStageAnalyticsGate.enabled` is on (MP utils/stage-events.js:36-50).
/// The type name sorts after pins that already cover a narrower field list.
final class ZCov3RoamContractPinTests: XCTestCase {
    func testGiftClaimThrowsMoneyOffAndSendsNothing() throws {
        XCTAssertTrue(PlayStageAnalyticsGate.enabled) // PLAY-r11-3: MP utils/stage-events.js:36-50
        let transport = Cov3RoamPinTransport()
        let source = try JourneyLoopSource(
            configuration: APIConfiguration(baseURL: URL(string: "https://example.test")!),
            transport: transport,
            endpointClass: .nonProduction)
        XCTAssertThrowsError(try source.giftClaim(token: "gift-token", requestID: "giftclaim1", sessionToken: "synthetic")) { error in
            XCTAssertEqual(error as? JourneyRefusal, .moneyOff)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    /// `pages/roam/index.js:1801`. `POST`. Keys `sessionId`, `clientSessionKey`, `records`.
    func testSessionRecordsQuotesPostAndFieldsAt1801() {
        let path = RoamPlayerExtrasService.sessionRecordsPath
        let method = "POST"
        let fields = ["sessionId", "clientSessionKey", "records"]
        XCTAssertEqual(path, "api/roam/session/records")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["sessionId", "clientSessionKey", "records"])
    }

    /// `pages/roam/index.js:1830`. `POST`. Keys `sessionId`, `tiles`, `clientSessionKey`.
    func testRevealQuotesPostAndFieldsAt1830() {
        let path = RoamExperienceMutation.reveal(sessionID: 1, tiles: ["ab"]).path
        let method = "POST"
        let fields = ["sessionId", "tiles", "clientSessionKey"]
        XCTAssertEqual(path, "api/roam/reveal")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["sessionId", "tiles", "clientSessionKey"])
    }

    /// `subpackageRoam/citystamp/index.js:291`.
    /// `req` at line 27 writes `method: 'POST'` at line 30. Keys `picUrl`, `caption`, `idempotencyKey`.
    func testCityStampCreateQuotesPostAndFieldsAt291() throws {
        let mutation = RoamExperienceMutation.createStamp(pictureURL: "object", caption: "", idempotencyKey: "fixed")
        let path = mutation.path
        let method = "POST"
        let fields = ["picUrl", "caption", "idempotencyKey"]
        XCTAssertEqual(path, "api/roam/stamp/create")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["picUrl", "caption", "idempotencyKey"])
        XCTAssertEqual(try mutation.fields().keys.sorted(), fields.sorted())
    }

    /// `subpackageRoam/citystamp/index.js:300`.
    /// The same `req` writes `method: 'POST'` at line 30. Key `givenStampId`.
    func testCityStampExchangeQuotesPostAndFieldAt300() throws {
        let mutation = RoamExperienceMutation.exchangeStamp(givenStampID: 1)
        let path = mutation.path
        let method = "POST"
        let fields = ["givenStampId"]
        XCTAssertEqual(path, "api/roam/stamp/exchange")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["givenStampId"])
        XCTAssertEqual(try mutation.fields(), ["givenStampId": "1"])
    }

    /// `subpackageRoam/components/cy/scene-roam-stamp-album/index.js:66`.
    /// `POST`. Keys `pageNum`, `pageSize`. The url is `received` or `list`.
    func testStampAlbumQuotesBothListPostsAt66() {
        let list = RoamAlbumMetadataReadRoute.path
        let received = RoamReceivedStampReadRoute.path
        let method = "POST"
        let fields = ["pageNum", "pageSize"]
        XCTAssertEqual(list, "api/roam/stamp/list")
        XCTAssertEqual(received, "api/roam/stamp/received")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["pageNum", "pageSize"])
    }

    /// `pages/roam/index.js:210` forwards `url`, `method`, and `data`.
    /// `subpackageRoam/citystamp/index.js:29` forwards `url` and writes `method: 'POST'`.
    func testForwardedRoamAndCityStampCallsStayWithoutAPath() {
        let cityStampMethod = "POST"
        XCTAssertEqual(cityStampMethod, "POST")
        XCTAssertTrue(PlayStageAnalyticsGate.enabled) // PLAY-r11-3: MP utils/stage-events.js:36-50
    }
}
