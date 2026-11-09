import XCTest
@testable import QuestifyCore

final class SettingsLegalAgreementPageTests: XCTestCase {
    private let dash = SettingsLegalAgreementPage.unknownDisplay

    func testUnknownCountIsAnEmDashAndALiteralZeroStaysZero() {
        XCTAssertEqual(dash, "—")
        XCTAssertEqual(SettingsLegalAgreementPage.countText(nil), dash)
        XCTAssertEqual(SettingsLegalAgreementPage.countText(0), "0")
        XCTAssertEqual(SettingsLegalAgreementPage.countText(13), "13")
        XCTAssertNotEqual(SettingsLegalAgreementPage.countText(nil), "0")
    }

    func testIdleLoadingFailureAndMissingDoNotInventASectionCount() {
        for state in [SettingsLegalState.idle, .loading, .failed] {
            let facts = SettingsLegalAgreementPage.facts(for: state)
            XCTAssertEqual(facts.versionText, dash)
            XCTAssertEqual(facts.effectiveDateText, dash)
            XCTAssertEqual(facts.sectionCountText, dash)
        }
        XCTAssertEqual(SettingsLegalAgreementPage.facts(for: .idle).phase, .loading)
        XCTAssertEqual(SettingsLegalAgreementPage.facts(for: .loading).accessibilityIdentifier, "settingsNative.legal.loading")
        XCTAssertEqual(SettingsLegalAgreementPage.facts(for: .failed).phase, .error)
        XCTAssertEqual(SettingsLegalAgreementPage.facts(for: .failed).accessibilityIdentifier, "settingsNative.legal.error")
        let missing = SettingsLegalAgreementPage.facts(for: .loaded(.missing(.pendingSourceText)))
        XCTAssertEqual(missing.phase, .empty(.pendingSourceText))
        XCTAssertEqual(missing.sectionCountText, dash)
        XCTAssertEqual(missing.accessibilityIdentifier, "settingsNative.legal.missing")
    }

    func testBlankDocumentIsUnknownAndATitledEmptyDocumentKeepsZero() {
        let unknown = SettingsLegalDocument(
            type: .userAgreement, title: " ", version: "", effectiveDate: "\n", intro: "", sections: []
        )
        let facts = SettingsLegalAgreementPage.facts(for: .loaded(.sourceDocument(unknown)))
        XCTAssertEqual(facts.phase, .unknown)
        XCTAssertEqual(facts.sectionCountText, dash)
        XCTAssertEqual(facts.versionText, dash)
        XCTAssertEqual(facts.accessibilityIdentifier, "settingsNative.legal.unknown")

        let empty = SettingsLegalDocument(
            type: .userAgreement, title: "fixture-title", version: "fixture-v0",
            effectiveDate: "fixture-date", intro: "fixture-intro", sections: []
        )
        let zero = SettingsLegalAgreementPage.facts(for: .loaded(.sourceDocument(empty)))
        XCTAssertEqual(zero.phase, .ready(empty))
        XCTAssertEqual(zero.sectionCountText, "0")
        XCTAssertEqual(zero.versionText, "fixture-v0")
        XCTAssertNotEqual(zero.sectionCountText, dash)
    }

    func testBlankVersionStaysUnknownWhileTheSectionCountStaysLiteral() {
        let document = SettingsLegalDocument(
            type: .cancellationNotice, title: "fixture-title", version: " \t ",
            effectiveDate: "", intro: "fixture-intro",
            sections: [.init(heading: "fixture-heading", body: "fixture-body")]
        )
        let facts = SettingsLegalAgreementPage.facts(for: .loaded(.sourceDocument(document)))
        XCTAssertEqual(facts.versionText, dash)
        XCTAssertEqual(facts.effectiveDateText, dash)
        XCTAssertEqual(facts.sectionCountText, "1")
        XCTAssertNotEqual(facts.versionText, "v2.2")
        XCTAssertNotEqual(facts.versionText, "0")
    }

    func testSectionIdentifierDoesNotUseANegativeIndex() {
        XCTAssertEqual(SettingsLegalAgreementPage.sectionAccessibilityIdentifier(index: 0), "settingsNative.legal.section.0")
        XCTAssertEqual(SettingsLegalAgreementPage.sectionAccessibilityIdentifier(index: 12), "settingsNative.legal.section.12")
        XCTAssertEqual(SettingsLegalAgreementPage.sectionAccessibilityIdentifier(index: -1), "settingsNative.legal.section")
        XCTAssertEqual(SettingsLegalAgreementPage.retryAccessibilityIdentifier, "settingsNative.legal.retry")
        XCTAssertEqual(SettingsLegalAgreementPage.versionAccessibilityIdentifier, "settingsNative.legal.version")
    }

    func testAgreementGetStaysHiddenAndReleaseApprovalStaysOff() {
        XCTAssertTrue(SettingsLegalAgreementPage.agreementGetStaysHidden)
        XCTAssertNil(ChinaReviewedRouteCapability.mark(for: "/api/agreement/get"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/agreement/get"))
        XCTAssertFalse(ChinaReviewedRouteCapability.virtualGoodsEnabled)
        XCTAssertFalse(SettingsSourceLegalCatalog.userAgreement.isReleaseApproved)
        XCTAssertFalse(SettingsSourceLegalCatalog.cancellationNotice.isReleaseApproved)
        XCTAssertFalse(SettingsSourceLegalCatalog.privacyPolicy.isReleaseApproved)
    }

    @MainActor func testBundledReaderProjectsReadyEmptyAndErrorWithoutANetworkRoute() async {
        let reader = SettingsBundledLegalReader()
        let coordinator = SettingsLegalCoordinator(reader: reader)
        await coordinator.load(type: .userAgreement, market: .china)
        let ready = SettingsLegalAgreementPage.facts(for: coordinator.state)
        guard case .ready(let document) = ready.phase else {
            return XCTFail("China user agreement should be the bundled source document")
        }
        XCTAssertEqual(document, SettingsSourceLegalCatalog.userAgreement)
        XCTAssertEqual(ready.versionText, document.version)
        XCTAssertEqual(ready.effectiveDateText, document.effectiveDate)
        XCTAssertEqual(ready.sectionCountText, String(document.sections.count))
        XCTAssertNotEqual(ready.sectionCountText, dash)
        XCTAssertEqual(ready.accessibilityIdentifier, "settingsNative.legal.sourceNotice")
        XCTAssertFalse(document.isReleaseApproved)

        await coordinator.load(type: .privacyPolicy, market: .china)
        let privacy = SettingsLegalAgreementPage.facts(for: coordinator.state)
        XCTAssertEqual(privacy.phase, .empty(.pendingSourceText))
        XCTAssertEqual(privacy.sectionCountText, dash)

        await coordinator.load(type: .userAgreement, market: .unitedStates)
        let unitedStates = SettingsLegalAgreementPage.facts(for: coordinator.state)
        XCTAssertEqual(unitedStates.phase, .empty(.regionalTextNotProvided))
        XCTAssertEqual(unitedStates.versionText, dash)

        await coordinator.load(type: .cancellationNotice, market: nil)
        let missingMarket = SettingsLegalAgreementPage.facts(for: coordinator.state)
        XCTAssertEqual(missingMarket.phase, .empty(.missingMarket))
        XCTAssertEqual(missingMarket.sectionCountText, dash)

        let failing = SettingsLegalCoordinator(reader: AgreementPageFailingReader())
        await failing.load(type: .userAgreement, market: .china)
        let error = SettingsLegalAgreementPage.facts(for: failing.state)
        XCTAssertEqual(error.phase, .error)
        XCTAssertEqual(error.sectionCountText, dash)
        XCTAssertTrue(SettingsLegalAgreementPage.agreementGetStaysHidden)
    }

    @MainActor func testInFlightLoadStaysLoadingUntilTheBundledDocumentReturns() async {
        let reader = AgreementPageSuspendingReader()
        let coordinator = SettingsLegalCoordinator(reader: reader)
        let task = Task { await coordinator.load(type: .userAgreement, market: .china) }
        while reader.requests.isEmpty { await Task.yield() }
        let loading = SettingsLegalAgreementPage.facts(for: coordinator.state)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.sectionCountText, dash)
        reader.requests[0].resume(returning: .sourceDocument(SettingsSourceLegalCatalog.cancellationNotice))
        await task.value
        let ready = SettingsLegalAgreementPage.facts(for: coordinator.state)
        XCTAssertEqual(ready.sectionCountText, String(SettingsSourceLegalCatalog.cancellationNotice.sections.count))
        XCTAssertEqual(ready.versionText, SettingsSourceLegalCatalog.cancellationNotice.version)
    }

    #if DEBUG
    func testDebugFixtureDataUsesSyntheticLabelsAndTheSameFacts() {
        let unknown = SettingsLegalAgreementPage.facts(for: .loaded(.sourceDocument(SettingsLegalAgreementFixtureData.unknownShell)))
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertEqual(unknown.sectionCountText, SettingsLegalAgreementFixtureData.unknownDisplay)
        let zero = SettingsLegalAgreementPage.facts(for: .loaded(.sourceDocument(SettingsLegalAgreementFixtureData.zeroSections)))
        XCTAssertEqual(zero.sectionCountText, "0")
        XCTAssertEqual(zero.versionText, "fixture-v0")
        let one = SettingsLegalAgreementPage.facts(for: .loaded(.sourceDocument(SettingsLegalAgreementFixtureData.oneSection)))
        XCTAssertEqual(one.sectionCountText, "1")
        let blank = SettingsLegalAgreementPage.facts(for: .loaded(.sourceDocument(SettingsLegalAgreementFixtureData.blankVersion)))
        XCTAssertEqual(blank.versionText, dash)
        XCTAssertEqual(blank.sectionCountText, "1")
        XCTAssertFalse(SettingsLegalAgreementFixtureData.oneSection.isReleaseApproved)
    }
    #endif
}

@MainActor private final class AgreementPageFailingReader: SettingsLegalReading {
    func document(type: SettingsLegalType, market: RegionalMarket?) async throws -> SettingsLegalAvailability {
        _ = (type, market)
        throw AgreementPageReadError()
    }
}

@MainActor private final class AgreementPageSuspendingReader: SettingsLegalReading {
    var requests: [CheckedContinuation<SettingsLegalAvailability, Never>] = []
    func document(type: SettingsLegalType, market: RegionalMarket?) async throws -> SettingsLegalAvailability {
        _ = (type, market)
        return await withCheckedContinuation { requests.append($0) }
    }
}

private struct AgreementPageReadError: Error {}
