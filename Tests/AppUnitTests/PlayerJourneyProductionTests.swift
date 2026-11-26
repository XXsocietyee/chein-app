import XCTest
@testable import Questify

@MainActor final class PlayerJourneyProductionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    func testShippedChinaConstructsTheReadersAndPurchaseStaysUnreachable() async throws {
        let recorder = PathRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let source = try XCTUnwrap(composition.playerJourneySource())
        let reader = try XCTUnwrap(composition.playerPWaveReader())
        let host = try XCTUnwrap(composition.publicCatalogHost())
        XCTAssertFalse(reader.capabilities.allows(.affiliateCenter))
        XCTAssertFalse(reader.capabilities.allows(.cityPass))
        XCTAssertTrue(reader.capabilities.allows(.battleReport))
        XCTAssertTrue(reader.capabilities.allows(.inviteLanding))
        XCTAssertTrue(reader.capabilities.allows(.ticketSeats))
        XCTAssertTrue(reader.capabilities.allows(.themeCollection))
        let bindings = MPParityBindings.none.fillingPlayerJourneyReads(source: source, token: { "player-token" })
        XCTAssertNotNil(bindings.journeyLanding)
        XCTAssertNotNil(bindings.journeySeats)
        XCTAssertNotNil(bindings.journeyReport)
        XCTAssertNotNil(bindings.journeySettle)
        XCTAssertNotNil(bindings.journeyPromo)
        XCTAssertNil(bindings.passGift)
        XCTAssertFalse(PublicCatalogHost.moneyEnabled)
        XCTAssertFalse(MPCommerceGate.purchasesEnabled)
        XCTAssertFalse(MPCommerceGate.claimsEnabled)
        XCTAssertFalse(MPCommerceGate.payoutEnabled)

        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        _ = try await source.report(topicID: "12", token: "player-token")
        _ = try await reader.themeCatalog(.list, fields: [:], token: nil, scope: scope, currentScope: { scope })
        XCTAssertEqual(recorder.paths, ["api/play/player-journey/report", "api/public-catalog/list"])
        let summary = try await source.affiliate(token: "player-token")
        XCTAssertTrue(summary.ok)
        XCTAssertThrowsError(try source.issueReferral(targetType: 1, targetID: "3", token: "player-token"))
        XCTAssertThrowsError(try source.giftClaim(token: "gift", requestID: "req", sessionToken: "player-token"))
        XCTAssertThrowsError(try reader.quoteProduct(requestID: "req", token: "player-token"))
        XCTAssertThrowsError(try reader.claimProductGift(credential: "gift", requestID: "req", token: "player-token"))
        XCTAssertThrowsError(try host.quote(requestID: "req", token: "player-token"))
        XCTAssertThrowsError(try host.order(requestID: "req", token: "player-token"))
        XCTAssertThrowsError(try host.pay(orderNo: "1", requestID: "req", token: "player-token"))
        XCTAssertEqual(recorder.paths, ["api/play/player-journey/report", "api/public-catalog/list", "api/marketing/affiliate/summary"])

        XCTAssertNil(RegionalLaunchConfiguration.composition.playerJourneySource())
        XCTAssertNil(RegionalLaunchConfiguration.composition.playerPWaveReader())
        XCTAssertNil(RegionalLaunchConfiguration.composition.publicCatalogHost())
        let market = RegionalLaunchConfiguration.reviewedMarketComposition(
            market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm)
        XCTAssertNil(market.playerJourneySource())
        XCTAssertNil(market.publicCatalogHost())
        let gatesOnly = try ReviewedAppDeployment(market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: [.china: [ReviewedMarketLaunch.chinaProductionBaseURL]],
            verifiedCapabilities: [.domesticChinaPhone], bundleIdentifier: bundle, realm: "gates-only",
            productionGatesEnabled: true, playerWritesEnabled: false)
        let closed = RegionalLaunchConfiguration.makeComposition(reviewed: gatesOnly, build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: "gates-only"))
        XCTAssertNil(closed.playerJourneySource())
        XCTAssertNil(closed.playerPWaveReader())
        XCTAssertNil(closed.publicCatalogHost())

        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let base = player.baseURL
        // fix-r10 MKT-3-1b: the gift claim is admitted on production (MP `market/gift/index.js:101-123`); the
        // landing journey stub still throws, and the market/gift page sends it through `PlatformPassGiftClaimSource`.
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/marketing/product/gifts/claim"))
        // JREF-r11-1: the share referral token follows the payout switch (MP settle/index.js:264-279).
        XCTAssertEqual(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/marketing/referral/token"), ReleaseMoneyWriteSwitch.payoutEnabled)
        if !ReleaseMoneyWriteSwitch.payoutEnabled {
            await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/marketing/referral/token"), #"{"targetId":"1"}"#, token: player.session.token)) }
        }
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/registration/pay"), #"{"payAmount":1}"#, token: player.session.token)) }
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/login"), "{}", token: player.session.token)) }
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/roam/presence"), #"{"lat":1}"#, token: player.session.token)) }
        XCTAssertFalse(ReleaseMoneyWriteSwitch.blocks("/api/play/player-journey/report"))
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/pay"))
    }

    private func assertClosed(_ body: () async throws -> some Any) async {
        do { _ = try await body(); XCTFail("expected the call to stay closed") }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
    }

    private func playerContext(_ composition: AppCompositionRoot) throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: "player-token")
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }

    private func jsonRequest(_ url: URL, _ body: String, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        return request
    }
}

private final class PathRecorder: HTTPTransport {
    var paths: [String] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let relative = request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? ""
        paths.append(relative)
        return (Data(#"{"code":200,"data":{"state":"VALID"}}"#.utf8), 200)
    }
}
