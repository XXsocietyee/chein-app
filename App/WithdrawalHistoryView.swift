import SwiftUI

/// Mini-program parity for subpackageMember/tixianjilu and the tixian history sheet
/// (components/cy/scene-member-withdraw-history). Read-only; never starts a withdrawal.
@MainActor struct WithdrawalHistoryView: View {
    let reader: WalletCommerceReader
    @State private var model: WithdrawalHistoryCoordinator
    @State private var selected: WithdrawalHistorySelection?
    init(reader: WalletCommerceReader) {
        self.reader = reader
        _model = State(initialValue: WithdrawalHistoryCoordinator(reader: reader))
    }
    var body: some View {
        List {
            switch model.phase {
            case .idle, .loading:
                CYSkeleton(variant: .row).accessibilityIdentifier("withdrawal.history.loading")
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
                if model.page?.mayHaveMore == true {
                    Text("wallet.sourceLimited").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
            case .empty:
                CYEmptyState(systemImage: "tray", "wallet.withdrawals.emptyTitle", messageIdentifier: "withdrawal.history.empty")
            case .login:
                state(title: "withdrawal.history.login.title", detail: "withdrawal.history.login.detail", image: "person.crop.circle", id: "login")
            case .denied:
                state(title: "withdrawal.history.denied.title", detail: "withdrawal.history.denied.detail", image: "lock", id: "denied")
            case .unavailable:
                state(title: "withdrawal.history.failed.title", detail: "withdrawal.history.unavailable.detail", image: "nosign", id: "unavailable")
            case .failed:
                state(title: "withdrawal.history.failed.title", detail: "withdrawal.history.failed.detail", image: "exclamationmark.triangle", id: "failed")
            }
        }
        .cyGroupedSurface()
        // FIN-19-3: the bar carries the inline title (type-and-chrome §2); no second title in the content.
        .cyPageTitle("wallet.withdrawals")
        .cyPushedChrome(domain: .player)
        .task(id: reader.scope) { await model.load() }
        .refreshable { await model.load() }
        .onDisappear { model.cancel() }
        .sheet(item: $selected) { item in WithdrawalHistoryDetailSheet(row: item.row) }
        .accessibilityIdentifier("withdrawal.history")
    }
    @ViewBuilder private func state(title: LocalizedStringKey, detail: LocalizedStringKey, image: String, id: String) -> some View {
        // Login recovery belongs to the account surface; retry here only re-reads.
        CYEmptyState(systemImage: image, title, detail: detail, messageIdentifier: "withdrawal.history." + id,
                     actionTitle: model.phase == .failed ? "wallet.retry" : nil, actionIdentifier: "withdrawal.history.retry",
                     action: model.phase == .failed ? { Task { await model.load() } } : nil)
    }
}

struct WithdrawalHistoryRowView: View {
    let row: WithdrawalHistoryRow
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("wallet.withdrawal.rowTitle").cyText(.cardTitle)
                Text(verbatim: row.createTime ?? "—").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: row.amountText ?? "—").cyText(.cardTitle, monospacedDigit: true)
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
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("withdrawal.history.detail.amount") {
                        Text(verbatim: row.amountText ?? "—").monospacedDigit()
                    }
                    LabeledContent("withdrawal.history.detail.status") { Text(LocalizedStringKey(row.statusKey)) }
                    LabeledContent("withdrawal.history.detail.created") { Text(verbatim: row.createTime ?? "—") }
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
