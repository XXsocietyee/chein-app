import SwiftUI

/// Reads only the loaded detail snapshot; no extra fetch, author route or write action.
struct ActivityReviewsSection: View {
    let reviews: ActivityReviews

    var body: some View {
        Section("activity.reviews.title") {
            // System rows: average and total as label/value rows, then one row per review.
            Group {
                if !reviews.hasConfirmedNoReviews {
                    LabeledContent("activity.reviews.average") {
                        if let average = reviews.averageRating {
                            (Text(average, format: .number.precision(.fractionLength(0...1))) + Text(verbatim: " / 5"))
                                .accessibilityIdentifier("activity.reviews.average")
                        } else {
                            Text("activity.reviews.ratingUnknown")
                                .accessibilityIdentifier("activity.reviews.averageUnknown")
                        }
                    }
                }
                LabeledContent("activity.reviews.total") {
                    if let count = reviews.commentCount {
                        Text(count, format: .number)
                            .accessibilityIdentifier("activity.reviews.count")
                    } else {
                        Text("activity.reviews.countUnknown")
                            .accessibilityIdentifier("activity.reviews.countUnknown")
                    }
                }
                if reviews.preview.isEmpty {
                    if reviews.hasConfirmedNoReviews {
                        Text("activity.reviews.empty")
                            .accessibilityIdentifier("activity.reviews.empty")
                    } else {
                        Text("activity.reviews.previewUnavailable")
                            .accessibilityIdentifier("activity.reviews.previewUnavailable")
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(reviews.preview.enumerated()), id: \.offset) { index, review in
                UGCBlockedFilterContainer(authorName: review.authorName) {
                    ActivityReviewCard(review: review, index: index)
                }
            }
        }
    }
}

private struct ActivityReviewCard: View {
    @Environment(\.locale) private var locale
    @Environment(\.ugcSafetySubjectID) private var safetySubjectID
    let review: ActivityReview
    let index: Int

    private var reportTarget: UGCSafetyReportTarget {
        .activity(activityID: max(1, safetySubjectID ?? 1))
    }

    var body: some View {
        // Mini-program `activity-comment`: name and time, stars, then the text.
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Group {
                    if let name = review.authorName { Text(verbatim: name) }
                    else { Text("activity.reviews.authorUnknown") }
                }
                .font(.headline)
                .accessibilityIdentifier("activity.reviews.author.\(index)")
                Spacer(minLength: 8)
                if let date = review.createTime {
                    Text(verbatim: LocaleDisplay.civil(date, locale: locale))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Group {
                if let rating = review.rating {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { star in
                            Image(systemName: star < rating ? "star.fill" : "star")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(CYColor.ratingStar)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("a11y.value.ofTotal \(rating) \(5)"))
                } else {
                    Text(verbatim: "—").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("activity.reviews.rating.\(index)")
            if let contents = review.contents {
                Text(verbatim: contents)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("activity.reviews.text.\(index)")
            }
            UGCReviewSafetyFooter(
                target: reportTarget,
                subjectTitle: review.contents,
                authorName: review.authorName
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
