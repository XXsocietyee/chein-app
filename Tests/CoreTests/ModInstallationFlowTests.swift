import XCTest
@testable import QuestifyCore

@MainActor final class ModInstallationFlowTests: XCTestCase {
    private let fixtureHash = String(repeating: "a", count: 64)
    private func context(account: Int = 7, epoch: UInt64 = 1) throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: "https://example.com/native")!, role: "merchant",
              session: try .init(accountID: account, epoch: epoch, namespace: "synthetic-installation", token: "synthetic-session", role: "merchant"))
    }
    private func options() -> ModInstallationOptions {
        .init(schema: "mod-installation-options-v1", licenseId: "license-1", moduleId: "module-1", releaseId: "release-1",
              contentHash: fixtureHash, termsHash: fixtureHash, title: "Licensed native test content",
              requiredBindings: [.init(key: "home", kind: .site)],
              merchants: [.init(kind: .site, id: 10, merchantId: 10, label: "Owned store", region: nil, fingerprint: fixtureHash)],
              resources: [.init(kind: .site, id: 10, merchantId: 10, label: "Owned store", region: nil, fingerprint: fixtureHash),
                          .init(kind: .poi, id: 20, merchantId: 10, label: "Owned map entry", region: "test-city", fingerprint: fixtureHash)])
    }
    private func attempt() throws -> ModInstallationAttempt {
        try .init(options: options(), merchantId: 10, anchorPoiId: 20, selections: ["SITE:home": 10])
    }
    private func receipt(_ attempt: ModInstallationAttempt, state: ModInstallationReceipt.State = .prepared) -> ModInstallationReceipt {
        .init(schema: "mod-installation-receipt-v1", requestId: attempt.request.requestId, licenseId: "license-1", moduleId: "module-1",
              releaseId: "release-1", contentHash: fixtureHash, termsHash: fixtureHash, state: state, merchantId: 10, anchorPoiId: 20,
              region: "test-city", bindingHash: fixtureHash, draftId: state == .installed ? 30 : nil, editKind: "MEMBER_TEMPLATE",
              createdAt: "2026-10-21T00:00:00.000000Z", errorCode: state == .failed ? "DRAFT_MATERIALIZATION_FAILED" : nil,
              published: false, executable: false, requiredGates: ["MERCHANT_FACT_CONFIRMATION", "THEME_CONTENT_REVIEW", "W02_PUBLISH"], bindings: attempt.bindings)
    }
    private final class Memory: TemplateAuthoringStorage {
        var values: [String: Data] = [:]
        var failWrite = false
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws {
            if failWrite { throw ModInstallationIssue.storageUnavailable }; values[key] = data
        }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    func testRealSiteProjectionAndStrictPlaceholderContract() throws {
        try options().validate(licenseId: "license-1", merchantId: 10)
        XCTAssertThrowsError(try ModInstallationValidation.placeholder("7invalid"))
        XCTAssertThrowsError(try ModInstallationValidation.placeholder(String(repeating: "a", count: 49)))
        XCTAssertThrowsError(try ModInstallationAttempt(options: options(), merchantId: 10, anchorPoiId: 99, selections: ["SITE:home": 10]))
        XCTAssertThrowsError(try ModInstallationAttempt(options: options(), merchantId: 10, anchorPoiId: 20, selections: [:]))
    }
    func testPendingRequestSurvivesRelaunchAndReloginWithoutNewID() throws {
        let original = try attempt(), memory = Memory(), first = ModInstallationPendingStore(storage: memory, context: try context(), identity: options().identity)
        try first.begin(original)
        let restored = ModInstallationPendingStore(storage: memory, context: try context(epoch: 2), identity: options().identity)
        XCTAssertEqual(try restored.load(), original)
        XCTAssertNil(try ModInstallationPendingStore(storage: memory, context: context(account: 8), identity: options().identity).load())
        XCTAssertThrowsError(try first.begin(attempt()))
        XCTAssertEqual(try restored.load()?.request.requestId, original.request.requestId)
    }
    func testStorageFailureCannotBeginNetworkMutation() throws {
        let memory = Memory(); memory.failWrite = true
        let store = ModInstallationPendingStore(storage: memory, context: try context(), identity: options().identity)
        XCTAssertThrowsError(try store.begin(attempt())); XCTAssertNil(try store.load())
    }
    func testOriginalReceiptIsRequiredBeforeEditingAndClearingPending() throws {
        let original = try attempt(), memory = Memory()
        let store = ModInstallationPendingStore(storage: memory, context: try context(), identity: options().identity)
        try store.begin(original)
        let prepared = receipt(original)
        XCTAssertNil(prepared.memberTemplateID)
        _ = try store.accept(prepared); _ = try store.markDispatch(.install, confirmed: prepared)
        XCTAssertThrowsError(try store.discardRejectedPreflight(requestId: original.request.requestId))
        let installed = receipt(original, state: .installed)
        XCTAssertEqual(installed.memberTemplateID?.rawValue, 30)
        _ = try store.accept(installed); try store.finish(installed); XCTAssertNil(try store.load())
    }
    func testStrictProjectionRejectsClientAuthorityOrExecutableFields() throws {
        let original = try attempt(), receipt = receipt(original)
        let data = try JSONSerialization.data(withJSONObject: ["code": 200, "data": JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt))])
        try ModInstallationWire.validate(data, route: "requests/" + original.request.requestId)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var row = try XCTUnwrap(root["data"] as? [String: Any]); row["executableCode"] = "not-allowed"; root["data"] = row
        XCTAssertThrowsError(try ModInstallationWire.validate(JSONSerialization.data(withJSONObject: root), route: "requests/" + original.request.requestId))
    }
    func testPreviewMustMatchOriginalBoundReceiptAndNativeFieldAllowlist() throws {
        let original = try attempt(), prepared = receipt(original)
        try ModInstallationPreview(schema: "mod-installation-preview-v1", requestId: prepared.requestId, licenseId: prepared.licenseId,
            bindingHash: prepared.bindingHash, fields: ["title": "Native content", "ruleInstructions": "Owned store (#10)"]).validate(receipt: prepared)
        XCTAssertThrowsError(try ModInstallationPreview(schema: "mod-installation-preview-v1", requestId: prepared.requestId,
            licenseId: prepared.licenseId, bindingHash: prepared.bindingHash,
            fields: ["title": "Native content", "ruleInstructions": "{{SITE:home}}", "script": "forbidden"]).validate(receipt: prepared))
    }
}
