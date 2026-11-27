import SwiftUI

private struct CoopWalletReaderKey: EnvironmentKey {
    static let defaultValue: WalletCommerceReader? = nil
}
extension EnvironmentValues {
    /// Wallet session used for owner-only funds stages and withdrawal records on coop pages.
    var coopWalletReader: WalletCommerceReader? {
        get { self[CoopWalletReaderKey.self] }
        set { self[CoopWalletReaderKey.self] = newValue }
    }
}

/// Source `pages/coop/finance` deep-link shell around `components/cy/scene-merchant-profit`.
/// Read-only: the only action opens platform withdrawal support; nothing here moves money.
@MainActor struct CoopFinanceProfitView: View {
    let reader: any CoopFlowReading
    @Environment(\.coopWalletReader) private var walletReader
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var profit: CoopFinanceProfit?
    @State private var issue: CoopFinanceProfit.ReadIssue?
    @State private var loadedSession: CoopFlowSession?
    @State private var generation = UUID()
    @State private var refresh = UUID()
    @State private var showsSupport = false

    var body: some View {
        List {
            Section {
                CYHeroHeader("cooperation.finance.title")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
            if reader.session == nil { failure(.authRequired) }
            else if loadedSession != reader.session { loadingRow.accessibilityIdentifier("cooperation.finance.loading") }
            else if let issue { failure(issue) }
            else if let profit { content(profit) }
            else { loadingRow }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
        .themeDomain(.merchant)
        .cyHideTabBar(true)
        .modifier(CoopOperationListPresentation())
        .labeledContentStyle(CoopFinancialRowStyle())
        .cyMiniListScreen()
        .task(id: "\(reader.session?.accountID ?? 0):\(reader.session?.epoch ?? 0):\(refresh)") { await load() }
        .refreshable { await load() }
        .onDisappear { generation = UUID() }
        .onChange(of: reader.session) { _, _ in showsSupport = false }
        .cySheet(isPresented: $showsSupport) {
            WithdrawalSupportContactView()
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.merchant)
        }
        .accessibilityIdentifier("cooperation.finance")
    }

    private var loadingRow: some View {
        CYSkeleton()
            .padding(.vertical, CYSpacing.md)
            .accessibilityLabel(Text("cooperation.loading"))
    }

    @ViewBuilder private func content(_ profit: CoopFinanceProfit) -> some View {
        // Parity coop/finance P1 (source k6 N-4): with no settlements the page is the empty state only — no
        // zero hero, no hand-off card, no disabled 提现.
        if profit.topics.isEmpty {
            Section {
                CYEmptyState(systemImage: "tray", "cooperation.finance.empty", messageIdentifier: "cooperation.finance.empty")
            }
        } else {
            settledContent(profit)
        }
        Section { CoopFlowSafetyNotice() }
    }

    @ViewBuilder private func settledContent(_ profit: CoopFinanceProfit) -> some View {
        Section {
            ForEach(profit.stats, id: \.key) { stat in
                Group {
                    if stat.key == .income {
                        VStack(alignment: .leading, spacing: Theme.Space.s2) {
                            // Mini `.profit-hero`: caption label over one big tabular total.
                            Text(LocalizedStringKey("cooperation.finance.stat." + stat.key.rawValue))
                                .cyText(.label).foregroundStyle(CYColor.textSecondary)
                            Text(verbatim: statText(stat)).cyText(.dataXL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }.padding(.vertical, Theme.Space.s2).accessibilityElement(children: .combine)
                    } else {
                        LabeledContent { Text(verbatim: statText(stat)).monospacedDigit().cyText(.numericBody).foregroundStyle(CYColor.textPrimary) } label: {
                            Text(LocalizedStringKey("cooperation.finance.stat." + stat.key.rawValue)).cyText(.label).foregroundStyle(CYColor.textSecondary)
                        }
                    }
                }
                    .accessibilityIdentifier("cooperation.finance.stat.\(stat.key.rawValue)")
            }
            if let reason = profit.adjustReason { Text(verbatim: reason).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
        }
        if profit.isOwner, let walletReader { CoopFinanceFundsStagesSection(reader: walletReader) }
        Section {
            // HANDOFF-R1 MR-38 / MR-07 (owner Q-A): the support hand-off is named, with the next steps.
            MerchantR1WithdrawalHandOff()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            // Parity coop/finance P1 (RevenueShareView 186:6257): 提现 is a row. It only opens support; it does not pay out.
            Button {
                if profit.canWithdraw, loadedSession == reader.session { showsSupport = true }
            } label: {
                HStack(spacing: CYSpacing.md) {
                    Label { Text("cooperation.finance.withdraw").cyText(.bodyMedium) } icon: { Image(systemName: "arrow.up.circle") }
                        .foregroundStyle(profit.canWithdraw ? CYColor.textPrimary : CYColor.textTertiary)
                    Spacer(minLength: CYSpacing.sm)
                    Image(systemName: "chevron.forward").imageScale(.small).foregroundStyle(CYColor.textTertiary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!profit.canWithdraw)
            .accessibilityLabel(Text(LocalizedStringKey(withdrawAccessibilityKey(profit.withdrawState))))
            .accessibilityIdentifier("cooperation.finance.withdraw")
            if profit.withdrawState == .unknown { Text("cooperation.finance.withdraw.unknown").cyText(.meta).foregroundStyle(CYColor.textTertiary).fixedSize(horizontal: false, vertical: true) }
            else if profit.withdrawState == .zero { Text("cooperation.finance.withdraw.zero").cyText(.meta).foregroundStyle(CYColor.textTertiary).fixedSize(horizontal: false, vertical: true) }
        }
        Section {
                ForEach(Array(profit.topics.enumerated()), id: \.offset) { index, topic in
                    if let id = topic.topicID, topic.canOpenDetail {
                        NavigationLink { CoopSettlementDetailView(reader: reader, source: .finance, id: id) } label: { row(topic) }
                            .accessibilityIdentifier("coopflow.settlement.finance.\(id)")
                    } else { row(topic).accessibilityIdentifier("cooperation.finance.topic.unavailable.\(index)") }
                }
            } header: { CYSectionHeader("cooperation.finance.topics") } footer: { Text("cooperation.finance.explainer") }
    }

    private func row(_ topic: CoopFinanceProfit.Topic) -> some View {
        let settled = topic.status != .unsettled && topic.status != .settlementUnknown
        return VStack(alignment: .leading, spacing: CYSpacing.sm) {
            // Image parity: MP coop/finance rows carry no artwork, so no generated thumbnail here.
            CYListRow(verbatim: topicName(topic), trailing: .none)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    topicAmount(topic)
                    topicStatus(topic)
                    CoopFinanceBadge(settled: settled, status: topic.status)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
                    topicStatus(topic)
                    Spacer(minLength: CYSpacing.sm)
                    VStack(alignment: .trailing, spacing: CYSpacing.sm) {
                        topicAmount(topic)
                        CoopFinanceBadge(settled: settled, status: topic.status)
                    }
                }
            }
        }
        .padding(.vertical, CYSpacing.sm)
    }
    private func topicAmount(_ topic: CoopFinanceProfit.Topic) -> some View {
        Text(verbatim: topic.status != .unsettled && topic.status != .settlementUnknown ? topic.income.map { LocaleDisplay.money($0, negative: false, locale: locale) } ?? "—" : "—")
            .cyText(.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
    }
    private func topicStatus(_ topic: CoopFinanceProfit.Topic) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(LocalizedStringKey("cooperation.finance.status." + topic.status.rawValue)).cyText(.label).foregroundStyle(CYColor.textSecondary)
            Text(LocalizedStringKey("cooperation.finance.merchant." + topic.merchantStatus.rawValue))
                .cyText(.meta).foregroundStyle(CYColor.textTertiary)
        }.fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func failure(_ issue: CoopFinanceProfit.ReadIssue) -> some View {
        let key: String = issue == .authRequired ? "auth" : issue == .accessDenied ? "denied" : "failed"
        // Sign-in is owned by the account entry; this page never presents credentials itself.
        let canRetry = issue != .authRequired || reader.session != nil
        Section {
            if canRetry {
                CYEmptyState(
                    systemImage: issue == .accessDenied ? "lock" : "exclamationmark.triangle",
                    LocalizedStringKey("cooperation.finance.issue." + key + ".title"),
                    detail: LocalizedStringKey("cooperation.finance.issue." + key + ".detail"),
                    messageIdentifier: "cooperation.finance.issue.\(key)",
                    actionTitle: "cooperation.refresh",
                    actionIdentifier: "cooperation.finance.retry",
                    actionStyle: .primary,
                    kind: .failure
                ) { refresh = UUID() }
            } else {
                CYEmptyState(
                    systemImage: "exclamationmark.triangle",
                    LocalizedStringKey("cooperation.finance.issue." + key + ".title"),
                    detail: LocalizedStringKey("cooperation.finance.issue." + key + ".detail"),
                    messageIdentifier: "cooperation.finance.issue.\(key)",
                    kind: .failure
                )
            }
        }
    }

    private func topicName(_ topic: CoopFinanceProfit.Topic) -> String {
        if let name = topic.topicName { return name }
        if let id = topic.topicID, id != 0 { return appLocalized("cooperation.finance.topicFallback \(id)", locale: locale) }
        return appLocalized("cooperation.unnamedTopic", locale: locale)
    }
    private func statText(_ stat: CoopFinanceProfit.Stat) -> String {
        guard let amount = stat.amount else { return "—" }
        return LocaleDisplay.money(amount, negative: stat.key == .adjustExecuted, locale: locale)
    }
    private func withdrawAccessibilityKey(_ state: CoopFinanceProfit.WithdrawState) -> String {
        switch state { case .positive: return "cooperation.finance.withdraw"; case .unknown: return "cooperation.finance.withdraw.a11y.unknown"; case .zero: return "cooperation.finance.withdraw.a11y.zero" }
    }
    private func load() async {
        let stamp = UUID(); generation = stamp; profit = nil; issue = nil; loadedSession = nil
        guard let session = reader.session else { return }
        do {
            let value = try await reader.read(.finance)
            let parsed = try CoopFinanceProfit(value)
            guard !Task.isCancelled, generation == stamp, reader.session == session else { return }
            profit = parsed; loadedSession = session
        } catch {
            guard !Task.isCancelled, generation == stamp, reader.session == session else { return }
            issue = CoopFinanceProfit.issue(for: error); loadedSession = session
        }
    }
}

struct CoopFinanceBadge: View {
    let settled: Bool
    let status: CoopFinanceProfit.TopicStatus
    var body: some View {
        let badge: CoopFinanceProfit.Badge = settled ? .success : status.badge
        let key = settled ? "cooperation.finance.settled" : "cooperation.finance.status." + status.rawValue
        let tone: CYStatusTone = badge == .success ? .success : badge == .warning ? .warning : .neutral
        let symbol = badge == .success ? "checkmark.circle" : badge == .warning ? "clock" : "minus.circle"
        CYStatusChip(LocalizedStringKey(key), tone: tone, systemImage: symbol)
            .accessibilityLabel(Text(LocalizedStringKey(key)))
    }
}

/// Owner-only "not yet received" breakdown, read with the wallet session; unknown amounts are labelled, not zeroed.
@MainActor struct CoopFinanceFundsStagesSection: View {
    let reader: WalletCommerceReader
    @Environment(\.locale) private var locale
    @State private var stages: WalletFundsStages?
    @State private var failed = false
    @State private var loadedScope: WalletCommerceScope?
    @State private var generation = 0
    var body: some View {
        Section {
            if let stages, loadedScope == reader.scope {
                if stages.pendingSettlement.value > 0 { LabeledContent("cooperation.finance.stages.pending", value: amount(stages.pendingSettlement, stages.currency)) }
                ForEach(Array(stages.complaintPeriod.enumerated()), id: \.offset) { _, item in
                    LabeledContent { Text(verbatim: amount(item.amount, stages.currency)).monospacedDigit() } label: { Text("wallet.complaintPeriod"); Text(verbatim: item.availableDate) }
                }
                if stages.disputed.value > 0 { LabeledContent("cooperation.finance.stages.disputed", value: amount(stages.disputed, stages.currency)) }
                if !stages.amountsKnown {
                    Text("cooperation.finance.stages.unknown")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if failed {
                Text("cooperation.finance.stages.failed")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("cooperation.refresh", style: .secondary, fullWidth: false) { Task { await load() } }
                    .accessibilityLabel(Text("cooperation.refresh"))
                    .accessibilityIdentifier("cooperation.finance.stages.retry")
            } else if reader.scope != nil {
                CYSkeleton()
                    .padding(.vertical, CYSpacing.sm)
                    .accessibilityLabel(Text("cooperation.loading"))
            }
        }
        .task(id: reader.scope) { await load() }
        .accessibilityIdentifier("cooperation.finance.stages")
    }
    private func amount(_ value: WalletAmount, _ currency: String?) -> String {
        value.text + " " + (currency ?? appLocalized("wallet.currencyUnknown", locale: locale))
    }
    private func load() async {
        generation += 1; let ticket = generation; let scope = reader.scope
        stages = nil; failed = false; loadedScope = nil
        guard scope != nil else { return }
        do {
            let result = try await reader.read { try await $0.stages(token: $1) }
            guard ticket == generation, reader.scope == scope, !Task.isCancelled else { return }
            stages = result; loadedScope = scope
        } catch { guard ticket == generation, reader.scope == scope, !Task.isCancelled else { return }; failed = true }
    }
}
