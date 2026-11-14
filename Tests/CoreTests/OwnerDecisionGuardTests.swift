import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One assertion group per WP-10 row. Cites OWN-D-01, -02, -03, -04, -05, -06, -08, -10 and OWN-OPT-010.
final class OwnerDecisionGuardTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    func testOWND01aListsSpendRulesAndDropsDeleted() throws {
        let rows = try JSONDecoder().decode([WalletPointsTask].self, from: Data(#"""
        [{"id":1,"status":1,"eventType":1,"title":"earn","delFlag":0},
         {"id":2,"status":1,"eventType":14,"title":"积分消耗"},
         {"id":3,"status":1,"eventType":1,"title":"gone","delFlag":2}]
        """#.utf8))
        XCTAssertEqual(rows.filter(\.isEarnTask).map(\.id), [1])
        XCTAssertEqual(rows.filter(\.isSpendRule).map(\.id), [2])
        XCTAssertEqual(rows.filter(\.isListedRule).map(\.id), [1, 2])
        let view = try source("App/WalletCommerceViews.swift")
        XCTAssertTrue(view.contains("积分消耗"))
        XCTAssertTrue(view.contains("wallet.tasks.spend"))
    }

    func testOWND01bTurnsTheToggleOffWithTheRealReason() throws {
        let refused = try quote(#"{"payAmount":12,"pointsDeductYuan":0,"pointsUsable":false,"pointsBalance":40,"quoteSign":"s"}"#)
        let noPoints = try quote(#"{"payAmount":12,"pointsDeductYuan":0,"pointsUsable":true,"pointsBalance":0,"quoteSign":"s"}"#)
        let refusedNotice = RegistrationCoreLoopRules.pointsAutoDisableEvaluation(usePoints: true, quote: refused, userAvailablePoints: refused.availablePoints)
        XCTAssertTrue(refusedNotice.shouldDisable)
        XCTAssertEqual(refusedNotice.notice, "该票不支持积分抵扣")
        let emptyNotice = RegistrationCoreLoopRules.pointsAutoDisableEvaluation(usePoints: true, quote: noPoints, userAvailablePoints: noPoints.availablePoints)
        XCTAssertTrue(emptyNotice.shouldDisable)
        XCTAssertEqual(emptyNotice.notice, "暂无可用积分")
        let flow = try source("Core/RegistrationUIFlow.swift")
        XCTAssertTrue(flow.contains("pointsToggleNotice"))
        XCTAssertTrue(flow.contains("usePoints = false"))
        let sheet = try source("App/RegistrationSheetView.swift")
        XCTAssertTrue(sheet.contains("registration.form.pointsNotice"))
    }

    func testOWND01cShowsTheSnapshotAndHasNoClientRateLiteral() throws {
        let order = try source("App/ProfileOrdersView.swift")
        XCTAssertTrue(order.contains("order.pointUsed"))
        XCTAssertFalse(order.contains("pointDeductRate"))
        XCTAssertFalse(order.contains("* pointUsed") || order.contains("pointUsed *"))
        let banned = ["pointDeductRate", "defaultRateMicroYuan", "rateMicroYuan", "POINT_DEDUCT_RATE", "乘50"]
        let excluded = ["MoneyParityRules.swift", "RegistrationCheckoutPresentation.swift"]
        for url in try swiftFiles(in: ["App", "Core"]) where !excluded.contains(url.lastPathComponent)
            && !url.lastPathComponent.hasPrefix("UnifiedOPT") && !url.lastPathComponent.hasPrefix("Legacy52") {
            let text = try String(contentsOf: url, encoding: .utf8)
            for token in banned where text.contains(token) {
                XCTFail("\(url.lastPathComponent) contains \(token)")
            }
        }
    }

    /// OWN-OPT-010 closes with D-01.a–c.
    func testOWNOPT010CitesThePointsRows() throws {
        let text = try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
        XCTAssertTrue(text.contains("OWN-D-01"))
        XCTAssertTrue(text.contains("testOWND01a"))
        XCTAssertTrue(text.contains("testOWND01b"))
        XCTAssertTrue(text.contains("testOWND01c"))
        XCTAssertTrue(text.contains("OWN-OPT-010"))
    }

    func testOWND02HasNoDuesRouteOrScreen() throws {
        let hits = try scan("api/club/membership", roots: ["App", "Core"]) { name in
            !name.hasPrefix("UnifiedOPT") && !name.hasPrefix("Legacy52")
        }
        XCTAssertEqual(hits, [], hits.joined(separator: ", "))
    }

    func testOWND03aMapsEachSurfaceToItsChain() throws {
        let names = OwnerDecisionContentChain.surfaces.map(\.name)
        XCTAssertEqual(names, ["feed", "notifications", "enforcements", "appeals", "capabilities", "reports",
                               "compose", "detail", "like", "bookmark", "report", "delete"])
        for surface in OwnerDecisionContentChain.surfaces {
            let text = try source(surface.clientFile)
            XCTAssertTrue(text.contains(surface.path), surface.name)
            if surface.chain == OwnerDecisionContentChain.community {
                XCTAssertTrue(surface.path.contains("api/v1/community"), surface.name)
            } else {
                XCTAssertTrue(surface.path.contains("creativesquare"), surface.name)
            }
        }
    }

    func testOWND03bDoesNotFlipASurfaceBetweenChains() throws {
        XCTAssertEqual(OwnerDecisionContentChain.squareDeleteOwnedBy, "WP-04")
        let deletion = try source("Core/SquareDeletionFlow.swift")
        XCTAssertTrue(deletion.contains("api/v1/community/posts/{id}"))
        let hits = try scan("ContentChainSwitch", roots: ["App", "Core"]) { _ in true }
        XCTAssertEqual(hits, [])
        XCTAssertFalse(try source("Core/OwnerDecisionGuards.swift").contains("func flip"))
    }

    func testOWND04RendersServerFragmentsInOrder() throws {
        let ending = try OwnerDecisionEndingRender(sourcePath: "api/play/ending", fragments: ["second", "first"])
        XCTAssertEqual(ending.fragments, ["second", "first"])
        let journey = try OwnerDecisionEndingRender(sourcePath: "api/play/journey/ending", fragments: ["a"])
        XCTAssertEqual(journey.sourcePath, "api/play/journey/ending")
        XCTAssertThrowsError(try OwnerDecisionEndingRender(sourcePath: "api/play/ending/pick", fragments: ["a"]))
        XCTAssertTrue(try source("Core/PlayExperienceService.swift").contains("api/play/ending"))
        XCTAssertTrue(try source("Core/JourneyNarrativeContracts.swift").contains("api/play/journey/ending"))
        let hits = try scan("endingPriority", roots: ["App", "Core"]) { _ in true }
        XCTAssertEqual(hits, [])
    }

    func testOWND05aStatusAndUnbindWithoutANativeBind() async throws {
        XCTAssertEqual(OwnerDecisionReceiverCopy.bindHandoff, "请在小程序完成绑定")
        XCTAssertEqual(OwnerDecisionReceiverCopy.miniProgramPath, "pages/club/payout-receiver/index")
        XCTAssertEqual(OwnerDecisionReceiverCopy.unbindTitle, "解除个人收款?")
        XCTAssertEqual(OwnerDecisionReceiverCopy.unbindConsequence, "解除后新的俱乐部收入会暂停，重新绑定后继续")
        XCTAssertEqual(OwnerDecisionReceiverCopy.unbindConfirm, "解除绑定")
        let shaped = OwnerDecisionReceiverStatus.shape([
            "available": true, "receiverState": "VERIFIED", "paused": false, "payoutEnabled": false, "canUnbind": true
        ])
        XCTAssertEqual(shaped?.page, .bound)
        XCTAssertEqual(shaped?.canUnbind, true)
        XCTAssertNil(OwnerDecisionReceiverStatus.shape(["available": false]))
        let transport = Recorder()
        let client = try makeClient(transport, payout: false)
        XCTAssertEqual(client.bind(), .notSent)
        XCTAssertTrue(transport.requests.isEmpty)
        let screen = try source("App/OwnerDecisionPayoutViews.swift")
        XCTAssertTrue(screen.contains("club.receiver.unbind"))
        XCTAssertFalse(screen.contains("api/club/personal-receiver/bind"))
        XCTAssertTrue(screen.contains("club.receiver.loading"))
        XCTAssertTrue(screen.contains("club.receiver.empty"))
        XCTAssertTrue(screen.contains("club.receiver.error"))
    }

    func testOWND05bMerchantAccountIsReadOnlyBehindFinanceRead() throws {
        XCTAssertTrue(OwnerDecisionMerchantAccount.allowsFinance(["merchant:finance:read"]))
        XCTAssertTrue(OwnerDecisionMerchantAccount.allowsFinance(["FINANCE_READ"]))
        XCTAssertFalse(OwnerDecisionMerchantAccount.allowsFinance(["merchant:order:read"]))
        let ready = OwnerDecisionMerchantAccount.shape([
            "available": true, "state": "NEED_SIGN", "stateDesc": "等待本人签约",
            "signUrl": "https://www.chengyinhub.com/sign/example"
        ])
        XCTAssertEqual(ready?.phase, .ready)
        XCTAssertEqual(ready?.signURL, "https://www.chengyinhub.com/sign/example")
        XCTAssertEqual(OwnerDecisionMerchantAccount.shape(["available": true, "state": "NONE"])?.phase, OwnerDecisionMerchantAccount.Phase.none)
        XCTAssertEqual(OwnerDecisionMerchantAccount.shape(["available": false])?.phase, .unavailable)
        XCTAssertEqual(OwnerDecisionMerchantAccount.shape(["available": false])?.stateText, "—")
        let screen = try source("App/OwnerDecisionPayoutViews.swift")
        XCTAssertTrue(screen.contains("merchant.payoutAccount.loading"))
        XCTAssertTrue(screen.contains("merchant.payoutAccount.empty"))
        XCTAssertTrue(screen.contains("merchant.payoutAccount.error"))
        XCTAssertFalse(screen.contains("withdraw"))
    }

    func testOWND05cPayoutWritesSendNothingWhileClosedAndProductionRefusesThem() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        let transport = Recorder()
        let client = try makeClient(transport, payout: false)
        let awaited = await client.unbind(clubID: 9003)
        XCTAssertEqual(awaited, .notSent)
        let awaited1 = await client.saveAccount()
        XCTAssertEqual(awaited1, .notSent)
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/personal-receiver/unbind"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/personal-receiver/bind"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/payout-account/save"))
        let production = try APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com/prod-api/")!)
        ReleaseMoneyWriteSwitch.testDerivation = { _ in true }
        let forced = OwnerDecisionPayoutClient(configuration: production, transport: transport, token: "synthetic-token",
                                                payoutOpen: true, merchantWritesOpen: true)
        let awaited2 = await forced.unbind(clubID: 9003)
        XCTAssertEqual(awaited2, .notSent)
        let awaited3 = await forced.saveAccount()
        XCTAssertEqual(awaited3, .notSent)
        XCTAssertTrue(transport.requests.isEmpty)
        let lease = try source("App/ReviewedPlayerWriteLeases.swift")
        for path in ChinaReviewedRouteCapability.ownerDecisionGuardGrant {
            XCTAssertTrue(lease.contains(String(path.dropFirst())), path)
        }
        XCTAssertFalse(lease.contains("api/club/personal-receiver/bind"))
        XCTAssertTrue(lease.contains("ReviewedAreaSwitch.payout"))
        XCTAssertTrue(lease.contains("ReviewedAreaSwitch.merchantWrites"))
    }

    func testOWND06PassPurchaseStaysBehindTheCommerceGate() throws {
        let gate = try source("App/MPParityKit.swift")
        XCTAssertTrue(gate.contains("static let purchasesEnabled = false"))
        let hits = try scan("api/club/membership", roots: ["App", "Core"]) { name in
            !name.hasPrefix("UnifiedOPT") && !name.hasPrefix("Legacy52")
        }
        XCTAssertEqual(hits, [])
        let pay = try source("Core/ChinaReviewedRouteCapability.swift")
        XCTAssertTrue(pay.contains("virtual-goods"))
    }

    func testOWND08aFailedOrIncompleteQuotaShowsUnavailableAndSpendsNothing() throws {
        XCTAssertEqual(QuickPublishSimplePageContract.quotaPath, "api/ai/theme/draft/quota")
        XCTAssertThrowsError(try PublishingAIQuota(.object(["limited": .bool(true)])))
        let flow = try source("Core/PublishingAIDraftFlow.swift")
        XCTAssertTrue(flow.contains("quotaReadState != .failed"))
        XCTAssertTrue(flow.contains("contextPublish.ai.unavailable"))
        XCTAssertFalse(flow.contains("mock draft"))
        let validation = try source("Core/QuickPublishValidation.swift")
        XCTAssertTrue(validation.contains("api/ai/theme/draft/quota"))
    }

    func testOWND08bLabelsGeneratedStoriesDraftsAndAdoptedAuthors() throws {
        XCTAssertEqual(OwnerDecisionAILabel.generated, "AI 生成")
        XCTAssertEqual(OwnerDecisionAILabel.draftDescription("A story", traceID: "trace-1"), "A story  [AI 辅助生成]")
        XCTAssertEqual(OwnerDecisionAILabel.draftDescription("A story", traceID: nil), "A story")
        XCTAssertEqual(OwnerDecisionAILabel.adoptedAuthorName("Ada [AI 辅助生成]"), "Ada")
        XCTAssertNil(OwnerDecisionAILabel.adoptedAuthorName("AI 生成"))
        var draft = QuickPublishDraft()
        draft.title = "Route"
        draft.description = "A story"
        draft.aiTraceID = "trace-1"
        var node = QuickPublishNode()
        node.name = "Place"
        node.confirmedPlace = try .init(id: "local", name: "Place", address: "Street", latitude: 31, longitude: 121)
        draft.nodes = [node]
        let seed = try draft.professionalSeed()
        XCTAssertEqual(seed.preserved["aiTraceId"], .string("trace-1"))
        XCTAssertTrue(seed.description.contains("[AI 辅助生成]"))
        let story = try source("App/ClubGovernanceViews.swift")
        XCTAssertTrue(story.contains("ai_simple"))
        XCTAssertTrue(story.contains("club.story.aigc"))
    }

    func testOWND08cHasNoLongTermMemoryPaidSlotOrDefaultAI() throws {
        let banned = ["longTermNPCMemory", "paidMemorySlot", "aiMemoryEnabled = true"]
        for token in banned {
            let hits = try scan(token, roots: ["App", "Core"]) { _ in true }
            XCTAssertEqual(hits, [], token)
        }
        let scene = try source("Core/ThreeDocumentMasterCrosswalkContract.swift")
        XCTAssertTrue(scene.contains("defaultEnabled: false"))
    }

    func testOWND10HidesAnEmptyRevenueTabAndDoesNotShowZeroOnFailure() throws {
        XCTAssertEqual(OwnerDecisionRevenueGate.phase(readFailed: true, participant: true, isEmpty: false), .unavailable)
        XCTAssertEqual(OwnerDecisionRevenueGate.unavailable, "收益暂不可用")
        XCTAssertEqual(OwnerDecisionRevenueGate.phase(readFailed: false, participant: false, isEmpty: false), .hidden)
        XCTAssertEqual(OwnerDecisionRevenueGate.phase(readFailed: false, participant: true, isEmpty: true), .hidden)
        XCTAssertEqual(OwnerDecisionRevenueGate.phase(readFailed: false, participant: true, isEmpty: false), .ready)
        let hidden = G6RevenueAllocations.state(G6Envelope(httpStatus: 200, code: "200", reasonCode: "NOT_PARTICIPANT",
                                                           message: nil, dataJSON: Data("[]".utf8), netFail: false))
        XCTAssertEqual(hidden, .hidden)
        let empty = G6RevenueAllocations.state(G6Envelope(httpStatus: 200, code: "200", reasonCode: nil,
                                                          message: nil, dataJSON: Data("[]".utf8), netFail: false))
        XCTAssertEqual(empty, .hidden)
        XCTAssertEqual(G6RevenueAllocations.state(.networkFailure), .error)
        let view = try source("App/WalletCommerceViews.swift")
        XCTAssertTrue(view.contains("收益暂不可用"))
        XCTAssertTrue(view.contains("WalletAuthorRevenueTab"))
    }

    private func quote(_ json: String) throws -> RegistrationQuote {
        try JSONDecoder().decode(RegistrationQuote.self, from: Data(json.utf8))
    }

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    private func swiftFiles(in folders: [String]) throws -> [URL] {
        var urls: [URL] = []
        for folder in folders {
            let base = root.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "swift" { urls.append(url) }
        }
        return urls
    }

    private func scan(_ needle: String, roots folders: [String], include: (String) -> Bool) throws -> [String] {
        var hits: [String] = []
        for url in try swiftFiles(in: folders) where include(url.lastPathComponent) {
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains(needle) { hits.append(url.lastPathComponent) }
        }
        return hits
    }

    private func makeClient(_ transport: Recorder, payout: Bool) throws -> OwnerDecisionPayoutClient {
        let configuration = try APIConfiguration(baseURL: URL(string: "https://example.test/native/")!)
        return OwnerDecisionPayoutClient(configuration: configuration, transport: transport, token: "synthetic-token",
                                          payoutOpen: payout, merchantWritesOpen: payout)
    }
}

private final class Recorder: HTTPTransport, @unchecked Sendable {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
    }
}
