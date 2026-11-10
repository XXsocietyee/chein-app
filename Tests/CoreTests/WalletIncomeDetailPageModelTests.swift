import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class IncomeDetailPageTransport: HTTPTransport {
    var requests: [URLRequest] = []
    let body: String
    let status: Int
    init(_ body: String, status: Int = 200) { self.body = body; self.status = status }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(body.utf8), status)
    }
}

@MainActor final class WalletIncomeDetailPageModelTests: XCTestCase {
    func testLoadingEmptyErrorAndUnknownNeverShowZero() throws {
        let loading = WalletIncomeDetailPageModel.list(loading: true, failed: true, hasLoadedPage: true, rowCount: 3)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.moneyText, "")
        XCTAssertNotEqual(loading.moneyText, "0")
        XCTAssertNotEqual(loading.moneyText, WalletIncomeDetailPageModel.unknownMoney)

        let failed = WalletIncomeDetailPageModel.list(loading: false, failed: true, hasLoadedPage: false, rowCount: 0)
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.moneyText, "\u{2014}")
        XCTAssertNotEqual(failed.moneyText, "0")

        let unknown = WalletIncomeDetailPageModel.list(loading: false, failed: false, hasLoadedPage: false, rowCount: 0)
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertEqual(unknown.moneyText, "\u{2014}")

        let empty = WalletIncomeDetailPageModel.list(loading: false, failed: false, hasLoadedPage: true, rowCount: 0)
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.moneyText, "\u{2014}")
        XCTAssertEqual(WalletIncomeDetailPageModel.amount(empty, WalletAmount(0)).phase, .empty)
        XCTAssertEqual(WalletIncomeDetailPageModel.amount(empty, WalletAmount(0)).moneyText, "\u{2014}")

        let ready = WalletIncomeDetailPageModel.list(loading: false, failed: false, hasLoadedPage: true, rowCount: 2)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.moneyText, "")
        let missing = WalletIncomeDetailPageModel.amount(ready, nil)
        XCTAssertEqual(missing.phase, .unknown)
        XCTAssertEqual(missing.moneyText, "\u{2014}")
        XCTAssertNotEqual(missing.moneyText, "0")
        XCTAssertEqual(WalletIncomeDetailPageModel.money(nil), "\u{2014}")
        XCTAssertEqual(WalletIncomeDetailPageModel.amount(ready, WalletAmount(0)).phase, .ready)
        XCTAssertEqual(WalletIncomeDetailPageModel.amount(ready, WalletAmount(0)).moneyText, "0")
        let decoded = try JSONDecoder().decode(WalletAmount.self, from: Data(#""8.50""#.utf8))
        XCTAssertEqual(WalletIncomeDetailPageModel.money(decoded), decoded.text)
        XCTAssertNotEqual(decoded.text, "\u{2014}")
        XCTAssertFalse(decoded.text.isEmpty)
    }

    func testCapabilityFlagsStayOffAndReuseTheExistingRead() {
        XCTAssertFalse(WalletIncomeDetailPageModel.registersRoute)
        XCTAssertFalse(WalletIncomeDetailPageModel.opensHost)
        XCTAssertFalse(WalletIncomeDetailPageModel.showsMerchantChoice)
        XCTAssertFalse(WalletIncomeDetailPageModel.showsOrganizerShare)
        XCTAssertFalse(WalletIncomeDetailPageModel.enablesPayment)
        XCTAssertFalse(WalletIncomeDetailPageModel.enablesPayout)
        XCTAssertFalse(WalletIncomeDetailPageModel.enablesWithdrawal)
        XCTAssertFalse(WalletIncomeDetailPageModel.enablesVirtualGoods)
        XCTAssertEqual(WalletIncomeDetailPageModel.existingReadPath, "api/user/balance/list")
        XCTAssertEqual(WalletIncomeDetailPageModel.Accessibility.unknownMoney, "wallet.income.detail.unknownMoney")
        XCTAssertEqual(WalletIncomeDetailPageModel.unknownMoney.unicodeScalars.first?.value, 0x2014)
    }

    func testFreshPagerIsUnknownRatherThanAnEmptyZero() {
        let pager = WalletLedgerPager()
        XCTAssertEqual(pager.incomeDetailListState().phase, .unknown)
        XCTAssertEqual(pager.incomeDetailAmountState(nil).moneyText, "\u{2014}")
        XCTAssertEqual(pager.incomeDetailAmountState(WalletAmount(0)).moneyText, "\u{2014}")
        XCTAssertNotEqual(pager.incomeDetailAmountState(nil).moneyText, "0")
    }

    func testExistingBalanceListFeedsEmptyUnknownZeroAndError() async throws {
        let empty = try await load(envelope(WalletIncomeDetailFixtureData.emptyList))
        XCTAssertEqual(empty.pager.incomeDetailListState().phase, .empty)
        XCTAssertEqual(empty.pager.incomeDetailAmountState(WalletAmount(0)).moneyText, "\u{2014}")
        XCTAssertEqual(empty.transport.requests.count, 1)
        XCTAssertTrue(empty.transport.requests[0].url?.path.hasSuffix("api/user/balance/list") == true)

        let missing = try await load(envelope(WalletIncomeDetailFixtureData.unknownAmount))
        XCTAssertEqual(missing.pager.rows.count, 1)
        XCTAssertNil(missing.pager.rows[0].changeBalance)
        XCTAssertEqual(missing.pager.incomeDetailAmountState(missing.pager.rows[0].changeBalance).phase, .unknown)
        XCTAssertEqual(missing.pager.incomeDetailAmountState(missing.pager.rows[0].changeBalance).moneyText, "\u{2014}")
        XCTAssertEqual(missing.transport.requests.count, 1)

        let zero = try await load(envelope(WalletIncomeDetailFixtureData.knownZero))
        let amount = try XCTUnwrap(zero.pager.rows.first?.changeBalance)
        XCTAssertEqual(amount.value, 0)
        let shown = zero.pager.incomeDetailAmountState(amount)
        XCTAssertEqual(shown.phase, .ready)
        XCTAssertEqual(shown.moneyText, "0")

        let failed = try await load(WalletIncomeDetailFixtureData.errorEnvelope, status: 503)
        XCTAssertEqual(failed.pager.incomeDetailListState().phase, .error)
        XCTAssertEqual(failed.pager.incomeDetailAmountState(WalletAmount(0)).moneyText, "\u{2014}")
        XCTAssertTrue(failed.pager.rows.isEmpty)
    }

    private func envelope(_ data: String) -> String { "{\"code\":200,\"data\":" + data + "}" }

    private func load(_ body: String, status: Int = 200) async throws -> (pager: WalletLedgerPager, transport: IncomeDetailPageTransport) {
        let transport = IncomeDetailPageTransport(body, status: status)
        let configuration = try APIConfiguration(baseURL: URL(string: "https://example.com")!)
        let service = WalletCommerceService(configuration: configuration, transport: transport)
        let scope = WalletCommerceScope(namespace: "synthetic", accountID: 9, epoch: UUID())
        let reader = WalletCommerceReader(service: service, session: { (scope, "fake") })
        let pager = WalletLedgerPager()
        await pager.load(reader: reader, kind: .income(.all))
        return (pager, transport)
    }
}
