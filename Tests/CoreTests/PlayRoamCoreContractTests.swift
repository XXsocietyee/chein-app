import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class PlayRoamContractTransport: HTTPTransport, @unchecked Sendable {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
    }
}

/// Pins the play-roam mini-program calls this branch touches.
/// History is `GET /api/roam/passport/history`. Rank is `GET /api/rank/list`.
/// Gift claim stays a named money write and is not sent.
final class PlayRoamCoreContractTests: XCTestCase {
    @MainActor
    func testPassportHistoryRequestMatchesMiniProgram() throws {
        let base = URL(string: "https://example.test")!
        let first = try RoamPassportHistoryReadRoute.history(before: nil).request(baseURL: base, token: "tok-1234")
        XCTAssertEqual(first.httpMethod, "GET")
        XCTAssertEqual(first.url?.path, "/api/roam/passport/history")
        XCTAssertEqual(query(first), [URLQueryItem(name: "limit", value: "30")])
        let page = try RoamPassportHistoryReadRoute.history(before: "12").request(baseURL: base, token: "tok-1234")
        XCTAssertEqual(query(page), [URLQueryItem(name: "before", value: "12"), URLQueryItem(name: "limit", value: "30")])
        XCTAssertThrowsError(try RoamPassportHistoryReadRoute.history(before: "0").request(baseURL: base, token: "tok-1234"))
        XCTAssertFalse(PlayRoamRound2Service.paths.contains("api/roam/history/list"))
    }

    @MainActor
    func testRankListQueryMatchesMiniProgram() async {
        let transport = PlayRoamContractTransport()
        let service = PlayRoamRound2Service(baseURL: URL(string: "https://example.test")!, token: { "tok-1234" }, transport: transport)
        _ = await service.fetchLeaderboard(JourneyLeaderboardScopeQuery(scope: "city", topicID: 9, cityCode: "310100", scopeID: "310100", period: "week"))
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/rank/list")
        let items = Dictionary(uniqueKeysWithValues: query(request).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["scope"] ?? "", "city")
        XCTAssertEqual(items["scopeId"] ?? "", "310100")
        XCTAssertEqual(items["period"] ?? "", "week")
        XCTAssertNil(items["topicId"])
        XCTAssertNil(items["cityCode"])
        XCTAssertNil(items["teamId"])
        XCTAssertEqual(JourneyRankBoardContract.query(scope: "world", scopeID: "", period: "0").map(\.name), ["scope"])
    }

    func testReportAndSettleReasonCodes() {
        let notFound = envelope(#"{"code":404,"reasonCode":"RUN_NOT_FOUND","msg":"gone"}"#, status: 404)
        XCTAssertEqual(notFound.reasonCode, "RUN_NOT_FOUND")
        XCTAssertEqual(JourneyReportRead.reject(notFound, surface: .report), .gone)
        XCTAssertEqual(JourneyReportRead.reject(notFound, surface: .settle), .gone)
        let other = envelope(#"{"code":404,"msg":"missing"}"#, status: 404)
        XCTAssertNil(other.reasonCode)
        XCTAssertEqual(JourneyReportRead.reject(other, surface: .report), .failed)
        XCTAssertEqual(JourneyReportRead.reject(other, surface: .settle), .failed)
        let mismatch = envelope(#"{"code":409,"reasonCode":"RUN_SCOPE_MISMATCH"}"#, status: 200)
        XCTAssertEqual(JourneyReportRead.reject(mismatch, surface: .report), .gone)
        XCTAssertEqual(JourneyReportRead.reject(mismatch, surface: .settle), .failed)
        let denied = envelope(#"{"code":403,"msg":"no"}"#, status: 200)
        XCTAssertEqual(JourneyReportRead.reject(denied, surface: .report), .denied("no"))
        let auth = envelope(#"{"code":401}"#, status: 401)
        XCTAssertEqual(JourneyReportRead.reject(auth, surface: .report), .auth)
        XCTAssertEqual(JourneyReportRead.reject(auth, surface: .settle), .auth)
        let ready = envelope(#"{"code":200,"data":{"runId":7}}"#, status: 200)
        XCTAssertNil(JourneyReportRead.reject(ready, surface: .report))
        XCTAssertTrue(JourneyReportRead.runDisagrees(asked: "8", answered: "7"))
        XCTAssertFalse(JourneyReportRead.runDisagrees(asked: "7", answered: nil))
        XCTAssertNil(envelope(#"{"code":500,"reasonCode":1}"#, status: 200).reasonCode)
    }

    func testSeatsSessionAndInviteHold() {
        XCTAssertEqual(JourneySeatsSessionGate.phase(hasValidSession: false, envelope: nil), .auth)
        let denied = envelope(#"{"code":403,"msg":"席位管理仅购票人可看"}"#, status: 200)
        XCTAssertEqual(JourneySeatsSessionGate.phase(hasValidSession: true, envelope: denied), .denied)
        let failed = envelope(#"{"code":500,"msg":"席位暂未加载"}"#, status: 200)
        XCTAssertEqual(JourneySeatsSessionGate.phase(hasValidSession: true, envelope: failed), .failed)
        let ready = envelope(#"{"code":200,"data":{"seatCount":2}}"#, status: 200)
        XCTAssertEqual(JourneySeatsSessionGate.phase(hasValidSession: true, envelope: ready), .ready)
        let hold = JourneyHeldSeatInviteRule.hold(invitationID: "44", token: "share-token")
        XCTAssertEqual(hold?.invitationID, "44")
        XCTAssertNotNil(JourneyHeldSeatInviteRule.afterRead(hold: hold, seats: [.init(invitationID: "44", state: "INVITED")]))
        XCTAssertNil(JourneyHeldSeatInviteRule.afterRead(hold: hold, seats: [.init(invitationID: "44", state: "CLAIMED")]))
        XCTAssertNil(JourneyHeldSeatInviteRule.afterRead(hold: hold, seats: [.init(invitationID: "8", state: "INVITED")]))
        XCTAssertNil(JourneyHeldSeatInviteRule.hold(invitationID: "44", token: nil))
    }

    func testGiftClaimStaysMoneyOffAndClassifiesLandingAnswers() throws {
        let transport = PlayRoamContractTransport()
        let source = try JourneyLoopSource(configuration: APIConfiguration(baseURL: URL(string: "https://example.test")!),
                                            transport: transport, endpointClass: .nonProduction)
        XCTAssertThrowsError(try source.giftClaim(token: "gift-token", requestID: "giftclaim1", sessionToken: "tok-1234")) { error in
            XCTAssertEqual(error as? JourneyRefusal, .moneyOff)
        }
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(JourneyLoopSource.journey(.giftClaim).method, "POST")
        XCTAssertEqual(JourneyLoopSource.journey(.giftClaim).path, "/api/marketing/product/gifts/claim")
        XCTAssertTrue(JourneyLoopSource.journey(.giftClaim).json)
        XCTAssertTrue(JourneyLoopSource.journey(.giftClaim).money)
        XCTAssertFalse(JourneyLoopSource.moneyWritesEnabled)
        XCTAssertEqual(JourneyRequestKey.giftClaim("0123456789abcdefghijklmnopQR"), "journey-claim:gift:456789abcdefghijklmnopQR")
        XCTAssertEqual(JourneyGiftClaimBody.fields(token: "gift-token", requestID: "giftclaim1"),
                       ["requestId": "giftclaim1", "token": "gift-token"])
        XCTAssertNil(JourneyGiftClaimBody.fields(token: "gift-token", requestID: ""))
        XCTAssertEqual(JourneyLandingClaim.gift(JourneyEnvelope.networkFailure, targetID: "9"), .unconfirmed)
        let refused = envelope(#"{"code":409,"msg":"已领取"}"#, status: 200)
        XCTAssertEqual(JourneyLandingClaim.gift(refused, targetID: "9"), .refused(message: "已领取", buyOwn: false))
        XCTAssertEqual(JourneyLandingClaim.seat(refused, canBuyOwn: true), .refused(message: "已领取", buyOwn: true))
        let claimed = envelope(#"{"code":200,"data":{"seatNo":3}}"#, status: 200)
        XCTAssertEqual(JourneyLandingClaim.gift(claimed, targetID: "9"), .giftClaimed(canView: true))
        XCTAssertEqual(JourneyLandingClaim.gift(claimed, targetID: "0"), .giftClaimed(canView: false))
        XCTAssertEqual(JourneyLandingClaim.seat(claimed, canBuyOwn: false), .seatClaimed(seatNo: "3"))
        let lost = envelope(#"{"code":500}"#, status: 500)
        XCTAssertEqual(JourneyLandingClaim.seat(lost, canBuyOwn: true), .unconfirmed)
    }

    func testRankMenuChoicesAndReportLinkCodes() {
        let menu = JourneyRankBoardContract.menu(topicID: "12", cityCode: "310100", countryCode: "cn", clubID: "7", teamID: "4")
        XCTAssertEqual(menu.tabs.map(\.kind), [.quest, .team])
        XCTAssertEqual(menu.tabs.map(\.scopeID), ["12", "4"])
        XCTAssertEqual(menu.more.map(\.kind), [.city, .country, .world, .club])
        XCTAssertEqual(menu.more.map(\.scopeID), ["310100", "CN", "", "7"])
        let bare = JourneyRankBoardContract.menu(topicID: "0", cityCode: "bad code", countryCode: "CHN", clubID: "x", teamID: nil)
        XCTAssertTrue(bare.tabs.isEmpty)
        XCTAssertEqual(bare.more.map(\.kind), [.world])
        let codes = JourneyRankBoardContract.LinkCodes.parse(["cityCode": "310100", "countryCode": "cn", "clubId": "0"])
        XCTAssertEqual(codes.cityCode, "310100")
        XCTAssertEqual(codes.countryCode, "cn")
        XCTAssertEqual(codes.clubID, "")
        let choices = Data(#"{"choices":[{"key":"SOLO"},{"key":"SHARED_TEAM","teamCapacity":{"teamId":"15","joinedCount":1}}]}"#.utf8)
        XCTAssertEqual(JourneyRankBoardContract.teamID(choicesJSON: choices), "15")
        XCTAssertNil(JourneyRankBoardContract.teamID(choicesJSON: Data(#"{"choices":[]}"#.utf8)))
    }

    func testPendingCheckInKeepsTheUnknownAttempt() throws {
        let store = RoamPendingCheckInMemory()
        let key = try XCTUnwrap(RoamPendingCheckInJournal.storageKey(ownerID: "7", poiID: "9"))
        XCTAssertEqual(key, "cy_roam_poi_checkin_pending:v1:7:9")
        XCTAssertNil(RoamPendingCheckInJournal.storageKey(ownerID: "0", poiID: "9"))
        let began = try RoamPendingCheckInJournal.begin(store, key: key, ownerID: "7", poiID: "9", attemptID: "a1", reverify: false)
        XCTAssertFalse(began.uncertain)
        XCTAssertThrowsError(try RoamPendingCheckInJournal.begin(store, key: key, ownerID: "7", poiID: "9", attemptID: "a2", reverify: false))
        let marked = try RoamPendingCheckInJournal.markUncertain(store, key: key, ownerID: "7", poiID: "9")
        XCTAssertEqual(marked?.attemptID, "a1")
        XCTAssertEqual(marked?.uncertain, true)
        store.set(Data("photo".utf8), forKey: RoamPendingCheckInJournal.photoKey(key))
        XCTAssertEqual(
            RoamPendingCheckInJournal.step(code: "500", message: "答案不正确", receiptAccepted: false, unknownBefore: true),
            .keepPreviousUnknown(message: "答案不正确"))
        XCTAssertEqual(try RoamPendingCheckInJournal.read(store, key: key, ownerID: "7", poiID: "9")?.attemptID, "a1")
        XCTAssertEqual(
            RoamPendingCheckInJournal.step(code: "500", message: "答案不正确", receiptAccepted: false, unknownBefore: false),
            .clear)
        XCTAssertEqual(
            RoamPendingCheckInJournal.step(code: "500", message: "别的失败", receiptAccepted: false, unknownBefore: true),
            .unknown)
        XCTAssertTrue(RoamPendingCheckInJournal.receiptAccepted(code: "200", poiID: "9", data: ["needRedeem": false, "completed": true]))
        XCTAssertFalse(RoamPendingCheckInJournal.receiptAccepted(code: "200", poiID: "9", data: ["needRedeem": true]))
        XCTAssertTrue(RoamPendingCheckInJournal.receiptAccepted(code: "200", poiID: "9", data: ["needRedeem": true, "couponId": "3", "poiId": "9"]))
        XCTAssertFalse(RoamPendingCheckInJournal.receiptAccepted(code: "200", poiID: "9", data: ["needRedeem": true, "couponId": "3", "poiId": "8"]))
        XCTAssertTrue(try RoamPendingCheckInJournal.clear(store, key: key, ownerID: "7", poiID: "9", attemptID: "a1"))
        XCTAssertNil(store.data(forKey: key))
        XCTAssertNil(store.data(forKey: RoamPendingCheckInJournal.photoKey(key)))
    }

    private func envelope(_ json: String, status: Int) -> JourneyEnvelope {
        JourneyLoopSource.envelope(data: Data(json.utf8), status: status, receiptReread: false)
    }

    private func query(_ request: URLRequest) -> [URLQueryItem] {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }
}
