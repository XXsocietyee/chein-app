import XCTest
import Foundation
@testable import Questify

/// fix/1128c-ai-showcase (brief planning-audit rule: prove it is ON in Release). Every test builds the shipped Release
/// composition (`RegionalLaunchConfiguration.reviewedDeployment` + `makeComposition`) and checks that the AI creation
/// services are switched on for the right roles and that the composition transport admits the exact request shapes.
/// Offline: the wire only records.
@MainActor final class AICreationReleaseCompositionTests: XCTestCase {
    static let base = "https://ai-showcase-1128c.example.test"
    static let token = "synthetic-ai-showcase-7"

    final class Vault: AppTokenStorage {
        var value: String?
        func read() throws -> String? { value }
        func write(_ token: String) throws { value = token }
        func clear() throws { value = nil }
    }
    final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
        }
    }

    private func release() throws -> AppCompositionRoot {
        let suite = "ai-showcase-1128c-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let build = RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: Self.base,
            bundleIdentifier: "com.questify.ios", realm: "ai-showcase-1128c-" + UUID().uuidString.lowercased())
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: build)
        XCTAssertTrue(deployment.productionGatesEnabled)
        XCTAssertTrue(deployment.playerWritesEnabled)
        let vault = Vault()
        return RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in vault }), makeTransport: { Wire() })
    }

    private func context(_ root: AppCompositionRoot, role: String) throws -> RuntimeDependencyContext {
        RuntimeDependencyContext(market: .china, baseURL: try XCTUnwrap(URL(string: Self.base)), role: role,
            session: try PlayExperienceSession(accountID: 7, epoch: 1, namespace: root.reviewed?.storageScope.service ?? "unconfigured",
                token: Self.token, role: role))
    }

    private func post(_ path: String, body: String?) throws -> URLRequest {
        var request = URLRequest(url: try XCTUnwrap(URL(string: Self.base + "/" + path)))
        request.httpMethod = "POST"
        request.setValue(Self.token, forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(body.utf8)
        }
        return request
    }

    private func routePaths(_ root: AppCompositionRoot, role: String, _ feature: BusinessRuntimeFeature) throws -> Set<String> {
        let configuration = root.sessionDependencies(try context(root, role: role)).businessConfiguration
        return Set((configuration?.routes[feature] ?? []).map(\.path))
    }

    func testReleaseCompositionSwitchesOnThemeDraftAndQuotaForPlayersAndClubs() throws {
        let root = try release()
        for role in ["player", "club"] {
            XCTAssertEqual(try routePaths(root, role: role, .publishingAITheme),
                           ["api/ai/theme/draft/prepare", "api/ai/theme/draft/execute"], role)
            XCTAssertEqual(try routePaths(root, role: role, .publishingAIQuota), ["api/ai/theme/draft/quota"], role)
        }
    }

    func testReleaseCompositionSwitchesOnClubDesignTemplateFillAndSafetyForClubs() throws {
        let root = try release()
        XCTAssertEqual(try routePaths(root, role: "club", .publishingAIClub), ["api/ai/club/design"])
        XCTAssertEqual(try routePaths(root, role: "club", .publishingAITemplate), ["api/ai/template/fill"])
        XCTAssertEqual(try routePaths(root, role: "club", .publishingAISafety), ["api/ai/safety/precheck"])
        // The backend `gateRole` blocks players on these three, so players get no grant (no dead call).
        for feature in [BusinessRuntimeFeature.publishingAIClub, .publishingAITemplate, .publishingAISafety] {
            XCTAssertTrue(try routePaths(root, role: "player", feature).isEmpty, "\(feature)")
        }
    }

    func testMerchantAIStaysDeferred() throws {
        let root = try release()
        for feature in [BusinessRuntimeFeature.publishingAIQuota, .publishingAITheme, .publishingAIClub, .publishingAITemplate, .publishingAISafety] {
            XCTAssertTrue(try routePaths(root, role: "merchant", feature).isEmpty, "\(feature)")
        }
    }

    func testEveryGrantedRouteIsAcceptedByItsFeatureCatalog() throws {
        let root = try release()
        for feature in AICreationReleaseApprovals.features(role: "club") {
            let configuration = try XCTUnwrap(root.sessionDependencies(try context(root, role: "club")).businessConfiguration)
            for route in configuration.routes[feature] ?? [] {
                XCTAssertTrue(feature.accepts(route), "\(feature) \(route.path)")
            }
        }
    }

    func testCompositionTransportAdmitsTheExactAIRequests() throws {
        let root = try release()
        let baseURL = try XCTUnwrap(URL(string: Self.base))
        let requests: [(String, String?)] = [
            ("api/ai/theme/draft/quota", nil),
            ("api/ai/theme/draft/prepare", #"{"idea":"夜游西湖","prepareKey":"0f4f8a4e-6c1b-4f63-9d7a-2a7f1b0c9d11","productType":1}"#),
            ("api/ai/theme/draft/execute", #"{"requestId":"r-0000000000000001"}"#),
            ("api/ai/club/design", #"{"idea":"周末骑行","clubStyle":"轻松","targetDurationMin":90}"#),
            ("api/ai/template/fill", #"{"shopName":"湖畔书店","extraNote":"找书挑战"}"#),
            ("api/ai/safety/precheck", #"{"title":"夜游","subtitle":"","description":"一起走","nodes":[{"name":"断桥","task":"拍照","hint1":"","hint2":""}]}"#)
        ]
        let ctx = try context(root, role: "club")
        let grant = try XCTUnwrap(root.playerWriteGrant(ctx))
        for (path, body) in requests {
            XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(try post(path, body: body), baseURL: baseURL,
                token: Self.token, context: ctx, grant: grant), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        var get = try post("api/ai/club/design", body: #"{"idea":"x"}"#)
        get.httpMethod = "GET"
        XCTAssertFalse(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(get, baseURL: baseURL, token: Self.token, context: ctx, grant: grant))
        XCTAssertFalse(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(try post("api/ai/club/design", body: nil),
            baseURL: baseURL, token: Self.token, context: ctx, grant: grant), "a creator AI call is a JSON object")
        XCTAssertFalse(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(try post("api/ai/theme/draft/quota", body: #"{"x":1}"#),
            baseURL: baseURL, token: Self.token, context: ctx, grant: grant), "the quota read has no body")
    }

    func testSafetyRuntimeTransportAcceptsOnlyTheBackendDTO() throws {
        let baseURL = try XCTUnwrap(URL(string: Self.base))
        let good = try post("api/ai/safety/precheck", body: #"{"title":"a","subtitle":"","description":"b","nodes":[{"name":"n","task":"t","hint1":"","hint2":""}]}"#)
        XCTAssertTrue(PublishingAIRuntimeTransport.validates(good, feature: .publishingAISafety, baseURL: baseURL))
        let legacy = try post("api/ai/safety/precheck", body: #"{"content":"b","scene":"feed"}"#)
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(legacy, feature: .publishingAISafety, baseURL: baseURL),
                       "H-08b: the old {content, scene} body is refused")
        let extraNodeKey = try post("api/ai/safety/precheck", body: #"{"title":"a","nodes":[{"name":"n","answer":"x"}]}"#)
        XCTAssertFalse(PublishingAIRuntimeTransport.validates(extraNodeKey, feature: .publishingAISafety, baseURL: baseURL))
    }

    func testSafetyRequestFieldsFollowTheMPOrder() {
        var draft = ProjectEditDraft()
        draft.name = "夜游西湖"; draft.subtitle = "三站"; draft.description = "沿苏堤走"
        var first = ProjectEditNode(); first.name = "断桥"; first.description = "拍一张合影"
        first.localMetadata["templateInfo"] = .object(["ruleInstructions": .string("找到石碑"), "hint1": .string("看桥头")])
        var second = ProjectEditNode(); second.name = "雷峰塔"; second.description = "登塔"
        var chapter = ProjectEditChapter(); chapter.nodes = [first, second]
        draft.chapters = [chapter]
        let fields = AISafetyPrecheckRequest.fields(for: draft)
        XCTAssertEqual(Set(fields.keys), AISafetyPrecheckRequest.fieldKeys)
        XCTAssertTrue(AISafetyPrecheckRequest.validates(fields))
        let nodes = fields["nodes"]?.array?.compactMap(\.object) ?? []
        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes.first?["task"], .string("找到石碑"), "rule text first, as MP _buildPrecheckReq")
        XCTAssertEqual(nodes.first?["hint1"], .string("看桥头"))
        XCTAssertEqual(nodes.last?["task"], .string("登塔"), "then the stop description")
    }

    func testVerdictClassificationMatchesTheMP() throws {
        let raw: ProjectEditJSON = .object(["issues": .array([
            .object(["level": .string("error"), "type": .string("unsafe_place"), "message": .string("夜间水边")]),
            .object(["level": .string("error"), "type": .string("missing_cover"), "message": .string("缺封面")]),
            .object(["level": .string("error"), "type": .string("timeline_conflict"), "message": .string("营业时间")]),
            .object(["level": .string("warn"), "type": .string("gap"), "message": .string("提示少")])
        ])])
        let verdict = AISafetyPrecheckRunner.verdict(.acknowledged(raw))
        XCTAssertEqual(verdict.blocking.map(\.message), ["夜间水边"])
        XCTAssertEqual(verdict.advisory.map(\.message), ["营业时间", "提示少"], "missing_cover is dropped; timeline is advisory")
        XCTAssertFalse(verdict.allowsPublish)
        XCTAssertEqual(AISafetyPrecheckRunner.verdict(.unavailable("今日AI次数已用完")).skip, .quota)
        XCTAssertEqual(AISafetyPrecheckRunner.verdict(.rejected("当前身份暂不支持AI创作")).skip, .unavailable)
        XCTAssertTrue(AISafetyPrecheckRunner.verdict(.unknown).allowsPublish, "AI never blocks the publish path")
    }

    func testShowcaseReadsTheWeatherBranchGuideFacts() {
        let weather = AIShowcaseWeather(guideFacts: ["weather": "rain", "temperatureC": "12.4", "daypart": "night", "source": "server"])
        XCTAssertEqual(weather, AIShowcaseWeather(condition: .rain, temperatureC: 12, daypart: .night))
        XCTAssertNil(AIShowcaseWeather(guideFacts: ["weather": "volcano"]))
        XCTAssertNil(AIShowcaseWeather(guideFacts: nil))
        XCTAssertEqual(AIShowcaseCatalog.suggestionKey(for: weather, dayOfYear: 5), "aiShowcase.guide.rain.3")
        XCTAssertEqual(AIShowcaseCatalog.suggestionKey(for: nil, dayOfYear: 3), "aiShowcase.guide.any.1")
        XCTAssertEqual(AIShowcaseCatalog.allSuggestionKeys.count, 24)
    }
}
