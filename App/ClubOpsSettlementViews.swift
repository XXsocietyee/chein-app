import SwiftUI

struct ClubOpsSettlementSummaryCard: View {
    @Environment(\.locale) private var locale
    let summary: ClubOpsSettlementSummary
    var body: some View {
        // Mini-program .settled-card: caption, then one large tabular amount; unknown stays 「金额待核验」, never 0.
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("clubOps.settlement.settledLabel", tableName: "ClubOpsCustomer").font(.subheadline).foregroundStyle(.secondary)
                Group {
                    if let amount = summary.settledAmountText { Text(verbatim: amount).font(.largeTitle.weight(.semibold)).monospacedDigit() }
                    else {
                        Text(verbatim: ClubOpsGovernanceCount.unknownDisplay).font(.largeTitle.weight(.semibold)).monospacedDigit()
                            .accessibilityLabel(Text("clubOps.settlement.amountUnverified", tableName: "ClubOpsCustomer"))
                    }
                }
                .cyWrapText()
                .accessibilityIdentifier("club.gov.fact.settledAmountStatus")
                if summary.unverifiedSettledCount > 0 {
                    Label(String(localized: LocalizedStringResource("clubOps.settlement.unverifiedCount \(summary.unverifiedSettledCount)", table: "ClubOpsCustomer", locale: locale)),
                          systemImage: "questionmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }
}

/// Co-owners and administrators: no wallet read and no payout path. The mini-program shows a disabled
/// withdraw button plus 「仅主理人可发起提现」; native shows only the fact, never a dead button.
struct ClubOpsSettlementOwnerOnlyWithdraw: View {
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            Label(String(localized: LocalizedStringResource(String.LocalizationValue(ClubOpsWithdrawHint.ownerOnly.localizationKey), table: "ClubOpsCustomer", locale: locale)),
                  systemImage: "lock")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("clubOps.settlement.withdraw.ownerOnly")
        }
    }
}

struct ClubOpsSettlementFootnote: View {
    var body: some View {
        Text("clubOps.settlement.footnote", tableName: "ClubOpsCustomer").font(.footnote).foregroundStyle(.secondary)
            .accessibilityIdentifier("clubOps.settlement.footnote")
    }
}
