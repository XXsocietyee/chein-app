import SwiftUI

struct ClubOpsSettlementSummaryCard: View {
    @Environment(\.locale) private var locale
    let summary: ClubOpsSettlementSummary
    var body: some View {
        // Mini-program .settled-card: caption, then one large tabular amount; unknown stays 「金额待核验」, never 0.
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("clubOps.settlement.settledLabel", tableName: "ClubOpsCustomer").cyText(.label).foregroundStyle(CYColor.textSecondary)
                Group {
                    if let amount = summary.settledAmountText { Text(verbatim: amount).cyText(.data2XL).monospacedDigit() }
                    else {
                        Text(verbatim: ClubOpsGovernanceCount.unknownDisplay).cyText(.data2XL).monospacedDigit()
                            .accessibilityLabel(Text("clubOps.settlement.amountUnverified", tableName: "ClubOpsCustomer"))
                    }
                }
                .foregroundStyle(CYColor.textPrimary)
                .cyWrapText()
                .accessibilityIdentifier("club.gov.fact.settledAmountStatus")
                if summary.unverifiedSettledCount > 0 {
                    CYStatusChip(verbatim: String(localized: LocalizedStringResource("clubOps.settlement.unverifiedCount \(summary.unverifiedSettledCount)", table: "ClubOpsCustomer", locale: locale)),
                                 tone: .warning, systemImage: "questionmark.circle")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cyDomainCard(radius: CYRadius.hero, padding: CYSpacing.lg)
            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear)
        }
    }
}

/// Co-owners and administrators: no wallet read and no payout path. The mini-program shows a disabled
/// withdraw button plus 「仅主理人可发起提现」; native shows only the fact, never a dead button.
struct ClubOpsSettlementOwnerOnlyWithdraw: View {
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            CYStatusChip(verbatim: String(localized: LocalizedStringResource(String.LocalizationValue(ClubOpsWithdrawHint.ownerOnly.localizationKey), table: "ClubOpsCustomer", locale: locale)),
                         tone: .neutral, systemImage: "lock")
                .accessibilityIdentifier("clubOps.settlement.withdraw.ownerOnly")
        }
    }
}

struct ClubOpsSettlementFootnote: View {
    var body: some View {
        Text("clubOps.settlement.footnote", tableName: "ClubOpsCustomer").cyText(.caption).foregroundStyle(CYColor.textTertiary)
            .accessibilityIdentifier("clubOps.settlement.footnote")
    }
}
