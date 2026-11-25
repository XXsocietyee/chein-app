import SwiftUI
import UIKit

/// Three ledger sections on one page. A batch card pushes a child cover; that
/// disappearance does not retire the sections. Popping the cover refreshes batches
/// once for that presentation. Scope or permission retirement clears loading and
/// the previous error before the next read starts.
@MainActor final class MerchantLedgerSettlementModel: ObservableObject {
    let reader: any MerchantBusinessReading
    @Published private(set) var state = MerchantLedgerSettlementRead()
    /// MC7-06-5 (ledger/index.js:125-130): 收入明细 / 结算批次 rows kept across pages. Page 1 replaces them,
    /// later pages append by row id. Cleared whenever the owner (scope or permission generation) changes.
    @Published private(set) var accumulated: [MerchantLedgerSettlementSection: [MerchantBusinessRecord]] = [:]
    private var tasks: [MerchantLedgerSettlementSection: Task<Void, Never>] = [:]
    private var started = false
    init(reader: any MerchantBusinessReading) { self.reader = reader }
    deinit { tasks.values.forEach { $0.cancel() } }

    private var currentOwner: MerchantLedgerSettlementOwner {
        .init(scope: reader.scope, authorizationGeneration: reader.authorizationGeneration)
    }
    @discardableResult private func mutate<T>(_ body: (inout MerchantLedgerSettlementRead) -> T) -> T {
        var copy = state
        let result = body(&copy)
        state = copy
        return result
    }
    private func cancelTasks() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    func appear() {
        let replaced = mutate { $0.replaceOwner(currentOwner) }
        if replaced { cancelTasks(); started = false; accumulated = [:] }
        guard reader.isConfigured, reader.scope != nil, replaced || !started else { return }
        started = true
        loadAll()
    }
    func overviewDisappeared() { mutate { $0.overviewDisappeared() } }
    func leave() {
        cancelTasks()
        started = false
        accumulated = [:]
        mutate { $0.leave() }
    }
    func openBatch(_ batchID: Int) { mutate { $0.presentBatch(batchID) } }
    func childPopped(_ cover: MerchantLedgerBatchCover?) {
        guard let cover else { return }
        guard mutate({ $0.consumePop(cover) }) else { return }
        // Appended rows refresh from the first page, as the MP onShow reload does.
        load(.batches, page: 1)
    }
    func batchDenied(_ cover: MerchantLedgerBatchCover) {
        guard mutate({ $0.denyFromBatch(cover) }) else { return }
        cancelTasks()
    }
    func loadAll() {
        load(.overview, page: 1)
        load(.entries, page: 1)
        load(.batches, page: 1)
    }
    func load(_ section: MerchantLedgerSettlementSection, page: Int) {
        guard reader.isConfigured, reader.scope != nil else { return }
        let owner = currentOwner
        if mutate({ $0.replaceOwner(owner) }) { cancelTasks(); accumulated = [:] }
        guard let ticket = mutate({ $0.begin(section, page: page, owner: owner) }) else { return }
        tasks[section]?.cancel()
        let task = Task { [weak self] in _ = await self?.perform(section, ticket: ticket, owner: owner) }
        tasks[section] = task
    }

    /// MC7-06-5: asks for the next page once the current one is loaded and more exist.
    func loadMore(_ section: MerchantLedgerSettlementSection) {
        let slot = state.section(section)
        guard section != .overview, slot.phase == .loaded, slot.hasMore else { return }
        load(section, page: slot.page + 1)
    }
    private func accumulate(_ section: MerchantLedgerSettlementSection, page: Int, rows: [MerchantBusinessRecord]) {
        guard page > 1 else { accumulated[section] = rows; return }
        var kept = accumulated[section] ?? []
        var known = Set(kept.map(\.id))
        for row in rows where !known.contains(row.id) { kept.append(row); known.insert(row.id) }
        accumulated[section] = kept
    }

    private func perform(_ section: MerchantLedgerSettlementSection, ticket: Int, owner: MerchantLedgerSettlementOwner) async {
        let page = state.section(section).page
        do {
            let snapshot = try await reader.snapshot(section.query(page: page), isCurrent: { [weak self] in
                guard let self else { return false }
                let slot = self.state.section(section)
                return self.state.owner == owner && slot.generation == ticket && slot.isLoading && !Task.isCancelled
            })
            guard !Task.isCancelled else { mutate { $0.cancel(section, generation: ticket) }; return }
            let result = mutate { $0.succeed(section, generation: ticket, owner: owner, snapshot: snapshot) }
            if result == .stored, section != .overview { accumulate(section, page: page, rows: snapshot.document.rows) }
            if result == .rejected("merchant.business.denied") { cancelTasks(); accumulated = [:] }
        } catch is CancellationError {
            mutate { $0.cancel(section, generation: ticket) }
        } catch {
            guard !Task.isCancelled else { mutate { $0.cancel(section, generation: ticket) }; return }
            let key = MerchantLedgerSettlementFailure.key(error)
            let accepted = mutate { $0.fail(section, generation: ticket, owner: owner, key: key) }
            if accepted && key == "merchant.business.denied" { cancelTasks() }
        }
    }
}

@MainActor struct MerchantLedgerSettlementOverview: View {
    let reader: any MerchantBusinessReading
    @StateObject private var model: MerchantLedgerSettlementModel
    @StateObject private var redemptions: MerchantLedgerRedemptionsModel
    /// Opens 核销 rows on their detail page; nil keeps the rows read-only.
    let journal: (any MerchantBusinessIntentStore)?
    @State private var ledgerView: MerchantR1LedgerView = .redemptions
    @Environment(\.merchantR1CumulativeRevenue) private var cumulativeRevenue
    @Environment(\.merchantCoopSettlementDetailDestination) private var coopSettlementDetail
    @Environment(\.locale) private var locale
    init(reader: any MerchantBusinessReading, journal: (any MerchantBusinessIntentStore)? = nil, topicID: Int? = nil, initialView: MerchantR1LedgerView = .redemptions) {
        self.reader = reader
        self.journal = journal
        _model = StateObject(wrappedValue: MerchantLedgerSettlementModel(reader: reader))
        _redemptions = StateObject(wrappedValue: MerchantLedgerRedemptionsModel(reader: reader, topicID: topicID))
        _ledgerView = State(initialValue: initialView)
    }
    /// MC7-06-2 (ledger/index.wxml:11): a denied overview read replaces the page with the no-permission state.
    private var accessDenied: Bool { model.state.section(.overview).failureKey == MerchantBusinessFailure.denied.key }
    var body: some View {
        let cover = Binding<MerchantLedgerBatchCover?>(get: { model.state.cover }, set: { model.childPopped($0 == nil ? model.state.cover : nil) })
        Group {
        if accessDenied {
            MerchantDeniedState(title: "merchant.gate.ledger.denied", identifier: "merchant.ledger.denied")
        } else {
        List {
            if reader.isOfflineExample {
                Text("merchant.business.synthetic").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            // HANDOFF-R1 MR-21 / MR-20: one 账本 — the cumulative total from the workbench, the overview,
            // then a 核销 · 结算 switcher instead of two stacked lists.
            if let cumulative = cumulativeRevenue {
                Section { MerchantR1CumulativeRow(raw: cumulative) }
            }
            section(.overview)
            Section {
                Picker(selection: $ledgerView) {
                    ForEach(MerchantR1LedgerView.allCases) { view in
                        Text(verbatim: merchantR1("ledger.view.\(view.rawValue)", locale)).tag(view)
                    }
                } label: { Text(verbatim: merchantR1("ledger.view.label", locale)) }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("merchant.ledger.switcher")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            // MC7-06-11: 核销 is the redemption ledger; 收入明细 moved under 结算 with the batches.
            if ledgerView == .redemptions {
                MerchantLedgerRedemptionsSections(model: redemptions, journal: journal)
            } else {
                section(.entries)
                section(.batches)
            }
        }
        .animation(.easeOut(duration: 0.18), value: ledgerView)
        .refreshable { model.loadAll(); await redemptions.reload() }
        }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.loadAll() } label: { Label("merchant.business.refresh", systemImage: "arrow.clockwise") }
                    .accessibilityIdentifier("merchant.ledgerSettlement.refresh")
            }
        }
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.merchant)
        // MP ledger/index.js:82 cy-page-title: 核销与退款 (view=redemptions) / 结算 (view=settlement).
        .navigationTitle(Text(ledgerView == .redemptions ? "merchant.ledger.title.redemptions" : "merchant.ledger.title.settlement"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: cover) { item in
            MerchantLedgerBatchDetailView(reader: reader, batchID: item.batchID, owner: item.owner,
                onDenied: { model.batchDenied(item) }, onReturn: { model.childPopped(item) })
                .id(item.id)
                .cyPushedChrome(domain: .merchant)
        }
        .background(MerchantLedgerSettlementLeaveAnchor(coveringChild: model.state.cover != nil, leave: { model.leave() }).frame(width: 0, height: 0))
        .onAppear { model.appear(); redemptions.appear() }
        .onDisappear { model.overviewDisappeared() }
        .onChange(of: reader.scope) { _, _ in model.appear() }
        .onChange(of: reader.authorizationGeneration) { _, _ in model.appear() }
    }

    @ViewBuilder private func section(_ id: MerchantLedgerSettlementSection) -> some View {
        let slot = model.state.section(id)
        let kept = model.accumulated[id] ?? []
        Section {
            if id != .overview, slot.page > 1, !kept.isEmpty, slot.phase != .loaded {
                // MC7-06-5: a later page is loading or failed; the rows already shown stay in place.
                rows(id, kept)
                appendFooter(id, slot, hasRows: true)
            } else {
            switch slot.phase {
            case .idle, .loading:
                CYSkeleton(variant: id == .overview ? .merchantMetric : .row)
                    .accessibilityIdentifier("merchant.ledgerSettlement.loading." + id.rawValue)
            case .failed:
                if let key = slot.failureKey {
                    Text(LocalizedStringKey(key))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
                Button { model.load(id, page: slot.page) } label: {
                    Text("merchant.ledgerSettlement.retrySection", tableName: "MerchantLedgerSettlement")
                }
                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false))
                .accessibilityIdentifier("merchant.ledgerSettlement.retry." + id.rawValue)
            case .loaded:
                loaded(id, slot)
            }
            }
        } header: { Text(LocalizedStringKey(headerKey(id))) }
    }
    private func headerKey(_ id: MerchantLedgerSettlementSection) -> String {
        switch id {
        case .overview: return "merchant.business.overview"
        case .entries: return "merchant.business.entries"
        case .batches: return "merchant.business.batches"
        }
    }
    @ViewBuilder private func loaded(_ id: MerchantLedgerSettlementSection, _ slot: MerchantLedgerReadSlot) -> some View {
        if let snapshot = slot.snapshot {
            switch id {
            case .overview:
                let summary = snapshot.document.summary
                if summary.isEmpty { Text("merchant.business.empty").cyText(.body).foregroundStyle(CYColor.textSecondary) }
                if let strip = MerchantLedgerParity.summary(summary, canReadFinance: snapshot.access.allows("merchant:finance:read")) {
                    MerchantLedgerSummaryStrip(summary: strip, usesKit: false)
                }
                // MC7-06-6 (ledger/index.wxml:120): 去我的资产 under the overview hero, as MerchantBusinessPage(.overview) does.
                MerchantLedgerAssetsEntry(reader: reader, currentSnapshot: {
                    let current = model.state.section(.overview)
                    guard current.phase == .loaded, current.snapshot == snapshot else { return nil }
                    return current.snapshot
                })
                ForEach(MerchantBusinessDocument.overviewMoneyKeys + ["adjustmentPendingCount"], id: \.self) { key in
                    if key == "personalArrivedThisMonthNet" {
                        MerchantLedgerNetSummary(presentation: .init(value: summary[key]))
                    } else if let value = summary[key] {
                        MerchantBusinessField(key: key, value: value, money: MerchantBusinessDocument.overviewMoneyKeys.contains(key))
                    }
                }
            case .entries:
                let entryRows = model.accumulated[.entries] ?? snapshot.document.rows
                if entryRows.isEmpty {
                    CYEmptyState(systemImage: "tray", LocalizedStringKey("merchant.ledgerSettlement.emptyEntries"), tableName: "MerchantLedgerSettlement")
                }
                rows(.entries, entryRows)
                appendFooter(id, slot, hasRows: !entryRows.isEmpty)
            case .batches:
                let batchRows = model.accumulated[.batches] ?? snapshot.document.rows
                if batchRows.isEmpty {
                    CYEmptyState(systemImage: "tray", LocalizedStringKey("merchant.ledgerSettlement.emptyBatches"), tableName: "MerchantLedgerSettlement")
                }
                rows(.batches, batchRows)
                appendFooter(id, slot, hasRows: !batchRows.isEmpty)
            }
        }
    }
    @ViewBuilder private func rows(_ id: MerchantLedgerSettlementSection, _ records: [MerchantBusinessRecord]) -> some View {
        switch id {
        case .overview:
            EmptyView()
        case .entries:
                ForEach(records) { row in
                    // MC7-06-9: coop-share rows open their settlement detail (source=ledger).
                    if let settlementID = MerchantLedgerCoopDetail.settlementID(row.fields), let coopSettlementDetail {
                        NavigationLink { coopSettlementDetail(settlementID) } label: {
                            MerchantLedgerRowLabel(line: MerchantLedgerParity.entry(row.fields), identifier: "merchant.ledgerSettlement.entry." + row.id)
                        }
                        .accessibilityIdentifier("merchant.ledgerSettlement.entry.coopDetail." + row.id)
                    } else {
                        MerchantLedgerRowLabel(line: MerchantLedgerParity.entry(row.fields), identifier: "merchant.ledgerSettlement.entry." + row.id)
                    }
                }
        case .batches:
                ForEach(records) { row in
                    Button { if let batchID = Int(row.id) { model.openBatch(batchID) } } label: {
                        MerchantLedgerRowLabel(line: MerchantLedgerParity.batch(row.fields), identifier: "merchant.ledgerSettlement.batch." + row.id)
                    }.buttonStyle(.plain).accessibilityIdentifier("merchant.ledgerSettlement.open." + row.id)
                }
        }
    }
    /// MC7-06-5 (ledger/index.wxml load-more footer): 正在加载更多… appends the next page when it appears,
    /// 重新加载 after a failed page, 已经到底了 once the last page is in. Replaces the 上一页 / 下一页 pager.
    @ViewBuilder private func appendFooter(_ id: MerchantLedgerSettlementSection, _ slot: MerchantLedgerReadSlot, hasRows: Bool) -> some View {
        if slot.phase == .failed {
            Button { model.load(id, page: slot.page) } label: {
                Text("merchant.gate.reload").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
            }
            .accessibilityIdentifier("merchant.ledgerSettlement.loadMoreRetry." + id.rawValue)
        } else if slot.isLoading || slot.hasMore {
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text("merchant.list.loadingMore").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
            .accessibilityElement(children: .combine)
            // Re-fires after each page settles, so a still-visible row keeps asking until the last page.
            .task(id: [slot.generation, slot.isLoading ? 1 : 0]) { model.loadMore(id) }
            .accessibilityIdentifier("merchant.ledgerSettlement.loadingMore." + id.rawValue)
        } else if hasRows {
            Text("merchant.list.end")
                .cyText(.meta)
                .foregroundStyle(CYColor.textTertiary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("merchant.ledgerSettlement.listEnd." + id.rawValue)
        }
    }
}

@MainActor final class MerchantLedgerBatchDetailModel: ObservableObject {
    let reader: any MerchantBusinessReading
    let batchID: Int
    private let onReturn: () -> Void
    private let onDenied: () -> Void
    @Published private(set) var state: MerchantLedgerBatchDetailRead
    /// MC7-08-4: the last accepted failure was a missing or no-longer-visible batch.
    @Published private(set) var missingRecord = false
    private var task: Task<Void, Never>?
    private var returned = false
    init(reader: any MerchantBusinessReading, batchID: Int, owner: MerchantLedgerSettlementOwner, onDenied: @escaping () -> Void = {}, onReturn: @escaping () -> Void) {
        self.reader = reader
        self.batchID = batchID
        self.onReturn = onReturn
        self.onDenied = onDenied
        state = .init(owner: owner)
    }
    deinit { task?.cancel() }
    private var currentOwner: MerchantLedgerSettlementOwner {
        .init(scope: reader.scope, authorizationGeneration: reader.authorizationGeneration)
    }
    private func mutate<T>(_ body: (inout MerchantLedgerBatchDetailRead) -> T) -> T {
        var copy = state
        let result = body(&copy)
        state = copy
        return result
    }
    func appear() {
        let owner = currentOwner
        if mutate({ $0.replaceOwner(owner) }) { task?.cancel(); task = nil }
        guard reader.isConfigured, reader.scope != nil, let batch = try? MerchantBatchID(batchID) else { return }
        guard let ticket = mutate({ $0.begin(owner: owner) }) else { return }
        let task = Task { [weak self] in _ = await self?.perform(batch, ticket: ticket, owner: owner) }
        self.task = task
    }
    func disappear() {
        task?.cancel()
        mutate { $0.leave() }
        guard !returned else { return }
        returned = true
        onReturn()
    }
    private func perform(_ batch: MerchantBatchID, ticket: Int, owner: MerchantLedgerSettlementOwner) async {
        do {
            let snapshot = try await reader.snapshot(.batch(batch), isCurrent: { [weak self] in
                guard let self else { return false }
                return self.state.owner == owner && self.state.slot.generation == ticket && self.state.slot.isLoading && !Task.isCancelled
            })
            guard !Task.isCancelled else { mutate { $0.cancel(generation: ticket) }; return }
            let result = mutate { $0.succeed(generation: ticket, owner: owner, batchID: batch.rawValue, snapshot: snapshot) }
            if result == .rejected("merchant.business.denied") { onDenied() }
        } catch is CancellationError {
            mutate { $0.cancel(generation: ticket) }
        } catch {
            guard !Task.isCancelled else { mutate { $0.cancel(generation: ticket) }; return }
            let key = MerchantBatchMissingRecord.failureKey(error, fallback: MerchantLedgerSettlementFailure.key)
            let accepted = mutate { $0.fail(generation: ticket, owner: owner, key: key) }
            // MC7-08-4 (batch-detail/index.wxml:52): a 404 or 记录不存在/不可见 reply is the missing-batch state,
            // not the generic retry error (Core MerchantFinanceDetailLoad).
            if accepted, case .rejected(let code, let message)? = error as? MerchantBusinessFailure {
                missingRecord = MerchantFinanceDetailLoad.isMissingRecord(code: String(code), statusCode: nil, message: message)
            } else if accepted {
                missingRecord = false
            }
            if accepted && key == "merchant.business.denied" { onDenied() }
        }
    }
}

enum MerchantBatchMissingRecord {
    static func failureKey(_ error: Error, fallback: (Error) -> String) -> String {
        if case let MerchantBusinessFailure.rejected(code, message) = error,
           MerchantFinanceDetailLoad.isMissingRecord(code: String(code), statusCode: nil, message: message) {
            return MerchantFinanceDetailLoad.batchMissingRecord
        }
        return fallback(error)
    }
}

@MainActor struct MerchantLedgerBatchDetailView: View {
    let reader: any MerchantBusinessReading
    let batchID: Int
    @StateObject private var model: MerchantLedgerBatchDetailModel
    @Environment(\.dismiss) private var dismiss
    init(reader: any MerchantBusinessReading, batchID: Int, owner: MerchantLedgerSettlementOwner, onDenied: @escaping () -> Void = {}, onReturn: @escaping () -> Void) {
        self.reader = reader
        self.batchID = batchID
        _model = StateObject(wrappedValue: MerchantLedgerBatchDetailModel(reader: reader, batchID: batchID, owner: owner, onDenied: onDenied, onReturn: onReturn))
    }
    var body: some View {
        let slot = model.state.slot
        List {
            if slot.isLoading {
                Section { CYSkeleton(variant: .detail) }.listRowBackground(Color.clear)
            }
            if slot.failureKey != nil, model.missingRecord {
                Section {
                    ContentUnavailableView {
                        // MP batch-detail cy-empty kind="empty" title="结算批次不可见": the MP empty art.
                        Label { Text("merchant.gate.batch.missingRecord") } icon: { CYEmptyIllustration(kind: .generic) }
                    } actions: {
                        Button { dismiss() } label: {
                            Text("merchant.gate.batch.backToList").frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("merchant.ledgerSettlement.batch.missing.back")
                    }
                    .accessibilityIdentifier("merchant.ledgerSettlement.batch.missing")
                }
                .listRowBackground(Color.clear)
            } else if let key = slot.failureKey {
                Section {
                    if key == MerchantFinanceDetailLoad.batchMissingRecord {
                        Text(verbatim: key).cyText(.body).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("merchant.ledger.batch.missing")
                    } else {
                        CYErrorState(LocalizedStringKey(key)) { model.appear() }
                            .disabled(slot.isLoading)
                    }
                }
                .listRowBackground(Color.clear)
            }
            if let snapshot = slot.snapshot, let batch = snapshot.document.sections.first(where: { $0.id == "batch" })?.rows.first {
                let count = detailCount(snapshot.document)
                Section {
                    MerchantLedgerBatchHero(hero: MerchantLedgerParity.batchHero(batch.fields))
                    // MC7-08-1 (batch-detail/index.wxml:16): 打款日期 under the hero, only once the batch is paid.
                    if batch.fields.mbText("paymentState") == "PAID", let paidAt = batch.fields.mbText("paidAt") {
                        LabeledContent("merchant.business.field.paidAt") { MerchantSettlementTimestampText(raw: paidAt) }
                            .accessibilityIdentifier("merchant.ledgerSettlement.batch.paidAt")
                    }
                    MerchantLedgerBatchStatementCard(statement: MerchantLedgerParity.batchStatementSummary(batch.fields, lineCount: count),
                                                     showsTimestamps: false)
                }
                detailRows(snapshot.document, id: "earnings")
                detailRows(snapshot.document, id: "adjustments")
                // MC7-08-3 (batch-detail/index.wxml:39-51): a labelled 打款进度 timeline (no dates for future steps),
                // with 复制打款凭证 when paid (MC7-08-2), instead of bare createdAt/confirmedAt/paidAt strings.
                if let progress = try? MerchantSettlementProgress(record: batch) {
                    Section {
                        MerchantSettlementProgressView(progress: progress, reader: reader, currentSnapshot: { model.state.slot.snapshot })
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.merchant)
        .navigationTitle(Text("merchant.business.batch")).navigationBarTitleDisplayMode(.inline)
        .onAppear { model.appear() }
        .onDisappear { model.disappear() }
        .onChange(of: reader.scope) { _, _ in model.appear() }
        .onChange(of: reader.authorizationGeneration) { _, _ in model.appear() }
        .cyDomainScreen(.merchant)
    }
    private func detailCount(_ document: MerchantBusinessDocument) -> Int {
        document.sections.reduce(0) { count, section in
            section.id == "earnings" || section.id == "adjustments" ? count + section.rows.count : count
        }
    }
    @ViewBuilder private func detailRows(_ document: MerchantBusinessDocument, id: String) -> some View {
        let rows = document.sections.first(where: { $0.id == id })?.rows ?? []
        if !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    MerchantLedgerRowLabel(line: MerchantLedgerParity.entry(row.fields), identifier: "merchant.ledgerSettlement." + id + "." + row.id)
                }
            }
        }
    }
}

/// Removing the overview retires its snapshots. A pushed batch cover is not removal:
/// `onDisappear` of the overview does not call this leave.
@MainActor struct MerchantLedgerSettlementLeaveAnchor: UIViewControllerRepresentable {
    var coveringChild: Bool
    var leave: () -> Void
    final class Coordinator {
        var coveringChild: Bool
        var leave: () -> Void
        init(coveringChild: Bool, leave: @escaping () -> Void) { self.coveringChild = coveringChild; self.leave = leave }
    }
    func makeCoordinator() -> Coordinator { Coordinator(coveringChild: coveringChild, leave: leave) }
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.coveringChild = coveringChild
        context.coordinator.leave = leave
    }
    static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) {
        if coordinator.coveringChild { return }
        coordinator.leave()
    }
}
