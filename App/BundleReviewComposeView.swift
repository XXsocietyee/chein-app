import SwiftUI

/// IWP-8a. Unmounted: nothing presents this view, and the default service is `UnavailableBundleReviewClient`.
/// Strings are inline `W8Text` pairs listed in docs/owner-plan/iwp-8a-new-strings.md (no xcstrings edits).
@MainActor struct BundleReviewComposeView: View {
    @ObservedObject var model: BundleReviewComposeModel
    @State private var rating = 5
    @State private var content = ""
    @State private var submitTick = 0
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var editorMin: CGFloat = 120
    @ScaledMetric(relativeTo: .largeTitle) private var artHeight: CGFloat = 112

    private var inputValid: Bool { BundleReviewComposeModel.isValidInput(rating: rating, content: content) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                // Native restyle r1 (spec §3.1): the title is the system inline title; the cover stays as the hero.
                CYCoverArt(seed: "bundle-review", symbol: "star.bubble", showsDebugLabel: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: artHeight)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
                    .accessibilityHidden(true)
                switch model.state {
                case .idle, .loading:
                    CYSkeleton()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: W8Text.t("加载中…", "Loading…")))
                case .unavailable:
                    CYStateLayout(
                        kind: .offline,
                        title: Text(verbatim: W8Text.t("评价功能暂未开放", "Reviews aren't open yet"))
                    )
                    .accessibilityIdentifier("bundleReview.unavailable")
                case .failed:
                    CYStateLayout(
                        kind: .failure,
                        title: Text(verbatim: W8Text.t("暂时无法评价，未发送任何内容", "Can't review right now. Nothing was sent."))
                    )
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
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.top, CYSpacing.md)
            .padding(.bottom, CYSpacing.xxl)
        }
        .cyDomainPageBackground()
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

    private var composeSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Picker(selection: $rating) {
                ForEach(Array(BundleReviewCommand.ratingRange), id: \.self) { value in
                    Text(verbatim: String(value)).monospacedDigit().tag(value)
                }
            } label: { Text(verbatim: W8Text.t("评分", "Rating")) }
            .pickerStyle(.menu)
            .cyText(.body)
            .frame(minHeight: CYSpacing.minTouchTarget)
            TextEditor(text: $content)
                .cyText(.body)
                .frame(minHeight: editorMin)
                .scrollContentBackground(.hidden)
                .padding(CYSpacing.sm)
                .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
                .accessibilityLabel(Text(verbatim: W8Text.t("评价内容", "Review text")))
            Text(verbatim: "\(content.count)/\(BundleReviewCommand.maxContentLength)")
                .cyText(.caption)
                .monospacedDigit()
                .foregroundStyle(palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "\(content.count)/\(BundleReviewCommand.maxContentLength)"))
        }
        if case .rejected(let code) = model.state {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                CYNoteBanner(text: Text(verbatim: W8Text.t("评价未被接受", "Your review wasn't accepted")), symbol: "exclamationmark.triangle", tone: .danger)
                if let code, !code.isEmpty {
                    Text(verbatim: code)
                        .cyText(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityIdentifier("bundleReview.rejected")
        }
        if model.state == .submitting {
            ProgressView()
                .accessibilityLabel(Text(verbatim: W8Text.t("提交评价", "Submit review")))
        }
        CYPillButton(verbatim: W8Text.t("提交评价", "Submit review"), systemImage: "paperplane.fill") {
            submitTick += 1
            Task { await model.submit(rating: rating, content: content) }
        }
        .disabled(!inputValid || model.state != .ready)
        .accessibilityLabel(Text(verbatim: W8Text.t("提交评价", "Submit review")))
        .cyHaptic(.impactMedium, trigger: submitTick)
        }
    }

    @ViewBuilder private var outcomeUnknown: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(verbatim: W8Text.t("评价是否提交成功尚未确认", "We couldn't confirm whether your review was submitted"))
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            CYPillButton(verbatim: W8Text.t("查询提交结果", "Check status")) { Task { await model.recover() } }
                .accessibilityLabel(Text(verbatim: W8Text.t("查询提交结果", "Check status")))
            if model.canRetryOriginal {
                CYPillButton(verbatim: W8Text.t("重新提交", "Submit again"), style: .secondary) { Task { await model.retryOriginal() } }
                    .accessibilityLabel(Text(verbatim: W8Text.t("重新提交", "Submit again")))
            }
        }
    }

    @ViewBuilder private func blocked(_ reason: String?) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: W8Text.t("当前订单暂不可评价", "This order can't be reviewed right now"))
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let reason, !reason.isEmpty {
                Text(verbatim: reason)
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("bundleReview.blocked")
    }

    @ViewBuilder private func reviewSummary(_ review: BundleReview) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: W8Text.t("评分", "Rating"))
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: String(review.rating))
                    .cyText(.dataXL)
                    .monospacedDigit()
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Text(verbatim: review.content)
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            CYStatusChip(verbatim: review.statusKind.label, tone: reviewTone(review.statusKind), systemImage: reviewSymbol(review.statusKind))
                .accessibilityIdentifier("bundleReview.status")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.lg)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
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
