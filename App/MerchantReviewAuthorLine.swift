import SwiftUI

/// MC7-13-7: the MP review author line — avatar (城 fallback), nickname, time, and 平台复审中 when a public review
/// has a report under platform review.
struct MerchantReviewAuthorLine: View {
    let fields: MerchantBusinessObject
    let fallbackTitle: String

    var body: some View {
        let name = fields.mbText("authorNickname") ?? fallbackTitle
        HStack(alignment: .center, spacing: CYSpacing.sm) {
            CYAvatarView(url: fields.mbText("authorAvatar").flatMap(URL.init(string:)), name: name.isEmpty ? "城" : name, size: .md)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                HStack(spacing: CYSpacing.xs) {
                    if let time = fields.mbText("createTime") {
                        Text(verbatim: time.count >= 16 ? String(time.prefix(16)) : time).monospacedDigit()
                    }
                    if fields["underPlatformReview"]?.bool == true, fields.mbText("status") != "PENDING_REVIEW" {
                        CYStatusChip("merchant.review.underPlatformReview", tone: .warning)
                    }
                }
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
