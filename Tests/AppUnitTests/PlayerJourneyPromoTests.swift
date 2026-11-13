import XCTest
@testable import Questify

@MainActor final class PlayerJourneyPromoTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"
    private let dash = "—"

    func testSummaryReadProjectsServerFactsAndDoesNotInventABalance() throws {
        let presented = try phase(#"""
        {"allocations":{"pending":{"allocationCount":2,"netAmount":null,"amountFen":150},
                        "confirmed":{"allocationCount":1,"netAmount":12.5},
                        "paid":{"allocationCount":0,"netAmount":"80"},
                        "reversed":{"amountUnavailableReason":"MULTIPLE_CURRENCIES","netAmount":9,"allocationCount":1}},
         "campaigns":[{"campaignKey":"c","targetId":"4","targetTitle":"江岸","attributedOrders":3,"paidOrders":null,"refundedOrders":0,"amountFen":999}],
         "credentials":[{"token":"secret-token","phone":"15500001111","targetType":1,"targetId":"4","targetTitle":"江岸","active":true,"expiresAt":"2026-11-12 08:30:00"}],
         "held":{"amountFen":80,"orders":2},"payout":{"available":true,"endpoint":"/api/withdrawal/create"}}
        """#)
        guard case .ready(let content) = presented else { return XCTFail("expected ready") }
        XCTAssertEqual(content.buckets.map(\.kind), [.pending, .confirmed, .paid, .reversed])
        XCTAssertNil(content.buckets[0].amountText)
        XCTAssertFalse(content.buckets[0].multiCurrency)
        XCTAssertEqual(content.buckets[0].count, 2)
        XCTAssertEqual(content.buckets[1].amountText, "¥12.50")
        XCTAssertNil(content.buckets[2].amountText)
        XCTAssertEqual(content.buckets[2].count, 0)
        XCTAssertNil(content.buckets[3].amountText)
        XCTAssertTrue(content.buckets[3].multiCurrency)
        XCTAssertEqual(content.heldOrders, 2)
        XCTAssertEqual(content.campaigns[0].title, "江岸")
        XCTAssertEqual(content.campaigns[0].attributed, 3)
        XCTAssertNil(content.campaigns[0].paid)
        XCTAssertEqual(content.campaigns[0].refunded, 0)
        XCTAssertEqual(content.links[0].title, "江岸")
        XCTAssertTrue(content.links[0].active)
        XCTAssertEqual(content.links[0].expiresText, "2026.11.12")
        XCTAssertFalse(content.links[0].id.contains("secret-token"))
        let rendered = dump(content)
        XCTAssertFalse(rendered.contains("secret-token"))
        XCTAssertFalse(rendered.contains("15500001111"))
        XCTAssertFalse(rendered.contains("150"))
        XCTAssertFalse(rendered.contains("999"))
        XCTAssertFalse(rendered.contains("80"))
        XCTAssertFalse(rendered.contains("/api/withdrawal"))
        XCTAssertEqual(MPText.unknown, dash)

        let arrayAmounts = try phase(#"""
        {"allocations":[{"amountFen":100},{"amountFen":50,"status":"paid"}],"held":{"amountFen":null},"payout":{"available":false}}
        """#)
        guard case .ready(let emptyAmounts) = arrayAmounts else { return XCTFail("expected ready") }
        XCTAssertTrue(emptyAmounts.buckets.isEmpty)
        XCTAssertNil(emptyAmounts.heldOrders)
        XCTAssertFalse(emptyAmounts.hasRecords)
        XCTAssertFalse(dump(emptyAmounts).contains("150"))
        XCTAssertFalse(dump(emptyAmounts).contains("100"))

        let same = try phase(#"""
        {"credentials":[],"campaigns":[],"allocations":{},"held":{"orders":null},"payout":{"available":false}}
        """#)
        let paid = try phase(#"""
        {"credentials":[],"campaigns":[],"allocations":{},"held":{"orders":null},"payout":{"available":true,"endpoint":"/api/asset/withdraw"}}
        """#)
        XCTAssertEqual(same, paid)
    }

    func testAuthAndFailureDoNotBecomeAnEmptyBalance() throws {
        XCTAssertEqual(try phase(#"{"code":401}"#, code: "401", status: 401), .auth)
        XCTAssertEqual(PlayerJourneyPromoProjection.phase(JourneyEnvelope.networkFailure), .failed)
        let missing = PlayerJourneyPromoProjection.phase(JourneyEnvelope(
            httpStatus: 200, code: "200", netFail: false, message: nil, dataJSON: nil, receiptReread: false))
        XCTAssertEqual(missing, .failed)
    }

    func testShippedChinaLoadsTheSummaryAndLeavesWritesUnsent() async throws {
        let body = Data(#"""
        {"code":200,"data":{"allocations":{"pending":{"allocationCount":1,"netAmount":null}},"held":{"amountFen":40},"payout":{"available":true}}}
        """#.utf8)
        let wire = PromoWire(body: body)
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { wire })
        let source = try XCTUnwrap(composition.playerJourneySource())
        let bindings = MPParityBindings.none.fillingPlayerJourneyReads(source: source, token: { "player-token" })
        let model = try XCTUnwrap(bindings.journeyPromo?())
        await model.reload()
        guard case .ready(let content) = model.phase else { return XCTFail("expected ready") }
        XCTAssertEqual(content.buckets.count, 4)
        XCTAssertNil(content.buckets[0].amountText)
        XCTAssertNil(content.heldOrders)
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].httpMethod, "GET")
        XCTAssertEqual(wire.requests[0].url?.path, "/prod-api/api/marketing/affiliate/summary")
        XCTAssertEqual(wire.requests[0].url?.query, "limit=20")
        XCTAssertThrowsError(try source.issueReferral(targetType: 1, targetID: "3", token: "player-token"))
        XCTAssertThrowsError(try source.giftClaim(token: "gift", requestID: "req", sessionToken: "player-token"))
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertFalse(MPCommerceGate.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)

        let closed = PlayerJourneyPromoModel(source: source, token: { nil })
        await closed.reload()
        XCTAssertEqual(closed.phase, .auth)
        XCTAssertEqual(wire.requests.count, 1)
    }

    private func phase(_ data: String, code: String = "200", status: Int = 200) throws -> JourneyPromoPhase {
        let object = try JSONSerialization.jsonObject(with: Data(data.utf8))
        let payload = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return PlayerJourneyPromoProjection.phase(JourneyEnvelope(
            httpStatus: status, code: code, netFail: false, message: nil, dataJSON: code == "200" ? payload : nil, receiptReread: false))
    }

    private func dump(_ content: JourneyPromoContent) -> String {
        let amounts = content.buckets.map { "\($0.amountText ?? dash):\($0.count.map(String.init) ?? dash)" }.joined(separator: "|")
        let deals = content.campaigns.map { "\($0.id):\($0.title ?? ""):\($0.attributed.map(String.init) ?? dash):\($0.paid.map(String.init) ?? dash):\($0.refunded.map(String.init) ?? dash)" }
        let links = content.links.map { "\($0.id):\($0.title ?? ""):\($0.expiresText ?? "")" }
        return amounts + deals.joined() + links.joined() + (content.heldOrders.map(String.init) ?? "")
    }
}

private final class PromoWire: HTTPTransport {
    var requests: [URLRequest] = []
    var body: Data
    init(body: Data) { self.body = body }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request)
        requests.append(request)
        return (body, 200)
    }
}
