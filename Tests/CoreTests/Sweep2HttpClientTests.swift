#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class Sweep2HttpClientTests: XCTestCase {
    private final class StubTransport: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var nextHandler: ((URLRequest) throws -> (Data, Int))?

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            if let nextHandler { return try nextHandler(request) }
            return (Data(#"{"code":200,"msg":"ok","data":{}}"#.utf8), 200)
        }
    }

    private func makeClient(
        baseURL: URL = URL(string: "https://test.chengyinhub.example")!,
        transport: StubTransport = StubTransport()
    ) throws -> (Sweep2Client, StubTransport) {
        let config = try APIConfiguration(baseURL: baseURL)
        let client = Sweep2Client(configuration: config, transport: transport, tokenProvider: { "Bearer valid-token-123" })
        return (client, transport)
    }

    override func tearDown() {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        super.tearDown()
    }

    func testPaymentReadinessRespectsSwitchAndParsesReadyState() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { _ in false }
        let (closedClient, closedTransport) = try makeClient()
        let closedStatus = try await closedClient.paymentReadiness()
        XCTAssertFalse(closedStatus.ready)
        XCTAssertTrue(closedTransport.requests.isEmpty)
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/registration/payment-readiness"))

        ReleaseMoneyWriteSwitch.testDerivation = { kind in kind == .payment }
        let (openClient, openTransport) = try makeClient()
        openTransport.nextHandler = { _ in
            (Data(#"{"code":200,"data":{"ready":true,"message":null}}"#.utf8), 200)
        }
        let openStatus = try await openClient.paymentReadiness()
        XCTAssertTrue(openStatus.ready)
        XCTAssertEqual(openTransport.requests.count, 1)
        XCTAssertEqual(openTransport.requests[0].httpMethod, "POST")
        XCTAssertEqual(openTransport.requests[0].url?.path, "/api/registration/payment-readiness")
    }

    func testPersonalSettlementClubsRespectsPayoutSwitchAndValidatesRows() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { _ in false }
        let (closedClient, closedTransport) = try makeClient()
        do {
            _ = try await closedClient.personalSettlementClubs()
            XCTFail("Expected gated error when payout switch is OFF")
        } catch {
            XCTAssertTrue(closedTransport.requests.isEmpty)
        }

        ReleaseMoneyWriteSwitch.testDerivation = { kind in kind == .payout }
        let (openClient, openTransport) = try makeClient()
        openTransport.nextHandler = { _ in
            (Data(#"{"code":200,"data":[{"clubId":9,"name":"Alpha Club"}]}"#.utf8), 200)
        }
        let items = try await openClient.personalSettlementClubs()
        XCTAssertEqual(items, [ClubPersonalSettlementItem(clubID: 9, name: "Alpha Club")])
        XCTAssertEqual(openTransport.requests[0].url?.path, "/api/club/settlement/mine")
    }

    func testAuditTimelineAppealAndReceiptMatchStrictIntent() async throws {
        let (client, transport) = try makeClient()
        let cmd = AuditAppealCommand(requestId: "req-1", bizType: "topic", bizId: "42", reason: "Reviewed evidence", attachments: ["https://cdn.test/1.jpg"])

        transport.nextHandler = { req in
            switch req.url?.path {
            case "/api/audit/timeline":
                return (Data(#"{"code":200,"data":{"canAppeal":true,"appeal":{"state":"SUBMITTED"},"rounds":[{"roundNo":1,"conclusionText":"驳回","decidedAt":"2026-11-01","problems":[{"id":3,"itemType":"NODE","itemId":11,"reasonText":"Missing photo"}]}]}}"#.utf8), 200)
            case "/api/audit/appeal":
                return (Data(#"{"code":200,"msg":"ok","appealId":"101","taskId":"202","state":"SUBMITTED"}"#.utf8), 200)
            case "/api/audit/appeal/receipt":
                return (Data(#"{"code":200,"data":{"state":"FOUND","appealId":"101","taskId":"202","appealState":"SUBMITTED","intent":{"version":1,"memberId":"88","bizType":"topic","bizId":"42","requestId":"req-1","reason":"Reviewed evidence","evidence":null,"attachments":["https://cdn.test/1.jpg"]}}}"#.utf8), 200)
            default:
                XCTFail("Unexpected path \(req.url?.path ?? "")")
                return (Data(), 404)
            }
        }

        let detail = try await client.auditTimeline(bizType: "topic", bizID: "42")
        XCTAssertTrue(detail.canAppeal)
        XCTAssertEqual(detail.rows.count, 2)

        _ = try await client.submitAuditAppeal(command: cmd)
        let receipt = try await client.auditAppealReceipt(command: cmd, memberID: 88)
        XCTAssertEqual(receipt, AuditAppealReceipt(appealID: "101", taskID: "202", appealState: "SUBMITTED"))
        XCTAssertEqual(transport.requests.map { $0.url?.path }, [
            "/api/audit/timeline",
            "/api/audit/appeal",
            "/api/audit/appeal/receipt"
        ])
    }

    func testGuardReferenceAppealAndReceiptRoundTrip() async throws {
        let (client, transport) = try makeClient()
        let ref = PlayGuardReference(guardLogID: 77, routeSessionID: 12, nodeID: 5, arrivalRequestID: "arr-77")
        let cmd = PlayGuardAppealCommand(guardLogId: 77, arrivalRequestId: "arr-77", requestId: "grd-1", reason: "GPS drifted")

        transport.nextHandler = { req in
            switch req.url?.path {
            case "/api/audit/guard/reference":
                return (Data(#"{"code":200,"data":{"guardOrigin":{"guardLogId":77,"routeSessionId":12},"canSubmit":true}}"#.utf8), 200)
            case "/api/audit/guard/appeal":
                return (Data(#"{"code":200,"appealId":"9","taskId":"10","state":"SUBMITTED"}"#.utf8), 200)
            case "/api/audit/guard/appeal/receipt":
                return (Data(#"{"code":200,"data":{"state":"FOUND","decisionReason":"Waiting review","intent":{"requestId":"grd-1","memberId":"88","bizId":"77","reason":"GPS drifted","evidence":null,"attachments":[],"guardReference":{"guardLogId":77,"arrivalRequestId":"arr-77"}}}}"#.utf8), 200)
            default:
                XCTFail("Unexpected path \(req.url?.path ?? "")")
                return (Data(), 404)
            }
        }

        let eligibility = try await client.guardReference(ref)
        XCTAssertTrue(eligibility.canSubmit)
        try await client.submitGuardAppeal(command: cmd)
        let receipt = try await client.guardAppealReceipt(command: cmd, memberID: 88)
        XCTAssertEqual(receipt, PlayGuardAppealReceipt(decisionReason: "Waiting review"))
    }

    func testEditionsEmptyReasonValidatesClubIDAndCodes() async throws {
        let (client, transport) = try makeClient()
        transport.nextHandler = { _ in
            (Data(#"{"code":200,"data":{"clubId":15,"reasonCode":"UNDERTAKEN_NOT_ON_SALE"}}"#.utf8), 200)
        }
        let code = try await client.editionsEmptyReason(clubID: 15)
        XCTAssertEqual(code, .undertakenNotOnSale)
        XCTAssertEqual(transport.requests[0].url?.path, "/api/club-compensation/editions/empty-reason")
    }

    func testLeadReleaseStationAndUnlockChapterReceipt() async throws {
        let (client, transport) = try makeClient()
        transport.nextHandler = { req in
            switch req.url?.path {
            case "/api/club/lead/release-station":
                return (Data(#"{"code":200,"msg":"已放行，成员可以跳过这一站"}"#.utf8), 200)
            case "/api/club/lead/unlock-chapter-receipt":
                return (Data(#"{"code":200,"data":{"commandId":"cmd-1","expectedChapterId":1,"targetChapterId":2}}"#.utf8), 200)
            default:
                return (Data(), 404)
            }
        }
        let msg = try await client.releaseStation(activityID: 3, memberID: 9, nodeID: 21)
        XCTAssertEqual(msg, "已放行，成员可以跳过这一站")
        let receipt = try await client.unlockChapterReceipt(activityID: 3, commandID: "cmd-1", expectedChapterID: 1, targetChapterID: 2)
        XCTAssertEqual(receipt, .applied(expectedChapterID: 1, targetChapterID: 2))
    }

    func testDirectLedgerParsesClubAndMerchantScopesAndSumsFen() async throws {
        let (client, transport) = try makeClient()
        transport.nextHandler = { req in
            switch req.url?.path {
            case "/api/club-direct-merchant/club":
                return (Data(#"{"code":200,"data":[{"id":1,"redemptionId":10,"topicId":5,"payerClubId":7,"merchantMemberId":3,"status":"OPEN","perHeadFeeSnapshot":"12.50","claimId":"9001","createTime":"2026-11-10T10:00:00"}]}"#.utf8), 200)
            case "/api/club-direct-merchant/merchant":
                return (Data(#"{"code":200,"data":[{"id":2,"redemptionId":11,"topicId":5,"payerClubId":7,"merchantMemberId":3,"status":"SETTLED","perHeadFeeSnapshot":"8.00","payVoucherNo":"V-1"}]}"#.utf8), 200)
            default:
                return (Data(), 404)
            }
        }
        let club = try await client.directLedger(scope: .club(clubID: 7, topicID: 5))
        XCTAssertEqual(club.openTotalText, "¥12.50")
        XCTAssertEqual(club.rows.first?.claimNo, "9001")

        let merchant = try await client.directLedger(scope: .merchant(topicID: 5))
        XCTAssertEqual(merchant.settledTotalText, "¥8.00")
        XCTAssertEqual(merchant.rows.first?.voucher, "V-1")
    }

    func testNonMoneySweep2RoutesAreAdmittedInChinaCapability() {
        let nonMoney = [
            "/api/audit/appeal",
            "/api/audit/appeal/receipt",
            "/api/audit/guard/appeal",
            "/api/audit/guard/appeal/receipt",
            "/api/audit/guard/reference",
            "/api/club-compensation/editions/empty-reason",
            "/api/club-direct-merchant/club",
            "/api/club-direct-merchant/merchant",
            "/api/club/lead/release-station",
            "/api/club/lead/unlock-chapter-receipt"
        ]
        for path in nonMoney {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
    }
}
#endif
