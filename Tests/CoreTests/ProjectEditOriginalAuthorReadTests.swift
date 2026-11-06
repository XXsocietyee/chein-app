import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import QuestifyCore

@MainActor final class ProjectEditOriginalAuthorReadTests: XCTestCase {
    private final class Owner {
        var session: ProjectEditSession? = try? .init(accountID: 901, epoch: 1, storageNamespace: "author-read-test")
    }
    private final class Wire: HTTPTransport {
        var data: Data, status = 200, requests: [URLRequest] = []
        var afterRead: (() -> Void)?
        init(_ data: Data) { self.data = data }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request); afterRead?(); return (data, status)
        }
    }
    private func detail(scope: ProjectEditScope = .full, member: Int = 901, club: Int = 0) throws -> Data {
        var root = try JSONDecoder().decode([String: ProjectEditJSON].self,
            from: ProjectEditRemoteFixtures.detail(product: .freeExplore, scope: scope))
        var body = try XCTUnwrap(root["data"]?.object), topic = try XCTUnwrap(body["topic"]?.object)
        topic["memberId"] = .number(Decimal(member)); topic["configVersion"] = .number(3)
        topic["clubId"] = .number(Decimal(club)); body["topic"] = .object(topic); root["data"] = .object(body)
        return try JSONEncoder().encode(root)
    }
    private func authority(_ kind: H5AuthorSelfUseTargetKind = .merchantTopic) throws -> H5AuthorSelfUseEditorAuthority {
        let request = "00000000-0000-4000-8000-000000000001", application = "00000000-0000-4000-8000-000000000002"
        let content = String(repeating: "a", count: 64)
        func binding(_ hash: String) -> H5AuthorSelfUseBinding {
            .init(authorizationSource: "AUTHOR_SELF_USE", selfUseRequestId: request, releaseApplicationRequestId: application,
                moduleId: "test-module", releaseId: "test-release", contentHash: content, authorizationHash: hash,
                authorId: 901, sourceTemplateId: 73, organizationId: 31, topicId: 71, targetKind: kind, state: .active,
                currentAvailable: true, runtimeAuthorization: "REQUIRES_ORIGINAL_PUBLISHED_NODE_AND_PLAYER_RUN")
        }
        let original = binding(try H5AuthorSelfUseWire.authorizationHash(binding(String(repeating: "0", count: 64))))
        let body = "{\"requestId\":\"\(request)\",\"releaseApplicationRequestId\":\"\(application)\",\"releaseId\":\"test-release\",\"contentHash\":\"\(content)\",\"targetKind\":\"\(kind.rawValue)\",\"organizationId\":31,\"topicId\":71,\"expectedTopicConfigVersion\":3,\"previousRequestId\":null}"
        let command = H5AuthorSelfUseCommand.bind(try JSONDecoder().decode(H5AuthorSelfUseBindCommand.self, from: Data(body.utf8)))
        let receipt = H5AuthorSelfUseReceipt(source: "h5-author-self-use-request-v1", actorId: "901", requestId: request,
            inputHash: try command.inputHash, receiptStatus: .bound, operation: .bind, command: command, binding: original,
            reasonCode: nil, grantsPlayerAccess: false, publishesTopic: false, materializesTemplate: false)
        let release = H5AuthorSelfUseRelease(source: "h5-author-self-use-release-v1", releaseApplicationRequestId: application,
            moduleId: "test-module", releaseId: "test-release", contentHash: content, authorizationSource: "AUTHOR_SELF_USE",
            authorId: 901, sourceTemplateId: 73, grantsPlayerAccess: false)
        return try .init(release: release, binding: original, receipt: receipt, actor: 901)
    }
    private func service(_ wire: Wire, _ owner: Owner, scope: ProjectEditOwner = .personal,
                         authority: H5AuthorSelfUseEditorAuthority? = nil,
                         check: ((H5AuthorSelfUseEditorAuthority) async throws -> Void)? = nil) throws -> ProjectEditHTTPService {
        try .init(configuration: .init(baseURL: URL(string: "https://example.com")!), transport: wire, owner: scope,
            selfUseEditorAuthority: authority, selfUseAuthorityCheck: check,
            currentCredentials: { owner.session.flatMap { try? .init(session: $0, token: "synthetic-author-read-token") } })
    }
    private func reject(_ operation: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await operation(); XCTFail("Unexpected private author read", file: file, line: line) } catch {}
    }
    func testDefaultNilAuthorityReturnsOnlyTheExactOriginalPrivateRead() async throws {
        let owner = Owner(), wire = Wire(try detail()), session = try XCTUnwrap(owner.session)
        let service = try service(wire, owner), result = try await service.readOriginalAuthorDetail(topicID: 71, session: session)
        XCTAssertEqual(result.raw, wire.data); XCTAssertEqual(result.session, session)
        XCTAssertEqual(result.owner, .personal); XCTAssertEqual(result.snapshot.topicID, 71)
        XCTAssertEqual(result.server.absoluteString, "https://example.com"); XCTAssertNil(service.selfUseEditorAuthority)
        XCTAssertEqual(service.authority, .readOnly); XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/topic/edit-detail"); XCTAssertEqual(wire.requests[0].httpMethod, "POST")
    }
    func testOriginalAuthorityIsRevalidatedBeforeAndAfterReadIncludingPreflight() async throws {
        let owner = Owner(), wire = Wire(try detail()), session = try XCTUnwrap(owner.session), expected = try authority()
        var checks = 0
        let service = try service(wire, owner, authority: expected, check: { value in XCTAssertEqual(value, expected); checks += 1 })
        let result = try await service.preflight(topicID: 71, session: session)
        XCTAssertEqual(result.snapshot?.scope, .full); XCTAssertEqual(checks, 2); XCTAssertEqual(wire.requests.count, 1)
    }
    func testMissingValidatorWrongOwnerTopicAndActorNeverDispatch() async throws {
        let expected = try authority()
        for (scope, topic, actor, validator) in [(ProjectEditOwner.personal, 71, 901, false), (.merchant, 71, 901, true),
                                                (.personal, 72, 901, true), (.personal, 71, 902, true)] {
            let owner = Owner(), wire = Wire(try detail())
            owner.session = try .init(accountID: actor, epoch: 1, storageNamespace: "author-read-test")
            let session = try XCTUnwrap(owner.session)
            let check: ((H5AuthorSelfUseEditorAuthority) async throws -> Void)? = validator ? { _ in } : nil
            let service = try service(wire, owner, scope: scope, authority: expected, check: check)
            await reject { _ = try await service.readOriginalAuthorDetail(topicID: topic, session: session) }
            XCTAssertTrue(wire.requests.isEmpty)
        }
    }
    func testOriginalOwnerFullScopeAndOrganizationCannotBeSubstituted() async throws {
        for kind in H5AuthorSelfUseTargetKind.allCases {
            let expected = try authority(kind), club = kind == .clubTopic ? 31 : 0
            for data in [try detail(scope: .sellingFrozen, club: club), try detail(member: 902, club: club),
                         try detail(club: kind == .clubTopic ? 32 : 31)] {
                let owner = Owner(), wire = Wire(data), session = try XCTUnwrap(owner.session)
                let service = try service(wire, owner, authority: expected, check: { _ in })
                await reject { _ = try await service.readOriginalAuthorDetail(topicID: 71, session: session) }
                XCTAssertEqual(wire.requests.count, 1)
            }
        }
    }
    func testRevocationAfterReadCannotReturnPrivateDetail() async throws {
        let owner = Owner(), wire = Wire(try detail()), session = try XCTUnwrap(owner.session)
        var checks = 0
        let service = try service(wire, owner, authority: authority(), check: { _ in
            checks += 1; if checks == 2 { throw H5AuthorSelfUseIssue.forbidden }
        })
        await reject { _ = try await service.readOriginalAuthorDetail(topicID: 71, session: session) }
        XCTAssertEqual(checks, 2); XCTAssertEqual(wire.requests.count, 1)
    }
    func testSessionChangeDuringAuthorityOrTransportCannotReturnPrivateDetail() async throws {
        for duringAuthority in [true, false] {
            let owner = Owner(), wire = Wire(try detail()), session = try XCTUnwrap(owner.session)
            if !duringAuthority { wire.afterRead = { owner.session = nil } }
            let service = try service(wire, owner, authority: authority(), check: { _ in
                if duringAuthority { owner.session = nil }
            })
            await reject { _ = try await service.readOriginalAuthorDetail(topicID: 71, session: session) }
            XCTAssertEqual(wire.requests.count, duringAuthority ? 0 : 1)
        }
    }
    func testUnauthorizedMalformedAndInvalidTopicReadsNeverRetry() async throws {
        for status in [401, 500] {
            let owner = Owner(), wire = Wire(try detail()), session = try XCTUnwrap(owner.session)
            wire.status = status
            let service = try service(wire, owner)
            await reject { _ = try await service.readOriginalAuthorDetail(topicID: 71, session: session) }
            XCTAssertEqual(wire.requests.count, 1)
        }
        let owner = Owner(), wire = Wire(Data("{}".utf8)), session = try XCTUnwrap(owner.session), service = try service(wire, owner)
        await reject { _ = try await service.readOriginalAuthorDetail(topicID: 0, session: session) }
        XCTAssertTrue(wire.requests.isEmpty)
        await reject { _ = try await service.readOriginalAuthorDetail(topicID: 71, session: session) }
        XCTAssertEqual(wire.requests.count, 1)
    }
}
