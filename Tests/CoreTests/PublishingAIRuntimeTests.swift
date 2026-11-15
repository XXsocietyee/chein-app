import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor final class PublishingAIRuntimeTests: XCTestCase {
    private let base = URL(string: "https://example.com/scoped/")!
    private let prepareKey = "11111111-1111-4111-8111-111111111111"
    private let serverRequestID = "td2_0123456789abcdef0123456789abcdef"
    private func request(_ fields: [String: ProjectEditJSON], path: String = "api/ai/theme/draft/prepare") throws -> URLRequest {
        try OperationAdapterHTTP.json(configuration: APIConfiguration(baseURL: base), path: path, body: JSONEncoder().encode(fields), token: "synthetic")
    }
    func testFeatureCatalogKeepsAISeparateFromPublishingWrites() throws {
        let prepare = try BusinessRuntimeRoute.post("api/ai/theme/draft/prepare")
        let execute = try BusinessRuntimeRoute.post("api/ai/theme/draft/execute")
        XCTAssertTrue(BusinessRuntimeFeature.publishingAITheme.accepts(prepare))
        XCTAssertTrue(BusinessRuntimeFeature.publishingAITheme.accepts(execute))
        XCTAssertFalse(BusinessRuntimeFeature.publishingWrite.accepts(prepare))
        XCTAssertFalse(BusinessRuntimeFeature.publishingAIClub.accepts(prepare))
        XCTAssertFalse(BusinessRuntimeFeature.publishingAITheme.accepts(try .init(method: "GET", path: prepare.path)))
    }
    func testExactThemeBodyRejectsMissingModeOrExtraFields() throws {
        let fields: [String: ProjectEditJSON] = ["prepareKey": .string(prepareKey), "idea": .string("Synthetic route"), "productType": .number(2)]
        XCTAssertTrue(PublishingAIRuntimeTransport.validates(try request(fields), feature: .publishingAITheme, baseURL: base))
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(try request(["prepareKey": .string(prepareKey), "idea": .string("Walk")]), feature: .publishingAITheme, baseURL: base))
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(try request(["idea": .string("Walk"), "productType": .number(2)]), feature: .publishingAITheme, baseURL: base))
        var extra = fields; extra["ownerId"] = .number(1)
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(try request(extra), feature: .publishingAITheme, baseURL: base))
        extra = fields; extra["productType"] = .number(9)
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(try request(extra), feature: .publishingAITheme, baseURL: base))
        XCTAssertTrue(PublishingAIRuntimeTransport.validates(try request(["requestId": .string(serverRequestID)], path: "api/ai/theme/draft/execute"), feature: .publishingAITheme, baseURL: base))
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(try request(["requestId": .string("not-a-td2-id")], path: "api/ai/theme/draft/execute"), feature: .publishingAITheme, baseURL: base))
    }
    func testClubOptionalFieldsRemainSourceTyped() throws {
        let fields: [String: ProjectEditJSON] = ["idea": .string("Synthetic route"), "clubStyle": .string("walking"), "targetDurationMin": .number(60)]
        XCTAssertTrue(PublishingAIRuntimeTransport.validates(try request(fields, path: "api/ai/club/design"), feature: .publishingAIClub, baseURL: base))
        var extra = fields; extra["productType"] = .number(2)
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(try request(extra, path: "api/ai/club/design"), feature: .publishingAIClub, baseURL: base))
    }
    func testQuotaCannotCarryPromptOrQuery() throws {
        var request = URLRequest(url: base.appendingPathComponent("api/ai/theme/draft/quota")); request.httpMethod = "POST"
        XCTAssertTrue(PublishingAIRuntimeTransport.validates(request, feature: .publishingAIQuota, baseURL: base))
        request.httpBody = Data("{}".utf8)
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(request, feature: .publishingAIQuota, baseURL: base))
        request.httpBody = nil; request.url = URL(string: base.absoluteString + "api/ai/theme/draft/quota?prompt=unexpected")
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(request, feature: .publishingAIQuota, baseURL: base))
    }
    func testWrongOriginMethodAndUnknownProviderRouteAreRejected() throws {
        var input = try request(["prepareKey": .string(prepareKey), "idea": .string("Walk"), "productType": .number(1)])
        input.httpMethod = "GET"; XCTAssertFalse(PublishingAIRuntimeTransport.validates(input, feature: .publishingAITheme, baseURL: base))
        input.httpMethod = "POST"; input.url = URL(string: "https://example.com/other/api/ai/theme/draft/prepare")
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(input, feature: .publishingAITheme, baseURL: base))
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(try request([:]), feature: .projectWrite, baseURL: base))
    }
}
