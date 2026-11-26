import SwiftUI

/// CLB-G17 / CLB-settlement-02 + CLB-r7-D-01 (fix-r8-club): mini-program `cy-fe-reference-range kind="payer"` on
/// `pages/club/settlement` (index.wxml:11): 自由探索结算（参考） with the date range and 导出对账表 bar.
/// Reads ride the payout area (open off the production host in DEBUG/TEST, closed in Release). 标记已结清 is a money
/// write: TEST-only and behind `ClubFEReferenceMoneyWriteGate.allowsSettle`, which stays false (owner decision 12).
enum ClubFEReferenceMoneyWriteGate {
    #if TEST
    static var allowsSettle = false
    #else
    static let allowsSettle = false
    #endif
}

@MainActor enum ClubFEReferenceBridge {
    /// CLB-settlement-05: the payer list and export are reads; they no longer wait on the payout area.
    static func open(_ session: AppSession) -> Bool { PayoutReceiverBridge.readsOpen(session) }
    /// 标记已结清 is money: it still needs the payout area (TEST/DEBUG off the production host) and the TEST gate.
    static func settleOpen(_ session: AppSession) -> Bool { PayoutReceiverBridge.payoutOpen(session) }

    private static func lease(_ session: AppSession) -> (any HTTPTransport)? {
        guard session.regionalConfiguration?.apiConfiguration != nil else { return nil }
        return Lease(underlying: session.composition.makeTransport(), open: { [weak session] in
            guard let session else { return false }
            return open(session)
        }, settleOpen: { [weak session] in
            guard let session else { return false }
            return settleOpen(session)
        })
    }

    static func list(_ session: AppSession) async throws -> [FEReferenceSettlementItem] {
        guard let configuration = session.regionalConfiguration?.apiConfiguration, let transport = lease(session) else { throw APIError.notConfigured }
        guard let token = session.token else { throw APIError.unauthorized }
        return try await ClubFEReferenceSettlementClient(configuration: configuration, transport: transport).list(role: .payer, token: token)
    }

    static func export(_ session: AppSession, range: FEReferenceRangeFilter) async throws -> URL? {
        guard let configuration = session.regionalConfiguration?.apiConfiguration, let transport = lease(session) else { throw APIError.notConfigured }
        guard let token = session.token else { throw APIError.unauthorized }
        let link = try await ClubFEReferenceExportClient(configuration: configuration, transport: transport).exportPayerCSV(range: range, token: token)
        guard let url = URL(string: link), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    static func settle(_ session: AppSession, ids: [Int], voucherNo: String?) async throws -> Bool {
        guard ClubFEReferenceMoneyWriteGate.allowsSettle, settleOpen(session) else { return false }
        guard let configuration = session.regionalConfiguration?.apiConfiguration, let transport = lease(session) else { throw APIError.notConfigured }
        guard let token = session.token else { throw APIError.unauthorized }
        return try await ClubFEReferenceSettlementClient(configuration: configuration, transport: transport)
            .markSettled(ids: ids, voucherNo: voucherNo, token: token, allowsMoneyWrite: ClubFEReferenceMoneyWriteGate.allowsSettle)
    }

    /// Only the three payer routes leave; the settle POST also needs the TEST money gate.
    private struct Lease: HTTPTransport {
        let underlying: any HTTPTransport
        let open: @MainActor () -> Bool
        let settleOpen: @MainActor () -> Bool
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            guard await open(), let path = request.url?.path else { throw APIError.notConfigured }
            if request.httpMethod?.uppercased() == "POST" { guard await settleOpen() else { throw APIError.notConfigured } }
            let method = request.httpMethod?.uppercased() ?? "GET"
            let read = method == "GET" && (path.hasSuffix("/api/fe/reference-settlement/payer") || path.hasSuffix("/api/fe/reference-settlement/payer/export"))
            let write = method == "POST" && path.hasSuffix("/api/fe/reference-settlement/settle") && ClubFEReferenceMoneyWriteGate.allowsSettle
            guard read || write else { throw APIError.notConfigured }
            return try await underlying.send(request)
        }
    }
}

/// Mounts `ClubGapFEReferenceRangeBar` + `ClubGapFEReferenceSettlementSection` on the club settlement page.
/// The payer view with no rows and no range draws nothing (MP wxml:2).
@MainActor struct ClubFEReferenceSettlementHost: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.openURL) private var openURL
    private enum Phase: Equatable { case loading, failed, ready([FEReferenceSettlementItem]) }
    @State private var phase: Phase = .loading
    @State private var range = FEReferenceRangeFilter()
    @State private var exporting = false
    @State private var exportFailed = false

    var body: some View {
        if ClubFEReferenceBridge.open(session) {
            Group {
                switch phase {
                case .loading:
                    Section { ProgressView().frame(maxWidth: .infinity) }
                case .failed:
                    Section {
                        // CLB-r9-native-03: system failure state.
                        ContentUnavailableView {
                            Label { Text("feReference.failed", tableName: "PayoutReceiver") } icon: { Image(systemName: "exclamationmark.triangle") }
                        } actions: {
                            Button { Task { await load() } } label: { Text("feReference.retry", tableName: "PayoutReceiver") }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("feReference.retry")
                        }
                    } header: { Text("feReference.title", tableName: "PayoutReceiver") }
                case .ready(let items):
                    if !items.isEmpty || range.isActive {
                        ClubGapFEReferenceRangeBar(range: $range, isExporting: exporting) { Task { await export() } }
                        if exportFailed {
                            Section { Text("feReference.exportFailed", tableName: "PayoutReceiver").font(.subheadline).foregroundStyle(.red) }
                        }
                        ClubGapFEReferenceSettlementSection(role: .payer, items: items,
                            allowsMoneyWrite: ClubFEReferenceMoneyWriteGate.allowsSettle,
                            onMarkSettled: { ids, voucher in Task { await settle(ids, voucher) } },
                            onDispute: { _ in })
                    }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        phase = .loading
        do { phase = .ready(try await ClubFEReferenceBridge.list(session)) }
        catch is CancellationError { return }
        catch { phase = .failed }
    }

    private func export() async {
        guard !exporting else { return }
        exporting = true; exportFailed = false
        defer { exporting = false }
        do {
            if let url = try await ClubFEReferenceBridge.export(session, range: range) { openURL(url) } else { exportFailed = true }
        } catch { exportFailed = true }
    }

    private func settle(_ ids: [Int], _ voucher: String?) async {
        do { if try await ClubFEReferenceBridge.settle(session, ids: ids, voucherNo: voucher) { await load() } }
        catch { await load() }
    }
}
