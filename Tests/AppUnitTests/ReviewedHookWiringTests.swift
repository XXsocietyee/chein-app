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

/// GM-HOOK: the read-only gap-wave hooks (passport history, team `my`/`info`, nearby-team reads) are leased only by a
/// reviewed China composition with production gates; `.unconfigured` / gates-off / foreign hosts / neighbours stay refused.
@MainActor
final class ReviewedHookWiringTests: XCTestCase {
    private static let base = "https://api.example.com"
    private static let token = "synthetic-7"

    private final class Vault: AppTokenStorage {
        var value: String?
        func read() throws -> String? { value }
        func write(_ token: String) throws { value = token }
        func clear() throws { value = nil }
    }
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
        }
    }

    private let viewer = CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: 7, role: "player", token: "synthetic-7", viewerRevision: 1)

    private func composition(gates: Bool, wire: Wire) throws -> AppCompositionRoot {
        let suite = "hook-wiring-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let build = RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: Self.base,
            bundleIdentifier: "com.questify.ios", realm: "hook-" + UUID().uuidString.lowercased())
        let deployment = try ReviewedAppDeployment(market: .china, baseURL: Self.base, approvedBaseURLs: [.china: [Self.base]],
            verifiedCapabilities: [.domesticChinaPhone], bundleIdentifier: "com.questify.ios", realm: build.realm!,
            reads: [], productionGatesEnabled: gates)
        let vault = Vault()
        return RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in vault }), makeTransport: { wire })
    }
    private func unconfigured(wire: Wire) throws -> AppCompositionRoot {
        let suite = "hook-unconf-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let vault = Vault()
        return RegionalLaunchConfiguration.makeComposition(reviewed: nil,
            build: .init(market: "CN", baseURL: Self.base, bundleIdentifier: "com.questify.ios", realm: "hook-unconf"),
            storage: .init(defaults: defaults, tokenStore: { _ in vault }), makeTransport: { wire })
    }

    private func context(_ composition: AppCompositionRoot, role: String = "player", market: RegionalMarket = .china) throws -> RuntimeDependencyContext {
        let namespace = composition.reviewed?.storageScope.service ?? "hook-unconf"
        return RuntimeDependencyContext(market: market, baseURL: try XCTUnwrap(URL(string: Self.base)), role: role,
            session: try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: Self.token))
    }

    private func request(_ method: String, _ url: String, body: String? = nil, json: Bool = true) -> URLRequest {
        var r = URLRequest(url: URL(string: url)!)
        r.httpMethod = method
        r.httpBody = body.map { Data($0.utf8) }
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if json { r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        r.setValue(Self.token, forHTTPHeaderField: "Authorization")
        return r
    }

    /// Every request shape the three new hooks may legitimately emit, built by the Core types where they exist.
    private func exactRequests() throws -> [(String, URLRequest)] {
        let url = try XCTUnwrap(URL(string: Self.base))
        let b = Self.base
        return [
            ("history", try RoamPassportHistoryReadRoute.history(before: nil).request(baseURL: url, token: Self.token)),
            ("history-before", try RoamPassportHistoryReadRoute.history(before: "123").request(baseURL: url, token: Self.token)),
            ("record", try RoamPassportHistoryReadRoute.record(sessionID: "123").request(baseURL: url, token: Self.token)),
            ("summary", try RoamPassportHistoryReadRoute.summary.request(baseURL: url, token: Self.token)),
            ("team-my", request("POST", b + "/api/team/my", body: "{}")),
            ("team-info", request("POST", b + "/api/team/info", body: #"{"teamId":5}"#)),
            ("nearby", request("GET", b + "/api/team/nearby?lat=31.2&lng=121.4&radius=3000")),
            ("applications", request("POST", b + "/api/team/applications", body: #"{"teamId":5}"#)),
            ("my-applications", request("POST", b + "/api/team/my-applications"))
        ]
    }

    /// Neighbours, extra keys, bad ids, foreign hosts and the unreviewed team writes.
    private func neighbours() throws -> [(String, URLRequest)] {
        let b = Self.base
        let evil = "https://evil.example.org"
        let url = try XCTUnwrap(URL(string: evil))
        return [
            ("kick", request("POST", b + "/api/team/kick", body: #"{"teamId":5}"#)),
            ("nearby-extra-query", request("GET", b + "/api/team/nearby?lat=31.2&lng=121.4&radius=3000&x=1")),
            ("nearby-bad-radius", request("GET", b + "/api/team/nearby?lat=31.2&lng=121.4&radius=999")),
            ("nearby-swapped", request("GET", b + "/api/team/nearby?lng=121.4&lat=31.2&radius=3000")),
            ("nearby-post", request("POST", b + "/api/team/nearby", body: "{}")),
            ("applications-extra-key", request("POST", b + "/api/team/applications", body: #"{"memberId":1,"teamId":5}"#)),
            ("applications-zero", request("POST", b + "/api/team/applications", body: #"{"teamId":0}"#)),
            ("my-applications-body", request("POST", b + "/api/team/my-applications", body: "{}")),
            ("my-applications-query", request("POST", b + "/api/team/my-applications?x=1")),
            ("record-bad-id", request("GET", b + "/api/roam/passport/record?sessionId=0123")),
            ("history-extra", request("GET", b + "/api/roam/passport/history?limit=30&x=1")),
            ("passport-post", request("POST", b + "/api/roam/passport/summary", body: "{}")),
            ("foreign-history", try RoamPassportHistoryReadRoute.summary.request(baseURL: url, token: Self.token)),
            ("foreign-nearby", request("GET", evil + "/api/team/nearby?lat=31.2&lng=121.4&radius=3000")),
            ("foreign-applications", request("POST", evil + "/api/team/applications", body: #"{"teamId":5}"#)),
            ("foreign-my", request("POST", evil + "/api/team/my", body: "{}"))
        ]
    }

    /// Exact team-write requests. GM-HOOK2 wired these behind the production gates (see ReviewedNearbyTeamWriteWiringTests);
    /// they must stay refused wherever the gates are off or the composition is unconfigured.
    private func teamWrites() -> [(String, URLRequest)] {
        let b = Self.base
        return [
            ("apply", request("POST", b + "/api/team/apply", body: #"{"teamId":5}"#)),
            ("withdraw", request("POST", b + "/api/team/withdraw", body: #"{"teamId":5}"#)),
            ("handle", request("POST", b + "/api/team/handle", body: #"{"approved":true,"memberId":2,"teamId":5}"#))
        ]
    }

    private func sentPaths(_ transport: CompositionHTTPTransport, _ requests: [(String, URLRequest)], wire: Wire) async -> [String: Bool] {
        var out: [String: Bool] = [:]
        for (name, request) in requests {
            let before = wire.requests.count
            _ = try? await transport.send(request)
            out[name] = wire.requests.count > before
        }
        return out
    }

    func testUnconfiguredCompositionIssuesNoLeaseAndRefusesEveryRoute() async throws {
        let wire = Wire()
        let root = try unconfigured(wire: wire)
        let ctx = try context(root)
        XCTAssertNil(root.roamPassportHistoryReadAccess(ctx))
        XCTAssertNil(root.roamEntryNearbyReadAccess(ctx))
        XCTAssertNil(root.roamNearbyPlayersReadAccess(ctx))
        XCTAssertNil(root.teamReadApproval(ctx))
        XCTAssertNil(root.nearbyTeamReadApproval(ctx))
        let transport = root.transport()
        transport.current = { self.viewer }
        let sent = await sentPaths(transport, try exactRequests() + neighbours() + teamWrites(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "unconfigured composition must not send anything: \(sent)")
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testReviewedWithoutProductionGatesIssuesNoLeaseAndRefusesTheNewRoutes() async throws {
        let wire = Wire()
        let root = try composition(gates: false, wire: wire)
        let ctx = try context(root)
        XCTAssertNil(root.roamPassportHistoryReadAccess(ctx))
        XCTAssertNil(root.roamEntryNearbyReadAccess(ctx))
        XCTAssertNil(root.roamNearbyPlayersReadAccess(ctx))
        XCTAssertNil(root.teamReadApproval(ctx))
        XCTAssertNil(root.nearbyTeamReadApproval(ctx))
        let transport = root.transport()
        transport.current = { self.viewer }
        let sent = await sentPaths(transport, try exactRequests() + teamWrites(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "gates-off composition must refuse every new route: \(sent)")
    }

    func testReviewedChinaCompositionLeasesOnlyForPlayerClubMerchantInChina() throws {
        let root = try composition(gates: true, wire: Wire())
        for role in ["player", "club", "merchant"] {
            let ctx = try context(root, role: role)
            XCTAssertNotNil(root.roamPassportHistoryReadAccess(ctx), role)
            XCTAssertNotNil(root.roamEntryNearbyReadAccess(ctx), role)
            XCTAssertNotNil(root.roamNearbyPlayersReadAccess(ctx), role)
            XCTAssertNotNil(root.teamReadApproval(ctx), role)
            XCTAssertNotNil(root.nearbyTeamReadApproval(ctx), role)
        }
        let guest = try context(root, role: "guest")
        XCTAssertNil(root.roamPassportHistoryReadAccess(guest))
        XCTAssertNil(root.roamEntryNearbyReadAccess(guest))
        XCTAssertNil(root.roamNearbyPlayersReadAccess(guest))
        XCTAssertNil(root.teamReadApproval(guest))
        XCTAssertNil(root.nearbyTeamReadApproval(guest))
        let us = try context(root, market: .unitedStates)
        XCTAssertNil(root.roamPassportHistoryReadAccess(us))
        XCTAssertNil(root.roamEntryNearbyReadAccess(us))
        XCTAssertNil(root.roamNearbyPlayersReadAccess(us))
        XCTAssertNil(root.teamReadApproval(us))
        XCTAssertNil(root.nearbyTeamReadApproval(us))
        let lease = try XCTUnwrap(root.nearbyTeamReadApproval(try context(root)))
        XCTAssertEqual(lease.paths, ["api/team/nearby", "api/team/applications", "api/team/my-applications"])
        XCTAssertEqual(try XCTUnwrap(root.roamPassportHistoryReadAccess(try context(root))).endpoints.paths, RoamPassportHistoryReadRoute.paths)
    }

    func testReviewedChinaCompositionAllowsExactlyTheNewRoutesAndRefusesNeighbours() async throws {
        let wire = Wire()
        let root = try composition(gates: true, wire: wire)
        let transport = root.transport()
        transport.current = { self.viewer }
        let allowed = await sentPaths(transport, try exactRequests(), wire: wire)
        for (name, sent) in allowed { XCTAssertTrue(sent, "reviewed composition must admit \(name)") }
        let refused = await sentPaths(transport, try neighbours(), wire: wire)
        for (name, sent) in refused { XCTAssertFalse(sent, "reviewed composition must refuse \(name)") }
        XCTAssertEqual(wire.requests.count, allowed.count)
    }

    func testSignedOutViewerIsRefusedOnTheNewRoutes() async throws {
        let wire = Wire()
        let transport = try composition(gates: true, wire: wire).transport()
        transport.current = { CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil, viewerRevision: 1) }
        let sent = await sentPaths(transport, try exactRequests(), wire: wire)
        XCTAssertFalse(sent.values.contains(true), "\(sent)")
    }

    func testNearbyTeamReadTransportBuildsOnlyRequestsTheRouteAdmits() async throws {
        let wire = Wire()
        let root = try composition(gates: true, wire: wire)
        let transport = root.transport()
        transport.current = { self.viewer }
        let ctx = try context(root)
        let approval = try XCTUnwrap(root.nearbyTeamReadApproval(ctx))
        let session = NearbyTeamSession(accountID: 7, epoch: 1, region: "CN", namespace: ctx.session.namespace, role: "player")
        let reader = NearbyTeamHTTPReadTransport(configuration: try APIConfiguration(baseURL: try XCTUnwrap(URL(string: Self.base))),
            transport: transport, approval: approval, currentSession: { session }, token: { _ in Self.token })
        _ = try await reader.sendRead(try .nearby(.init(latitude: 31.2304, longitude: 121.4737, radius: 5000)), session: session)
        _ = try await reader.sendRead(try .applications(NearbyTeamID(9)), session: session)
        _ = try await reader.sendRead(.myApplications(), session: session)
        XCTAssertEqual(wire.requests.compactMap { $0.url?.path }, ["/api/team/nearby", "/api/team/applications", "/api/team/my-applications"])
        do {
            _ = try await reader.sendRead(try .action(.apply(NearbyTeamID(9))), session: session)
            XCTFail("the read transport must never carry a mutation")
        } catch {}
        XCTAssertEqual(wire.requests.count, 3)
    }

    func testProductionGatesLeaseEntryPeekAndRunnersAndAdmitGuestEntry() async throws {
        let centre = RoamSearchArea(coordinate: RoamCoordinate(latitude: 30, longitude: 120)!, label: "Selected area")
        let url = try XCTUnwrap(URL(string: Self.base))
        let signedEntry = try RoamEntryNearbyRoute.request(baseURL: url, area: centre, token: Self.token)
        let publicEntry = try RoamEntryNearbyRoute.publicRequest(baseURL: url, area: centre)
        let runners = try AuthRequestBuilder.makeFormRequest(url: url.appendingPathComponent(RoamNearbyPlayersReadRoute.path),
            fields: ["lat": String(centre.coordinate.latitude), "lng": String(centre.coordinate.longitude), "radius": "3000"],
            token: Self.token, boundary: "synthetic")
        let selection = ManualMapAreaSelection(); selection.select(centre)
        let guest = CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil, viewerRevision: 1)
        let off = Wire()
        let offRoot = try composition(gates: false, wire: off)
        XCTAssertNil(offRoot.roamEntryNearbyReadAccess(try context(offRoot)))
        XCTAssertNil(offRoot.roamNearbyPlayersReadAccess(try context(offRoot)))
        let offTransport = offRoot.transport().scopedForManualMap(selection)
        offTransport.current = { self.viewer }
        _ = try? await offTransport.send(signedEntry)
        offTransport.current = { guest }
        _ = try? await offTransport.send(publicEntry)
        XCTAssertTrue(off.requests.isEmpty)
        let wire = Wire()
        let root = try composition(gates: true, wire: wire)
        let player = try context(root)
        XCTAssertEqual(try XCTUnwrap(root.roamEntryNearbyReadAccess(player)).endpoints.paths, [RoamEntryNearbyRoute.path])
        XCTAssertEqual(try XCTUnwrap(root.roamNearbyPlayersReadAccess(player)).endpoints.paths, [RoamNearbyPlayersReadRoute.path])
        let transport = root.transport().scopedForManualMap(selection)
        transport.current = { self.viewer }
        _ = try await transport.send(signedEntry)
        _ = try await transport.send(runners)
        transport.current = { guest }
        _ = try await transport.send(publicEntry)
        var authedGuest = publicEntry
        authedGuest.setValue(Self.token, forHTTPHeaderField: "Authorization")
        do { _ = try await transport.send(authedGuest); XCTFail("guest entry must not carry Authorization") } catch {}
        do { _ = try await transport.send(runners); XCTFail("nearby runners stay signed in") } catch {}
        XCTAssertEqual(wire.requests.count, 3)
        XCTAssertNil(wire.requests[2].value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(wire.requests[2].url, publicEntry.url)
    }
}
