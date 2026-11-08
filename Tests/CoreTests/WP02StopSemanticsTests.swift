import XCTest
@testable import QuestifyCore

/// Examples only. These values are NOT production policy or approved defaults.
enum WP02Fixture {
    static let now: Int64 = 1_800_000_000_000
    static let digest = String(repeating: "b", count: 64)
    static func uuid(_ n: Int) -> String { String(format: "00000000-0000-4000-8000-%012d", n) }
    static func scope(_ account: Int64 = 1) throws -> PersonalLocationShareScope {
        try .init(namespace: "synthetic.invalid/wp02-test-only", accountId: account, epoch: 1)
    }
    static func policy() -> PersonalLocationSharePolicy {
        .init(policyId: "TEST_ONLY", version: 1, digest: digest, approvalRef: "TEST_NOT_APPROVAL", foregroundOnly: true,
            requiresRecipientAcceptance: false,
            modeChoices: [.init(id: "test-exact", mode: .exact, datum: "WGS84", latitudeStep: nil, longitudeStep: nil)],
            durationChoices: [.init(id: "test-duration", seconds: 120)],
            refreshAfterMs: 20_000, staleAfterMs: 30_000, displayLeaseMs: 40_000, ownerLeaseMs: 60_000)
    }
    static func request(key: String, recipient: Int64 = 2) -> PersonalLocationShareCreate {
        .init(requestKey: key, recipientId: recipient, policyId: "TEST_ONLY", policyVersion: 1, policyDigest: digest,
            modeChoiceId: "test-exact", durationChoiceId: "test-duration", foregroundOnly: true,
            acknowledgedDisclosures: PersonalLocationShareDisclosure.allCases)
    }
    static func grant(key: String, grantId: String, owner: Int64 = 1, recipient: Int64 = 2) -> PersonalLocationShareGrant {
        .init(grantId: grantId, requestKey: key, ownerId: owner, recipientId: recipient, policyId: "TEST_ONLY",
            policyVersion: 1, policyDigest: digest, modeChoiceId: "test-exact", mode: .exact,
            durationChoiceId: "test-duration", createdAtMs: now, expiresAtMs: now + 120_000,
            ownerLeaseUntilMs: now + 60_000, version: 1, watermark: 1, status: .active, reason: nil)
    }
    static func active(_ request: PersonalLocationShareCreate) -> PersonalLocationShareReceipt {
        .init(requestKey: request.requestKey, known: true, state: .active, requestHash: "opaque-server-test-hash",
            grant: grant(key: request.requestKey, grantId: uuid(900)), serverNowMs: now, watermark: 1)
    }
}
@MainActor final class WP02Journal: PersonalLocationShareJournaling {
    var values: [PersonalLocationSharePendingRecord] = []
    func records(scope: PersonalLocationShareScope) throws -> [PersonalLocationSharePendingRecord] { values.filter { $0.accountId == scope.accountId } }
    func put(_ record: PersonalLocationSharePendingRecord, scope: PersonalLocationShareScope) throws {
        try record.validate(scope: scope); values.removeAll { $0.id == record.id }; values.append(record)
    }
    func remove(requestKey: String, scope: PersonalLocationShareScope) throws { values.removeAll { $0.id == requestKey } }
}
@MainActor final class WP02Provider: PersonalLocationShareCoordinateProviding, PersonalLocationShareCoordinateFactory {
    let isSynthetic = true
    var makes = 0, samples = 0, stops = 0
    func canCreate(scope: PersonalLocationShareScope) -> Bool { true }
    func confirmationPurpose(scope: PersonalLocationShareScope) -> PersonalLocationShareCaptureApproval? {
        try? .init(scope: scope, approvalReference: "TEST_NOT_APPROVAL", usageDescription: "TEST ONLY personal sharing")
    }
    func make(binding: PersonalLocationShareCaptureBinding, isCurrent: @escaping () -> Bool) throws -> any PersonalLocationShareCoordinateProviding {
        guard isCurrent() else { throw PersonalLocationShareFailure.staleSession }
        makes += 1; return self
    }
    func sample() async throws -> PersonalLocationShareSample {
        samples += 1
        return .init(observedAtMs: WP02Fixture.now, datum: "WGS84", latitude: 0, longitude: 0, sourceId: "synthetic-test-only", systemAccuracy: .full)
    }
    func stop() { stops += 1 }
}
@MainActor final class WP02Service: PersonalLocationShareServicing {
    let scope: PersonalLocationShareScope
    let isSynthetic = true
    var createCalls = 0, publishCalls = 0
    var revokedKeys: [String] = []
    var ownedValues: [PersonalLocationShareGrant] = []
    init(scope: PersonalLocationShareScope) { self.scope = scope }
    func context(recipientId: Int64) async throws -> PersonalLocationShareContext {
        .init(ownerId: scope.accountId, recipientId: recipientId, eligible: true, unavailableReason: nil, policy: WP02Fixture.policy())
    }
    func create(_ request: PersonalLocationShareCreate) async throws -> PersonalLocationShareReceipt { createCalls += 1; return WP02Fixture.active(request) }
    func requestStatus(requestKey: String) async throws -> PersonalLocationShareReceipt {
        .init(requestKey: requestKey, known: false, state: .notFound, requestHash: nil, grant: nil, serverNowMs: WP02Fixture.now, watermark: 0)
    }
    func revoke(requestKey: String) async throws -> PersonalLocationShareReceipt {
        revokedKeys.append(requestKey)
        return .init(requestKey: requestKey, known: true, state: .stopped, requestHash: nil, grant: nil, serverNowMs: WP02Fixture.now, watermark: 2)
    }
    func owned() async throws -> PersonalLocationShareOwned { .init(ownerId: scope.accountId, serverNowMs: WP02Fixture.now, grants: ownedValues) }
    func received() async throws -> PersonalLocationShareSnapshot {
        .init(recipientId: scope.accountId, serverNowMs: WP02Fixture.now, cursor: 1, displayLeaseUntilMs: WP02Fixture.now + 40_000,
            refreshAfterMs: 20_000, staleAfterMs: 30_000, policyId: "TEST_ONLY", policyVersion: 1, policyDigest: WP02Fixture.digest, entries: [])
    }
    func events(cursor: Int64) async throws -> PersonalLocationShareEventBatch {
        .init(recipientId: scope.accountId, serverNowMs: WP02Fixture.now, cursor: cursor, resetRequired: false, refreshAfterMs: 20_000, events: [])
    }
    func publish(grantId: String, observation: PersonalLocationSharePublish, synthetic: Bool) async throws -> PersonalLocationSharePublished {
        publishCalls += 1
        return .init(grantId: grantId, sequence: observation.sequence, version: 2, watermark: 2, observedAtMs: observation.observedAtMs, ownerLeaseUntilMs: WP02Fixture.now + 60_000)
    }
}
@MainActor struct WP02Rig {
    let service: WP02Service, journal: WP02Journal, provider: WP02Provider, coordinator: PersonalLocationShareCoordinator
    init() throws {
        let scope = try WP02Fixture.scope()
        service = WP02Service(scope: scope); journal = WP02Journal(); provider = WP02Provider()
        coordinator = PersonalLocationShareCoordinator(scope: scope, service: service, journal: journal,
            providerFactory: provider, current: { scope }, uptime: { 100 })
    }
    func prepareAndAcknowledge() async {
        await coordinator.prepare(recipientId: 2)
        coordinator.chooseMode("test-exact"); coordinator.chooseDuration("test-duration")
        for item in PersonalLocationShareDisclosure.allCases { coordinator.acknowledge(item, accepted: true) }
    }
    /// Full explicit start: prepare, choose, acknowledge, final confirmation.
    @discardableResult func startSharing() async -> String? {
        await prepareAndAcknowledge()
        guard let ticket = coordinator.makeConfirmationTicket(displayedRecipientId: 2, presentationId: UUID(), allowsFirstPermissionRequest: false) else { return nil }
        await coordinator.confirmStart(ticket: ticket).value
        return coordinator.publishingRequestKey
    }
    func waitForRevokes(_ count: Int) async { for _ in 0..<200 where service.revokedKeys.count < count { await Task.yield() } }
}

@MainActor final class WP02StopSemanticsTests: XCTestCase {
    func testBackgroundTransitionStopsShare() async throws {
        let rig = try WP02Rig(); let key = await rig.startSharing()
        XCTAssertNotNil(key)
        await rig.coordinator.stop(for: .background)
        XCTAssertNil(rig.coordinator.publishingRequestKey)
        XCTAssertGreaterThanOrEqual(rig.provider.stops, 1)
        XCTAssertTrue(rig.coordinator.visibleLocations.isEmpty)
        XCTAssertFalse(rig.coordinator.canConfirm)
        XCTAssertFalse(rig.coordinator.foreground)
        await rig.waitForRevokes(1)
        XCTAssertEqual(rig.service.revokedKeys, [try XCTUnwrap(key)])
    }
    func testOfflineStopsShare() async throws {
        let rig = try WP02Rig(); let key = try XCTUnwrap(await rig.startSharing())
        await rig.coordinator.stop(for: .offline)
        XCTAssertNil(rig.coordinator.publishingRequestKey)
        XCTAssertGreaterThanOrEqual(rig.provider.stops, 1)
        XCTAssertFalse(rig.coordinator.connected)
        // No network path: the stop intent is durable and no revoke is faked.
        XCTAssertEqual(rig.journal.values.first(where: { $0.id == key })?.stopRequested, true)
        XCTAssertTrue(rig.service.revokedKeys.isEmpty)
        // Coming back online never silently restarts collection.
        rig.coordinator.resume(foreground: true, connected: true)
        XCTAssertNil(rig.coordinator.publishingRequestKey)
        XCTAssertEqual(rig.provider.makes, 1)
    }
    func testTeamExitStopsShare() async throws {
        let rig = try WP02Rig(); let key = try XCTUnwrap(await rig.startSharing())
        await rig.coordinator.stop(for: .teamExit)
        XCTAssertNil(rig.coordinator.publishingRequestKey)
        XCTAssertGreaterThanOrEqual(rig.provider.stops, 1)
        XCTAssertEqual(rig.service.revokedKeys, [key])
        XCTAssertEqual(rig.coordinator.requests[key], .stopped)
        XCTAssertTrue(rig.coordinator.visibleLocations.isEmpty)
        XCTAssertTrue(rig.journal.values.isEmpty)
    }
    func testBanStopsShare() async throws {
        let rig = try WP02Rig(); let key = try XCTUnwrap(await rig.startSharing())
        await rig.coordinator.stop(for: .ban)
        XCTAssertNil(rig.coordinator.publishingRequestKey)
        XCTAssertGreaterThanOrEqual(rig.provider.stops, 1)
        XCTAssertTrue(rig.coordinator.authorizationBlocked)
        XCTAssertFalse(rig.coordinator.canConfirm)
        XCTAssertTrue(rig.coordinator.visibleLocations.isEmpty)
        XCTAssertEqual(rig.journal.values.first(where: { $0.id == key })?.stopRequested, true)
        // A banned session cannot be revived by prepare/resume.
        await rig.coordinator.prepare(recipientId: 2)
        rig.coordinator.resume(foreground: true, connected: true)
        XCTAssertNil(rig.coordinator.publishingRequestKey)
        XCTAssertEqual(rig.provider.makes, 1)
    }
    func testStopAllClearsEveryRequestKey() async throws {
        let rig = try WP02Rig()
        let journaled = WP02Fixture.uuid(11), ownedKey = WP02Fixture.uuid(12)
        rig.journal.values = [try .init(scope: rig.service.scope, request: WP02Fixture.request(key: journaled))]
        rig.service.ownedValues = [WP02Fixture.grant(key: ownedKey, grantId: WP02Fixture.uuid(21))]
        await rig.coordinator.prepare(recipientId: 2)
        await rig.coordinator.openManagement()
        XCTAssertEqual(Set(rig.coordinator.pending.map(\.id)), [journaled])
        XCTAssertEqual(rig.coordinator.ownedGrants.map(\.requestKey), [ownedKey])
        await rig.coordinator.stopAll()
        XCTAssertEqual(Set(rig.service.revokedKeys), [journaled, ownedKey])
        XCTAssertEqual(rig.coordinator.requests[journaled], .stopped)
        XCTAssertEqual(rig.coordinator.requests[ownedKey], .stopped)
        XCTAssertTrue(rig.coordinator.pending.isEmpty)
        XCTAssertTrue(rig.journal.values.isEmpty)
        XCTAssertNil(rig.coordinator.publishingRequestKey)
    }
}
