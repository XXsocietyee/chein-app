import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class G2OpsGapTests: XCTestCase {
    private final class StubTransport: HTTPTransport {
        let handler: (URLRequest) throws -> (Data, Int)
        var requests: [URLRequest] = []

        init(_ handler: @escaping (URLRequest) throws -> (Data, Int)) {
            self.handler = handler
        }

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return try handler(request)
        }
    }

    private let baseConfig = try! APIConfiguration(baseURL: URL(string: "https://example.com")!)
    private let validToken = "valid-token-123456"

    func testClubCoopPoolAndEditionsReason() async throws {
        XCTAssertEqual(ClubCoopPoolCopy.sectionTitle, "可对接的活动")
        XCTAssertEqual(ClubCoopPoolCopy.applyModalTitle(topicName: "夜游"), "申请带队「夜游」")
        XCTAssertEqual(ClubCoopPoolCopy.applyModalTitle(topicName: "  "), "申请带队「该主题」")

        let transport = StubTransport { _ in
            (Data(#"{"code":200,"data":{"reason":"暂未开通售票","title":"无场次"}}"#.utf8), 200)
        }
        let client = ClubEditionsEmptyReasonClient(configuration: baseConfig, transport: transport)
        let reason = try await client.fetchEmptyReason(clubID: 12, token: validToken)
        XCTAssertEqual(reason.reason, "暂未开通售票")
        let req = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertTrue(req.url?.path.hasSuffix("api/club-compensation/editions/empty-reason") == true)
        let body = try JSONSerialization.jsonObject(with: try XCTUnwrap(req.httpBody)) as? [String: Any]
        XCTAssertEqual(body?["clubId"] as? Int, 12)
    }

    func testClubTopicDirectorTypes() {
        let summary = ClubTopicDirectorSummary(readyStations: 3, totalStations: 5, activeTeams: 2, hasUnknownWrite: true)
        XCTAssertEqual(summary.readyStations, 3)
        XCTAssertTrue(summary.hasUnknownWrite)
        XCTAssertEqual(ClubTopicDirectorToolKind.allCases.map(\.title), ["章节放行", "队伍进度", "角色分配", "现场事件", "定向广播"])
    }

    func testFEReferenceSettlementMoneyWriteGateClosedByDefault() async throws {
        let transport = StubTransport { _ in (Data("{\"code\":200}".utf8), 200) }
        let client = ClubFEReferenceSettlementClient(configuration: baseConfig, transport: transport)

        let settled = try await client.markSettled(ids: [42], token: validToken, allowsMoneyWrite: false)
        XCTAssertFalse(settled)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testClubRemainingModelsAndClients() async throws {
        let opt1 = ClubPostRefOption.fromJoinedRecord(ownerType: 2, refID: 10, title: "活动A")
        let opt2 = ClubPostRefOption.fromJoinedRecord(ownerType: 1, refID: 20, title: "主题B")
        XCTAssertEqual(opt1?.refType, 1)
        XCTAssertEqual(opt2?.refType, 2)
        XCTAssertNil(ClubPostRefOption.fromJoinedRecord(ownerType: 1, refID: 0, title: "无效"))

        let ctx = ClubDetailEntryContext(clubID: 8, targetPostID: 99, openScanner: true, isMerchantViewer: true, preselectedMemberID: 5)
        XCTAssertTrue(ctx.usesMerchantLightDomain)

        let transport = StubTransport { req in
            if req.url?.path.hasSuffix("host-node-answer") == true {
                return (Data(#"{"code":200,"data":{"question":"Q","answerReveal":"A"}}"#.utf8), 200)
            }
            return (Data(#"{"code":200}"#.utf8), 200)
        }
        let client = ClubRemainingGapClient(configuration: baseConfig, transport: transport)
        try await client.toggleFollowAuthor(targetUserID: 7, follow: true, token: validToken)
        let followReq = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(followReq.httpMethod, "POST")
        XCTAssertEqual(followReq.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        let formBody = String(data: try XCTUnwrap(followReq.httpBody), encoding: .utf8) ?? ""
        XCTAssertTrue(formBody.contains("follow_member_id=7"))
        XCTAssertTrue(formBody.contains("follow=1"))

        let answer = try await client.fetchHostNodeAnswer(topicID: 1, nodeID: 2, scope: "MERCHANT", token: validToken)
        XCTAssertEqual(answer.answerReveal, "A")
    }

    func testMerchantAIInsightModelsAndClient() async throws {
        let none = MerchantAIInsightGrowTip.visibleTips(canCoop: false, canCityNode: false, canCoupon: false, canAINPC: false)
        XCTAssertTrue(none.isEmpty)
        let all = MerchantAIInsightGrowTip.visibleTips(canCoop: true, canCityNode: true, canCoupon: true, canAINPC: true)
        XCTAssertEqual(all.map(\.key), [.coop, .citynode, .coupon, .aiNpc])
        XCTAssertEqual(MerchantAIInsightWindow.days30.title, "近30天")
        XCTAssertEqual(MerchantAIInsightMetricKind.visitors.unit, "位玩家到店")

        let transport = StubTransport { _ in
            (Data(#"{"code":200,"data":{"facts":{"sources":[{"topicName":"夜游","count":6},{"topicName":"探店","count":4}]}}}"#.utf8), 200)
        }
        let client = MerchantAIInsightClient(configuration: baseConfig, transport: transport)
        let items = try await client.fetchSources(days: .days7, token: validToken)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.name, "夜游")
        XCTAssertEqual(items.first?.pct, "60%")
        let req = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertTrue(req.url?.path.hasSuffix("api/ai/merchant/insight") == true)
    }

    func testMerchantOperationsAndDepositGate() async throws {
        XCTAssertEqual(MerchantCustomerExportBannerState.ready(rows: 12).title, "已就绪 12 行")
        XCTAssertEqual(MerchantAINPCIntroCopy.steps.count, 4)

        let transport = StubTransport { _ in (Data("{\"code\":200,\"data\":[]}".utf8), 200) }
        let client = MerchantGapOperationsClient(configuration: baseConfig, transport: transport)

        let created = try await client.createDeposit(inviteID: 9, token: validToken, allowsMoneyWrite: false)
        let retried = try await client.retryDepositRefund(inviteID: 9, token: validToken, allowsMoneyWrite: false)
        XCTAssertFalse(created)
        XCTAssertFalse(retried)
        XCTAssertTrue(transport.requests.isEmpty)

        let stations = try await client.supplyStations(topicID: 4, merchantMemberID: 3, token: validToken)
        XCTAssertTrue(stations.isEmpty)
        let stationReq = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(stationReq.httpMethod, "GET")
        XCTAssertTrue(stationReq.url?.query?.contains("topicId=4") == true)
        XCTAssertTrue(stationReq.url?.query?.contains("merchantMemberId=3") == true)

        _ = try await client.invitableMerchants(topicID: 4, latitude: 31.2, longitude: 121.4, token: validToken)
        let invReq = try XCTUnwrap(transport.requests.last)
        XCTAssertEqual(invReq.httpMethod, "POST")
        XCTAssertTrue(invReq.url?.path.hasSuffix("api/merchant/chapter-application/invitable") == true)
    }

    func testMerchantRemainingModelsAndClient() async throws {
        let transport = StubTransport { _ in (Data(#"{"code":200}"#.utf8), 200) }
        let client = MerchantRemainingGapClient(configuration: baseConfig, transport: transport)
        try await client.claimExistingStore(MerchantOnboardingClaimRequest(storeName: "城瘾书店"), token: validToken)
        try await client.saveBrandContact(MerchantDecorContactDraft(contactPhone: "13800000000", wechatID: "cy_wx"), token: validToken)
        try await client.saveDecorDisplay(MerchantDecorContactDraft(address: "南京路"), token: validToken)
        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertTrue(transport.requests[0].url?.path.hasSuffix("api/merchant/claims/submit") == true)
        XCTAssertTrue(transport.requests[1].url?.path.hasSuffix("api/merchant/update") == true)
        XCTAssertTrue(transport.requests[2].url?.path.hasSuffix("api/merchant/decor/save") == true)
    }

    func testAccountPublishModelsAndClients() async throws {
        XCTAssertEqual(TeamGapCopy.maxJoinCodeLength, 40)
        XCTAssertEqual(TeamGapCopy.buyTicketCTA, "去买这一场的票")
        XCTAssertEqual(AccountPublishGapCopy.ownComposerPlaceholder, "有什么新鲜好玩的分享吗？")
        XCTAssertEqual(ProjectEditExtraStoryBlockKind.allCases.map(\.title), ["分支选择", "多图画廊", "角色对白"])
        XCTAssertEqual(SettingsSceneTarget(scene: "privacy"), .privacy)
        XCTAssertEqual(SettingsSceneTarget(scene: "bad"), .unknown("bad"))

        let transport = StubTransport { req in
            if req.url?.path.hasSuffix("topic-template/use") == true {
                return (Data(#"{"code":200,"data":{"topicId":88}}"#.utf8), 200)
            }
            if req.url?.path.hasSuffix("cast/voice") == true {
                return (Data(#"{"code":200,"data":{"url":"https://example.com/a.mp3"}}"#.utf8), 200)
            }
            if req.url?.path.hasSuffix("getwxbindphone") == true {
                return (Data(#"{"code":200,"data":{"phone":"138****0000"}}"#.utf8), 200)
            }
            return (Data(#"{"code":200}"#.utf8), 200)
        }
        let client = AccountPublishGapClient(configuration: baseConfig, transport: transport)
        let topicID = try await client.remixTemplate(templateID: 5, requestID: "req-1", token: validToken)
        XCTAssertEqual(topicID, 88)
        let remixReq = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(remixReq.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")

        let audioURL = try await client.previewCastVoice(topicID: 1, preset: "warm", token: validToken)
        XCTAssertEqual(audioURL, "https://example.com/a.mp3")
        try await client.handleTeamApplication(teamID: 4, memberID: 9, approved: false, token: validToken)
        let handle = try XCTUnwrap(transport.requests.last { $0.url?.path.hasSuffix("api/team/command") == true })
        XCTAssertEqual(handle.httpMethod, "POST")
        let handleBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(handle.httpBody)) as? [String: Any])
        XCTAssertEqual(handleBody["memberId"] as? String, "9")
        XCTAssertEqual(handleBody["targetId"] as? String, "4")
        XCTAssertEqual(handleBody["approved"] as? Bool, false)
        XCTAssertEqual(handleBody["action"] as? String, "handle")
        XCTAssertNil(handleBody["applicationId"])
        XCTAssertNil(handleBody["teamId"])

        let remClient = AccountPublishRemainingClient(configuration: baseConfig, transport: transport)
        let phone = try await remClient.bindPhone(code: "wx-code", token: validToken)
        XCTAssertEqual(phone, "138****0000")
    }

    func testReferenceSettlementReadsSendTheRangeAndMoneyWritesSendNothing() async throws {
        for path in ChinaReviewedRouteCapability.feReferenceSettlementReadGrant {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/fe/reference-settlement/settle"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/fe/reference-settlement/dispute"))
        XCTAssertFalse(FEReferenceSettlementMoneyWrite.enabled)
        let transport = StubTransport { _ in (Data(#"{"code":200,"data":[]}"#.utf8), 200) }
        let client = ClubFEReferenceSettlementClient(configuration: baseConfig, transport: transport)
        _ = try await client.list(role: .payer, from: "2026-11-01", to: "2026-11-24", token: validToken)
        let listed = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(listed.httpMethod, "GET")
        XCTAssertTrue(listed.url?.path.hasSuffix("api/fe/reference-settlement/payer") == true)
        XCTAssertTrue(listed.url?.query?.contains("from=2026-11-01") == true)
        XCTAssertTrue(listed.url?.query?.contains("to=2026-11-24") == true)
        let settled = try await client.markSettled(ids: [42], token: validToken, allowsMoneyWrite: true)
        let disputed = try await client.dispute(id: 7, note: "没收到", token: validToken, allowsMoneyWrite: true)
        XCTAssertFalse(settled)
        XCTAssertFalse(disputed)
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testClubScanSendsTheMiniProgramBodyAndDropsInvalidCodes() async throws {
        XCTAssertEqual(ClubScanRoute.resolve("v1.x.group_1").readyPath, "api/verify/groupcode/redeem")
        XCTAssertEqual(ClubScanRoute.resolve("v1.x.activity").readyPath, "api/registration/scan_dynamic_code")
        XCTAssertEqual(ClubScanRoute.resolve("cq1.a.b.c").readyPath, "api/coupon/verification")
        XCTAssertEqual(ClubScanRoute.resolve(#"{"type":"topic","code":"T1"}"#).readyBody?["type"], "topic")
        if case .invalid(let message, let path, _) = ClubScanRoute.resolve("v1.x.citynode_1") {
            XCTAssertEqual(path, "/pages/merchant/citynode/index")
            XCTAssertFalse(message.isEmpty)
        } else { XCTFail("city node scan must not post") }
        let transport = StubTransport { _ in (Data(#"{"code":200}"#.utf8), 200) }
        let client = ClubScanClient(configuration: baseConfig, transport: transport)
        let invalidCodePosted = try await client.submit("not-a-code", token: validToken, canGovern: true, canManageActivities: false)
        XCTAssertFalse(invalidCodePosted)
        XCTAssertTrue(transport.requests.isEmpty)
        let unauthorizedPosted = try await client.submit("v1.x.group_1", token: validToken, canGovern: false, canManageActivities: false)
        XCTAssertFalse(unauthorizedPosted)
        XCTAssertTrue(transport.requests.isEmpty)
        let governedPosted = try await client.submit("v1.x.group_1", token: validToken, canGovern: true, canManageActivities: false)
        XCTAssertTrue(governedPosted)
        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(sent.httpMethod, "POST")
        XCTAssertTrue(sent.url?.path.hasSuffix("api/verify/groupcode/redeem") == true)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(sent.httpBody)) as? [String: Any])
        XCTAssertEqual(body["code"] as? String, "v1.x.group_1")
        XCTAssertEqual(body.count, 1)
    }
}
