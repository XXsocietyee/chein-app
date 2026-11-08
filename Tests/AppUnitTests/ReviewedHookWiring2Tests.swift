import XCTest
#if canImport(QuestifyApp)
@testable import QuestifyApp
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif
#else
@testable import Questify
#endif

/// GM-HOOK2 shared harness: a reviewed example.com composition (production gates on or off) and an unconfigured one,
/// both over a recording wire, plus helpers to ask which requests the composition transport lets through.
@MainActor
class ReviewedHookWiring2Base: XCTestCase {
    static let base = "https://api.example.com"
    static let token = "synthetic-7"

    final class Vault: AppTokenStorage {
        var value: String?
        func read() throws -> String? { value }
        func write(_ token: String) throws { value = token }
        func clear() throws { value = nil }
    }
    final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var respond: (URLRequest) -> Data = { _ in Data(#"{"code":200,"data":[]}"#.utf8) }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (respond(request), 200)
        }
    }

    func viewer(role: String = "player") -> CompositionHTTPTransport.SessionIdentity {
        .init(epoch: 1, accountID: 7, role: role, token: Self.token, viewerRevision: 1)
    }

    func composition(gates: Bool, wire: Wire, underlying: (any HTTPTransport)? = nil) throws -> AppCompositionRoot {
        let suite = "hook2-wiring-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let build = RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: Self.base,
            bundleIdentifier: "com.questify.ios", realm: "hook2-" + UUID().uuidString.lowercased())
        let deployment = try ReviewedAppDeployment(market: .china, baseURL: Self.base, approvedBaseURLs: [.china: [Self.base]],
            verifiedCapabilities: [.domesticChinaPhone], bundleIdentifier: "com.questify.ios", realm: build.realm!,
            reads: [], productionGatesEnabled: gates)
        let vault = Vault()
        return RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in vault }), makeTransport: { underlying ?? wire })
    }
    func unconfigured(wire: Wire) throws -> AppCompositionRoot {
        let suite = "hook2-unconf-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let vault = Vault()
        return RegionalLaunchConfiguration.makeComposition(reviewed: nil,
            build: .init(market: "CN", baseURL: Self.base, bundleIdentifier: "com.questify.ios", realm: "hook2-unconf"),
            storage: .init(defaults: defaults, tokenStore: { _ in vault }), makeTransport: { wire })
    }

    func context(_ composition: AppCompositionRoot, role: String = "player", market: RegionalMarket = .china) throws -> RuntimeDependencyContext {
        let namespace = composition.reviewed?.storageScope.service ?? "hook2-unconf"
        return RuntimeDependencyContext(market: market, baseURL: try XCTUnwrap(URL(string: Self.base)), role: role,
            session: try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: Self.token))
    }

    func request(_ method: String, _ url: String, body: String? = nil, contentType: String? = "application/json") -> URLRequest {
        var r = URLRequest(url: URL(string: url)!)
        r.httpMethod = method
        r.httpBody = body.map { Data($0.utf8) }
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType { r.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        r.setValue(Self.token, forHTTPHeaderField: "Authorization")
        return r
    }

    func sentPaths(_ transport: CompositionHTTPTransport, _ requests: [(String, URLRequest)], wire: Wire) async -> [String: Bool] {
        var out: [String: Bool] = [:]
        for (name, request) in requests {
            let before = wire.requests.count
            _ = try? await transport.send(request)
            out[name] = wire.requests.count > before
        }
        return out
    }
}

/// Item 1: merchant marketing home (30-day window) + AI insight reads. Settlement, subscription, commerce and the
/// prediction inbox stay off.
@MainActor
final class ReviewedMerchantMarketingWiringTests: ReviewedHookWiring2Base {
    private func exactRequests() -> [(String, URLRequest)] {
        let b = Self.base
        return [
            ("marketing-home", request("POST", b + "/api/merchant/marketing-home?windowDays=30", contentType: nil)),
            ("insight", request("POST", b + "/api/ai/merchant/insight", contentType: nil))
        ]
    }
    private func neighbours() -> [(String, URLRequest)] {
        let b = Self.base
        let evil = "https://evil.example.org"
        return [
            ("home-window-7", request("POST", b + "/api/merchant/marketing-home?windowDays=7", contentType: nil)),
            ("home-window-030", request("POST", b + "/api/merchant/marketing-home?windowDays=030", contentType: nil)),
            ("home-extra-query", request("POST", b + "/api/merchant/marketing-home?windowDays=30&x=1", contentType: nil)),
            ("home-other-key", request("POST", b + "/api/merchant/marketing-home?days=30", contentType: nil)),
            ("home-get", request("GET", b + "/api/merchant/marketing-home?windowDays=30", contentType: nil)),
            ("home-body", request("POST", b + "/api/merchant/marketing-home?windowDays=30", body: "{}")),
            ("insight-query", request("POST", b + "/api/ai/merchant/insight?x=1", contentType: nil)),
            ("insight-body", request("POST", b + "/api/ai/merchant/insight", body: "{}")),
            ("insight-get", request("GET", b + "/api/ai/merchant/insight", contentType: nil)),
            ("insight-sibling", request("POST", b + "/api/ai/merchant/insight/raw", contentType: nil)),
            ("settle", request("POST", b + "/api/merchant/predict/settle", body: "nodeId=1", contentType: "application/x-www-form-urlencoded; charset=utf-8")),
            ("predict-inbox", request("POST", b + "/api/merchant/predict/inbox", contentType: nil)),
            ("subscription", request("POST", b + "/api/merchant/subscription", body: "{}")),
            ("commerce", request("POST", b + "/api/merchant/commerce/capabilities", body: "{}")),
            ("foreign-home", request("POST", evil + "/api/merchant/marketing-home?windowDays=30", contentType: nil)),
            ("foreign-insight", request("POST", evil + "/api/ai/merchant/insight", contentType: nil))
        ]
    }

    func testUnconfiguredCompositionEnablesNothingAndRefusesEveryRoute() async throws {
        let wire = Wire()
        let root = try unconfigured(wire: wire)
        let gates = root.merchantMarketingGates
        XCTAssertFalse(gates.reads); XCTAssertFalse(gates.insight); XCTAssertFalse(gates.settlement)
        let transport = root.transport()
        transport.current = { self.viewer(role: "merchant") }
        let sent = await sentPaths(transport, exactRequests() + neighbours(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "\(sent)")
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testReviewedWithoutProductionGatesEnablesNothing() async throws {
        let wire = Wire()
        let root = try composition(gates: false, wire: wire)
        let gates = root.merchantMarketingGates
        XCTAssertFalse(gates.reads); XCTAssertFalse(gates.insight); XCTAssertFalse(gates.settlement)
        let transport = root.transport()
        transport.current = { self.viewer(role: "merchant") }
        let sent = await sentPaths(transport, exactRequests(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "\(sent)")
    }

    func testReviewedChinaCompositionEnablesReadsAndInsightButNeverSettlement() throws {
        let gates = try composition(gates: true, wire: Wire()).merchantMarketingGates
        XCTAssertTrue(gates.reads); XCTAssertTrue(gates.insight); XCTAssertFalse(gates.settlement)
    }

    func testReviewedChinaCompositionAllowsExactlyTheTwoRoutesForMerchantsOnly() async throws {
        let wire = Wire()
        let transport = try composition(gates: true, wire: wire).transport()
        transport.current = { self.viewer(role: "merchant") }
        let allowed = await sentPaths(transport, exactRequests(), wire: wire)
        for (name, sent) in allowed { XCTAssertTrue(sent, "reviewed composition must admit \(name)") }
        let refused = await sentPaths(transport, neighbours(), wire: wire)
        for (name, sent) in refused { XCTAssertFalse(sent, "reviewed composition must refuse \(name)") }
        XCTAssertEqual(wire.requests.count, allowed.count)

        let playerWire = Wire()
        let playerTransport = try composition(gates: true, wire: playerWire).transport()
        playerTransport.current = { self.viewer(role: "player") }
        let playerSent = await sentPaths(playerTransport, exactRequests(), wire: playerWire)
        XCTAssertFalse(playerSent.values.contains(true), "non-merchant viewers must be refused: \(playerSent)")

        let outWire = Wire()
        let outTransport = try composition(gates: true, wire: outWire).transport()
        outTransport.current = { CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil, viewerRevision: 1) }
        let outSent = await sentPaths(outTransport, exactRequests(), wire: outWire)
        XCTAssertFalse(outSent.values.contains(true), "signed-out viewers must be refused: \(outSent)")
    }

    func testServiceEmitsOnlyRequestsTheCompositionAdmits() async throws {
        let fixture = MerchantMarketingFixtureTransport()
        let wire = Wire()
        let root = try composition(gates: true, wire: wire, underlying: fixture)
        let transport = root.transport()
        transport.current = { self.viewer(role: "merchant") }
        let scope = try MerchantMarketingScope(namespace: "hook2", accountID: 7, epoch: 1, token: Self.token)
        let service = MerchantMarketingService(configuration: try APIConfiguration(baseURL: try XCTUnwrap(URL(string: Self.base))),
            transport: transport, gates: root.merchantMarketingGates, currentSession: { scope })
        XCTAssertTrue(service.permitsReads); XCTAssertTrue(service.permitsInsight); XCTAssertFalse(service.permitsSettlement)
        _ = try await service.home()
        _ = try await service.insight()
        XCTAssertEqual(fixture.requests.compactMap { $0.url?.path },
                       ["/api/merchant/access/me", "/api/merchant/marketing-home", "/api/ai/merchant/insight"])
        do { _ = try await service.subscriptions(); XCTFail("subscription is not wired") } catch {}
        do { _ = try await service.inbox(); XCTFail("prediction inbox is not wired") } catch {}
        // inbox() reads access/me first (admitted); neither the subscription nor the prediction-inbox route reaches the wire.
        XCTAssertEqual(fixture.requests.compactMap { $0.url?.path }.suffix(1), ["/api/merchant/access/me"])
        XCTAssertEqual(fixture.requests.count, 4)
        XCTAssertFalse(fixture.requests.contains { ["/api/merchant/subscription", "/api/merchant/predict/inbox"].contains($0.url?.path) })

        let off = MerchantMarketingService(configuration: try APIConfiguration(baseURL: try XCTUnwrap(URL(string: Self.base))),
            transport: transport, gates: try unconfigured(wire: Wire()).merchantMarketingGates, currentSession: { scope })
        XCTAssertFalse(off.permitsReads); XCTAssertFalse(off.permitsInsight)
    }
}
