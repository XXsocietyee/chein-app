import SwiftUI

/// IWP-8a. Unmounted: nothing presents this view, and the default service is `UnavailableBundleReviewClient`.
/// Strings are inline `W8Text` pairs listed in docs/owner-plan/iwp-8a-new-strings.md (no xcstrings edits).
@MainActor struct BundleReviewComposeView: View {
    @ObservedObject var model: BundleReviewComposeModel
    @State private var rating = 5
    @State private var content = ""
    @State private var submitTick = 0
    @ScaledMetric(relativeTo: .body) private var editorMin: CGFloat = 120

    private var inputValid: Bool { BundleReviewComposeModel.isValidInput(rating: rating, content: content) }

    var body: some View {
        // Native r2: an inset-grouped Form under the system inline title.
        Form {
            switch model.state {
            case .idle, .loading:
                Section {
                    ProgressView { Text(verbatim: W8Text.t("加载中…", "Loading…")) }
                        .frame(maxWidth: .infinity)
                }
            case .unavailable:
                Section {
                    ContentUnavailableView(W8Text.t("评价功能暂未开放", "Reviews aren't open yet"), systemImage: "wifi.slash")
                        .accessibilityIdentifier("bundleReview.unavailable")
                }
            case .failed:
                Section {
                    ContentUnavailableView(W8Text.t("暂时无法评价，未发送任何内容", "Can't review right now. Nothing was sent."), systemImage: "exclamationmark.triangle")
                }
            case .blocked(let reason):
                blocked(reason)
            case .alreadyReviewed(let review):
                reviewSummary(review)
            case .submitted(let review):
                reviewSummary(review)
                    .accessibilityIdentifier("bundleReview.submitted")
            case .ready, .submitting, .rejected:
                composeSection
            case .outcomeUnknown:
                outcomeUnknown
            }
        }
        .themeDomain(.player)
        .navigationTitle(Text(verbatim: W8Text.t("评价", "Review")))
        .navigationBarTitleDisplayMode(.inline)
        .cyAnimation(value: model.state)
        .cyHaptic(.success, trigger: model.state) { _, new in
            if case .submitted = new { return true }
            return false
        }
        .task { await model.load() }
    }

    @ViewBuilder private var composeSection: some View {
        Section {
            Picker(selection: $rating) {
                ForEach(Array(BundleReviewCommand.ratingRange), id: \.self) { value in
                    Text(verbatim: String(value)).monospacedDigit().tag(value)
                }
            } label: { Text(verbatim: W8Text.t("评分", "Rating")) }
            .pickerStyle(.menu)
            TextEditor(text: $content)
                .frame(minHeight: editorMin)
                .accessibilityLabel(Text(verbatim: W8Text.t("评价内容", "Review text")))
        } footer: {
            Text(verbatim: "\(content.count)/\(BundleReviewCommand.maxContentLength)")
                .monospacedDigit()
                .accessibilityLabel(Text(verbatim: "\(content.count)/\(BundleReviewCommand.maxContentLength)"))
        }
        if case .rejected(let code) = model.state {
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Cloud03Note(text: Text(verbatim: W8Text.t("评价未被接受", "Your review wasn't accepted")), symbol: "exclamationmark.triangle", tone: .danger)
                    if let code, !code.isEmpty {
                        Text(verbatim: code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("bundleReview.rejected")
            }
        }
        Section {
            Button {
                submitTick += 1
                Task { await model.submit(rating: rating, content: content) }
            } label: {
                HStack(spacing: CYSpacing.sm) {
                    Label(W8Text.t("提交评价", "Submit review"), systemImage: "paperplane.fill")
                    if model.state == .submitting {
                        Spacer(minLength: 0)
                        ProgressView()
                    }
                }
            }
            .disabled(!inputValid || model.state != .ready)
            .accessibilityLabel(Text(verbatim: W8Text.t("提交评价", "Submit review")))
            .cyHaptic(.impactMedium, trigger: submitTick)
        }
    }

    @ViewBuilder private var outcomeUnknown: some View {
        Section {
            Text(verbatim: W8Text.t("评价是否提交成功尚未确认", "We couldn't confirm whether your review was submitted"))
                .fixedSize(horizontal: false, vertical: true)
            Button { Task { await model.recover() } } label: { Text(verbatim: W8Text.t("查询提交结果", "Check status")) }
                .accessibilityLabel(Text(verbatim: W8Text.t("查询提交结果", "Check status")))
            if model.canRetryOriginal {
                Button { Task { await model.retryOriginal() } } label: { Text(verbatim: W8Text.t("重新提交", "Submit again")) }
                    .accessibilityLabel(Text(verbatim: W8Text.t("重新提交", "Submit again")))
            }
        }
    }

    @ViewBuilder private func blocked(_ reason: String?) -> some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: W8Text.t("当前订单暂不可评价", "This order can't be reviewed right now"))
                    .fixedSize(horizontal: false, vertical: true)
                if let reason, !reason.isEmpty {
                    Text(verbatim: reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("bundleReview.blocked")
        }
    }

    @ViewBuilder private func reviewSummary(_ review: BundleReview) -> some View {
        Section {
            LabeledContent {
                Text(verbatim: String(review.rating)).monospacedDigit()
            } label: {
                Text(verbatim: W8Text.t("评分", "Rating"))
            }
            Text(verbatim: review.content)
                .fixedSize(horizontal: false, vertical: true)
            Label {
                Text(verbatim: review.statusKind.label)
            } icon: {
                Image(systemName: reviewSymbol(review.statusKind))
                    .foregroundStyle(Cloud03Note.tint(reviewTone(review.statusKind)))
            }
            .accessibilityIdentifier("bundleReview.status")
        }
    }

    private func reviewTone(_ kind: BundleReviewStatusKind) -> CYStatusTone {
        switch kind {
        case .published: return .success
        case .underReview: return .warning
        case .rejected: return .danger
        case .hidden, .unknown: return .neutral
        }
    }

    private func reviewSymbol(_ kind: BundleReviewStatusKind) -> String {
        switch kind {
        case .published: return "checkmark.circle.fill"
        case .underReview: return "clock.fill"
        case .rejected: return "xmark.circle.fill"
        case .hidden: return "eye.slash"
        case .unknown: return "questionmark.circle"
        }
    }
}

#if DEBUG
#Preview("Review · player dark") {
    ReviewComposePreviewHost(domain: .player)
}
#Preview("Review · merchant light") {
    ReviewComposePreviewHost(domain: .merchant)
}

@MainActor private struct ReviewComposePreviewHost: View {
    let domain: ThemeDomain
    @StateObject private var model: BundleReviewComposeModel
    init(domain: ThemeDomain) {
        self.domain = domain
        let id = try! FreeExploreLaunchID(1)
        _model = StateObject(wrappedValue: BundleReviewComposeModel(registrationID: id, accountID: id, service: UnavailableBundleReviewClient()))
    }
    var body: some View {
        NavigationStack { BundleReviewComposeView(model: model) }
            .themeDomain(domain)
    }
}
#endif
