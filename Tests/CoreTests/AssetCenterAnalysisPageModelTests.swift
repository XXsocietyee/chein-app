#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class AssetCenterAnalysisPageModelTests: XCTestCase {
    func testLoadingEmptyErrorAndUnknownMoneyStayAnEmDash() {
        let models = [AssetCenterAnalysisPageModel(.loading), AssetCenterAnalysisPageModel(.empty),
                      AssetCenterAnalysisPageModel(.error), AssetCenterAnalysisPageModel(.unknown),
                      AssetCenterAnalysisPageModel(.ready)]
        for model in models {
            XCTAssertEqual(model.moneyText, "—")
            XCTAssertNotEqual(model.moneyText, "0")
        }
        XCTAssertEqual(AssetCenterAnalysisPageModel(.loading).phase, .loading)
        XCTAssertEqual(AssetCenterAnalysisPageModel(.empty).phase, .empty)
        XCTAssertEqual(AssetCenterAnalysisPageModel(.error).phase, .error)
        XCTAssertEqual(AssetCenterAnalysisPageModel(.unknown).phase, .unknown)
        XCTAssertEqual(AssetCenterAnalysisPageModel(.ready).phase, .unknown)
        XCTAssertEqual(AssetCenterAnalysisPageModel.moneyText(amount: nil), "—")
    }

    func testKnownZeroStaysZeroAndAMissingAmountDoesNot() throws {
        let zero = try JSONDecoder().decode(WalletAmount.self, from: Data("\"0\"".utf8))
        XCTAssertEqual(AssetCenterAnalysisPageModel.moneyText(amount: zero), "0")
        XCTAssertEqual(AssetCenterAnalysisPageModel.incomeListPath, "api/user/balance/list")
    }

#if DEBUG
    func testFixturePagesUseTheExistingIncomeListAndDoNotInventZero() throws {
        XCTAssertEqual(AssetCenterAnalysisFixtureData.incomeListPath, "api/user/balance/list")
        XCTAssertEqual(AssetCenterAnalysisFixtureData.loading.phase, .loading)
        XCTAssertEqual(AssetCenterAnalysisFixtureData.loading.moneyText, "—")
        XCTAssertEqual(AssetCenterAnalysisFixtureData.failed.phase, .error)
        XCTAssertEqual(AssetCenterAnalysisFixtureData.failed.moneyText, "—")
        XCTAssertFalse(String(data: AssetCenterAnalysisFixtureData.errorBody, encoding: .utf8)!.contains("changeBalance"))

        let empty = try AssetCenterAnalysisFixtureData.model(page: AssetCenterAnalysisFixtureData.emptyPage)
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.moneyText, "—")

        let unknown = try AssetCenterAnalysisFixtureData.model(page: AssetCenterAnalysisFixtureData.unknownAmountPage)
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertEqual(unknown.moneyText, "—")
        XCTAssertNil(try AssetCenterAnalysisFixtureData.decodeRows(AssetCenterAnalysisFixtureData.unknownAmountPage).first?.changeBalance)

        let zero = try AssetCenterAnalysisFixtureData.model(page: AssetCenterAnalysisFixtureData.knownZeroPage)
        XCTAssertEqual(zero.phase, .ready)
        XCTAssertEqual(zero.moneyText, "0")

        let ready = try AssetCenterAnalysisFixtureData.model(page: AssetCenterAnalysisFixtureData.readyPage)
        let posix = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(Decimal(string: ready.moneyText, locale: posix), Decimal(string: "8.50", locale: posix))
        XCTAssertNotEqual(ready.moneyText, "0")
        XCTAssertNotEqual(ready.moneyText, "—")

        let mixed = try AssetCenterAnalysisFixtureData.model(page: AssetCenterAnalysisFixtureData.mixedCurrencyPage)
        XCTAssertEqual(mixed.phase, .ready)
        XCTAssertEqual(mixed.moneyText, "—")

        XCTAssertThrowsError(try AssetCenterAnalysisFixtureData.decodeRows(AssetCenterAnalysisFixtureData.malformedAmountPage))
    }
#endif
}
#endif
