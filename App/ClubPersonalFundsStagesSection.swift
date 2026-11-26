import SwiftUI

/// CLB-r9-settlement-01 (MP pages/club/settlement/index.wxml:13 `cy-funds-stages` when isOwner ‖ personal): the
/// personal settlement path shows the same balance stages (/api/wallet/stages via the session's wallet reader) as
/// 管理 → 结算. A read only; it reports the availability upward so the withdraw button can follow it
/// (CLB-settlement-06, MP js:261-264 onStages → withdrawState / complaintWaiting).
@MainActor struct ClubPersonalFundsStagesSection: View {
    let context: ClubOwnerFundsContext
    @Binding var availability: ClubOwnerFundsAvailability
    @Binding var complaintWaiting: Bool
    private enum Phase: Equatable { case loading, failed, ready(WalletFundsStages) }
    @State private var phase: Phase = .loading
    var body: some View {
        Section("club.ownerFunds.title") {
            switch phase {
            case .loading:
                CYLoadingStateView(rows: 1)
                    .accessibilityLabel(Text("wallet.loading"))
            case .failed:
                HStack {
                    Text("wallet.failed").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    Spacer()
                    Button("wallet.retry") { Task { await load() } }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("clubSettlement.funds.retry")
                }
            case .ready(let value):
                if !value.amountsKnown {
                    Text("wallet.amountsUnknown").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                row("wallet.available", value.amountsKnown ? money(value.withdrawable) : "—")
                if value.pendingSettlement.value > 0 { row("wallet.pendingSettlement", money(value.pendingSettlement)) }
                ForEach(Array(value.complaintPeriod.enumerated()), id: \.offset) { _, item in
                    LabeledContent {
                        Text(verbatim: money(item.amount)).monospacedDigit()
                    } label: {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text("wallet.complaintPeriod")
                            Text(verbatim: item.availableDate).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                    }
                }
                if value.disputed.value > 0 { row("wallet.disputed", money(value.disputed)) }
            }
        }
        .accessibilityIdentifier("clubSettlement.funds")
        .task { await load() }
    }
    private func row(_ key: LocalizedStringKey, _ amount: String) -> some View {
        LabeledContent { Text(verbatim: amount).monospacedDigit() } label: { Text(key) }
    }
    /// Owner decision 9: ¥ with two decimals through the shared club formatter.
    private func money(_ amount: WalletAmount) -> String { ClubMoneyText.display(amount.text) }
    private func load() async {
        phase = .loading; availability = .unknown; complaintWaiting = false
        guard let reader = context.reader, reader.isConfigured else { phase = .failed; return }
        do {
            let value = try await reader.readClubOwnerFunds()
            guard context.isCurrent(), !Task.isCancelled else { return }
            phase = .ready(value)
            availability = ClubOwnerFundsAvailability(value)
            // MP 第十一轮 h4: 客诉期结束后可提现 only while money is actually waiting in the complaint period.
            complaintWaiting = !value.complaintPeriod.isEmpty
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }
}
