#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class ObjectBadgeWallPageStateTests: XCTestCase {
    private func identities(_ json: String) throws -> [ProfileIdentityBadge] {
        try JSONDecoder().decode([ProfileIdentityBadge].self, from: Data(json.utf8))
    }
    private func medals(_ json: String) throws -> [ProfileMedal] {
        try JSONDecoder().decode([ProfileMedal].self, from: Data(json.utf8))
    }

    func testEmptyWallIsKnownZero() {
        let state = ObjectBadgeWallPageState.project(ProfileBadgeWall(identities: [], medals: []))
        guard case .empty(let counts) = state else { return XCTFail("\(state)") }
        XCTAssertEqual([counts.unlocked, counts.total, counts.waiting], ["0", "0", "0"])
        XCTAssertEqual(counts.accessibilityIdentifier, "badgeWall.count.known")
        XCTAssertEqual(state.accessibilityIdentifier, "badgeWall.state.empty")
        XCTAssertEqual(state.titleKey, "badgeWall.state.empty")
        XCTAssertNotEqual(counts.total, ObjectBadgeWallPageCounts.unknownMark)
    }

    func testMissingMedalCollectionIsUnknownEvenWithoutIdentityCards() throws {
        let bare = ObjectBadgeWallPageState.project(ProfileBadgeWall(identities: [], medals: nil))
        guard case .unknown(let counts, let rows) = bare else { return XCTFail("\(bare)") }
        XCTAssertEqual(counts, .unknown)
        XCTAssertEqual(counts.unlocked, "—")
        XCTAssertEqual(counts.total, "—")
        XCTAssertEqual(counts.waiting, "—")
        XCTAssertNotEqual(counts.total, "0")
        XCTAssertTrue(rows.isEmpty)
        XCTAssertEqual(bare.accessibilityIdentifier, "badgeWall.state.unknown")
        XCTAssertEqual(bare.titleKey, "badgeWall.state.unknown")
        XCTAssertEqual(bare.detailKey, "badgeWall.state.unknownDetail")
        XCTAssertEqual(counts.accessibilityIdentifier, "badgeWall.count.unknown")

        let partial = ObjectBadgeWallPageState.project(ProfileBadgeWall(
            identities: try identities(#"[{"badgeCode":"A","unlocked":false},{"badgeCode":"B","unlocked":true}]"#),
            medals: nil))
        XCTAssertEqual(partial.orderedIdentityCodes, ["B", "A"])
        XCTAssertEqual(partial.counts, .unknown)
        XCTAssertNotEqual(partial.counts.total, "2")
        XCTAssertNotEqual(partial.counts.unlocked, "1")
    }

    func testReadyWallKeepsLitOrderAndLiteralZeroWaiting() throws {
        let wall = ProfileBadgeWall(
            identities: try identities(#"[{"badgeCode":"A","unlocked":true}]"#),
            medals: try medals(#"[{"medalName":"City","kind":"city"}]"#))
        let state = ObjectBadgeWallPageState.project(wall)
        guard case .ready(let counts, let rows, let medals) = state else { return XCTFail("\(state)") }
        XCTAssertEqual([counts.unlocked, counts.total, counts.waiting], ["2", "2", "0"])
        XCTAssertEqual(counts.waiting, "0")
        XCTAssertNotEqual(counts.waiting, "—")
        XCTAssertEqual(rows.map(\.badgeCode), ["A"])
        XCTAssertEqual(medals.map(\.medalName), ["City"])
        XCTAssertEqual(state.titleKey, "profile.badges.title")
        XCTAssertEqual(state.accessibilityIdentifier, "badgeWall.state.ready")
        XCTAssertEqual(ObjectBadgeWallSummary(wall: wall).total, 2)
    }

    func testLoadingHiddenAndErrorDoNotShowZero() {
        for state in [ObjectBadgeWallPageState.loading, .hidden, .error(.unavailable)] {
            XCTAssertEqual(state.counts, .unknown)
            XCTAssertNotEqual(state.counts.total, "0")
        }
        XCTAssertNil(ObjectBadgeWallPageState.hidden.titleKey)
        XCTAssertEqual(ObjectBadgeWallPageState.hidden.accessibilityIdentifier, "badgeWall.state.hidden")
        XCTAssertEqual(ObjectBadgeWallPageState.loading.titleKey, "badgeWall.state.loading")
        XCTAssertEqual(ObjectBadgeWallPageState.loading.accessibilityIdentifier, "badgeWall.state.loading")
        XCTAssertNil(ObjectBadgeWallPageCounts.known(unlocked: -1, total: 0, waiting: 0))
        XCTAssertNil(ObjectBadgeWallPageCounts.known(unlocked: 2, total: 1, waiting: 0))
    }

    func testFailureKindsStayDistinctFromEmpty() {
        XCTAssertEqual(ObjectBadgeWallPageFailure.classify(ProfileReadFailure(httpStatus: 401, code: 401)), .unauthorized)
        XCTAssertEqual(ObjectBadgeWallPageFailure.classify(APIError.unauthorized), .unauthorized)
        XCTAssertEqual(ObjectBadgeWallPageFailure.classify(ProfileReadFailure(httpStatus: 403, code: 403)), .denied)
        XCTAssertEqual(ObjectBadgeWallPageFailure.classify(APIError.httpStatus(403)), .denied)
        XCTAssertEqual(ObjectBadgeWallPageFailure.classify(APIError.businessCode(403)), .denied)
        XCTAssertEqual(ObjectBadgeWallPageFailure.classify(APIError.malformedResponse), .malformed)
        XCTAssertEqual(ObjectBadgeWallPageFailure.classify(ProfileReadFailure(code: 500, message: "Identity unavailable")), .unavailable)
        XCTAssertEqual(ObjectBadgeWallPageFailure.classify(URLError(.timedOut)), .unavailable)
        XCTAssertEqual(ObjectBadgeWallPageFailure.unauthorized.titleKey, "badgeWall.state.signIn")
        XCTAssertNil(ObjectBadgeWallPageFailure.unauthorized.retryKey)
        XCTAssertEqual(ObjectBadgeWallPageFailure.denied.titleKey, "badgeWall.state.denied")
        XCTAssertEqual(ObjectBadgeWallPageFailure.malformed.titleKey, "badgeWall.state.malformed")
        XCTAssertEqual(ObjectBadgeWallPageFailure.unavailable.titleKey, "badgeWall.state.error")
        XCTAssertEqual(ObjectBadgeWallPageFailure.denied.retryKey, "badgeWall.state.retry")
        let denied = ObjectBadgeWallPageState.error(.denied)
        XCTAssertEqual(denied.accessibilityIdentifier, "badgeWall.state.error")
        XCTAssertNotEqual(denied.counts.total, "0")
    }

    @MainActor func testSignedOutAndUnconfiguredStayHiddenWithoutReading() async {
        let reader = ObjectBadgeWallPageProbe(isConfigured: false)
        let model = ObjectBadgeWallPageCoordinator()
        await model.load(reader: reader)
        XCTAssertEqual(model.state, .hidden)
        XCTAssertEqual(reader.reads, 0)
        reader.isConfigured = true
        reader.identity = nil
        await model.load(reader: reader)
        XCTAssertEqual(model.state, .hidden)
        XCTAssertEqual(reader.reads, 0)
    }

    @MainActor func testConfiguredEmptyReadIsEmptyAndAFailedReadIsNot() async throws {
        let reader = ObjectBadgeWallPageProbe()
        let model = ObjectBadgeWallPageCoordinator()
        await model.load(reader: reader)
        let zeros = try XCTUnwrap(ObjectBadgeWallPageCounts.known(unlocked: 0, total: 0, waiting: 0))
        XCTAssertEqual(model.state, .empty(zeros))
        XCTAssertEqual(reader.reads, 1)

        reader.result = .failure(ProfileReadFailure(code: 500, message: "Identity unavailable"))
        await model.load(reader: reader)
        XCTAssertEqual(model.state, .error(.unavailable))
        XCTAssertEqual(model.state.counts.total, "—")

        reader.result = .failure(APIError.malformedResponse)
        await model.load(reader: reader)
        XCTAssertEqual(model.state, .error(.malformed))

        reader.result = .failure(APIError.httpStatus(403))
        await model.load(reader: reader)
        XCTAssertEqual(model.state, .error(.denied))

        reader.result = .failure(APIError.unauthorized)
        await model.load(reader: reader)
        XCTAssertEqual(model.state, .error(.unauthorized))
        XCTAssertEqual(model.state.titleKey, "badgeWall.state.signIn")
    }

    @MainActor func testNotConfiguredResultStaysHidden() async {
        let reader = ObjectBadgeWallPageProbe(result: .failure(APIError.notConfigured))
        let model = ObjectBadgeWallPageCoordinator()
        await model.load(reader: reader)
        XCTAssertEqual(model.state, .hidden)
        XCTAssertEqual(reader.reads, 1)
        XCTAssertNotEqual(model.state.counts.total, "0")
    }

    @MainActor func testCancellationDoesNotBecomeErrorOrZero() async {
        let reader = ObjectBadgeWallPageProbe(result: .failure(CancellationError()))
        let model = ObjectBadgeWallPageCoordinator()
        await model.load(reader: reader)
        XCTAssertEqual(model.state, .loading)
        XCTAssertEqual(model.state.counts.total, "—")
        XCTAssertNotEqual(model.state.counts.total, "0")
        if case .error = model.state { XCTFail("cancellation is not an error") }
        if case .empty = model.state { XCTFail("cancellation is not an empty wall") }
    }

    @MainActor func testAccountChangeDropsTheLateWall() async {
        let reader = ObjectBadgeWallPageProbe(result: .success(ProfileBadgeWall(identities: [], medals: [])))
        reader.onRead = { reader.identity = ProfileReadIdentity(accountID: 8, epoch: 2) }
        let model = ObjectBadgeWallPageCoordinator()
        await model.load(reader: reader)
        XCTAssertEqual(model.state, .hidden)
        XCTAssertNotEqual(model.state.accessibilityIdentifier, "badgeWall.state.empty")
    }

    @MainActor func testOlderReadCannotReplaceANewerLoad() async throws {
        let reader = ObjectBadgeWallPageGate()
        let model = ObjectBadgeWallPageCoordinator()
        let first = Task { await model.load(reader: reader) }
        await reader.waitUntilReads(1)
        guard reader.reads == 1 else { return }
        let second = Task { await model.load(reader: reader) }
        await reader.waitUntilReads(2)
        guard reader.reads == 2 else { return }
        reader.resume(ProfileBadgeWall(identities: [], medals: []))
        await first.value
        XCTAssertEqual(model.state, .loading)
        let wall = ProfileBadgeWall(
            identities: try identities(#"[{"badgeCode":"B","unlocked":true},{"badgeCode":"A","unlocked":false}]"#),
            medals: try medals(#"[{"medalName":"City","kind":"city"}]"#))
        reader.resume(wall)
        await second.value
        guard case .ready(let counts, let rows, _) = model.state else { return XCTFail("\(model.state)") }
        XCTAssertEqual([counts.unlocked, counts.total, counts.waiting], ["2", "3", "1"])
        XCTAssertEqual(rows.map(\.badgeCode), ["B", "A"])
    }

    #if DEBUG
    func testFixtureDataProjectsReadyEmptyAndUnknown() throws {
        let ready = ObjectBadgeWallPageState.project(try ObjectBadgeWallFixtureData.readyWall())
        guard case .ready(let counts, let rows, let medals) = ready else { return XCTFail("\(ready)") }
        XCTAssertEqual(rows.map(\.badgeCode), ["FIXTURE-LIT", "FIXTURE-LOCKED"])
        XCTAssertEqual(medals.count, 2)
        XCTAssertEqual([counts.unlocked, counts.total, counts.waiting], ["3", "4", "1"])
        let empty = ObjectBadgeWallPageState.project(ObjectBadgeWallFixtureData.emptyWall())
        guard case .empty(let zeros) = empty else { return XCTFail("\(empty)") }
        XCTAssertEqual([zeros.unlocked, zeros.total, zeros.waiting], ["0", "0", "0"])
        let unknown = ObjectBadgeWallPageState.project(try ObjectBadgeWallFixtureData.unknownWall())
        guard case .unknown(let marks, let kept) = unknown else { return XCTFail("\(unknown)") }
        XCTAssertEqual(marks, .unknown)
        XCTAssertEqual(kept.map(\.badgeCode), ["FIXTURE-LIT", "FIXTURE-LOCKED"])
        XCTAssertNotEqual(marks.total, "0")
        XCTAssertNotEqual(marks.total, "2")
    }
    #endif
}

@MainActor private final class ObjectBadgeWallPageProbe: ProfileReading {
    var isConfigured: Bool
    var identity: ProfileReadIdentity?
    var result: Result<ProfileBadgeWall, Error>
    var onRead: (@MainActor () -> Void)?
    private(set) var reads = 0
    init(isConfigured: Bool = true, identity: ProfileReadIdentity? = ProfileReadIdentity(accountID: 7, epoch: 1),
         result: Result<ProfileBadgeWall, Error> = .success(ProfileBadgeWall(identities: [], medals: []))) {
        self.isConfigured = isConfigured
        self.identity = identity
        self.result = result
    }
    func profileBadges() async throws -> ProfileBadgeWall {
        reads += 1
        onRead?()
        try Task.checkCancellation()
        return try result.get()
    }
    func profileOrders() async throws -> [ProfileOrder] { throw APIError.notConfigured }
    func profileOrder(id: Int) async throws -> ProfileOrder { throw APIError.notConfigured }
    func profileParticipants() async throws -> [ProfileParticipant] { throw APIError.notConfigured }
    func profileParticipant(id: Int) async throws -> ProfileParticipant { throw APIError.notConfigured }
}

@MainActor private final class ObjectBadgeWallPageGate: ProfileReading {
    var isConfigured = true
    var identity: ProfileReadIdentity? = ProfileReadIdentity(accountID: 7, epoch: 1)
    private var waiters: [CheckedContinuation<ProfileBadgeWall, Error>] = []
    private(set) var reads = 0
    func profileBadges() async throws -> ProfileBadgeWall {
        reads += 1
        return try await withCheckedThrowingContinuation { waiters.append($0) }
    }
    func resume(_ wall: ProfileBadgeWall) { waiters.removeFirst().resume(returning: wall) }
    func waitUntilReads(_ count: Int) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while reads < count, ContinuousClock.now < deadline { await Task.yield() }
    }
    func profileOrders() async throws -> [ProfileOrder] { throw APIError.notConfigured }
    func profileOrder(id: Int) async throws -> ProfileOrder { throw APIError.notConfigured }
    func profileParticipants() async throws -> [ProfileParticipant] { throw APIError.notConfigured }
    func profileParticipant(id: Int) async throws -> ProfileParticipant { throw APIError.notConfigured }
}
#endif
