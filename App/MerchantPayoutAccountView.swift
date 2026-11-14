import SwiftUI
import UIKit

/// WP-01. Mini-program pages/merchant/payout-account (l-payout): the merchant's own sub-merchant onboarding status,
/// read only. Onboarding is filed by platform operations; this page shows the server fact and, when the merchant
/// must sign or verify, a copyable https link. `FINANCE_READ` is enforced by the server (a refusal shows its copy).
@MainActor struct MerchantPayoutAccountView: View {
    @Environment(\.locale) private var locale
    @EnvironmentObject private var session: AppSession
    @State private var state: PayoutPageState<MerchantPayoutAccount> = .loading
    @State private var copied = false

    var body: some View {
        List {
            // Owner 2026-11-14: the account state is a status read and always shows.
            content
            ClubDirectLedgerSection(scope: .merchant(topicID: nil))
        }
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.merchant)
        .navigationTitle(Text("payoutAccount.title", tableName: "PayoutReceiver"))
        .refreshable { await load() }
        .task { await load() }
        .appSwitcherPrivacyShield()
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            Section { CYLoadingStateView(rows: 2) }.accessibilityIdentifier("payoutAccount.loading")
        case .empty:
            Section { CYEmptyState(systemImage: "building.columns", "payoutAccount.none", tableName: "PayoutReceiver", messageIdentifier: "payoutAccount.none") }
        case .failed(let issue):
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("payoutAccount.loadFailed", tableName: "PayoutReceiver").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                    PayoutReceiverIssueText(issue: issue, fallbackKey: "payoutAccount.loadFailed")
                        .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    CYPillButton("payoutReceiver.reload", style: .secondary, tableName: "PayoutReceiver") { Task { await load() } }
                        .accessibilityIdentifier("payoutAccount.reload")
                }
            }
        case .ready(let account):
            switch account.pageState {
            case .unavailable:
                Section { CYEmptyState(systemImage: "lock", "payoutAccount.unavailable", tableName: "PayoutReceiver", messageIdentifier: "payoutAccount.unavailable") }
            case .none:
                Section { CYEmptyState(systemImage: "building.columns", "payoutAccount.none", tableName: "PayoutReceiver", messageIdentifier: "payoutAccount.none") }
            case .ready:
                ready(account)
            }
        }
    }

    @ViewBuilder private func ready(_ account: MerchantPayoutAccount) -> some View {
        Section {
            if let key = account.stateKey {
                LabeledContent {
                    CYStatusChip(verbatim: payoutText(key, locale), tone: tone(account.tone))
                } label: { Text("payoutAccount.row.state", tableName: "PayoutReceiver") }
                    .accessibilityIdentifier("payoutAccount.state." + (account.state ?? ""))
            }
            if let masked = account.maskedSubMerchantID {
                LabeledContent { Text(verbatim: masked).monospacedDigit() } label: { Text("payoutAccount.row.subMchid", tableName: "PayoutReceiver") }
            }
            if let checked = account.checkedAt {
                LabeledContent { Text(checked, format: .dateTime.month().day().hour().minute()).foregroundStyle(CYColor.textTertiary) }
                    label: { Text("payoutAccount.row.checkedAt", tableName: "PayoutReceiver") }
            }
        } footer: {
            if let description = account.stateDescription { Text(verbatim: description) }
        }
        if let link = account.signURL, let key = account.copyKey {
            Section {
                CYPillButton(LocalizedStringKey(key), style: .primary, tableName: "PayoutReceiver") {
                    LocalPasteboard.copy(link.absoluteString)
                    copied = true
                }
                .accessibilityIdentifier("payoutAccount.copyLink")
                if copied { CYStatusChip(verbatim: payoutText("payoutAccount.copied", locale), tone: .success, systemImage: "doc.on.doc") }
            }
            .listRowBackground(Color.clear)
        }
    }

    private func tone(_ raw: String) -> CYStatusTone {
        switch raw { case "success": return .success; case "warning": return .warning; case "danger": return .danger; default: return .neutral }
    }

    private func load() async {
        state = .loading
        do {
            let account = try await PayoutReceiverBridge.call(session) { try await $0.merchantPayoutAccount(token: $1) }
            state = .ready(account)
        } catch { state = .failed(error as? PayoutReceiverIssue ?? .network) }
    }
}
