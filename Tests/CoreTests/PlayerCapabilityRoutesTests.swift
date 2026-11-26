import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// G4/G5: one stub transport per route; each test checks the method, path, body shape the mini-program sends,
/// and that the reply is read the way the mini-program reads it.
private final class RouteStub: HTTPTransport {
    var replies: [String: (String, Int)] = [:]
    var requests: [URLRequest] = []
    var fail = false
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if fail { throw URLError(.timedOut) }
        let path = request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? ""
        let reply = replies[path] ?? (#"{"code":200,"data":null}"#, 200)
        return (Data(reply.0.utf8), reply.1)
    }
    var last: URLRequest { requests.last! }
    var lastJSON: [String: Any] { (try? JSONSerialization.jsonObject(with: last.httpBody ?? Data())) as? [String: Any] ?? [:] }
    var lastForm: [String: String] {
        var out: [String: String] = [:]
        for pair in String(decoding: last.httpBody ?? Data(), as: UTF8.self).split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            out[parts[0]] = parts.count > 1 ? parts[1].removingPercentEncoding : ""
        }
        return out
    }
    func query(_ name: String) -> String? {
        URLComponents(url: last.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}

final class PlayerCapabilityRoutesTests: XCTestCase {
    private let base = URL(string: "https://example.test/native/")!
    private func client(_ stub: RouteStub) -> PlayerCapabilityClient {
        PlayerCapabilityClient(baseURL: base, token: "synthetic-token", transport: stub)
    }
    private func path(_ stub: RouteStub) -> String {
        stub.last.url!.path.replacingOccurrences(of: "/native/", with: "")
    }

    // MARK: Community trust

    func testContributionTaxonomyKeepsOnlyKnownIssueCodes() async throws {
        let stub = RouteStub()
        stub.replies["api/community-trust/contributions/taxonomy"] = (#"{"code":200,"data":{"contributionTypes":["ISSUE_REPORT"],"issueTypes":["CLOSED","WEIRD","OTHER"]}}"#, 200)
        let issues = try await CommunityTrustPlayerService(client: client(stub)).contributionIssueTypes()
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertEqual(path(stub), "api/community-trust/contributions/taxonomy")
        XCTAssertEqual(issues.map(\.code), ["CLOSED", "OTHER"])
        XCTAssertEqual(stub.last.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
    }

    func testContributionSubmitSendsIssueReportAndReadsReceipt() async throws {
        let stub = RouteStub()
        stub.replies["api/community-trust/contributions/submit"] = (#"{"code":200,"data":{"id":"88","reviewStatus":"PENDING"}}"#, 200)
        let receipt = try await CommunityTrustPlayerService(client: client(stub))
            .submitContribution(merchantID: 5, issueType: "ADDRESS", description: "  门牌号不对  ", idempotencyKey: "mct-5-abcdef")
        XCTAssertEqual(stub.last.httpMethod, "POST")
        XCTAssertEqual(path(stub), "api/community-trust/contributions/submit")
        XCTAssertEqual(stub.last.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(stub.lastJSON["contributionType"] as? String, "ISSUE_REPORT")
        XCTAssertEqual(stub.lastJSON["description"] as? String, "门牌号不对")
        XCTAssertNil(stub.lastJSON["evidenceAssetIds"])
        XCTAssertEqual(receipt.text, "受理编号 88，当前状态：待审核。")
        stub.replies["api/community-trust/contributions/submit"] = (#"{"code":500,"msg":"x"}"#, 200)
        do { _ = try await CommunityTrustPlayerService(client: client(stub)).submitContribution(merchantID: 5, issueType: "ADDRESS", description: "a", idempotencyKey: "mct-5-abcdef"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayerCapabilityFailure, .outcomeUnknown) }
    }

    func testSafetyTaxonomyRatingAndSummary() async throws {
        let stub = RouteStub()
        stub.replies["api/community-trust/safety/taxonomy"] = (#"{"code":"200","data":{"levels":["safe","UNSAFE","SAFE","OTHER"]}}"#, 200)
        let service = CommunityTrustPlayerService(client: client(stub))
        let levels = try await service.safetyLevels()
        XCTAssertEqual(levels.map(\.key), ["SAFE", "UNSAFE"])
        XCTAssertEqual(path(stub), "api/community-trust/safety/taxonomy")

        stub.replies["api/community-trust/safety/ratings"] = (#"{"code":200,"data":{"ratingId":9,"overallLevel":"SAFE","ratingPeriod":"2026-11"}}"#, 200)
        let text = try await service.submitSafetyRating(merchantID: 12, level: "SAFE", reason: " 灯很亮 ", idempotencyKey: "safety-12-x")
        XCTAssertEqual(path(stub), "api/community-trust/safety/ratings")
        XCTAssertEqual(stub.lastJSON["merchantId"] as? Int, 12)
        XCTAssertEqual(stub.lastJSON["reason"] as? String, "灯很亮")
        XCTAssertEqual(text, "你的感受：安心 · 评价周期 2026-11 · 受理编号 9")

        stub.replies["api/community-trust/safety/merchants/12"] = (#"{"code":200,"data":{"sampleStatus":"SUFFICIENT","level":"NEUTRAL","sampleCount":7,"windowDays":30}}"#, 200)
        let summary = await service.merchantSafety(merchantID: 12)
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertEqual(path(stub), "api/community-trust/safety/merchants/12")
        XCTAssertEqual(summary?.note, "近 30 天 7 人反馈，仅代表用户感受，不构成安全保证")
        stub.replies["api/community-trust/safety/merchants/12"] = (#"{"code":200,"data":{"sampleStatus":"INSUFFICIENT","level":"SAFE","sampleCount":1}}"#, 200)
        let hidden = await service.merchantSafety(merchantID: 12)
        XCTAssertNil(hidden)
    }

    func testReportAppealSendsTextOnlyAndReadsReceipt() async throws {
        let stub = RouteStub()
        stub.replies["api/community-trust/reports/appeal"] = (#"{"code":200,"data":{"reportId":31,"stage":"APPEALED"}}"#, 200)
        let text = try await CommunityTrustPlayerService(client: client(stub))
            .appeal(reportID: 31, reason: "处理不公", requestID: "rpa-31-abcdef", stageLabel: { CommunityTrustPlayerService.stageLabels[$0] })
        XCTAssertEqual(path(stub), "api/community-trust/reports/appeal")
        XCTAssertEqual(Set(stub.lastJSON.keys), ["reportId", "reason", "requestId"])
        XCTAssertEqual(text, "举报编号 31 · 当前阶段：申诉中")
    }

    func testReportAppealKeepsTheRequestIdAndDoesNotTreatUnknownAsSuccess() async throws {
        let first = try XCTUnwrap(CommunityTrustPlayerService.appealSubmission(existingRequestID: "", lockedReason: "", reason: "  处理不公  ", reportID: 31))
        let retry = try XCTUnwrap(CommunityTrustPlayerService.appealSubmission(existingRequestID: first.requestID, lockedReason: first.reason, reason: "换成另一段理由", reportID: 31))
        XCTAssertEqual(retry.requestID, first.requestID)
        XCTAssertEqual(retry.reason, "处理不公")
        XCTAssertNil(CommunityTrustPlayerService.appealSubmission(existingRequestID: "", lockedReason: "", reason: " ", reportID: 31))
        XCTAssertNil(CommunityTrustPlayerService.appealSubmission(existingRequestID: "", lockedReason: "", reason: String(repeating: "理", count: 1001), reportID: 31))
        XCTAssertNil(CommunityTrustPlayerService.appealSubmission(existingRequestID: "short", lockedReason: "处理不公", reason: "处理不公", reportID: 31))

        let stub = RouteStub()
        let service = CommunityTrustPlayerService(client: client(stub))
        stub.replies["api/community-trust/reports/appeal"] = (#"{"code":200,"data":{}}"#, 200)
        do {
            _ = try await service.appeal(reportID: 31, reason: "处理不公", requestID: first.requestID, stageLabel: { CommunityTrustPlayerService.stageLabels[$0] })
            XCTFail("unconfirmed receipt")
        } catch { XCTAssertEqual(error as? PlayerCapabilityFailure, .outcomeUnknown) }
        XCTAssertEqual(stub.lastJSON["requestId"] as? String, first.requestID)
        stub.fail = true
        do {
            _ = try await service.appeal(reportID: 31, reason: "处理不公", requestID: first.requestID, stageLabel: { CommunityTrustPlayerService.stageLabels[$0] })
            XCTFail("transport")
        } catch { XCTAssertEqual(error as? PlayerCapabilityFailure, .outcomeUnknown) }
        XCTAssertEqual(stub.requests.count, 2)
    }

    func testCommunityMineListsReadPostsAndBookmarks() async throws {
        let stub = RouteStub()
        let service = SquareService(configuration: try APIConfiguration(baseURL: base), transport: stub)
        for list in SquareMineList.allCases {
            stub.replies[list.path] = (#"{"code":200,"data":{"items":[],"hasMore":false}}"#, 200)
            let page = try await service.mine(list, token: "synthetic-token")
            XCTAssertEqual(stub.last.httpMethod, "GET")
            XCTAssertEqual(path(stub), "api/v1/community/me/\(list.rawValue)")
            XCTAssertEqual(stub.query("limit"), "20")
            XCTAssertFalse(page.hasMore)
        }
    }

    // MARK: Roam

    func testRoamSessionRecordsArchiveIsAFormPostWithJSONRecords() async throws {
        let stub = RouteStub()
        stub.replies["api/roam/session/records"] = (#"{"code":200,"data":{"sessionId":"44","evidenceType":"CLIENT_REPORTED","acceptedRecords":2}}"#, 200)
        let records = [RoamPlayerExtrasService.TileRecord(tile: "wtw3sjq", collectedAt: 1_700_000_000_000),
                       RoamPlayerExtrasService.TileRecord(tile: "wtw3sjr", collectedAt: 1_700_000_000_500)]
        let accepted = try await RoamPlayerExtrasService(client: client(stub)).archive(sessionID: 44, clientSessionKey: "k1", records: records)
        XCTAssertEqual(accepted, 2)
        XCTAssertEqual(path(stub), "api/roam/session/records")
        XCTAssertEqual(stub.last.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertEqual(stub.lastForm["sessionId"], "44")
        XCTAssertEqual(stub.lastForm["clientSessionKey"], "k1")
        XCTAssertEqual(stub.lastForm["records"], #"[{"collectedAt":1700000000000,"tile":"wtw3sjq"},{"collectedAt":1700000000500,"tile":"wtw3sjr"}]"#)
        XCTAssertFalse(RoamPlayerExtrasService.validRecords([.init(tile: "aaaaaaa", collectedAt: 1)]))
    }

    func testRoamShareRevokeAndShopVisitors() async throws {
        let stub = RouteStub()
        let service = RoamPlayerExtrasService(client: client(stub))
        let revoked = await service.revokeShareSnapshots()
        XCTAssertTrue(revoked)
        XCTAssertEqual(path(stub), "api/roam/share/revoke")
        XCTAssertEqual(stub.last.httpMethod, "POST")
        XCTAssertEqual(stub.last.httpBody, Data())
        stub.fail = true
        let failed = await service.revokeShareSnapshots()
        XCTAssertFalse(failed)
        stub.fail = false

        stub.replies["api/roam/shop/visitors"] = (#"{"code":200,"data":[{"sourceId":3,"total":4,"avatars":["https://a.test/1.png","ftp://x","https://a.test/2.png"]},{"sourceId":4,"total":0}]}"#, 200)
        let rows = await service.visitors(for: [.init(sourceType: 1, sourceID: 3), .init(sourceType: 1, sourceID: 3), .init(sourceType: 1, sourceID: 4)])
        XCTAssertEqual(path(stub), "api/roam/shop/visitors")
        XCTAssertEqual(stub.lastForm["sourceType"], "1")
        XCTAssertEqual(stub.lastForm["sourceIds"], "3,4")
        XCTAssertEqual(rows[.init(sourceType: 1, sourceID: 3)]?.faces.count, 2)
        XCTAssertEqual(rows[.init(sourceType: 1, sourceID: 3)]?.label, "4 人打过卡")
        XCTAssertNil(rows[.init(sourceType: 1, sourceID: 4)])
    }

    // MARK: Templates

    func testAdoptionRunsSourceAdoptDetailAndClearsTheJournal() async throws {
        let stub = RouteStub()
        let version = String(repeating: "a", count: 64)
        stub.replies["api/template/adoption-source"] = (#"{"code":200,"data":{"originalTemplateId":"17","sourceVersion":"\#(version)"}}"#, 200)
        var journal: TemplateAdoptionService.Record?
        let service = TemplateAdoptionService(client: client(stub))
        // adopt-draft echo depends on the minted request ID; answer from the journal.
        final class Echo: HTTPTransport {
            let inner: RouteStub; let version: String; var record: () -> TemplateAdoptionService.Record?
            init(_ inner: RouteStub, _ version: String, _ record: @escaping () -> TemplateAdoptionService.Record?) { self.inner = inner; self.version = version; self.record = record }
            func send(_ request: URLRequest) async throws -> (Data, Int) {
                let path = request.url!.path
                if path.hasSuffix("adopt-draft"), let record = record() {
                    inner.requests.append(request)
                    return (Data(#"{"code":200,"data":{"requestId":"\#(record.requestId)","sourceVersion":"\#(version)","originalTemplateId":"17","status":"COMPLETED","draftId":"501"}}"#.utf8), 200)
                }
                if path.hasSuffix("adoption-detail") {
                    inner.requests.append(request)
                    return (Data(#"{"code":200,"data":{"id":501,"advancedConfigJson":null}}"#.utf8), 200)
                }
                return try await inner.send(request)
            }
        }
        let echo = Echo(stub, version, { journal })
        let adopting = TemplateAdoptionService(client: PlayerCapabilityClient(baseURL: base, token: "synthetic-token", transport: echo))
        _ = service
        var cleared = false
        let outcome = await adopting.adopt(sourceID: 17, owner: 7, scope: "", load: { journal }, save: { journal = $0 }, clear: { cleared = true })
        guard case .ready = outcome else { return XCTFail("\(outcome)") }
        XCTAssertTrue(cleared)
        let paths = stub.requests.map { $0.url!.path.replacingOccurrences(of: "/native/", with: "") }
        XCTAssertEqual(paths, ["api/template/adoption-source", "api/template/adopt-draft", "api/template/adoption-detail"])
        let adopt = try XCTUnwrap(stub.requests[1].httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        XCTAssertEqual(adopt["originalTemplateId"] as? String, "17")
        XCTAssertEqual(adopt["requestId"] as? String, journal?.requestId)
    }

    func testAdoptionResumeReadsTheReceiptBeforeAnyResubmit() async throws {
        let stub = RouteStub()
        let record = TemplateAdoptionService.Record(schemaVersion: 1, owner: "7", scope: "", requestId: "adopt_1_x",
            sourceVersion: String(repeating: "b", count: 64), originalTemplateId: "17", draftId: nil)
        stub.replies["api/template/adoption-receipt"] = (#"{"code":200,"data":{"requestId":"adopt_1_x","sourceVersion":"\#(record.sourceVersion)","originalTemplateId":"17","status":"REJECTED","reason":"SOURCE_VERSION_CONFLICT"}}"#, 200)
        var cleared = false
        let outcome = await TemplateAdoptionService(client: client(stub)).adopt(sourceID: 17, owner: 7, scope: "",
            load: { record }, save: { _ in }, clear: { cleared = true })
        XCTAssertEqual(outcome, .rejected("原采用被拒绝：来源已改变或下架，请重新选择"))
        XCTAssertTrue(cleared)
        XCTAssertEqual(path(stub), "api/template/adoption-receipt")
        XCTAssertEqual(stub.query("requestId"), "adopt_1_x")
        XCTAssertEqual(stub.requests.count, 1)
    }

    func testAuthorDetailUsesMyInfoOnlyForMyScope() async throws {
        let stub = RouteStub()
        stub.replies["api/template/author-myinfo"] = (#"{"code":200,"data":{"id":5}}"#, 200)
        stub.replies["api/template/author-info"] = (#"{"code":200,"data":{"id":5}}"#, 200)
        let service = TemplateAdoptionService(client: client(stub))
        _ = try await service.authorDetail(templateID: 5, myScope: "MERCHANT")
        XCTAssertEqual(path(stub), "api/template/author-myinfo")
        XCTAssertEqual(stub.lastForm, ["id": "5", "scope": "MERCHANT"])
        _ = try await service.authorDetail(templateID: 5, myScope: nil)
        XCTAssertEqual(path(stub), "api/template/author-info")
        XCTAssertEqual(stub.lastForm, ["id": "5", "scope": ""])
    }

    func testBindingStatusBindSaveAsAndMarketSubmit() async throws {
        let stub = RouteStub()
        stub.replies["api/template/topic-template/binding-status"] = (#"{"code":200,"data":{"contract":{"locationSlots":[{"slotKey":"s1","title":"钟楼"},{"slotKey":"s2"}],"locationBindings":[{"slotKey":"s1","verificationStatus":"BOUND_UNVERIFIED","nodeId":9,"bindingRevision":3}]},"bindingIssues":[{"slotKey":"s2","level":"error","message":"未绑定"}],"sourceTemplateTopicId":12}}"#, 200)
        let service = TemplateAdoptionService(client: client(stub))
        let todos = try await service.bindingStatus(topicID: 40, scope: "")
        XCTAssertEqual(path(stub), "api/template/topic-template/binding-status")
        XCTAssertEqual(stub.lastForm, ["topicId": "40", "scope": ""])
        XCTAssertEqual(todos?.summary, "1 项挡住发布")
        XCTAssertEqual(todos?.rows.first?.revision, 3)
        XCTAssertEqual(todos?.sourceRevisionText, "未锁定来源修订")

        try await service.bind(topicID: 40, scope: "", slotKey: "s1", nodeID: 9, expectedRevision: 3)
        XCTAssertEqual(path(stub), "api/template/topic-template/binding")
        XCTAssertEqual(stub.lastForm["expectedRevision"], "3")

        try await service.saveAsTemplate(topicID: 40, scope: "")
        XCTAssertEqual(path(stub), "api/template/topic-template/save-as")
        XCTAssertEqual(stub.lastForm, ["id": "40", "scope": ""])

        try await service.submitToMarket(templateID: 41, scope: "")
        XCTAssertEqual(path(stub), "api/template/41/market-submit")
        XCTAssertEqual(stub.lastForm, ["scope": ""])
    }

    // MARK: Map / search

    func testGeocodePlaceSearchWeatherAndUnifiedSearch() async throws {
        let stub = RouteStub()
        let service = MapSearchPlayerService(client: client(stub))
        stub.replies["api/map/geocode"] = (#"{"code":200,"data":{"lat":31.2,"lng":121.5}}"#, 200)
        let point = await service.geocode(address: " 外滩 ", region: "上海")
        XCTAssertEqual(point, .init(latitude: 31.2, longitude: 121.5))
        XCTAssertEqual(path(stub), "api/map/geocode")
        XCTAssertEqual(stub.lastForm, ["address": "外滩", "region": "上海"])

        stub.replies["api/map/place-search"] = (#"{"code":200,"data":[{"name":"海星市场","address":"x","lat":1.5,"lng":2.5},{"name":"本地"}]}"#, 200)
        let places = try await service.placeSearch(keyword: "海星", latitude: 31.2, longitude: 121.5, localNames: ["本地"])
        XCTAssertEqual(path(stub), "api/map/place-search")
        XCTAssertEqual(stub.lastForm["keyword"], "海星")
        XCTAssertEqual(places.map(\.name), ["海星市场"])

        stub.replies["api/map/weather"] = (#"{"code":200,"data":{"kind":"rain","intensity":3}}"#, 200)
        let weather = await service.weather(latitude: 31.23, longitude: 121.47)
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertEqual(path(stub), "api/map/weather")
        XCTAssertEqual(stub.query("lat"), "31.225")
        XCTAssertEqual(stub.query("lng"), "121.475")
        XCTAssertEqual(weather, .init(kind: "rain", intensity: 1))

        stub.replies["api/search/unified"] = (#"{"code":200,"data":{"rows":[{"type":"topic","id":"3","name":"城墙"}],"total":20}}"#, 200)
        let page = try await service.unifiedSearch(keyword: "城", types: ["topic", "activity"], cityCode: "310100", page: 1)
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertEqual(path(stub), "api/search/unified")
        XCTAssertEqual(stub.query("keyword"), "城")
        XCTAssertEqual(stub.query("types"), "topic,activity")
        XCTAssertEqual(stub.query("city_code"), "310100")
        XCTAssertEqual(stub.query("pageNum"), "1")
        XCTAssertEqual(stub.query("pageSize"), "12")
        XCTAssertEqual(page.items.first?.title, "城墙")
        XCTAssertTrue(MapSearchPlayerService.hasMore(page, pageNumber: 1))
        let guestService = MapSearchPlayerService(client: PlayerCapabilityClient(baseURL: URL(string: "https://example.invalid")!, token: "", transport: stub))
        let guestPage = try await guestService.unifiedSearch(keyword: "城", types: ["topic"], cityCode: "310100", page: 1)
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertNil(stub.last.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(guestPage.items.first?.title, "城墙")
        stub.replies["api/search/unified"] = (#"{"code":200,"data":{"rows":[{"type":"post","id":"3"}],"total":1}}"#, 200)
        do { _ = try await service.unifiedSearch(keyword: "城", types: ["topic"], cityCode: "", page: 1); XCTFail() }
        catch { XCTAssertEqual(error as? PlayerCapabilityFailure, .malformed) }
    }

    // MARK: Grant

    func testChinaGateAdmitsTheNewRoutesAndKeepsMoneyClosed() {
        for path in ChinaReviewedRouteCapability.socialRoamOwnerGrant {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
            XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path), path)
        }
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/v1/community/posts/12/actions/BOOKMARK"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/template/41/market-submit"))
        for money in ["/api/registration/pay", "/api/pay/create", "/api/withdrawal/create", "/api/wallet/withdraw", "/api/asset/withdraw"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(money), money)
        }
    }

    func testWeatherLockedNodeAndClearWeatherFallback() async {
        let json = """
        {
          "mode": 1,
          "playable": true,
          "registered": true,
          "total": 1,
          "doneCount": 0,
          "nodes": [
            {
              "nodeId": 701,
              "name": "雨夜茶馆",
              "done": false,
              "locked": true,
              "weatherLocked": true,
              "lockReason": "仅在降雨天气解锁"
            }
          ]
        }
        """
        let result = try! JSONDecoder().decode(PlayNodesResult.self, from: Data(json.utf8))
        let snapshot = try! PlaySnapshot(scope: .activity(1), result: result)
        let node = snapshot.visibleNodes[0]
        XCTAssertEqual(node.weatherLocked, true)
        XCTAssertTrue(snapshot.isLocked(node))
        XCTAssertEqual(snapshot.lockReason(node), "仅在降雨天气解锁")

        let stub = RouteStub()
        let service = MapSearchPlayerService(client: client(stub))
        stub.replies["api/map/weather"] = (#"{"code":200,"data":{"kind":"clear","intensity":0}}"#, 200)
        let fallbackWeather = await service.weather(latitude: 30.27, longitude: 120.15)
        XCTAssertNil(fallbackWeather)
    }
}
