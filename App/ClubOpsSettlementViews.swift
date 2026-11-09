import SwiftUI

struct ClubOpsSettlementSummaryCard: View {
    let summary: ClubOpsSettlementSummary
    var body: some View {
        // Mini-program .settled-card: caption, then one large tabular amount; unknown stays 「金额待核验」, never 0.
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("clubOps.settlement.settledLabel", tableName: "ClubOpsCustomer").font(CYTypography.label).foregroundStyle(CYColor.textSecondary)
                Group {
                    if let amount = summary.settledAmountText { Text(verbatim: amount).font(CYTypography.data2XL).monospacedDigit() }
                    else { Text("clubOps.settlement.amountUnverified", tableName: "ClubOpsCustomer").font(CYTypography.sectionTitle) }
                }
                .foregroundStyle(CYColor.textPrimary)
                .minimumScaleFactor(0.6).lineLimit(1)
                .accessibilityIdentifier("club.gov.fact.settledAmountStatus")
                if summary.unverifiedSettledCount > 0 {
                    Text("clubOps.settlement.unverifiedCount \(summary.unverifiedSettledCount)", tableName: "ClubOpsCustomer")
                        .font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CYSpacing.lg)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear)
        }
    }
}

/// Co-owners and administrators: no wallet read and no payout path. The mini-program shows a disabled
/// withdraw button plus 「仅主理人可发起提现」; native shows only the fact, never a dead button.
struct ClubOpsSettlementOwnerOnlyWithdraw: View {
    var body: some View {
        Section {
            Label { Text(LocalizedStringKey(ClubOpsWithdrawHint.ownerOnly.localizationKey), tableName: "ClubOpsCustomer") }
                icon: { Image(systemName: "lock") }
                .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("clubOps.settlement.withdraw.ownerOnly")
        }
    }
}

struct ClubOpsSettlementFootnote: View {
    var body: some View {
        Text("clubOps.settlement.footnote", tableName: "ClubOpsCustomer").font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
            .accessibilityIdentifier("clubOps.settlement.footnote")
    }
}
