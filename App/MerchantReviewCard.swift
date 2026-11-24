import SwiftUI

/// Local, display-only status strip for a merchant review row. Actions stay in the
/// existing `rowActions` (reply editor → review → cancel keeps draft / readback).
struct MerchantReviewCard: View {
    let presentation: MerchantReviewCardPresentation
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
            HStack(spacing: CYSpacing.sm) {
                if let rating = presentation.rating {
                    Text(verbatim: "★ \(rating)/5")
                        .cyText(.meta, weight: .bold)
                        .monospacedDigit()
                        .foregroundStyle(CYColor.warningText)
                }
                if presentation.verifiedRedemption {
                    Label {
                        Text("merchant.review.verifiedRedemption", tableName: "MerchantReviewAndCustomerDetail")
                    } icon: {
                        Image(systemName: "checkmark.seal")
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
