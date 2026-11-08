import XCTest
@testable import Questify

/// ADAPT-4 group 3. Pins GET /api/official/v2/events/{id}/publish-check (ApiOfficialEventController @GetMapping, class mapping
/// /api/official; hengyin@4ac8c249) against OfficialEventV2PublishCheck's Jackson output. Fixtures follow that DTO:
/// blockers/risks/pass always; warnings/results (@JsonInclude NON_NULL) only when the tier switch is on.
@MainActor final class Adapt4OfficialPublishCheckShapeTests: XCTestCase {
    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var reply: (String, Int) = ("{}", 200)
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (Data(reply.0.utf8), reply.1) }
    }
    private func access(_ wire: Wire) throws -> OfficialOrganizerHTTPAccess {
        OfficialOrganizerHTTPAccess(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/prod-api/")!),
                                    transport: wire, enabled: { true }, session: { (7, "synthetic-token") })
    }
    private let legacy = #"{"msg":"操作成功","code":200,"data":{"blockers":["缺少封面"],"risks":["主办方未确认"],"pass":false}}"#
    private let tiered = #"{"msg":"操作成功","code":200,"data":{"blockers":["缺少封面"],"risks":["主办方未确认"],"pass":false,"warnings":["标题较短"],"results":[{"level":"BLOCK","message":"缺少封面"},{"level":"WARN","message":"主办方未确认"},{"level":"WARN","message":"标题较短"}]}}"#
    private let clean = #"{"msg":"操作成功","code":200,"data":{"blockers":[],"risks":[],"pass":true}}"#

    func testRequestIsGETWithPathIdNoBodyNoQuery() async throws {
        let wire = Wire(); wire.reply = (clean, 200)
        _ = try await access(wire).publishCheck(eventID: 42)
        let req = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.url?.path, "/prod-api/api/official/v2/events/42/publish-check")
        XCTAssertNil(req.url?.query); XCTAssertNil(req.httpBody)
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
    }
    func testLegacyShapeMapsBlockersAndRisks() async throws {
        let wire = Wire(); wire.reply = (legacy, 200)
        guard case .allowed(let c) = try await access(wire).publishCheck(eventID: 42) else { return XCTFail() }
        XCTAssertEqual(c.blockers, ["缺少封面"]); XCTAssertEqual(c.risks, ["主办方未确认"]); XCTAssertFalse(c.pass); XCTAssertTrue(c.known)
    }
    func testTieredShapeExtraFieldsAreIgnoredWithoutChangingBlockersOrRisks() async throws {
        let wire = Wire(); wire.reply = (tiered, 200)
        guard case .allowed(let c) = try await access(wire).publishCheck(eventID: 42) else { return XCTFail() }
        XCTAssertEqual(c.blockers, ["缺少封面"]); XCTAssertEqual(c.risks, ["主办方未确认"]); XCTAssertFalse(c.pass)
    }
    func testCleanCheckPasses() async throws {
        let wire = Wire(); wire.reply = (clean, 200)
        guard case .allowed(let c) = try await access(wire).publishCheck(eventID: 42) else { return XCTFail() }
        XCTAssertTrue(c.pass); XCTAssertTrue(c.blockers.isEmpty)
    }
    // Backend: error("无权查看该活动发布检查") -> code 500 with HTTP 200.
    func testNoPermissionIsDeniedWithServerMessage() async throws {
        let wire = Wire(); wire.reply = (#"{"msg":"无权查看该活动发布检查","code":500}"#, 200)
        let result = try await access(wire).publishCheck(eventID: 42)
        XCTAssertEqual(result, .denied("无权查看该活动发布检查"))
    }
    func testNonPositiveEventIdNeverReachesTheWire() async throws {
        let wire = Wire()
        do { _ = try await access(wire).publishCheck(eventID: 0); XCTFail() } catch { XCTAssertEqual(error as? OfficialOrganizerFailure, .invalid) }
        XCTAssertTrue(wire.requests.isEmpty)
    }
}
