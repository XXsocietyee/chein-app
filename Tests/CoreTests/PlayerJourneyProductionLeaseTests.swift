import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class PlayerJourneyProductionLeaseTests: XCTestCase {
    private let china = "https://www.chengyinhub.com/prod-api/"

    func testProductionHostStaysRefusedWithoutALease() throws {
        let wire = Wire()
        XCTAssertThrowsError(try source(wire, url: china)) { error in
            XCTAssertEqual(error as? JourneyRefusal, .productionEndpoint)
        }
        XCTAssertThrowsError(try reader(wire, url: china)) { error in
            XCTAssertEqual(error as? PWaveRefusal, .productionEndpoint)
        }
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testLeaseOpensTheNamedChinaHostAndKeepsMoneyUnsent() async throws {
        let wire = Wire()
        let journey = try source(wire, url: china, lease: JourneyProductionLease(host: "www.chengyinhub.com"))
        let report = try await journey.report(topicID: "12", token: "session-token")
        XCTAssertTrue(report.ok)
        XCTAssertEqual(wire.requests[0].url?.path, "/prod-api/api/play/player-journey/report")
        XCTAssertThrowsError(try journey.issueReferral(targetType: 1, targetID: "3", token: "session-token")) { error in
            XCTAssertEqual(error as? JourneyRefusal, .moneyOff)
        }
        XCTAssertThrowsError(try journey.giftClaim(token: "gift", requestID: "req-1", sessionToken: "session-token")) { error in
            XCTAssertEqual(error as? JourneyRefusal, .moneyOff)
        }
        let summary = try await journey.affiliate(token: "session-token")
        XCTAssertTrue(summary.ok)
        XCTAssertEqual(wire.requests[1].httpMethod, "GET")
        XCTAssertEqual(wire.requests[1].url?.path, "/prod-api/api/marketing/affiliate/summary")
        XCTAssertEqual(wire.requests[1].url?.query, "limit=20")
        do {
            _ = try await journey.rate(ownerType: 3, ownerID: "9", rating: 5, contents: "一起玩", requestID: "rateintent0000001", token: "session-token")
            XCTFail("owner type")
        } catch JourneyRefusal.invalidRequest {}
        XCTAssertEqual(wire.requests.count, 2)

        let reader = try reader(wire, url: china, lease: PWaveProductionReadLease(host: "www.chengyinhub.com"))
        XCTAssertTrue(reader.capabilities.allows(.themeCollection))
        XCTAssertFalse(reader.capabilities.allows(.affiliateCenter))
        XCTAssertFalse(reader.capabilities.allows(.cityPass))
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        _ = try await reader.themeCatalog(.cityList, fields: [:], token: nil, scope: scope, currentScope: { scope })
        XCTAssertEqual(wire.requests.last?.url?.path, "/prod-api/api/public-catalog/city/list")
        _ = try await reader.themeCatalog(.list, fields: [:], token: nil, scope: scope, currentScope: { scope })
        _ = try await reader.themeCatalog(.filters, fields: [:], token: nil, scope: scope, currentScope: { scope })
        _ = try await reader.themeCatalog(.info, fields: ["id": "9"], token: nil, scope: scope, currentScope: { scope })
        do {
            _ = try await reader.themeCatalog(.map, fields: [:], token: nil, scope: scope, currentScope: { scope })
            XCTFail("map")
        } catch PWaveRefusal.productionEndpoint {}
        do {
            _ = try await reader.themeCatalog(.ids, fields: ["ids": "9"], token: nil, scope: scope, currentScope: { scope })
            XCTFail("ids")
        } catch PWaveRefusal.productionEndpoint {}
        do {
            _ = try await reader.affiliateSummary(token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("affiliate")
        } catch PWaveRefusal.productionEndpoint {}
        do {
            _ = try await reader.products(token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("pass list")
        } catch PWaveRefusal.productionEndpoint {}
        XCTAssertThrowsError(try reader.quoteProduct(requestID: "req", token: "session-token")) { error in
            XCTAssertEqual(error as? PWaveRefusal, .writesNotAvailable)
        }
        XCTAssertThrowsError(try reader.orderProduct(requestID: "req", token: "session-token")) { error in
            XCTAssertEqual(error as? PWaveRefusal, .writesNotAvailable)
        }
        XCTAssertThrowsError(try reader.payProduct(orderNo: "1", requestID: "req", token: "session-token")) { error in
            XCTAssertEqual(error as? PWaveRefusal, .writesNotAvailable)
        }
        XCTAssertThrowsError(try reader.claimProductGift(credential: "gift", requestID: "req", token: "session-token")) { error in
            XCTAssertEqual(error as? PWaveRefusal, .writesNotAvailable)
        }
        let host = PublicCatalogHost(reader: reader)
        XCTAssertThrowsError(try host.quote(requestID: "req", token: "session-token"))
        XCTAssertThrowsError(try host.order(requestID: "req", token: "session-token"))
        XCTAssertThrowsError(try host.pay(orderNo: "1", requestID: "req", token: "session-token"))
        XCTAssertEqual(wire.requests.map { $0.url?.path }, [
            "/prod-api/api/play/player-journey/report",
            "/prod-api/api/marketing/affiliate/summary",
            "/prod-api/api/public-catalog/city/list",
            "/prod-api/api/public-catalog/list",
            "/prod-api/api/public-catalog/filters",
            "/prod-api/api/public-catalog/info"
        ])
    }

    func testUnknownSeatOutcomeKeepsTheSavedRequestIdOnTheProductionLease() async throws {
        let store = JourneyMemoryRequestStore()
        let wire = Wire(body: Data(#"{"code":503}"#.utf8), status: 503)
        let journey = try source(wire, url: china, store: store, lease: JourneyProductionLease(host: "www.chengyinhub.com"))
        let first = try await journey.seatInvite(registrationID: "15", token: "session-token")
        XCTAssertTrue(first.unconfirmed)
        let saved = store.read(JourneyRequestKey.seatInvite("15"))
        XCTAssertEqual(saved, "seatinv-loyw3v28-abcd1234")
        let again = try await journey.seatInvite(registrationID: "15", token: "session-token")
        XCTAssertTrue(again.unconfirmed)
        XCTAssertEqual(store.read(JourneyRequestKey.seatInvite("15")), saved)
        XCTAssertEqual(json(wire.requests[0])["requestId"], saved)
        XCTAssertEqual(json(wire.requests[1])["requestId"], saved)
    }

    func testOwnerGrantAdmitsTheReadsAndRefusesMoney() {
        for path in [
            "/api/play/player-journey/report",
            "/api/play/player-journey/memory",
            "/api/play/player-journey/choices",
            "/api/play/player-journey/seats",
            "/api/rank/list",
            "/api/referral/landing/referral",
            "/api/referral/landing/gift",
            "/api/play/seat-invitations/invite",
            "/api/play/seat-invitations/claim",
            "/api/play/seat-invitations/44",
            "/api/play/seat-invitations/44/cancel",
            "/api/play/seat-invitations/transfer-phone",
            "/api/play/seat-invitations/claim-phone/seat-token",
            "/api/play/seat-invitations/claim-phone/44",
            "/api/play/seat-invitations/mine",
            "/api/public-catalog/city/list",
            "/api/public-catalog/list",
            "/api/public-catalog/filters",
            "/api/public-catalog/info",
            "/api/comment/add",
            "/api/marketing/affiliate/summary"
        ] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        XCTAssertEqual(JourneyProductionLease.refused, [.issueReferral, .giftClaim])
        for path in [
            "/api/marketing/product/gifts/claim",
            "/api/marketing/referral/token",
            "/api/public-catalog/map",
            "/api/public-catalog/ids",
            "/api/registration/pay",
            "/api/registration/pay/app",
            "/api/login",
            "/api/pay/create"
        ] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        // 672 + H8 help use/skip + H1 template binding, binding-status, media attribution + IM in-game resolve/summary (679).
        XCTAssertEqual(ChinaReviewedRouteCapability.wiredPatternCount, 679)
        XCTAssertFalse(JourneyLoopSource.moneyWritesEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
    }

    private func source(_ wire: Wire, url: String, store: JourneyMemoryRequestStore = JourneyMemoryRequestStore(),
                        lease: JourneyProductionLease? = nil) throws -> JourneyLoopSource {
        try JourneyLoopSource(configuration: APIConfiguration(baseURL: URL(string: url)!), transport: wire, store: store,
                              endpointClass: lease == nil ? .nonProduction : .production,
                              nowMillis: { 1_700_000_000_000 }, entropy: { "abcd1234" }, productionLease: lease)
    }

    private func reader(_ wire: Wire, url: String, lease: PWaveProductionReadLease? = nil) throws -> PWaveReader {
        try PWaveReader(configuration: APIConfiguration(baseURL: URL(string: url)!), transport: wire,
                        endpointClass: lease == nil ? .nonProduction : .production,
                        capabilities: PWaveCapability(granted: PWaveProductionReadLease.grantedFeatures),
                        productionLease: lease)
    }

    private func json(_ request: URLRequest) -> [String: String] {
        guard let data = request.httpBody, let object = try? JSONSerialization.jsonObject(with: data) else { return [:] }
        return object as? [String: String] ?? [:]
    }

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var body: Data
        var status: Int
        init(body: Data = Data(#"{"code":200,"data":{"state":"VALID"}}"#.utf8), status: Int = 200) {
            self.body = body
            self.status = status
        }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (body, status)
        }
    }
}
