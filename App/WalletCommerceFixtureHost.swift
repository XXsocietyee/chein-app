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
        if request.url?.path == "/api/user/info", arguments.contains("--design-fixture") {
            return (Data(#"{"code":200,"data":{"balance":"128.50","currency":"CNY"}}"#.utf8), 200)
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
                        Text(verbatim: "Synthetic fixture · debug only").font(.caption2).foregroundStyle(.secondary).padding(.vertical, 2)
                    }
                    .toolbar { ToolbarItem(placement: .primaryAction) { Menu { Button("Withdrawal parity") { showParity = true }; Button("Sign out") { state.scope = nil } } label: { Image(systemName: "ellipsis.circle") } } }
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
