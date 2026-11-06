import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import QuestifyCore

@MainActor final class NativeAttributeAuthorConditionCatalogReaderTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var data = Data(), status = 200
        var requests: [URLRequest] = []
        var afterRead: (() -> Void)?
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request); afterRead?(); return (data, status)
        }
    }
    private final class Owner {
        var session: ProjectEditSession? = try? .init(accountID: 7, epoch: 1, storageNamespace: "fixture")
        var source: NativeAttributeAuthorConditionCatalogSource?
    }
    private func setup() throws -> (NativeAttributeAuthorConditionCatalogReader, Wire, Owner, NativeConditionAuthorScope) {
        let owner = Owner(), wire = Wire(), binding = try binding()
        let scope = NativeConditionAuthorScope(accountID: 7, namespace: "fixture", epoch: 1, authorizationRevision: "0:0",
            documentIdentity: try ProjectEditDraftIdentity(topicID: 88).bucket, sourceRevision: "source-4:0", incarnation: UUID())
        owner.source = .init(binding: binding, scope: scope, baseRevision: "source-4")
        wire.data = try response()
        let service = ProjectEditHTTPService(configuration: try .init(baseURL: URL(string: "https://fixture.test")!),
            transport: wire, owner: .personal, currentCredentials: {
                owner.session.flatMap { try? .init(session: $0, token: "synthetic-catalog-test-token") }
            })
        return (.init(service: service, currentSession: { owner.session }, currentSource: { owner.source }), wire, owner, scope)
    }
    private func reject(_ operation: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await operation(); XCTFail("unexpected catalog", file: file, line: line) } catch {}
    }
    private func binding() throws -> NativeAttributeAuthorBinding {
        try .init(server: "https://fixture.test", namespace: "fixture", accountID: 7, epoch: 1,
                  authorizationRevision: "0:0", topicID: 88, sourceConfigVersion: 4, requestScope: "")
    }
    private func response(theme: ProjectEditJSON? = .null, graph: ProjectEditJSON? = .null,
                          nodes: ProjectEditJSON = .array([]), version: ProjectEditJSON = .number(4)) throws -> Data {
        var topic: [String: ProjectEditJSON] = ["id": .number(88), "configVersion": version,
            "productType": .number(1), "updateTime": .string("source-4")]
        topic["routeGraphJson"] = graph
        var body: [String: ProjectEditJSON] = ["topic": .object(topic), "chapters": .array([.object(["cmsTopicNodeList": nodes])]),
            "editScope": .string("FULL"), "tickets": .array([])]
        body["themeRuntimeConfig"] = theme
        return try NativeAttributeAuthorWire.encode(.object(["code": .number(200), "data": .object(body)]))
    }
    private func project(_ data: Data) throws -> NativeConditionAuthorCatalog {
        try NativeAttributeAuthorConditionCatalogReader.project(data, binding: binding())
    }
    func testReadsActualPrivateTopLevelThemeNodesAndEdges() throws {
        let theme = #"{"schemaVersion":1,"items":[{"id":"key","kind":"ITEM","name":"Key"},{"id":"badge","kind":"MEDAL","name":"Badge"}]}"#
        let graph = #"{"edges":[{"id":"edge-a"}],"fallbacks":[{"fromNodeId":11}]}"#
        let nodes: ProjectEditJSON = .array([.object(["id": .number(11), "topicId": .number(88), "name": .string("Station")])])
        let value = try project(response(theme: .string(theme), graph: .string(graph), nodes: nodes))
        XCTAssertEqual(value.nodes.map(\.id), ["11"]); XCTAssertEqual(value.nodes.map(\.label), ["Station"])
        XCTAssertEqual(value.items.map(\.id), ["key"]); XCTAssertEqual(value.medals.map(\.id), ["badge"])
        XCTAssertEqual(value.edges.map(\.id), ["edge-a", "fallback-11"])
        XCTAssertNil(value.rpg); XCTAssertTrue(value.triggers.isEmpty); XCTAssertTrue(value.outcomes.isEmpty)
    }
    func testExplicitOriginalEmptySourcesRemainEmpty() throws {
        for empty in [ProjectEditJSON.null, .string(""), .string(" \n\t")] {
            let value = try project(response(theme: empty, graph: empty))
            XCTAssertTrue(value.items.isEmpty); XCTAssertTrue(value.edges.isEmpty); XCTAssertTrue(value.nodes.isEmpty)
        }
        XCTAssertTrue(try project(response(theme: .string(#"{"schemaVersion":1}"#))).items.isEmpty)
    }
    func testMissingTopLevelSourceCannotBeCertifiedAsEmpty() throws {
        XCTAssertThrowsError(try project(response(theme: nil)))
        XCTAssertThrowsError(try project(response(graph: nil)))
    }
    func testWrongVersionOrForeignNodeCannotEnterCatalog() throws {
        XCTAssertThrowsError(try project(response(version: .number(5))))
        XCTAssertThrowsError(try project(response(nodes: .array([.object(["id": .number(11), "topicId": .number(99)])]))))
    }
    func testUnknownItemKindOrMalformedSourceRemainsAnError() throws {
        for theme in [#"{"schemaVersion":2,"items":[]}"#, #"{"schemaVersion":1,"items":{}}"#,
                      #"{"schemaVersion":1,"items":[{"id":"key","kind":"UNKNOWN"}]}"#,
                      #"{"schemaVersion":1,"items":[{"id":"legacy_badge","kind":"MEDAL"}]}"#] {
            XCTAssertThrowsError(try project(response(theme: .string(theme))))
        }
        XCTAssertThrowsError(try project(response(graph: .string(#"{"edges":{}}"#))))
    }
    func testDuplicateNodeItemOrEdgeIdentitiesAreNotSilentlyCollapsed() throws {
        let node: ProjectEditJSON = .object(["id": .number(11)])
        XCTAssertThrowsError(try project(response(nodes: .array([node, node]))))
        XCTAssertThrowsError(try project(response(theme: .string(#"{"schemaVersion":1,"items":[{"id":"key","kind":"ITEM"},{"id":"key","kind":"ITEM"}]}"#))))
        XCTAssertThrowsError(try project(response(graph: .string(#"{"edges":[{"id":"a"},{"id":"a"}]}"#))))
    }
    func testFractionalIntegerSpellingDoesNotCreateIdentity() throws {
        let data = try response(nodes: .array([.object(["id": .number(11)])]))
        let malformed = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"id\":11", with: "\"id\":11.0")
        XCTAssertThrowsError(try project(Data(malformed.utf8)))
        XCTAssertThrowsError(try project(response(theme: .string(#"{"schemaVersion":1.0,"items":[]}"#))))
        XCTAssertThrowsError(try project(response(graph: .string(#"{"fallbacks":[{"fromNodeId":11.0}]}"#))))
    }
    func testRefreshUsesOnlyOriginalPrivateReaderAndCachesExactScope() async throws {
        let (reader, wire, _, scope) = try setup()
        XCTAssertNil(reader.attributeRuleCatalog(for: scope))
        try await reader.refresh()
        XCTAssertNotNil(reader.attributeRuleCatalog(for: scope))
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/topic/edit-detail")
        XCTAssertEqual(wire.requests[0].httpMethod, "POST")
    }
    func testLateRetirementCannotPopulateCatalog() async throws {
        let (reader, wire, owner, scope) = try setup()
        wire.afterRead = { owner.source = nil }
        await reject { try await reader.refresh() }
        XCTAssertNil(reader.attributeRuleCatalog(for: scope))
    }
    func testFailedRefreshClearsPriorCatalogInsteadOfLeavingStaleChoices() async throws {
        let (reader, wire, _, scope) = try setup()
        try await reader.refresh(); XCTAssertNotNil(reader.attributeRuleCatalog(for: scope))
        wire.status = 401
        await reject { try await reader.refresh() }
        XCTAssertNil(reader.attributeRuleCatalog(for: scope))
    }
    func testUnchangedVersionButDifferentOriginalRevisionIsRejected() async throws {
        let (reader, wire, _, scope) = try setup()
        wire.data = Data(String(decoding: wire.data, as: UTF8.self).replacingOccurrences(of: "source-4", with: "changed-source-4").utf8)
        await reject { try await reader.refresh() }
        XCTAssertNil(reader.attributeRuleCatalog(for: scope))
    }
    func testRevokedSessionCannotIssueReadOrReuseExistingCache() async throws {
        let (reader, wire, owner, scope) = try setup()
        try await reader.refresh()
        owner.session = nil
        XCTAssertNil(reader.attributeRuleCatalog(for: scope))
        await reject { try await reader.refresh() }
        XCTAssertEqual(wire.requests.count, 1)
    }

}
