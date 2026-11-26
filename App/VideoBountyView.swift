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
    /// PC-D-7-1: no session token. The page shows one sign-in gate (MP cy-access-gate kind=login), not two 读取失败.
    var signedOut = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.submissions == rhs.submissions && lhs.accruals == rhs.accruals && lhs.submitting == rhs.submitting
            && lhs.fieldError?.field == rhs.fieldError?.field && lhs.fieldError?.text == rhs.fieldError?.text
            && lhs.submitError == rhs.submitError && lhs.submitRevision == rhs.submitRevision
            && lhs.signedOut == rhs.signedOut
    }
}

/// Implemented by `VideoBountySessionModel`: `/api/video-bounty/submission/mine`, `/accrual/mine`, submit, appeal, cancel.
/// R9-PC-D7-2: MP subpackageA/pages/video-bounty/index.wxml has no attribution block, so the binding has no attribution reads.
@MainActor protocol VideoBountyBinding: AnyObject, Observable {
    var state: VideoBountyState { get }
    func load()
    func submit(campaignKey: String, topicID: String, platform: VideoBountyPlatform?, sourceURL: String, originGroupKey: String)
    func appeal(submissionID: String, note: String)
    func cancel(submissionID: String)
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
            onCancel: { binding.cancel(submissionID: $0) }
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

    @State private var tab: VideoBountyTab = .submissions
    @State private var platform: VideoBountyPlatform?
    @State private var sourceURL = ""
    @State private var groupKey = ""
    @State private var appealTarget: VideoBountySubmissionRow?
    @State private var cancelTarget: VideoBountySubmissionRow?
    @Environment(\.rootTabSwitch) private var rootTabSwitch

    // R9-PC-D7-1 (native r2): an inset-grouped List; the submit fields are Form-style Section rows
    // (MP subpackageA/pages/video-bounty/index.wxml:12-30: platform tabs, 视频页链接, 原视频分组, 提交投稿).
    var body: some View {
        List {
            if state.signedOut {
                // PC-D-7-1: a permission problem is not a retryable error; 登录 opens 我的, where sign-in lives.
                ContentUnavailableView {
                    Label("mp.vb.signedOut", systemImage: "person.crop.circle")
                        .accessibilityIdentifier("videoBounty.signedOut")
                } actions: {
                    if rootTabSwitch.isAvailable {
                        Button("mp.common.signIn") { rootTabSwitch(.mine) }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("videoBounty.signIn")
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                if let campaign { form(campaign) }
                Section {
                    Picker("mp.vb.title", selection: $tab) {
                        Text("mp.vb.tab.submissions").tag(VideoBountyTab.submissions)
                        Text("mp.vb.tab.accruals").tag(VideoBountyTab.accruals)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("videoBounty.tab")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    switch tab {
                    case .submissions: submissions
                    case .accruals: accruals
                    }
                }
                // R7-PC-D7-1 MP-first: subpackageA/pages/video-bounty/index.wxml has no campaign-ID attribution block.
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { onLoad() }
        .navigationTitle("mp.vb.title")
        .navigationBarTitleDisplayMode(.inline) // PC-D-7-2: pushed page, inline title
        .onChange(of: state.submitRevision) { _, _ in
            platform = nil; sourceURL = ""; groupKey = ""; tab = .submissions
        }
        .cySheet(item: $appealTarget) { target in
            VideoBountyAppealSheet(onSubmit: { note in onAppeal(target.id, note); appealTarget = nil }, onClose: { appealTarget = nil })
        }
        .confirmationDialog(Text("mp.vb.cancel.title"), isPresented: Binding(get: { cancelTarget != nil }, set: { if !$0 { cancelTarget = nil } }), titleVisibility: .visible) {
            Button("mp.vb.cancel.confirm", role: .destructive) { if let target = cancelTarget { onCancel(target.id) } }
            Button("mp.vb.cancel.keep", role: .cancel) {}
        } message: { Text("mp.vb.cancel.message") }
    }

    // MARK: Form (ops link only)

    @ViewBuilder private func form(_ campaign: (String, String)) -> some View {
        Section {
            Picker("mp.vb.form.platform", selection: $platform) {
                Text("mp.vb.form.platform").tag(VideoBountyPlatform?.none)
                ForEach(VideoBountyPlatform.allCases) { item in
                    Text(verbatim: item.label).tag(Optional(item))
                }
            }
            .accessibilityIdentifier("videoBounty.platform")
            TextField("mp.vb.form.url", text: $sourceURL)
                .textContentType(.URL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.next)
                .onChange(of: sourceURL) { _, value in if value.count > 512 { sourceURL = String(value.prefix(512)) } }
                .accessibilityIdentifier("videoBounty.form.url")
            TextField("mp.vb.form.group", text: $groupKey)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.done)
                .onChange(of: groupKey) { _, value in if value.count > 64 { groupKey = String(value.prefix(64)) } }
                .accessibilityIdentifier("videoBounty.form.group")
        } footer: {
            // Validation in the section footer (native r2), same texts as the MP inline errors.
            if let text = state.fieldError?.text, state.fieldError?.field == .platform || state.fieldError?.field == .sourceURL {
                Text(verbatim: text).foregroundStyle(.red)
            } else if let error = state.submitError {
                Text(verbatim: error).foregroundStyle(.red)
            }
        }
        Section {
            Button {
                onSubmit(campaign.0, campaign.1, platform, sourceURL.trimmingCharacters(in: .whitespacesAndNewlines), groupKey.trimmingCharacters(in: .whitespacesAndNewlines))
            } label: {
                HStack {
                    Text("mp.vb.form.submit")
                    if state.submitting { Spacer(); ProgressView() }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(state.submitting)
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            .accessibilityIdentifier("videoBounty.form.submit")
        }
    }

    // MARK: Submissions

    @ViewBuilder private var submissions: some View {
        MPLoadSwitch(load: state.submissions, errorTitle: "mp.common.readFailed", identifier: "videoBounty.submissions", onRetry: onLoad) { rows in
            if rows.isEmpty {
                CYEmptyState(systemImage: "tray", "mp.vb.empty.submissions", messageIdentifier: "videoBounty.submissions.empty")
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
                CYEmptyState(systemImage: "tray", "mp.vb.empty.accruals", messageIdentifier: "videoBounty.accruals.empty")
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

/// Appeal note (mini-program modal: editable, multiline, "explain why", required).
private struct VideoBountyAppealSheet: View {
    let onSubmit: (String) -> Void
    let onClose: () -> Void
    @State private var note = ""
    @State private var showsRequired = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            // R10-PC-D-N13: system Form on the system background; validation in the section footer.
            Form {
                Section {
                    TextField(text: $note, axis: .vertical) { Text("mp.vb.appeal.placeholder") }
                        .lineLimit(4...8)
                        .focused($focused)
                        .submitLabel(.done)
                        .onChange(of: note) { _, _ in showsRequired = false }
                        .accessibilityIdentifier("videoBounty.appeal.note")
                } footer: {
                    if showsRequired { Text("mp.vb.appeal.required").foregroundStyle(.red) }
                }
            }
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
        .presentationDetents([.medium, .large])
    }
}
