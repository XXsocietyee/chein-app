import XCTest
@testable import QuestifyCore

@MainActor final class ModUpgradeAdapterTests: XCTestCase {
    private let fixtureHash = String(repeating: "a", count: 64)
    private func context() throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: "https://example.com/native")!, role: "merchant",
              session: try .init(accountID: 7, epoch: 1, namespace: "synthetic-upgrade-adapter", token: "synthetic-session", role: "merchant"))
    }
    private func selection() throws -> ModUpgradeIntent {
        let source = ModInstallationIdentity(licenseId: "old-license", moduleId: "module", releaseId: "old", contentHash: fixtureHash, termsHash: fixtureHash)
        let terms = WorkshopCommerceTerms(version: "synthetic-terms-v1", hash: fixtureHash, contentHash: fixtureHash,
            commercialUse: true, allowedRegions: ["region"], installationLimit: 1,
            useDuration: "PERPETUAL_PURCHASED_VERSION", updatePolicy: "EXACT_PURCHASED_VERSION",
            redistribution: "PROHIBITED", refundPolicyReference: "synthetic-refund-policy")
        let candidate = ModUpgradeCandidate(offerId: "offer", title: "New version", targetReleaseId: "new", targetContentHash: fixtureHash,
            targetTermsHash: fixtureHash, packageId: nil, packageVersion: nil, ordering: .otherReviewedRelease,
            authorization: .authorized, targetLicenseId: "new-license", comparisonHash: fixtureHash, changedFields: ["fields.title"],
            requiredBindings: [], compatibility: .compatible, conflicts: [],
            termsComparison: .init(schema: "mod-upgrade-frozen-terms-v1", creatorId: 7, source: terms, target: terms))
        return try .init(source: source, candidate: candidate, confirmedByBuyer: true)
    }
    private final class Memory: TemplateAuthoringStorage {
        var values: [String: Data] = [:]
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { values[key] = data }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    private final class Base: ModInstallationServing {
        var isCurrent = true
        var canMutate = true
        var basePrepareCalls = 0
        var installCalls = 0
        let value: ModInstallationOptions
        init(identity: ModInstallationIdentity, hash: String) {
            value = .init(schema: "mod-installation-options-v1", licenseId: identity.licenseId, moduleId: identity.moduleId,
                releaseId: identity.releaseId, contentHash: identity.contentHash, termsHash: identity.termsHash, title: "Reviewed new content", requiredBindings: [],
                merchants: [.init(kind: .site, id: 10, merchantId: 10, label: "Store", region: nil, fingerprint: hash)],
                resources: [.init(kind: .poi, id: 20, merchantId: 10, label: "Entry", region: "region", fingerprint: hash)])
        }
        func invalidate() { isCurrent = false }
        func options(identity: ModInstallationIdentity, merchantId: Int64?) async throws -> ModInstallationOptions {
            let result = ModInstallationOptions(schema: value.schema, licenseId: value.licenseId, moduleId: value.moduleId,
                releaseId: value.releaseId, contentHash: value.contentHash, termsHash: value.termsHash, title: value.title,
                requiredBindings: value.requiredBindings, merchants: value.merchants,
                resources: merchantId == nil ? [] : value.resources)
            try result.validate(licenseId: identity.licenseId, merchantId: merchantId)
            return result
        }
        func prepare(_ attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt { basePrepareCalls += 1; throw ModInstallationIssue.unavailable }
        func request(_ requestId: String, identity: ModInstallationIdentity) async throws -> ModInstallationReceipt { throw ModInstallationIssue.requestNotFound }
        func install(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt { installCalls += 1; return prepared }
        func cancel(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt { prepared }
        func preview(_ receipt: ModInstallationReceipt) async throws -> ModInstallationPreview {
            .init(schema: "mod-installation-preview-v1", requestId: receipt.requestId, licenseId: receipt.licenseId, bindingHash: receipt.bindingHash, fields: ["title": "New full content"])
        }
        func facts(_ receipt: ModInstallationReceipt) async throws -> ModInstallationFacts { throw ModInstallationIssue.unavailable }
        func confirmFacts(_ facts: ModInstallationFacts, receipt: ModInstallationReceipt) async throws -> ModInstallationFacts { throw ModInstallationIssue.unavailable }
        func history(identity: ModInstallationIdentity) async throws -> [ModInstallationReceipt] { [] }
    }
    private final class Upgrade: ModUpgradeServing {
        var isCurrent = true
        var canStage = true
        var loseResponse = false
        var reject = false
        var stageKeys: [String] = []
        var readKeys: [String] = []
        var receipts: [String: ModInstallationReceipt] = [:]
        var beforeStage: ((ModUpgradeIntent) throws -> Void)?
        func invalidate() { isCurrent = false }
        func versions(source: ModInstallationIdentity, before: String?) async throws -> ModUpgradeVersionPage { throw ModUpgradeIssue.unavailable }
        func stage(_ intent: ModUpgradeIntent, attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt {
            try beforeStage?(intent); stageKeys.append(attempt.request.requestId)
            if reject { throw ModUpgradeIssue.preflightRejected("UPGRADE_PREFLIGHT_REJECTED: BINDING_CHANGED") }
            let value = ModInstallationReceipt(schema: "mod-installation-receipt-v1", requestId: attempt.request.requestId,
                licenseId: attempt.identity.licenseId, moduleId: attempt.identity.moduleId, releaseId: attempt.identity.releaseId,
                contentHash: attempt.identity.contentHash, termsHash: attempt.identity.termsHash, state: .prepared,
                merchantId: attempt.request.merchantId, anchorPoiId: attempt.request.anchorPoiId, region: attempt.region,
                bindingHash: attempt.identity.contentHash, draftId: nil, editKind: "MEMBER_TEMPLATE", createdAt: "2026-10-21T00:00:00Z",
                errorCode: nil, published: false, executable: false,
                requiredGates: ["MERCHANT_FACT_CONFIRMATION", "THEME_CONTENT_REVIEW", "W02_PUBLISH"], bindings: attempt.bindings)
            receipts[value.requestId] = value
            if loseResponse { throw ModUpgradeIssue.unavailable }
            return value
        }
        func request(_ intent: ModUpgradeIntent) async throws -> ModInstallationReceipt {
            let key = try XCTUnwrap(intent.installation?.requestId); readKeys.append(key)
            guard let receipt = receipts[key] else { throw ModUpgradeIssue.notFound }; return receipt
        }
    }
    func testLostStageResponseRecoversOriginalWithoutSecondPrepare() async throws {
        let selected = try selection(), target = try XCTUnwrap(selected.target), memory = Memory(), context = try context()
        let intents = ModUpgradeIntentStore(storage: memory, context: context, source: selected.source); try intents.begin(selected)
        let pending = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: memory, source: selected.source), context: context, identity: target)
        let base = Base(identity: target, hash: fixtureHash), upgrade = Upgrade(); upgrade.loseResponse = true
        upgrade.beforeStage = { sent in XCTAssertEqual(try intents.load(), sent); XCTAssertEqual(try pending.load()?.request, sent.installation) }
        let adapter = try ModUpgradeInstallationService(base: base, upgrade: upgrade, intents: intents, pending: pending, selected: selected)
        let controller = ModInstallationController(identity: target, service: adapter, store: pending)
        await controller.recover(); XCTAssertTrue(controller.canSelect)
        await controller.selectMerchant(10); controller.selectAnchor(20); XCTAssertTrue(controller.canPrepare)
        await controller.prepare()
        let original = try XCTUnwrap(controller.attempt?.request.requestId)
        XCTAssertNil(controller.receipt); XCTAssertEqual(upgrade.stageKeys, [original]); XCTAssertEqual(base.basePrepareCalls, 0)
        await controller.recover()
        XCTAssertEqual(controller.receipt?.requestId, original); XCTAssertEqual(upgrade.stageKeys, [original])
        XCTAssertFalse(controller.canStartAnother)
        upgrade.canStage = false
        await controller.confirmInstall(try XCTUnwrap(controller.receipt)); XCTAssertEqual(base.installCalls, 0)
    }
    func testCrashBetweenJournalsBindsSameOriginalAnd404DoesNotWrite() async throws {
        let selected = try selection(), target = try XCTUnwrap(selected.target), memory = Memory(), context = try context()
        let intents = ModUpgradeIntentStore(storage: memory, context: context, source: selected.source); try intents.begin(selected)
        let pending = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: memory, source: selected.source), context: context, identity: target)
        let base = Base(identity: target, hash: fixtureHash), upgrade = Upgrade()
        let original = try ModInstallationAttempt(options: base.value, merchantId: 10, anchorPoiId: 20, selections: [:]); try pending.begin(original)
        let adapter = try ModUpgradeInstallationService(base: base, upgrade: upgrade, intents: intents, pending: pending, selected: selected)
        let controller = ModInstallationController(identity: target, service: adapter, store: pending)
        await controller.recover()
        XCTAssertEqual(try intents.load()?.installation, original.request); XCTAssertTrue(controller.canRetryOriginalPrepare)
        XCTAssertEqual(upgrade.stageKeys, [])
        await controller.retryOriginalPrepare()
        XCTAssertEqual(upgrade.stageKeys, [original.request.requestId]); XCTAssertEqual(controller.receipt?.requestId, original.request.requestId)
    }
    func testDefiniteRejectionDurableBeforeClearingNoReceiptJournal() async throws {
        let selected = try selection(), target = try XCTUnwrap(selected.target), memory = Memory(), context = try context()
        let intents = ModUpgradeIntentStore(storage: memory, context: context, source: selected.source); try intents.begin(selected)
        let pending = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: memory, source: selected.source), context: context, identity: target)
        let base = Base(identity: target, hash: fixtureHash), upgrade = Upgrade(); upgrade.reject = true
        let adapter = try ModUpgradeInstallationService(base: base, upgrade: upgrade, intents: intents, pending: pending, selected: selected)
        let controller = ModInstallationController(identity: target, service: adapter, store: pending)
        await controller.recover(); XCTAssertTrue(controller.canSelect)
        await controller.selectMerchant(10); controller.selectAnchor(20); XCTAssertTrue(controller.canPrepare)
        await controller.prepare()
        XCTAssertNil(try pending.load()); XCTAssertNotNil(try intents.load()?.rejectionReason)
        XCTAssertFalse(adapter.canMutate); XCTAssertFalse(controller.canPrepare)
        XCTAssertThrowsError(try intents.abandonRejected(selected))
        let rejected = try XCTUnwrap(intents.load()); try intents.abandonRejected(rejected)
        XCTAssertNil(try intents.load())
    }
    func testCancelledOriginalCanBeExplicitlyFinishedWithoutAnotherStage() async throws {
        let selected = try selection(), target = try XCTUnwrap(selected.target), memory = Memory(), context = try context()
        let intents = ModUpgradeIntentStore(storage: memory, context: context, source: selected.source); try intents.begin(selected)
        let pending = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: memory, source: selected.source), context: context, identity: target)
        let base = Base(identity: target, hash: fixtureHash), upgrade = Upgrade()
        let attempt = try ModInstallationAttempt(options: base.value, merchantId: 10, anchorPoiId: 20, selections: [:])
        try pending.begin(attempt); let original = try intents.bind(attempt)
        let prepared = try await upgrade.stage(original, attempt: attempt); _ = try pending.accept(prepared)
        var raw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(prepared)) as! [String: Any]
        raw["state"] = "CANCELLED"
        let cancelled = try JSONDecoder().decode(ModInstallationReceipt.self, from: JSONSerialization.data(withJSONObject: raw))
        upgrade.receipts[prepared.requestId] = cancelled
        let sourceController = ModUpgradeController(source: selected.source, service: upgrade, store: intents,
            finishUninstalledJournal: { saved, verified in
                XCTAssertEqual(saved.installation?.requestId, verified.requestId)
                _ = try pending.accept(verified); try pending.finish(verified)
            })
        await sourceController.recover(); await sourceController.finishUninstalledOriginal()
        XCTAssertNil(try intents.load()); XCTAssertNil(try pending.load())
        XCTAssertEqual(upgrade.stageKeys, [attempt.request.requestId])
    }

}
