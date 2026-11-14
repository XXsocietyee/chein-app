import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class PayoutRecordingTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var replies: [String: String] = [:]
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        let reply = replies.first(where: { path.hasSuffix("/" + $0.key) })?.value ?? #"{"code":200,"msg":"操作成功","data":{}}"#
        return (Data(reply.utf8), 200)
    }
}

/// WP-01 payout receivers and WP-05 money writes. Stub transport only; nothing reaches a network.
final class PayoutReceiverClientTests: XCTestCase {
    private let example = URL(string: "https://example.com/prod-api/")!
    private var china: URL { URL(string: ReviewedMarketLaunch.chinaProductionBaseURL)! }
    private let token = "synthetic-token"

    override func tearDown() { ReleaseMoneyWriteSwitch.testDerivation = nil; super.tearDown() }

    private func service(_ wire: PayoutRecordingTransport, payout: Bool = true) throws -> PayoutReceiverService {
        PayoutReceiverService(configuration: try APIConfiguration(baseURL: example),
                              transport: PayoutReceiverTransport(underlying: wire, payoutEnabled: { payout }))
    }
    private func json(_ request: URLRequest) -> [String: AnyHashable]? {
        request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: AnyHashable] }
    }

    // MARK: request shapes (TEST shapes curled from 8120, club 7001 owned by 9003, merchant 9002)

    func testEveryRequestMatchesTheMiniProgramShape() async throws {
        let wire = PayoutRecordingTransport()
        wire.replies = [
            "api/club/settlement/mine": #"{"code":200,"data":[{"clubId":7001,"name":"城隐俱乐部"}]}"#,
            "api/club/personal-receiver/status": #"{"msg":"操作成功","code":200,"data":{"available":true,"receiverType":"PERSONAL_OPENID","receiverState":"UNBOUND","payoutEnabled":false,"paused":false,"pauseReason":null,"canUnbind":false}}"#,
            "api/merchant/payout-account": #"{"msg":"操作成功","code":200,"data":{"available":false,"unavailableReason":"PLATFORM_NOT_OPEN"}}"#,
            "api/club-direct-merchant/club": #"{"msg":"操作成功","code":200,"data":[]}"#,
            "api/club-direct-merchant/merchant": #"{"msg":"操作成功","code":200,"data":[]}"#,
            "api/club/settlement/summary": #"{"msg":"操作成功","code":200,"data":{"settledAmountText":"¥0.00","settledAmountStatus":"verified","unverifiedSettledCount":0,"pendingAdjustment":null,"topics":[],"sessions":[],"isOwner":true,"personal":false}}"#
        ]
        let service = try service(wire)
        let clubs = try await service.settlementClubs(token: token)
        XCTAssertEqual(clubs, [PayoutSettlementClub(id: 7001, name: "城隐俱乐部")])
        let status = try await service.receiverStatus(clubID: 7001, token: token)
        XCTAssertEqual(status.pageState, .unbound); XCTAssertTrue(status.payoutPending); XCTAssertFalse(status.canUnbind)
        try await service.bind(clubID: 7001, jsCode: "wx-one-time", token: token)
        try await service.unbind(clubID: 7001, token: token)
        let account = try await service.merchantPayoutAccount(token: token)
        XCTAssertEqual(account.pageState, .unavailable)
        _ = try await service.directLedger(.club(clubID: 7001, topicID: nil), token: token)
        _ = try await service.directLedger(.merchant(topicID: 12), token: token)
        let summary = try await service.settlementSummary(clubID: 7001, personal: true, token: token)
        XCTAssertTrue(summary.isOwner); XCTAssertTrue(summary.isEmpty)

        let r = wire.requests
        XCTAssertEqual(r.map { $0.url?.path }, [
            "/prod-api/api/club/settlement/mine", "/prod-api/api/club/personal-receiver/status", "/prod-api/api/club/personal-receiver/bind",
            "/prod-api/api/club/personal-receiver/unbind", "/prod-api/api/merchant/payout-account", "/prod-api/api/club-direct-merchant/club",
            "/prod-api/api/club-direct-merchant/merchant", "/prod-api/api/club/settlement/summary"])
        XCTAssertEqual(r.map { $0.httpMethod }, ["POST", "GET", "POST", "POST", "POST", "GET", "GET", "POST"])
        XCTAssertEqual(r.map { $0.value(forHTTPHeaderField: "Authorization") }, Array(repeating: token, count: 8))
        XCTAssertEqual(json(r[0]), [:])
        XCTAssertEqual(r[1].url?.query, "clubId=7001"); XCTAssertNil(r[1].httpBody)
        XCTAssertEqual(json(r[2]), ["clubId": 7001, "jsCode": "wx-one-time", "consent": true])
        XCTAssertEqual(json(r[3]), ["clubId": 7001])
        XCTAssertNil(r[4].httpBody); XCTAssertNil(r[4].url?.query)
        XCTAssertEqual(r[5].url?.query, "clubId=7001")
        XCTAssertEqual(r[6].url?.query, "topicId=12")
        XCTAssertEqual(json(r[7]), ["clubId": 7001, "personal": true])
        XCTAssertEqual(r[2].value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: acceptance: bind / unbind / payout-account send nothing while payoutEnabled is false

    func testPayoutWritesSendNothingWhilePayoutSwitchIsOff() async throws {
        let wire = PayoutRecordingTransport()
        let closed = try service(wire, payout: false)
        for call in [
            { try await closed.bind(clubID: 7001, jsCode: "code", token: self.token) },
            { try await closed.unbind(clubID: 7001, token: self.token) },
            { _ = try await closed.merchantPayoutAccount(token: self.token) }
        ] as [() async throws -> Void] {
            do { try await call(); XCTFail("sent a payout route") }
            catch { XCTAssertEqual(error as? PayoutReceiverIssue, .closed) }
        }
        XCTAssertTrue(wire.requests.isEmpty)

        // The default switch is the Core Release switch: off with no derivation, so the same three send nothing.
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        let real = PayoutReceiverService(configuration: try APIConfiguration(baseURL: example), transport: PayoutReceiverTransport(underlying: wire))
        do { try await real.unbind(clubID: 7001, token: token); XCTFail() } catch { XCTAssertEqual(error as? PayoutReceiverIssue, .closed) }
        do { _ = try await real.merchantPayoutAccount(token: token); XCTFail() } catch { XCTAssertEqual(error as? PayoutReceiverIssue, .closed) }
        XCTAssertTrue(wire.requests.isEmpty)
        for route in PayoutReceiverRoute.allCases where route.isPayout {
            XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/" + route.rawValue), route.rawValue)
            XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/" + route.rawValue), .payout)
        }
    }

    func testTransportRefusesOtherRoutesMethodsAndQueries() async throws {
        let wire = PayoutRecordingTransport()
        let transport = PayoutReceiverTransport(underlying: wire, payoutEnabled: { true })
        var withdraw = URLRequest(url: example.appendingPathComponent("api/club/settlement/withdraw")); withdraw.httpMethod = "POST"
        var getBind = URLRequest(url: example.appendingPathComponent("api/club/personal-receiver/bind")); getBind.httpMethod = "GET"
        var postQuery = URLRequest(url: URL(string: "https://example.com/api/club/personal-receiver/unbind?clubId=1")!); postQuery.httpMethod = "POST"
        var extraKey = URLRequest(url: URL(string: "https://example.com/api/club/personal-receiver/status?clubId=1&memberId=2")!); extraKey.httpMethod = "GET"
        for request in [withdraw, getBind, postQuery, extraKey] {
            do { _ = try await transport.send(request); XCTFail(request.url?.absoluteString ?? "") }
            catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        }
        XCTAssertTrue(wire.requests.isEmpty)
    }

    // MARK: production host

    func testChinaProductionRefusesEveryPayoutRouteUntilTheSwitchOpens() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        let wire = PayoutRecordingTransport()
        let transport = PayoutReceiverTransport(underlying: wire, payoutEnabled: { true })
        for route in PayoutReceiverRoute.allCases where route != .settlementSummary {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + route.rawValue), route.rawValue)
            var request = URLRequest(url: china.appendingPathComponent(route.rawValue)); request.httpMethod = route.method
            do { _ = try await transport.send(request); XCTFail(route.rawValue) }
            catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        }
        XCTAssertTrue(wire.requests.isEmpty)
        // TEST/DEBUG off the production host: the derivation opens payout, and the same routes are admitted.
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payout }
        for route in PayoutReceiverRoute.allCases {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + route.rawValue), route.rawValue)
        }
    }

    /// WP-05 acceptance: every money write stays refused on the China production host. Release compiles the switch
    /// constants false; a DEBUG build on the production host derives false; both are the `nil`/false derivation here.
    func testEveryMoneyWriteIsRefusedOnChinaProductionAndOpensOnlyOffIt() {
        let money = ["/api/registration/pay", "/api/registration/pay/app", "/api/pay/create", "/api/asset/withdraw",
                     "/api/withdrawal/create", "/api/wallet/withdraw", "/api/fund/preflight/bank-withdrawal",
                     "/api/fund/preflight/123/confirm", "/api/fund/preflight/123/reject", "/api/club/settlement/withdraw",
                     "/api/club/personal-receiver/bind", "/api/club/personal-receiver/unbind", "/api/merchant/payout-account",
                     "/api/cart/add", "/api/cart/order/settlement", "/api/mod-commerce/orders"]
        for derivation in [nil, { (_: ReleaseMoneyWriteKind) in false }] as [(@Sendable (ReleaseMoneyWriteKind) -> Bool)?] {
            ReleaseMoneyWriteSwitch.testDerivation = derivation
            for path in money {
                XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
                XCTAssertTrue(ChinaReviewedRouteCapability.isHiddenFromChinaReviewed(path), path)
            }
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/registration/payment-readiness"))
        }
        // Owner 2026-11-13 TEST/DEBUG derivation (payment, payout, withdrawal on; virtual goods never).
        ReleaseMoneyWriteSwitch.testDerivation = { $0 != .virtualGoods }
        for path in ["/api/registration/pay", "/api/registration/pay/app", "/api/pay/create", "/api/asset/withdraw",
                     "/api/withdrawal/create", "/api/fund/preflight/bank-withdrawal", "/api/fund/preflight/123/confirm",
                     "/api/club/personal-receiver/bind", "/api/merchant/payout-account", "/api/registration/payment-readiness"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        for path in ["/api/cart/add", "/api/cart/order/settlement", "/api/mod-commerce/orders", "/api/product/list", "/api/login",
                     "/api/club/settlement/withdraw"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
    }

    // MARK: shapes

    func testStatusShapeFollowsServerFactsOnly() {
        let paused = ClubPayoutReceiverStatus(data: ["available": true, "receiverState": "CONSENTED", "paused": true,
                                                     "pauseReason": "PERSONAL_BINDING_REQUIRED", "payoutEnabled": true, "canUnbind": true])
        XCTAssertEqual(paused?.pageState, .paused); XCTAssertEqual(paused?.bindKey, "payoutReceiver.rebind")
        XCTAssertEqual(paused?.canUnbind, true); XCTAssertEqual(paused?.payoutPending, false); XCTAssertEqual(paused?.tone, "warning")
        let bound = ClubPayoutReceiverStatus(data: ["available": true, "receiverState": "VERIFIED", "canUnbind": true])
        XCTAssertEqual(bound?.pageState, .bound); XCTAssertNil(bound?.bindKey); XCTAssertEqual(bound?.payoutPending, true)
        let unbound = ClubPayoutReceiverStatus(data: ["available": true, "receiverState": "UNBOUND", "canUnbind": true])
        XCTAssertEqual(unbound?.canUnbind, false)
        XCTAssertNil(ClubPayoutReceiverStatus(data: ["available": false, "receiverState": "VERIFIED"]))
        XCTAssertNil(ClubPayoutReceiverStatus(data: ["available": true, "receiverState": "UNKNOWN"]))
    }

    func testPayoutAccountShape() {
        XCTAssertEqual(MerchantPayoutAccount(data: ["available": false, "unavailableReason": "PLATFORM_NOT_OPEN"])?.pageState, .unavailable)
        XCTAssertEqual(MerchantPayoutAccount(data: ["available": true, "state": "NONE"])?.pageState, MerchantPayoutAccount.PageState.none)
        XCTAssertNil(MerchantPayoutAccount(data: ["available": true, "state": "WHATEVER"]))
        let sign = MerchantPayoutAccount(data: ["available": true, "state": "NEED_SIGN", "stateDesc": "请签约", "signUrl": "https://pay.example/sign",
                                                "subMchidMasked": "16***01", "checkedAt": "2026-11-13 10:20:00"])
        XCTAssertEqual(sign?.copyKey, "payoutAccount.copySign"); XCTAssertEqual(sign?.signURL?.absoluteString, "https://pay.example/sign")
        XCTAssertNil(sign?.maskedSubMerchantID); XCTAssertEqual(sign?.stateDescription, "请签约"); XCTAssertNotNil(sign?.checkedAt)
        let insecure = MerchantPayoutAccount(data: ["available": true, "state": "NEED_SIGN", "signUrl": "http://pay.example/sign"])
        XCTAssertNil(insecure?.signURL)
        let finished = MerchantPayoutAccount(data: ["available": true, "state": "FINISH", "stateDesc": "完成", "subMchidMasked": "16***01",
                                                    "signUrl": "https://pay.example/sign"])
        XCTAssertEqual(finished?.maskedSubMerchantID, "16***01"); XCTAssertNil(finished?.stateDescription); XCTAssertNil(finished?.signURL)
        XCTAssertEqual(finished?.tone, "success")
    }

    func testDirectLedgerTotalsAndFailClosed() {
        let rows: [[String: Any]] = [
            ["id": 1, "redemptionId": 11, "topicId": 5, "payerClubId": 7001, "merchantMemberId": 9002, "status": "OPEN", "perHeadFeeSnapshot": "12.5", "createTime": "2026-11-13T10:20:30"],
            ["id": 2, "redemptionId": 12, "topicId": 5, "payerClubId": 7001, "merchantMemberId": 9002, "status": "SETTLED", "perHeadFeeSnapshot": 8, "payVoucherNo": "V2", "claimId": "9223372036854775807"],
            ["id": 3, "redemptionId": 13, "topicId": 5, "payerClubId": 7001, "merchantMemberId": 9002, "status": "REFUNDED", "perHeadFeeSnapshot": "3.00", "refundVoucherNo": "R3", "claimId": "9223372036854775808"]
        ]
        let ledger = ClubDirectLedger(data: rows, scope: .club(clubID: 7001, topicID: nil))
        XCTAssertEqual(ledger?.openCents, 1250); XCTAssertEqual(ledger?.settledCents, 800); XCTAssertEqual(ledger?.refundDueCents, 0)
        XCTAssertEqual(ledger?.activeCount, 2)
        XCTAssertEqual(ledger?.rows.first?.timeText, "2026-11-13 10:20")
        XCTAssertEqual(ledger?.rows[1].voucher, "V2"); XCTAssertEqual(ledger?.rows[1].claimNumber, "9223372036854775807")
        XCTAssertEqual(ledger?.rows[2].voucher, "R3"); XCTAssertNil(ledger?.rows[2].claimNumber)
        XCTAssertEqual(ClubDirectLedger.amountText(1250), "¥12.50")
        XCTAssertNil(ClubDirectLedger(data: rows, scope: .club(clubID: 7002, topicID: nil)), "another club's row fails the read")
        XCTAssertNil(ClubDirectLedger(data: rows, scope: .merchant(topicID: 6)), "another topic's row fails the read")
        XCTAssertNil(ClubDirectLedger(data: [rows[0], rows[0]], scope: .merchant(topicID: nil)), "duplicate id fails")
        var bad = rows[0]; bad["perHeadFeeSnapshot"] = "1.234"
        XCTAssertNil(ClubDirectLedger(data: [bad], scope: .merchant(topicID: nil)))
        XCTAssertEqual(ClubDirectLedger(data: [], scope: .merchant(topicID: nil))?.rows, [])
    }

    func testSettlementSummaryIsFailClosed() {
        let topic: [String: Any] = ["id": 1, "topicId": 5, "name": "主题", "amountText": "¥10.00", "amountStatus": "verified",
                                    "originalAmountText": "¥10.00", "executedAdjustmentText": "¥0.00", "netAmountText": "¥10.00",
                                    "arrivedText": "已到账", "paidText": "已入账", "status": "settled"]
        let session: [String: Any] = ["activityId": 3, "name": "场次", "dateText": "11月13日", "grossText": "¥100.00", "feeText": "¥5.00",
                                      "feeRateText": NSNull(), "netText": "¥95.00", "payeeText": "入主理人余额", "merchantFeeText": NSNull()]
        let base: [String: Any] = ["settledAmountText": "¥10.00", "settledAmountStatus": "verified", "unverifiedSettledCount": 0,
                                   "topics": [topic], "sessions": [session], "isOwner": true]
        let summary = ClubSettlementSummaryView(data: base)
        XCTAssertEqual(summary?.topics.first?.chipKey, "clubSettlement.chip.settled")
        XCTAssertEqual(summary?.sessions.first?.feeRateText, nil); XCTAssertEqual(summary?.isOwner, true)
        var unverified = base; unverified["settledAmountStatus"] = "unverified"
        XCTAssertNil(ClubSettlementSummaryView(data: unverified), "unverified total needs a null text and a positive count")
        var noSessions = base; noSessions["sessions"] = nil
        XCTAssertNil(ClubSettlementSummaryView(data: noSessions))
        var personal = base; personal["personal"] = true; personal["sessions"] = [["activityId": 3, "name": "场次", "dateText": "d", "netText": "n", "payeeText": "p"]]
        XCTAssertEqual(ClubSettlementSummaryView(data: personal)?.personal, true)
    }

    func testIssueCopyNeverShowsAMachineCode() throws {
        XCTAssertThrowsError(try PayoutReceiverService.payload(Data(#"{"msg":"PERSONAL_RECEIVER_APPID_MISMATCH","code":500}"#.utf8), status: 200)) { error in
            XCTAssertEqual(error as? PayoutReceiverIssue, .rejected(code: "PERSONAL_RECEIVER_APPID_MISMATCH", message: nil))
            XCTAssertEqual((error as? PayoutReceiverIssue)?.codeKey, "payoutReceiver.error.PERSONAL_RECEIVER_APPID_MISMATCH")
        }
        XCTAssertNil(PayoutReceiverIssue.rejected(code: "SOMETHING_NEW", message: nil).codeKey)
        XCTAssertEqual(PayoutReceiverIssue.rejected(code: nil, message: "仅主理人可操作").serverSentence, "仅主理人可操作")
        XCTAssertNil(PayoutReceiverIssue.rejected(code: nil, message: "操作成功").serverSentence)
        XCTAssertThrowsError(try PayoutReceiverService.payload(Data(#"{"code":401}"#.utf8), status: 200)) {
            XCTAssertEqual($0 as? PayoutReceiverIssue, .unauthorized)
        }
    }

    // MARK: WP-05 payment readiness

    func testPaymentReadinessRequestAndDecode() async throws {
        let request = try RegistrationPaymentReadiness.request(configuration: try APIConfiguration(baseURL: example), token: token)
        XCTAssertEqual(request.httpMethod, "POST"); XCTAssertEqual(request.url?.path, "/prod-api/api/registration/payment-readiness")
        XCTAssertEqual(request.httpBody, Data("{}".utf8))
        // TEST 8120 answer.
        let test = RegistrationPaymentReadiness.decode(Data(#"{"msg":"操作成功","code":200,"data":{"ready":false,"message":"支付服务暂不可用"}}"#.utf8), status: 200)
        XCTAssertEqual(test, .init(ready: false, message: "支付服务暂不可用"))
        XCTAssertEqual(RegistrationPaymentReadiness.decode(Data(#"{"code":200,"data":{"ready":true,"message":"支付服务可用"}}"#.utf8), status: 200).ready, true)
        XCTAssertEqual(RegistrationPaymentReadiness.decode(Data(#"{"code":200,"data":{"ready":"true"}}"#.utf8), status: 200).ready, false)
        XCTAssertEqual(RegistrationPaymentReadiness.decode(Data("oops".utf8), status: 502).ready, false)
        let wire = PayoutRecordingTransport()
        wire.replies = ["api/registration/payment-readiness": #"{"code":200,"data":{"ready":true}}"#]
        let read = try await RegistrationPaymentReadiness.read(configuration: try APIConfiguration(baseURL: example), transport: wire, token: token)
        XCTAssertTrue(read.ready); XCTAssertEqual(wire.requests.count, 1)
    }

    // MARK: StoreKit (workshop MODs are digital goods: IAP only)

    func testWorkshopStoreKitEnvironmentAdmitsSandboxOnlyInDebugOrTest() {
        XCTAssertTrue(WorkshopStoreKitEnvironment.admits("PRODUCTION"))
        XCTAssertTrue(WorkshopStoreKitEnvironment.admits("SANDBOX"), "this test bundle is a DEBUG build")
        XCTAssertFalse(WorkshopStoreKitEnvironment.admits("XCODE"))
        XCTAssertFalse(WorkshopStoreKitEnvironment.admits(nil))
    }
}
