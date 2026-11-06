import Foundation
import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore
#elseif canImport(Questify)
@testable import Questify
#endif

@MainActor final class NativeConditionAuthorSessionTests: XCTestCase {
    private final class Host: NativeConditionAuthorDraftHosting {
        var scope = NativeConditionAuthorWireTests.scope
        var raw = NativeConditionAuthorWireTests.graph
        var canEdit = true
        var saveFails = false
        var writes = 0
        var pendingRequest = Data("original-unknown-request".utf8)
        var projection: NativeConditionAuthorAttributeProjection?
        func capture() -> NativeConditionAuthorCapture? {
            .init(scope: scope, raw: raw, surface: .routeGraph, catalog: NativeConditionAuthorWireTests.catalog, attributes: projection, canEdit: canEdit)
        }
        func persistOriginalDraft(_ raw: String, replacing expected: NativeConditionAuthorCapture) throws -> NativeConditionAuthorCapture {
            guard canEdit, scope == expected.scope, self.raw.utf8.elementsEqual(expected.raw.utf8) else { throw NativeConditionAuthorError.staleEditor }
            writes += 1
            if saveFails { throw NativeConditionAuthorError.persistenceFailed }
            self.raw = raw; return capture()!
        }
    }
    private final class Reader: NativeConditionAuthorReadbackServing {
        var continuation: CheckedContinuation<NativeConditionAuthorReadback, Error>?
        func readOriginalAuthorSource(for scope: NativeConditionAuthorScope) async throws -> NativeConditionAuthorReadback {
            try await withCheckedThrowingContinuation { continuation = $0 }
        }
    }
    private func edit(_ session: NativeConditionAuthorSession) throws {
        let path = NativeConditionAuthorWireTests.condition
        let before = try XCTUnwrap(NativeConditionAuthorTree.value(session.document.value, at: path))
        try session.replace(path: path, expected: before, replacement: .object(["op": .string("HAS_TAG"), "value": .string("tag.open")]), revision: session.document.revision)
    }
    private func waitForReader(_ reader: Reader) async {
        for _ in 0..<100 where reader.continuation == nil { await Task.yield() }
        XCTAssertNotNil(reader.continuation)
    }
    func testOriginalLocalSaverReceivesWholeGraphAndLocalSavedIsNotServerSuccess() async throws {
        let host = Host(), session = try NativeConditionAuthorSession(host: host); try edit(session)
        let pending = host.pendingRequest
        try session.saveOriginalLocalDraft()
        XCTAssertEqual(host.writes, 1); XCTAssertEqual(host.pendingRequest, pending)
        XCTAssertEqual(session.state, .localSaved); XCTAssertNil(session.authoritative)
        XCTAssertFalse(session.document.hasChanges); XCTAssertTrue(host.raw.contains("tag.open"))
        XCTAssertTrue(host.raw.contains("fallbacks")); XCTAssertTrue(host.raw.contains("stringVariables"))
    }
    func testStorageFailureDoesNotClaimSave() async throws {
        let host = Host(), session = try NativeConditionAuthorSession(host: host); try edit(session); host.saveFails = true
        XCTAssertThrowsError(try session.saveOriginalLocalDraft())
        XCTAssertNotEqual(session.state, .localSaved); XCTAssertTrue(session.document.hasChanges)
        XCTAssertEqual(host.raw, NativeConditionAuthorWireTests.graph)
    }
    func testUnknownPendingWriteLocksEditorAndRetainsOriginalRequest() async throws {
        let host = Host(), session = try NativeConditionAuthorSession(host: host)
        let pending = host.pendingRequest; host.canEdit = false
        XCTAssertThrowsError(try edit(session)); XCTAssertThrowsError(try session.saveOriginalLocalDraft())
        XCTAssertEqual(host.writes, 0); XCTAssertEqual(host.pendingRequest, pending)
    }
    func testScopeChangeOrRestoredDraftCannotOverwriteNewOwner() async throws {
        let host = Host(), session = try NativeConditionAuthorSession(host: host); try edit(session)
        host.scope = .init(accountID: 9, namespace: "other", epoch: 2, authorizationRevision: "other", documentIdentity: "topic:21", sourceRevision: "8", incarnation: UUID())
        XCTAssertFalse(session.isCurrent); XCTAssertThrowsError(try session.saveOriginalLocalDraft()); XCTAssertEqual(host.writes, 0)
        XCTAssertEqual(host.raw, NativeConditionAuthorWireTests.graph)
    }
    func testConcurrentOriginalDraftEditRejectsStaleCandidate() async throws {
        let host = Host(), session = try NativeConditionAuthorSession(host: host); try edit(session)
        host.raw += " "
        XCTAssertThrowsError(try session.saveOriginalLocalDraft()); XCTAssertEqual(host.writes, 0)
    }
    func testSameVersionAttributeProjectionMutationRetiresEditor() async throws {
        let host = Host()
        host.projection = .init(scope: host.scope, definitionVersion: "7", origin: .currentDefinition,
                                references: [.init(key: "counter.other", label: "old", type: .number, writable: true)])
        let session = try NativeConditionAuthorSession(host: host)
        host.projection = .init(scope: host.scope, definitionVersion: "7", origin: .currentDefinition,
                                references: [.init(key: "counter.other", label: "new", type: .number, writable: true)])
        XCTAssertFalse(session.isCurrent); XCTAssertThrowsError(try edit(session))
    }
    func testUnknownFieldsPreventAnySaverDispatch() async throws {
        let host = Host(); host.raw = host.raw.replacingOccurrences(of: #""id":"gate""#, with: #""future":true,"id":"gate""#)
        let session = try NativeConditionAuthorSession(host: host); try edit(session)
        XCTAssertThrowsError(try session.saveOriginalLocalDraft()); XCTAssertEqual(host.writes, 0)
        XCTAssertTrue(host.raw.contains("future"))
    }
    func testAuthoritativeReadbackComesOnlyFromReaderAndDoesNotReplaceDraft() async throws {
        let host = Host(), session = try NativeConditionAuthorSession(host: host), reader = Reader()
        let task = Task { try await session.readAuthoritative(using: reader) }; await waitForReader(reader)
        let serverRaw = host.raw.replacingOccurrences(of: #""counter.hp":10"#, with: #""counter.hp":9"#)
        reader.continuation?.resume(returning: .init(requestedScope: host.scope, raw: serverRaw, serverRevision: "8"))
        try await task.value
        XCTAssertEqual(session.state, .authoritative("8")); XCTAssertEqual(session.authoritative?.original, serverRaw)
        XCTAssertEqual(host.raw, NativeConditionAuthorWireTests.graph); XCTAssertEqual(host.writes, 0)
    }
    func testLateReadAfterAccountChangeCannotPopulateNewScope() async throws {
        let host = Host(), session = try NativeConditionAuthorSession(host: host), reader = Reader(), scope = host.scope
        let task = Task { try await session.readAuthoritative(using: reader) }; await waitForReader(reader)
        host.scope = .init(accountID: 9, namespace: "other", epoch: 2, authorizationRevision: "x", documentIdentity: "topic:20", sourceRevision: "7", incarnation: UUID())
        reader.continuation?.resume(returning: .init(requestedScope: scope, raw: host.raw, serverRevision: "8"))
        do { try await task.value; XCTFail("stale read accepted") } catch { }
        XCTAssertNil(session.authoritative); XCTAssertEqual(session.state, .stale); XCTAssertEqual(host.writes, 0)
    }
    func testReadCannotOverwriteEditMadeWhileAwaitingResponse() async throws {
        let host = Host(), session = try NativeConditionAuthorSession(host: host), reader = Reader()
        let task = Task { try await session.readAuthoritative(using: reader) }; await waitForReader(reader); try edit(session)
        reader.continuation?.resume(returning: .init(requestedScope: host.scope, raw: host.raw, serverRevision: "8"))
        do { try await task.value; XCTFail("stale read accepted") } catch { }
        XCTAssertNil(session.authoritative); XCTAssertEqual(session.state, .editing); XCTAssertTrue(session.document.hasChanges)
    }
    func testRetireInvalidatesOutstandingCallbacksWithoutTouchingPendingJournal() async throws {
        let host = Host(), session = try NativeConditionAuthorSession(host: host), reader = Reader(), pending = host.pendingRequest
        let task = Task { try await session.readAuthoritative(using: reader) }; await waitForReader(reader); session.retire()
        reader.continuation?.resume(returning: .init(requestedScope: host.scope, raw: host.raw, serverRevision: "8"))
        do { try await task.value; XCTFail("retired read accepted") } catch { }
        XCTAssertNil(session.authoritative); XCTAssertEqual(host.pendingRequest, pending)
    }
}
