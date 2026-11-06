import Foundation
import XCTest
@testable import QuestifyCore

@available(macOS 14.0, *)
@MainActor final class ModInstallationEncryptedRecoveryBridgeTests: XCTestCase {
    private let realm = "https://example.test/mod-bridge/"
    private let start = "/mod-bridge/api/play/advanced/start"
    private let action = "/mod-bridge/api/play/advanced/action"
    private let read = "/mod-bridge/api/play/advanced/state"

    private final class Memory: TemplateAuthoringStorage {
        var values: [String: Data] = [:]
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ value: Data, key: String) throws { values[key] = value }
        func remove(_ key: String) throws { XCTFail("The original MOD evidence must remain retained") }
    }
    @MainActor private final class Recovery: PlayAdvancedRecovery {
        let base: PlayMemoryAdvancedRecovery
        let processID: UUID
        var failAcknowledgement = false
        var acknowledgementAttempts = 0
        var clears = 0
        init(base: PlayMemoryAdvancedRecovery? = nil, processID: UUID? = nil) {
            let original = base ?? PlayMemoryAdvancedRecovery()
            self.base = original; self.processID = processID ?? original.processID
        }
        func read() async throws -> PlayAdvancedRecoverySnapshot? { try await base.read() }
        func prepare(_ record: PlayAdvancedRecoveryRecord) async throws -> PlayAdvancedRecoverySnapshot { try await base.prepare(record) }
        func transition(_ snapshot: PlayAdvancedRecoverySnapshot, to phase: PlayAdvancedRecoveryRecord.Phase, startedSessionID: Int?) async throws -> PlayAdvancedRecoverySnapshot {
            if phase == .acknowledged {
                acknowledgementAttempts += 1
                if failAcknowledgement { throw PlayExperienceError.persistenceUnavailable }
            }
            return try await base.transition(snapshot, to: phase, startedSessionID: startedSessionID)
        }
        func clear(_ snapshot: PlayAdvancedRecoverySnapshot) async throws { try await base.clear(snapshot); clears += 1 }
    }
    private func owner() throws -> PlayExperienceSession {
        try .init(accountID: 9001, epoch: 1, namespace: "synthetic-mod-bridge", token: "synthetic", role: "player")
    }
    private func raw(_ version: Int) -> String {
        """
        {"sessionId":501,"activityId":0,"topicId":71,"nodeId":701,"ownerType":1,"status":"RUNNING","version":\(version),"config":{"qa":{"enabled":true}},"playKit":{"qa":{"mode":"PICK","multi":false,"finished":false,"passed":false,"options":[{"id":"b","label":"B"}]}},"modInstallationRuntime":{"schema":"mod-installation-native-runtime-v1","status":"SUPPORTED","kind":"QA_PICK","sourceHash":"\(String(repeating: "a", count: 64))","runHash":"\(String(repeating: "b", count: 64))","sessionId":501,"activityId":0,"topicId":71,"nodeId":701}}
        """
    }
    private func configure(_ wire: PlayRecoveryRecordingTransport) {
        wire.responses[start] = .reply(PlayExperienceSyntheticFixtures.envelope(raw(1)), 200)
        wire.responses[action] = .reply(PlayExperienceSyntheticFixtures.envelope(raw(2)), 200)
        wire.responses[read] = .reply(PlayExperienceSyntheticFixtures.envelope(raw(4)), 200)
    }
    private func coordinator(_ wire: PlayRecoveryRecordingTransport, memory: Memory, owner: PlayExperienceSession,
                             recovery: (any PlayAdvancedRecovery)? = nil) throws -> PlayAdvancedCoordinator {
        .init(activityID: 0, topicID: 71, nodeID: 701,
            service: .init(configuration: try .init(baseURL: XCTUnwrap(URL(string: realm))), transport: wire, enabled: [.reads, .advanced]),
            modJournal: .init(storage: memory), recovery: recovery, currentSession: { owner })
    }
    private func record(_ memory: Memory, owner: PlayExperienceSession) throws -> ModInstallationNativeRuntimeRecord {
        try XCTUnwrap(ModInstallationNativeRuntimeJournal(storage: memory).load(owner: owner, realm: realm, activity: 0, topic: 71, node: 701))
    }
    private func submit(_ model: PlayAdvancedCoordinator) async {
        await model.submit(kind: "qa", action: "SUBMIT_QA", detail: ["optionId": .string("b")])
    }

    func testBothJournalsPreserveOriginalReceiptSeparatelyFromNewerState() async throws {
        let wire = PlayRecoveryRecordingTransport(), memory = Memory(), owner = try owner(), recovery = Recovery()
        configure(wire)
        let model = try coordinator(wire, memory: memory, owner: owner, recovery: recovery)
        await model.start(); await submit(model)
        XCTAssertEqual(model.modInstallationActionReceipt?.version, 2)
        XCTAssertEqual(model.state?.version, 4)
        XCTAssertTrue(model.canInteract); XCTAssertNil(model.pending)
        XCTAssertEqual(wire.requests.filter { $0.url?.path == action }.count, 1)
        let retained = try record(memory, owner: owner), encrypted = try await recovery.read()
        XCTAssertTrue(retained.settled); XCTAssertEqual(retained.receipt?["version"].integer, 2)
        XCTAssertNil(encrypted)
    }

    func testModAcknowledgementDoesNotPromoteEncryptedUnknownOrReplay() async throws {
        let wire = PlayRecoveryRecordingTransport(), memory = Memory(), owner = try owner(), recovery = Recovery()
        configure(wire)
        let model = try coordinator(wire, memory: memory, owner: owner, recovery: recovery)
        await model.start(); recovery.failAcknowledgement = true; await submit(model)
        let original = try record(memory, owner: owner), attempts = recovery.acknowledgementAttempts, clears = recovery.clears
        XCTAssertNotNil(original.receipt); XCTAssertFalse(original.settled)
        recovery.failAcknowledgement = false
        await model.recover(); await model.retryExact()
        let encrypted = try await recovery.read()
        XCTAssertEqual(encrypted?.value.phase, .unknown)
        XCTAssertEqual(model.pending?.key, original.command.key); XCTAssertEqual(model.phase, "unknown")
        XCTAssertEqual(model.modInstallationActionReceipt?.version, 2); XCTAssertFalse(model.canInteract)
        XCTAssertEqual(recovery.acknowledgementAttempts, attempts); XCTAssertEqual(recovery.clears, clears)
        XCTAssertEqual(wire.requests.filter { $0.url?.path == action }.count, 1)
        XCTAssertEqual(wire.requests.filter { $0.url?.path == read }.count, 1)
        XCTAssertFalse(try record(memory, owner: owner).settled)
    }

    func testMissingEncryptedCompanionCannotInventMigrationOrNewStart() async throws {
        let originalWire = PlayRecoveryRecordingTransport(), memory = Memory(), owner = try owner()
        configure(originalWire); originalWire.responses[action] = .failure(.unknownResult)
        let original = try coordinator(originalWire, memory: memory, owner: owner)
        await original.start(); await submit(original)
        let retained = try record(memory, owner: owner)
        let freshWire = PlayRecoveryRecordingTransport(), recovery = Recovery()
        configure(freshWire)
        let fresh = try coordinator(freshWire, memory: memory, owner: owner, recovery: recovery)
        await fresh.start(); await fresh.recover(); await fresh.retryExact()
        XCTAssertTrue(freshWire.requests.isEmpty); XCTAssertEqual(fresh.phase, "unknown")
        XCTAssertEqual(fresh.pending?.key, retained.command.key); XCTAssertFalse(fresh.canInteract)
        let encrypted = try await recovery.read()
        XCTAssertNil(encrypted); XCTAssertEqual(try record(memory, owner: owner).command, retained.command)
    }

    func testCanonicallyEquivalentPayloadsCannotJoinDifferentOriginalCommands() async throws {
        let originalWire = PlayRecoveryRecordingTransport(), memory = Memory(), owner = try owner()
        configure(originalWire)
        let composed = "\u{00e9}", decomposed = "e\u{0301}"
        originalWire.responses[start] = .reply(PlayExperienceSyntheticFixtures.envelope(raw(1).replacingOccurrences(of: "\"id\":\"b\"", with: "\"id\":\"\(composed)\"")), 200)
        originalWire.responses[action] = .failure(.unknownResult)
        let original = try coordinator(originalWire, memory: memory, owner: owner)
        await original.start()
        await original.submit(kind: "qa", action: "SUBMIT_QA", detail: ["optionId": .string(composed)])
        let retained = try record(memory, owner: owner), recovery = Recovery()
        let changed = PlayAdvancedPending(sessionID: retained.command.sessionID, version: retained.command.version,
            key: retained.command.key, action: retained.command.action, payload: ["optionId": .string(decomposed)])
        XCTAssertNotEqual(try PlayAdvancedFrozenAction.requestBytes(retained.command), try PlayAdvancedFrozenAction.requestBytes(changed))
        _ = try await recovery.prepare(PlayAdvancedRecoveryRecord(session: owner,
            scope: .init(activityID: 0, topicID: 71, nodeID: 701), pending: changed, requestedCard: false))
        let wire = PlayRecoveryRecordingTransport(); configure(wire)
        let fresh = try coordinator(wire, memory: memory, owner: owner, recovery: recovery)
        await fresh.start(); await fresh.retryExact()
        XCTAssertTrue(wire.requests.isEmpty); XCTAssertEqual(fresh.phase, "unknown")
        XCTAssertEqual(try PlayAdvancedFrozenAction.requestBytes(record(memory, owner: owner).command),
                       try PlayAdvancedFrozenAction.requestBytes(retained.command))
        let encrypted = try await recovery.read()
        XCTAssertEqual(encrypted?.value.phase, .prepared)
    }

    func testOlderCurrentReadCannotSettleAValidOriginalModReceipt() async throws {
        let wire = PlayRecoveryRecordingTransport(), memory = Memory(), owner = try owner()
        configure(wire); wire.responses[read] = .reply(PlayExperienceSyntheticFixtures.envelope(raw(1)), 200)
        let model = try coordinator(wire, memory: memory, owner: owner)
        await model.start(); await submit(model)
        XCTAssertEqual(model.modInstallationActionReceipt?.version, 2)
        XCTAssertNotNil(model.pending); XCTAssertFalse(model.canInteract)
        XCTAssertFalse(try record(memory, owner: owner).settled)
        wire.responses[read] = .reply(PlayExperienceSyntheticFixtures.envelope(raw(4)), 200)
        await model.recover()
        XCTAssertNil(model.pending); XCTAssertEqual(model.state?.version, 4)
        XCTAssertEqual(model.modInstallationActionReceipt?.version, 2)
        XCTAssertEqual(wire.requests.filter { $0.url?.path == action }.count, 1)
    }

    func testForeignDispatchWithOriginalModReceiptRemainsReadOnlyAndRetained() async throws {
        let originalWire = PlayRecoveryRecordingTransport(), memory = Memory(), owner = try owner()
        configure(originalWire); originalWire.responses[read] = .failure(.unknownResult)
        let original = try coordinator(originalWire, memory: memory, owner: owner)
        await original.start(); await submit(original)
        let retained = try record(memory, owner: owner)
        let base = PlayMemoryAdvancedRecovery()
        let prepared = try await base.prepare(PlayAdvancedRecoveryRecord(session: owner,
            scope: .init(activityID: 0, topicID: 71, nodeID: 701), pending: retained.command, requestedCard: false))
        let dispatched = try await base.transition(prepared, to: .dispatching, startedSessionID: nil)
        let recovery = Recovery(base: base, processID: UUID()), freshWire = PlayRecoveryRecordingTransport()
        configure(freshWire)
        let fresh = try coordinator(freshWire, memory: memory, owner: owner, recovery: recovery)
        await fresh.start(); await fresh.retryExact()
        let encrypted = try await recovery.read()
        XCTAssertEqual(encrypted, dispatched); XCTAssertEqual(fresh.phase, "unknown")
        XCTAssertEqual(fresh.modInstallationActionReceipt?.version, 2); XCTAssertFalse(fresh.canInteract)
        XCTAssertEqual(recovery.acknowledgementAttempts, 0); XCTAssertEqual(recovery.clears, 0)
        XCTAssertEqual(freshWire.requests.filter { $0.url?.path == read }.count, 1)
        XCTAssertTrue(freshWire.requests.allSatisfy { $0.httpMethod == "GET" })
        XCTAssertFalse(try record(memory, owner: owner).settled)
    }
}
