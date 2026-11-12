import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Platform pass and market reads, plus the four pass/market bindings. No purchase or claim.
final class PlatformPassReadTests: XCTestCase {
    func testReadsOverviewLibraryProductsOrdersGiftsAndPoints() async throws {
        let wire = Wire()
        wire.bodies["/api/platform-pass"] = envelope(#"""
        {"enabled":true,"libraryCount":12,"plans":[{"planCode":"YEAR","title":"年卡","priceFen":29900,"validDays":365},{"planCode":"MONTH","title":"月卡","priceFen":3900,"validDays":30}],"channels":{"jsapi":{"available":true},"xpay":{"available":false}},"holding":{"active":false,"validTo":null,"coverageEnd":null}}
        """#)
        wire.bodies["/api/platform-pass/library"] = envelope(#"""
        {"enabled":true,"covered":true,"rows":[{"topicId":5,"name":"老城三封信","productType":1,"totalTime":3600,"addressName":"外滩源","imgUrl":"u"},{"name":"x"}]}
        """#)
        wire.bodies["/api/marketing/product/list"] = envelope(#"""
        [{"productId":9,"productName":"城市包","productKind":2,"saleCity":"上海","validityKind":1,"validDays":30,"seatCount":1,"cashPrice":88,"pointsPrice":null,"items":[{"topicId":990014,"topicTitle":"老城"}]},{"productName":"缺编号"}]
        """#)
        wire.bodies["/api/marketing/product/orders"] = envelope(#"""
        [{"orderNo":"MO1","productId":9,"statusLabel":"PAID","fulfillmentKind":2,"payMode":2,"pointsAmount":12,"paidAt":"2026-11-02 09:30:00"}]
        """#)
        wire.bodies["/api/marketing/product/gifts/bought"] = envelope(#"""
        [{"giftId":3,"status":0,"claimExpiresAt":"2026-12-01","createdAt":"2026-11-01"}]
        """#)
        wire.bodies["/api/marketing/product/gifts/received"] = envelope(#"""
        [{"giftId":4,"status":1,"claimedAt":"2026-11-03"}]
        """#)
        wire.bodies["/api/user/info"] = envelope(#"{"point":18}"#)
        let reader = try make(wire)

        let overview = try await reader.overview(token: "session-token", viewerIsMerchant: false)
        XCTAssertTrue(overview.enabled)
        XCTAssertFalse(overview.merchantBlocked)
        XCTAssertEqual(overview.libraryCount, 12 as Int?)
        XCTAssertEqual(overview.plans.map(\.code), ["YEAR", "MONTH"])
        XCTAssertFalse(overview.xpayAvailable)
        XCTAssertEqual(wire.requests[0].httpMethod, "GET" as String?)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/platform-pass")
        XCTAssertEqual(wire.requests[0].value(forHTTPHeaderField: "Authorization"), "session-token")

        let library = try await reader.library(kind: "city", token: "session-token", viewerIsMerchant: false)
        XCTAssertEqual(library.cards.count, 1)
        XCTAssertEqual(library.cards[0].id, "5")
        XCTAssertEqual(library.cards[0].data, "城市定向 · 约 60 分钟")
        XCTAssertEqual(library.cards[0].tags, ["城市定向", "外滩源"])
        XCTAssertTrue(library.cards[0].free)
        XCTAssertEqual(wire.requests[1].url?.path, "/api/platform-pass/library")
        XCTAssertTrue(wire.requests[1].url?.query?.contains("limit=100") == true)
        XCTAssertTrue(wire.requests[1].url?.query?.contains("productType=1") == true)

        let products = try await reader.productList(token: "session-token")
        XCTAssertEqual(products.map(\.id), ["9"])
        XCTAssertEqual(products[0].kind, "城市包")
        XCTAssertEqual(products[0].price, "¥88.00")
        XCTAssertEqual(products[0].validity, "购买后 30 天内有效")
        XCTAssertEqual(products[0].topicIDs, ["990014"])
        XCTAssertEqual(wire.requests[2].url?.path, "/api/marketing/product/list")
        XCTAssertTrue(wire.requests[2].url?.query?.contains("limit=20") == true)

        let orders = try await reader.orders(token: "session-token")
        XCTAssertEqual(orders.first?.row(nameByID: ["9": "城市包"]).name, "城市包")
        XCTAssertEqual(orders.first?.state, "已购买 · 礼品")
        XCTAssertEqual(orders.first?.amount, "12 积分")
        XCTAssertEqual(orders.first?.time, "2026.11.02")
        XCTAssertEqual(wire.requests[3].url?.path, "/api/marketing/product/orders")

        let gifts = try await reader.gifts(token: "session-token")
        XCTAssertEqual(gifts.bought.map(\.state), ["待领取 · 领取前你和对方都不能游玩"])
        XCTAssertEqual(gifts.bought.map(\.expires), ["领取截止 2026.12.01"])
        XCTAssertEqual(gifts.received.map(\.state), ["已领取"])
        XCTAssertFalse(gifts.claimReachable)
        XCTAssertFalse(gifts.bought[0].claimReachable)
        XCTAssertEqual(wire.requests[4].httpMethod, "GET" as String?)
        XCTAssertEqual(wire.requests[4].url?.path, "/api/marketing/product/gifts/bought")
        XCTAssertEqual(wire.requests[5].url?.path, "/api/marketing/product/gifts/received")

        let points = try await reader.points(token: "session-token")
        XCTAssertEqual(points, 18.0 as Double?)
        XCTAssertEqual(wire.requests[6].httpMethod, "POST" as String?)
        XCTAssertEqual(wire.requests[6].url?.path, "/api/user/info")
        XCTAssertNil(wire.requests[6].httpBody)

        let forbidden = ["/api/platform-pass/orders", "/api/marketing/product/quote", "/api/marketing/product/order", "/api/marketing/product/gifts/claim"]
        XCTAssertTrue(wire.requests.allSatisfy { forbidden.contains($0.url?.path ?? "") == false })
        XCTAssertEqual(wire.requests.count, 7)
    }

    func testStringCodeUnknownCountAndZeroPointsStayLiteral() async throws {
        let wire = Wire()
        wire.bodies["/api/platform-pass"] = Data(#"{"code":"200","data":{"enabled":true,"libraryCount":null,"plans":[]}}"#.utf8)
        wire.bodies["/api/platform-pass/library"] = envelope(#"{"enabled":false,"covered":true,"rows":[{"topicId":1,"name":"隐藏"}]}"#)
        wire.bodies["/api/user/info"] = envelope(#"{"point":0}"#)
        let reader = try make(wire)
        let overview = try await reader.overview(token: "session-token", viewerIsMerchant: false)
        XCTAssertNil(overview.libraryCount)
        XCTAssertNotEqual(overview.libraryCount, 0 as Int?)
        let library = try await reader.library(kind: "all", token: "session-token", viewerIsMerchant: false)
        XCTAssertFalse(library.enabled)
        XCTAssertTrue(library.cards.isEmpty)
        XCTAssertFalse(wire.requests[1].url?.query?.contains("productType=") == true)
        let points = try await reader.points(token: "session-token")
        XCTAssertEqual(points, 0.0 as Double?)
        wire.bodies["/api/user/info"] = envelope(#"{"nick":"a"}"#)
        let missing = try await reader.points(token: "session-token")
        XCTAssertNil(missing)
    }

    func testMerchantSkipsOverviewAndLibraryAndABadTokenSendsNothing() async throws {
        let wire = Wire()
        let reader = try make(wire)
        let overview = try await reader.overview(token: "session-token", viewerIsMerchant: true)
        let library = try await reader.library(kind: "free", token: "session-token", viewerIsMerchant: true)
        XCTAssertTrue(overview.merchantBlocked)
        XCTAssertFalse(overview.enabled)
        XCTAssertTrue(library.merchantBlocked)
        XCTAssertTrue(wire.requests.isEmpty)
        do {
            _ = try await reader.productList(token: " ")
            XCTFail("blank token")
        } catch APIError.invalidRequest {
        } catch { XCTFail("unexpected \(error)") }
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testPassAndMarketBindingsStayReadOnly() {
        XCTAssertEqual(MPParityBindings.passAndMarket.map(\.rawValue), ["viewerIsMerchant", "passStoreCard", "passCheckoutCover", "orderDetail"])
        XCTAssertFalse(MPParityBindings.moneyEnabled)
        XCTAssertFalse(MPParityBindings.viewerIsMerchant(role: "player"))
        XCTAssertTrue(MPParityBindings.viewerIsMerchant(role: "merchant"))
        XCTAssertTrue(MPParityBindings.viewerIsMerchant(role: "", userType: "2"))
        XCTAssertFalse(MPParityBindings.viewerIsMerchant(role: "merchant", debugView: "user"))
        XCTAssertFalse(MPParityBindings.viewerIsMerchant(role: "", userType: "2", debugView: "user"))

        let selling = PlatformPassOverview(
            enabled: true, merchantBlocked: false, libraryCount: 12,
            plans: [PlatformPassPlan(code: "YEAR", title: "年卡", priceFen: 29900, validDays: 365),
                    PlatformPassPlan(code: "MONTH", title: "月卡", priceFen: 3900, validDays: 30)],
            holding: PlatformPassHolding(active: false, validTo: nil, coverageEnd: nil),
            jsapiAvailable: true, xpayAvailable: false)
        let card = MPParityBindings.passStoreCard(viewerIsMerchant: false, overview: selling)
        XCTAssertTrue(card.shown)
        XCTAssertEqual(card.side, "¥299 · ¥39")
        XCTAssertFalse(card.purchaseReachable)
        XCTAssertFalse(MPParityBindings.passStoreCard(viewerIsMerchant: true, overview: selling).shown)
        let held = PlatformPassOverview(
            enabled: true, merchantBlocked: false, libraryCount: nil, plans: selling.plans,
            holding: PlatformPassHolding(active: true, validTo: "2027-11-10 12:00:00", coverageEnd: "2027-12-10 12:00:00"),
            jsapiAvailable: true, xpayAvailable: true)
        XCTAssertEqual(MPParityBindings.passStoreCard(viewerIsMerchant: false, overview: held).side, "有效期至 2027.12.10")
        let counted = PlatformPassOverview(
            enabled: true, merchantBlocked: false, libraryCount: 0, plans: [],
            holding: PlatformPassHolding(active: false, validTo: nil, coverageEnd: nil),
            jsapiAvailable: false, xpayAvailable: false)
        XCTAssertEqual(MPParityBindings.passStoreCard(viewerIsMerchant: false, overview: counted).side, "0 个主题全部可玩")
        XCTAssertFalse(MPParityBindings.passStoreCard(viewerIsMerchant: false, overview: .merchantBlocked).shown)

        let city = product(id: "1", name: "城市包", kind: 2, topics: ["990014"])
        let gift = product(id: "7", name: "礼品", kind: 7, topics: ["990014"])
        let covered = MPParityBindings.passCheckoutCover(
            selfPlayPrice: 39, quoteState: "ready", payAmount: 0, memberDiscountYuan: 39,
            platformPassCovered: true, products: [city, gift], topicID: "990014")
        XCTAssertTrue(covered.covered)
        XCTAssertEqual(covered.totalText, "¥0")
        XCTAssertEqual(covered.payLabel, "免费领取")
        XCTAssertEqual(covered.bill.map { ($0.label, $0.value) }, [("自玩门票 × 1", "¥39"), ("通行证", "你已可直接游玩")])
        XCTAssertTrue(covered.passes.isEmpty)
        XCTAssertFalse(covered.purchaseReachable)

        let open = MPParityBindings.passCheckoutCover(
            selfPlayPrice: 39, quoteState: "ready", payAmount: 31.2, memberDiscountYuan: 7.8,
            platformPassCovered: false, products: [city, gift], topicID: "990014")
        XCTAssertFalse(open.covered)
        XCTAssertEqual(open.bill.map(\.value), ["¥39", "-¥7.80"])
        XCTAssertEqual(open.passes.map(\.id), ["1"])
        XCTAssertEqual(open.payLabel, "支付 ¥31.20")
        XCTAssertFalse(open.purchaseReachable)

        let detail = MPParityBindings.orderDetail(
            id: "ORD-1", purchaseKind: 2, ownerType: 1, ticketID: nil, expiresAt: "2027-12-11 00:00:00",
            wechatPaymentAmount: nil, payableAmount: 0, totalAmount: 0, pointPaymentAmount: nil)
        XCTAssertTrue(detail.shown)
        XCTAssertTrue(detail.selfPlayPass)
        XCTAssertEqual(detail.untilText, "可玩至 12 月 10 日")
        XCTAssertEqual(detail.actualPaid, 0.0 as Double?)
        XCTAssertTrue(detail.free)
        XCTAssertFalse(detail.payReachable)
        XCTAssertFalse(detail.refundReachable)
        let paid = MPParityBindings.orderDetail(
            id: "ORD-2", purchaseKind: nil, ownerType: 1, ticketID: nil, expiresAt: "2027-12-10 12:00:00",
            wechatPaymentAmount: 12, payableAmount: 0, totalAmount: 0, pointPaymentAmount: 0)
        XCTAssertTrue(paid.selfPlayPass)
        XCTAssertEqual(paid.untilText, "可玩至 12 月 10 日")
        XCTAssertEqual(paid.actualPaid, 12.0 as Double?)
        XCTAssertFalse(paid.free)
        XCTAssertFalse(MPParityBindings.orderDetail(
            id: "", purchaseKind: 2, ownerType: nil, ticketID: nil, expiresAt: nil,
            wechatPaymentAmount: nil, payableAmount: nil, totalAmount: nil, pointPaymentAmount: nil).shown)
    }

    private func product(id: String, name: String, kind: Int, topics: [String]) -> PlatformPassProduct {
        PlatformPassProduct(id: id, name: name, kind: "", city: "上海", validity: "", seats: "", price: "",
                            coverCount: topics.count, topics: [], topicIDs: topics, giftOnly: kind == 7,
                            isExtraSeat: kind == 8, cashPrice: 88, pointsPrice: nil, productKind: kind,
                            validityKind: 1, validDays: 30)
    }

    private func make(_ wire: Wire) throws -> PlatformPass {
        try PlatformPass(configuration: APIConfiguration(baseURL: URL(string: "https://fixture.example.test")!), transport: wire)
    }

    private func envelope(_ data: String) -> Data {
        Data(#"{"code":200,"msg":"ok","data":\#(data)}"#.utf8)
    }

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var bodies: [String: Data] = [:]
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (bodies[request.url?.path ?? ""] ?? Data("{}".utf8), 200)
        }
    }
}
