import SwiftUI

/// Mini-program parity for subpackageMember/tixianjilu and the tixian history sheet
/// (components/cy/scene-member-withdraw-history). Read-only; never starts a withdrawal.
@MainActor struct WithdrawalHistoryView: View {
    let reader: WalletCommerceReader
    /// R7-MEM-19-1: the coop entry (`pages/coop/withdraw/records`) keeps merchant chrome.
    var domain: ThemeDomain = .player
    /// FIN-19-4: MP 登录 on the signed-out state. Nil keeps the state without a button.
    var onSignIn: (() -> Void)? = nil
    @State private var model: WithdrawalHistoryCoordinator
    @State private var selected: WithdrawalHistorySelection?
    init(reader: WalletCommerceReader, domain: ThemeDomain = .player, onSignIn: (() -> Void)? = nil) {
        self.reader = reader
        self.domain = domain
        self.onSignIn = onSignIn
        _model = State(initialValue: WithdrawalHistoryCoordinator(reader: reader))
    }
    var body: some View {
        List {
            switch model.phase {
            case .idle, .loading:
                // MP `cy-skeleton type="list" count="{{4}}"`.
                CYSkeleton(variant: .row).accessibilityIdentifier("withdrawal.history.loading")
                ForEach(0..<3, id: \.self) { _ in CYSkeleton(variant: .row) }
            case .ready:
                // Revolut-style: rows grouped by China calendar day, tap opens a read-only detail sheet.
                ForEach(Array(WithdrawalHistoryGrouping.groups(model.rows).enumerated()), id: \.offset) { _, group in
                    Section {
                        ForEach(Array(group.rows.enumerated()), id: \.offset) { index, row in
                            Button { selected = WithdrawalHistorySelection(row: row) } label: {
                                WithdrawalHistoryRowView(row: row)
                            }
                            .buttonStyle(.plain).frame(minHeight: 44)
                            .accessibilityIdentifier("withdrawal.history.row.\(row.id.map(String.init) ?? "index\(index)")")
                        }
                    } header: {
                        if let day = group.dayKey { Text(verbatim: day) } else { Text("withdrawal.history.dateUnknown") }
                    }
                }
                // FIN-19-1: tixianjilu shows 加载更多 while another page exists.
                // loadMore is the existing read; a failure keeps the rows already on screen.
                if model.hasMore && !model.loadMoreFailed {
                    Button("wallet.loadMore") { Task { await model.loadMore() } }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("withdrawal.history.loadMore")
                }
                // FIN-19-1: MP scene-member-withdraw-history index.wxml:16 `cy-error` 更多提现记录加载失败 · 重试 (onPageRetry).
                if model.loadMoreFailed {
                    // mp-states r3: one state with 重试 inside (cy-error), not a label over a separate button row.
                    Section {
                        CYEmptyState(systemImage: "exclamationmark.triangle", "withdrawal.history.loadMoreFailed",
                                     messageIdentifier: "withdrawal.history.loadMoreFailed",
                                     actionTitle: "wallet.retry", actionIdentifier: "withdrawal.history.loadMoreRetry",
                                     kind: .failure) { Task { await model.loadMore() } }
                    }
                }
            case .empty:
                CYEmptyState(systemImage: "tray", "wallet.withdrawals.emptyTitle", messageIdentifier: "withdrawal.history.empty")
            // mp-states r3: MP scene-member-withdraw-history index.wxml:19 cy-error is the title alone (no sub line);
            // only the not-configured read keeps its explanation.
            case .login:
                state(title: "withdrawal.history.login.title", detail: nil, image: "person.crop.circle", id: "login")
            case .denied:
                state(title: "withdrawal.history.denied.title", detail: nil, image: "lock", id: "denied")
            case .unavailable:
                state(title: "withdrawal.history.failed.title", detail: "withdrawal.history.unavailable.detail", image: "nosign", id: "unavailable")
            case .failed:
                state(title: "withdrawal.history.failed.title", detail: nil, image: "exclamationmark.triangle", id: "failed")
            }
        }
        .cyGroupedSurface()
        // FIN-19-3: the bar carries the inline title (type-and-chrome §2); no second title in the content.
        .cyPageTitle("wallet.withdrawals")
        .cyPushedChrome(domain: domain)
        .task(id: reader.scope) { await model.load() }
        .refreshable { await model.load() }
        .onDisappear { model.cancel() }
        .cySheet(item: $selected) { item in WithdrawalHistoryDetailSheet(row: item.row) }
        .accessibilityIdentifier("withdrawal.history")
    }
    @ViewBuilder private func state(title: LocalizedStringKey, detail: LocalizedStringKey?, image: String, id: String) -> some View {
        // Retry only re-reads; FIN-19-4: the signed-out state offers 登录 when the host supplies it.
        if model.phase == .login, let onSignIn {
            CYEmptyState(systemImage: image, title, detail: detail, messageIdentifier: "withdrawal.history." + id,
                         actionTitle: "auth.signIn", actionIdentifier: "withdrawal.history.signIn", action: onSignIn)
        } else {
            CYEmptyState(systemImage: image, title, detail: detail, messageIdentifier: "withdrawal.history." + id,
                         actionTitle: model.phase == .failed ? "wallet.retry" : nil, actionIdentifier: "withdrawal.history.retry",
                         action: model.phase == .failed ? { Task { await model.load() } } : nil)
        }
    }
}

/// MP L09-023 `moneyText`: −¥ with the site amount format (¥0 for zero), never a bare "-12.00".
enum WithdrawalAmountDisplay {
    static func text(_ row: WithdrawalHistoryRow, locale: Locale) -> String {
        guard let amount = row.receivedAmount else { return "—" }
        let signed: Decimal = amount == 0 ? 0 : -amount
        return signed.formatted(.currency(code: "CNY").locale(locale).precision(.fractionLength(2)))
    }
}

struct WithdrawalHistoryRowView: View {
    let row: WithdrawalHistoryRow
    @Environment(\.locale) private var locale
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("wallet.withdrawal.rowTitle").cyText(.cardTitle)
                Text(verbatim: row.createTime.map { LocaleDisplay.civil($0, locale: locale) } ?? "—").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            Spacer(minLength: CYSpacing.sm)
            VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                Text(verbatim: WithdrawalAmountDisplay.text(row, locale: locale)).cyText(.cardTitle, monospacedDigit: true)
                CYStatusChip(LocalizedStringKey(row.statusKey), tone: tone)
            }
        }
        .accessibilityElement(children: .combine)
    }
    private var tone: CYStatusTone {
        switch row.status {
        case .processing: return .warning
        case .succeeded: return .success
        case .failed: return .danger
        case .unknown: return .neutral
        }
    }
}

struct WithdrawalHistorySelection: Identifiable {
    let id = UUID()
    let row: WithdrawalHistoryRow
}

/// Read-only detail sheet. It names no action: payouts are offline and nothing is sent from here.
struct WithdrawalHistoryDetailSheet: View {
    let row: WithdrawalHistoryRow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("withdrawal.history.detail.amount") {
                        Text(verbatim: WithdrawalAmountDisplay.text(row, locale: locale)).monospacedDigit()
                    }
                    LabeledContent("withdrawal.history.detail.status") { Text(LocalizedStringKey(row.statusKey)) }
                    LabeledContent("withdrawal.history.detail.created") { Text(verbatim: row.createTime.map { LocaleDisplay.civil($0, locale: locale) } ?? "—") }
                    if let id = row.id {
                        LabeledContent("withdrawal.history.detail.id") { Text(verbatim: String(id)).monospacedDigit() }
                    }
                } footer: { Text("withdrawal.history.detail.note") }
            }
            .cyGroupedSurface()
            .navigationTitle("withdrawal.history.detail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("action.done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .accessibilityIdentifier("withdrawal.history.detail")
    }
}
