import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Uses the original service, coordinator, store and receipt verifier. All wire bytes are
/// synthetic; a rejected proof is evidence for inspection, never an acknowledged result.
@MainActor final class NativeAttributeAuthorReceiptEvidencePreservationTests: XCTestCase {
    private static let sourceRow = String(NativeAttributeAuthorTestFixtures.extendedRow.dropLast())
        + #", "future":{"exact":1e1,"text":"原值👩🏽‍💻"}}"#
    private static var editedRow: String { sourceRow.replacingOccurrences(of: "温度", with: "气温") }
    private func binding(account: Int64 = 7, epoch: UInt64 = 1, namespace: String = "receipt-evidence",
                         revision: String = "author-issuance", topic: Int64 = 88) throws -> NativeAttributeAuthorBinding {
        try .init(server: "https://example.test/author-evidence", namespace: namespace, accountID: account,
            epoch: epoch, authorizationRevision: revision, topicID: topic, sourceConfigVersion: 4, requestScope: "")
    }
    private static func list() -> Data {
        Data("{\"code\":200,\"topicId\":88,\"configVersion\":4,\"data\":[\(sourceRow)]}".utf8)
    }
    private static func target() -> Data {
        Data("{\"code\":200,\"topicId\":88,\"configVersion\":4,\"data\":{\"definitions\":[\(editedRow)],\"warnings\":[]}}".utf8)
    }
    private func pending(_ owner: NativeAttributeAuthorBinding, deleting: Bool = false) throws -> NativeAttributeAuthorPending {
        var draft = try NativeAttributeAuthorDraft(binding: owner, rawRows: Data("[\(Self.sourceRow)]".utf8))
        let key = UUID()
        if deleting {
            var result = NativeAttributeAuthorPending(request: try .definitionDelete("counter.temp", binding: owner, requestKey: key),
                draft: draft, deletingKey: "counter.temp")
            result.dispatchStarted = true; return result
        }
        var row = draft.rows[0]; row.label = "气温"; try draft.replace(row)
        var result = NativeAttributeAuthorPending(request: try .definitionsWrite(draft, key: key), draft: draft)
        result.validatedTarget = try .init(draft: draft, requestKey: key, response: Self.target())
        result.dispatchStarted = true; return result
    }
    private func response(_ original: NativeAttributeAuthorPending, omitProof: Bool = false,
                          modify: (inout [String: ProjectEditJSON]) -> Void = { _ in }) throws -> Data {
        let request = original.request
        var proof: [String: ProjectEditJSON] = [
            "protocolVersion": .string(NativeAttributeAuthorRequest.originalRequestProtocol),
            "requestId": .string(request.requestKey.uuidString.lowercased()),
            "payloadSHA256": .string(request.originalPayloadSHA256), "method": .string(request.method.rawValue),
            "topicId": .number(Decimal(request.binding.topicID)),
            "expectedConfigVersion": .number(Decimal(request.binding.sourceConfigVersion)), "state": .string("COMMITTED")]
        modify(&proof)
        let proofText = String(decoding: try NativeAttributeAuthorWire.encode(.object(proof)), as: UTF8.self)
        let proofField = omitProof ? "" : ",\"requestReceipt\":\(proofText)"
        return Data("{\"code\":200,\"topicId\":88,\"configVersion\":5,\"data\":{\"definitions\":[\(Self.editedRow)],\"warnings\":[],\"keys\":[\(Self.editedRow)]}\(proofField),\"futureEvidence\":{\"number\":1e1,\"zero\":-0.00,\"text\":\"原响应👩🏽‍💻\"}}".utf8)
    }
    private func invalidProofResponses(_ original: NativeAttributeAuthorPending) throws -> [Data] {
        var values = [try response(original, omitProof: true)]
        for field in ["protocolVersion", "requestId", "payloadSHA256", "method", "topicId", "expectedConfigVersion", "state"] {
            values.append(try response(original) { $0[field] = nil })
        }
        let wrong: [String: ProjectEditJSON] = ["protocolVersion": .string("future-protocol"),
            "requestId": .string(UUID().uuidString.lowercased()), "payloadSHA256": .string(String(repeating: "0", count: 64)),
            "method": .string("PUT"), "topicId": .number(89), "expectedConfigVersion": .number(5), "state": .string("FUTURE_STATE")]
        for (field, value) in wrong { values.append(try response(original) { $0[field] = value }) }
        for state in ["NOT_FOUND", "UNKNOWN"] { values.append(try response(original) { $0["state"] = .string(state) }) }
        return values
    }
    private func assertUnconfirmed(_ value: NativeAttributeAuthorMutationReply, bytes: Data,
                                   file: StaticString = #filePath, line: UInt = #line) {
        guard case .unconfirmed(let received) = value else { return XCTFail("Invalid proof must not acknowledge a mutation", file: file, line: line) }
        XCTAssertEqual(received, bytes, file: file, line: line)
    }
    private func invoke(_ service: NativeAttributeAuthorService, _ original: NativeAttributeAuthorPending,
                        recovering: Bool) async throws -> NativeAttributeAuthorMutationReply {
        if recovering { return try await service.recoverOriginal(original) }
        return try await service.submitWithReceipt(original)
    }
    private func setup(_ owner: NativeAttributeAuthorBinding) ->
        (NativeAttributeAuthorRecordingTransport, NativeAttributeAuthorMemoryStorage, NativeAttributeAuthorService, NativeAttributeAuthorCoordinator) {
        let wire = NativeAttributeAuthorRecordingTransport(), storage = NativeAttributeAuthorMemoryStorage()
        wire.response = { request in (request.path.hasSuffix("/validate") ? Self.target() : Self.list(), 200) }
        let service = NativeAttributeAuthorService(transport: wire, current: { owner }, contract: .versionedCandidate)
        return (wire, storage, service, .init(binding: owner, service: service, store: .init(storage: storage)))
    }
    private func prepare(_ coordinator: NativeAttributeAuthorCoordinator) async throws {
        await coordinator.load()
        var row = try XCTUnwrap(coordinator.draft?.rows.first); row.label = "气温"
        XCTAssertTrue(coordinator.replace(row)); await coordinator.prepareSave()
        XCTAssertEqual(coordinator.phase, .review)
    }
    func testSubmitAndOriginalGETPreserveEveryRejectedProofByteWithoutAcknowledging() async throws {
        let owner = try binding(), original = try pending(owner), wire = NativeAttributeAuthorRecordingTransport()
        let service = NativeAttributeAuthorService(transport: wire, current: { owner }, contract: .versionedCandidate)
        for bytes in try invalidProofResponses(original) {
            wire.response = { _ in (bytes, 200) }
            assertUnconfirmed(try await service.submitWithReceipt(original), bytes: bytes)
            assertUnconfirmed(try await service.recoverOriginal(original), bytes: bytes)
            XCTAssertEqual(wire.requests.suffix(2).map(\.method), [.post, .get])
            XCTAssertEqual(wire.requests.last, try NativeAttributeAuthorRequest.originalReceipt(original.request))
            XCTAssertEqual(wire.requests[wire.requests.count - 2], original.request)
            XCTAssertFalse(original.acknowledged); XCTAssertNil(original.receipt); XCTAssertNil(original.lastResponse)
            XCTAssertTrue(String(decoding: bytes, as: UTF8.self).contains("1e1"))
            XCTAssertTrue(String(decoding: bytes, as: UTF8.self).contains("-0.00"))
        }
    }
    func testCoordinatorPersistsEvidenceAndColdLoadRecoversSameUUIDOnlyThroughOriginalGET() async throws {
        let owner = try binding(), (wire, storage, service, coordinator) = setup(owner)
        try await prepare(coordinator)
        var first: Data?
        wire.response = { _ in
            let bytes = try self.response(XCTUnwrap(coordinator.pending), omitProof: true); first = bytes; return (bytes, 200)
        }
        await coordinator.confirm()
        let original = try XCTUnwrap(coordinator.pending), bytes = try XCTUnwrap(first)
        XCTAssertEqual(coordinator.phase, .unknown); XCTAssertEqual(original.lastResponse, bytes)
        XCTAssertFalse(original.acknowledged); XCTAssertNil(original.receipt); XCTAssertFalse(coordinator.canEdit)
        let local = NativeAttributeAuthorLocalStore(storage: storage)
        XCTAssertEqual(try local.load(binding: owner)?.pending, original)
        XCTAssertTrue(String(decoding: original.draft.rawSource, as: UTF8.self).contains("1e1"))
        let restarted = NativeAttributeAuthorCoordinator(binding: owner, service: service, store: local)
        let before = wire.requests.count; await restarted.load()
        XCTAssertEqual(wire.requests.count, before); XCTAssertEqual(restarted.pending, original)
        let next = try response(original) { $0["payloadSHA256"] = .string("wrong") }
        wire.response = { request in
            XCTAssertEqual(request, try NativeAttributeAuthorRequest.originalReceipt(original.request)); return (next, 200)
        }
        await restarted.readback(); await restarted.confirm()
        XCTAssertEqual(restarted.phase, .unknown); XCTAssertEqual(restarted.pending?.request, original.request)
        XCTAssertEqual(restarted.pending?.draft.rawSource, original.draft.rawSource)
        XCTAssertEqual(restarted.pending?.lastResponse, next); XCTAssertFalse(restarted.pending?.acknowledged == true)
        XCTAssertEqual(try local.load(binding: owner)?.pending?.lastResponse, next)
        XCTAssertEqual(wire.requests.count, before + 1)
        XCTAssertEqual(wire.requests.filter { $0.isVersionedMutation }.count, 1)
        XCTAssertNil(restarted.sourceRetirementReceipt); XCTAssertNil(restarted.latestForInspection)
    }
    func testValidCommittedProofStillRequiresCompleteReceiptAndConfirmsOriginalTarget() async throws {
        let owner = try binding(), original = try pending(owner), wire = NativeAttributeAuthorRecordingTransport()
        let bytes = try response(original)
        XCTAssertEqual(try original.request.verifyOriginalReceipt(XCTUnwrap(NativeAttributeAuthorWire.decode(bytes).object)), "COMMITTED")
        let service = NativeAttributeAuthorService(transport: wire, current: { owner }, contract: .versionedCandidate)
        wire.response = { _ in (bytes, 200) }
        for reply in [try await service.submitWithReceipt(original), try await service.recoverOriginal(original)] {
            guard case .confirmed(let receipt) = reply else { return XCTFail("Complete original receipt was lost") }
            XCTAssertEqual(receipt.response, bytes); XCTAssertEqual(receipt.requestKey, original.request.requestKey)
            XCTAssertEqual(receipt.binding.sourceConfigVersion, 5)
            XCTAssertNotNil(try receipt.readback().rows.first?.original["future"])
        }
        let (flowWire, _, _, coordinator) = setup(owner); try await prepare(coordinator)
        flowWire.response = { _ in (try self.response(XCTUnwrap(coordinator.pending)), 200) }
        await coordinator.confirm()
        XCTAssertEqual(coordinator.phase, .confirmed); XCTAssertNil(coordinator.pending)
        XCTAssertEqual(coordinator.sourceRetirementReceipt?.binding.sourceConfigVersion, 5)
        XCTAssertEqual(coordinator.draft?.rows.first?.label, "气温"); XCTAssertFalse(coordinator.canEdit)
        XCTAssertEqual(flowWire.requests.filter(\.isVersionedMutation).count, 1)
    }
    func testCommittedProofCannotBypassWrongVersionTopicOrIncompleteMutationReceipt() async throws {
        let owner = try binding(), original = try pending(owner), wire = NativeAttributeAuthorRecordingTransport()
        let correct = try response(original), text = String(decoding: correct, as: UTF8.self)
        let invalid = [text.replacingOccurrences(of: "\"configVersion\":5", with: "\"configVersion\":4"),
            text.replacingOccurrences(of: "\"configVersion\":5", with: "\"configVersion\":6"),
            text.replacingOccurrences(of: "\"topicId\":88,\"configVersion\"", with: "\"topicId\":89,\"configVersion\""),
            text.replacingOccurrences(of: "\"visible\":true,", with: ""),
            text.replacingOccurrences(of: "\"warnings\":[]", with: "\"warnings\":null")]
        let service = NativeAttributeAuthorService(transport: wire, current: { owner }, contract: .versionedCandidate)
        for text in invalid {
            let bytes = Data(text.utf8); XCTAssertNotEqual(bytes, correct)
            wire.response = { _ in (bytes, 200) }
            assertUnconfirmed(try await service.submitWithReceipt(original), bytes: bytes)
            assertUnconfirmed(try await service.recoverOriginal(original), bytes: bytes)
            XCTAssertThrowsError(try NativeAttributeAuthorMutationReceipt(pending: original, response: bytes))
        }
    }
    func testConflictsRejectionsNotDeletedAndTransportErrorsKeepDistinctSemantics() async throws {
        let owner = try binding(), original = try pending(owner), wire = NativeAttributeAuthorRecordingTransport()
        let service = NativeAttributeAuthorService(transport: wire, current: { owner }, contract: .versionedCandidate)
        for recover in [false, true] {
            for status in [403, 409] {
                wire.response = { _ in (Data("{\"code\":\(status),\"msg\":\"explicit refusal\"}".utf8), status) }
                do {
                    _ = try await invoke(service, original, recovering: recover); XCTFail()
                } catch {
                    XCTAssertEqual(error as? NativeAttributeAuthorError, status == 409 ? .versionConflict("explicit refusal") : .rejected("explicit refusal"))
                }
            }
            let unavailable = Data(#"{"code":503,"msg":"temporarily unavailable"}"#.utf8)
            wire.response = { _ in (unavailable, 503) }
            do { _ = try await invoke(service, original, recovering: recover); XCTFail() }
            catch { XCTAssertEqual(error as? NativeAttributeAuthorError, .unconfirmedResponse(unavailable)) }
            wire.response = { _ in throw URLError(.timedOut) }
            do { _ = try await invoke(service, original, recovering: recover); XCTFail() }
            catch { XCTAssertEqual((error as? URLError)?.code, .timedOut) }
            let deletion = try pending(owner, deleting: true)
            let saved = try response(deletion)
            let root = try XCTUnwrap(NativeAttributeAuthorWire.decode(saved).object)
            let proof = try XCTUnwrap(root["requestReceipt"])
            let bytes = try NativeAttributeAuthorWire.encode(.object(["code": .number(200), "topicId": .number(88),
                "configVersion": .number(4), "data": .object(["deleted": .bool(false)]), "requestReceipt": proof]))
            wire.response = { _ in (bytes, 200) }
            let reply = try await invoke(service, deletion, recovering: recover)
            guard case .notDeleted = reply else { return XCTFail("Existing explicit notDeleted outcome changed") }
        }
    }
    func testLateRejectedEvidenceCannotWriteAfterOwnerEpochAuthorizationOrVisitRetirement() async throws {
        let owner = try binding()
        let replacements: [NativeAttributeAuthorBinding?] = [owner, try binding(account: 8), try binding(epoch: 2),
            try binding(namespace: "other"), try binding(revision: "revoked"), nil]
        for recover in [false, true] {
            for replacement in replacements {
                var current: NativeAttributeAuthorBinding? = owner
                let wire = NativeAttributeAuthorRecordingTransport(), storage = NativeAttributeAuthorMemoryStorage()
                wire.response = { request in (request.path.hasSuffix("/validate") ? Self.target() : Self.list(), 200) }
                let service = NativeAttributeAuthorService(transport: wire, current: { current }, contract: .versionedCandidate)
                let local = NativeAttributeAuthorLocalStore(storage: storage)
                let coordinator = NativeAttributeAuthorCoordinator(binding: owner, service: service, store: local)
                try await prepare(coordinator)
                if recover {
                    wire.response = { _ in throw URLError(.timedOut) }; await coordinator.confirm()
                }
                var held: CheckedContinuation<(Data, Int), Error>?
                wire.response = { _ in try await withCheckedThrowingContinuation { held = $0 } }
                let task = Task { if recover { await coordinator.readback() } else { await coordinator.confirm() } }
                for _ in 0..<2000 { if held != nil { break }; await Task.yield() }
                guard let continuation = held else { return XCTFail("No original wire admission") }; held = nil
                let original = try XCTUnwrap(coordinator.pending), bytes = try response(original, omitProof: true)
                let before = storage.values; current = replacement
                let retired = replacement == nil || replacement == owner
                if retired { coordinator.retire() }
                continuation.resume(returning: (bytes, 200)); await task.value
                XCTAssertEqual(storage.values, before)
                XCTAssertNil(coordinator.pending?.lastResponse); XCTAssertNil(coordinator.sourceRetirementReceipt)
                if retired { XCTAssertEqual(coordinator.phase, .retired); XCTAssertNil(coordinator.draft) }
                else { XCTAssertEqual(coordinator.phase, .unknown); XCTAssertEqual(coordinator.pending?.request, original.request) }
                XCTAssertEqual(try local.load(binding: owner)?.pending?.request, original.request)
            }
        }
    }
    func testOriginalHostApprovalWithdrawalDropsAdmittedResponseWithoutPersistingItsBytes() async throws {
        let owner = try binding(), config = try APIConfiguration(baseURL: XCTUnwrap(URL(string: owner.server)))
        for recover in [false, true] {
            let approval = try OperationEndpointApproval(baseURL: config.baseURL, namespace: owner.namespace, accountID: 7,
                paths: ["api/topic/attribute-author", "api/topic/attribute-author/validate", "api/topic/attribute-author/request"])
            var live: OperationEndpointApproval? = approval
            let credentials = try NativeAttributeAuthorHostCredentials(binding: owner, token: "synthetic-author-token")
            var wire: [URLRequest] = [], held: CheckedContinuation<(Data, Int), Error>?, hold = false, loseOriginalWrite = false
            let transport = NativeAttributeAuthorHostTransport(configuration: config, approval: approval,
                currentApproval: { live }, currentCapability: { _ in true }, credentials: { credentials }) { request, finalCheck in
                try finalCheck(); wire.append(request)
                if hold { return try await withCheckedThrowingContinuation { held = $0 } }
                if request.url?.path.hasSuffix("/validate") == true { return (Self.target(), 200) }
                if request.httpMethod == "POST", loseOriginalWrite { throw URLError(.timedOut) }
                return (Self.list(), 200)
            }
            let storage = NativeAttributeAuthorMemoryStorage()
            let service = NativeAttributeAuthorService(transport: transport, current: { owner }, contract: .versionedCandidate)
            let coordinator = NativeAttributeAuthorCoordinator(binding: owner, service: service, store: .init(storage: storage))
            try await prepare(coordinator)
            if recover {
                // Enter the real original host POST once, lose its response, then cold-restore.
                loseOriginalWrite = true; await coordinator.confirm(); loseOriginalWrite = false
                XCTAssertEqual(coordinator.phase, .unknown); XCTAssertNotNil(coordinator.pending)
                coordinator.retire()
            }
            let active: NativeAttributeAuthorCoordinator
            if recover {
                active = .init(binding: owner, service: service, store: .init(storage: storage)); await active.load()
                XCTAssertEqual(active.phase, .unknown)
            } else { active = coordinator }
            hold = true
            let task = Task { if recover { await active.readback() } else { await active.confirm() } }
            for _ in 0..<2000 { if held != nil { break }; await Task.yield() }
            guard let continuation = held else { return XCTFail("No original host final-forward") }; held = nil
            let original = try XCTUnwrap(active.pending), before = storage.values
            XCTAssertEqual(wire.last?.httpMethod, recover ? "GET" : "POST")
            live = nil; continuation.resume(returning: (try response(original, omitProof: true), 200)); await task.value
            XCTAssertEqual(storage.values, before); XCTAssertNil(active.pending?.lastResponse)
            XCTAssertEqual(active.phase, .unknown); XCTAssertEqual(active.pending?.request, original.request)
        }
    }
    func testEvidenceStorageFailureRetainsOriginalDurablePendingAndCannotConfirm() async throws {
        let owner = try binding(), (wire, storage, _, coordinator) = setup(owner)
        try await prepare(coordinator)
        var oldBytes: [String: Data] = [:], original: NativeAttributeAuthorPending?
        wire.response = { _ in
            original = coordinator.pending; oldBytes = storage.values; storage.failWrites = true
            return (try self.response(XCTUnwrap(original), omitProof: true), 200)
        }
        await coordinator.confirm()
        XCTAssertEqual(coordinator.phase, .unknown); XCTAssertEqual(storage.values, oldBytes)
        XCTAssertEqual(coordinator.pending?.request, original?.request); XCTAssertNil(coordinator.pending?.receipt)
        XCTAssertFalse(coordinator.pending?.acknowledged == true); XCTAssertFalse(coordinator.canEdit)
        storage.failWrites = false
        XCTAssertEqual(try NativeAttributeAuthorLocalStore(storage: storage).load(binding: owner)?.pending?.request, original?.request)
    }
}
