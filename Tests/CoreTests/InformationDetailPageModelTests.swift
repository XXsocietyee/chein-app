import XCTest
@testable import QuestifyCore

final class InformationDetailPageModelTests: XCTestCase {
    private func article(_ json: String) throws -> SocialInformation {
        try JSONDecoder().decode(SocialInformation.self, from: Data(json.utf8))
    }

    private func model(capability: Bool = true, path: String = ProfileGuideReadRoute.detailPath, id: Int = 91, outcome: InformationDetailPageModel.Outcome) -> InformationDetailPageModel {
        InformationDetailPageModel(readCapabilityPresent: capability, path: path, requestedID: id, outcome: outcome)
    }

    func testLoadingEmptyErrorAndUnknownStayDistinct() {
        let loading = model(outcome: .loading)
        let removed = model(outcome: .article(SocialInformation.removed))
        let failed = model(outcome: .failure(status: 503, message: "temporary"))
        let unknown = model(outcome: .unresolved)
        XCTAssertEqual(loading.phase, .some(.loading))
        XCTAssertEqual(loading.stateKey, InformationDetailPageModel.Copy.loading)
        XCTAssertEqual(loading.accessibilityIdentifier, "social.information.detail.loading")
        XCTAssertEqual(removed.phase, .some(.empty(.removed)))
        XCTAssertEqual(removed.stateKey, InformationDetailPageModel.Copy.removed)
        XCTAssertEqual(removed.identifierDisplay, InformationDetailPageModel.unknownDisplay)
        XCTAssertNotEqual(removed.identifierDisplay, "0")
        XCTAssertEqual(failed.phase, .some(.error(status: 503, message: "temporary")))
        XCTAssertEqual(failed.accessibilityIdentifier, "social.information.detail.error")
        XCTAssertEqual(unknown.phase, .some(.unknown))
        XCTAssertEqual(unknown.stateKey, InformationDetailPageModel.Copy.unknown)
        XCTAssertEqual(unknown.identifierDisplay, "—")
        XCTAssertNil(unknown.createTimeDisplay)
    }

    func testIncompleteLinkDoesNotReadAndDoesNotShowZero() {
        let page = model(id: 0, outcome: .loading)
        XCTAssertEqual(page.phase, .some(.empty(.incompleteLink)))
        XCTAssertEqual(page.stateKey, "social.incompleteLink")
        XCTAssertEqual(page.identifierDisplay, "—")
        XCTAssertEqual(page.accessibilityIdentifier, "social.information.detail.empty.incompleteLink")
    }

    func testReadyDocumentKeepsCreateTimeAndBlankBody() throws {
        let ready = try article(#"{"id":91,"title":"城市定向","subtitle":"规则","contents":"<p>a</p>","createTime":"2026-10-01 08:30:00"}"#)
        let page = model(outcome: .article(ready))
        guard case .ready(let row) = page.phase else { return XCTFail("\(String(describing: page.phase))") }
        XCTAssertEqual(row.createTime, "2026-10-01 08:30:00")
        XCTAssertEqual(page.createTimeDisplay, "2026-10-01 08:30:00")
        XCTAssertEqual(page.identifierDisplay, "91")
        XCTAssertEqual(page.stateKey, "guideXcx.detailTitle")
        XCTAssertEqual(page.accessibilityIdentifier, "social.information.detail")
        XCTAssertNil(page.bodyKey)
        let blankBody = try article(#"{"id":91,"title":"城市定向","contents":"  "}"#)
        let emptyBody = model(outcome: .article(blankBody))
        XCTAssertEqual(emptyBody.bodyKey, "social.guide.noContent")
        if case .ready = emptyBody.phase {} else { XCTFail("blank body stays a document") }
    }

    func testWrongArticleAndBlankDocumentAreUnknownNotAGuessedRow() throws {
        let other = try article(#"{"id":92,"title":"Other","contents":"x"}"#)
        let mismatched = model(id: 91, outcome: .article(other))
        XCTAssertEqual(mismatched.phase, .some(.unknown))
        XCTAssertEqual(mismatched.identifierDisplay, "—")
        XCTAssertNotEqual(mismatched.identifierDisplay, "92")
        let blank = try article(#"{"id":95,"title":" ","contents":""}"#)
        XCTAssertEqual(model(id: 95, outcome: .article(blank)).phase, .some(.unknown))
    }

    func testMissingCapabilityOrOtherPathStaysHidden() throws {
        let row = try article(#"{"id":91,"title":"城市定向","contents":"x"}"#)
        let missing = model(capability: false, outcome: .article(row))
        XCTAssertNil(missing.phase)
        XCTAssertTrue(missing.hidden)
        XCTAssertNil(missing.accessibilityIdentifier)
        XCTAssertEqual(missing.identifierDisplay, "—")
        let otherPath = model(path: "api/common/infomation_list", outcome: .article(row))
        XCTAssertTrue(otherPath.hidden)
        XCTAssertEqual(InformationDetailPageModel.contractPath, ProfileGuideReadRoute.detailPath)
    }

    func testUnknownCountIsAnEmDashAndLiteralZeroStaysZero() {
        XCTAssertEqual(InformationDetailPageModel.unknownDisplay, "—")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: "0"), "0")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: "0.0"), "0")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: "3"), "3")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: "null"), "—")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: "\"0\""), "—")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: "\"12\""), "—")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: "false"), "—")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: "1.5"), "—")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: "\"UNKNOWN\""), "—")
        XCTAssertNotEqual(InformationDetailPageModel.countDisplay(jsonFragment: "null"), "0")
    }

    func testCommerceFlagsStayOffAndURLMessagesAreDropped() {
        let page = model(outcome: .failure(status: 400, message: "https://example.com/must-not-keep"))
        XCTAssertFalse(page.showsMerchantChoice)
        XCTAssertFalse(page.paymentEnabled)
        XCTAssertFalse(page.payoutEnabled)
        XCTAssertFalse(page.withdrawalEnabled)
        XCTAssertFalse(page.virtualGoodsEnabled)
        XCTAssertEqual(page.phase, .some(.error(status: 400, message: nil)))
        let kept = model(outcome: .failure(status: 422, message: "  temporary  "))
        XCTAssertEqual(kept.phase, .some(.error(status: 422, message: "temporary")))
    }

    #if DEBUG
    func testDebugFixtureDataProjectsReadyRemovedAndCounts() throws {
        XCTAssertEqual(InformationDetailFixtureData.contractPath, ProfileGuideReadRoute.detailPath)
        let ready = try article(InformationDetailFixtureData.readyJSON)
        let page = model(id: 91, outcome: .article(ready))
        XCTAssertEqual(page.createTimeDisplay, "2026-10-01 08:30:00")
        XCTAssertEqual(page.identifierDisplay, "91")
        let removed = try article(InformationDetailFixtureData.removedJSON)
        XCTAssertEqual(model(outcome: .article(removed)).phase, .some(.empty(.removed)))
        let noContent = try article(InformationDetailFixtureData.noContentJSON)
        XCTAssertEqual(model(id: 94, outcome: .article(noContent)).bodyKey, "social.guide.noContent")
        let blank = try article(InformationDetailFixtureData.blankDocumentJSON)
        XCTAssertEqual(model(id: 95, outcome: .article(blank)).phase, .some(.unknown))
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: InformationDetailFixtureData.literalZeroJSON), "0")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: InformationDetailFixtureData.missingCountJSON), "—")
        XCTAssertEqual(InformationDetailPageModel.countDisplay(jsonFragment: InformationDetailFixtureData.numericStringZeroJSON), "—")
    }
    #endif
}
