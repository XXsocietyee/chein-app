import SwiftUI

// MC7-06-11 (pages/merchant/ledger/index.wxml:16-63): the 账本 核销 segment shows the redemption ledger itself —
// 合作分润 entry (finance), the 全部/待结算/已结算/零现金 filter (finance), the 本月核销 · 待结算 · 已入账 strip, then the
// day rows (verifiers see no amounts) — instead of the settlement entries, which now sit under 结算.
// MC7-06-5: rows append on reaching the last one, with 正在加载更多… / 已经到底了 rows instead of a pager.
// Without a topic the read stays `.redemptions(filter:page:)`, which omits `topicId`. A ledger link that
// carried one uses `MerchantFinanceRedemptionList` so the body includes `topicId`. Nothing here writes.

@MainActor final class MerchantLedgerRedemptionsModel: ObservableObject {
    enum Phase: Equatable { case idle, loading, loaded, failed(String) }
    let reader: any MerchantBusinessReading
    let topicID: Int?
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var rows: [MerchantBusinessRecord] = []
    @Published private(set) var summary: MerchantBusinessObject = [:]
    @Published private(set) var access: MerchantBusinessAccess?
    @Published private(set) var hasMore = false
    @Published private(set) var loadingMore = false
    @Published private(set) var filter: MerchantRedemptionFilter = .all
    private var page = 1
    private var generation = 0
    private var scope: MerchantBusinessScope?

    init(reader: any MerchantBusinessReading, topicID: Int? = nil) { self.reader = reader; self.topicID = topicID }

    var canReadFinance: Bool { access?.allows(MerchantAccess.Permission.finance.rawValue) == true }

    func appear() {
        guard phase == .idle || scope != reader.scope else { return }
        Task { await reload() }
    }

    func select(_ next: MerchantRedemptionFilter) {
        guard next != filter, canReadFinance else { return }
        filter = next
        Task { await reload() }
    }

    func reload() async {
        generation += 1
        let ticket = generation
        scope = reader.scope
        page = 1; loadingMore = false
        if rows.isEmpty { phase = .loading }
        do {
            let snapshot = try await pageSnapshot(1, ticket: ticket)
            guard generation == ticket else { return }
            rows = snapshot.document.rows; summary = snapshot.document.summary
            access = snapshot.access; hasMore = snapshot.document.hasMore
            phase = .loaded
        } catch {
            guard generation == ticket, !(error is CancellationError) else { return }
            rows = []; hasMore = false
            phase = .failed(MerchantLedgerSettlementFailure.key(error))
        }
    }

    func loadMore() async {
        guard phase == .loaded, hasMore, !loadingMore else { return }
        let ticket = generation, next = page + 1
        loadingMore = true
        defer { if generation == ticket { loadingMore = false } }
        guard let snapshot = try? await pageSnapshot(next, ticket: ticket), generation == ticket else { return }
        let known = Set(rows.map(\.id))
        rows += snapshot.document.rows.filter { !known.contains($0.id) }
        hasMore = snapshot.document.hasMore
        page = next
    }

    /// `topicId` is sent only when this ledger was opened with one. Otherwise the query omits it.
    private func pageSnapshot(_ page: Int, ticket: Int) async throws -> MerchantBusinessSnapshot {
        if let topicID {
            let snapshot = try await reader.redemptions(filter: filter.rawValue, page: page, topicID: topicID)
            guard generation == ticket, !Task.isCancelled else { throw CancellationError() }
            return snapshot
        }
        return try await reader.snapshot(.redemptions(filter: filter.rawValue, page: page), isCurrent: { [weak self] in
            self?.generation == ticket && !Task.isCancelled
        })
    }
}

struct MerchantLedgerRedemptionsSections: View {
    @ObservedObject var model: MerchantLedgerRedemptionsModel
    let journal: (any MerchantBusinessIntentStore)?
    @Environment(\.merchantCoopProfitDestination) private var coopProfitDestination

    var body: some View {
        if model.canReadFinance, let coopProfitDestination {
            // MC7-06-3 (ledger/index.wxml:17-18): 合作分润 for finance roles.
            Section {
                NavigationLink { coopProfitDestination() } label: {
                    Label("merchant.ledger.coopShare", systemImage: "person.2.wave.2")
                }
                .accessibilityIdentifier("merchant.ledger.coopShare")
            }
        }
        if model.canReadFinance {
            Section {
                Picker("merchant.business.filter", selection: Binding(get: { model.filter }, set: { model.select($0) })) {
                    ForEach(MerchantRedemptionFilter.allCases, id: \.rawValue) { option in
                        Text(LocalizedStringKey(option.titleKey)).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("merchant.ledger.redemptions.filter")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        Section {
            switch model.phase {
            case .idle, .loading:
                CYSkeleton(variant: .row).accessibilityIdentifier("merchant.ledger.redemptions.loading")
            case .failed(let key):
                MerchantLoadFailedState(title: "merchant.ledger.redemptions.loadFailed",
                                        message: Bundle.main.localizedString(forKey: key, value: nil, table: nil),
                                        identifier: "merchant.ledger.redemptions.failed") { Task { await model.reload() } }
            case .loaded:
                if let strip = MerchantLedgerParity.summary(model.summary, canReadFinance: model.canReadFinance) {
                    MerchantLedgerSummaryStrip(summary: strip)
                }
                if model.rows.isEmpty {
                    CYEmptyState(systemImage: "tray", "merchant.ledger.redemptions.empty", messageIdentifier: "merchant.ledger.redemptions.empty")
                }
                ForEach(model.rows) { row in
                    rowView(row)
                        .onAppear { if row.id == model.rows.last?.id { Task { await model.loadMore() } } }
                }
                if model.loadingMore {
                    HStack(spacing: CYSpacing.sm) {
                        ProgressView()
                        Text("merchant.list.loadingMore").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                } else if !model.hasMore, !model.rows.isEmpty {
                    Text("merchant.list.end").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("merchant.ledger.redemptions.end")
                }
            }
        } header: { Text("merchant.ledger.redemptions.header") }
    }

    @ViewBuilder private func rowView(_ row: MerchantBusinessRecord) -> some View {
        let label = MerchantLedgerRowLabel(line: MerchantLedgerParity.redemption(row.fields, canReadFinance: model.canReadFinance),
                                           identifier: "merchant.ledger.redemption.\(row.id)")
        if let journal, let destination = row.destination {
            NavigationLink {
                MerchantBusinessPage(reader: model.reader, journal: journal, query: destination)
                    .cyPushedChrome(domain: .merchant)
            } label: { label }
        } else {
            label
        }
    }
}

private struct MerchantCoopProfitDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> AnyView)? = nil
}

extension EnvironmentValues {
    /// The coop finance list (pages/coop/finance), injected at the root with the session's coop reader.
    var merchantCoopProfitDestination: (@MainActor () -> AnyView)? {
        get { self[MerchantCoopProfitDestinationKey.self] }
        set { self[MerchantCoopProfitDestinationKey.self] = newValue }
    }
}
