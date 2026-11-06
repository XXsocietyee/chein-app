import XCTest
@testable import Questify

/// Host composition tests are authored, not executed without the Apple toolchain.
@MainActor final class ModInstallationSavedRehearsalViewTests: XCTestCase {
    private func context() throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: "https://chengyin-appunit-fixture.example.test")!, role: "merchant", session: try .init(accountID: 7, epoch: 1, namespace: "synthetic-installed-host", token: "synthetic", role: "merchant"))
    }
    private func installation() -> ModInstallationReceipt {
        let hash = String(repeating: "a", count: 64)
        return .init(schema: "mod-installation-receipt-v1", requestId: "00000000-0000-0000-0000-000000000001", licenseId: "license", moduleId: "module", releaseId: "release", contentHash: hash, termsHash: hash, state: .installed, merchantId: 10, anchorPoiId: 20, region: "test", bindingHash: hash, draftId: 30, editKind: "MEMBER_TEMPLATE", createdAt: "2026-10-21T00:00:00.000000Z", errorCode: nil, published: false, executable: false, requiredGates: ["MERCHANT_FACT_CONFIRMATION", "THEME_CONTENT_REVIEW", "W02_PUBLISH"], bindings: [])
    }
    private final class Memory: TemplateAuthoringStorage {
        func read(_ key: String) throws -> Data? { nil }
        func write(_ data: Data, key: String) throws { XCTFail("Composition must not write") }
        func remove(_ key: String) throws { XCTFail("Composition must not remove") }
    }
    func testRealCompositionForwardsIndependentReadGrantToInstalledEditor() throws {
        let context = try context(), installation = installation()
        var approval: ModInstallationApproval? = try .init(context: context, expiresAt: Date().addingTimeInterval(60), readApprovalReference: "synthetic-read", templateRehearsalReadApprovalReference: "synthetic-rehearsal")
        let controller = try XCTUnwrap(ModInstallationComposition.make(reference: installation.identity, context: context, approval: approval, currentApproval: { approval }, current: { context }, storage: Memory()))
        let editor = try XCTUnwrap(controller.templateEditor(installation))
        XCTAssertTrue(editor.savedRehearsalReadEnabled)
        XCTAssertFalse(editor.canReadSavedRehearsal) // It must still load the real saved editor state first.
        XCTAssertFalse(editor.canEdit); XCTAssertFalse(editor.canSubmitReview)
        approval = nil; XCTAssertFalse(editor.savedRehearsalReadEnabled)
    }
    func testRealCompositionDefaultsOffEvenWithInstallAndReviewGrants() throws {
        let context = try context(), installation = installation()
        let approval = try ModInstallationApproval(context: context, expiresAt: Date().addingTimeInterval(60), readApprovalReference: "synthetic-read", installApprovalReference: "synthetic-install", templateReviewApprovalReference: "synthetic-review")
        let controller = try XCTUnwrap(ModInstallationComposition.make(reference: installation.identity, context: context, approval: approval, currentApproval: { approval }, current: { context }, storage: Memory()))
        XCTAssertFalse(try XCTUnwrap(controller.templateEditor(installation)).savedRehearsalReadEnabled)
    }
    func testRealCompositionReplacedApprovalRevisionCannotReviveOldEditor() throws {
        let context = try context(), installation = installation()
        func grant() throws -> ModInstallationApproval { try .init(context: context, expiresAt: Date().addingTimeInterval(60), readApprovalReference: "synthetic-read", templateRehearsalReadApprovalReference: "synthetic-rehearsal") }
        var approval: ModInstallationApproval? = try grant()
        let controller = try XCTUnwrap(ModInstallationComposition.make(reference: installation.identity, context: context, approval: approval, currentApproval: { approval }, current: { context }, storage: Memory()))
        let editor = try XCTUnwrap(controller.templateEditor(installation)); XCTAssertTrue(editor.savedRehearsalReadEnabled)
        approval = try grant(); XCTAssertFalse(editor.savedRehearsalReadEnabled)
    }
    func testSharedRehearsalViewReceivesReadOnlyCapturedAdmission() {
        var current = true
        let view = TemplateCreatorRehearsalView(draft: .init(), family: .branch, branchAdmission: { current }, showsReview: false)
        XCTAssertTrue(view.branchAdmission()); XCTAssertFalse(view.showsReview)
        current = false; XCTAssertFalse(view.branchAdmission())
    }
    func testSavedVersionAndReturnCopyIsAvailableInBothLocales() {
        for language in ["en", "zh-Hans"] {
            let locale = Locale(identifier: language)
            for key in ["entry", "savedOnly", "unsavedPreserved", "licenseChecked", "boundary", "return", "unavailable"] {
                let value = installedRehearsalLocalized(key, locale: locale)
                XCTAssertFalse(value.isEmpty); XCTAssertNotEqual(value, "installedRehearsal." + key)
            }
        }
    }
}
