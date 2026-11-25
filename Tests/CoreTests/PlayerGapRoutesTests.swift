import XCTest
@testable import QuestifyCore

/// G7/G8: one stub reply per route; method, path, and body match the mini-program call.
@MainActor final class PlayerGapRoutesTests: XCTestCase {
    private final class Stub: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var replies: [String: (String, Int)] = [:]
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let path = request.url!.path
            guard let reply = replies.first(where: { path.hasSuffix($0.key) })?.value else { throw URLError(.notConnectedToInternet) }
            return (Data(reply.0.utf8), reply.1)
        }
        var last: URLRequest { requests.last! }
        var lastJSON: [String: Any] { (try? JSONSerialization.jsonObject(with: last.httpBody ?? Data())) as? [String: Any] ?? [:] }
        var lastForm: String { String(data: last.httpBody ?? Data(), encoding: .utf8) ?? "" }
    }
    private let base = URL(string: "https://example.test/native")!
    private func make(_ stub: Stub, token: String? = "synthetic-token") -> PlayerGapService {
        PlayerGapService(baseURL: base, accountID: 7, token: { token }, transport: stub)
    }
    private func ok(_ data: String) -> (String, Int) { (#"{"code":200,"msg":"done","data":\#(data)}"#, 200) }

    func testEveryServicePathIsGrantedInChinaGate() {
        for path in PlayerGapService.paths {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        // Owner 2026-11-14: receiver status and the payout-account read are status reads, admitted on production.
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/personal-receiver/status"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/payout-account"))
        // r8 CLB-settlement-05: mine is a POST {} read, admitted on production. Withdraw stays closed.
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/settlement/mine"))
        for money in ["/api/registration/payment-readiness", "/api/club/personal-receiver/bind", "/api/club/personal-receiver/unbind",
                      "/api/registration/pay", "/api/pay/create",
                      "/api/wallet/withdraw", "/api/club/settlement/withdraw", "/api/merchant/payout-account/save"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(money), money)
        }
    }

    func testClassifyOnlyFourHundredsRefuse() {
        XCTAssertEqual(PlayerGapReply.classify(data: Data(#"{"code":409,"msg":"x"}"#.utf8), status: 200), .refused(code: 409, message: "x"))
        XCTAssertEqual(PlayerGapReply.classify(data: Data(#"{"code":500}"#.utf8), status: 200), .unknown)
        XCTAssertEqual(PlayerGapReply.classify(data: Data(), status: 502), .unknown)
        XCTAssertEqual(PlayerGapReply.classify(data: Data(#"{"code":401}"#.utf8), status: 200), .unauthorized)
    }

    func testNoTokenSendsNothing() async {
        let stub = Stub()
        let reply = await make(stub, token: nil).teamTrailState(activityID: 3)
        XCTAssertEqual(reply, .unknown)
        XCTAssertTrue(stub.requests.isEmpty)
    }

    func testActiveForRoamCard() async {
        let stub = Stub()
        stub.replies["api/official/active-for-roam"] = ok(#"[{"id":5,"title":" Spring walk ","coverImg":"https://c/1.png"},{"id":6,"title":""}]"#)
        let card = await make(stub).activeOfficialForRoam()
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertEqual(stub.last.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        XCTAssertEqual(card, OfficialRoamActiveCard(firstTitle: "Spring walk", count: 1, cover: "https://c/1.png", eventID: 5))
        stub.replies["api/official/active-for-roam"] = ok(#"[{"id":5,"title":"A"},{"id":6,"title":"B"}]"#)
        let many = await make(stub).activeOfficialForRoam()
        XCTAssertEqual(many?.count, 2); XCTAssertNil(many?.eventID)
    }

    func testSignupCommandKeepsRequestIDUntilTerminalReceipt() async {
        let stub = Stub(), defaults = UserDefaults(suiteName: "gap-signup-\(UUID())")!
        let store = OfficialSignupCommandDefaultsStore(defaults: defaults)
        stub.replies["api/official/signup-command"] = ("", 502)
        let flow = OfficialSignupCommandFlow(service: make(stub), store: store, accountID: 7, eventID: 71)
        let first = await flow.start()
        XCTAssertNil(first); XCTAssertEqual(flow.phase, .unknown)
        XCTAssertEqual(stub.last.url?.path, "/native/api/official/signup-command")
        let requestID = stub.lastJSON["requestId"] as? String
        XCTAssertEqual(stub.lastJSON["targetId"] as? String, "71"); XCTAssertEqual(stub.lastJSON["action"] as? String, "signup")
        let r1 = await flow.start()
        XCTAssertNil(r1, "an open intention is never replaced")
        stub.replies["api/official/signup-command/query"] = ok(#"{"requestId":"\#(requestID!)","state":"APPLIED"}"#)
        let r2 = await flow.query()
        XCTAssertEqual(r2, .applied)
        XCTAssertEqual(stub.lastJSON.keys.sorted(), ["requestId"])
        XCTAssertEqual(stub.lastJSON["requestId"] as? String, requestID)
        XCTAssertFalse(flow.hasPending)
        // A receipt for another request id is not a result.
        stub.replies["api/official/signup-command"] = ok(#"{"requestId":"ffffffffffffffffffffffffffffffff","state":"APPLIED"}"#)
        _ = await flow.start()
        XCTAssertEqual(flow.phase, .unknown)
        stub.replies["api/official/signup-command/cancel"] = ok(#"{"requestId":"\#(stub.lastJSON["requestId"] as! String)","state":"CANCELLED"}"#)
        let r3 = await flow.cancel()
        XCTAssertEqual(r3, .cancelled)
        XCTAssertEqual(stub.last.url?.path, "/native/api/official/signup-command/cancel")
    }

    func testSignupRejectedSafetyBlocked() async {
        let stub = Stub(), store = OfficialSignupCommandDefaultsStore(defaults: UserDefaults(suiteName: "gap-signup-\(UUID())")!)
        let flow = OfficialSignupCommandFlow(service: make(stub), store: store, accountID: 7, eventID: 71)
        stub.replies["api/official/signup-command"] = ("", 200)
        _ = await flow.start()
        let id = stub.lastJSON["requestId"] as! String
        stub.replies["api/official/signup-command"] = ok(#"{"requestId":"\#(id)","state":"REJECTED","message":"no","errorCode":"ORIENT_SAFETY_BLOCKED"}"#)
        let r4 = await flow.retry()
        XCTAssertEqual(r4, .rejected)
        XCTAssertEqual(stub.lastJSON["requestId"] as? String, id)
        XCTAssertTrue(flow.safetyBlocked)
        XCTAssertEqual(flow.phase, .settled(.rejected, message: "no"))
    }

    func testTeamInviteQRCode() async {
        let stub = Stub()
        stub.replies["api/team/invite-qrcode"] = ok(#"{"teamId":4,"inviteCode":" AB23CD ","qrState":"READY","qrcodeUrl":"https://q/1.png"}"#)
        let ready = await make(stub).teamInviteQRCode(teamID: 4)
        XCTAssertEqual(stub.lastJSON["teamId"] as? Int, 4)
        XCTAssertEqual(stub.last.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(ready, .ready(qr: URL(string: "https://q/1.png")!, code: "AB23CD"))
        stub.replies["api/team/invite-qrcode"] = ok(#"{"inviteCode":"AB23CD","qrState":"UNAVAILABLE"}"#)
        let codeOnly = await make(stub).teamInviteQRCode(teamID: 4)
        XCTAssertEqual(codeOnly, .code("AB23CD"))
        stub.replies["api/team/invite-qrcode"] = (#"{"code":403,"msg":"not a member"}"#, 200)
        let refused = await make(stub).teamInviteQRCode(teamID: 4)
        XCTAssertEqual(refused, .error(message: "not a member"))
        XCTAssertEqual(TeamInviteQRView.normalizeJoinCode(" ab 23cd "), "AB23CD")
        XCTAssertNil(TeamInviteQRView.normalizeJoinCode("AB1CD0"))
    }

    func testTeamTrailConsentSyncAndFinish() async {
        let stub = Stub(), service = make(stub)
        let trail = TeamTrailModel(service: service, activityID: 9)
        stub.replies["api/team/trail/state"] = ok(#"{"available":true,"share":true,"decided":false}"#)
        await trail.load()
        XCTAssertEqual(stub.last.url?.query, "activityId=9")
        XCTAssertTrue(trail.needsConsent)
        stub.replies["api/team/trail/consent"] = ("", 500)
        let r5 = await trail.consent(false)
        XCTAssertFalse(r5)
        XCTAssertFalse(trail.state.share, "an unconfirmed off stays off locally")
        XCTAssertEqual(stub.lastJSON["share"] as? Bool, false)
        stub.replies["api/team/trail/consent"] = ok(#"{"available":true,"share":true}"#)
        let r6 = await trail.consent(true)
        XCTAssertTrue(r6)
        XCTAssertTrue(trail.canRun)
        stub.replies["api/team/trail/sync"] = ok(#"{"available":true,"share":true,"teams":[{"key":"t1","name":"Fox","done":2,"pts":[[31.2,121.4],[31.3,121.5]]},{"key":"t2","pts":[]}]}"#)
        let points = (0..<50).map { TeamTrailPoint(latitude: 31 + Double($0) / 1000, longitude: 121) }
        let firstTick = await trail.tick(points: points, done: 3)
        XCTAssertTrue(firstTick)
        XCTAssertEqual((stub.lastJSON["pts"] as? [[Double]])?.count, 40)
        XCTAssertEqual(stub.lastJSON["done"] as? Int, 3)
        XCTAssertEqual(trail.teams.map(\.id), ["t1"])
        XCTAssertEqual(trail.teams.first?.initial, "F")
        let secondTick = await trail.tick(points: points, done: 3)
        XCTAssertTrue(secondTick)
        XCTAssertEqual((stub.lastJSON["pts"] as? [[Double]])?.count, 0, "only points since the last success")
        await trail.finish()
        XCTAssertEqual(stub.lastJSON["finished"] as? Bool, true)
        XCTAssertTrue(trail.teams.isEmpty)
    }

    func testJoinInfoHostRequestAndPrecheck() async {
        let stub = Stub(), service = make(stub)
        stub.replies["api/registration/join_info"] = ok("null")
        let join = await service.joinInfo(memberID: 7)
        XCTAssertEqual(stub.lastForm, "member_id=7"); XCTAssertEqual(join?.hasJoin, false)
        stub.replies["api/club/event-ops/host/request"] = ok("{}")
        _ = await service.requestHost(activityID: 3, ticketID: 8)
        XCTAssertEqual(stub.lastJSON["activityId"] as? Int, 3); XCTAssertEqual(stub.lastJSON["ticketId"] as? Int, 8)
        stub.replies["api/activity/publish_precheck"] = (#"{"code":403,"msg":"not a publisher"}"#, 200)
        let denied = await service.publishPrecheck(merchantHost: true)
        XCTAssertEqual(denied, .denied("not a publisher"))
        XCTAssertEqual(stub.lastForm, "scope=MERCHANT")
        stub.replies["api/activity/publish_precheck"] = ok("null")
        let allowed = await service.publishPrecheck(merchantHost: false)
        XCTAssertEqual(allowed, .allowed)
    }

    func testLeadMemberArriveAndBroadcast() async {
        let stub = Stub(), service = make(stub)
        stub.replies["api/club/lead/arrive"] = ok("null")
        let arrived = await service.leadArrive(activityID: 3, latitude: 31.25, longitude: 121.5)
        XCTAssertEqual(arrived.data, .null)
        XCTAssertEqual(stub.lastForm, "activityId=3&latitude=31.25&longitude=121.5")
        let count = stub.requests.count
        _ = await service.leadArrive(activityID: 3, latitude: 91, longitude: 0)
        _ = await service.leadBroadcast(activityID: 3, text: "  ")
        XCTAssertEqual(stub.requests.count, count, "invalid fixes and empty text send nothing")
        stub.replies["api/club/lead/broadcast"] = ok("null")
        _ = await service.leadBroadcast(activityID: 3, text: "go")
        XCTAssertEqual(stub.lastForm, "activityId=3&text=go")
    }

    func testLikeStateReadback() async {
        let stub = Stub(), service = make(stub)
        stub.replies["api/club/post/like-state"] = ok(#"{"id":5,"clubId":2,"isLiked":true,"likeCount":4}"#)
        let state = await service.clubPostLikeState(postID: 5, clubID: 2)
        XCTAssertEqual(state?.isLiked, true); XCTAssertEqual(state?.likeCount, 4)
        stub.replies["api/club/post/like-state"] = ok(#"{"id":6,"clubId":2,"isLiked":true}"#)
        let foreign = await service.clubPostLikeState(postID: 5, clubID: 2)
        XCTAssertNil(foreign)
    }

    func testCityNodesMediaCardAndPlayerCode() async {
        let stub = Stub(), service = make(stub)
        stub.replies["api/city/nodes/favorites"] = ok(#"[{"poiId":3,"name":"Gate"},{"poiId":0}]"#)
        let favorites = await service.favoriteCityNodes()
        XCTAssertEqual(favorites?.map(\.id), [3])
        stub.replies["api/city/nodes/merchant/12"] = ok(#"{"poiId":3,"name":"Gate","favorited":true}"#)
        let node = await service.merchantCityNode(merchantID: 12)
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertEqual(node, CityMerchantNode(.object(["poiId": .integer(3), "name": .string("Gate"), "favorited": .bool(true)])))
        stub.replies["api/city/nodes/3/favorite"] = ok(#"{"favorited":false}"#)
        let toggled = await service.toggleCityNodeFavorite(poiID: 3)
        XCTAssertEqual(toggled, false)
        stub.replies["api/media/asset/attribution"] = ok(#"{"attribution":"Photo by Lin","aiGenerated":true}"#)
        let credit = await service.assetCredit(reference: "https://m/1.jpg")
        XCTAssertEqual(credit, "Photo by Lin")
        XCTAssertEqual(URLComponents(url: stub.last.url!, resolvingAgainstBaseURL: false)?.queryItems, [.init(name: "reference", value: "https://m/1.jpg")])
        stub.replies["api/object-card/rename"] = ok(#"{"title":"Lamp"}"#)
        let renamed = await service.renameObjectCard(id: 4, title: "Lamp ")
        XCTAssertEqual(renamed, .renamed("Lamp"))
        XCTAssertEqual(stub.lastForm, "id=4&title=Lamp%20")
        stub.replies["api/object-card/rename"] = (#"{"code":400,"msg":"too long"}"#, 200)
        let failed = await service.renameObjectCard(id: 4, title: "x")
        XCTAssertEqual(failed, .failed(message: "too long"))
        stub.replies["api/user/player-code"] = ok(#"{"qr":" https://q/me.png "}"#)
        let qr = await service.playerCode()
        XCTAssertEqual(qr, URL(string: "https://q/me.png"))
        XCTAssertEqual(stub.last.httpMethod, "POST")
        stub.replies["api/user/player-code"] = ok(#"{"qr":"data:image/png;base64,xx"}"#)
        let fake = await service.playerCode()
        XCTAssertNil(fake)
    }
}
