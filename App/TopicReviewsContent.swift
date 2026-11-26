import SwiftUI

/// Reads only the loaded detail snapshot; no extra fetch, author route or write action.
struct TopicReviewsContent: View {
    let reviews: TopicReviews

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                // C13 (MP `det6`): a known zero is said once, by the empty line below; no 「0」 total.
                let showsTotal = reviews.commentCount != 0
                if !reviews.hasConfirmedNoReviews {
                    LabeledContent("topic.reviews.average") {
                        if let average = reviews.averageRating {
                            // REV-B B-07 (MP index.wxml:289-293): the average, then round(average) filled MP stars.
                            HStack(spacing: 4) {
                                (Text(average, format: .number.precision(.fractionLength(0...1))) + Text(verbatim: " / 5"))
                                    .monospacedDigit()
                                    .accessibilityIdentifier("topic.reviews.average")
                                HStack(spacing: 2) {
                                    ForEach(0..<max(0, min(5, Int(average.rounded()))), id: \.self) { _ in
                                        MPAsset.FeatureIcon.iconStarFilled.resizable().scaledToFit().frame(width: 12, height: 12)
                                    }
                                }
                                .accessibilityHidden(true)
                            }
                        } else {
                            Text("topic.reviews.ratingUnknown")
                                .accessibilityIdentifier("topic.reviews.averageUnknown")
                        }
                    }
                }
                if !reviews.hasConfirmedNoReviews && showsTotal { Divider() }
                if showsTotal {
                    LabeledContent("topic.reviews.total") {
                        if let count = reviews.commentCount {
                            // REV-B B-07: MP 「基于N条评论」.
                            Text("topic.reviews.basedOn \(count)")
                                .monospacedDigit()
                                .accessibilityIdentifier("topic.reviews.count")
                        } else {
                            Text("topic.reviews.countUnknown")
                                .accessibilityIdentifier("topic.reviews.countUnknown")
                        }
                    }
                }
                // C13: no 「评价预览 · 最多显示 5 条」 small print under the list.
                if reviews.preview.isEmpty {
                    if reviews.hasConfirmedNoReviews {
                        Text("topic.reviews.empty")
                            .accessibilityIdentifier("topic.reviews.empty")
                    } else {
                        Text("topic.reviews.previewUnavailable")
                            .accessibilityIdentifier("topic.reviews.previewUnavailable")
                    }
                }
            }
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(reviews.preview.enumerated()), id: \.offset) { index, review in
                UGCBlockedFilterContainer(authorName: review.authorName) {
                    TopicReviewCard(review: review, index: index)
                }
            }
        }
    }
}

private struct TopicReviewCard: View {
    @Environment(\.ugcSafetySubjectID) private var safetySubjectID
    let review: TopicReview
    let index: Int

    private var reviewReportTarget: UGCSafetyReportTarget {
        .topic(id: max(1, safetySubjectID ?? 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let name = review.authorName { Text(verbatim: name) }
                else { Text("topic.reviews.authorUnknown") }
            }
            .font(.headline)
            .accessibilityIdentifier("topic.reviews.author.\(index)")
            if let date = review.createTime {
                Text(verbatim: date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("topic.reviews.rating") {
                if let rating = review.rating { Text(verbatim: "\(rating) / 5") }
                else {
                    Text("topic.reviews.ratingUnknown")
                        .accessibilityIdentifier("topic.reviews.ratingUnknown.\(index)")
                }
            }
            .font(.subheadline).foregroundStyle(.secondary)
            .accessibilityIdentifier("topic.reviews.rating.\(index)")
            Group {
                if let contents = review.contents { Text(verbatim: contents) }
                else { Text("topic.reviews.textUnavailable").foregroundStyle(.secondary) }
            }
            .textSelection(.enabled)
            .accessibilityIdentifier("topic.reviews.text.\(index)")
            UGCReviewSafetyFooter(
                target: reviewReportTarget,
                subjectTitle: review.contents,
                authorName: review.authorName
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
