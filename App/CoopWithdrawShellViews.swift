import SwiftUI

/// Source `pages/coop/withdraw`: the retired bank-card form now only explains that withdrawals are handled
/// offline by platform support. The single action opens the configured support contact; nothing is submitted.
@MainActor struct CoopWithdrawNoticeView: View {
    let isSignedIn: Bool
    @State private var showsSupport = false
    var body: some View {
        List {
            // Source: the page title says 提现方式已调整; the body is one neutral notice and one action.
            CYHeroHeader("cooperation.withdraw.title").listRowBackground(Color.clear).listRowSeparator(.hidden)
            if isSignedIn {
                CYEmptyState(systemImage: "bubble.left.and.text.bubble.right", "cooperation.finance.withdraw", detail: "cooperation.withdraw.detail",
                             messageIdentifier: "cooperation.withdraw.notice")
                    .listRowBackground(Color.clear)
            } else {
                CYEmptyState(systemImage: "lock", "cooperation.login", messageIdentifier: "cooperation.withdraw.login", kind: .generic)
                    .listRowBackground(Color.clear)
            }
        }
        .cyGroupedSurface()
        .cyMiniListScreen()
        .cyHeroScreen()
        .themeDomain(.merchant)
        .questifyBottomAction {
            if isSignedIn {
                // Opens support. It does not submit a withdrawal.
                CYPillButton("cooperation.finance.withdraw", systemImage: "bubble.left.and.text.bubble.right") { showsSupport = true }
                    .accessibilityIdentifier("cooperation.withdraw.contact")
                    .accessibilityLabel(Text("cooperation.finance.withdraw"))
            }
        }
        .onChange(of: isSignedIn) { _, signedIn in if !signedIn { showsSupport = false } }
        .cySheet(isPresented: $showsSupport) {
            WithdrawalSupportContactView()
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.merchant)
        }
        .accessibilityIdentifier("cooperation.withdraw")
    }
}

/// Source `pages/coop/withdraw/records`: a compatibility shell that forwards to the bank-card withdrawal
/// records (`subpackageMember/tixianjilu`). Without a composed wallet reader it shows the source's
/// open-failure state with a retry instead of a blank page.
@MainActor struct CoopWithdrawRecordsShell: View {
    var reader: WalletCommerceReader? = nil
    /// Retry resolves the wallet session again from the environment; the attempt identity rebuilds the whole shell.
    @Environment(\.coopWalletReader) private var composedReader
    @State private var attempt = 0
    var body: some View {
        Group {
            if let reader = reader ?? composedReader {
                WalletWithdrawalsView(reader: reader)
            } else {
                List {
                    CYEmptyState(systemImage: "exclamationmark.triangle", "cooperation.withdrawRecords.failed.title",
                                 detail: "cooperation.withdrawRecords.failed.detail",
                                 messageIdentifier: "cooperation.withdrawRecords.failed",
                                 actionTitle: "cooperation.refresh", actionIdentifier: "cooperation.withdrawRecords.retry",
                                 actionStyle: .primary, kind: .failure) { attempt += 1 }
                        .listRowBackground(Color.clear)
                }
                .cyGroupedSurface()
                .cyMiniListScreen()
                .themeDomain(.merchant)
            }
        }
        .id(attempt)
        .cyPageTitle("cooperation.withdrawRecords.title")
        .accessibilityIdentifier("cooperation.withdrawRecords")
    }
}

/// Legacy `pages/coop/withdraw` and `pages/coop/withdraw/records` routes are deep links in the source;
/// natively they hang off the cooperation business section next to profit share details.
@MainActor struct CoopWithdrawEntryLinks: View {
    let isSignedIn: Bool
    @Environment(\.coopWalletReader) private var walletReader
    var body: some View {
        NavigationLink { CoopWithdrawNoticeView(isSignedIn: isSignedIn) } label: {
            CYListRow("cooperation.withdraw.entry", meta: "cooperation.withdraw.subtitle", trailing: .none) {
                CYRowIcon(systemImage: "bubble.left.and.text.bubble.right")
            }
        }
        .accessibilityIdentifier("cooperation.withdraw.open")
        NavigationLink { CoopWithdrawRecordsShell(reader: walletReader) } label: {
            CYListRow("cooperation.withdrawRecords.title", meta: "cooperation.withdrawRecords.subtitle", trailing: .none) {
                CYRowIcon(systemImage: "list.bullet")
            }
        }
        .accessibilityIdentifier("cooperation.withdrawRecords.open")
    }
}
