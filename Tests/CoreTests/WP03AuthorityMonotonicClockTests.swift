import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class WP03UptimeClock: WalkingMonotonicClock {
    var uptime: TimeInterval
    init(_ uptime: TimeInterval = 5_000) { self.uptime = uptime }
}

/// Shared deterministic fakes for the WP-03 suites. No network, no real clock.
@MainActor final class WP03Rig {
    let reference: WalkingTargetReference
    var wall = Date(timeIntervalSince1970: 1_800_000_000)
    let uptime = WP03UptimeClock()
    var current = true
    let targets: WP03Targets
    let location: WP03Location
    let planner: WP03Planner
    let lifetime: TimeInterval
    lazy var model = WalkingNavigationCoordinator(reference: reference, ownerNamespace: "wp03-owner",
        authorizer: targets, location: location, planner: planner, current: { [weak self] in self?.current == true },
        now: { [unowned self] in self.wall }, monotonicClock: uptime)
    init(lifetime: TimeInterval = 120, straightLine: Bool = false) throws {
        self.lifetime = lifetime
        reference = try .init(kind: .cityNode, id: 7)
        let coordinate = try WalkingCoordinate(point: RoamCoordinate(latitude: 1.001, longitude: 1.002)!, datum: .wgs84, region: "US")
        let target = try AuthorizedWalkingTarget(reference: reference, title: "Allowed current stop", coordinate: coordinate,
            authorityRevision: "r1", expiresAt: wall.addingTimeInterval(lifetime), monotonicDeadline: uptime.uptime + lifetime)
        targets = WP03Targets(target)
        location = WP03Location(try .init(coordinate: .init(latitude: 1, longitude: 1)!, accuracyMeters: 5, measuredAt: wall, datum: .wgs84))
        planner = WP03Planner(now: wall); planner.straightLine = straightLine
    }
    /// A fresh fix in the (possibly jumped) wall-clock frame.
    func refreshFix() throws {
        location.fix = try .init(coordinate: .init(latitude: 1, longitude: 1)!, accuracyMeters: 5, measuredAt: wall, datum: .wgs84)
    }
}
@MainActor final class WP03Targets: WalkingTargetAuthorizing {
    var value: AuthorizedWalkingTarget; var calls = 0
    init(_ value: AuthorizedWalkingTarget) { self.value = value }
    func authorize(_ reference: WalkingTargetReference) async throws -> AuthorizedWalkingTarget { calls += 1; return value }
}
@MainActor final class WP03Location: WalkingLocationProviding {
    var authorization: WalkingLocationAuthorization = .authorized
    var fix: RoamDeviceFix; var calls = 0
    init(_ fix: RoamDeviceFix) { self.fix = fix }
    func currentFix() async throws -> RoamDeviceFix { calls += 1; return fix }
    func stop() {}
}
@MainActor final class WP03Planner: SearchRoutePlanning {
    var now: Date; var straightLine = false; var requests: [SearchRouteRequest] = []
    var calls: Int { requests.count }
    init(now: Date) { self.now = now }
    func preview(_ request: SearchRouteRequest) async throws -> SearchRoutePreview {
        requests.append(request)
        if straightLine { return .straightLine(request) }
        let end = request.destination
        return try .init(coordinates: [request.origin, .init(latitude: request.origin.latitude, longitude: end.longitude)!, end],
            distanceMeters: 300, etaSeconds: 240,
            steps: [.init(instruction: "Walk east", distanceMeters: 200), .init(instruction: "Walk north", distanceMeters: 100)],
            isStraightLine: false, datum: .wgs84, provider: .init(identifier: "synthetic.walking", attribution: "Synthetic", fetchedAt: now))
    }
    func cancel() {}
}

@MainActor final class WP03AuthorityMonotonicClockTests: XCTestCase {
    func testWallClockRewindDoesNotExtendExpiredAuthority() async throws {
        let rig = try WP03Rig(); await rig.model.start()
        XCTAssertEqual(rig.model.phase, .navigating)
        rig.uptime.uptime += 121                       // real elapsed time passes the lease
        rig.wall = rig.wall.addingTimeInterval(-3_600) // user rewinds the system clock
        try rig.refreshFix()
        await rig.model.update()
        XCTAssertEqual(rig.model.phase, .failed(.targetUnavailable))
        XCTAssertNil(rig.model.cameraSnapshot)
    }
    func testWallClockForwardJumpDoesNotExpireValidAuthority() async throws {
        let rig = try WP03Rig(); await rig.model.start()
        rig.uptime.uptime += 10                        // lease still has 110 s
        rig.wall = rig.wall.addingTimeInterval(7_200)  // user jumps the system clock forward
        try rig.refreshFix()
        await rig.model.update()
        XCTAssertEqual(rig.model.phase, .navigating)
        XCTAssertNotNil(rig.model.cameraSnapshot)
    }
    func testExpiryUsesInjectedMonotonicClock() async throws {
        let rig = try WP03Rig(); await rig.model.start()
        XCTAssertNotNil(rig.model.cameraSnapshot)
        rig.uptime.uptime += 119.9
        XCTAssertNotNil(rig.model.cameraSnapshot)
        rig.uptime.uptime += 0.2                       // wall clock never moved
        XCTAssertNil(rig.model.cameraSnapshot)
        await rig.model.update()
        XCTAssertEqual(rig.model.phase, .failed(.targetUnavailable))
    }
    func testReaderDerivesDeadlineFromInjectedUptimeNotWallClock() async throws {
        struct Wire: HTTPTransport {
            let data: Data
            func send(_ request: URLRequest) async throws -> (Data, Int) { (data, 200) }
        }
        let wall = Date(timeIntervalSince1970: 1_800_000_000), ms = Int64(wall.timeIntervalSince1970 * 1000)
        let body = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "kind": "cityNode", "id": 7, "title": "t",
            "longitude": 120.0, "latitude": 30.0, "datum": "wgs84", "region": "CN", "authorityRevision": "city:7:r",
            "issuedAtMs": ms, "expiresAtMs": ms + 120_000] as [String: Any])
        let session = try PlayExperienceSession(accountID: 17, epoch: 3, namespace: "fixture", token: "not-live")
        let uptime = WP03UptimeClock(9_000)
        let reader = CityWalkingAuthorityReader(owner: .init(market: .china, baseURL: URL(string: "https://example.test/native")!, role: "player", session: session),
            transport: Wire(data: body), current: { true }, now: { wall }, monotonicClock: uptime)
        let value = try await reader.authorize(.init(kind: .cityNode, id: 7))
        XCTAssertEqual(value.monotonicDeadline, 9_120)
    }
}
