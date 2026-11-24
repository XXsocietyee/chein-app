import SwiftUI

struct MerchantInsightAttributionSummary: View {
    let summary: MerchantInsightAttribution
    let isCurrent: Bool
    var facts: MerchantMarketingValue = .null
    var onCoopCenter: (() -> Void)? = nil
    /// MC7-11-8: 重新加载 for facts that did not load completely.
    var onReload: (() -> Void)? = nil
    var body: some View {
        Section("merchant.insightAttribution.title") {
            if !isCurrent {
                Text("merchantMarketing.stale").foregroundStyle(.secondary)
                    .accessibilityIdentifier("merchant.insightAttribution.stale")
            } else {
                LabeledContent("merchantMarketing.window", value: summary.window ?? "—")
                if let counts = summary.counts {
                    LabeledContent("merchant.insightAttribution.visitors", value: String(counts.visitors))
                    LabeledContent("merchant.insightAttribution.checkins", value: String(counts.checkins))
                    LabeledContent("merchant.insightAttribution.redeems", value: String(counts.redeems))
                    if counts.isEmpty { Text("merchant.insightAttribution.empty").foregroundStyle(.secondary) }
                    MerchantInsightParityRows(facts: facts, isEmpty: counts.isEmpty, onCoopCenter: onCoopCenter)
                } else {
                    // MC7-11-8 (ai-insight/index.wxml:80-82): unknown is not zero — 店铺数据没加载完整 + 重新加载.
                    Text("merchant.insight.factsIncomplete").foregroundStyle(.secondary)
                        .accessibilityIdentifier("merchant.insightAttribution.unavailable")
                    if let onReload {
                        Button("merchant.gate.reload", action: onReload)
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .accessibilityIdentifier("merchant.insightAttribution.reload")
                    }
                }
                if let split = summary.split {
                    LabeledContent("merchant.insightAttribution.newVisitors", value: String(split.newVisitors))
                    LabeledContent("merchant.insightAttribution.returningVisitors", value: String(split.returningVisitors))
                } else { Text("merchant.insightAttribution.splitUnavailable").foregroundStyle(.secondary) }
            }
        }
    }
}
