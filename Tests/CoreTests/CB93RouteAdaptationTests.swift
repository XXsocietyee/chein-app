import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// CB93. Swift was not available in the authoring environment; these cases are authored and not run there.
final class CB93RouteAdaptationTests: XCTestCase {
    private func china(_ path: String) -> URL {
        URL(string: ReviewedMarketLaunch.chinaProductionBaseURL + path)!
    }

    func testAdaptedRoutesAreTheLiveChinaPathsOnly() {
        let expected: [String: String] = [
            "/api/topic/detail": "/api/topic/info-to-user",
            "/api/club/settlements": "/api/club/settlement/summary",
            "/api/club/update": "/api/club/update-mine",
            "/api/join-request/submit": "/api/club/join",
            "/api/space/leave": "/api/club/quit"
        ]
        XCTAssertEqual(Set(ChinaReviewedRouteAdaptation.routes.map(\.missing)), Set(expected.keys))
        for (missing, production) in expected {
            // 2026-11-13 backend-final-gaps: the original paths are now served or never sent; the adaptation stays.
            XCTAssertNotEqual(ChinaReviewedRouteCapability.mark(for: missing), .missing, missing)
            XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: production), .liveInProduction, production)
            XCTAssertEqual(ChinaReviewedRouteAdaptation.productionPath(forMissing: missing), production, missing)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(production), production)
            XCTAssertNil(ChinaReviewedRouteCapability.hidingCapability(for: production), production)
            XCTAssertTrue(ChinaReviewedRouteAdaptation.admits(missing: missing, baseURL: china("")))
            XCTAssertFalse(ChinaReviewedRouteAdaptation.admits(missing: missing, baseURL: URL(string: "https://example.com/prod-api/")!))
        }
    }

    func testEmptyURLAndHiddenCapabilitiesAreNotAdapted() {
        XCTAssertFalse(ChinaReviewedRouteAdaptation.admits(
            missing: "/api/topic/detail", baseURL: URL(string: "https://example.com/")!))
        XCTAssertNil(ChinaReviewedRouteAdaptation.productionPath(forMissing: "/api/login"))
        XCTAssertNil(ChinaReviewedRouteAdaptation.productionPath(forMissing: "/api/withdrawal/create"))
        XCTAssertNil(ChinaReviewedRouteAdaptation.productionPath(forMissing: "/api/cart/list"))
        XCTAssertNil(ChinaReviewedRouteAdaptation.productionPath(forMissing: "/api/registration/pay"))
        XCTAssertNil(ChinaReviewedRouteAdaptation.productionPath(forMissing: "/api/pay/create"))
        XCTAssertNil(ChinaReviewedRouteAdaptation.productionPath(forMissing: "/api/user/sms/send"))
        XCTAssertNil(ChinaReviewedRouteAdaptation.productionPath(forMissing: "/api/ugc/block"))
        XCTAssertNil(ChinaReviewedRouteAdaptation.productionPath(forMissing: "/api/growth/leaderboard/anonymous"))
        XCTAssertNil(ReviewedMarketLaunch.approvedBaseURLs[.unitedStates])
        // H2 marks /api/topic/publish-status missing on production + in-game channel resolve/summary.
        XCTAssertEqual(ChinaReviewedRouteCapability.callSiteCount, 996)
        // Channels contract 8.1: the five /api/native/blacklist/* routes are live (375 -> 370).
        XCTAssertEqual(ChinaReviewedRouteCapability.missingCount, 12)  // 2026-11-13 backend-final-gaps: only the 12 backend-closed workshop stubs stay missing (each row says why)
    }

    func testChinaTransportRewritesOnlyMatchingBodies() async throws {
        let wire = CB93RouteRecorder()
        let transport = ChinaReviewedProductionTransport(underlying: wire)

        var topic = URLRequest(url: china("api/topic/detail"))
        topic.httpMethod = "POST"
        topic.httpBody = Data("id=12".utf8)
        _ = try await transport.send(topic)
        XCTAssertEqual(wire.urls.last?.path, "/prod-api/api/topic/info-to-user")
        XCTAssertEqual(wire.bodies.last, Data("id=12".utf8))

        var settlement = URLRequest(url: china("api/club/settlements"))
        settlement.httpMethod = "POST"
        settlement.httpBody = Data(#"{"clubId":7}"#.utf8)
        _ = try await transport.send(settlement)
        XCTAssertEqual(wire.urls.last?.path, "/prod-api/api/club/settlement/summary")

        var update = URLRequest(url: china("api/club/update"))
        update.httpMethod = "POST"
        update.httpBody = Data(#"{"id":4,"name":"Club"}"#.utf8)
        _ = try await transport.send(update)
        XCTAssertEqual(wire.urls.last?.path, "/prod-api/api/club/update-mine")

        var foreign = URLRequest(url: URL(string: "https://example.com/prod-api/api/topic/detail")!)
        foreign.httpMethod = "POST"
        foreign.httpBody = Data("id=12".utf8)
        _ = try await transport.send(foreign)
        XCTAssertEqual(wire.urls.last?.host, "example.com")
        XCTAssertEqual(wire.calls, 4)
    }

    func testMismatchedAndHiddenChinaRequestsDoNotLeave() async {
        let wire = CB93RouteRecorder()
        let transport = ChinaReviewedProductionTransport(underlying: wire)
        let blocked: [URLRequest] = [
            post(china("api/topic/detail"), Data("id=0".utf8)),
            post(china("api/club/settlements"), Data(#"{"clubId":7,"export":true}"#.utf8)),
            post(china("api/club/update"), Data(#"{"id":4,"withdraw":true}"#.utf8)),
            post(china("api/login"), Data("{}".utf8)),
            post(china("api/withdrawal/create"), Data(#"{"amount":1}"#.utf8)),
            post(china("api/cart/list"), Data("{}".utf8)),
            post(china("api/pay/create"), Data("{}".utf8)),
            // `api/join-request/*` and `api/space/leave` are owner-granted since the channels contract (§6.10);
            // the deferred webhook and anchored audit-log routes stay hidden.
            post(china("api/im/webhook/not-issued"), Data(#"{"id":1}"#.utf8)),
            post(china("api/im/audit-log/not-issued"), Data(#"{"id":1}"#.utf8))
        ]
        for request in blocked {
            do {
                _ = try await transport.send(request)
                XCTFail(request.url?.path ?? "")
            } catch APIError.notConfigured {
            } catch {
                XCTFail("\(error)")
            }
        }
        XCTAssertEqual(wire.calls, 0)
    }

    func testClubJoinAndLeaveUseProductionRoutesOnlyOnTheChinaHost() async throws {
        let chinaWire = CB93RouteRecorder()
        let chinaClient = try admissionClient(base: china(""), transport: chinaWire)
        chinaWire.body = Data(#"{"code":200,"msg":"ok","data":{"state":"pending"}}"#.utf8)
        let catalog = try ChannelCatalogEntry(
            channelID: 21, conversationID: 12, kind: .group,
            rules: try ChannelRulesCAS(publishedVersion: 3, pendingVersion: nil, expectedVersion: 3))
        let joined = try await chinaClient.submit(
            catalog: catalog, kind: 1, spaceID: 12, inviteID: nil, message: "  hi  ", requestID: "c93-join-01")
        XCTAssertEqual(joined["state"] as? String, "pending")
        XCTAssertEqual(chinaWire.urls.last?.path, "/prod-api/api/club/join")
        let joinBody = try JSONSerialization.jsonObject(with: chinaWire.bodies.last ?? Data()) as? [String: Any]
        XCTAssertEqual(joinBody?["id"] as? Int, 12)
        XCTAssertEqual(joinBody?["joinMessage"] as? String, "hi")
        XCTAssertNil(joinBody?["request_id"])

        chinaWire.body = Data(#"{"code":200,"msg":"已退出"}"#.utf8)
        let left = try await chinaClient.leave(kind: 1, spaceID: 12, requestID: "c93-leave-01")
        XCTAssertEqual(left["left"] as? Bool, true)
        XCTAssertEqual(chinaWire.urls.last?.path, "/prod-api/api/club/quit")

        chinaWire.body = Data(#"{"code":200,"msg":"未加入"}"#.utf8)
        do {
            _ = try await chinaClient.leave(kind: 1, spaceID: 12, requestID: "c93-leave-02")
            XCTFail("not a member")
        } catch ChannelAuthorizationError.invalidCatalog {}
        XCTAssertEqual(chinaWire.urls.last?.path, "/prod-api/api/club/quit")

        chinaWire.body = Data(#"{"code":200,"data":{"state":"pending"}}"#.utf8)
        _ = try await chinaClient.submit(
            catalog: catalog, kind: 1, spaceID: 12, inviteID: 4, message: nil, requestID: "c93-invite-01")
        XCTAssertEqual(chinaWire.urls.last?.path, "/prod-api/api/join-request/submit")

        chinaWire.body = Data(#"{"code":200,"data":{"guild_kind":3,"guild_id":"12","left":true}}"#.utf8)
        _ = try await chinaClient.leave(kind: 3, spaceID: 12, requestID: "c93-team-01")
        XCTAssertEqual(chinaWire.urls.last?.path, "/prod-api/api/space/leave")

        let other = CB93RouteRecorder()
        let otherClient = try admissionClient(base: URL(string: "https://api.example.test/prod-api")!, transport: other)
        other.body = Data(#"{"code":200,"data":{"guild_kind":1,"guild_id":"12","left":true}}"#.utf8)
        _ = try await otherClient.leave(kind: 1, spaceID: 12, requestID: "c93-other-01")
        XCTAssertEqual(other.urls.last?.path, "/prod-api/api/space/leave")
    }

    private func post(_ url: URL, _ body: Data) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        return request
    }

    private func admissionClient(base: URL, transport: CB93RouteRecorder) throws -> ChannelAdmissionGovernanceClient {
        let configuration = try APIConfiguration(baseURL: base)
        let identity = try ChannelAccount4Identity(accountID: 7, epoch: 1)
        let admission = try ChannelRulesAdmission(identity: identity, consentedVersion: 3)
        return try ChannelAdmissionGovernanceClient(
            configuration: configuration, transport: transport, token: "token", admission: admission)
    }
}

private final class CB93RouteRecorder: HTTPTransport {
    var calls = 0
    var urls: [URL] = []
    var bodies: [Data] = []
    var body = Data(#"{"code":200,"data":{}}"#.utf8)
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        calls += 1
        if let url = request.url { urls.append(url) }
        bodies.append(request.httpBody ?? Data())
        return (body, 200)
    }
}
