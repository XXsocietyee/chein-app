import SwiftUI

// Mini-program `subpackageA/pages/video-bounty/index` (creator video bounty, author side).
// Tabs "my submissions" / "plays and accruals"; the submit form shows only when the page was opened from an ops campaign
// link (campaignKey + topicId). Accruals are record-only: payout stays OFF and is never written as withdrawable.

enum VideoBountyTab: String, CaseIterable, Identifiable, Hashable { case submissions, accruals; var id: String { rawValue } }

enum VideoBountyPlatform: String, CaseIterable, Identifiable, Hashable {
    case tiktok, reels, youtube
    var id: String { rawValue }
    /// Brand names stay verbatim in every language.
    var label: String {
        switch self {
        case .tiktok: "TikTok"
        case .reels: "Instagram Reels"
        case .youtube: "YouTube"
        }
    }
}

/// Server `statusLabel`; anything else maps to `.unknown` in the binding.
enum VideoBountyStatus: String, Equatable {
    case submitted = "SUBMITTED", underReview = "UNDER_REVIEW", approved = "APPROVED", rejected = "REJECTED"
    case revoked = "REVOKED", appealing = "APPEALING", cancelled = "CANCELLED", unknown = "UNKNOWN"

    var label: LocalizedStringKey {
        switch self {
        case .submitted: "mp.vb.status.submitted"
        case .underReview: "mp.vb.status.underReview"
        case .approved: "mp.vb.status.approved"
        case .rejected: "mp.vb.status.rejected"
        case .revoked: "mp.vb.status.revoked"
        case .appealing: "mp.vb.status.appealing"
        case .cancelled: "mp.vb.status.cancelled"
        case .unknown: "mp.vb.status.unknown"
        }
    }
}

struct VideoBountySubmissionRow: Identifiable, Equatable {
    let id: String
    let platform: VideoBountyPlatform?
    let sourceURL: String?
    let status: VideoBountyStatus
    /// Review note, only for REJECTED.
    let reviewNote: String?
    /// Counting window end, only for APPROVED (already formatted, e.g. "2026.11.30").
    let windowEndText: String?
    let canAppeal: Bool
    let canCancel: Bool
}

struct VideoBountyAccrualRow: Identifiable, Equatable {
    let id: String
    /// Formatted payable amount ("¥12.30" / "USD 3.00"); nil renders an em dash, never 0.
    let amountText: String?
    let views: Int?
    let groupViews: Int?
}

enum VideoBountyFormField: Equatable { case platform, sourceURL }

struct VideoBountyState: Equatable {
    var submissions: MPLoad<[VideoBountySubmissionRow]> = .loading
    var accruals: MPLoad<[VideoBountyAccrualRow]> = .loading
    var submitting = false
    /// Field-level error (platform missing / link missing), already localized by the binding or nil.
    var fieldError: (field: VideoBountyFormField, text: String)? = nil
    /// Reason-code sentence from a refused submit, or the "result pending" sentence after a network loss.
    var submitError: String? = nil
    /// Bumps after a successful submit so the view can clear the form and switch tabs.
    var submitRevision = 0
    /// Nil until the reader asks. Counts inside a ready value are already em dashes when unconfirmed.
    var attribution: MPLoad<VideoBountyAttributionFact>? = nil
    /// PC-D-7-1: no session token. The page shows one sign-in gate (MP cy-access-gate kind=login), not two 读取失败.
    var signedOut = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.submissions == rhs.submissions && lhs.accruals == rhs.accruals && lhs.submitting == rhs.submitting
            && lhs.fieldError?.field == rhs.fieldError?.field && lhs.fieldError?.text == rhs.fieldError?.text
            && lhs.submitError == rhs.submitError && lhs.submitRevision == rhs.submitRevision
            && lhs.attribution == rhs.attribution && lhs.signedOut == rhs.signedOut
    }
}

/// Implemented by `VideoBountySessionModel`: `/api/video-bounty/submission/mine`, `/accrual/mine`, submit, appeal, cancel.
@MainActor protocol VideoBountyBinding: AnyObject, Observable {
    var state: VideoBountyState { get }
    func load()
    func submit(campaignKey: String, topicID: String, platform: VideoBountyPlatform?, sourceURL: String, originGroupKey: String)
    func appeal(submissionID: String, note: String)
    func cancel(submissionID: String)
    func loadSubmissionAttribution(id: String)
    func loadCampaignAttribution(campaignID: String, topicID: String)
}

@MainActor struct VideoBountyHost: View {
    let binding: any VideoBountyBinding
    let campaignKey: String?
    let topicID: String?

    var body: some View {
        VideoBountyView(
            state: binding.state,
            campaign: campaignKey.flatMap { key in topicID.map { (key, $0) } },
            onLoad: { binding.load() },
            onSubmit: { binding.submit(campaignKey: $0, topicID: $1, platform: $2, sourceURL: $3, originGroupKey: $4) },
            onAppeal: { binding.appeal(submissionID: $0, note: $1) },
            onCancel: { binding.cancel(submissionID: $0) },
            onSubmissionAttribution: { binding.loadSubmissionAttribution(id: $0) },
            onCampaignAttribution: { binding.loadCampaignAttribution(campaignID: $0, topicID: $1) }
        )
        .task { binding.load() }
    }
}

struct VideoBountyView: View {
    let state: VideoBountyState
    /// (campaignKey, topicId) from the ops link. Nil hides the submit form.
    let campaign: (String, String)?
    let onLoad: () -> Void
    let onSubmit: (String, String, VideoBountyPlatform?, String, String) -> Void
    let onAppeal: (String, String) -> Void
    let onCancel: (String) -> Void
    let onSubmissionAttribution: (String) -> Void
    let onCampaignAttribution: (String, String) -> Void

    @State private var tab: VideoBountyTab = .submissions
    @State private var attributionID: String?
    @State private var campaignID = ""
    @State private var platform: VideoBountyPlatform?
    @State private var sourceURL = ""
    @State private var groupKey = ""
    @State private var appealTarget: VideoBountySubmissionRow?
    @State private var cancelTarget: VideoBountySubmissionRow?
    @Environment(\.rootTabSwitch) private var rootTabSwitch

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if state.signedOut {
                    // PC-D-7-1: a permission problem is not a retryable error; 登录 opens 我的, where sign-in lives.
                    if rootTabSwitch.isAvailable {
                        CYEmptyState(systemImage: "person.crop.circle", "mp.vb.signedOut", messageIdentifier: "videoBounty.signedOut",
                                     actionTitle: "mp.common.signIn", actionIdentifier: "videoBounty.signIn",
                                     actionStyle: .primary, action: { rootTabSwitch(.mine) })
                    } else {
                        CYEmptyState(systemImage: "person.crop.circle", "mp.vb.signedOut", messageIdentifier: "videoBounty.signedOut")
                    }
                } else {
                if let campaign { form(campaign) }
                MPChipTabs(tabs: VideoBountyTab.allCases, selection: $tab, title: { tab in
                    (tab == .submissions ? Text("mp.vb.tab.submissions") : Text("mp.vb.tab.accruals"))
                }, identifier: { "videoBounty.tab.\($0.rawValue)" })
                .padding(.horizontal, -CYSpacing.pageHorizontal)
                Group {
                    switch tab {
                    case .submissions: submissions
                    case .accruals: accruals
                    }
                }
                .transition(.opacity)
                // R7-PC-D7-1 MP-first: subpackageA/pages/video-bounty/index.wxml has no campaign-ID attribution block.
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyAnimation(value: tab)
        .refreshable { onLoad() }
        .background { MPNightGround() }
        .cyDomainScreen(.player)
        .cyPageTitle("mp.vb.title") // PC-D-7-2: pushed page, inline title
        .onChange(of: state.submitRevision) { _, _ in
            platform = nil; sourceURL = ""; groupKey = ""; tab = .submissions
        }
        .sheet(isPresented: Binding(get: { attributionID != nil }, set: { if !$0 { attributionID = nil } })) {
            VideoBountyAttributionSheet(load: state.attribution, onRetry: { retryAttribution() }, onClose: { attributionID = nil })
        }
        .sheet(item: $appealTarget) { target in
            VideoBountyAppealSheet(onSubmit: { note in onAppeal(target.id, note); appealTarget = nil }, onClose: { appealTarget = nil })
        }
        .confirmationDialog(Text("mp.vb.cancel.title"), isPresented: Binding(get: { cancelTarget != nil }, set: { if !$0 { cancelTarget = nil } }), titleVisibility: .visible) {
            Button("mp.vb.cancel.confirm", role: .destructive) { if let target = cancelTarget { onCancel(target.id) } }
            Button("mp.vb.cancel.keep", role: .cancel) {}
        } message: { Text("mp.vb.cancel.message") }
        .cyDomainScreen(.player)
    }

    // MARK: Form (ops link only)

    private func form(_ campaign: (String, String)) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            MPChipTabs(tabs: VideoBountyPlatform.allCases, selection: $platform,
                       title: { Text(verbatim: $0.label) }, identifier: { "videoBounty.platform.\($0.rawValue)" })
                .padding(.horizontal, -CYSpacing.pageHorizontal)
            if state.fieldError?.field == .platform, let text = state.fieldError?.text { MPInlineError(text: Text(verbatim: text)) }
            MPCard {
                TextField(text: $sourceURL) { Text("mp.vb.form.url") }
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(CYSpacing.lg).frame(minHeight: CYSpacing.minTouchTarget)
                    .onChange(of: sourceURL) { _, value in if value.count > 512 { sourceURL = String(value.prefix(512)) } }
                    .accessibilityIdentifier("videoBounty.form.url")
                MPDivider()
                TextField(text: $groupKey) { Text("mp.vb.form.group") }
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(CYSpacing.lg).frame(minHeight: CYSpacing.minTouchTarget)
                    .onChange(of: groupKey) { _, value in if value.count > 64 { groupKey = String(value.prefix(64)) } }
                    .accessibilityIdentifier("videoBounty.form.group")
            }
            if state.fieldError?.field == .sourceURL, let text = state.fieldError?.text { MPInlineError(text: Text(verbatim: text)) }
            if let error = state.submitError { MPInlineError(text: Text(verbatim: error)) }
            CYMorphButton("mp.vb.form.submit", state: state.submitting ? .working : .idle, action: {
                onSubmit(campaign.0, campaign.1, platform, sourceURL.trimmingCharacters(in: .whitespacesAndNewlines), groupKey.trimmingCharacters(in: .whitespacesAndNewlines))
            })
            .identifier("videoBounty.form.submit")
        }
    }

    private func retryAttribution() {
        if attributionID == "campaign" {
            onCampaignAttribution(campaignID.trimmingCharacters(in: .whitespacesAndNewlines), campaign?.1 ?? "")
        } else if let attributionID {
            onSubmissionAttribution(attributionID)
        }
    }

    private var campaignAttribution: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text("mp.vb.attribution.campaign").cyText(.sectionTitle).accessibilityAddTraits(.isHeader)
            TextField("mp.vb.attribution.campaignId", text: $campaignID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("videoBounty.attribution.campaignId")
            Button("mp.vb.attribution") {
                let topic = campaign?.1 ?? ""
                onCampaignAttribution(campaignID.trimmingCharacters(in: .whitespacesAndNewlines), topic)
                attributionID = "campaign"
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
            .accessibilityIdentifier("videoBounty.attribution.campaign")
        }
    }

    // MARK: Submissions

    @ViewBuilder private var submissions: some View {
        MPLoadSwitch(load: state.submissions, errorTitle: "mp.common.readFailed", identifier: "videoBounty.submissions", onRetry: onLoad) { rows in
            if rows.isEmpty {
                CYEmptyState(systemImage: "film", "mp.vb.empty.submissions", messageIdentifier: "videoBounty.submissions.empty")
            } else {
                MPRows(items: rows) { row in submissionRow(row) }
            }
        }
    }

    private func submissionRow(_ row: VideoBountySubmissionRow) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYStatusChip(row.status.label, tone: .neutral, systemImage: "film")
            HStack(spacing: CYSpacing.xs) {
                if let platform = row.platform { Text(verbatim: platform.label) } else { Text("mp.vb.video") }
            }
            .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            if let url = row.sourceURL, !url.isEmpty {
                // R7-PC-D7-2: the full link can be copied (it is middle-truncated on screen).
                Text(verbatim: url).cyText(.meta).foregroundStyle(CYColor.textSecondary).lineLimit(1).truncationMode(.middle)
                    .textSelection(.enabled)
                    .contextMenu { Button { LocalPasteboard.copy(url) } label: { Label("requestReference.copy", systemImage: "doc.on.doc") } }
            }
            if let end = row.windowEndText { Text("mp.vb.windowEnd \(end)").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            if let note = row.reviewNote, !note.isEmpty { Text(verbatim: note).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            // R7-PC-D7-1 MP-first: the MP submission row has no 成交归因 action.
            if row.canAppeal || row.canCancel {
                HStack(spacing: CYSpacing.lg) {
                    if row.canAppeal {
                        Button("mp.vb.appeal") { appealTarget = row }
                            .cyText(.label).frame(minHeight: CYSpacing.minTouchTarget)
                            .accessibilityIdentifier("videoBounty.appeal.\(row.id)")
                    }
                    if row.canCancel {
                        Button("mp.vb.cancel.confirm", role: .destructive) { cancelTarget = row }
                            .cyText(.label).foregroundStyle(CYColor.dangerText).frame(minHeight: CYSpacing.minTouchTarget)
                            .accessibilityIdentifier("videoBounty.cancel.\(row.id)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.md)
        .accessibilityElement(children: .contain)
    }

    // MARK: Accruals (record only)

    @ViewBuilder private var accruals: some View {
        MPLoadSwitch(load: state.accruals, errorTitle: "mp.common.readFailed", identifier: "videoBounty.accruals", onRetry: onLoad) { rows in
            if rows.isEmpty {
                CYEmptyState(systemImage: "doc.text", "mp.vb.empty.accruals", messageIdentifier: "videoBounty.accruals.empty")
            } else {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    MPRows(items: rows) { row in
                        MPRow(title: Text(verbatim: MPText.orDash(row.amountText)),
                              sub: Text("mp.vb.views \(MPText.orDash(row.views)) \(MPText.orDash(row.groupViews))"),
                              value: Text("mp.vb.accrual.recorded"))
                    }
                    MPGatedNote(text: Text("mp.vb.accrual.note"), identifier: "videoBounty.payoutOff")
                }
            }
        }
    }
}

private struct VideoBountyAttributionSheet: View {
    let load: MPLoad<VideoBountyAttributionFact>?
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let load {
                    MPLoadSwitch(load: load, errorTitle: "mp.vb.attribution.error", identifier: "videoBounty.attribution", onRetry: onRetry) { fact in
                        attributionBody(fact)
                    }
                } else {
                    CYEmptyState(systemImage: "chart.bar", "mp.vb.attribution.empty", messageIdentifier: "videoBounty.attribution.empty")
                }
            }
            .padding(CYSpacing.pageHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { MPNightGround() }
            .navigationTitle(Text("mp.vb.attribution"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close", action: onClose) } }
        }
        .presentationDetents([.medium, .large])
    }

    private func attributionBody(_ fact: VideoBountyAttributionFact) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Group {
                switch fact.status {
                case "UNBOUND":
                    Text("mp.vb.attribution.unbound")
                case "OWNER_NOT_SET":
                    Text("mp.vb.attribution.ownerMissing")
                case "UNKNOWN":
                    // polish-d-r1: an unknown status reads as the em dash, never the raw server word.
                    Text(verbatim: "—")
                default:
                    Text(verbatim: fact.status)
                }
            }
            .cyText(.bodyMedium)
            .accessibilityIdentifier("videoBounty.attribution.status")
            count("mp.vb.attribution.orders", fact.attributedOrders, "attributed")
            count("mp.vb.attribution.paid", fact.paidOrders, "paidOrders")
            count("mp.vb.attribution.amount", fact.paidAmount, "paidAmount")
            count("mp.vb.attribution.refunded", fact.refundedOrders, "refundedOrders")
            count("mp.vb.attribution.refundAmount", fact.refundedAmount, "refundedAmount")
            Text("mp.vb.attribution.currencyNote").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            Text(verbatim: fact.amountCurrency).cyText(.meta).accessibilityIdentifier("videoBounty.attribution.currency")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func count(_ title: LocalizedStringKey, _ value: String, _ id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: value).accessibilityIdentifier("videoBounty.attribution." + id)
        }
        .cyText(.body)
        .frame(minHeight: CYSpacing.minTouchTarget)
    }
}

/// Appeal note (mini-program modal: editable, multiline, "explain why", required).
private struct VideoBountyAppealSheet: View {
    let onSubmit: (String) -> Void
    let onClose: () -> Void
    @State private var note = ""
    @State private var showsRequired = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                TextField(text: $note, axis: .vertical) { Text("mp.vb.appeal.placeholder") }
                    .lineLimit(4...8)
                    .focused($focused)
                    .padding(CYSpacing.lg)
                    .background(CYNight.ink1, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .onChange(of: note) { _, _ in showsRequired = false }
                    .accessibilityIdentifier("videoBounty.appeal.note")
                if showsRequired { MPInlineError(text: Text("mp.vb.appeal.required")) }
                Spacer()
            }
            .padding(CYSpacing.pageHorizontal)
            .background(CYNight.ink0.ignoresSafeArea())
            .navigationTitle(Text("mp.vb.appeal.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel", action: onClose) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("mp.vb.appeal.submit") {
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { showsRequired = true; return }
                        onSubmit(trimmed)
                    }
                    .accessibilityIdentifier("videoBounty.appeal.submit")
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}
