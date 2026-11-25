import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// G2 + G3. One stub transport answer per route; each test checks the method, path, body shape the
/// mini-program sends, and how the answer is read. No live backend.
@MainActor final class TopicCreatorEditorServiceTests: XCTestCase {
    private final class Stub: HTTPTransport {
        var requests: [URLRequest] = []
        var answers: [(Data, Int)] = []
        var error: Error?
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            if let error { throw error }
            return answers.isEmpty ? (Data(#"{"code":200}"#.utf8), 200) : answers.removeFirst()
        }
    }
    private let base = URL(string: "https://example.com/prod-api/")!

    private func ok(_ data: Any) throws -> (Data, Int) {
        (try JSONSerialization.data(withJSONObject: ["code": 200, "data": data]), 200)
    }
    private func service(_ stub: Stub, scope: String? = nil, enabled: Bool = true) -> TopicCreatorEditorService {
        TopicCreatorEditorService(baseURL: base, transport: stub, token: { "creator-token" }, scope: scope, enabled: { enabled })
    }
    private func form(_ request: URLRequest) -> [String: String] {
        let text = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        return Dictionary(uniqueKeysWithValues: (URLComponents(string: "?" + text)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }
    private func json(_ request: URLRequest) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]) ?? [:]
    }
    private func path(_ request: URLRequest) -> String { request.url?.path ?? "" }
    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    func testAuthorEditAndSavedDetailPostFormAndValidatePayload() async throws {
        let stub = Stub()
        let payload: [String: Any] = ["isDraft": true, "topic": ["id": 9, "name": "Night walk", "configVersion": 4,
            "journeyRulesJson": #"{"attributeBinding":{"schemaVersion":1,"registryVersion":"3","enabledKeys":[]}}"#],
            "chapters": [["id": 1, "cmsTopicNodeList": [["id": 2]]]], "tickets": []]
        stub.answers = [try ok(payload), try ok(payload)]
        let editor = service(stub, scope: "club:3")
        let detail = try await editor.authorEditDetail(topicID: 9)
        XCTAssertEqual(detail.name, "Night walk"); XCTAssertTrue(detail.isDraft)
        XCTAssertEqual(detail.configVersion, "4"); XCTAssertEqual(detail.chapterCount, 1)
        XCTAssertEqual(path(stub.requests[0]), "/prod-api/api/topic/author-edit-detail")
        XCTAssertEqual(stub.requests[0].httpMethod, "POST")
        XCTAssertEqual(form(stub.requests[0]), ["id": "9", "scope": "club:3"])
        XCTAssertEqual(stub.requests[0].value(forHTTPHeaderField: "Authorization"), "creator-token")
        _ = try await editor.authorSavedDetail(topicID: 9)
        XCTAssertEqual(path(stub.requests[1]), "/prod-api/api/topic/author-saved-detail")
        stub.answers = [try ok(["topic": ["id": 9], "chapters": [1]])]
        await XCTAssertThrowsIssue(.malformed) { _ = try await editor.authorEditDetail(topicID: 9) }
    }

    func testAttributeBindingIsAQueryGetAndRejectsAnotherConfigVersion() async throws {
        let stub = Stub()
        let definition: [String: Any] = ["stateKey": "clue.door", "keyType": "flag", "label": "Door", "scope": "run",
            "persistScope": "run", "initialValue": 0, "minValue": 0, "maxValue": 1, "visible": true]
        stub.answers = [try ok(["topicId": "9", "configVersion": "4", "registryVersion": "3", "definitions": [definition]]),
                        try ok(["topicId": "9", "configVersion": "5", "registryVersion": "3", "definitions": []])]
        let editor = service(stub)
        let registry = try await editor.attributeBinding(topicID: 9, configVersion: "4")
        XCTAssertEqual(registry.definitions.map(\.stateKey), ["clue.door"])
        XCTAssertEqual(stub.requests[0].httpMethod, "GET"); XCTAssertNil(stub.requests[0].httpBody)
        XCTAssertEqual(query(stub.requests[0]), ["topicId": "9"])
        XCTAssertEqual(path(stub.requests[0]), "/prod-api/api/topic/attribute-binding")
        do { _ = try await editor.attributeBinding(topicID: 9, configVersion: "4"); XCTFail("stale version") }
        catch { guard case TopicCreatorEditorIssue.rejected = error else { return XCTFail("\(error)") } }
    }

    func testPlaySetupGetAndWholePutStripNextDayPrefix() async throws {
        let stub = Stub()
        stub.answers = [try ok(["playWindow": ["mode": "custom", "start": "19:00", "end": "02:00"], "prepItems": ["带水"]]), try ok([:])]
        let editor = service(stub)
        let setup = try await editor.playSetup(topicID: 9)
        XCTAssertEqual(setup.window, TopicPlayWindow(mode: .custom, start: "19:00", end: "次日 02:00"))
        XCTAssertEqual(setup.prepItems, ["带水"])
        XCTAssertEqual(stub.requests[0].httpMethod, "GET")
        try await editor.savePlaySetup(topicID: 9, setup: setup)
        let put = stub.requests[1]
        XCTAssertEqual(put.httpMethod, "PUT"); XCTAssertEqual(path(put), "/prod-api/api/topic/play-setup")
        XCTAssertEqual(put.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = json(put)
        XCTAssertEqual(body["topicId"] as? Int, 9)
        XCTAssertEqual(body["playWindow"] as? [String: String], ["mode": "custom", "start": "19:00", "end": "02:00"])
        XCTAssertEqual(body["prepItems"] as? [String], ["带水"])
    }

    func testStateKeysListNamedCreateAndRename() async throws {
        let stub = Stub()
        stub.answers = [try ok([["stateKey": "clue.door", "label": "Door", "keyType": "flag", "scope": "run"]]),
                        try ok(["key": "tag.k1", "label": "Lantern"]), try ok([:])]
        let editor = service(stub)
        let rows = try await editor.stateKeys(topicID: 9)
        XCTAssertEqual(rows.map(\.id), ["clue.door"])
        XCTAssertEqual(path(stub.requests[0]), "/prod-api/api/topic/state-keys")
        let created = try await editor.createNamedStateKey(topicID: 9, kind: "tag", label: " Lantern ")
        XCTAssertEqual(created.key, "tag.k1")
        XCTAssertEqual(path(stub.requests[1]), "/prod-api/api/topic/state-keys/named")
        XCTAssertEqual(json(stub.requests[1])["label"] as? String, "Lantern")
        XCTAssertEqual(json(stub.requests[1])["kind"] as? String, "tag")
        try await editor.renameStateKey(topicID: 9, row: rows[0], label: "Front door")
        let put = stub.requests[2]
        XCTAssertEqual(put.httpMethod, "PUT"); XCTAssertEqual(path(put), "/prod-api/api/topic/state-keys/clue.door")
        let key = json(put)["key"] as? [String: Any]
        XCTAssertEqual(key?["label"] as? String, "Front door"); XCTAssertEqual(key?["keyType"] as? String, "flag")
        XCTAssertTrue(ChinaReviewedRouteCapability.isTopicStateKey("clue.door"))
        XCTAssertFalse(ChinaReviewedRouteCapability.isTopicStateKey("../pay"))
        await XCTAssertThrowsIssue(.invalid) { _ = try await editor.createNamedStateKey(topicID: 9, kind: "counter", label: "x") }
    }

    func testPublishDraftCarriesVersionsAndRequestIdAndAnUnknownStaysUnknown() async throws {
        let stub = Stub()
        stub.answers = [try ok(["reviewState": "PENDING", "contentRevisionNo": 12])]
        let editor = service(stub)
        let receipt = try await editor.publishDraft(topicID: 9, configVersion: "4", registryVersion: "3",
                                                    publishRequestID: "pub0123456789abcdef")
        XCTAssertEqual(receipt, TopicPublishReceipt(reviewState: "PENDING", contentRevisionNo: "12"))
        XCTAssertEqual(form(stub.requests[0]), ["id": "9", "configVersion": "4", "registryVersion": "3",
                                                "publishRequestId": "pub0123456789abcdef"])
        stub.error = URLError(.timedOut)
        await XCTAssertThrowsIssue(.outcomeUnknown) {
            _ = try await editor.publishDraft(topicID: 9, configVersion: nil, registryVersion: nil, publishRequestID: "pub0123456789abcdef")
        }
        await XCTAssertThrowsIssue(.invalid) {
            _ = try await editor.publishDraft(topicID: 9, configVersion: nil, registryVersion: nil, publishRequestID: "short")
        }
    }

    func testShareCodeHostQRCodeAndInviteChapters() async throws {
        let stub = Stub()
        stub.answers = [try ok(["qrcodeUrl": "https://cdn.example.com/q.png"]), try ok(["qrcodeUrl": "https://cdn.example.com/h.png"]),
                        try ok(["chapters": [["id": 31, "name": "Gate"], ["id": "x"]]])]
        let editor = service(stub)
        let code = try await editor.shareCode(topicID: 9)
        XCTAssertEqual(code, "https://cdn.example.com/q.png")
        XCTAssertEqual(form(stub.requests[0]), ["id": "9"])
        let host = try await editor.hostQRCode(topicID: 9)
        XCTAssertEqual(host, "https://cdn.example.com/h.png")
        XCTAssertEqual(form(stub.requests[1]), ["id": "9", "scope": ""])
        let chapters = try await editor.inviteChapters(topicID: 9)
        XCTAssertEqual(chapters, [TopicInviteChapter(id: "31", name: "Gate")])
        XCTAssertEqual(path(stub.requests[2]), "/prod-api/api/topic/invite-chapters")
    }

    func testSupplyTermsSendsOnlyPerkOrTrafficAndNoFee() async throws {
        let stub = Stub()
        let editor = service(stub)
        try await editor.saveSupplyTerms(try TopicChapterSupplyTerms(chapterID: 31, mode: .perk, maxMerchant: 3, perkMinValue: "20"))
        XCTAssertEqual(form(stub.requests[0]), ["chapterId": "31", "termsMode": "PERK", "maxMerchant": "3", "perkMinValue": "20"])
        try await editor.saveSupplyTerms(try TopicChapterSupplyTerms(chapterID: 31, mode: .traffic, maxMerchant: 0, perkMinValue: "20"))
        XCTAssertEqual(form(stub.requests[1]), ["chapterId": "31", "termsMode": "TRAFFIC", "maxMerchant": "0"])
        XCTAssertEqual(Set(TopicChapterSupplyTerms.Mode.allCases.map(\.rawValue)), ["PERK", "TRAFFIC"])
        XCTAssertThrowsError(try TopicChapterSupplyTerms(chapterID: 31, mode: .perk, maxMerchant: 100))
    }

    func testDisabledAndRejectedAndUnauthorized() async throws {
        let stub = Stub()
        await XCTAssertThrowsIssue(.disabled) { _ = try await self.service(stub, enabled: false).shareCode(topicID: 9) }
        XCTAssertTrue(stub.requests.isEmpty)
        stub.answers = [(Data(#"{"code":400,"msg":"名称重复"}"#.utf8), 200)]
        await XCTAssertThrowsIssue(.rejected("名称重复")) { _ = try await self.service(stub).createNamedStateKey(topicID: 9, kind: "clue", label: "a") }
        var expired = false
        stub.answers = [(Data(#"{"code":401}"#.utf8), 200)]
        let editor = TopicCreatorEditorService(baseURL: base, transport: stub, token: { "creator-token" },
                                               enabled: { true }, unauthorized: { expired = true })
        await XCTAssertThrowsIssue(.unauthorized) { _ = try await editor.playSetup(topicID: 9) }
        XCTAssertTrue(expired)
    }

    func testOrderCenterDetailReadsSummaryAndNeverInfersPaid() async throws {
        let stub = Stub()
        let summary: [String: Any] = ["kind": "COMMERCE", "id": "77", "orderNo": "CY2026", "title": "Map pack",
                                      "statusText": "待支付", "amountText": "9.90", "createdAtText": "2026-11-12 10:00"]
        stub.answers = [try ok(summary), try ok(["kind": "COMMERCE", "id": "77", "orderNo": "x", "title": "t", "statusText": "s", "amountText": "9.999"]),
                        (Data(#"{"code":403}"#.utf8), 200), (Data(), 404)]
        let reader = OrderCenterDetailService(baseURL: base, transport: stub, token: { "creator-token" }, enabled: { true })
        let read = try await reader.detail(outTradeNo: "CY2026_01")
        XCTAssertEqual(read.statusText, "待支付"); XCTAssertEqual(read.kind, .commerce); XCTAssertEqual(read.amountText, "9.90")
        XCTAssertEqual(path(stub.requests[0]), "/prod-api/api/order-center/detail")
        XCTAssertEqual(form(stub.requests[0]), ["outTradeNo": "CY2026_01"])
        await XCTAssertThrowsOrder(.malformed) { _ = try await reader.detail(outTradeNo: "CY2026_01") }
        await XCTAssertThrowsOrder(.forbidden) { _ = try await reader.detail(outTradeNo: "CY2026_01") }
        await XCTAssertThrowsOrder(.notFound) { _ = try await reader.detail(outTradeNo: "CY2026_01") }
        await XCTAssertThrowsOrder(.invalidLink) { _ = try await reader.detail(outTradeNo: "bad") }
        XCTAssertEqual(stub.requests.count, 4)
    }

    func testChinaGateAdmitsTheG2G3RoutesAndKeepsMoneyClosed() {
        for route in ["/api/order-center/detail", "/api/topic/attribute-binding", "/api/topic/author-edit-detail",
                      "/api/topic/author-saved-detail", "/api/topic/play-setup", "/api/topic/publish-draft",
                      "/api/topic/share-code", "/api/topic/state-keys", "/api/topic/state-keys/named",
                      "/api/topic/state-keys/clue.door", "/api/topic/invite-chapters", "/api/topic/chapter/supply-terms",
                      "/api/topic/host-qrcode", "/api/topic/free-explore/visit-config",
                      "/api/invoice/apply", "/api/invoice/request", "/api/invoice/cancel",
                      "/api/invoice/titles/save-request", "/api/invoice/titles/request", "/api/invoice/titles/delete"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(route), route)
        }
        for money in ["/api/registration/pay", "/api/pay/create", "/api/withdrawal/create", "/api/wallet/withdraw",
                      "/api/asset/withdraw", "/api/club/settlement/withdraw", "/api/topic/state-keys/pay"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(money), money)
        }
    }

    private func XCTAssertThrowsIssue(_ expected: TopicCreatorEditorIssue, file: StaticString = #filePath, line: UInt = #line,
                                      _ body: () async throws -> Void) async {
        do { try await body(); XCTFail("expected \(expected)", file: file, line: line) }
        catch { XCTAssertEqual(error as? TopicCreatorEditorIssue, expected, file: file, line: line) }
    }
    private func XCTAssertThrowsOrder(_ expected: OrderCenterIssue, file: StaticString = #filePath, line: UInt = #line,
                                      _ body: () async throws -> Void) async {
        do { try await body(); XCTFail("expected \(expected)", file: file, line: line) }
        catch { XCTAssertEqual(error as? OrderCenterIssue, expected, file: file, line: line) }
    }
}
