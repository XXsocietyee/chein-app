import SwiftUI

/// Local, display-only status strip for a merchant review row. Actions stay in the
/// existing `rowActions` (reply editor → review → cancel keeps draft / readback).
struct MerchantReviewCard: View {
    let presentation: MerchantReviewCardPresentation
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
            HStack(spacing: CYSpacing.sm) {
                if let rating = presentation.rating {
                    // MP asset (reviews/index.wxml:160-163): small filled stars up to the rating, muted for the rest.
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            MerchantMPIcon(image: star <= rating ? MPAsset.FeatureIcon.iconStarSmall : MPAsset.FeatureIcon.iconStarMuted, size: 12)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("merchant.reviewSummary.stars \(rating)"))
                }
                if presentation.verifiedRedemption {
                    Label {
                        Text("merchant.review.verifiedRedemption", tableName: "MerchantReviewAndCustomerDetail")
                    } icon: {
                        MerchantMPIcon(image: MPAsset.FeatureIcon.iconCheckGreen, size: 14)
                    }
                    .cyText(.meta)
                    .foregroundStyle(CYColor.successText)
                }
                if presentation.photoCount > 0 {
                    Label {
                        Text(
                            "merchant.review.photoCount \(presentation.photoCount)",
                            tableName: "MerchantReviewAndCustomerDetail"
                        )
                    } icon: {
                        Image(systemName: "photo")
                    }
                    .cyText(.meta)
                    .monospacedDigit()
                    .foregroundStyle(CYColor.textSecondary)
                }
            }
            HStack(spacing: CYSpacing.sm) {
                CYStatusChip(
                    verbatim: NSLocalizedString(
                        presentation.visibilityTitleKey,
                        tableName: "MerchantReviewAndCustomerDetail",
                        comment: ""
                    ),
                    tone: .neutral
                )
                .accessibilityIdentifier("merchant.business.review.visibility")
                Text(
                    LocalizedStringKey(presentation.replyTitleKey),
                    tableName: "MerchantReviewAndCustomerDetail"
                )
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("merchant.business.review.replyState")
            }
        }.accessibilityElement(children: .combine)
    }
}
