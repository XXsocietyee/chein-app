import SwiftUI

/// No independent cache or action: lifecycle and access belong to the current authorized detail host.
struct MerchantRedemptionProgressView: View {
    let progress: MerchantRedemptionProgress
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.s2_5) {
            Text("merchant.redemptionProgress.title")
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
            ForEach(progress.steps) { step in
                HStack(alignment: .top, spacing: CYSpacing.s2_5) {
                    Image(systemName: step.state == .done ? "checkmark.circle.fill" : step.state == .current ? "circle.inset.filled" : "circle")
                        .foregroundStyle(step.state == .done ? CYColor.successText : CYColor.textSecondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(LocalizedStringKey("merchant.redemptionProgress.step." + step.id))
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                        Text(LocalizedStringKey("merchant.settlementProgress.stepState." + step.state.rawValue))
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                        if let raw = step.timestamp {
                            MerchantSettlementTimestampText(raw: raw)
                                .cyText(.meta)
                                .monospacedDigit()
                                .foregroundStyle(CYColor.textSecondary)
                        }
                    }
                }.fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("merchant.redemptionProgress.step." + step.id)
            }
        }.accessibilityIdentifier("merchant.redemptionProgress")
    }
}
