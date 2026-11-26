#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class WalletPointsLedgerEmptyStateTests: XCTestCase {
    func testPointsFilterNamesTheMissingDirection() {
        XCTAssertEqual(WalletPointsLedgerEmptyState.key(direction: "income", isIncomeLedger: false, isPointsLedger: true), "wallet.points.empty.income")
        XCTAssertEqual(WalletPointsLedgerEmptyState.key(direction: "expense", isIncomeLedger: false, isPointsLedger: true), "wallet.points.empty.expense")
        XCTAssertEqual(WalletPointsLedgerEmptyState.key(direction: "all", isIncomeLedger: false, isPointsLedger: true), "wallet.points.empty.all")
    }
    func testBalanceAndIncomeLedgersKeepTheirOwnCopy() {
        XCTAssertEqual(WalletPointsLedgerEmptyState.key(direction: "income", isIncomeLedger: false, isPointsLedger: false), "wallet.empty")
        XCTAssertEqual(WalletPointsLedgerEmptyState.key(direction: "expense", isIncomeLedger: true, isPointsLedger: false), "wallet.income.empty")
        // R11-PC-D-2: MP scene-asset-income-detail/index.js:62-68.
        XCTAssertEqual(WalletPointsLedgerEmptyState.key(direction: "all", isIncomeLedger: true, isPointsLedger: false, incomeFilter: .create), "wallet.income.empty.create")
        XCTAssertEqual(WalletPointsLedgerEmptyState.key(direction: "all", isIncomeLedger: true, isPointsLedger: false, incomeFilter: .brand), "wallet.income.empty.brand")
    }
}
#endif
