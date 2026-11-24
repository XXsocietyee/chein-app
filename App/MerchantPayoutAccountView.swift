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
    @State private var toastMessage: String?
    /// MC7-09-1 (payout-account/index.js:53-55): access/me without an active merchant or finance:read.
    @State private var accessDenied = false

    var body: some View {
        Group {
        if accessDenied {
            MerchantDeniedState(title: "merchant.gate.payout.denied", identifier: "payoutAccount.denied")
        } else {
        List {
            // Owner 2026-11-14: the account state is a status read and always shows.
            content
            if state.needsSeparateReload {
                // F-17: a loaded account (or none) also offers 重新加载, not only the failure card.
                Section {
                    CYPillButton("payoutReceiver.reload", style: .secondary, tableName: "PayoutReceiver") { Task { await load() } }
                        .accessibilityIdentifier("payoutAccount.reload")
                }
                .listRowBackground(Color.clear)
            }
            ClubDirectLedgerSection(scope: .merchant(topicID: nil))
        }
        }
        }
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.merchant)
        .navigationTitle(Text("payoutAccount.title", tableName: "PayoutReceiver")).navigationBarTitleDisplayMode(.inline)
        .refreshable { await load(refreshing: true) }
        .task { await load(refreshing: false) }
        .cyToast(verbatimMessage: $toastMessage)
        .appSwitcherPrivacyShield()
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            Section { CYSkeleton(variant: .formSection) }.accessibilityIdentifier("payoutAccount.loading")
        case .empty:
            Section { CYEmptyState(systemImage: "building.columns", "payoutAccount.none", tableName: "PayoutReceiver", messageIdentifier: "payoutAccount.none") }
        case .failed(let issue):
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("payoutAccount.loadFailed", tableName: "PayoutReceiver").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    PayoutReceiverIssueText(issue: issue, fallbackKey: "payoutAccount.loadFailed")
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
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
                } label: { Text("payoutAccount.row.state", tableName: "PayoutReceiver").cyText(.body).foregroundStyle(CYColor.textSecondary) }
                    .accessibilityIdentifier("payoutAccount.state." + (account.state ?? ""))
            }
            if let masked = account.maskedSubMerchantID {
                LabeledContent { Text(verbatim: masked).cyText(.body).monospacedDigit().foregroundStyle(CYColor.textPrimary) }
                    label: { Text("payoutAccount.row.subMchid", tableName: "PayoutReceiver").cyText(.body).foregroundStyle(CYColor.textSecondary) }
                    // Parity payout P1 (PG-083): 商户号 is a copy-only row.
                    .textSelection(.enabled)
                    .contextMenu { Button("payoutAccount.copySubMchid", systemImage: "doc.on.doc") {
                        UIPasteboard.general.setItems([["public.utf8-plain-text": masked]],
                                                      options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                    } }
            }
            if let checked = account.checkedAt {
                LabeledContent { Text(checked, format: .dateTime.month().day().hour().minute()).cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary) }
                    label: { Text("payoutAccount.row.checkedAt", tableName: "PayoutReceiver").cyText(.body).foregroundStyle(CYColor.textSecondary) }
            }
        } footer: {
            if let description = account.stateDescription {
                Text(verbatim: description)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
        }
        if let link = account.signURL, let key = account.copyKey {
            // HANDOFF-R1 MR-07 (owner Q-A): signing stays a WeChat hand-off — named, with the next steps.
            Section {
                MerchantR1SigningHandOff(copied: copied)
                    .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Color.clear)
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

    private func load(refreshing: Bool = false) async {
        let hadReady: Bool
        if case .ready = state { hadReady = true } else { hadReady = false }
        if !refreshing || !hadReady {
            state = .loading
        }
        // MC7-09-1: the MP checks access/me first; a non-member or a role without finance:read gets the
        // no-permission page (申请入驻 / 返回) instead of the generic reload card. A failed check falls through.
        if let access = try? await session.merchantAccess() {
            accessDenied = !access.active || !access.allows(.finance)
            if accessDenied { return }
        }
        do {
            let account = try await PayoutReceiverBridge.call(session) { try await $0.merchantPayoutAccount(token: $1) }
            state = .ready(account)
        } catch {
            if refreshing && hadReady {
                toastMessage = MerchantCloseCopy.text("刷新失败，稍后再试", "Refresh failed, try again later", locale)
            } else {
                state = .failed(error as? PayoutReceiverIssue ?? .network)
            }
        }
    }
}

extension PayoutPageState {
    /// F-17: every settled state offers 重新加载 (`payoutAccount.reload`). A failure carries it inside its own card; a loaded
    /// account or an empty one gets a separate row. Only the loading skeleton has none.
    var needsSeparateReload: Bool {
        switch self {
        case .ready, .empty: return true
        case .loading, .failed: return false
        }
    }
}
