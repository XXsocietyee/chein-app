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
    }
}
#endif
