import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import QuestifyCore

/// Source-backed private-read fixture, not a grant or an installed publication profile.
@MainActor final class NativeAttributeAuthorPublishedReaderTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var data = Data(), status = 200, requests: [URLRequest] = []
        var afterRead: (() -> Void)?
        func send(_ request: URLRequest) async throws -> (Data,Int) {
            requests.append(request); afterRead?(); return (data,status)
        }
    }
    private final class Owner {
        var session: ProjectEditSession? = try? .init(accountID:7,epoch:1,storageNamespace:"fixture")
        var token = "synthetic-private-author-token"
    }
    private let digest = String(repeating:"a",count:64)
    private func source(version:Int = 6, sourceVersion:Int = 4, definitions:String = NativeAttributeAuthorTestFixtures.extendedRow) -> String {
        "{\"schemaVersion\":1,\"definitionVersion\":\(version),\"sourceConfigVersion\":\(sourceVersion),\"sha256\":\"\(digest)\",\"definitions\":[\(definitions)]}"
    }
    private func detail(graph:String?, currentVersion:Int = 8, publishedVersion:Int? = 6, topicID:Int = 88) throws -> Data {
        var topic:[String:ProjectEditJSON] = ["id":.number(Decimal(topicID)),"productType":.number(1),
            "updateTime":.string("source-8"),"configVersion":.number(Decimal(currentVersion))]
        if let graph { topic["publishedRouteGraphJson"] = .string(graph) }
        if let publishedVersion { topic["publishedConfigVersion"] = .number(Decimal(publishedVersion)) }
        return try JSONEncoder().encode(ProjectEditJSON.object(["code":.number(200),"data":.object([
            "topic":.object(topic),"editScope":.string("FULL"),"chapters":.array([]),"tickets":.array([])])]))
    }
    private func graph(_ attributes:String? = nil, marker:Int = 1) -> String {
        "{\"runtimeSnapshotVersion\":\(marker),\"dynamicAttributes\":\(attributes ?? source())}"
    }
    private func binding(owner:ProjectEditOwner = .personal, version:Int64 = 8) throws -> NativeAttributeAuthorBinding {
        try .init(server:"https://example.com",namespace:"fixture",accountID:7,epoch:1,authorizationRevision:"0:0",
            topicID:88,sourceConfigVersion:version,requestScope:owner.rawValue)
    }
    private func setup(owner:ProjectEditOwner = .personal) throws -> (NativeAttributeAuthorPublishedReader,ProjectEditHTTPService,Wire,Owner) {
        let wire = Wire(), current = Owner(); wire.data = try detail(graph:graph())
        let service = ProjectEditHTTPService(configuration:try .init(baseURL:URL(string:"https://example.com")!),transport:wire,
            owner:owner,currentCredentials:{current.session.flatMap {try? .init(session:$0,token:current.token)}})
        return (.init(service:service,currentSession:{current.session}),service,wire,current)
    }
    private func reject(_ body:() async throws -> Void,file:StaticString = #filePath,line:UInt = #line) async {
        do {try await body();XCTFail("unexpected accepted source",file:file,line:line)} catch {}
    }
    func testExistingPreflightStillUsesOneOriginalPrivateRead() async throws {
        let (_,service,wire,owner) = try setup()
        let result = try await service.preflight(topicID:88,session:XCTUnwrap(owner.session))
        XCTAssertEqual(result.snapshot?.topicID,88);XCTAssertEqual(wire.requests.count,1)
        XCTAssertEqual(wire.requests[0].url?.path,"/api/topic/edit-detail")
        XCTAssertEqual(wire.requests[0].httpMethod,"POST")
        XCTAssertEqual(service.authority,.readOnly)
    }
    func testCurrentInspectionCapturesActualOlderPublishedSourceWithoutClaimingCommit() async throws {
        let (reader,_,wire,_) = try setup()
        let inspected = try await reader.inspect(binding())
        XCTAssertTrue(inspected.binding.isLocked);XCTAssertEqual(inspected.binding.sourceConfigVersion,4)
        guard case .locked(let version,let sourceVersion,let hash) = inspected.binding.source else {return XCTFail("not locked")}
        XCTAssertEqual(version,6);XCTAssertEqual(sourceVersion,4);XCTAssertEqual(hash,digest)
        let draft = try NativeAttributeAuthorService.frozenDraft(binding:inspected.binding,source:inspected.source)
        XCTAssertEqual(draft.rows.map(\.key),["counter.temp"])
        XCTAssertEqual(wire.requests.count,1);XCTAssertEqual(wire.requests[0].url?.path,"/api/topic/edit-detail")
        // Result deliberately has no requestID/receipt/success flag and cannot settle a journal.
    }
    func testLockedReadRejectsNewPublicationRatherThanReturningLatest() async throws {
        let (reader,_,wire,_) = try setup()
        let captured = try await reader.inspect(binding())
        let lockedSource = try await reader.readLocked(captured.binding)
        XCTAssertEqual(lockedSource,captured.source)
        wire.data = try detail(graph:graph(source(version:7)),publishedVersion:7)
        await reject { _ = try await reader.readLocked(captured.binding) }
    }
    func testMarkerMissingVersionMismatchAndUnknownSourceAreNeverEmpty() async throws {
        let (reader,_,wire,_) = try setup()
        let cases:[Data] = [try detail(graph:nil),try detail(graph:graph(marker:0)),
            try detail(graph:graph(),publishedVersion:nil),try detail(graph:graph(),publishedVersion:7),
            try detail(graph:graph("null")),try detail(graph:graph(source(sourceVersion:9))),
            try detail(graph:graph(source().replacingOccurrences(of:"\"definitions\":[\(NativeAttributeAuthorTestFixtures.extendedRow)]",with:"\"definitions\":null")))]
        for data in cases {wire.data=data;await reject {_ = try await reader.inspect(binding())}}
    }
    func testInvalidIntegerSpellingDigestAndDefinitionSchemaFailClosed() async throws {
        let (reader,_,wire,_) = try setup()
        let original = String(decoding: try detail(graph:graph()), as: UTF8.self)
        let metadata = [original.replacingOccurrences(of:"\"publishedConfigVersion\":6",with:"\"publishedConfigVersion\":6.0"),
            original.replacingOccurrences(of:"\"configVersion\":8",with:"\"configVersion\":8e0")]
        for text in metadata { wire.data=Data(text.utf8); await reject {_ = try await reader.inspect(binding())} }
        wire.data=try detail(graph:graph().replacingOccurrences(of:"\"runtimeSnapshotVersion\":1",with:"\"runtimeSnapshotVersion\":1.0"))
        await reject {_ = try await reader.inspect(binding())}
        wire.data=try detail(graph:graph(source().replacingOccurrences(of:digest,with:"invalid")))
        await reject {_ = try await reader.inspect(binding())}
        wire.data=try detail(graph:graph(source().replacingOccurrences(of:"\"schemaVersion\":1",with:"\"schemaVersion\":2")))
        await reject {_ = try await reader.inspect(binding())}
    }
    func testLegitimateEmptyPublishedDefinitionsRemainAReadableEmptySnapshot() async throws {
        let (reader,_,wire,_) = try setup();wire.data=try detail(graph:graph(source(definitions:"")))
        let result=try await reader.inspect(binding())
        let draft=try NativeAttributeAuthorService.frozenDraft(binding:result.binding,source:result.source)
        XCTAssertTrue(draft.rows.isEmpty)
    }
    func testCurrentDraftVersionAndExactRequestedHashAreBound() async throws {
        let (reader,_,wire,_) = try setup()
        await reject {_ = try await reader.inspect(binding(version:7))}
        let captured=try await reader.inspect(binding())
        wire.data=try detail(graph:graph(source().replacingOccurrences(of:digest,with:String(repeating:"b",count:64))))
        await reject {_ = try await reader.readLocked(captured.binding)}
    }
    func testWrongOwnerServerTopicOrAuthRevisionCannotReusePrivateRead() async throws {
        let (reader,_,wire,_) = try setup(owner:.merchant)
        await reject {_ = try await reader.inspect(binding())}
        let current=try binding(owner:.merchant)
        let wrong=try NativeAttributeAuthorBinding(server:current.server,namespace:current.namespace,accountID:current.accountID,
            epoch:current.epoch,authorizationRevision:"1:0",topicID:88,sourceConfigVersion:8,requestScope:"MERCHANT")
        let count=wire.requests.count;await reject {_ = try await reader.inspect(wrong)};XCTAssertEqual(wire.requests.count,count)
        wire.data=try detail(graph:graph(),topicID:89)
        await reject {_ = try await reader.inspect(current)}
        wire.data=try detail(graph:graph())
        let otherServer=try NativeAttributeAuthorBinding(server:"https://other.example.com",namespace:current.namespace,accountID:current.accountID,
            epoch:current.epoch,authorizationRevision:current.authorizationRevision,topicID:88,sourceConfigVersion:8,requestScope:"MERCHANT")
        await reject {_ = try await reader.inspect(otherServer)}
    }
    func testLateRevocationOrUnauthorizedReadCannotReturnFrozenSource() async throws {
        let (reader,_,wire,owner)=try setup()
        wire.afterRead={owner.session=nil}
        await reject {_ = try await reader.inspect(binding())}
        owner.session=try .init(accountID:7,epoch:1,storageNamespace:"fixture");wire.afterRead=nil
        wire.status=401;await reject {_ = try await reader.inspect(binding())}
        wire.status=200;wire.data=Data(#"{"code":500,"msg":"unknown original read"}"#.utf8)
        await reject {_ = try await reader.inspect(binding())}
    }
}
