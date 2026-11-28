import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// WP-08 rows: OWN-C, OWN-D, OWN-G, OWN-十六-12, OWN-十六-13, OWN-十六-14, OWN-20.1, OWN-20.2.
/// Roll-ups OWN-十八, OWN-十三-10, and OWN-十三-11 follow those children.
/// §12–§17 money, coupon, and payout routes stay absent.
final class WP08HostTipSurfaceTests: XCTestCase {
    func testGrantCoversTheNamedRoutesAndLeavesMoneyClosed() {
        let grant = ChinaReviewedRouteCapability.hostTipSurfaceGrant
        for path in [
            "/api/host-tip/config",
            "/api/host-tip/config/mine",
            "/api/host-tip/prepare",
            "/api/host-tip/intent/mine",
            "/api/host-tip/intent/{}/cancel",
            "/api/video-bounty/submission/{}/attribution",
            "/api/video-bounty/campaign/{}/attribution",
            "/api/channel/redeem",
            "/api/channel/redeem/status",
            "/api/content-landing/info",
            "/api/content-landing/save",
            "/api/content-landing/translation/save"
        ] {
            XCTAssertTrue(grant.contains(path), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/host-tip/intent/9/cancel"))
        for closed in [
            "/api/registration/pay",
            "/api/registration/pay/app",
            "/api/withdrawal/create",
            "/api/wallet/withdraw",
            "/api/coupon/usability",
            "/api/host-tip/pay",
            "/api/video-bounty/payout"
        ] {
            XCTAssertFalse(grant.contains(closed), closed)
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(closed), closed)
        }
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/pay"))
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "/api/host-tip/prepare"))
        XCTAssertEqual(ChinaReviewedRouteCapability.wiredPatternCount, 680)
    }

    /// P2-1: a payable prepare used to say "payment closed" on both branches of the switch.
    /// The switch is not flipped here. Open payments stay pending (not paid). Closed payments say closed.
    func testPayablePrepareIsPendingOnlyWhilePaymentsAreOpen() throws {
        let body = Data(#"{"code":200,"data":{"id":9,"payable":true,"status":"AWAITING_PAYMENT","amount":12}}"#.utf8)
        let fact = try XCTUnwrap(HostTipSource.prepareFact(HostTipSource.envelope(data: body, status: 200)))
        XCTAssertTrue(fact.payable)
        XCTAssertFalse(fact.paymentSucceeded)
        XCTAssertEqual(HostTipPreparePresentation.banner(fact: fact, paymentsOpen: true), .pending)
        XCTAssertEqual(HostTipPreparePresentation.banner(fact: fact, paymentsOpen: false), .paymentClosed)
        let off = Data(#"{"code":501,"reasonCode":"CHANNEL_NOT_ENABLED","data":{"id":9,"payable":true,"status":"CHANNEL_UNSUPPORTED","amount":12}}"#.utf8)
        let closed = try XCTUnwrap(HostTipSource.prepareFact(HostTipSource.envelope(data: off, status: 501)))
        XCTAssertEqual(HostTipPreparePresentation.banner(fact: closed, paymentsOpen: true), .unavailable)
        let flagged = HostTipPrepareFact(unavailable: false, payable: true, paymentSucceeded: true,
                                         intentID: "9", status: "PAID", amountText: "12.00", reasonCode: nil)
        XCTAssertEqual(HostTipPreparePresentation.banner(fact: flagged, paymentsOpen: true), .paymentClosed)
    }

    func testPrepare501IsUnavailableAndNotAPayment() throws {
        let body = Data(#"{"code":501,"reasonCode":"CHANNEL_NOT_ENABLED","data":{"id":9,"payable":false,"status":"CHANNEL_UNSUPPORTED","amount":12}}"#.utf8)
        let envelope = HostTipSource.envelope(data: body, status: 501)
        let fact = try XCTUnwrap(HostTipSource.prepareFact(envelope))
        XCTAssertTrue(fact.unavailable)
        XCTAssertFalse(fact.payable)
        XCTAssertFalse(fact.paymentSucceeded)
        XCTAssertEqual(fact.reasonCode, "CHANNEL_NOT_ENABLED")
        XCTAssertNotEqual(fact.amountText, "0")
        XCTAssertNotEqual(fact.amountText, "¥0.00")
    }

    func testMissingPrepareAmountIsAnEmDash() throws {
        let body = Data(#"{"code":200,"data":{"id":3,"payable":false,"status":"CREATED"}}"#.utf8)
        let envelope = HostTipSource.envelope(data: body, status: 200)
        let fact = try XCTUnwrap(HostTipSource.prepareFact(envelope))
        XCTAssertEqual(fact.amountText, "—")
        XCTAssertFalse(fact.paymentSucceeded)
        XCTAssertTrue(fact.unavailable)
    }

    func testConfigBodyOmitsShareAndPayFields() throws {
        let fields = try HostTipSource.configFields(clubID: "0", enabled: true, minAmount: "1.5", currency: "CNY", channelFeeBearer: 0)
        XCTAssertNil(fields["hostSharePercent"])
        XCTAssertNil(fields["payChannel"])
        XCTAssertNil(fields["price"])
        XCTAssertThrowsError(try HostTipSource.configFields(clubID: "0", enabled: true, minAmount: "-1", currency: "CNY", channelFeeBearer: 0))
    }

    func testAttributionNullsStayUnknownAndNotZero() throws {
        let unbound = try fact(#"{"status":"UNBOUND","confirmed":false,"attributedOrders":null,"paidOrders":0,"paidAmount":0,"refundedOrders":null,"refundedAmount":null,"amountCurrency":"CNY"}"#)
        XCTAssertEqual(unbound.status, "UNBOUND")
        XCTAssertFalse(unbound.showsCounts)
        XCTAssertEqual(unbound.paidOrders, "—")
        XCTAssertEqual(unbound.paidAmount, "—")
        XCTAssertNotEqual(unbound.paidOrders, "0")
        let missing = try fact(#"{"confirmed":false,"paidOrders":null,"paidAmount":null}"#)
        XCTAssertEqual(missing.status, "UNKNOWN")
        XCTAssertEqual(missing.attributedOrders, "—")
        XCTAssertNotEqual(missing.paidAmount, "0")
        let bound = try fact(#"{"status":"BOUND","confirmed":true,"attributedOrders":2,"paidOrders":0,"paidAmount":"3.50","refundedOrders":1,"refundedAmount":"1.00","amountCurrency":"CNY"}"#)
        XCTAssertTrue(bound.showsCounts)
        XCTAssertEqual(bound.paidOrders, "0")
        XCTAssertEqual(bound.paidAmount, "3.50")
        XCTAssertEqual(bound.amountCurrency, "CNY")
    }

    func testChannelProviderOffIsUnavailable() {
        let envelope = ChannelRedeemEnvelope(httpStatus: 200, code: "200", reasonCode: "PROVIDER_NOT_CONFIGURED",
                                             message: nil, dataJSON: nil, netFail: false)
        XCTAssertEqual(ChannelRedeemSource.presentation(envelope), .unavailable)
        let expired = ChannelRedeemEnvelope(httpStatus: 400, code: "400", reasonCode: "CODE_EXPIRED", message: nil, dataJSON: nil, netFail: false)
        XCTAssertEqual(ChannelRedeemSource.presentation(expired), .expired)
    }

    func testRedeemedReceiptKeepsLiteralZeroAndDashesMissingFields() throws {
        let data = try XCTUnwrap(JSONSerialization.data(withJSONObject: [
            "productName": "Night walk",
            "seatCount": 0,
            "registrationNo": "R-1",
            "replayed": true
        ]))
        let envelope = ChannelRedeemEnvelope(httpStatus: 200, code: "200", reasonCode: nil, message: nil, dataJSON: data, netFail: false)
        guard case .redeemed(let receipt) = ChannelRedeemSource.presentation(envelope) else {
            return XCTFail("receipt")
        }
        XCTAssertEqual(receipt.productName, "Night walk")
        XCTAssertEqual(receipt.seatCount, "0")
        XCTAssertEqual(receipt.validFrom, "—")
        XCTAssertEqual(receipt.validTo, "—")
        XCTAssertTrue(receipt.replayed)
    }

    func testLandingSaveOmitsPriceAndApprovedStatus() throws {
        let fields = try ContentLandingSource.saveFields(topicID: "12", expectedVersion: "3", summary: "A walk",
                                                         group: .undeclared, school: .yes, groupMin: "", groupMax: "8",
                                                         ageMin: "", ageMax: "", accessibility: "")
        XCTAssertNil(fields["price"])
        XCTAssertNil(fields["status"])
        XCTAssertTrue(fields["groupEligible"] is NSNull)
        XCTAssertEqual(fields["schoolEligible"] as? Bool, true)
        let translation = try ContentLandingSource.translationFields(topicID: "12", locale: "zh-Hans", title: "夜", subtitle: "", summary: "")
        XCTAssertNil(translation["status"])
        XCTAssertFalse(translation.values.contains { ($0 as? String) == "APPROVED" })
        let object: [String: Any] = ["landingSummary": "A walk", "translationState": "APPROVED", "canonicalPath": "/t/12"]
        let fact = ContentLandingSource.fact(topicID: "12", object: object)
        XCTAssertEqual(fact.canonicalPath, "/t/12")
        XCTAssertTrue(fact.needsReviewAgain)
        XCTAssertEqual(fact.versionText, "—")
        XCTAssertEqual(fact.groupEligible, .undeclared)
    }

    func testHostTipReadPathsAreTheMineRoutes() async throws {
        let wire = Wire()
        let source = try HostTipSource(configuration: APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com/prod-api/")!),
                                       transport: wire, nowMillis: { 1_700_000_000_000 }, entropy: { "abcd1234" })
        _ = try await source.configs(token: "session-token")
        _ = try await source.intents(token: "session-token")
        XCTAssertEqual(wire.requests.map { $0.url?.path }, [
            "/prod-api/api/host-tip/config/mine",
            "/prod-api/api/host-tip/intent/mine"
        ])
    }

    private func fact(_ json: String) throws -> VideoBountyAttributionFact {
        let data = Data(json.utf8)
        let envelope = VideoBountyEnvelope(httpStatus: 200, code: "200", reasonCode: nil, message: nil, dataJSON: data, netFail: false, receiptReread: false)
        return try XCTUnwrap(VideoBountySource.attribution(in: envelope))
    }

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
        }
    }
}
