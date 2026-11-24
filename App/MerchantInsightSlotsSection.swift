import SwiftUI

/// MC7-11-3 · pages/merchant/marketing/ai-insight 到店时段: one bar per slot (早/午/晚/夜) scaled to the peak,
/// the share of check-ins, then 共 N 次打卡 · {peak}到店最多. Data and rounding come from Core `MerchantInsightSlots`.
struct MerchantInsightSlotsSection: View {
    let slots: MerchantInsightSlots

    var body: some View {
        Section {
            ForEach(Array(slots.bars.enumerated()), id: \.offset) { _, bar in
                HStack(spacing: CYSpacing.md) {
                    Text(verbatim: bar.slot)
                        .cyText(bar.isPeak ? .bodyMedium : .body)
                        .foregroundStyle(CYColor.textPrimary)
                        .frame(minWidth: 28, alignment: .leading)
                    ProgressView(value: Double(bar.height), total: 100)
                        .tint(bar.isPeak ? CYColor.brand : CYColor.textTertiary)
                        .accessibilityHidden(true)
                    Text(verbatim: bar.pct)
                        .cyText(.meta)
                        .monospacedDigit()
                        .foregroundStyle(CYColor.textSecondary)
                        .frame(minWidth: 44, alignment: .trailing)
                }
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("merchant.insight.slots.rowA11y \(bar.slot) \(bar.count) \(bar.pct)"))
                .accessibilityIdentifier("merchant.insight.slots.row.\(bar.slot)")
            }
        } header: {
            Text("merchant.insight.slots.title")
        } footer: {
            if slots.peakText.isEmpty {
                Text("merchant.insight.slots.total \(slots.total)")
            } else {
                Text("merchant.insight.slots.totalPeak \(slots.total) \(slots.peakText)")
            }
        }
        .accessibilityIdentifier("merchant.insight.slots")
    }
}
