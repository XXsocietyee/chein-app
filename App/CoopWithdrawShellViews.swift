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
                Section { CYStatusChip("cooperation.login", tone: .neutral, systemImage: "person.crop.circle.badge.questionmark").accessibilityIdentifier("cooperation.withdraw.login") }
            }
        }
        .cyGroupedSurface()
        .cyMiniListScreen()
        .cyHeroScreen()
        .questifyBottomAction {
            if isSignedIn {
                CYPillButton("cooperation.finance.withdraw") { showsSupport = true }
                    .accessibilityIdentifier("cooperation.withdraw.contact")
            }
        }
        .onChange(of: isSignedIn) { _, signedIn in if !signedIn { showsSupport = false } }
        .sheet(isPresented: $showsSupport) { WithdrawalSupportContactView() }
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
                CYEmptyState(systemImage: "exclamationmark.triangle", "cooperation.withdrawRecords.failed.title",
                             detail: "cooperation.withdrawRecords.failed.detail",
                             messageIdentifier: "cooperation.withdrawRecords.failed",
                             actionTitle: "cooperation.refresh", actionIdentifier: "cooperation.withdrawRecords.retry") { attempt += 1 }
            }
        }
        .id(attempt)
        .appNavigationTitle("cooperation.withdrawRecords.title")
        .accessibilityIdentifier("cooperation.withdrawRecords")
    }
}

/// Legacy `pages/coop/withdraw` and `pages/coop/withdraw/records` routes are deep links in the source;
/// natively they hang off the cooperation business section next to profit share details.
@MainActor struct CoopWithdrawEntryLinks: View {
    let isSignedIn: Bool
    @Environment(\.coopWalletReader) private var walletReader
    var body: some View {
        NavigationLink { CoopWithdrawNoticeView(isSignedIn: isSignedIn) } label: { Text("cooperation.withdraw.entry") }
            .accessibilityIdentifier("cooperation.withdraw.open")
        NavigationLink { CoopWithdrawRecordsShell(reader: walletReader) } label: { Text("cooperation.withdrawRecords.title") }
            .accessibilityIdentifier("cooperation.withdrawRecords.open")
    }
}
