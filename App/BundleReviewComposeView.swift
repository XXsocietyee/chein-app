import SwiftUI

/// IWP-8a. Unmounted: nothing presents this view, and the default service is `UnavailableBundleReviewClient`.
/// Strings are inline `W8Text` pairs listed in docs/owner-plan/iwp-8a-new-strings.md (no xcstrings edits).
@MainActor struct BundleReviewComposeView: View {
    @ObservedObject var model: BundleReviewComposeModel
    @State private var rating = 5
    @State private var content = ""

    private var inputValid: Bool { BundleReviewComposeModel.isValidInput(rating: rating, content: content) }

    var body: some View {
        Form {
            switch model.state {
            case .idle, .loading:
                Section { ProgressView() }
            case .unavailable:
                Section { Text(verbatim: W8Text.t("评价功能暂未开放", "Reviews are not available yet")) }
                    .accessibilityIdentifier("bundleReview.unavailable")
            case .failed:
                Section { Text(verbatim: W8Text.t("暂时无法评价，未发送任何内容", "Can't review right now. Nothing was sent.")) }
            case .blocked(let reason):
                Section {
                    Text(verbatim: W8Text.t("当前订单暂不可评价", "This order can't be reviewed right now"))
                    if let reason, !reason.isEmpty { Text(verbatim: reason).font(.caption) }
                }
                .accessibilityIdentifier("bundleReview.blocked")
            case .alreadyReviewed(let review):
                Section { reviewSummary(review) }
            case .submitted(let review):
                Section { reviewSummary(review) }
                    .accessibilityIdentifier("bundleReview.submitted")
            case .ready, .submitting, .rejected:
                composeSection
            case .outcomeUnknown:
                Section {
                    Text(verbatim: W8Text.t("评价是否提交成功尚未确认", "We couldn't confirm whether your review was submitted"))
                    Button { Task { await model.recover() } } label: {
                        Text(verbatim: W8Text.t("查询提交结果", "Check status"))
                    }
                    if model.canRetryOriginal {
                        Button { Task { await model.retryOriginal() } } label: {
                            Text(verbatim: W8Text.t("重新提交", "Submit again"))
                        }
                    }
                }
            }
        }
        .task { await model.load() }
    }

    @ViewBuilder private var composeSection: some View {
        Section {
            Picker(selection: $rating) {
                ForEach(Array(BundleReviewCommand.ratingRange), id: \.self) { Text(verbatim: String($0)).tag($0) }
            } label: { Text(verbatim: W8Text.t("评分", "Rating")) }
            TextEditor(text: $content).frame(minHeight: 120)
            Text(verbatim: "\(content.count)/\(BundleReviewCommand.maxContentLength)").font(.caption)
        }
        if case .rejected(let code) = model.state {
            Section {
                Text(verbatim: W8Text.t("评价未被接受", "Your review wasn't accepted"))
                if let code, !code.isEmpty { Text(verbatim: code).font(.caption) }
            }
            .accessibilityIdentifier("bundleReview.rejected")
        }
        Section {
            Button { Task { await model.submit(rating: rating, content: content) } } label: {
                Text(verbatim: W8Text.t("提交评价", "Submit review"))
            }
            .disabled(!inputValid || model.state != .ready)
        }
    }

    @ViewBuilder private func reviewSummary(_ review: BundleReview) -> some View {
        LabeledContent { Text(verbatim: String(review.rating)) } label: { Text(verbatim: W8Text.t("评分", "Rating")) }
        Text(verbatim: review.content)
        Text(verbatim: review.statusKind.label).font(.footnote)
            .accessibilityIdentifier("bundleReview.status")
    }
}
