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

    /// MP-first (owner 2026-11-25): the MP settles predictions (pages/merchant/predict/index.js:215).
    func testReviewedChinaCompositionEnablesReadsAndInsightButNeverSettlement() throws {
        let gates = try composition(gates: true, wire: Wire()).merchantMarketingGates
        XCTAssertTrue(gates.reads); XCTAssertTrue(gates.insight); XCTAssertTrue(gates.settlement)
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
        // Settlement also needs a lock store; this service has none, so it still cannot settle.
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

/// Item 2: anonymous roam share-snapshot read (`api/roam/share/snapshot?token=`). The share-token entry point
/// (link -> `RoamSharedFootprintView`) has no production host yet; only the reader and the transport route are wired.
@MainActor
final class ReviewedRoamShareSnapshotWiringTests: ReviewedHookWiring2Base {
    private static let hex = "0123456789abcdef0123456789abcdef"
    private func anonymous(_ url: String, method: String = "GET") -> URLRequest {
        var r = URLRequest(url: URL(string: url)!)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        return r
    }
    private func exactRequests() throws -> [(String, URLRequest)] {
        let token = try XCTUnwrap(RoamShareToken(Self.hex))
        return [("snapshot", try token.request(baseURL: try XCTUnwrap(URL(string: Self.base))))]
    }
    private func neighbours() throws -> [(String, URLRequest)] {
        let b = Self.base
        let evil = "https://evil.example.org"
        var withAuth = anonymous(b + "/api/roam/share/snapshot?token=" + Self.hex)
        withAuth.setValue(Self.token, forHTTPHeaderField: "Authorization")
        var withCookie = anonymous(b + "/api/roam/share/snapshot?token=" + Self.hex)
        withCookie.setValue("a=b", forHTTPHeaderField: "Cookie")
        var withBody = anonymous(b + "/api/roam/share/snapshot?token=" + Self.hex)
        withBody.httpBody = Data("x".utf8)
        return [
            ("authorized", withAuth), ("cookie", withCookie), ("body", withBody),
            ("post", anonymous(b + "/api/roam/share/snapshot?token=" + Self.hex, method: "POST")),
            ("uppercase", anonymous(b + "/api/roam/share/snapshot?token=" + Self.hex.uppercased())),
            ("short", anonymous(b + "/api/roam/share/snapshot?token=abc")),
            ("no-token", anonymous(b + "/api/roam/share/snapshot")),
            ("extra-query", anonymous(b + "/api/roam/share/snapshot?token=" + Self.hex + "&x=1")),
            ("wrong-key", anonymous(b + "/api/roam/share/snapshot?id=" + Self.hex)),
            ("revoke", anonymous(b + "/api/roam/share/revoke?token=" + Self.hex)),
            ("sibling", anonymous(b + "/api/roam/share/snapshots?token=" + Self.hex)),
            ("foreign", anonymous(evil + "/api/roam/share/snapshot?token=" + Self.hex))
        ]
    }

    func testUnconfiguredCompositionIsNotApprovedAndRefusesTheRoute() async throws {
        let wire = Wire()
        let root = try unconfigured(wire: wire)
        XCTAssertFalse(root.isRoamShareSnapshotApproved)
        let transport = root.transport()
        for identity in [viewer(), CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil, viewerRevision: 1)] {
            transport.current = { identity }
            let sent = await sentPaths(transport, try exactRequests(), wire: wire)
            XCTAssertFalse(sent.values.contains(true), "\(sent)")
        }
    }

    func testReviewedWithoutProductionGatesIsNotApprovedAndRefusesTheRoute() async throws {
        let wire = Wire()
        let root = try composition(gates: false, wire: wire)
        XCTAssertFalse(root.isRoamShareSnapshotApproved)
        let transport = root.transport()
        transport.current = { CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil, viewerRevision: 1) }
        let sent = await sentPaths(transport, try exactRequests(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "\(sent)")
    }

    func testReviewedChinaCompositionAllowsOnlyTheExactAnonymousReadForSignedOutAndSignedInViewers() async throws {
        XCTAssertTrue(try composition(gates: true, wire: Wire()).isRoamShareSnapshotApproved)
        for identity in [viewer(), CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil, viewerRevision: 1)] {
            let wire = Wire()
            let transport = try composition(gates: true, wire: wire).transport()
            transport.current = { identity }
            let allowed = await sentPaths(transport, try exactRequests(), wire: wire)
            for (name, sent) in allowed { XCTAssertTrue(sent, "must admit \(name) for \(String(describing: identity.role))") }
            let refused = await sentPaths(transport, try neighbours(), wire: wire)
            for (name, sent) in refused { XCTAssertFalse(sent, "must refuse \(name)") }
            XCTAssertEqual(wire.requests.count, 1)
            XCTAssertNil(wire.requests.first?.value(forHTTPHeaderField: "Authorization"))
        }
    }

    func testSessionReaderIsNilWhenUnapprovedAndReadsWhenApproved() async throws {
        let off = try unconfigured(wire: Wire())
        XCTAssertNil(RoamShareSnapshotReaderFactory.make(baseURL: URL(string: Self.base), transport: Wire(),
            approval: off.isRoamShareSnapshotApproved ? { true } : nil))
        let wire = Wire()
        let root = try composition(gates: true, wire: wire)
        let transport = root.transport()
        transport.current = { self.viewer() }
        let reader = try XCTUnwrap(RoamShareSnapshotReaderFactory.make(baseURL: URL(string: Self.base), transport: transport,
            approval: root.isRoamShareSnapshotApproved ? { root.isRoamShareSnapshotApproved } : nil))
        _ = await reader.snapshot(try XCTUnwrap(RoamShareToken(Self.hex)))
        XCTAssertEqual(wire.requests.compactMap { $0.url?.path }, ["/api/roam/share/snapshot"])
    }
}

/// Item 4: city-node voucher issue (`api/verify/citynode/issue`, form field `poiId`). Ticket issue, redeem and receipt stay off.
@MainActor
final class ReviewedCityVoucherIssueWiringTests: ReviewedHookWiring2Base {
    private func exactRequests() throws -> [(String, URLRequest)] {
        let configuration = try APIConfiguration(baseURL: try XCTUnwrap(URL(string: Self.base)))
        return [("issue", try RoamExperienceMutation.issueVoucher(poiID: 12).request(configuration: configuration, token: Self.token))]
    }
    private func neighbours() throws -> [(String, URLRequest)] {
        let url = try XCTUnwrap(URL(string: Self.base)), evil = try XCTUnwrap(URL(string: "https://evil.example.org"))
        func form(_ base: URL, _ path: String, _ fields: [String: String]) throws -> URLRequest {
            try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent(path), fields: fields, token: Self.token)
        }
        return [
            ("zero-id", try form(url, "api/verify/citynode/issue", ["poiId": "0"])),
            ("leading-zero", try form(url, "api/verify/citynode/issue", ["poiId": "012"])),
            ("extra-field", try form(url, "api/verify/citynode/issue", ["poiId": "12", "code": "x"])),
            ("wrong-field", try form(url, "api/verify/citynode/issue", ["id": "12"])),
            ("json-body", request("POST", Self.base + "/api/verify/citynode/issue", body: #"{"poiId":12}"#)),
            ("redeem", try form(url, "api/verify/citynode/redeem", ["code": "x"])),
            ("receipt", try form(url, "api/verify/citynode/receipt", ["code": "x"])),
            ("dyncode", try form(url, "api/verify/dyncode/issue", ["registrationId": "12"])),
            ("groupcode", try form(url, "api/verify/groupcode/issue", ["teamId": "12"])),
            ("foreign", try RoamExperienceMutation.issueVoucher(poiID: 12).request(configuration: try APIConfiguration(baseURL: evil), token: Self.token))
        ]
    }

    func testUnconfiguredCompositionIssuesNoLeaseAndRefusesTheRoute() async throws {
        let wire = Wire()
        let root = try unconfigured(wire: wire)
        XCTAssertNil(root.verificationCodeApproval(try context(root)))
        let transport = root.transport()
        transport.current = { self.viewer() }
        let sent = await sentPaths(transport, try exactRequests() + neighbours(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "\(sent)")
    }

    func testReviewedWithoutProductionGatesIssuesNoLeaseAndRefusesTheRoute() async throws {
        let wire = Wire()
        let root = try composition(gates: false, wire: wire)
        XCTAssertNil(root.verificationCodeApproval(try context(root)))
        let transport = root.transport()
        transport.current = { self.viewer() }
        let sent = await sentPaths(transport, try exactRequests(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "\(sent)")
    }

    func testLeaseCoversOnlyTheCityVoucherKindForPlayerClubMerchantInChina() throws {
        let root = try composition(gates: true, wire: Wire())
        for role in ["player", "club", "merchant"] {
            let ctx = try context(root, role: role)
            let approval = try XCTUnwrap(root.verificationCodeApproval(ctx), role)
            XCTAssertTrue(approval.allows(.cityVoucher, context: ctx))
            XCTAssertFalse(approval.allows(.ticket, context: ctx))
            XCTAssertEqual(approval.endpoints.paths, ["api/verify/citynode/issue"])
        }
        XCTAssertNil(root.verificationCodeApproval(try context(root, role: "guest")))
        XCTAssertNil(root.verificationCodeApproval(try context(root, market: .unitedStates)))
    }

    func testReviewedChinaCompositionAllowsExactlyTheIssueRoute() async throws {
        let wire = Wire()
        let root = try composition(gates: true, wire: wire)
        let transport = root.transport()
        transport.current = { self.viewer() }
        let allowed = await sentPaths(transport, try exactRequests(), wire: wire)
        for (name, sent) in allowed { XCTAssertTrue(sent, "must admit \(name)") }
        let refused = await sentPaths(transport, try neighbours(), wire: wire)
        for (name, sent) in refused { XCTAssertFalse(sent, "must refuse \(name)") }
        XCTAssertEqual(wire.requests.count, 1)
        let out = Wire()
        let outTransport = try composition(gates: true, wire: out).transport()
        outTransport.current = { CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil, viewerRevision: 1) }
        let outSent = await sentPaths(outTransport, try exactRequests(), wire: out)
        XCTAssertFalse(outSent.values.contains(true), "\(outSent)")
    }

    func testVerificationServiceIssuesOnlyThroughTheLease() async throws {
        let wire = Wire()
        let root = try composition(gates: true, wire: wire)
        let transport = root.transport()
        transport.current = { self.viewer() }
        let ctx = try context(root)
        let configuration = try APIConfiguration(baseURL: try XCTUnwrap(URL(string: Self.base)))
        let service = VerificationCodeHTTPService(configuration: configuration, approval: root.verificationCodeApproval(ctx),
            kind: .cityVoucher, transport: transport, current: { ctx })
        XCTAssertTrue(service.enabled)
        _ = try? await service.issue(VerificationCodeTarget(kind: .cityVoucher, id: 12), context: ctx)
        XCTAssertEqual(wire.requests.compactMap { $0.url?.path }, ["/api/verify/citynode/issue"])
        let ticket = VerificationCodeHTTPService(configuration: configuration, approval: root.verificationCodeApproval(ctx),
            kind: .ticket, transport: transport, current: { ctx })
        XCTAssertFalse(ticket.enabled)
        let off = VerificationCodeHTTPService(configuration: configuration, approval: try unconfigured(wire: Wire()).verificationCodeApproval(ctx),
            kind: .cityVoucher, transport: transport, current: { ctx })
        XCTAssertFalse(off.enabled)
    }
}

/// Item 5: team apply / withdraw / handle writes. Evidence contract (AppSession): the review's team, applicant and
/// application are re-read through the reviewed nearby read routes and must equal what was reviewed.
@MainActor
final class ReviewedNearbyTeamWriteWiringTests: ReviewedHookWiring2Base {
    private func built(_ action: NearbyTeamAction, token: String = ReviewedHookWiring2Base.token) throws -> URLRequest {
        let descriptor = try NearbyTeamRequest.action(action)
        return try OperationAdapterHTTP.json(configuration: try APIConfiguration(baseURL: try XCTUnwrap(URL(string: Self.base))),
            path: String(descriptor.path.dropFirst()), body: try XCTUnwrap(descriptor.body), token: token)
    }
    private func exactRequests() throws -> [(String, URLRequest)] {
        [("apply", try built(.apply(NearbyTeamID(5)))), ("withdraw", try built(.withdraw(NearbyTeamID(5)))),
         ("handle-approve", try built(.handle(team: NearbyTeamID(5), applicant: NearbyApplicantID(2), approved: true))),
         ("handle-reject", try built(.handle(team: NearbyTeamID(5), applicant: NearbyApplicantID(2), approved: false)))]
    }
    private func neighbours() throws -> [(String, URLRequest)] {
        let b = Self.base
        let evil = "https://evil.example.org"
        return [
            ("kick", request("POST", b + "/api/team/kick", body: #"{"teamId":5}"#)),
            ("quit", request("POST", b + "/api/team/quit", body: #"{"teamId":5}"#)),
            ("disband", request("POST", b + "/api/team/disband", body: #"{"teamId":5}"#)),
            ("join", request("POST", b + "/api/team/join", body: #"{"teamId":5}"#)),
            ("apply-extra-key", request("POST", b + "/api/team/apply", body: #"{"memberId":1,"teamId":5}"#)),
            ("apply-zero", request("POST", b + "/api/team/apply", body: #"{"teamId":0}"#)),
            ("apply-string-id", request("POST", b + "/api/team/apply", body: #"{"teamId":"5"}"#)),
            ("apply-query", request("POST", b + "/api/team/apply?x=1", body: #"{"teamId":5}"#)),
            ("apply-unsorted", request("POST", b + "/api/team/apply", body: #"{ "teamId": 5 }"#)),
            ("apply-get", request("GET", b + "/api/team/apply")),
            ("apply-form", request("POST", b + "/api/team/apply", body: "teamId=5", contentType: "application/x-www-form-urlencoded")),
            ("handle-missing-approved", request("POST", b + "/api/team/handle", body: #"{"memberId":2,"teamId":5}"#)),
            ("handle-int-approved", request("POST", b + "/api/team/handle", body: #"{"approved":1,"memberId":2,"teamId":5}"#)),
            ("handle-zero-member", request("POST", b + "/api/team/handle", body: #"{"approved":true,"memberId":0,"teamId":5}"#)),
            ("handle-extra-key", request("POST", b + "/api/team/handle", body: #"{"approved":true,"memberId":2,"note":"x","teamId":5}"#)),
            ("withdraw-member", request("POST", b + "/api/team/withdraw", body: #"{"memberId":2,"teamId":5}"#)),
            ("foreign-apply", request("POST", evil + "/api/team/apply", body: #"{"teamId":5}"#)),
            ("foreign-handle", request("POST", evil + "/api/team/handle", body: #"{"approved":true,"memberId":2,"teamId":5}"#))
        ]
    }

    func testUnconfiguredCompositionIssuesNoLeaseAndRefusesEveryRoute() async throws {
        let wire = Wire()
        let root = try unconfigured(wire: wire)
        XCTAssertNil(root.nearbyTeamWriteApproval(try context(root)))
        let transport = root.transport()
        transport.current = { self.viewer() }
        let sent = await sentPaths(transport, try exactRequests() + neighbours(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "\(sent)")
    }

    func testReviewedWithoutProductionGatesIssuesNoLeaseAndRefusesTheWrites() async throws {
        let wire = Wire()
        let root = try composition(gates: false, wire: wire)
        XCTAssertNil(root.nearbyTeamWriteApproval(try context(root)))
        let transport = root.transport()
        transport.current = { self.viewer() }
        let sent = await sentPaths(transport, try exactRequests(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "\(sent)")
    }

    func testLeaseCoversExactlyThreePathsForPlayerClubMerchantInChina() throws {
        let root = try composition(gates: true, wire: Wire())
        for role in ["player", "club", "merchant"] {
            let lease = try XCTUnwrap(root.nearbyTeamWriteApproval(try context(root, role: role)), role)
            XCTAssertEqual(lease.paths, ["api/team/apply", "api/team/withdraw", "api/team/handle"])
        }
        XCTAssertNil(root.nearbyTeamWriteApproval(try context(root, role: "guest")))
        XCTAssertNil(root.nearbyTeamWriteApproval(try context(root, market: .unitedStates)))
    }

    func testReviewedChinaCompositionAllowsExactlyTheWritesAndRefusesNeighbours() async throws {
        let wire = Wire()
        let transport = try composition(gates: true, wire: wire).transport()
        transport.current = { self.viewer() }
        let allowed = await sentPaths(transport, try exactRequests(), wire: wire)
        for (name, sent) in allowed { XCTAssertTrue(sent, "must admit \(name)") }
        let refused = await sentPaths(transport, try neighbours(), wire: wire)
        for (name, sent) in refused { XCTAssertFalse(sent, "must refuse \(name)") }
        XCTAssertEqual(wire.requests.count, allowed.count)
        let out = Wire()
        let outTransport = try composition(gates: true, wire: out).transport()
        outTransport.current = { CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil, viewerRevision: 1) }
        let outSent = await sentPaths(outTransport, try exactRequests(), wire: out)
        XCTAssertFalse(outSent.values.contains(true), "\(outSent)")
    }
}

/// Item 3: merchant decor / cooperation / NPC / perk-template saves plus the four baseline reads a save needs.
/// Profile, business-status and the second (profile) leg of a story save are not leased.
@MainActor
final class ReviewedMerchantOperationsWiringTests: ReviewedHookWiring2Base {
    private var configuration: APIConfiguration { get throws { try APIConfiguration(baseURL: try XCTUnwrap(URL(string: Self.base))) } }
    private func json(_ path: String, _ body: String) throws -> URLRequest {
        try OperationAdapterHTTP.json(configuration: try configuration, path: path, body: Data(body.utf8), token: Self.token)
    }
    private func jsonRead(_ path: String) throws -> URLRequest {
        var r = try AuthRequestBuilder.makeFormRequest(url: try XCTUnwrap(URL(string: Self.base)).appendingPathComponent(path), fields: [:], token: Self.token, includesBody: false)
        r.httpBody = Data("{}".utf8); r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return r
    }
    private func form(_ path: String, _ fields: [String: String]) throws -> URLRequest {
        try AuthRequestBuilder.makeFormRequest(url: try XCTUnwrap(URL(string: Self.base)).appendingPathComponent(path), fields: fields, token: Self.token)
    }
    private func previews() throws -> [(String, URLRequest)] {
        let all: [MerchantOperationsRequestPreview] = [
            try .init(path: "api/merchant/decor/save", fields: ["slogan": "hi", "cityRole": "x", "storyTitle": "t", "gallery": "a,b", "tags": "", "coverImage": NSNull(), "featuredType": NSNull(), "featuredId": NSNull(), "serviceTag": NSNull(), "serviceText": NSNull(), "locationLat": NSNull(), "locationLng": NSNull(), "locationVerified": NSNull(), "categoryIds": "1,2"]),
            try .init(path: "api/merchant/decor/save", fields: ["locationLat": 31.2, "locationLng": 121.4, "address": "x"]),
            try .init(path: "api/merchant/coop-profile/save", fields: ["availableTime": "a", "demand": "d", "capacity": 3, "chargeType": 1, "suitActivityTypes": "1,2", "coopOpen": true]),
            try .init(path: "api/merchant/coop-profile/save", fields: ["availableTime": "a", "demand": "d", "capacity": NSNull(), "params": ["clearCapacity": true]]),
            try .init(path: "api/merchant/npc/save", fields: ["name": "n", "avatar": "", "greeting": "g", "persona": "", "knowledge": ""]),
            try .init(path: "api/merchant/city-node/template/submit", fields: ["id": 4, "title": "t", "validationMethod": 1, "duration": 30, "hint1": "h", "storyJson": "[]", "categoryId": 2, "activityCategoryids": "2", "questionA": "a"])
        ]
        return try all.enumerated().map { ("save-\($0.offset)-" + $0.element.path, try json($0.element.path, String(data: $0.element.json, encoding: .utf8)!)) }
    }
    private func exactRequests() throws -> [(String, URLRequest)] {
        try previews() + [
            ("coop-read", try jsonRead("api/merchant/coop-profile")), ("npc-read", try jsonRead("api/merchant/npc/profile")),
            ("info-read", try form("api/merchant/info", [:])), ("myinfo-read", try form("api/template/myinfo", ["id": "9"]))
        ]
    }
    private func neighbours() throws -> [(String, URLRequest)] {
        let evil = try XCTUnwrap(URL(string: "https://evil.example.org"))
        return [
            ("profile-save", try json("api/merchant/update", #"{"name":"n"}"#)),
            ("business-status", try json("api/merchant/business-status/update", #"{"business_status":"1"}"#)),
            ("decor-extra-key", try json("api/merchant/decor/save", #"{"slogan":"x","role":"admin"}"#)),
            ("decor-empty", try json("api/merchant/decor/save", "{}")),
            ("decor-array", try json("api/merchant/decor/save", #"{"gallery":["a"]}"#)),
            ("coop-missing-required", try json("api/merchant/coop-profile/save", #"{"availableTime":"a"}"#)),
            ("coop-bad-params", try json("api/merchant/coop-profile/save", #"{"availableTime":"a","demand":"d","params":{"x":1}}"#)),
            ("npc-partial", try json("api/merchant/npc/save", #"{"name":"n"}"#)),
            ("npc-number", try json("api/merchant/npc/save", #"{"name":"n","avatar":1,"greeting":"g","persona":"","knowledge":""}"#)),
            ("template-no-title", try json("api/merchant/city-node/template/submit", #"{"id":4}"#)),
            ("template-extra", try json("api/merchant/city-node/template/submit", #"{"title":"t","merchantId":1}"#)),
            ("template-delete", try json("api/merchant/city-node/template/delete", #"{"id":4}"#)),
            ("form-body-save", try form("api/merchant/decor/save", ["slogan": "x"])),
            ("coop-read-no-body", try AuthRequestBuilder.makeFormRequest(url: try XCTUnwrap(URL(string: Self.base)).appendingPathComponent("api/merchant/coop-profile"), fields: [:], token: Self.token, includesBody: false)),
            ("info-with-field", try form("api/merchant/info", ["id": "1"])),
            ("myinfo-no-id", try form("api/template/myinfo", [:])),
            ("myinfo-zero", try form("api/template/myinfo", ["id": "0"])),
            ("get-read", request("GET", Self.base + "/api/merchant/npc/profile", contentType: nil)),
            ("foreign-save", try OperationAdapterHTTP.json(configuration: try APIConfiguration(baseURL: evil), path: "api/merchant/npc/save", body: Data(#"{"name":"n","avatar":"","greeting":"g","persona":"","knowledge":""}"#.utf8), token: Self.token)),
            ("foreign-read", try AuthRequestBuilder.makeFormRequest(url: evil.appendingPathComponent("api/merchant/info"), fields: [:], token: Self.token))
        ]
    }

    func testUnconfiguredCompositionIssuesNoLeaseAndRefusesEveryRoute() async throws {
        let wire = Wire()
        let root = try unconfigured(wire: wire)
        XCTAssertNil(root.merchantOperationsWriteApproval(try context(root, role: "merchant")))
        let transport = root.transport()
        transport.current = { self.viewer(role: "merchant") }
        let sent = await sentPaths(transport, try exactRequests() + neighbours(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "\(sent)")
    }

    func testReviewedWithoutProductionGatesIssuesNoLeaseAndRefusesEveryRoute() async throws {
        let wire = Wire()
        let root = try composition(gates: false, wire: wire)
        XCTAssertNil(root.merchantOperationsWriteApproval(try context(root, role: "merchant")))
        let transport = root.transport()
        transport.current = { self.viewer(role: "merchant") }
        let sent = await sentPaths(transport, try exactRequests(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "\(sent)")
    }

    func testLeaseCoversExactlyTheFourSavesForMerchantsInChina() throws {
        let root = try composition(gates: true, wire: Wire())
        let lease = try XCTUnwrap(root.merchantOperationsWriteApproval(try context(root, role: "merchant")))
        XCTAssertEqual(lease.paths, ["api/merchant/decor/save", "api/merchant/coop-profile/save", "api/merchant/npc/save", "api/merchant/city-node/template/submit"])
        for role in ["player", "club", "guest"] { XCTAssertNil(root.merchantOperationsWriteApproval(try context(root, role: role)), role) }
        XCTAssertNil(root.merchantOperationsWriteApproval(try context(root, role: "merchant", market: .unitedStates)))
    }

    func testReviewedChinaCompositionAllowsExactlyTheReadsAndSavesForMerchantsOnly() async throws {
        let wire = Wire()
        let transport = try composition(gates: true, wire: wire).transport()
        transport.current = { self.viewer(role: "merchant") }
        let allowed = await sentPaths(transport, try exactRequests(), wire: wire)
        for (name, sent) in allowed { XCTAssertTrue(sent, "must admit \(name)") }
        let refused = await sentPaths(transport, try neighbours(), wire: wire)
        for (name, sent) in refused { XCTAssertFalse(sent, "must refuse \(name)") }
        XCTAssertEqual(wire.requests.count, allowed.count)
        for role in ["player", "club"] {
            let w = Wire()
            let t = try composition(gates: true, wire: w).transport()
            t.current = { self.viewer(role: role) }
            let sent = await sentPaths(t, try exactRequests(), wire: w)
            XCTAssertFalse(sent.values.contains(true), "\(role): \(sent)")
        }
        let out = Wire()
        let outTransport = try composition(gates: true, wire: out).transport()
        outTransport.current = { CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil, viewerRevision: 1) }
        let outSent = await sentPaths(outTransport, try exactRequests(), wire: out)
        XCTAssertFalse(outSent.values.contains(true), "\(outSent)")
    }
}
