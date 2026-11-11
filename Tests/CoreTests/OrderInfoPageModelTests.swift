import XCTest
@testable import QuestifyCore

final class OrderInfoPageModelTests: XCTestCase {
    private typealias Page = OrderInfoPageModel
    private let dash = "\u{2014}"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func detail(_ json: String) throws -> OrderLifecycleDetail {
        try JSONDecoder().decode(OrderLifecycleDetail.self, from: Data(json.utf8))
    }
    private func phase(_ id: Int = 7, signedIn: Bool = true, configured: Bool = true, loading: Bool = false,
                       issue: OrderLifecycleCoordinatorIssue? = nil, detail: OrderLifecycleDetail? = nil) -> Page.Phase {
        Page.phase(orderID: id, signedIn: signedIn, configured: configured, loading: loading, issue: issue, detail: detail, now: now)
    }

    func testSignedOutUnconfiguredAndIssueAreErrorsNeverAnEmptyOrder() throws {
        XCTAssertEqual(phase(signedIn: false), .error(.login))
        XCTAssertEqual(phase(configured: false), .error(.notConfigured))
        XCTAssertEqual(phase(issue: .network), .error(.network))
        XCTAssertEqual(phase(signedIn: true, issue: .accessDenied, detail: try detail(#"{"id":7}"#)), .error(.accessDenied))
    }

    func testNoDetailIsLoadingOrUnknownAndAnotherOrdersDetailIsNotShown() throws {
        XCTAssertEqual(phase(loading: true), .loading)
        XCTAssertEqual(phase(), .unknown)
        XCTAssertEqual(phase(7, detail: try detail(#"{"id":8,"registrationStatus":2}"#)), .unknown)
        XCTAssertEqual(phase(0, detail: try detail(#"{"id":7}"#)), .unknown)
    }

    func testMissingAmountAndTimeAreEmDashesAndALiteralZeroStaysZero() throws {
        guard case .ready(let unknown) = phase(detail: try detail(#"{"id":7,"registrationStatus":1,"paymentStatus":1}"#)) else { return XCTFail("ready") }
        XCTAssertEqual(unknown.payableAmountText, dash)
        XCTAssertEqual(unknown.createTimeText, dash)
        XCTAssertNil(unknown.refundAmountText)
        XCTAssertEqual(unknown.state, .pendingPayment)
        guard case .ready(let zero) = phase(detail: try detail(#"{"id":7,"registrationStatus":1,"paymentStatus":1,"payableAmount":0}"#)) else { return XCTFail("ready") }
        XCTAssertEqual(zero.payableAmountText, "0")
        guard case .ready(let priced) = phase(detail: try detail(#"{"id":7,"registrationStatus":1,"payableAmount":12.5,"createTime":"2026-01-01 10:00:00"}"#)) else { return XCTFail("ready") }
        XCTAssertEqual(priced.payableAmountText, "12.5")
        XCTAssertEqual(priced.createTimeText, "2026-01-01 10:00")
    }

    func testUnrecognizedStatusStaysUnknownAndTimelineTimesOnlyShowOnDoneSteps() throws {
        guard case .ready(let unknown) = phase(detail: try detail(#"{"id":7}"#)) else { return XCTFail("ready") }
        XCTAssertEqual(unknown.state, .unknown)
        guard case .ready(let paid) = phase(detail: try detail(#"{"id":7,"registrationStatus":2,"paymentStatus":2,"createTime":"2026-01-01 10:00:00"}"#)) else { return XCTFail("ready") }
        let byID = Dictionary(uniqueKeysWithValues: paid.timeline.map { ($0.id, $0) })
        XCTAssertEqual(byID["created"]?.timeText, "2026-01-01 10:00")
        XCTAssertEqual(byID["paid"]?.timeText, dash)
        XCTAssertEqual(byID["paid"]?.done, true)
        XCTAssertNil(byID["verification"]?.timeText)
        XCTAssertEqual(byID["verification"]?.done, false)
    }

    func testRefundAmountKeepsMissingApartFromZero() throws {
        let json = #"{"id":7,"registrationStatus":2,"paymentStatus":2,"refundApplication":{"status":1,"payoutStatus":0}}"#
        guard case .ready(let missing) = phase(detail: try detail(json)) else { return XCTFail("ready") }
        XCTAssertEqual(missing.refundAmountText, dash)
        guard case .ready(let zero) = phase(detail: try detail(json.replacingOccurrences(of: #""payoutStatus":0"#, with: #""payoutStatus":0,"refundAmount":0"#))) else { return XCTFail("ready") }
        XCTAssertEqual(zero.refundAmountText, "0")
    }

    func testMoneyWritesStayOff() {
        XCTAssertFalse(Page.paymentEnabled)
        XCTAssertFalse(Page.payoutEnabled)
    }
}
