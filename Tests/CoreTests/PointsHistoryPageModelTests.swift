import XCTest
@testable import QuestifyCore

final class PointsHistoryPageModelTests: XCTestCase {
    private typealias Page = PointsHistoryPageModel
    private let dash = "\u{2014}"

    private func rows(_ json: String) throws -> [WalletLedgerRow] {
        try JSONDecoder().decode([WalletLedgerRow].self, from: Data(json.utf8))
    }
    private let mixed = #"[{"id":1,"changeType":1,"changePoints":12,"afterPoints":112,"createTime":"2026-01-01 10:00:00","changeReason":" fixture reason "},{"id":2,"changeType":2,"changePoints":3},{"id":3,"changeType":1}]"#

    func testNoPageYetIsLoadingOrUnknownNeverAnEmptyLedger() {
        XCTAssertEqual(Page.load(direction: .all, loading: true, failure: nil, rows: nil, total: nil, pageSize: 20), .loading)
        XCTAssertEqual(Page.load(direction: .all, loading: false, failure: nil, rows: nil, total: nil, pageSize: 20), .unknown)
    }

    func testFailureWinsOverRowsAndUsesExistingKeys() throws {
        let loaded = try rows(mixed)
        XCTAssertEqual(Page.load(direction: .all, loading: false, failure: APIError.unauthorized, rows: loaded, total: 3, pageSize: 20), .error(titleKey: "wallet.login"))
        XCTAssertEqual(Page.load(direction: .all, loading: false, failure: APIError.notConfigured, rows: nil, total: nil, pageSize: nil), .error(titleKey: "wallet.unavailable"))
        XCTAssertEqual(Page.load(direction: .all, loading: false, failure: URLError(.timedOut), rows: nil, total: nil, pageSize: nil), .error(titleKey: "wallet.failed"))
    }

    func testEmptyLedgerAndFilteredEmptyUseTheirOwnCopy() throws {
        // FIN-18-3 (parity r1): an empty account reads 还没有积分记录 whatever the direction.
        XCTAssertEqual(Page.load(direction: .all, loading: false, failure: nil, rows: [], total: 0, pageSize: 20), .empty(key: "wallet.points.empty.all"))
        XCTAssertEqual(Page.load(direction: .income, loading: false, failure: nil, rows: [], total: 0, pageSize: 20), .empty(key: "wallet.points.empty.all"))
        let expenseOnly = try rows(#"[{"id":2,"changeType":2,"changePoints":3}]"#)
        XCTAssertEqual(Page.load(direction: .income, loading: false, failure: nil, rows: expenseOnly, total: 1, pageSize: 20), .empty(key: "wallet.points.empty.income"))
        let incomeOnly = try rows(#"[{"id":1,"changeType":1,"changePoints":3}]"#)
        XCTAssertEqual(Page.load(direction: .expense, loading: false, failure: nil, rows: incomeOnly, total: 1, pageSize: 20), .empty(key: "wallet.points.empty.expense"))
    }

    func testRowsKeepMissingNumbersAsEmDashAndSignedMagnitudes() throws {
        guard case .ready(let all) = Page.load(direction: .all, loading: false, failure: nil, rows: try rows(mixed), total: nil, pageSize: 20) else { return XCTFail("ready") }
        XCTAssertEqual(all.rows.map(\.changeText), ["+12", "\u{2212}3", dash])
        XCTAssertEqual(all.rows.map(\.afterText), ["112", dash, dash])
        XCTAssertEqual(all.rows[0].reason, "fixture reason")
        XCTAssertNil(all.rows[1].reason)
        XCTAssertEqual(all.rows[0].timeText, "2026-01-01 10:00")
        XCTAssertEqual(all.rows[1].timeText, dash)
        XCTAssertEqual(all.totalText, dash)
        XCTAssertNotEqual(all.totalText, "0")
    }

    func testLiteralZeroAmountAndTotalStayZero() throws {
        guard case .ready(let zero) = Page.load(direction: .all, loading: false, failure: nil, rows: try rows(#"[{"id":9,"changeType":1,"changePoints":0,"afterPoints":0}]"#), total: 1, pageSize: 20) else { return XCTFail("ready") }
        XCTAssertEqual(zero.rows[0].changeText, "+0")
        XCTAssertEqual(zero.rows[0].afterText, "0")
        XCTAssertEqual(Page.countText(0), "0")
        XCTAssertEqual(Page.countText(nil), dash)
    }

    func testDirectionFilterIsLocalBecauseTheServerIgnoresIt() throws {
        let loaded = try rows(mixed)
        guard case .ready(let income) = Page.load(direction: .income, loading: false, failure: nil, rows: loaded, total: 3, pageSize: 20),
              case .ready(let expense) = Page.load(direction: .expense, loading: false, failure: nil, rows: loaded, total: 3, pageSize: 20) else { return XCTFail("ready") }
        XCTAssertEqual(income.rows.map(\.id), [1, 3])
        XCTAssertEqual(expense.rows.map(\.id), [2])
    }

    func testContinuationFollowsTheSourceRule() {
        XCTAssertTrue(Page.hasMore(loadedCount: 20, total: 45, pageSize: 20))
        XCTAssertFalse(Page.hasMore(loadedCount: 45, total: 45, pageSize: 20))
        XCTAssertTrue(Page.hasMore(loadedCount: 20, total: nil, pageSize: 20))
        XCTAssertFalse(Page.hasMore(loadedCount: 7, total: nil, pageSize: 20))
        XCTAssertFalse(Page.hasMore(loadedCount: 20, total: nil, pageSize: nil))
    }
}
