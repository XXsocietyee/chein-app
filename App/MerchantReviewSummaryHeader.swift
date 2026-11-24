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
                        Image(systemName: star <= presentation.filledStars ? "star.fill" : "star")
                            .foregroundStyle(star <= presentation.filledStars ? CYColor.warningText : CYColor.textTertiary)
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
            metric(Text(presentation.pendingReplyCount.map { String($0) } ?? "—"), "merchant.reviewSummary.pending", note: "merchant.reviewSummary.pending.note")
            metric(Text(presentation.monthNewCount.map { String($0) } ?? "—"), "merchant.reviewSummary.month", note: "merchant.reviewSummary.month.note")
            metric(Text(presentation.replyRatePct.map { "\($0)%" } ?? "—"), "merchant.reviewSummary.rate", note: "merchant.reviewSummary.rate.note")
            metric(Text(presentation.averageText ?? "—"), "merchant.reviewSummary.average30", note: "merchant.reviewSummary.average30.note")
        }
        .accessibilityIdentifier("merchant.reviewSummary.metrics")
    }
    private func metric(_ value: Text, _ title: LocalizedStringKey, note: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
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
