import SwiftUI

/// Mini-program reviews header: score, five stars and "{total} 条已核销评价 · 商家不能改用户原评",
/// followed by the four manage-mode metrics (value and label, as in the source cards). Server summary fields remain below.
struct MerchantReviewSummaryHeader: View {
    let presentation: MerchantReviewSummaryPresentation
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("merchant.reviewSummary.title").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(presentation.averageText ?? "—").cyText(.data2XL).foregroundStyle(CYColor.textPrimary).monospacedDigit()
                    .accessibilityIdentifier("merchant.reviewSummary.average")
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        // MP asset (reviews/index.wxml:42): icon-star-filled / icon-star-muted.
                        MerchantMPIcon(image: star <= presentation.filledStars ? MPAsset.FeatureIcon.iconStarFilled : MPAsset.FeatureIcon.iconStarMuted, size: 18)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("merchant.reviewSummary.stars \(presentation.filledStars)"))
            }
            Text("merchant.reviewSummary.total \(presentation.total)")
                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("merchant.reviewSummary.total")
        }
        .padding(.vertical, 4)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: CYSpacing.md) {
            metric(Text(presentation.pendingReplyCount.map { String($0) } ?? "—"), "merchant.reviewSummary.pending", icon: MPAsset.FeatureIcon.iconBubble, note: "merchant.reviewSummary.pending.note")
            metric(Text(presentation.monthNewCount.map { String($0) } ?? "—"), "merchant.reviewSummary.month", icon: MPAsset.FeatureIcon.iconPlus, note: "merchant.reviewSummary.month.note")
            metric(Text(presentation.replyRatePct.map { "\($0)%" } ?? "—"), "merchant.reviewSummary.rate", icon: MPAsset.FeatureIcon.iconCheckBlue, note: "merchant.reviewSummary.rate.note")
            metric(Text(presentation.averageText ?? "—"), "merchant.reviewSummary.average30", icon: MPAsset.FeatureIcon.iconStarOutline, note: "merchant.reviewSummary.average30.note")
        }
        .accessibilityIdentifier("merchant.reviewSummary.metrics")
    }
    private func metric(_ value: Text, _ title: LocalizedStringKey, icon: Image, note: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // MP asset (reviews/index.wxml:50-75): each manage metric card leads with its review-stat icon.
            MerchantMPIcon(image: icon, size: 20)
            value.cyText(.cardTitle, monospacedDigit: true).foregroundStyle(CYColor.textPrimary).monospacedDigit()
            Text(title).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
            Text(note).cyText(.meta).foregroundStyle(CYColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.md)
        .background(CYColor.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
