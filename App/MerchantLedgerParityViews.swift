import SwiftUI

/// Source pages/merchant/ledger/index.wxml `.fin-row`: leading status dot, title, "who · HH:mm" + state chip, right-aligned amount.
struct MerchantLedgerRowLabel: View {
    let line: MerchantLedgerParity.Line
    let identifier: String
    @Environment(\.cyPalette) private var palette
    private var chipColor: Color {
        switch line.variant { case .warning: return CYColor.warningText; case .success: return CYColor.successText; case .danger: return CYColor.dangerText; case .neutral: return CYColor.textTertiary }
    }
    private var amountColor: Color {
        switch line.tone { case .positive: return CYColor.successText; case .negative: return CYColor.dangerText; case .muted: return CYColor.textTertiary }
    }
    private func copy(_ text: String?, _ key: String?) -> String? { text ?? key.map { MerchantOpsCopy.text($0) } }
    /// Redemption directory rows only. Batch rows share the identifier prefix but always use the public-transfer subtitle.
    private var usesKit: Bool {
        identifier.hasPrefix("merchantOps.ledger.row.") && line.subtitleKey != "merchantOps.ledger.batch.publicTransfer"
    }
    var body: some View {
        row
            .padding(.vertical, CYSpacing.xs)
            .frame(minHeight: CYSpacing.minTouchTarget)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
            .modifier(MerchantLedgerKitCard(enabled: usesKit))
    }
    @ViewBuilder private var row: some View {
        if usesKit { kitRow } else { legacyRow }
    }
    private var legacyRow: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Circle().fill(chipColor).frame(width: 8, height: 8).padding(.top, 7).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if let title = copy(line.title, line.titleKey) {
                    Text(verbatim: title).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                }
                let detail = [copy(line.subtitle, line.subtitleKey), line.timeText].compactMap { $0 }.joined(separator: " · ")
                if !detail.isEmpty { Text(verbatim: detail).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                HStack(spacing: CYSpacing.sm) {
                    switch line.state {
                    case .key(let key): Text(verbatim: MerchantOpsCopy.text(key))
                    case .server(let text): Text(verbatim: text)
                    }
                    if let extra = line.extraKey { Text(verbatim: MerchantOpsCopy.text(extra)).foregroundStyle(CYColor.textTertiary) }
                }.cyText(.meta).foregroundStyle(chipColor)
            }
            Spacer(minLength: CYSpacing.sm)
            if let amount = copy(line.amount, line.amountKey) {
                Text(verbatim: amount).cyText(.numericBody).monospacedDigit().foregroundStyle(amountColor)
            }
        }
    }
    private var kitRow: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Circle().fill(chipColor).frame(width: 8, height: 8).padding(.top, 7).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: copy(line.title, line.titleKey) ?? "—").cyText(.bodyMedium).foregroundStyle(palette.textPrimary)
                let detail = [copy(line.subtitle, line.subtitleKey), line.timeText].compactMap { $0 }.joined(separator: " · ")
                if !detail.isEmpty { Text(verbatim: detail).cyText(.meta).foregroundStyle(palette.textTertiary) }
                HStack(spacing: CYSpacing.sm) {
                    switch line.state {
                    case .key(let key): CYStatusChip(verbatim: MerchantOpsCopy.text(key), tone: chipTone)
                    case .server(let text): CYStatusChip(verbatim: text, tone: chipTone)
                    }
                    if let extra = line.extraKey { Text(verbatim: MerchantOpsCopy.text(extra)).foregroundStyle(palette.textTertiary) }
                }
            }
            Spacer(minLength: CYSpacing.sm)
            if let amount = copy(line.amount, line.amountKey) {
                Text(verbatim: amount).cyText(.numericBody).monospacedDigit().foregroundStyle(kitAmountColor)
            }
        }
    }
    private var kitAmountColor: Color {
        switch line.tone { case .positive: return palette.success; case .negative: return palette.danger; case .muted: return palette.textTertiary }
    }
    private var chipTone: CYStatusTone {
        switch line.variant { case .warning: return .warning; case .success: return .success; case .danger: return .danger; case .neutral: return .neutral }
    }
}

private struct MerchantLedgerKitCard: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.cyDomainCard(padding: CYSpacing.md).themeDomain(.merchant) } else { content }
    }
}

/// Source ledger `.fin-summary`: three key/value cells (this month's redemptions, pending, arrived), server totals only.
struct MerchantLedgerSummaryStrip: View {
    let summary: MerchantLedgerParity.Summary
    /// Settlement overview keeps the previous strip. The redemption ledger uses the kit card.
    var usesKit = true
    @Environment(\.cyPalette) private var palette
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            cell("merchantOps.ledger.summary.count", shown(MerchantOpsCopy.text("merchantOps.ledger.summary.countValue %lld", summary.count)), usesKit ? palette.textPrimary : CYColor.textPrimary)
            if let pending = summary.pending { cell("merchantOps.ledger.summary.pending", shown(pending), usesKit ? palette.warning : CYColor.warningText) }
            if let arrived = summary.arrived { cell("merchantOps.ledger.summary.arrived", shown(arrived), usesKit ? palette.success : CYColor.successText) }
        }
        .padding(.vertical, CYSpacing.xs)
        .modifier(MerchantLedgerKitCard(enabled: usesKit))
        .accessibilityElement(children: .combine).accessibilityIdentifier("merchantOps.ledger.summary")
    }
    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return usesKit && trimmed.isEmpty ? "—" : value
    }
    private func cell(_ key: String, _ value: String, _ tone: Color) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: MerchantOpsCopy.text(key)).cyText(.meta).foregroundStyle(usesKit ? palette.textTertiary : CYColor.textTertiary)
            Text(verbatim: value).cyText(.numericBody).monospacedDigit().foregroundStyle(tone)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Source ledger/order-detail hero card.
struct MerchantLedgerRedemptionHero: View {
    let hero: MerchantLedgerParity.RedemptionHero
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            let title = hero.title ?? hero.titleKey.map { MerchantOpsCopy.text($0) } ?? ""
            Text(verbatim: hero.showsIncome ? MerchantOpsCopy.text("merchantOps.ledger.detail.income %@", title) : title).cyText(.label).foregroundStyle(CYColor.textTertiary)
            if hero.showsIncome, let amount = hero.amount ?? hero.amountKey.map({ MerchantOpsCopy.text($0) }) {
                Text(verbatim: amount).cyText(.data2XL).monospacedDigit().foregroundStyle(hero.amount == nil ? CYColor.textTertiary : CYColor.textPrimary)
            }
            switch hero.state {
            case .key(let key): Text(verbatim: MerchantOpsCopy.text(key)).cyText(.meta, weight: .bold).foregroundStyle(CYColor.textSecondary)
            case .server(let text): Text(verbatim: text).cyText(.meta, weight: .bold).foregroundStyle(CYColor.textSecondary)
            }
            LabeledContent(MerchantOpsCopy.text("merchantOps.ledger.detail.store"), value: hero.store ?? MerchantOpsCopy.text("merchantOps.ledger.detail.storeMissing"))
            if let accrual = hero.accrual { LabeledContent(MerchantOpsCopy.text("merchantOps.ledger.detail.accrual"), value: accrual) }
            if let refund = hero.refundKey { LabeledContent(MerchantOpsCopy.text("merchantOps.ledger.detail.refund"), value: MerchantOpsCopy.text(refund)) }
        }.accessibilityElement(children: .combine).accessibilityIdentifier("merchantOps.ledger.redemptionHero")
    }
}

/// Source ledger/batch-detail hero card.
struct MerchantLedgerBatchHero: View {
    let hero: MerchantLedgerParity.BatchHero
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: MerchantOpsCopy.text("merchantOps.ledger.batch.net %@", hero.period ?? "")).cyText(.label).foregroundStyle(CYColor.textTertiary)
            Text(verbatim: hero.amount ?? MerchantOpsCopy.text("merchantOps.ledger.amount.pending")).cyText(.data2XL).monospacedDigit()
                .foregroundStyle(hero.amount == nil ? CYColor.textTertiary : CYColor.textPrimary)
            HStack {
                Text(verbatim: MerchantOpsCopy.text(hero.stateKey)).cyText(.meta, weight: .bold).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: MerchantOpsCopy.text(hero.invoiceKey)).cyText(.meta).foregroundStyle(CYColor.textTertiary)
            }
        }.accessibilityElement(children: .combine).accessibilityIdentifier("merchantOps.ledger.batchHero")
    }
}

struct MerchantLedgerBatchStatementCard: View {
    let statement: MerchantLedgerParity.BatchStatementSummary
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
            Text("merchant.settlementOverview.statement", tableName: "MerchantSettlementOverview")
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
            if let total = statement.totalText {
                LabeledContent {
                    Text(verbatim: total).cyText(.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                } label: {
                    Text("merchant.settlementOverview.serverTotal", tableName: "MerchantSettlementOverview")
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                }
            } else if statement.emptyText != nil {
                Text("merchant.settlementOverview.statementEmpty", tableName: "MerchantSettlementOverview")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            ForEach(Array(statement.stepTimestamps.enumerated()), id: \.offset) { _, stamp in
                Text(verbatim: stamp).cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("merchantOps.ledger.batchStatement")
    }
}

/// 对账单 card for one batch-detail response. It reports only the server
/// batch total and how many detail lines this response actually returned;
/// the detail contract has no complete-line total, and that gap is shown.
struct MerchantSettlementStatementCard: View {
    let statement: MerchantSettlementStatement
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
            Text("merchant.settlementOverview.statement", tableName: "MerchantSettlementOverview")
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
            LabeledContent {
                if let total = statement.serverTotalDisplay {
                    Text(verbatim: total).cyText(.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                } else {
                    Text("merchant.settlementOverview.totalUnknown", tableName: "MerchantSettlementOverview")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
            } label: {
                Text("merchant.settlementOverview.serverTotal", tableName: "MerchantSettlementOverview")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
            }
            if statement.returnedDetailCount == 0 {
                Text("merchant.settlementOverview.statementEmpty", tableName: "MerchantSettlementOverview")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            if !statement.hasCompleteDetailContract {
                Text("merchant.settlementOverview.detailIncomplete", tableName: "MerchantSettlementOverview")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("merchant.settlementOverview.batchStatement")
    }
}

/// Owned batch detail reached from the settlement overview's batches section.
/// Reuses the existing `.batch` finance read and settlement progress view;
/// it performs no settlement, payment, refund or payout action.
@MainActor struct MerchantSettlementBatchDetailView: View {
    let reader: any MerchantBusinessReading
    let batchID: Int
    var onReturn: () -> Void = {}
    @State private var snapshot: MerchantBusinessSnapshot?
    @State private var failureKey: String?
    @State private var loading = false
    @State private var generation = 0
    @State private var visible = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            if loading {
                Section { CYSkeleton(variant: .detail) }.listRowBackground(Color.clear)
            }
            if let failureKey {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text(LocalizedStringKey(failureKey)).cyText(.body).foregroundStyle(CYColor.textSecondary)
                        CYPillButton("action.retry", style: .secondary) { Task { await load() } }
                            .disabled(loading)
                            .accessibilityIdentifier("merchant.settlementOverview.batchDetail.retry")
                    }
                }
            }
            if let snapshot {
                let document = snapshot.document
                if let batch = document.sections.first(where: { $0.id == "batch" })?.rows.first {
                    Section("merchant.business.section.batch") {
                        VStack(alignment: .leading, spacing: CYSpacing.s2_5) {
                            Text(batch.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                            MerchantBusinessRecordFields(row: batch, access: snapshot.access, compact: false,
                                                         settlementReader: reader, settlementSnapshot: { self.snapshot })
                        }
                    }
                }
                if let statement = MerchantSettlementStatement(document: document) {
                    Section {
                        MerchantSettlementStatementCard(statement: statement)
                    }
                }
                detailSection(document, id: "earnings", title: "merchant.settlementOverview.earnings", access: snapshot.access)
                detailSection(document, id: "adjustments", title: "merchant.settlementOverview.adjustments", access: snapshot.access)
            }
        }
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.merchant)
        .cyPageTitle("merchant.business.batch")
        .task { visible = true; await load() }
        .onAppear { visible = true }
        .onDisappear {
            visible = false; generation += 1; loading = false; snapshot = nil; failureKey = nil
            onReturn()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { generation += 1; loading = false; snapshot = nil; failureKey = nil }
            else if visible, snapshot == nil { Task { await load() } }
        }
        .onChange(of: reader.scope) { _, _ in generation += 1; snapshot = nil; Task { await load() } }
        .onChange(of: reader.authorizationGeneration) { _, _ in generation += 1; snapshot = nil; Task { await load() } }
        .cyDomainScreen(.merchant)
    }

    @ViewBuilder private func detailSection(_ document: MerchantBusinessDocument, id: String,
                                            title: String, access: MerchantBusinessAccess) -> some View {
        if let rows = document.sections.first(where: { $0.id == id })?.rows, !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
                        Text(row.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        MerchantBusinessRecordFields(row: row, access: access, compact: false, settlementEntries: true)
                    }
                }
            } header: {
                Text(LocalizedStringKey(title), tableName: "MerchantSettlementOverview")
            }
        }
    }

    private func load() async {
        guard visible, scenePhase == .active, !loading, reader.isConfigured,
              let scope = reader.scope, let id = try? MerchantBatchID(batchID) else { return }
        loading = true; failureKey = nil
        generation += 1
        let ticket = generation, authorization = reader.authorizationGeneration
        defer { if generation == ticket { loading = false } }
        do {
            let result = try await reader.snapshot(.batch(id))
            guard visible, scenePhase == .active, generation == ticket, !Task.isCancelled,
                  reader.scope == scope, reader.authorizationGeneration == authorization,
                  result.access.allows("merchant:finance:read"),
                  MerchantSettlementStatement(document: result.document) != nil else { return }
            snapshot = result
        } catch {
            guard visible, scenePhase == .active, generation == ticket, !Task.isCancelled,
                  reader.scope == scope, reader.authorizationGeneration == authorization else { return }
            failureKey = MerchantSettlementOverviewModel.failureKey(error)
        }
    }
}
