import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MerchantCoopCoreTests: XCTestCase {
    func testReviewManagePinsFilterAndDecodesFilterCounts() throws {
        let request = try MerchantReviewManageRead(filter: "platform", page: 2).request()
        XCTAssertEqual(request.path, "api/merchant/reviews/manage")
        XCTAssertEqual(request.query, ["filter": "platform", "pageNum": "2", "pageSize": "20"])
        XCTAssertEqual(request.body, .none)
        XCTAssertEqual(try MerchantBusinessQuery.reviews(page: 1).request().query["filter"], "all")
        XCTAssertThrowsError(try MerchantReviewManageRead(filter: "photos", page: 1))
        let read = try MerchantReviewManageRead(filter: "platform", page: 1)
        var payload = try XCTUnwrap(MerchantBusinessSyntheticFixtures.payload(.reviews(page: 1)).object)
        payload["filter"] = .string("platform")
        payload["filterCounts"] = .object(["all": .int(4), "pending": .int(1), "low": .int(0), "photo": .int(2), "platform": .int(1)])
        let document = try read.document(from: .object(payload))
        XCTAssertEqual(document.reviewFilterCounts, ["all": 4, "pending": 1, "low": 0, "photo": 2, "platform": 1])
        XCTAssertEqual(document.query, .reviews(page: 1))
        XCTAssertEqual(document.rows.first?.fields["id"]?.integer, 63001)
        XCTAssertEqual(document.rows.first?.fields.mbText("status"), "VISIBLE")
        payload["filter"] = .string("pending")
        XCTAssertThrowsError(try read.document(from: .object(payload)))
        payload["filter"] = .string("platform")
        payload["filterCounts"] = .object(["all": .int(1)])
        XCTAssertThrowsError(try read.document(from: .object(payload)))
    }

    func testRedemptionDetailCarriesActivityTicketAndSessionFee() throws {
        for type in ["activity_ticket", "session_fee"] {
            let raw = MerchantBusinessSyntheticFixtures.redemption
                .replacingOccurrences(of: "redemption:64001", with: "\(type):64001")
                .replacingOccurrences(of: "\"recordType\":\"redemption\"", with: "\"recordType\":\"\(type)\"")
            let payload = try MerchantBusinessSyntheticFixtures.decode(raw)
            let request = try MerchantBusinessQuery.redemption(recordID: "\(type):64001").request()
            XCTAssertEqual(request.path, "api/merchant/finance/redemption-detail")
            XCTAssertEqual(request.body, .json(["recordType": .string(type), "recordId": .string("64001")]))
            let document = try MerchantBusinessDocument(query: .redemption(recordID: "\(type):64001"), payload: payload)
            XCTAssertEqual(document.rows.first?.fields.mbText("recordType"), type)
            XCTAssertEqual(document.rows.first?.fields.mbText("fulfillmentState"), "ACTIVE")
            let page = MerchantBusinessValue.object(["rows": .array([payload]), "total": .int(1), "pageNum": .int(1), "pageSize": .int(20)])
            let list = try MerchantBusinessDocument(query: .redemptions(filter: "all", page: 1), payload: page)
            XCTAssertEqual(list.rows.first?.destination, .redemption(recordID: "\(type):64001"))
        }
        XCTAssertEqual(try MerchantBusinessQuery.redemption(recordID: "64001").request().body, .json(["recordType": .string("redemption"), "recordId": .string("64001")]))
        XCTAssertNil(MerchantOrderDetailLink.record([:]))
        XCTAssertEqual(MerchantOrderDetailLink.missing, "缺少核销记录信息")
        XCTAssertEqual(MerchantOrderDetailLink.record(["recordType": "session_fee", "recordId": "9"])?.recordKey, "session_fee:9")
    }

    func testRedemptionListSendsTopicIdOnlyWhenTheLedgerLinkHasOne() throws {
        let scoped = try MerchantFinanceRedemptionList.request(filter: "all", page: 1, pageSize: 20, topicID: 44)
        XCTAssertEqual(scoped.path, "api/merchant/finance/redemptions")
        XCTAssertEqual(scoped.body, .json(["filter": .string("all"), "pageNum": .int(1), "pageSize": .int(20), "topicId": .int(44)]))
        let plain = try MerchantBusinessQuery.redemptions(filter: "all", page: 1).request()
        guard case .json(let fields) = plain.body else { return XCTFail() }
        XCTAssertNil(fields["topicId"])
        XCTAssertEqual(fields["filter"], .string("all"))
        let page = try MerchantBusinessSyntheticFixtures.payload(.redemptions(filter: "all", page: 1))
        let document = try MerchantBusinessDocument(query: .redemptions(filter: "all", page: 1), payload: page)
        XCTAssertEqual(document.rows.first?.fields.mbText("recordKey"), "redemption:64001")
        XCTAssertEqual(document.rows.first?.fields.mbText("chapterName"), "Example chapter")
        XCTAssertThrowsError(try MerchantFinanceRedemptionList.body(filter: "all", page: 1, pageSize: 20, topicID: 0))
    }

    func testVerificationRecordsPageAppendsWhileThePageIsFull() throws {
        let page = try MerchantVerificationRecordPage(page: 2)
        XCTAssertEqual(try page.request().path, "api/merchant/finance/redemptions")
        XCTAssertEqual(try page.request().body, .json(["filter": .string("all"), "pageNum": .int(2), "pageSize": .int(50)]))
        XCTAssertTrue(MerchantVerificationRecordPage.hasMore(pageRowCount: 50, collected: 50, total: 51))
        XCTAssertFalse(MerchantVerificationRecordPage.hasMore(pageRowCount: 49, collected: 49, total: 100))
        let first = try MerchantBusinessDocument(query: .verificationRecords, payload: MerchantBusinessSyntheticFixtures.payload(.verificationRecords))
        XCTAssertFalse(first.hasMore)
        XCTAssertEqual(first.total, 2)
        XCTAssertEqual(first.rows.map { $0.fields.mbText("recordKey") }, ["redemption:69001", "redemption:69002"])
        let rows = (1...50).map { MerchantBusinessValue.object(["recordKey": .string("redemption:\($0)"), "fulfillmentState": .string("ACTIVE")]) }
        let more = try MerchantBusinessDocument(query: .verificationRecords, payload: .object(["rows": .array(rows), "total": .int(51)]))
        XCTAssertTrue(more.hasMore)
        XCTAssertEqual(more.total, 51)
    }

    func testOnboardingRegistrationSendsBothCoordinates() throws {
        var draft = try makeMerchantOnboardingDraft()
        var fields = try XCTUnwrap(JSONSerialization.jsonObject(with: draft.jsonData()) as? [String: Any])
        XCTAssertNil(fields["locationLat"])
        XCTAssertNil(fields["locationLng"])
        draft.locationLat = 31.25
        XCTAssertNil(try (JSONSerialization.jsonObject(with: draft.jsonData()) as? [String: Any])?["locationLat"])
        draft.locationLng = 121.5
        fields = try XCTUnwrap(JSONSerialization.jsonObject(with: draft.jsonData()) as? [String: Any])
        XCTAssertEqual(fields["locationLat"] as? Double, 31.25)
        XCTAssertEqual(fields["locationLng"] as? Double, 121.5)
        let stored = try makeMerchantOnboardingApplication(status: 2, extras: ["locationLat": 31.25, "locationLng": 121.5])
        XCTAssertEqual(try MerchantOnboardingDraft(reapplying: stored).locationLat, 31.25)
        XCTAssertEqual(try MerchantOnboardingDraft(reapplying: stored).locationLng, 121.5)
        let broken = try makeMerchantOnboardingApplication(status: 2, extras: ["locationLat": 91, "locationLng": 121.5])
        XCTAssertNil(try MerchantOnboardingDraft(reapplying: broken).locationLat)
    }

    func testInsightSlotsFollowTheCheckinBuckets() {
        let facts = MerchantMarketingValue.object(["checkin": .object(["slotBuckets": .array([
            .object(["slot": .string("早"), "count": .number(1)]),
            .object(["slot": .string("午"), "count": .number(3)]),
        ])])])
        let slots = MerchantInsightSlots.build(facts)
        XCTAssertEqual(slots?.total, 4)
        XCTAssertEqual(slots?.peakText, "中午到店最多")
        XCTAssertEqual(slots?.bars.map(\.pct), ["25%", "75%"])
        XCTAssertEqual(slots?.bars.map(\.height), [33, 100])
        XCTAssertEqual(slots?.bars.map(\.isPeak), [false, true])
        XCTAssertNil(MerchantInsightSlots.build(.object(["checkin": .object(["hourBuckets": .array([.object(["slot": .string("早"), "count": .number(1)])])])])))
        XCTAssertNil(MerchantInsightSlots.build(.object(["checkin": .object(["slotBuckets": .array([])])])))
    }

    func testDeskResolveClassifiesAndStaysOff() async throws {
        let transport = DeskTransport()
        let base = try APIConfiguration(baseURL: URL(string: "https://example.com/")!)
        let off = MerchantDeskManualCodeClient(configuration: base, transport: transport)
        XCTAssertFalse(off.gate.enabled)
        do { _ = try await off.resolve(code: "ABC", token: "synthetic-desk-token"); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantBusinessFailure, .disabled) }
        XCTAssertTrue(transport.requests.isEmpty)
        let on = MerchantDeskManualCodeClient(configuration: base, transport: transport, gate: .init(enabled: true))
        let route = try await on.resolve(code: " ABC ", token: "synthetic-desk-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/desk/redeem/resolve")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["code"] as? String, "ABC")
        XCTAssertEqual(body["mode"] as? String, "MANUAL")
        XCTAssertEqual(body.count, 2)
        guard case .route(let endpoint, let code, _, let title, let choice) = route else { return XCTFail() }
        XCTAssertEqual(endpoint, "/api/coupon/verification")
        XCTAssertEqual(code, "ABC")
        XCTAssertEqual(title, "核销中...")
        XCTAssertEqual(choice?.options.map(\.label), ["第一章", "第二章"])
        XCTAssertEqual(MerchantDeskManualCode.validationError(""), "请输入核销码")
        XCTAssertEqual(MerchantDeskManualCode.validationError(String(repeating: "a", count: 513)), "核销码过长")
    }

    func testSupplyStationAcceptStaysBehindTheHandleGrant() async throws {
        let body = try CoopSupplyStationAccept.body(inviteID: 8, reason: " 到店 ", supplyStationID: 3)
        XCTAssertEqual(body["status"], .id(1))
        XCTAssertEqual(body["supplyStationId"], .id(3))
        XCTAssertEqual(body["handleReason"], .string("到店"))
        XCTAssertEqual(CoopSupplyStationAccept.path, "api/coop/handle")
        let idle = RecordingTransport()
        let closed = CoopFlowService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/")!), transport: idle)
        let session = try CoopFlowSession(accountID: 7, epoch: 1, token: "synthetic-coop-token")
        do { _ = try await closed.acceptSupplyStation(inviteID: 8, reason: nil, supplyStationID: 3, session: session); XCTFail() }
        catch { XCTAssertEqual(error as? CoopFlowFailure, .disabled) }
        XCTAssertTrue(idle.requests.isEmpty)
        let live = OfflineCoopTransport()
        let base = try APIConfiguration(baseURL: URL(string: "https://example.com/")!)
        let service = CoopFlowService(configuration: base, transport: live, dormantWritesEnabled: true,
                                      protectedDispatch: .init(operations: [.handle], endpoint: base.baseURL))
        let value = try await service.acceptSupplyStation(inviteID: 8, reason: nil, supplyStationID: 3, session: session)
        XCTAssertEqual(value["status"].integer, 1)
        let sent = try JSONDecoder().decode(CoopFlowJSON.self, from: XCTUnwrap(live.requests.first?.httpBody))
        guard case .object(let fields) = sent else { return XCTFail() }
        XCTAssertEqual(fields["supplyStationId"], .id(3))
        XCTAssertEqual(fields["status"], .id(1))
        XCTAssertNil(fields["handleReason"])
        XCTAssertFalse(live.requests.contains { $0.url?.path.contains("withdraw") == true })
        let invite = try JSONDecoder().decode(CooperationInvite.self, from: Data(#"{"id":1,"supplyStationId":"3","supplyStationName":" 夜市档 "}"#.utf8))
        XCTAssertEqual(invite.supplyStationId, 3)
        XCTAssertEqual(invite.supplyStationName, "夜市档")
        let ignored = try JSONDecoder().decode(CooperationInvite.self, from: Data(#"{"id":1,"supplyStationId":true}"#.utf8))
        XCTAssertNil(ignored.supplyStationId)
    }

    func testFinanceAndCoopLinksMatchTheMiniProgramRules() {
        XCTAssertEqual(MerchantFinanceRoute.normalize([:])?.view, .redemptions)
        XCTAssertNil(MerchantFinanceRoute.normalize(["view": "unknown"]))
        XCTAssertEqual(MerchantFinanceRoute.normalize(["tab": "3"])?.source, "coop")
        XCTAssertEqual(MerchantFinanceRoute.normalize(["view": "redemptions", "topicId": "44"])?.topicID, 44)
        XCTAssertEqual(MerchantFinanceRoute.normalize(["view": "messages", "ownerType": "1", "ownerId": "9"])?.ownerID, 9)
        XCTAssertNil(MerchantFinanceRoute.normalize(["view": "messages", "ownerType": "3", "ownerId": "9"]))
        XCTAssertEqual(MerchantFinanceRoute.expired, "链接已失效")
        XCTAssertEqual(MiniProgramPageLink(path: "pages/merchant/ledger/index", query: ["view": "settlement", "source": "coop", "topicId": "4"])?.query["topicId"], "4")
        XCTAssertNil(MiniProgramPageLink(path: "pages/merchant/ledger/index", query: ["view": "nope"]))
        XCTAssertEqual(MerchantPublicHomeLink.target(["poiId": "5"]), .poi(5))
        XCTAssertNil(MerchantPublicHomeLink.target([:]))
        XCTAssertNil(MerchantSettlementDetailLink.resolve(["source": "club", "topicId": "8"]))
        XCTAssertEqual(MerchantSettlementDetailLink.resolve(["source": "club", "clubId": "3", "id": "8", "personal": "1"])?.personal, true)
        XCTAssertEqual(MerchantSettlementDetailLink.resolve(["source": "finance", "topicId": "8"])?.recordKey, "topicId")
        XCTAssertEqual(MerchantSettlementDetailLink.missing, "缺少结算记录信息")
        let list = CoopListLink(["tab": "received", "topicId": "4", "topicName": "夜跑", "scope": "MERCHANT"])
        XCTAssertEqual(list.topicID, 4)
        XCTAssertTrue(list.merchantScope)
        XCTAssertEqual(CoopInviteLink(["type": "0", "toId": "6", "topicId": "4"])?.toID, 6)
        XCTAssertEqual(CoopInviteDetailLink(["inviteId": "5", "box": "sent"]).box, "sent")
        XCTAssertEqual(CoopNearbyLink(["topicId": "4", "topicName": "夜跑"]).topicName, "夜跑")
        let token = String(repeating: "a", count: 16)
        XCTAssertEqual(MiniProgramPageLink(path: "pages/merchant/team/index", query: ["invite": token])?.query["invite"], token)
        XCTAssertTrue(MerchantFinanceDetailLoad.isMissingRecord(code: "404", statusCode: nil, message: nil))
        XCTAssertTrue(MerchantFinanceDetailLoad.isMissingRecord(code: nil, statusCode: nil, message: "这条结算批次不存在或已不可见"))
        XCTAssertFalse(MerchantFinanceDetailLoad.isMissingRecord(code: "500", statusCode: nil, message: "结算详情加载失败"))
        XCTAssertEqual(MerchantFinanceDetailLoad.batchMissingParam, "缺少结算批次信息")
        let unverified: [String: Any] = ["topicId": 4, "name": "夜跑", "status": "settled", "amountStatus": "unverified", "amountText": NSNull(),
                                         "originalAmountText": "1", "executedAdjustmentText": "0", "netAmountText": "1", "arrivedText": "—", "paidText": "—"]
        XCTAssertEqual(CoopClubSettlementDetail.resolve(unverified)?.amountText, CoopClubSettlementDetail.pendingNet)
        XCTAssertEqual(CoopClubSettlementDetail.resolve(unverified)?.statusText, "待核验")
    }

    func testReadyDraftReportsEachFailingField() {
        var draft = MerchantGameNodeReadyDraft()
        XCTAssertEqual(draft.fieldIssues(routePlay: false).map(\.kind), [.capacity, .date, .checklist])
        draft.capacity = "4"
        draft.serviceDate = "2026-10-02"
        draft.serviceStartTime = "12:00"
        draft.serviceEndTime = "10:00"
        XCTAssertEqual(draft.fieldIssues(routePlay: true).map(\.kind), [.timeWindow])
        draft.serviceEndTime = "13:00"
        draft.checklist = [MerchantGameNodeChecklistItem(code: "KIT", label: "Kit", checked: false)]
        XCTAssertEqual(draft.fieldIssues(routePlay: true).map(\.kind), [.checklist])
        draft.checklist[0].checked = true
        XCTAssertTrue(draft.fieldIssues(routePlay: false).isEmpty)
        XCTAssertTrue(MerchantGameNodeReadyDraft().fieldIssues(routePlay: true).map(\.kind).contains(.capacity))
    }
}

private final class RecordingTransport: HTTPTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
    }
}

private final class OfflineCoopTransport: HTTPTransport, CoopFlowOfflineHTTPTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":{"status":1}}"#.utf8), 200)
    }
}

private final class DeskTransport: HTTPTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let body: [String: Any] = ["code": 200, "data": [
            "accepted": true,
            "form": [
                "submitEndpoint": "/api/coupon/verification",
                "fields": [
                    ["name": "code", "widget": "hidden", "value": "ABC"],
                    ["name": "chapterId", "widget": "select", "label": "选择章", "options": [
                        ["value": "1", "label": "第一章"], ["value": "2", "label": "第二章"],
                    ]],
                ],
            ],
        ]]
        return (try JSONSerialization.data(withJSONObject: body), 200)
    }
}
