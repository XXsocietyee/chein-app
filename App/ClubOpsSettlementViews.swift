import SwiftUI

struct ClubOpsSettlementSummaryCard: View {
    @Environment(\.locale) private var locale
    let summary: ClubOpsSettlementSummary
    var body: some View {
        // Mini-program .settled-card: caption, then one large tabular amount; unknown stays 「金额待核验」, never 0.
        // CLB-r10-nat-settlement-06: a LabeledContent row (amount `.monospacedDigit()`) instead of a hero card.
        Section {
            LabeledContent {
                Group {
                    if let amount = summary.settledAmountText { Text(verbatim: amount).monospacedDigit() }
                    else {
                        Text(verbatim: ClubOpsGovernanceCount.unknownDisplay).monospacedDigit()
                            .accessibilityLabel(Text("clubOps.settlement.amountUnverified", tableName: "ClubOpsCustomer"))
                    }
                }
                .accessibilityIdentifier("club.gov.fact.settledAmountStatus")
            } label: {
                Text("clubOps.settlement.settledLabel", tableName: "ClubOpsCustomer")
            }
            if summary.unverifiedSettledCount > 0 {
                Label(String(localized: LocalizedStringResource("clubOps.settlement.unverifiedCount \(summary.unverifiedSettledCount)", table: "ClubOpsCustomer", locale: locale)),
                      systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(CYColor.warningText)
            }
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
