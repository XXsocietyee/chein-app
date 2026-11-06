import Foundation
import XCTest
#if canImport(Questify)
@testable import Questify
#endif

/// SOURCE ONLY until run in the original App target. Replies use the real private
/// edit-detail decoder; no replacement parser, grant, owner field or account field is invented.
@MainActor final class NativeConditionAuthorReadbackIdentityTests: XCTestCase {
    private typealias Adapter = NativeConditionAuthorProjectReadbackAdapter
    private static let graph = #"{ "schemaVersion":1,"routeExpressionVersion":2,"startNodeId":20,"terminalNodeIds":[21],"variables":{},"edges":[],"future":{"n":9007199254740993,"text":"keep"} }"#
    private final class Service: ProjectEditServing {
        var authority: ProjectEditServiceAuthority { .readOnly }
        var owner: ProjectEditOwner = .personal
        var product: Int? = ProjectEditProduct.city.rawValue
        var responseTopicID = 20
        var revision: String? = "8"
        var graph: String? = NativeConditionAuthorReadbackIdentityTests.graph
        var requests: [(topicID: Int?, session: ProjectEditSession)] = []
        var writes = 0
        var receiptReads = 0
        var hold = false
        var continuation: CheckedContinuation<Void, Never>?

        /// Exactly the required normal response envelope consumed by ProjectEditContract.
        /// Owner is supplied by the original service binding, not manufactured in the body.
        func response() throws -> Data {
            var topic: [String: ProjectEditJSON] = ["id": .number(Decimal(responseTopicID))]
            if let product { topic["productType"] = .number(Decimal(product)) }
            if let revision { topic["updateTime"] = .string(revision) }
            if let graph { topic["routeGraphJson"] = .string(graph) }
            return try JSONEncoder().encode(ProjectEditJSON.object(["code": .number(200), "data": .object([
                "topic": .object(topic), "editScope": .string("FULL"), "chapters": .array([]), "tickets": .array([])
            ])]))
        }
        func preflight(topicID: Int?, session: ProjectEditSession) async throws -> ProjectEditPreflight {
            requests.append((topicID, session))
            if hold { await withCheckedContinuation { continuation = $0 } }
            guard let topicID else { throw ProjectEditError.invalidContract }
            let snapshot = try ProjectEditContract.decodeEditDetail(response(), expectedTopicID: topicID, owner: owner)
            return .init(capability: .init(canProPublish: false, remaining: nil), snapshot: snapshot)
        }
        func submit(_ operation: ProjectEditPending, session: ProjectEditSession) async -> ProjectEditWriteOutcome { writes += 1; return .notSent }
        func terminalReceipt(operationID: UUID, session: ProjectEditSession) async throws -> ProjectEditWriteOutcome? { receiptReads += 1; return nil }
    }
    private final class SourceBox {
        var source: Adapter.Source?
        init(_ source: Adapter.Source?) { self.source = source }
    }
    private final class ReadOnlyHost: NativeConditionAuthorDraftHosting {
        let scope: NativeConditionAuthorScope
        let raw: String
        var writes = 0
        var pending = Data("original-UNKNOWN-request:unchanged".utf8)
        init(scope: NativeConditionAuthorScope, raw: String) { self.scope = scope; self.raw = raw }
        func capture() -> NativeConditionAuthorCapture? {
            .init(scope: scope, raw: raw, surface: .routeGraph,
                  catalog: .init(nodes: [], items: [], medals: [], triggers: [], outcomes: []), attributes: nil, canEdit: false)
        }
        func persistOriginalDraft(_ raw: String, replacing expected: NativeConditionAuthorCapture) throws -> NativeConditionAuthorCapture {
            writes += 1; throw NativeConditionAuthorError.persistenceFailed
        }
    }
    private func scope(namespace: String = "app", identity: String = "topic:20") -> NativeConditionAuthorScope {
        .init(accountID: 8, namespace: namespace, epoch: 1, authorizationRevision: "0:0",
              documentIdentity: identity, sourceRevision: "7:0", incarnation: UUID())
    }
    private func source(_ scope: NativeConditionAuthorScope, account: Int = 8, namespace: String = "app",
                        epoch: UInt64 = 1, viewer: UInt64 = 0, configuration: UInt64 = 0, topic: Int = 20,
                        owner: ProjectEditOwner = .personal, product: ProjectEditProduct = .city) throws -> Adapter.Source {
        let session = try ProjectEditSession(accountID: account, epoch: epoch, storageNamespace: namespace,
                                             viewerRevision: viewer, configurationRevision: configuration)
        return .init(scope: scope, session: session, topicID: topic, owner: owner, product: product)
    }
    private func reject(_ reader: Adapter, scope: NativeConditionAuthorScope, file: StaticString = #filePath, line: UInt = #line) async {
        do { _ = try await reader.readOriginalAuthorSource(for: scope); XCTFail("Misbound original author reply accepted", file: file, line: line) } catch { }
    }
    private func waitForRequest(_ service: Service) async {
        for _ in 0..<100 where service.continuation == nil { await Task.yield() }
        XCTAssertNotNil(service.continuation)
    }

    func testAuditedAccountMismatchRejectsBeforeOriginalRead() async throws {
        let expected = scope(), service = Service(), wrong = try source(expected, account: 9)
        await reject(.init(service: service, current: { wrong }), scope: expected)
        XCTAssertEqual(service.requests.count, 0)
    }
    func testAuditedTopicMismatchRejectsBeforeOriginalRead() async throws {
        let expected = scope(), service = Service(), wrong = try source(expected, topic: 21)
        service.responseTopicID = 21
        await reject(.init(service: service, current: { wrong }), scope: expected)
        XCTAssertEqual(service.requests.count, 0)
    }
    func testAuditedOwnerMismatchRejectsNormalDecodedReply() async throws {
        let expected = scope(), service = Service(), original = try source(expected)
        service.owner = .merchant
        await reject(.init(service: service, current: { original }), scope: expected)
        XCTAssertEqual(service.requests.count, 1)
    }
    func testAuditedProductMismatchRejectsNormalDecodedReply() async throws {
        let expected = scope(), service = Service(), original = try source(expected)
        service.product = ProjectEditProduct.freeExplore.rawValue
        await reject(.init(service: service, current: { original }), scope: expected)
        XCTAssertEqual(service.requests.count, 1)
    }
    func testEverySessionDimensionIsCrossBoundBeforeDispatch() async throws {
        let expected = scope()
        for wrong in [try source(expected, namespace: "other"), try source(expected, epoch: 2),
                      try source(expected, viewer: 1), try source(expected, configuration: 1)] {
            let service = Service()
            await reject(.init(service: service, current: { wrong }), scope: expected)
            XCTAssertEqual(service.requests.count, 0)
        }
    }
    func testNamespaceMustMatchExactUTF8DespiteSwiftCanonicalEquality() async throws {
        let expected = scope(namespace: "é"), service = Service(), wrong = try source(expected, namespace: "e\u{301}")
        await reject(.init(service: service, current: { wrong }), scope: expected)
        XCTAssertEqual(service.requests.count, 0)
    }
    func testNewDraftIdentityCannotBeRelabeledAsExistingTopicRead() async throws {
        let expected = scope(identity: "new:" + UUID().uuidString), service = Service(), wrong = try source(expected)
        await reject(.init(service: service, current: { wrong }), scope: expected)
        XCTAssertEqual(service.requests.count, 0)
    }
    func testMissingOriginalSourceDoesNotFillDefaultsOrRead() async {
        let expected = scope(), service = Service()
        await reject(.init(service: service, current: { nil }), scope: expected)
        XCTAssertEqual(service.requests.count, 0)
    }
    func testNormalRepliesForBothOriginalOwnersAndProductsAreAccepted() async throws {
        for owner in [ProjectEditOwner.personal, .merchant] {
            for product in [ProjectEditProduct.city, .freeExplore] {
                let expected = scope(), service = Service(), original = try source(expected, owner: owner, product: product)
                service.owner = owner; service.product = product.rawValue
                let decoded = try ProjectEditContract.decodeEditDetail(service.response(), expectedTopicID: 20, owner: owner)
                XCTAssertEqual(decoded.draft.owner, owner); XCTAssertEqual(decoded.draft.product, product)
                let value = try await Adapter(service: service, current: { original }).readOriginalAuthorSource(for: expected)
                XCTAssertEqual(value.requestedScope, expected); XCTAssertEqual(value.serverRevision, "8")
                XCTAssertEqual(Data(value.raw.utf8), Data(Self.graph.utf8))
                XCTAssertEqual(service.requests.count, 1); XCTAssertEqual(service.requests.first?.topicID, 20)
                XCTAssertEqual(service.requests.first?.session, original.session)
                XCTAssertEqual(service.writes, 0); XCTAssertEqual(service.receiptReads, 0)
            }
        }
    }
    func testMissingProductGraphOrRevisionDoesNotUseLocalFallbacks() async throws {
        for missing in ["product", "graph", "revision"] {
            let expected = scope(), service = Service(), original = try source(expected)
            if missing == "product" { service.product = nil }
            if missing == "graph" { service.graph = nil }
            if missing == "revision" { service.revision = nil }
            await reject(.init(service: service, current: { original }), scope: expected)
            XCTAssertEqual(service.requests.count, 1)
        }
    }
    func testOwnerOrProductChangeWhileAwaitingReplyRetiresResult() async throws {
        for dimension in ["owner", "product"] {
            let expected = scope(), service = Service(), original = try source(expected), box = SourceBox(original)
            service.hold = true
            let reader = Adapter(service: service, current: { box.source })
            let task = Task { try await reader.readOriginalAuthorSource(for: expected) }
            await waitForRequest(service)
            box.source = try source(expected, owner: dimension == "owner" ? .merchant : .personal,
                                    product: dimension == "product" ? .freeExplore : .city)
            service.continuation?.resume()
            do { _ = try await task.value; XCTFail("Retired owner/product result accepted") } catch { }
            XCTAssertEqual(service.requests.count, 1)
        }
    }
    func testOriginalVisitDisappearingWhileAwaitingReplyRejects() async throws {
        let expected = scope(), service = Service(), box = SourceBox(try source(expected))
        service.hold = true
        let reader = Adapter(service: service, current: { box.source })
        let task = Task { try await reader.readOriginalAuthorSource(for: expected) }; await waitForRequest(service)
        box.source = nil; service.continuation?.resume()
        do { _ = try await task.value; XCTFail("Retired editor reply accepted") } catch { }
    }
    func testPostAwaitNamespaceCrossCheckIsExactToo() async throws {
        let expected = scope(namespace: "é"), service = Service(), box = SourceBox(try source(expected, namespace: "é"))
        service.hold = true
        let reader = Adapter(service: service, current: { box.source })
        let task = Task { try await reader.readOriginalAuthorSource(for: expected) }; await waitForRequest(service)
        box.source = try source(expected, namespace: "e\u{301}"); service.continuation?.resume()
        do { _ = try await task.value; XCTFail("Different deployment bytes accepted") } catch { }
    }
    func testRejectedReadDoesNotChangeLegacyUnknownDraftOrPendingRequest() async throws {
        let expected = scope(), service = Service(), original = try source(expected)
        let legacy = " \n{\"schemaVersion\":1,\"future\":{\"n\":9007199254740993}}\n "
        let host = ReadOnlyHost(scope: expected, raw: legacy), session = try NativeConditionAuthorSession(host: host)
        let pending = host.pending; service.owner = .merchant
        do { try await session.readAuthoritative(using: Adapter(service: service, current: { original })); XCTFail("Misbound response accepted") } catch { }
        XCTAssertEqual(session.state, .failed); XCTAssertNil(session.authoritative)
        XCTAssertEqual(Data(session.document.original.utf8), Data(legacy.utf8))
        XCTAssertEqual(try session.document.serialized(), legacy)
        XCTAssertEqual(host.pending, pending); XCTAssertEqual(host.writes, 0)
        XCTAssertEqual(service.writes, 0); XCTAssertEqual(service.receiptReads, 0)
    }
    func testCorrectLegacyUnknownReadbackIsPreservedWithoutSavingOrUpgrading() async throws {
        let expected = scope(), service = Service(), original = try source(expected)
        let legacy = " \n{\"schemaVersion\":1,\"future\":{\"n\":9007199254740993}}\n "
        let host = ReadOnlyHost(scope: expected, raw: legacy), session = try NativeConditionAuthorSession(host: host)
        let pending = host.pending; service.graph = legacy
        try await session.readAuthoritative(using: Adapter(service: service, current: { original }))
        XCTAssertEqual(session.state, .authoritative("8")); XCTAssertEqual(session.authoritative?.original, legacy)
        XCTAssertFalse(try XCTUnwrap(session.authoritative).isExplicitV2)
        XCTAssertEqual(try session.document.serialized(), legacy); XCTAssertEqual(host.pending, pending)
        XCTAssertEqual(host.writes, 0); XCTAssertEqual(service.writes, 0); XCTAssertEqual(service.receiptReads, 0)
    }
}
