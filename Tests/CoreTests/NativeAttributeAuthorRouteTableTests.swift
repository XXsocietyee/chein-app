import Foundation
import XCTest
@testable import QuestifyCore

/// FP-E5. Pins the attribute-author method/path table and its dormancy. The backend controller
/// (`CanonicalEquipmentDynamicAuthorController`) maps only `POST /api/topic/attribute-author` and
/// `GET /api/topic/attribute-author/request`, and only when `equipment.dynamic-author.http-enabled=true`
/// (default false). The GET definitions/references and validate routes have no backend mapping (AN-1), so no
/// request may reach the wire unless the composition supplies an exact approval and capability.
@MainActor final class NativeAttributeAuthorRouteTableTests: XCTestCase {
    private func binding() throws -> NativeAttributeAuthorBinding {
        try .init(server: "https://example.test/author", namespace: "route-table", accountID: 7, epoch: 1,
                  authorizationRevision: "rev", topicID: 88, sourceConfigVersion: 4, requestScope: "")
    }
    func testMethodAndPathTableMatchesTheReviewedRoutes() throws {
        let b = try binding(), key = UUID()
        let list = NativeAttributeAuthorRequest.definitionsList(b, key: key)
        XCTAssertEqual(list.method, .get); XCTAssertEqual(list.path, "api/topic/attribute-author")
        XCTAssertEqual(try NativeAttributeAuthorHostEndpoint(request: list), .definitions)
        let inspect = NativeAttributeAuthorRequest.definitionsList(b, key: key, inspect: true)
        XCTAssertEqual(try NativeAttributeAuthorHostEndpoint(request: inspect), .inspectCurrent)
        let references = try NativeAttributeAuthorRequest.definitionReferences("counter.temp", binding: b, requestKey: key)
        XCTAssertEqual(references.method, .get); XCTAssertEqual(references.path, "api/topic/attribute-author/references")
        XCTAssertEqual(try NativeAttributeAuthorHostEndpoint(request: references), .references)
        let delete = try NativeAttributeAuthorRequest.definitionDelete("counter.temp", binding: b, requestKey: key)
        XCTAssertEqual(delete.method, .delete); XCTAssertEqual(try NativeAttributeAuthorHostEndpoint(request: delete), .delete)
    }
    func testNothingReachesTheWireWithoutExactApprovalAndCapability() async throws {
        let b = try binding(), key = UUID()
        var dispatched = 0
        let credentials = try NativeAttributeAuthorHostCredentials(binding: b, token: "synthetic-token")
        let transport = NativeAttributeAuthorHostTransport(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/author")!),
            credentials: { credentials }, dispatch: { _, _ in dispatched += 1; return (Data(), 200) })
        let requests = [NativeAttributeAuthorRequest.definitionsList(b, key: key),
                        NativeAttributeAuthorRequest.definitionsList(b, key: key, inspect: true),
                        try NativeAttributeAuthorRequest.definitionReferences("counter.temp", binding: b, requestKey: key),
                        try NativeAttributeAuthorRequest.definitionDelete("counter.temp", binding: b, requestKey: key)]
        for request in requests {
            do { _ = try await transport.send(request, finalCheck: {}); XCTFail("must be dormant: \(request.path)") }
            catch { XCTAssertEqual(error as? NativeAttributeAuthorError, .unavailable("original exact author method/path approval")) }
        }
        XCTAssertEqual(dispatched, 0)
    }
}
