import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One Core test per player-content mini-program call this pass touches.
final class PlayerContentCoreContractTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var handler: (URLRequest) -> (Data, Int) = { _ in (Data(#"{"code":200,"data":[]}"#.utf8), 200) }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return handler(request)
        }
    }

    private func configuration() throws -> APIConfiguration {
        try APIConfiguration(baseURL: URL(string: "https://example.test/")!)
    }

    private func body(_ request: URLRequest) -> String {
        String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    }

    func testTemplateListPagesByFiftyUntilAShortPageAndDedupes() async throws {
        let wire = Wire()
        wire.handler = { request in
            let text = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            let page = text.contains("name=\"pageNum\"\r\n\r\n2\r\n") ? 2 : 1
            let ids = page == 1 ? Array(1...50) : [1, 51, 52, 53, 54, 55]
            let rows = ids.map { #"{"id":\#($0),"title":"T\#($0)"}"# }.joined(separator: ",")
            return (Data(#"{"code":200,"data":{"rows":[\#(rows)],"total":55}}"#.utf8), 200)
        }
        let service = DiscoveryService(configuration: try configuration(), transport: wire)
        let rows = try await service.playTemplates()
        XCTAssertEqual(rows.map(\.id), Array(1...55))
        XCTAssertEqual(wire.requests.count, 2)
        XCTAssertTrue(wire.requests.allSatisfy { self.body($0).contains("name=\"pageSize\"\r\n\r\n50\r\n") })
        XCTAssertEqual(wire.requests.first?.url?.path, "/api/template/list")
    }

    func testMerchantCategoryListPostsMerchantType() async throws {
        let wire = Wire()
        wire.handler = { _ in (Data(#"{"code":200,"data":[{"id":3,"categoryName":"餐饮"}]}"#.utf8), 200) }
        let rows = try await SearchMapService(configuration: configuration(), transport: wire).merchantCategories()
        XCTAssertEqual(rows.map(\.name), ["餐饮"])
        let text = body(try XCTUnwrap(wire.requests.first))
        XCTAssertEqual(wire.requests.first?.url?.path, "/api/category/list")
        XCTAssertEqual(wire.requests.first?.httpMethod, "POST")
        XCTAssertTrue(text.contains("name=\"type\"\r\n\r\nMERCHANT\r\n"))
        XCTAssertTrue(text.contains("name=\"parentid\"\r\n\r\n0\r\n"))
        XCTAssertFalse(text.contains("name=\"type\"\r\n\r\n1\r\n"))
    }

    func testActivityInfoAllowsANilToken() async throws {
        let wire = Wire()
        wire.handler = { _ in (Data(#"{"code":200,"data":{"id":6,"name":"Walk"}}"#.utf8), 200) }
        let access = try await ActivityService(configuration: configuration(), transport: wire).detail(id: 6, token: nil)
        guard case .allowed(let detail) = access else { return XCTFail("expected detail") }
        XCTAssertEqual(detail.summary.id, 6)
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(request.url?.path, "/api/activity/info")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(body(request).contains("name=\"id\"\r\n\r\n6\r\n"))
    }

    @MainActor func testActivityCancelPreviewUsesFormAndBlocksConfirmWithoutACount() async throws {
        let wire = Wire()
        wire.handler = { _ in (Data(#"{"code":200,"data":{"paidPlayers":4}}"#.utf8), 200) }
        let config = try configuration()
        let mutator = MyProjectHTTPMutator(configuration: { config }, transport: wire, tokenProvider: { "synthetic-token" })
        let count = await mutator.previewActivityCancel(id: 3, scope: "MERCHANT")
        XCTAssertEqual(count, 4)
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(request.url?.path, "/api/activity/cancel_preview")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(body(request).contains("name=\"id\"\r\n\r\n3\r\n"))
        XCTAssertTrue(body(request).contains("name=\"scope\"\r\n\r\nMERCHANT\r\n"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        let model = MyProjectMutationModel(writer: mutator, scope: "MERCHANT")
        await model.beginActivityCancel(id: 3, title: "夜跑")
        XCTAssertEqual(model.state, .awaitingConfirmation(.cancelActivity(id: 3)))
        XCTAssertTrue(model.confirmationText?.contains("将给 4 位已付款玩家全额退款") == true)
        wire.handler = { _ in (Data(#"{"code":200,"data":{}}"#.utf8), 200) }
        let blocked = MyProjectMutationModel(writer: mutator, scope: "MERCHANT")
        await blocked.beginActivityCancel(id: 3, title: "夜跑")
        guard case .failed = blocked.state else { return XCTFail("missing count opened confirm") }
        XCTAssertNil(blocked.confirmationText)
        XCTAssertFalse(wire.requests.contains { $0.url?.path.hasSuffix("api/activity/cancel") == true && !$0.url!.path.hasSuffix("cancel_preview") })
    }

    func testRegistrationMerchantListMergesAcceptedJoins() async throws {
        let wire = Wire()
        wire.handler = { request in
            switch request.url?.path {
            case "/api/project/my":
                return (Data(#"{"code":200,"data":{"rows":[{"id":9,"bizType":"topic","title":"Own"}],"total":1}}"#.utf8), 200)
            case "/api/registration/merchant/list":
                return (Data(#"{"code":200,"data":[{"id":1,"status":1,"topicId":4,"topicName":"Joined","startDate":"2099-01-01","endDate":"2099-01-02"},{"id":2,"status":1,"topicId":9,"topicName":"Duplicate","startDate":"2099-01-01"}]}"#.utf8), 200)
            default:
                return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
            }
        }
        let page = try await CreatorContentService(configuration: configuration(), transport: wire)
            .projects(operationScope: "MERCHANT", token: "synthetic-token")
        XCTAssertEqual(page.rows.map(\.id), ["topic:9", "topic:4"])
        XCTAssertEqual(page.rows.last?.title, "Joined")
        let list = try XCTUnwrap(wire.requests.first { $0.url?.path == "/api/registration/merchant/list" })
        XCTAssertEqual(list.httpMethod, "POST")
        XCTAssertTrue(body(list).contains("name=\"status\"\r\n\r\n0\r\n"))
    }

    func testChapterApplicationMineMergesAPendingInvite() async throws {
        let wire = Wire()
        wire.handler = { request in
            switch request.url?.path {
            case "/api/project/my":
                return (Data(#"{"code":200,"data":{"rows":[],"total":0}}"#.utf8), 200)
            case "/api/merchant/chapter-application/mine":
                return (Data(#"{"code":200,"data":[{"status":0,"source":1,"topicId":8,"topicName":"Invite","startDate":"2099-02-01"}]}"#.utf8), 200)
            default:
                return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
            }
        }
        let page = try await CreatorContentService(configuration: configuration(), transport: wire)
            .projects(operationScope: "MERCHANT", token: "synthetic-token")
        XCTAssertEqual(page.rows.map(\.id), ["topic:8"])
        XCTAssertEqual(page.rows.first?.stateText, "待接受")
        XCTAssertEqual(page.rows.first?.projectTypeText, "受邀")
        let mine = try XCTUnwrap(wire.requests.first { $0.url?.path == "/api/merchant/chapter-application/mine" })
        XCTAssertEqual(mine.httpMethod, "POST")
        wire.handler = { request in
            if request.url?.path == "/api/project/my" {
                return (Data(#"{"code":200,"data":{"rows":[],"total":0}}"#.utf8), 200)
            }
            return (Data(#"{"code":500,"msg":"no"}"#.utf8), 200)
        }
        do {
            _ = try await CreatorContentService(configuration: configuration(), transport: wire)
                .projects(operationScope: "MERCHANT", token: "synthetic-token")
            XCTFail("a failed join source still returned projects")
        } catch {}
    }

    func testCommunityTrustReportSubmitDefaultsOnAndMatchesTheSheetBody() async throws {
        let wire = Wire()
        let client = try CommunityMemberReportClient(configuration: configuration(), transport: wire)
        XCTAssertTrue(client.writesEnabled)
        let requestID = CommunityMemberReportDraft.requestID(targetType: .member, targetID: 8, nowMillis: 1_700_000_000_000, random: "ab12cd34")
        let draft = try CommunityMemberReportDraft(
            targetType: .member, targetID: 8, reasonCode: "HARASSMENT", policyVersion: "v1",
            description: "具体经过", requestID: requestID
        )
        try await client.submit(draft, token: "synthetic-token")
        XCTAssertEqual(wire.requests.count, 1)
        let closed = try CommunityMemberReportClient(configuration: configuration(), transport: wire, writesEnabled: false)
        do { try await closed.submit(draft, token: "synthetic-token"); XCTFail("closed grant sent") }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        let request = try client.submitRequest(draft, token: "synthetic-token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/community-trust/reports/submit")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(json["targetType"] as? String, "MEMBER")
        XCTAssertEqual((json["targetId"] as? NSNumber)?.intValue, 8)
        XCTAssertEqual(json["reasonCode"] as? String, "HARASSMENT")
        XCTAssertEqual(json["policyVersion"] as? String, "v1")
        XCTAssertEqual(json["description"] as? String, "具体经过")
        XCTAssertEqual(json["requestId"] as? String, requestID)
        XCTAssertNil(json["evidenceAssetIds"])
        let direct = try JSONDecoder().decode(MessagingConversation.self, from: Data(#"{"conversationId":1,"type":1}"#.utf8))
        let system = try JSONDecoder().decode(MessagingConversation.self, from: Data(#"{"conversationId":2,"type":2}"#.utf8))
        XCTAssertTrue(IMSafetyMenu.offersPeerReport(conversation: direct))
        XCTAssertFalse(IMSafetyMenu.offersPeerReport(conversation: system))
        XCTAssertEqual(IMSafetyMenu(conversation: direct, blockedByMe: false).items, [.report, .block, .hide])
    }

    func testCommunityTrustReportTaxonomyIsAGET() async throws {
        let client = try CommunityMemberReportClient(configuration: configuration(), transport: Wire())
        let request = try client.taxonomyRequest(token: nil)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.url?.path, "/api/community-trust/reports/taxonomy")
    }
}
