import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Platform pass and market reads. Purchase and claim stay on the unreachable test. Bindings live on the App struct.
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
        XCTAssertEqual(library.cards[0].productType, 1)
        XCTAssertEqual(library.cards[0].minuteCount, 60)
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

    func testOverviewTermsFollowTheMiniProgramPassTermsParser() async throws {
        let wire = Wire()
        wire.bodies["/api/platform-pass"] = envelope(#"""
        {"enabled":true,"plans":[],"terms":["有效期：至 2027-12-31","到期自动续费，可随时关闭","不支持退款","限本人及同行使用","覆盖已开通城市"]}
        """#)
        let reader = try make(wire)
        let overview = try await reader.overview(token: "session-token", viewerIsMerchant: false)
        XCTAssertEqual(wire.requests[0].httpMethod, "GET" as String?)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/platform-pass")
        XCTAssertEqual(overview.terms.period, "至 2027-12-31")
        XCTAssertEqual(overview.terms.renewal, "到期自动续费，可随时关闭")
        XCTAssertEqual(overview.terms.refund, "不支持退款")
        XCTAssertEqual(overview.terms.seat, "限本人及同行使用")
        XCTAssertEqual(overview.terms.coverage, "覆盖已开通城市")
        let olderObject: [String: Any] = [
            "period": "一年", "renewal": "按月", "refund": "不可退", "seat": "双人", "coverage": "城内"
        ]
        let older = PlatformPassTermFacts.parse(olderObject)
        XCTAssertEqual(older, PlatformPassTermFacts(period: "一年", renewal: "按月", refund: "不可退", seat: "双人", coverage: "城内"))
        let firstWins = PlatformPassTermFacts.parse(["续费一次", "再次续费"])
        XCTAssertEqual(firstWins.renewal, "续费一次")
        XCTAssertNil(firstWins.coverage)
    }

    func testChinaClockPassUntilRollsMidnightBackOneMillisecond() {
        XCTAssertEqual(MPParityChinaClock.passUntil("2027-12-11 00:00:00"), "可玩至 12 月 10 日")
        XCTAssertEqual(MPParityChinaClock.shownMonthDay("2027-12-11 00:00:00")?.month, 12)
        XCTAssertEqual(MPParityChinaClock.shownMonthDay("2027-12-11 00:00:00")?.day, 10)
        XCTAssertEqual(MPParityChinaClock.passUntil("2027-12-10 12:00:00"), "可玩至 12 月 10 日")
        XCTAssertEqual(MPParityChinaClock.dotDay("2027-12-10 12:00:00"), "2027.12.10")
        XCTAssertEqual(MPParityChinaClock.dotDay(nil), "")
        XCTAssertNil(MPParityChinaClock.shownMonthDay(""))
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
