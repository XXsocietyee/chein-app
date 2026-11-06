import XCTest
@testable import QuestifyCore

@available(macOS 14.0, *)
@MainActor final class ModInstallationNativeRuntimeTests: XCTestCase {
    private let start = "/fixture/api/play/advanced/start", action = "/fixture/api/play/advanced/action", read = "/fixture/api/play/advanced/state"
    private let realm = "https://example.com/fixture/"
    private final class Memory: TemplateAuthoringStorage {
        var data: [String: Data] = [:], writes = 0
        var failRead = false, failWrite = false, failReadAfterWrite: Int?
        func read(_ key: String) throws -> Data? { if failRead { throw PlayExperienceError.persistenceUnavailable }; return data[key] }
        func write(_ value: Data, key: String) throws {
            if failWrite { throw PlayExperienceError.persistenceUnavailable }
            data[key] = value; writes += 1
            if writes == failReadAfterWrite { failRead = true }
        }
        func remove(_ key: String) throws { XCTFail("Unresolved/acknowledged journal must not be deleted") }
    }
    private func owner(_ account: Int = 9001, epoch: UInt64 = 1, role: String = "player") throws -> PlayExperienceSession {
        try .init(accountID: account, epoch: epoch, namespace: "synthetic-mod", token: "synthetic", role: role)
    }
    private func raw(version: Int = 1, proof: Bool = true, run: String = String(repeating: "b", count: 64), passed: Bool = false, finished: Bool = false) -> String {
        let provenance = proof ? ",\"modInstallationRuntime\":{\"schema\":\"mod-installation-native-runtime-v1\",\"status\":\"SUPPORTED\",\"kind\":\"QA_PICK\",\"sourceHash\":\"\(String(repeating: "a", count: 64))\",\"runHash\":\"\(run)\",\"sessionId\":501,\"activityId\":0,\"topicId\":71,\"nodeId\":701}" : ""
        return """
        {"sessionId":501,"activityId":0,"topicId":71,"nodeId":701,"ownerType":1,"status":"RUNNING","version":\(version),"config":{"qa":{"enabled":true}},"playKit":{"qa":{"mode":"PICK","multi":false,"finished":\(finished),"passed":\(passed),"attempts":\(max(0, version - 1)),"options":[{"id":"a","label":"A"},{"id":"b","label":"B"}]}}\(provenance)}
        """
    }
    private func reply(_ raw: String) -> PlayRecoveryRecordingTransport.Response { .reply(PlayExperienceSyntheticFixtures.envelope(raw), 200) }
    private func prepare(_ t: PlayRecoveryRecordingTransport) {
        t.responses[start] = reply(raw()); t.responses[action] = .failure(.unknownResult); t.responses[read] = reply(raw(version: 2))
    }
    private func model(_ t: PlayRecoveryRecordingTransport, _ memory: Memory?, lifetime: PlayInteractionLifetime? = nil, current: @escaping () -> PlayExperienceSession?) throws -> PlayAdvancedCoordinator {
        .init(activityID: 0, topicID: 71, nodeID: 701, service: .init(configuration: try .init(baseURL: URL(string: realm)!), transport: t, enabled: [.reads, .advanced], readLifetime: lifetime),
              modJournal: memory.map { ModInstallationNativeRuntimeJournal(storage: $0) }, modGameplayMode: lifetime?.gameplayMode, currentSession: current)
    }
    private func submit(_ m: PlayAdvancedCoordinator) async { await m.submit(kind: "qa", action: "SUBMIT_QA", detail: ["optionId": .string("b")]) }
    private func body(_ t: PlayRecoveryRecordingTransport) throws -> PlayWireValue {
        try JSONDecoder().decode(PlayWireValue.self, from: XCTUnwrap(t.requests.last { $0.url?.path == action }?.httpBody))
    }
    func testRestartRestoresFixedSessionAndOnlyExplicitlyReplaysOriginalUUIDPayload() async throws {
        let t = PlayRecoveryRecordingTransport(), memory = Memory(), firstOwner = try owner(); prepare(t)
        let first = try model(t, memory, current: { firstOwner }); await first.start(); await submit(first)
        let command = try body(t); XCTAssertNotNil(first.pending); XCTAssertEqual(first.phase, "unknown")
        let secondOwner = try owner(epoch: 2), second = try model(t, memory, current: { secondOwner })
        await second.start()
        XCTAssertEqual(t.requests.filter { $0.url?.path == start }.count, 1)
        XCTAssertEqual(t.requests.filter { $0.url?.path == action }.count, 1)
        XCTAssertEqual(second.phase, "retryable"); XCTAssertEqual(second.pending?.key, command["idempotencyKey"].text)
        XCTAssertFalse(second.canInteract); XCTAssertNil(second.modInstallationActionReceipt) // Advanced version is not proof.
        t.responses[action] = reply(raw(version: 2)); t.responses[read] = reply(raw(version: 4, passed: true, finished: true))
        await second.retryExact()
        XCTAssertEqual(try body(t), command); XCTAssertNil(second.pending); XCTAssertEqual(second.state?.version, 4)
        XCTAssertEqual(second.modInstallationActionReceipt?.version, 2)
        XCTAssertEqual(second.modInstallationActionReceipt?.playKit["qa"]["passed"].bool, false)
    }
    func testFailedPersistenceNeverDispatchesAndUncertainWriteRestoresOriginal() async throws {
        let t = PlayRecoveryRecordingTransport(), memory = Memory(), session = try owner(); prepare(t)
        let m = try model(t, memory, current: { session }); await m.start(); memory.failReadAfterWrite = 1
        await submit(m); XCTAssertEqual(t.requests.count, 1); XCTAssertEqual(m.phase, "unknown")
        memory.failRead = false; await m.recover(); XCTAssertEqual(m.phase, "retryable"); XCTAssertNotNil(m.pending)
        XCTAssertEqual(t.requests.filter { $0.url?.path == action }.count, 0)
        let record = try ModInstallationNativeRuntimeJournal(storage: memory).load(owner: session, realm: realm, activity: 0, topic: 71, node: 701)
        XCTAssertEqual(record?.command, m.pending)
    }
    func testACKPersistedBeforeReadbackFailureRestartsWithGETOnly() async throws {
        let t = PlayRecoveryRecordingTransport(), memory = Memory(), session = try owner(); prepare(t)
        t.responses[action] = reply(raw(version: 2)); t.responses[read] = .failure(.unknownResult)
        let m = try model(t, memory, current: { session }); await m.start(); await submit(m)
        XCTAssertEqual(m.modInstallationActionReceipt?.version, 2); XCTAssertNotNil(m.pending); XCTAssertFalse(m.canInteract)
        t.responses[read] = reply(raw(version: 3))
        let restored = try model(t, memory, current: { session }); await restored.start()
        XCTAssertEqual(t.requests.filter { $0.url?.path == action }.count, 1); XCTAssertEqual(restored.state?.version, 3)
        XCTAssertEqual(restored.modInstallationActionReceipt?.version, 2); XCTAssertNil(restored.pending)
    }
    func testACKWriteSucceedsButReadbackFailsNeverRepeatsPOST() async throws {
        let t = PlayRecoveryRecordingTransport(), memory = Memory(), session = try owner(); prepare(t)
        let m = try model(t, memory, current: { session }); await m.start()
        memory.failReadAfterWrite = 2; t.responses[action] = reply(raw(version: 2)); await submit(m)
        XCTAssertEqual(m.phase, "unknown"); XCTAssertNotNil(m.pending)
        memory.failRead = false; await m.recover()
        XCTAssertEqual(t.requests.filter { $0.url?.path == action }.count, 1); XCTAssertNil(m.pending)
        XCTAssertEqual(m.modInstallationActionReceipt?.version, 2)
    }
    func testSettledWriteReadbackFailureKeepsOriginalReceiptAndRecoversWithoutPOST() async throws {
        let t = PlayRecoveryRecordingTransport(), memory = Memory(), session = try owner(); prepare(t)
        let m = try model(t, memory, current: { session }); await m.start()
        memory.failReadAfterWrite = 3; t.responses[action] = reply(raw(version: 2)); await submit(m)
        XCTAssertEqual(m.phase, "unknown"); XCTAssertNotNil(m.pending)
        memory.failRead = false; await m.recover()
        XCTAssertNil(m.pending); XCTAssertEqual(m.phase, "ready"); XCTAssertEqual(t.requests.filter { $0.url?.path == action }.count, 1)
    }
    func testMissingChangedProofOrRejectedRetryCannotReleaseUnknown() async throws {
        for response in [reply(raw(version: 2, proof: false)), reply(raw(version: 2, run: String(repeating: "c", count: 64)))] {
            let t = PlayRecoveryRecordingTransport(), memory = Memory(), session = try owner(); prepare(t)
            let m = try model(t, memory, current: { session }); await m.start(); await submit(m)
            let key = m.pending?.key; t.responses[read] = response; await m.recover()
            XCTAssertEqual(m.phase, "unknown"); XCTAssertEqual(m.pending?.key, key); XCTAssertFalse(m.canInteract)
            t.responses[read] = reply(raw(version: 2)); await m.recover()
            t.responses[action] = .failure(.rejected(409, "synthetic rollback not proved")); await m.retryExact()
            XCTAssertEqual(m.phase, "unknown"); XCTAssertEqual(m.pending?.key, key)
        }
    }
    func testAccountNamespaceAndRoleNeverRebindOriginalCommand() async throws {
        let t = PlayRecoveryRecordingTransport(), memory = Memory(); var session: PlayExperienceSession? = try owner(); prepare(t)
        let m = try model(t, memory, current: { session }); await m.start(); await submit(m)
        let record = try XCTUnwrap(ModInstallationNativeRuntimeJournal(storage: memory).load(owner: XCTUnwrap(session), realm: realm, activity: 0, topic: 71, node: 701))
        session = try owner(9002); await m.recover(); XCTAssertFalse(m.isCurrent); XCTAssertNil(m.modInstallationActionReceipt)
        let store = ModInstallationNativeRuntimeJournal(storage: memory)
        XCTAssertNil(try store.load(owner: XCTUnwrap(session), realm: realm, activity: 0, topic: 71, node: 701))
        XCTAssertThrowsError(try store.load(owner: owner(role: "merchant"), realm: realm, activity: 0, topic: 71, node: 701))
        XCTAssertEqual(try store.load(owner: owner(epoch: 9), realm: realm, activity: 0, topic: 71, node: 701)?.command, record.command)
    }
    func testLateOwnerResponseCannotAcknowledgeOrExposeReceipt() async throws {
        let t = PlayRecoveryRecordingTransport(), memory = Memory(); var session: PlayExperienceSession? = try owner(); prepare(t)
        let m = try model(t, memory, current: { session }); await m.start()
        t.responses[action] = reply(raw(version: 2)); t.pauseResponse = true
        let task = Task { await self.submit(m) }
        for _ in 0..<1000 { if t.isAwaitingResponse { break }; await Task.yield() }
        XCTAssertTrue(t.isAwaitingResponse); session = try owner(9002); t.resumeResponse(); await task.value
        XCTAssertEqual(m.phase, "stale"); XCTAssertNil(m.modInstallationActionReceipt)
        let record = try ModInstallationNativeRuntimeJournal(storage: memory).load(owner: owner(), realm: realm, activity: 0, topic: 71, node: 701)
        XCTAssertNil(record?.receipt); XCTAssertEqual(record?.settled, false)
    }
    func testOrdinaryRuntimeRetainsLegacyPathAndDoesNotWriteModJournal() async throws {
        let t = PlayRecoveryRecordingTransport(), memory = Memory(), session = try owner(); prepare(t)
        t.responses[start] = reply(raw(proof: false)); t.responses[action] = reply(raw(version: 2, proof: false))
        let m = try model(t, memory, current: { session }); await m.start(); await submit(m)
        XCTAssertTrue(memory.data.isEmpty); XCTAssertNil(m.pending); XCTAssertEqual(t.requests.count, 2)
    }
    func testProvenModWithoutStorageOrLosingProofCannotDowngradeToLegacy() async throws {
        let t = PlayRecoveryRecordingTransport(), session = try owner(); prepare(t)
        let missing = try model(t, nil, current: { session }); await missing.start(); XCTAssertFalse(missing.canInteract)
        let m = try model(t, Memory(), current: { session }); await m.start(); XCTAssertTrue(m.canInteract)
        t.responses[read] = reply(raw(version: 2, proof: false)); await m.refreshAuthoritative(); XCTAssertFalse(m.canInteract)
    }
    func testChoiceRetainsOptionIdentityAndOriginalTerminalStepWithoutCorrectness() async throws {
        func choice(_ version: Int, terminal: Bool) throws -> String {
            var wire = try JSONDecoder().decode(PlayWireValue.self, from: Data(raw(version: version).utf8)).object!
            var proof = wire["modInstallationRuntime"]!.object!; proof["kind"] = .string("CHOICE")
            wire["modInstallationRuntime"] = .object(proof); wire["config"] = .object(["branch": .object(["enabled": .bool(true)])]); wire["playKit"] = .object([:])
            let options: [PlayWireValue] = terminal ? [] : [.object(["id": .string("b"), "label": .string("Choice B")])]
            let step: PlayWireValue = .object(["terminal": .bool(terminal), "title": .string("Choice B"), "options": .array(options)])
            wire["branch"] = .object(["currentStepId": .string(terminal ? "__result_1" : "__entry"), "currentStep": step])
            return String(decoding: try JSONEncoder().encode(PlayWireValue.object(wire)), as: UTF8.self)
        }
        let t = PlayRecoveryRecordingTransport(), memory = Memory(), session = try owner(); prepare(t)
        t.responses[start] = reply(try choice(1, terminal: false)); t.responses[read] = reply(try choice(2, terminal: true))
        let m = try model(t, memory, current: { session }); await m.start()
        await m.submit(kind: "branch", action: "CHOOSE", detail: ["optionId": .string("b")])
        let original = try body(t); XCTAssertEqual(original["action"].text, "CHOOSE")
        let restored = try model(t, memory, current: { session }); await restored.start()
        XCTAssertFalse(restored.canInteract); t.responses[action] = reply(try choice(2, terminal: true)); await restored.retryExact()
        XCTAssertEqual(try body(t), original); XCTAssertEqual(restored.modInstallationActionReceipt?.branch["currentStepId"].text, "__result_1")
        XCTAssertEqual(restored.modInstallationActionReceipt?.branch["currentStep"]["terminal"].bool, true)
        XCTAssertNil(restored.modInstallationActionReceipt?.branch["passed"].bool)
    }
    func testUnreadableJournalBlocksStartUntilOriginalScopeCanBeRead() async throws {
        let t = PlayRecoveryRecordingTransport(), memory = Memory(), session = try owner(); prepare(t)
        memory.failRead = true; let m = try model(t, memory, current: { session }); await m.start()
        XCTAssertTrue(t.requests.isEmpty); XCTAssertEqual(m.phase, "unknown")
        memory.failRead = false; await m.recover(); XCTAssertEqual(m.phase, "idle")
        await m.start(); XCTAssertEqual(t.requests.count, 1)
    }
    private func root(_ t: PlayRecoveryRecordingTransport, owner: PlayExperienceSession) throws -> PlayExperienceCoordinator {
        .init(scope: .topic(71), service: .init(configuration: try .init(baseURL: URL(string: realm)!), transport: t, enabled: [.reads]),
              recovery: PlayMemoryCompletionRecovery(), pausedStorage: PlayMemoryPausedStorage(), currentSession: { owner })
    }
    private func nodes(_ mode: Int) -> String { "{\"mode\":\(mode),\"topicId\":71,\"registered\":true,\"playable\":true,\"nodes\":[{\"nodeId\":701,\"done\":false,\"arrived\":true,\"validationMethod\":6}]}" }
    func testRetiredReadOnlyRecreatesDurableModInSameAuthoritativeMode() async throws {
        for proven in [true, false] {
            let t = PlayRecoveryRecordingTransport(), reads = PlayRecoveryRecordingTransport(), memory = Memory(), session = try owner(); prepare(t)
            t.responses[start] = reply(raw(proof: proven)); reads.responses["/fixture/api/play/nodes"] = reply(nodes(1))
            let root = try root(reads, owner: session); await root.load(); let oldLease = try XCTUnwrap(root.makeInteractionLifetime())
            let old = try model(t, memory, lifetime: oldLease, current: { session }); await old.start(); await submit(old)
            let key = old.pending?.key; await root.load(); XCTAssertFalse(oldLease.isCurrent)
            XCTAssertEqual(old.canRestoreModAfterRetiredRead(gameplayMode: .cityOrientation), proven)
            XCTAssertFalse(old.canRestoreModAfterRetiredRead(gameplayMode: .freeExploration))
            if proven {
                let fresh = try model(t, memory, lifetime: XCTUnwrap(root.makeInteractionLifetime()), current: { session }); await fresh.start()
                XCTAssertEqual(fresh.pending?.key, key); XCTAssertEqual(fresh.phase, "retryable")
                XCTAssertEqual(t.requests.filter { $0.url?.path == start }.count, 1); XCTAssertEqual(t.requests.filter { $0.url?.path == action }.count, 1)
                reads.responses["/fixture/api/play/nodes"] = reply(nodes(2)); await root.load()
                let different = try model(t, memory, lifetime: XCTUnwrap(root.makeInteractionLifetime()), current: { session })
                let count = t.requests.count; await different.start(); XCTAssertEqual(different.phase, "unknown"); XCTAssertEqual(t.requests.count, count)
                let saved = try ModInstallationNativeRuntimeJournal(storage: memory).load(owner: session, realm: realm, activity: 0, topic: 71, node: 701, gameplayMode: .cityOrientation)
                XCTAssertEqual(saved?.command.key, key); XCTAssertEqual(saved?.settled, false)
            }
        }
    }
    func testRetiredLateResponseCannotAcknowledgeFreshCoordinatorOriginalCommand() async throws {
        let oldWire = PlayRecoveryRecordingTransport(), freshWire = PlayRecoveryRecordingTransport(), reads = PlayRecoveryRecordingTransport(), memory = Memory(), session = try owner()
        prepare(oldWire); prepare(freshWire); reads.responses["/fixture/api/play/nodes"] = reply(nodes(1))
        let root = try root(reads, owner: session); await root.load()
        let old = try model(oldWire, memory, lifetime: XCTUnwrap(root.makeInteractionLifetime()), current: { session }); await old.start()
        oldWire.responses[action] = reply(raw(version: 2)); oldWire.pauseResponse = true
        let submit = Task { await self.submit(old) }
        for _ in 0..<1000 { if oldWire.isAwaitingResponse { break }; await Task.yield() }
        XCTAssertTrue(oldWire.isAwaitingResponse); let key = old.pending?.key
        await root.load(); let fresh = try model(freshWire, memory, lifetime: XCTUnwrap(root.makeInteractionLifetime()), current: { session }); await fresh.start()
        XCTAssertEqual(fresh.pending?.key, key); XCTAssertEqual(fresh.phase, "retryable")
        oldWire.resumeResponse(); await submit.value
        XCTAssertEqual(old.phase, "stale"); XCTAssertNil(old.modInstallationActionReceipt)
        XCTAssertEqual(fresh.pending?.key, key); XCTAssertFalse(fresh.canInteract); XCTAssertNil(fresh.modInstallationActionReceipt)
        XCTAssertEqual(freshWire.requests.count, 1); XCTAssertEqual(freshWire.requests.first?.httpMethod, "GET")
        let saved = try ModInstallationNativeRuntimeJournal(storage: memory).load(owner: session, realm: realm, activity: 0, topic: 71, node: 701, gameplayMode: .cityOrientation)
        XCTAssertNil(saved?.receipt)
    }
    func testConcurrentJournalCASAndMalformedRecordFailClosed() async throws {
        let memory = Memory(), session = try owner(), journal = ModInstallationNativeRuntimeJournal(storage: memory)
        let state = try PlayAdvancedState(JSONDecoder().decode(PlayWireValue.self, from: Data(raw().utf8)))
        let command = PlayAdvancedPending(sessionID: 501, version: 1, key: UUID().uuidString, action: "SUBMIT_QA", payload: ["optionId": .string("a")])
        let record = try ModInstallationNativeRuntimeRecord(owner: session, realm: realm, proof: ModInstallationNativeRuntimeProof(state: state), command: command)
        try journal.save(record, replacing: nil, owner: session)
        XCTAssertThrowsError(try journal.save(record, replacing: nil, owner: session))
        let key = try XCTUnwrap(memory.data.keys.first); memory.data[key] = Data("{}".utf8)
        XCTAssertThrowsError(try journal.load(owner: session, realm: realm, activity: 0, topic: 71, node: 701))
    }
}
