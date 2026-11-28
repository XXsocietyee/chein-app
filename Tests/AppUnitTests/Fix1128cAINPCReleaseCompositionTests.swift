import XCTest
@testable import Questify

/// fix/1128c-ai-npc-guide: every player AI feature the inventory lists as "Done" is ON in the shipped (Release)
/// China composition. Each case builds `RegionalLaunchConfiguration.shippedComposition` (→ `reviewedComposition` →
/// `reviewedDeployment`) and asserts the service / approval is non-nil and admits the exact path and fields.
@MainActor final class Fix1128cAINPCReleaseCompositionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"
    private let token = "player-token"

    private func composition(_ recorder: Fix1128cRecorder) -> AppCompositionRoot {
        RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
    }

    private func playerContext(_ composition: AppCompositionRoot) throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: token)
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }

    private func factory(_ built: AppCompositionRoot, player: RuntimeDependencyContext) throws -> RuntimeDependencyFactory {
        let composed = built.transport()
        composed.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        return RuntimeDependencyFactory(api: try APIConfiguration(baseURL: player.baseURL),
                                        configuration: built.sessionDependencies(player).configuration,
                                        transport: composed, current: { player })
    }

    /// Inventory rows 6, 7, 15: shop NPC text + voice and the hint ladder are admitted; reply audio playback stays off.
    func testReleaseCompositionSwitchesOnShopNPCTextVoiceAndHints() throws {
        let built = composition(Fix1128cRecorder())
        let player = try playerContext(built)
        let dependencies = built.sessionDependencies(player)
        let configuration = try XCTUnwrap(dependencies.configuration)
        XCTAssertTrue(configuration.shopNPCWrites)
        XCTAssertTrue(dependencies.shopNPCGrants.textAllowed)
        XCTAssertTrue(dependencies.shopNPCGrants.voiceAllowed)
        XCTAssertTrue(dependencies.shopNPCGrants.microphone)
        XCTAssertFalse(dependencies.shopNPCGrants.playback, "audioUrl belongs to the deferred merchant voice clone")
        XCTAssertTrue(configuration.play.contains(.hints))
        for path in ["api/ai/npc/shop-chat", "api/ai/npc/voice-chat", "api/play/puzzle/hint", "api/play/hint/unlock",
                     "api/ai/npc/chat/data/delete"] {
            XCTAssertTrue(configuration.endpoints.paths.contains(path), path)
            XCTAssertTrue(ReviewedProductionGateLeases.playPaths.contains(path), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        // Roam free chat stays closed by the owner's 07-22 decision (backend chatOn() is hard false).
        XCTAssertFalse(configuration.endpoints.paths.contains("api/ai/npc/chat"))
        XCTAssertFalse(configuration.journeyAsks)
        XCTAssertNotNil(ShopNPCVoiceCaptureFactory.make(for: dependencies.shopNPCGrants))
        XCTAssertNil(ShopNPCVoiceCaptureFactory.make(for: ShopNPCGrants()))
    }

    /// The exact MP / backend wire shapes reach the network through the shipped composition firewall:
    /// `shop-chat {requestId,nodeId,message}` JSON and `voice-chat file,nodeId,requestId` multipart.
    func testShippedShopNPCAdapterSendsTextAndVoiceToTheWire() async throws {
        let recorder = Fix1128cRecorder()
        let built = composition(recorder)
        let player = try playerContext(built)
        let runtime = try factory(built, player: player)
        let accepted = try XCTUnwrap(runtime.accepted)
        let nodeID = try XCTUnwrap(ShopNPCNodeID(81))
        let scope = ShopNPCScope(sessionID: "ns:1:topic:12", accountID: "7", roleID: "player", accessRevision: 0, nodeID: nodeID)
        let host = try ShopNPCHostSession(scope: scope, token: token)
        let grants = built.sessionDependencies(player).shopNPCGrants
        let adapter = ShopNPCAuthenticatedHTTPTransport(configuration: try APIConfiguration(baseURL: player.baseURL),
            transport: runtime.transport, productionWritesEnabled: accepted.shopNPCWrites,
            currentSession: { host }, currentGrants: { grants })
        let client = ShopNPCHTTPClient(transport: adapter)
        _ = try? await client.text("这家店几点关门？", requestID: UUID(), scope: scope)
        XCTAssertEqual(recorder.paths.last, "api/ai/npc/shop-chat")
        let sent = try XCTUnwrap(recorder.bodies.last)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: sent) as? [String: Any])
        XCTAssertEqual(Set(fields.keys), ["requestId", "nodeId", "message"])
        XCTAssertEqual(fields["nodeId"] as? Int, 81)
        let clip = try ShopNPCVoiceClip(bytes: Data(repeating: 1, count: 2048), duration: 3)
        _ = try? await client.voice(clip, requestID: UUID(), scope: scope)
        XCTAssertEqual(recorder.paths.last, "api/ai/npc/voice-chat")
        XCTAssertTrue(recorder.contentTypes.last?.hasPrefix("multipart/form-data; boundary=ShopNPC-") == true)
    }

    /// Inventory row 11: 「AI 对话记录」 read lease and log deletion are issued in Release, through the exact routes.
    func testReleaseCompositionIssuesNPCChatDataReadAndDeletion() async throws {
        let recorder = Fix1128cRecorder()
        let built = composition(recorder)
        let player = try playerContext(built)
        XCTAssertTrue(built.releaseAINPCEnabled(player))
        let read = try NPCChatDataReadApproval(context: player, expiresAt: Date().addingTimeInterval(3600))
        XCTAssertTrue(read.matches(player))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + NPCChatData.path))
        let approval = try XCTUnwrap(ReviewedProductionGateLeases.npcChatLogDeletionApproval(player))
        let api = try APIConfiguration(baseURL: player.baseURL)
        XCTAssertTrue(approval.allows(configuration: api, namespace: player.session.namespace,
                                      accountID: player.session.accountID, path: NPCChatLogDeletion.path))
        let session = ComplianceSession(accountID: 7, epoch: 1, market: player.market.rawValue, namespace: player.session.namespace)
        let service = NPCChatLogDeletionService(configuration: api, transport: built.makeTransport(),
            current: { session }, token: { "player-token" }, approval: { approval })
        XCTAssertTrue(service.canDelete(session: session))
        recorder.reply = #"{"code":200,"data":{"deleted":3}}"#
        let outcome = try await service.delete(session: session)
        XCTAssertEqual(outcome, .deleted(count: 3))
        XCTAssertEqual(recorder.paths.last, "api/ai/npc/chat/data/delete")
        XCTAssertEqual(recorder.methods.last, "POST")
        XCTAssertEqual(recorder.bodies.last, Data("{}".utf8))
        // US stays dormant.
        let us = RuntimeDependencyContext(market: .unitedStates, baseURL: player.baseURL, role: "player", session: player.session)
        XCTAssertNil(ReviewedProductionGateLeases.npcChatLogDeletionApproval(us))
    }

    /// The data-driven story content ships both languages for every key the views read.
    func testStoryContentBundleHasEnglishAndSimplifiedChinese() throws {
        let catalog = try XCTUnwrap(StoryContentCatalog.bundled())
        for key in StoryContentKey.allCases {
            XCTAssertFalse(catalog.text(key, language: .english).isEmpty, key.rawValue)
            XCTAssertFalse(catalog.text(key, language: .simplifiedChinese).isEmpty, key.rawValue)
        }
        XCTAssertFalse(catalog.guidePrompts(for: .roam, language: .english).isEmpty)
        XCTAssertFalse(catalog.guidePrompts(for: .play, language: .simplifiedChinese).isEmpty)
    }
}

private final class Fix1128cRecorder: HTTPTransport {
    var paths: [String] = []
    var methods: [String] = []
    var bodies: [Data] = []
    var contentTypes: [String] = []
    var reply = #"{"code":200,"data":{}}"#
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        paths.append(request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? "")
        methods.append(request.httpMethod ?? "")
        bodies.append(request.httpBody ?? Data())
        contentTypes.append(request.value(forHTTPHeaderField: "Content-Type") ?? "")
        return (Data(reply.utf8), 200)
    }
}
