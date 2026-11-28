import XCTest
@testable import Questify

/// fix-1128b play wave: the shipped (Release) China composition switches on what the planning audit found dormant.
/// Every case builds `RegionalLaunchConfiguration.shippedComposition` (→ `reviewedComposition` → `reviewedDeployment`)
/// and asserts the approval is non-nil and admits the exact path(s). Merchant routes stay off.
@MainActor final class Fix1128bPlayReleaseCompositionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    private func composition(_ recorder: Fix1128bRecorder) -> AppCompositionRoot {
        RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
    }

    private func playerContext(_ composition: AppCompositionRoot) throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: "player-token")
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }

    private func request(_ base: URL, _ path: String, method: String, query: String? = nil, json: String? = nil, token: String) throws -> URLRequest {
        var parts = try XCTUnwrap(URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false))
        parts.query = query
        var request = URLRequest(url: try XCTUnwrap(parts.url))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        if let json {
            request.httpBody = Data(json.utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    /// #5 photo devices + upload, #19 preference/tags capabilities, #22 kit artwork hosts.
    func testReleasePlayConfigurationTurnsOnPhotoUploadPreferenceTagsAndArtwork() throws {
        let built = composition(Fix1128bRecorder())
        XCTAssertTrue(try XCTUnwrap(built.reviewed).playerWritesEnabled)
        let player = try playerContext(built)
        let configuration = try XCTUnwrap(built.sessionDependencies(player).configuration)
        XCTAssertEqual(configuration.devices, [.photo, .scan, .location, .motion])
        XCTAssertTrue(configuration.play.isSuperset(of: [.mediaUpload, .preference, .tags, .reads, .classicCompletion]))
        XCTAssertFalse(configuration.play.contains(.leader))
        XCTAssertFalse(configuration.play.contains(.directorCommands))
        XCTAssertTrue(configuration.artworkHosts.contains("www.chengyinhub.com"))
        XCTAssertFalse(configuration.artworkHosts.contains { $0.contains("://") || $0.contains("/") })
        XCTAssertEqual(ReviewedProductionGateLeases.playArtworkHosts(apiBase: player.baseURL, extra: "https://cdn.example.test, http://plain.example.test, https://port.example.test:8443"),
                       ["www.chengyinhub.com", "cdn.example.test"])
        for path in ["api/common/uploadOSS", "api/play/photo", "api/play/ending", "api/play/leaderboard",
                     "api/play/preference/{}", "api/play/preference/{}/submit", "api/play/tag/{}/confirm",
                     "api/play/tag/{}/correct", "api/play/tag/{}/revoke", "api/play/os/{}",
                     "api/compliance/consents", "api/compliance/consents/latest"] {
            XCTAssertTrue(configuration.endpoints.paths.contains(path), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        XCTAssertFalse(configuration.endpoints.paths.contains { $0.hasPrefix("api/merchant/") })
    }

    /// #19: the runtime transport admits a templated approved path filled with an id, and nothing else.
    func testRuntimeTransportMatchesTemplatedPlayPathsOnly() throws {
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let paths: Set<String> = ["api/play/os/{}", "api/play/tag/{}/revoke", "api/play/preference/{}/submit", "api/play/nodes"]
        func admits(_ path: String) -> Bool { RuntimeDependencyTransport.admits(base.appendingPathComponent(path), paths: paths, baseURL: base) }
        XCTAssertTrue(admits("api/play/nodes"))
        XCTAssertTrue(admits("api/play/os/71"))
        XCTAssertTrue(admits("api/play/tag/81/revoke"))
        XCTAssertTrue(admits("api/play/preference/34/submit"))
        XCTAssertFalse(admits("api/play/os/abc"))
        XCTAssertFalse(admits("api/play/tag/81/delete"))
        XCTAssertFalse(admits("api/play/preference/34"))
        XCTAssertFalse(admits("api/play/nodes/9"))
        XCTAssertFalse(admits("api/merchant/71"))
        XCTAssertFalse(RuntimeDependencyTransport.admits(try XCTUnwrap(URL(string: "https://other.example.test/prod-api/api/play/os/71")), paths: paths, baseURL: base))
    }

    /// #16, #19, #21: the shipped runtime transport sends the finish reads, the templated reads/writes and the consent
    /// routes through the composition lease to the wire.
    func testShippedRuntimeTransportSendsFinishPreferenceTagOSAndConsentRoutes() async throws {
        let recorder = Fix1128bRecorder()
        let built = composition(recorder)
        let player = try playerContext(built)
        let composed = built.transport()
        composed.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let api = try APIConfiguration(baseURL: player.baseURL)
        let factory = RuntimeDependencyFactory(api: api, configuration: built.sessionDependencies(player).configuration,
                                               transport: composed, current: { player })
        XCTAssertNotNil(factory.accepted)
        let token = player.session.token, base = player.baseURL
        let sends: [URLRequest] = [
            try request(base, "api/play/ending", method: "GET", query: "topicId=12", token: token),
            try request(base, "api/play/leaderboard", method: "GET", query: "topicId=12", token: token),
            try request(base, "api/play/preference/34", method: "GET", query: "topicId=12", token: token),
            try request(base, "api/play/os/71", method: "GET", token: token),
            try request(base, "api/play/tag/81/revoke", method: "POST", token: token),
            try request(base, "api/play/tag/81/confirm", method: "POST", token: token),
            try request(base, "api/play/tag/81/correct", method: "POST", json: #"{"tagValue":"night"}"#, token: token),
            try request(base, "api/play/preference/34/submit", method: "POST", json: #"{"choices":{"q1":"a"},"topicId":12}"#, token: token)
        ]
        for outgoing in sends {
            _ = try await factory.transport.send(outgoing)
            XCTAssertEqual(recorder.paths.last, outgoing.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/"))
        }
        do {
            _ = try await factory.transport.send(try request(base, "api/play/os/abc", method: "GET", token: token))
            XCTFail("a non-id template segment stays refused")
        } catch {
            XCTAssertEqual(error as? PlayExperienceError, .disabled)
        }
        let grant = try XCTUnwrap(built.playerWriteGrant(player))
        let consentLatest = try request(base, "api/compliance/consents/latest", method: "POST",
            json: #"{"docType":"merchant_onsite","scene":"store_day","scopeId":81,"scopeType":"MERCHANT"}"#, token: token)
        XCTAssertTrue(grant.play.paths.contains("api/compliance/consents/latest"))
        XCTAssertTrue(factory.accepted?.endpoints.paths.contains("api/compliance/consents/latest") == true)
        XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(
            try request(base, "api/play/tag/81/revoke", method: "POST", token: token), baseURL: base, token: token, context: player, grant: grant))
        XCTAssertFalse(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(
            try request(base, "api/play/tag/81/revoke", method: "GET", token: token), baseURL: base, token: token, context: player, grant: grant))
        XCTAssertNotNil(consentLatest.httpBody)
    }

    /// mp-journey r3 (plan audit J-09a / J-10b): the Release play lease admits the MP hint ladder and the points hint
    /// unlock (form fields session scope, nodeId, level match `PlayExperienceService.hint`; pinned in PlayModeLifecycleTests).
    func testReleasePlayLeaseAdmitsPuzzleHintAndHintUnlock() throws {
        let built = composition(Fix1128bRecorder())
        let player = try playerContext(built)
        let configuration = try XCTUnwrap(built.sessionDependencies(player).configuration)
        XCTAssertTrue(configuration.play.contains(.hints))
        for path in ["api/play/puzzle/hint", "api/play/hint/unlock"] {
            XCTAssertTrue(configuration.endpoints.paths.contains(path), path)
            XCTAssertTrue(ReviewedProductionGateLeases.isPlayGrantPath(path), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        let grant = try XCTUnwrap(built.playerWriteGrant(player))
        XCTAssertTrue(grant.play.paths.isSuperset(of: ["api/play/puzzle/hint", "api/play/hint/unlock"]))
    }

    /// #21: the store-day gates the Release session builds permit proof and consent writes; merchant gates do not.
    func testStoreDayGatesOpenProofAndConsentWritesForThePlayerOnly() throws {
        let gates = MerchantCityNPCParityGates.playStoreDay
        let service = PlayStoreDayService(configuration: try APIConfiguration(baseURL: XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))),
                                          transport: Fix1128bRecorder(), market: .china, gates: gates, readsEnabled: true, currentSession: { nil })
        XCTAssertTrue(service.permitsProofWrites)
        XCTAssertTrue(service.permitsConsentWrites)
        let unitedStates = PlayStoreDayService(configuration: try APIConfiguration(baseURL: XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))),
                                               transport: Fix1128bRecorder(), market: .unitedStates, gates: gates, readsEnabled: true, currentSession: { nil })
        XCTAssertFalse(unitedStates.permitsProofWrites)
        XCTAssertFalse(MerchantCityNPCParityGates.mpFirst.storeDayPlayerEndpoints)
        XCTAssertFalse(MerchantCityNPCParityGates.mpFirst.allows("api/play/checkin", market: .china))
        XCTAssertFalse(gates.allows("api/merchant/coupon/publish", market: .china))
        XCTAssertFalse(MerchantCityNPCParityGates.storeDayChinaEndpoints.contains { $0.hasPrefix("api/merchant/") })
        let stored = ReviewedProductionGateLeases.playPaths
        for path in MerchantCityNPCParityGates.storeDayChinaEndpoints { XCTAssertTrue(stored.contains(path), path) }
    }
}

private final class Fix1128bRecorder: HTTPTransport {
    var paths: [String] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let relative = request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? ""
        paths.append(relative)
        return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
    }
}
