import XCTest
import Foundation
@testable import QuestifyCore

/// CL-01: one citation or absence check per OPT triage id.
/// Source scans are read-only. They do not change routes or call the network.
final class OPTTriageClosureTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ relative: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let url = repoRoot.appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("cannot read \(relative)", file: file, line: line)
            throw CocoaError(.fileReadNoSuchFile)
        }
        return text
    }

    private func assertCites(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(id.hasPrefix("OWN-OPT-"), "citation id \(id)", file: file, line: line)
    }

    private enum ContractExclusion {
        case unifiedOPT
        case unifiedOPTAndLegacy52

        func excludes(_ relative: String) -> Bool {
            let name = URL(fileURLWithPath: relative).lastPathComponent
            if name.hasPrefix("UnifiedOPT") { return true }
            if self == .unifiedOPTAndLegacy52, name.hasPrefix("Legacy52") { return true }
            return false
        }
    }

    private struct SourceHit: Equatable {
        let location: String
        let text: String
    }

    /// `grep -nE` over App and Core Swift, skipping the contract records named by CL-01.
    private func sourceHits(_ pattern: String, excluding exclusion: ContractExclusion) throws -> [SourceHit] {
        let regex = try NSRegularExpression(pattern: pattern)
        var hits: [SourceHit] = []
        let rootPath = repoRoot.path
        for directory in ["App", "Core"] {
            let base = repoRoot.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
                XCTFail("cannot enumerate \(directory)")
                continue
            }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let path = url.path
                guard path.hasPrefix(rootPath + "/") else { continue }
                let relative = String(path.dropFirst(rootPath.count + 1))
                if exclusion.excludes(relative) { continue }
                let text = try String(contentsOf: url, encoding: .utf8)
                for (offset, row) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    let line = String(row)
                    let range = NSRange(location: 0, length: (line as NSString).length)
                    guard regex.firstMatch(in: line, range: range) != nil else { continue }
                    hits.append(SourceHit(location: "\(relative):\(offset + 1)", text: line))
                }
            }
        }
        return hits.sorted { $0.location < $1.location }
    }

    func testSourceBaselineCitesOWNOPT001() throws {
        assertCites("OWN-OPT-001")
        let matrix = try source("docs/release/completeness-matrix.md")
        guard let start = matrix.range(of: "## Sources read") else {
            XCTFail("completeness-matrix.md has no Sources read section")
            return
        }
        let rest = matrix[start.upperBound...]
        let end = rest.range(of: "\n## ")?.lowerBound ?? rest.endIndex
        let section = String(rest[..<end])
        XCTAssertTrue(section.contains("e3264af9fc694cfadea419e59d31c790aa8163c1"))
        XCTAssertTrue(section.contains("067da9748"))
        XCTAssertTrue(section.contains("1ca6d3215beee96afdcdfd300dd9176f2d0ac5b3"))
        XCTAssertTrue(section.contains("TEST 8120"))
    }

    func testDecisionListCitesOWNOPT003() throws {
        assertCites("OWN-OPT-003")
        let supplement = try source("docs/owner-handover/SUPPLEMENT.md")
        XCTAssertTrue(supplement.contains("### NX-01: owner decisions (21 rows)"))
        XCTAssertTrue(supplement.contains("`OWN-D-09`"))
        XCTAssertTrue(supplement.contains("Counts: 21 decisions."))
    }

    func testRequestReceiptCitesOWNOPT070() throws {
        assertCites("OWN-OPT-070")
        let tests = try source("Tests/CoreTests/ContentContractV1Tests.swift")
        XCTAssertTrue(tests.contains("func testRequestIdempotencyVectorSeparatesFactKeyFromFingerprint"))
        let service = try source("Core/PlayExperienceService.swift")
        XCTAssertTrue(service.contains("name: \"requestId\", value: command.requestID"))
        let scope = PlayWireValue.object(["topicId": .integer(3), "nodeId": .integer(4)])
        let key = ContentContractV1.requestFactKey(memberID: 9, scope: scope, requestID: "one")
        let other = ContentContractV1.requestFactKey(memberID: 9, scope: scope, requestID: "two")
        XCTAssertNotEqual(key, other)
        let fingerprint = ContentContractV1.requestFingerprint(factKey: key, level: 1, free: true, chargedPoints: 0)
        let otherPayload = ContentContractV1.requestFingerprint(factKey: key, level: 2, free: true, chargedPoints: 0)
        XCTAssertNotEqual(fingerprint, otherPayload)
        XCTAssertTrue(fingerprint.hasPrefix(key))
    }

    func testEnvironmentGatesCitesOWNOPT071() throws {
        assertCites("OWN-OPT-071")
        let area = try source("App/ReviewedAreaSwitch.swift")
        XCTAssertTrue(area.contains("static func installReleaseMoneyDerivation(host: String?)"))
        XCTAssertTrue(area.contains("#if DEBUG || TEST"))
        let routes = try source("Core/ChinaReviewedRouteCapability.swift")
        XCTAssertTrue(routes.contains("public enum ReleaseMoneyWriteSwitch"))
        XCTAssertTrue(routes.contains("testDerivation"))
        XCTAssertTrue(routes.contains("case virtualGoods"))
    }

    func testPlayerRefundCitesOWNOPT012() throws {
        assertCites("OWN-OPT-012")
        XCTAssertEqual(OrderLifecycleAction.refund.sourcePath, "api/registration/cancel-refund")
        let coordinator = try source("Core/OrderLifecycleCoordinator.swift")
        XCTAssertTrue(coordinator.contains("case .refund: return \"api/registration/cancel-refund\""))
    }

    func testMerchantPayableCitesOWNOPT013() throws {
        assertCites("OWN-OPT-013")
        let progress = try source("App/MerchantSettlementProgressView.swift")
        XCTAssertTrue(progress.contains("struct MerchantSettlementProgressView"))
        let business = try source("App/MerchantBusinessViews.swift")
        XCTAssertTrue(business.contains("struct MerchantBusinessHomeView"))
        XCTAssertTrue(business.contains("ledgerRefundPreview"))
    }

    func testBusinessDashboardCitesOWNOPT061() throws {
        assertCites("OWN-OPT-061")
        let home = try source("App/MerchantHomeView.swift")
        XCTAssertTrue(home.contains("struct MerchantHomeView"))
        XCTAssertTrue(home.contains("Source pages/merchant/index order"))
        let inbox = try source("App/MerchantPredictionInboxView.swift")
        XCTAssertTrue(inbox.contains("struct MerchantPredictionInboxView"))
        XCTAssertTrue(inbox.contains("merchant.predict.title"))
    }

    func testCommunityChainCitesOWNOPT020() throws {
        assertCites("OWN-OPT-020")
        let root = try source("App/AppCompositionRoot.swift")
        XCTAssertTrue(root.contains("api/v1/community/"))
    }

    func testAuthorModerationCitesOWNOPT021() throws {
        assertCites("OWN-OPT-021")
        let governance = try source("Core/SquareGovernanceService.swift")
        XCTAssertTrue(governance.contains("api/v1/community/me/enforcements"))
        XCTAssertTrue(governance.contains("api/v1/community/notifications"))
        XCTAssertTrue(governance.contains("func enforcements("))
        XCTAssertTrue(governance.contains("func notifications("))
    }

    func testAuthorDraftCitesOWNOPT030() throws {
        assertCites("OWN-OPT-030")
        let editor = try source("App/ProjectEditView.swift")
        XCTAssertTrue(editor.contains("struct ProjectEditAutosaveObservation"))
        XCTAssertTrue(editor.contains("struct ProjectEditView"))
        XCTAssertTrue(editor.contains("observeDraftMutation()"))
        let coordinator = try source("Core/ProjectEditCoordinator.swift")
        XCTAssertTrue(coordinator.contains("func fabuPageModel("))
    }

    func testEndingConfigCitesOWNOPT031() throws {
        assertCites("OWN-OPT-031")
        let model = try source("Core/ProjectEditService.swift")
        XCTAssertTrue(model.contains("enum PublishFabuPageModel"))
        let service = try source("Core/PlayExperienceService.swift")
        XCTAssertTrue(service.contains("func ending(scope: PlaySessionScope, token: String)"))
        XCTAssertTrue(service.contains("request(\"api/play/ending\""))
        let journey = try source("Core/JourneyNarrativeContracts.swift")
        XCTAssertTrue(journey.contains("api/play/journey/ending"))
        let contracts = try source("Core/PlayExperienceContracts.swift")
        guard let start = contracts.range(of: "public struct PlayEndingDocument") else {
            XCTFail("PlayEndingDocument missing")
            return
        }
        let rest = contracts[start.lowerBound...]
        let end = rest.range(of: "public struct PlayCompanionLeaderboard")?.lowerBound ?? rest.endIndex
        let body = String(rest[..<end])
        XCTAssertTrue(body.contains("public let fragments"))
        XCTAssertFalse(body.contains("sort("))
        XCTAssertFalse(body.contains("reorder"))
    }

    func testCreatorRevenueCitesOWNOPT033() throws {
        assertCites("OWN-OPT-033")
        let wallet = try source("App/WalletCommerceViews.swift")
        XCTAssertTrue(wallet.contains("assetcenter/earnings"))
        XCTAssertTrue(wallet.contains("func loadEarnings("))
        XCTAssertTrue(G6CapabilitySource.paths.contains("/api/marketing/revenue/author/mine"))
        let sourceText = try source("Core/G6CapabilitySource.swift")
        XCTAssertTrue(sourceText.contains("func authorRevenue(token: String)"))
    }

    func testUnknownResultCitesOWNOPT040() throws {
        assertCites("OWN-OPT-040")
        XCTAssertEqual(PlayExperienceError.unknownResult, .unknownResult)
        let service = try source("Core/PlayExperienceService.swift")
        XCTAssertTrue(service.contains("throw PlayExperienceError.unknownResult"))
        XCTAssertTrue(service.contains("One request with no retry."))
        XCTAssertFalse(service.contains("retryHelp"))
        let coordinator = try source("Core/PlayExperienceCoordinator.swift")
        XCTAssertTrue(coordinator.contains("func reconcileRun("))
        XCTAssertTrue(coordinator.contains("PlayPausedRecord.reconcile("))
    }

    func testGPSAccuracyCitesOWNOPT041() throws {
        assertCites("OWN-OPT-041")
        let tasks = try source("Core/PlayDeviceTasks.swift")
        XCTAssertTrue(tasks.contains("enum PlayLocationMeasurement"))
        XCTAssertTrue(tasks.contains("static func validate(accuracyMeters:"))
        try PlayLocationMeasurement.validate(accuracyMeters: nil, measuredAt: nil)
        try PlayLocationMeasurement.validate(accuracyMeters: 100, measuredAt: Date())
        XCTAssertThrowsError(try PlayLocationMeasurement.validate(accuracyMeters: .nan, measuredAt: Date()))
    }

    func testOfficialActivityCitesOWNOPT051() throws {
        assertCites("OWN-OPT-051")
        let organizer = try source("App/OfficialOrganizerConsoleView.swift")
        XCTAssertTrue(organizer.contains("class OfficialOrganizerConsoleModel"))
        XCTAssertTrue(organizer.contains("pages/activity/official-organizer"))
        let detail = try source("App/OfficialEventDetailView.swift")
        XCTAssertTrue(detail.contains("struct OfficialEventDetailView"))
        XCTAssertTrue(detail.contains("pages/activity/official-detail/index"))
    }

    func testBroadcastTodosCitesOWNOPT053() throws {
        assertCites("OWN-OPT-053")
        let notify = try source("App/ClubOpsNotifySections.swift")
        XCTAssertTrue(notify.contains("struct ClubOpsNotifyAudienceRows"))
        XCTAssertTrue(notify.contains("pages/club/notify"))
        let inbox = try source("App/OfficialPrivateViews.swift")
        XCTAssertTrue(inbox.contains("struct OfficialInboxView"))
        XCTAssertTrue(inbox.contains("pages/activity/official-inbox/index"))
    }

    func testAISafetyCitesOWNOPT080() throws {
        assertCites("OWN-OPT-080")
        XCTAssertEqual(PublishingContracts.safetyPrecheck([:]).path, "api/ai/safety/precheck")
        let auxiliary = try source("Core/PublishingAuxiliaryService.swift")
        XCTAssertTrue(auxiliary.contains("request.path == \"api/ai/safety/precheck\""))
    }

    func testNPCDataCitesOWNOPT081() throws {
        assertCites("OWN-OPT-081")
        XCTAssertEqual(NPCChatLogDeletion.path, "api/ai/npc/chat/data/delete")
        XCTAssertEqual(NPCChatData.path, "api/ai/npc/chat/data/export")
        let deletion = try source("Core/NPCChatLogDeletion.swift")
        XCTAssertTrue(deletion.contains("enum NPCChatLogDeletion"))
        let data = try source("Core/NPCChatData.swift")
        XCTAssertTrue(data.contains("struct NPCChatData"))
    }

    func testLegacyLeadReviewAbsenceCitesOWNOPT002() throws {
        assertCites("OWN-OPT-002")
        let register = try source("docs/release/cb70-gap-register.md")
        XCTAssertTrue(register.contains("does not re-scan `App/` or `Core/`"))
        let hits = try sourceHits("totalLegacyClues|509Defect|legacyClueReview|509条", excluding: .unifiedOPT)
        XCTAssertEqual(hits.map(\.location), [])
    }

    func testCartCallSiteAbsenceCitesOWNOPT011() throws {
        assertCites("OWN-OPT-011")
        let hits = try sourceHits(#""/?api/cart/(add|settlement|submit)"#, excluding: .unifiedOPT)
        let locations = hits.map(\.location)
        XCTAssertEqual(locations, [
            "Core/ChinaReviewedRouteCapability.swift:2559",
            "Core/ChinaReviewedRouteCapability.swift:757",
            "Core/WalletCommerceSafety.swift:323",
            "Core/WalletCommerceService.swift:76",
            "Core/WalletCommerceSyntheticFixtures.swift:63",
        ])
        let byLocation = Dictionary(uniqueKeysWithValues: hits.map { ($0.location, $0.text) })
        XCTAssertTrue(byLocation["Core/WalletCommerceSafety.swift:323"]?.contains("\"api/cart/settlement\"") == true)
        XCTAssertTrue(byLocation["Core/WalletCommerceService.swift:76"]?.contains("send(path: \"api/cart/settlement\"") == true)
        XCTAssertTrue(byLocation["Core/WalletCommerceSyntheticFixtures.swift:63"]?.contains("\"/api/cart/settlement\"") == true)
        XCTAssertTrue(byLocation["Core/ChinaReviewedRouteCapability.swift:757"]?.contains("\"/api/cart/settlement\"") == true)
        let blockList = byLocation["Core/ChinaReviewedRouteCapability.swift:2559"] ?? ""
        XCTAssertTrue(blockList.contains("\"/api/cart/add\""))
        XCTAssertFalse(blockList.contains("send("))
        let joined = hits.map(\.text).joined(separator: "\n")
        XCTAssertFalse(joined.contains("send(path: \"api/cart/add\""))
        XCTAssertFalse(joined.contains("send(path: \"api/cart/submit\""))
        let safety = try source("Core/WalletCommerceSafety.swift")
        XCTAssertTrue(safety.contains("never accepts cart mutations"))
    }

    func testContentChainSwitchAbsenceCitesOWNOPT023() throws {
        assertCites("OWN-OPT-023")
        let hits = try sourceHits("B-stack|bStack|contentChainSwitch|switchContentChain|flipSurfaceChain|chainMigration", excluding: .unifiedOPT)
        XCTAssertEqual(hits.map(\.location), [])
        let square = try source("Core/SquareService.swift")
        XCTAssertTrue(square.contains("api/v1/community/feeds/"))
        XCTAssertTrue(square.contains("no legacy fallback exists"))
    }

    func testDuesAbsenceCitesOWNOPT050() throws {
        assertCites("OWN-OPT-050")
        let hits = try sourceHits("api/club/membership|会费|duesPlan|membershipFee|ClubDues", excluding: .unifiedOPTAndLegacy52)
        XCTAssertEqual(hits.map(\.location), [])
    }
}
