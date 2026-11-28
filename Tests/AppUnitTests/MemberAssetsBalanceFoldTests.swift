import XCTest
@testable import Questify

/// mp-mine r3 continue 39 — MP `subpackageMember/components/cy/profile/index.wxml` `pc-asset` (1121 N5):
/// 账户余额 folds away only when the balance is a known 0.00 and the 余额流水 count is a known 0.
@MainActor final class MemberAssetsBalanceFoldTests: XCTestCase {
    func testFoldsOnlyForKnownZeroBalanceWithKnownEmptyLedger() {
        XCTAssertTrue(MemberAssetsBalanceRow.folds(balanceText: "0.00", ledgerCount: 0))
        XCTAssertTrue(MemberAssetsBalanceRow.folds(balanceText: "0", ledgerCount: 0))
    }

    func testUnknownValuesKeepTheRow() {
        // MP: "没拉到照常出" — an unread balance or a failed ledger read shows the row (¥0, P-49).
        XCTAssertFalse(MemberAssetsBalanceRow.folds(balanceText: nil, ledgerCount: 0))
        XCTAssertFalse(MemberAssetsBalanceRow.folds(balanceText: "0.00", ledgerCount: nil))
        XCTAssertFalse(MemberAssetsBalanceRow.folds(balanceText: "", ledgerCount: 0))
    }

    func testMoneyOrHistoryKeepsTheRow() {
        XCTAssertFalse(MemberAssetsBalanceRow.folds(balanceText: "0.00", ledgerCount: 3))
        XCTAssertFalse(MemberAssetsBalanceRow.folds(balanceText: "12.50", ledgerCount: 0))
        XCTAssertFalse(MemberAssetsBalanceRow.folds(balanceText: "1,280.00", ledgerCount: 0))
    }
}
