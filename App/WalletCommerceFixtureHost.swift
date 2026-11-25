#if DEBUG
import SwiftUI

@MainActor private final class WalletFixtureState: ObservableObject {
    @Published var scope: WalletCommerceScope? = .init(namespace: "offline-fixture", accountID: 9001, epoch: UUID())
    private let failed: Bool
    init(failed: Bool) { self.failed = failed }
    lazy var reader: WalletCommerceReader = {
        let configuration = try! APIConfiguration(baseURL: URL(string: "https://example.com")!)
        let service = WalletCommerceService(configuration: configuration,
            transport: WalletAssetFixtureTransport(failed: failed, arguments: ProcessInfo.processInfo.arguments))
        return WalletCommerceReader(service: service) { [weak self] in
            guard let scope = self?.scope else { return nil }
            return (scope, "synthetic-token")
        }
    }()
}
/// Test-only asset read outcomes; all other fixture routes keep their original transport.
private actor WalletAssetFixtureTransport: HTTPTransport {
    let fallback: WalletCommerceSyntheticTransport
    let arguments: [String]
    private var reads = 0
    private var ledgerReads = 0
    private var withdrawalReads = 0
    init(failed: Bool, arguments: [String]) {
        fallback = WalletCommerceSyntheticTransport(fail: failed); self.arguments = arguments
    }
    /// DEBUG-labelled design data: invented amounts across three months so the balance hero and month groups can be judged.
    static func designLedger(path: String) -> String? {
        switch path {
        case "/api/balance/list", "/api/user/balance/list":
            let rows = #"[{"id":6,"changeBalance":"58.00","afterBalance":"128.50","changeType":1,"eventType":2,"currency":"CNY","changeReason":"Weekend city walk share","createTime":"2026-11-06 18:20:00"},{"id":5,"changeBalance":"30.00","afterBalance":"70.50","changeType":2,"eventType":3,"currency":"CNY","changeReason":"Withdrawal request","createTime":"2026-11-02 09:41:00"},{"id":4,"changeBalance":"24.50","afterBalance":"100.50","changeType":1,"eventType":1,"currency":"CNY","changeReason":"Old Town route share","createTime":"2026-10-28 20:05:00"},{"id":3,"changeBalance":"12.00","afterBalance":"76.00","changeType":1,"eventType":5,"currency":"CNY","changeReason":"Cafe referral reward","createTime":"2026-10-15 13:12:00"},{"id":2,"changeBalance":"40.00","afterBalance":"64.00","changeType":1,"eventType":2,"currency":"CNY","changeReason":"Riverside night ride share","createTime":"2026-09-30 21:30:00"},{"id":1,"changeBalance":"18.00","afterBalance":"24.00","changeType":2,"eventType":3,"currency":"CNY","changeReason":"Withdrawal request","createTime":"2026-09-12 10:00:00"}]"#
            return path == "/api/balance/list" ? rows : "{\"rows\":" + rows + ",\"total\":6}"
        case "/api/points/list", "/api/user/points/list":
            let rows = #"[{"id":11,"changePoints":20,"afterPoints":340,"changeType":1,"changeReason":"Check-in stamp: Old Town","createTime":"2026-11-07 10:12:00"},{"id":12,"changePoints":-50,"afterPoints":320,"changeType":2,"changeReason":"Redeemed postcard","createTime":"2026-11-03 16:40:00"},{"id":13,"changePoints":15,"afterPoints":370,"changeType":1,"changeReason":"Finished route: River loop","createTime":"2026-10-24 19:02:00"},{"id":14,"changePoints":10,"afterPoints":355,"changeType":1,"changeReason":"Daily sign-in","createTime":"2026-10-20 08:00:00"}]"#
            return path == "/api/points/list" ? rows : "{\"rows\":" + rows + ",\"total\":4}"
        default: return nil
        }
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        if request.url?.path == "/api/withdrawal/list" {
            withdrawalReads += 1
            if arguments.contains("--wallet-withdrawals-denied") { throw APIError.notConfigured }
            if arguments.contains("--wallet-withdrawals-unauthorized") { throw APIError.unauthorized }
            if arguments.contains("--wallet-withdrawals-recover"), withdrawalReads == 1 { throw APIError.httpStatus(503) }
            if arguments.contains("--wallet-withdrawals-empty") {
                return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
            }
            if arguments.contains("--wallet-withdrawals-invalid-status") {
                return (Data(#"{"code":200,"data":[{"id":40,"amount":5}]}"#.utf8), 200)
            }
        }
        if ["/api/balance/list", "/api/points/list"].contains(request.url?.path ?? "") {
            ledgerReads += 1
            if arguments.contains("--wallet-ledger-denied") { throw APIError.notConfigured }
            if arguments.contains("--wallet-ledger-unauthorized") { throw APIError.unauthorized }
            if arguments.contains("--wallet-ledger-recover"), ledgerReads == 1 { throw APIError.httpStatus(503) }
            if arguments.contains("--wallet-ledger-empty") {
                return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
            }
        }
        if request.url?.path == "/api/user/info" {
            let payload = Data(#"{"code":200,"data":{"balance":"128.50","currency":"CNY"}}"#.utf8)
            let contractForm = request.value(forHTTPHeaderField: "Content-Type") == AccountPublishMPContract.formContentType
                && request.httpBody?.isEmpty == false
            if contractForm || arguments.contains("--design-fixture") {
                guard case .amount = AccountPublishMPContract.earningsBalance(from: payload) else {
                    return try await fallback.send(request)
                }
                return (payload, 200)
            }
        }
        if arguments.contains("--design-fixture"), let rich = Self.designLedger(path: request.url?.path ?? "") {
            return (Data(("{\"code\":200,\"data\":" + rich + "}").utf8), 200)
        }
        guard request.url?.path == "/api/wallet/stages" else { return try await fallback.send(request) }
        reads += 1
        if arguments.contains("--wallet-assets-denied") { throw APIError.notConfigured }
        if arguments.contains("--wallet-assets-recover"), reads == 1 { throw APIError.httpStatus(503) }
        let knownZero = arguments.contains("--wallet-assets-known-zero")
        let recovering = arguments.contains("--wallet-assets-recover")
        let unknownNonzero = arguments.contains("--wallet-assets-unknown-nonzero")
        let returnRefresh = arguments.contains("--wallet-assets-return-refresh")
        if knownZero || recovering || unknownNonzero || returnRefresh {
            let amount = knownZero || (returnRefresh && reads == 1) ? 0 : 7
            let known = unknownNonzero ? "false" : "true"
            let json = "{\"code\":200,\"data\":{\"pendingSettlement\":\(amount),\"disputed\":\(amount),\"withdrawable\":\(amount),\"complaintPeriod\":[{\"availableDate\":\"2026-10-08\",\"amount\":\(amount)}],\"amountsKnown\":\(known)}}"
            return (Data(json.utf8), 200)
        }
        return try await fallback.send(request)
    }
}
/// DEBUG: the real points ledger on the fixture reader, without its own NavigationStack, so a fixture can push it
/// (`--design-fixture t5-pass-market-points`: the 通行证与礼品 balance card zooms into it).
@MainActor struct WalletLedgerPointsFixturePage: View {
    @StateObject private var state = WalletFixtureState(failed: false)
    var body: some View { WalletLedgerView(reader: state.reader, kind: .points) }
}

/// Register only in the existing DEBUG --uitesting-module switch, never ordinary navigation.
@MainActor struct WalletCommerceFixtureHost: View {
    static var selected: Bool { ProcessInfo.processInfo.arguments.contains("--wallet-commerce-fixture") }
    @StateObject private var state: WalletFixtureState
    var designHome = false
    /// e4 design shots: mount one real wallet page (income, points, assets, analysis, bank, withdrawals, tasks, cart, products).
    var designPage: String? = nil
    @State private var showParity = false
    init(designHome: Bool = false, designPage: String? = nil) { self.designHome = designHome; self.designPage = designPage; _state = StateObject(wrappedValue: WalletFixtureState(failed: ProcessInfo.processInfo.arguments.contains("--wallet-failure"))) }
    var body: some View {
        if let page = designPage {
            NavigationStack {
                switch page {
                case "income": WalletIncomeView(reader: state.reader, onCooperationFinance: {})
                case "points": WalletLedgerView(reader: state.reader, kind: .points)
                case "balance": WalletLedgerView(reader: state.reader, kind: .balance)
                case "assets": WalletAssetsView(reader: state.reader)
                case "analysis": WalletIncomeAnalysisView(reader: state.reader)
                case "bank": BankWithdrawalView(reader: state.reader)
                case "withdrawals": WalletWithdrawalsView(reader: state.reader)
                case "tasks": WalletPointsTasksView(reader: state.reader)
                case "products": WalletProductsView(reader: state.reader)
                default: WalletCartView(reader: state.reader)
                }
            }.id(state.scope)
        } else if designHome {
            NavigationStack {
                WalletCommerceHomeView(reader: state.reader, visibility: Self.fullVisibility, onCooperationFinance: {})
                    .safeAreaInset(edge: .top) {
                        Text(verbatim: "Synthetic fixture · debug only").cyText(.caption).foregroundStyle(.secondary).padding(.vertical, 2)
                    }
                    .toolbar { ToolbarItem(placement: .primaryAction) { Menu { Button("Withdrawal parity") { showParity = true }; Button("Sign out") { state.scope = nil } } label: { Image(systemName: "ellipsis.circle").accessibilityLabel(Text(verbatim: "More")).frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget) } } }
                .navigationDestination(isPresented: $showParity) { WithdrawalParityFixtureHost() }
            }.id(state.scope)
        } else { listBody }
    }
    private static var fullVisibility: WalletCommerceVisibility {
        var v = WalletCommerceVisibility(); v.income = true; v.assets = true; v.points = true; v.mall = true; v.withdrawalRecords = true; return v
    }
    private var listBody: some View {
        NavigationStack {
            List {
                Text("Synthetic offline wallet fixture")
                NavigationLink("Assets") { WalletAssetsView(reader: state.reader) }.accessibilityIdentifier("wallet.fixture.assets")
                NavigationLink("Income") { WalletIncomeView(reader: state.reader, onCooperationFinance: {}) }.accessibilityIdentifier("wallet.fixture.income")
                NavigationLink("Points") { WalletLedgerView(reader: state.reader, kind: .points) }.accessibilityIdentifier("wallet.fixture.points")
                NavigationLink("Cart") { WalletCartView(reader: state.reader) }.accessibilityIdentifier("wallet.fixture.cart")
                NavigationLink("Bank withdrawal") { BankWithdrawalView(reader: state.reader) }.accessibilityIdentifier("wallet.fixture.bankWithdrawal")
                NavigationLink("Withdrawals") { WalletWithdrawalsView(reader: state.reader) }.accessibilityIdentifier("wallet.fixture.withdrawals")
                NavigationLink("Withdrawal parity") { WithdrawalParityFixtureHost() }.accessibilityIdentifier("wallet.fixture.withdrawalParity")
            }.toolbar {
                Button("Sign out") { state.scope = nil }.accessibilityIdentifier("wallet.fixture.signOut")
            }
        }.id(state.scope)
    }
}
#endif
