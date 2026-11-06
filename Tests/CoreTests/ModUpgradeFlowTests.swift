import XCTest
@testable import QuestifyCore

/// Executable XCTest coverage supplied for an authorized Swift host. Not executed by parser-only local checks.
@MainActor final class ModUpgradeFlowTests: XCTestCase {
    private let fixtureHash = String(repeating: "a", count: 64)
    private func context(account: Int = 7, epoch: UInt64 = 1, base: String = "https://example.com/native") throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: base)!, role: "merchant",
              session: try .init(accountID: account, epoch: epoch, namespace: "synthetic-upgrade", token: "synthetic-session", role: "merchant"))
    }
    private var source: ModInstallationIdentity { .init(licenseId: "old-license", moduleId: "module-1", releaseId: "old-release", contentHash: fixtureHash, termsHash: fixtureHash) }
    private func candidate(authorized: Bool = true, compatibility: ModUpgradeCandidate.Compatibility = .compatible,
                           includeTerms: Bool = true) -> ModUpgradeCandidate {
        let terms = WorkshopCommerceTerms(version: "synthetic-terms-v1", hash: fixtureHash, contentHash: fixtureHash,
            commercialUse: true, allowedRegions: ["region"], installationLimit: 1,
            useDuration: "PERPETUAL_PURCHASED_VERSION", updatePolicy: "EXACT_PURCHASED_VERSION",
            redistribution: "PROHIBITED", refundPolicyReference: "synthetic-refund-policy")
        return .init(offerId: "offer-2", title: "Reviewed release", targetReleaseId: "other-release", targetContentHash: fixtureHash,
              targetTermsHash: fixtureHash, packageId: nil, packageVersion: nil, ordering: .otherReviewedRelease,
              authorization: authorized ? .authorized : .acquisitionRequired, targetLicenseId: authorized ? "new-license" : nil,
              comparisonHash: fixtureHash, changedFields: ["fields.title"], requiredBindings: [], compatibility: compatibility,
              conflicts: compatibility == .blocked ? ["UNSUPPORTED_CAPABILITY"] : [],
              termsComparison: includeTerms ? .init(schema: "mod-upgrade-frozen-terms-v1", creatorId: 7, source: terms, target: terms) : nil)
    }
    private func attempt(_ target: ModInstallationIdentity) throws -> ModInstallationAttempt {
        let options = ModInstallationOptions(schema: "mod-installation-options-v1", licenseId: target.licenseId,
            moduleId: target.moduleId, releaseId: target.releaseId, contentHash: target.contentHash, termsHash: target.termsHash,
            title: "New licensed content", requiredBindings: [],
            merchants: [.init(kind: .site, id: 10, merchantId: 10, label: "Store", region: nil, fingerprint: fixtureHash)],
            resources: [.init(kind: .poi, id: 20, merchantId: 10, label: "Entry", region: "region", fingerprint: fixtureHash)])
        return try .init(options: options, merchantId: 10, anchorPoiId: 20, selections: [:])
    }
    private final class Memory: TemplateAuthoringStorage {
        var values: [String: Data] = [:]
        var failWrite = false
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { if failWrite { throw ModUpgradeIssue.storageUnavailable }; values[key] = data }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    private final class Fake: ModUpgradeServing {
        var isCurrent = true
        var canStage = true
        var page: ModUpgradeVersionPage
        var stageCalls = 0
        var readCalls = 0
        init(page: ModUpgradeVersionPage) { self.page = page }
        func invalidate() { isCurrent = false }
        func versions(source: ModInstallationIdentity, before: String?) async throws -> ModUpgradeVersionPage { readCalls += 1; return page }
        func stage(_ intent: ModUpgradeIntent, attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt { stageCalls += 1; throw ModUpgradeIssue.unavailable }
        func request(_ intent: ModUpgradeIntent) async throws -> ModInstallationReceipt { readCalls += 1; throw ModUpgradeIssue.notFound }
    }
    private func page(_ rows: [ModUpgradeCandidate]) -> ModUpgradeVersionPage {
        .init(schema: "mod-upgrade-versions-v1", source: source, sourceTitle: "Original", candidates: rows, nextCursor: nil)
    }
    func testExactNewLicenseRequiredWithoutExtendingOldTerms() throws {
        try candidate().validate(source: source)
        XCTAssertNotEqual(candidate().identity(source: source)?.licenseId, source.licenseId)
        XCTAssertNil(candidate(authorized: false).identity(source: source))
        XCTAssertThrowsError(try ModUpgradeIntent(source: source, candidate: candidate(authorized: false), confirmedByBuyer: true))
        XCTAssertThrowsError(try ModUpgradeIntent(source: source, candidate: candidate(), confirmedByBuyer: false))
        XCTAssertThrowsError(try ModUpgradeIntent(source: source, candidate: candidate(compatibility: .blocked), confirmedByBuyer: true))
    }
    func testOriginalIntentAndRequestSurviveRestartAndRelogin() throws {
        let memory = Memory(), first = ModUpgradeIntentStore(storage: memory, context: try context(), source: source)
        let selected = try ModUpgradeIntent(source: source, candidate: candidate(), confirmedByBuyer: true)
        try first.begin(selected)
        let command = try attempt(XCTUnwrap(selected.target))
        let original = try first.bind(command)
        let reloaded = ModUpgradeIntentStore(storage: memory, context: try context(epoch: 2), source: source)
        XCTAssertEqual(try reloaded.load(), original)
        XCTAssertEqual(try reloaded.load()?.installation?.requestId, command.request.requestId)
        XCTAssertThrowsError(try reloaded.bind(attempt(XCTUnwrap(selected.target))))
        XCTAssertNil(try ModUpgradeIntentStore(storage: memory, context: context(account: 8), source: source).load())
        XCTAssertNil(try ModUpgradeIntentStore(storage: memory, context: context(base: "https://other.example.com/native"), source: source).load())
    }
    func testIntentWriteFailureAndExactStageShape() throws {
        let memory = Memory(), store = ModUpgradeIntentStore(storage: memory, context: try context(), source: source)
        let selected = try ModUpgradeIntent(source: source, candidate: candidate(), confirmedByBuyer: true)
        memory.failWrite = true; XCTAssertThrowsError(try store.begin(selected)); XCTAssertNil(try store.load())
        memory.failWrite = false; try store.begin(selected)
        let saved = try store.bind(attempt(XCTUnwrap(selected.target)))
        let raw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ModUpgradeStageCommand(intent: saved))) as! [String: Any]
        XCTAssertEqual(Set(raw.keys), Set(["sourceLicenseId", "offerId", "comparisonHash", "confirmedByBuyer", "installation"]))
        XCTAssertNil(raw["targetLicenseId"]); XCTAssertNil(raw["sourcePayload"])
    }
    func testMetadataWireRejectsUnknownLicensedPayload() throws {
        let encoded = try JSONEncoder().encode(page([candidate()]))
        var root = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        let envelope = try JSONSerialization.data(withJSONObject: ["code": 200, "data": root])
        try ModUpgradeWire.versions(envelope)
        var rows = root["candidates"] as! [[String: Any]]
        rows[0]["newAnswers"] = "not permitted before acquisition"; root["candidates"] = rows
        XCTAssertThrowsError(try ModUpgradeWire.versions(JSONSerialization.data(withJSONObject: ["code": 200, "data": root])))
    }
    func testSelectionConfirmationDoesNotSendPrepareAndRecoverIsReadOnly() async throws {
        let memory = Memory(), store = ModUpgradeIntentStore(storage: memory, context: try context(), source: source)
        let server = Fake(page: page([candidate()]))
        let controller = ModUpgradeController(source: source, service: server, store: store)
        await controller.recover(); controller.select(candidate())
        controller.confirm(candidate(), confirmedByBuyer: false); XCTAssertNil(try store.load())
        controller.confirm(candidate(), confirmedByBuyer: true); XCTAssertNotNil(try store.load())
        await controller.recover()
        XCTAssertEqual(server.stageCalls, 0); XCTAssertNotNil(controller.intent)
    }
    func testMissingFrozenTermsCannotConfirmOrStage() async throws {
        let selected = candidate(includeTerms: false)
        try selected.validate(source: source)
        XCTAssertThrowsError(try ModUpgradeIntent(source: source, candidate: selected, confirmedByBuyer: true)) {
            XCTAssertEqual($0 as? ModUpgradeIssue, .selectionChanged)
        }
        let memory = Memory(), store = ModUpgradeIntentStore(storage: memory, context: try context(), source: source)
        let server = Fake(page: page([selected]))
        let controller = ModUpgradeController(source: source, service: server, store: store)
        await controller.recover(); controller.select(selected)
        XCTAssertFalse(controller.canConfirm)
        controller.confirm(selected, confirmedByBuyer: true)
        XCTAssertNil(try store.load()); XCTAssertNil(controller.intent)
        XCTAssertEqual(server.stageCalls, 0)
    }

    func testUnapprovedAndRevokedSelectionCannotAdvance() async throws {
        let memory = Memory(), store = ModUpgradeIntentStore(storage: memory, context: try context(), source: source)
        let server = Fake(page: page([candidate()]))
        let controller = ModUpgradeController(source: source, service: server, store: store)
        await controller.recover(); controller.select(candidate()); server.canStage = false
        XCTAssertFalse(controller.canConfirm); controller.confirm(candidate(), confirmedByBuyer: true); XCTAssertNil(try store.load())
        server.canStage = true; server.isCurrent = false
        controller.confirm(candidate(), confirmedByBuyer: true); XCTAssertNil(try store.load())
    }
    func testInstallationJournalIsSeparateFromOriginalAndDirectTarget() throws {
        let memory = Memory(), target = try XCTUnwrap(candidate().identity(source: source))
        let journal = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: memory, source: source), context: try context(), identity: target)
        let original = try attempt(target); try journal.begin(original)
        XCTAssertNil(try ModInstallationPendingStore(storage: memory, context: context(), identity: target).load())
        XCTAssertNil(try ModInstallationPendingStore(storage: memory, context: context(), identity: source).load())
        XCTAssertEqual(try journal.load(), original)
    }
    func testUnsubmittedCancellationCannotDiscardCrashGapOriginal() async throws {
        let memory = Memory(), context = try context(), selected = try ModUpgradeIntent(source: source, candidate: candidate(), confirmedByBuyer: true)
        let target = try XCTUnwrap(selected.target)
        let store = ModUpgradeIntentStore(storage: memory, context: context, source: source)
        let pending = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: memory, source: source), context: context, identity: target)
        try store.begin(selected)
        let server = Fake(page: page([candidate()]))
        let controller = ModUpgradeController(source: source, service: server, store: store, verifyUnstagedJournalEmpty: { _ in
            guard try pending.load() == nil else { throw ModUpgradeIssue.pendingConflict }
        })
        await controller.recover(); controller.discardUnstaged(); XCTAssertNil(try store.load())
        try store.begin(selected); try pending.begin(attempt(target)); await controller.recover()
        controller.discardUnstaged()
        XCTAssertEqual(try store.load(), selected); XCTAssertNotNil(try pending.load())
    }

}
