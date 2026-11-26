import XCTest
@testable import Questify

/// G6 grants live in both places: `ReviewedPlayerWriteLeases` (play paths and capability reads) and
/// `ChinaReviewedRouteCapability`. The shipped China composition admits them and still refuses money routes.
@MainActor final class G6CapabilityGrantTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    func testShippedChinaAdmitsG6PathsAndKeepsMoneyClosed() async throws {
        let recorder = G6Recorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let base = player.baseURL
        let grant = try XCTUnwrap(composition.playerWriteGrant(player))
        for write in ["api/ai/theme/draft/prepare", "api/ai/theme/draft/execute"] {
            XCTAssertTrue(grant.play.paths.contains(write), write)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + write), write)
        }
        let prepare = jsonRequest(base.appendingPathComponent("api/ai/theme/draft/prepare"),
            #"{"idea":"coffee","prepareKey":"0f8fad5b-d9cb-469f-a165-70867728950e","productType":1}"#, token: player.session.token)
        _ = try await transport.send(prepare)
        XCTAssertEqual(recorder.paths.last, "api/ai/theme/draft/prepare")
        let execute = jsonRequest(base.appendingPathComponent("api/ai/theme/draft/execute"),
            #"{"requestId":"td2_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}"#, token: player.session.token)
        _ = try await transport.send(execute)
        XCTAssertEqual(recorder.paths.last, "api/ai/theme/draft/execute")

        let reads: [(String, [URLQueryItem])] = [
            ("api/ai/npc/profile", [URLQueryItem(name: "scope", value: "global")]),
            ("api/ai/npc/event", [URLQueryItem(name: "profileId", value: "31"), URLQueryItem(name: "eventType", value: "roam_start"),
                                  URLQueryItem(name: "cacheOnly", value: "true")]),
            ("api/ai/theme/draft/recovery", []),
            ("api/marketing/promotions/catalog", [URLQueryItem(name: "ownerType", value: "2"), URLQueryItem(name: "ownerId", value: "42")]),
            ("api/marketing/revenue/author/mine", []),
            ("api/marketing/product/88", [])
        ]
        for (path, query) in reads {
            XCTAssertTrue(ReviewedProductionFormMutationRoute.coversCapabilityRead(path), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            _ = try await transport.send(try getRequest(base.appendingPathComponent(path), query: query, token: player.session.token))
            XCTAssertEqual(recorder.paths.last, path)
        }

        // The money-write switch is process-global and the host app installs it at launch (139e06853: money is on
        // for any installed host). Pin "no host derivation" so these checks measure the G6 grant, not test order.
        let savedDerivation = ReleaseMoneyWriteSwitch.testDerivation
        ReleaseMoneyWriteSwitch.testDerivation = nil
        defer { ReleaseMoneyWriteSwitch.testDerivation = savedDerivation }
        for path in ["api/marketing/attribution/claim", "api/marketing/product/order",
                     "api/marketing/product/quote", "api/marketing/product/gifts/claim", "api/registration/pay", "api/pay/create"] {
            XCTAssertFalse(ReviewedProductionGateLeases.playPaths.contains(path), path)
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent(path), #"{"amount":1}"#, token: player.session.token)) }
        }
        for path in ["api/ai/npc/chat/request", "api/author-write/receipt"] {
            XCTAssertFalse(ReviewedProductionFormMutationRoute.coversCapabilityRead(path), path)
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        // 7579bd41b (owner 2026-11-24): platform-pass order reads are on for players, so the path is admitted.
        // Any write on it (create, pay, cancel) is still refused by `isPlatformPassOrderWrite`, and the G6 play
        // grant still does not carry it.
        for path in ["api/platform-pass/orders", "api/platform-pass/orders/77"] {
            XCTAssertFalse(ReviewedProductionGateLeases.playPaths.contains(path), path)
            XCTAssertFalse(ReviewedProductionFormMutationRoute.coversCapabilityRead(path), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            let write = jsonRequest(base.appendingPathComponent(path), #"{"amount":1}"#, token: player.session.token)
            XCTAssertTrue(ChinaReviewedRouteCapability.isPlatformPassOrderWrite(write), path)
            await assertClosed { try await transport.send(write) }
        }
        XCTAssertFalse(recorder.paths.contains { $0.contains("attribution") || $0.contains("platform-pass") || $0.hasSuffix("/pay") })
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
    }

    private func assertClosed(_ body: () async throws -> some Any) async {
        do { _ = try await body(); XCTFail("expected the route to stay closed") }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
    }

    private func playerContext(_ composition: AppCompositionRoot) throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: "player-token")
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }

    private func getRequest(_ url: URL, query: [URLQueryItem], token: String) throws -> URLRequest {
        var parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        if !query.isEmpty { parts.queryItems = query }
        var request = URLRequest(url: try XCTUnwrap(parts.url))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        return request
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

private final class G6Recorder: HTTPTransport {
    var paths: [String] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let relative = request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? ""
        paths.append(relative)
        return (Data(#"{"code":200}"#.utf8), 200)
    }
}
