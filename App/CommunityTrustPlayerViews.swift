import SwiftUI

/// BL-66 merchant safety summary. Insufficient sample, policy off, or any failure: nothing is drawn.
struct MerchantSafetySummaryRow: View {
    let merchantID: Int
    let client: PlayerCapabilityClient
    @State private var summary: CommunityTrustPlayerService.SafetySummary?

    var body: some View {
        // A VStack, not a Group: a `.task` on an empty Group never runs, so the summary would never load.
        VStack(alignment: .leading, spacing: 0) {
            if let summary {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Label { Text(verbatim: summary.text) } icon: { Image(systemName: "shield.lefthalf.filled") }
                        .cyText(.cardTitle)
                        .foregroundStyle(summary.level == "UNSAFE" ? CYColor.warningText : CYColor.textPrimary)
                    Text(verbatim: summary.note)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("merchant.safety.summary")
            }
        }
        .task(id: merchantID) {
            summary = await CommunityTrustPlayerService(client: client).merchantSafety(merchantID: merchantID)
        }
    }
}

/// BL-67 merchant correction sheet: pick an issue type from the taxonomy, describe it, submit once.
/// An unconfirmed submit keeps the same idempotency key; changing the issue or the text mints a new one.
struct MerchantCorrectionSheet: View {
    let merchantID: Int
    let client: PlayerCapabilityClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var issues: [CommunityTrustPlayerService.IssueType] = []
    @State private var issue: String?
    @State private var text = ""
    @State private var key = ""
    @State private var stage: Stage = .loading
    @State private var message = ""

    enum Stage: Equatable { case loading, loadFailed, pickType, form, busy, done, failed, unknown }

    private var service: CommunityTrustPlayerService { CommunityTrustPlayerService(client: client) }

    var body: some View {
        Group {
            switch stage {
            case .pickType:
                VStack(spacing: CYSpacing.md) {
                    CYOptionSheet(
                        title: PlayerCapabilityCopy.text("哪里不对", "What is wrong", locale),
                        items: issues.map { CYOptionSheetItem(id: $0.code, title: $0.label) },
                        selectedID: issue,
                        onSelect: { selected in
                            if selected != issue { key = "" }
                            issue = selected
                        },
                        onClose: { dismiss() }
                    )
                    CYPillButton(
                        verbatim: PlayerCapabilityCopy.text("下一步", "Next", locale),
                        style: .primary
                    ) {
                        stage = .form
                    }
                    .disabled(issue == nil)
                    .padding(.horizontal, CYSpacing.lg)
                    .padding(.bottom, CYSpacing.md)
                    .accessibilityIdentifier("merchant.correction.next")
                }
            default:
                CYSheetContainer(
                    title: PlayerCapabilityCopy.text("信息纠错", "Correct merchant info", locale),
                    onClose: { if stage != .busy { dismiss() } }
                ) {
                    switch stage {
                    case .loading:
                        VStack(spacing: CYSpacing.md) {
                            ProgressView()
                            Text(verbatim: PlayerCapabilityCopy.text("正在读取纠错类型", "Loading issue types", locale))
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CYSpacing.lg)
                    case .loadFailed:
                        VStack(spacing: CYSpacing.md) {
                            CYEmptyState(
                                systemImage: "exclamationmark.triangle",
                                LocalizedStringKey(message.isEmpty ? PlayerCapabilityCopy.text("暂时无法纠错", "Unable to correct info right now", locale) : message),
                                kind: .failure
                            )
                            HStack(spacing: CYSpacing.sm) {
                                CYPillButton(verbatim: PlayerCapabilityCopy.text("取消", "Cancel", locale), style: .secondary) { dismiss() }
                                CYPillButton(verbatim: PlayerCapabilityCopy.text("重试", "Retry", locale), style: .primary) { Task { await load() } }
                            }
                        }
                    case .done:
                        VStack(spacing: CYSpacing.md) {
                            CYEmptyState(
                                systemImage: "checkmark.circle",
                                LocalizedStringKey(PlayerCapabilityCopy.text("纠错已提交", "Correction submitted", locale)),
                                kind: .generic
                            )
                            Text(verbatim: message)
                                .cyText(.body)
                                .foregroundStyle(CYColor.textPrimary)
                                .accessibilityIdentifier("merchant.correction.receipt")
                            CYPillButton(verbatim: PlayerCapabilityCopy.text("关闭", "Close", locale), style: .primary) { dismiss() }
                        }
                    default:
                        ScrollView {
                            VStack(alignment: .leading, spacing: CYSpacing.md) {
                                if let selectedCode = issue,
                                   let selectedLabel = issues.first(where: { $0.code == selectedCode })?.label {
                                    HStack {
                                        Text(verbatim: selectedLabel)
                                            .cyText(.cardTitle)
                                            .foregroundStyle(CYColor.textPrimary)
                                        Spacer()
                                        Button(PlayerCapabilityCopy.text("重选类型", "Change", locale)) {
                                            stage = .pickType
                                        }
                                        .cyText(.meta)
                                        .disabled(stage == .busy)
                                    }
                                    .padding(CYSpacing.sm)
                                    .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.sheetCard))
                                }

                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    Text(verbatim: PlayerCapabilityCopy.text("补充说明", "Details", locale))
                                        .cyText(.sectionTitle)
                                        .foregroundStyle(CYColor.textSecondary)
                                    TextField(
                                        PlayerCapabilityCopy.text("请写一下哪里不对、正确的信息是什么", "What is wrong and what is correct", locale),
                                        text: Binding(get: { text }, set: { value in if value != text { key = "" }; text = value }),
                                        axis: .vertical
                                    )
                                    .lineLimit(3...6)
                                    .textFieldStyle(.roundedBorder)
                                    Text(verbatim: "\(text.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(CommunityTrustPlayerService.descriptionMax)")
                                        .cyText(.meta)
                                        .foregroundStyle(CYColor.textSecondary)
                                }

                                if stage == .failed || stage == .unknown {
                                    Text(verbatim: message)
                                        .cyText(.meta)
                                        .foregroundStyle(stage == .failed ? CYColor.dangerText : CYColor.warningText)
                                }

                                HStack(spacing: CYSpacing.sm) {
                                    CYPillButton(verbatim: PlayerCapabilityCopy.text("取消", "Cancel", locale), style: .secondary) {
                                        dismiss()
                                    }
                                    .disabled(stage == .busy)

                                    CYPillButton(
                                        verbatim: stage == .busy
                                            ? PlayerCapabilityCopy.text("正在提交纠错", "Submitting correction", locale)
                                            : stage == .failed
                                                ? PlayerCapabilityCopy.text("重试", "Retry", locale)
                                                : PlayerCapabilityCopy.text("提交", "Submit", locale),
                                        style: .primary
                                    ) {
                                        Task { await submit() }
                                    }
                                    .disabled(stage == .busy || issue == nil || CommunityTrustPlayerService.checkedDescription(text) == nil)
                                    .accessibilityIdentifier("merchant.correction.submit")
                                }
                            }
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(stage == .busy)
        .task { await load() }
    }

    private func load() async {
        stage = .loading
        guard merchantID > 0 else { message = "商家信息不完整，暂时无法纠错"; stage = .loadFailed; return }
        do {
            issues = try await service.contributionIssueTypes()
            stage = issues.isEmpty ? .loadFailed : .pickType
            if issues.isEmpty { message = "暂时无法纠错" }
        }
        catch { message = "纠错类型没有读取成功，请稍后再试"; stage = .loadFailed }
    }

    private func submit() async {
        guard let issue, stage != .busy else { return }
        if key.isEmpty { key = CommunityTrustPlayerService.contributionKey(merchantID: merchantID) }
        stage = .busy
        do {
            let receipt = try await service.submitContribution(merchantID: merchantID, issueType: issue, description: text, idempotencyKey: key)
            key = ""; message = receipt.text; stage = .done
        } catch PlayerCapabilityFailure.outcomeUnknown {
            message = "网络异常，结果未确认；再次提交会沿用同一编号"; stage = .unknown
        } catch {
            key = ""; message = PlayerCapabilityCopy.failure(error, fallback: "纠错没有提交成功，请稍后再试"); stage = .failed
        }
    }
}

/// BL-89 visit safety rating. `merchantID` is `mms_merchant.id` (the caller already resolved it from public-home).
/// Retries of one filling reuse the same key; changing the level or reason mints a new one.
struct MerchantSafetyRatingSheet: View {
    let merchantID: Int
    let client: PlayerCapabilityClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var levels: [(key: String, label: String)] = []
    @State private var level = ""
    @State private var reason = ""
    @State private var key = ""
    @State private var loading = true
    @State private var submitting = false
    @State private var error = ""
    @State private var receipt: String?

    private var canSubmit: Bool {
        let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return !level.isEmpty && !text.isEmpty && text.count <= 1000 && !submitting
    }

    var body: some View {
        NavigationStack {
            Form {
                if let receipt {
                    Label { Text(verbatim: receipt.isEmpty ? "评价已提交" : receipt) } icon: { Image(systemName: "checkmark.circle") }
                        .accessibilityIdentifier("merchant.safety.receipt")
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if levels.isEmpty {
                    Text(verbatim: error.isEmpty ? "评价选项暂时不可用" : error).foregroundStyle(CYColor.textSecondary)
                    Button(PlayerCapabilityCopy.text("重试", "Retry", locale)) { Task { await load() } }
                } else {
                    Section(PlayerCapabilityCopy.text("到访安全感受", "How safe did it feel", locale)) {
                        Picker(PlayerCapabilityCopy.text("感受", "Feeling", locale), selection: Binding(
                            get: { level }, set: { key = ""; level = $0 })) {
                            ForEach(levels, id: \.key) { item in Text(verbatim: item.label).tag(item.key) }
                        }
                        .cyAdaptiveSegmented()
                        TextField(PlayerCapabilityCopy.text("说说原因", "Why", locale),
                                  text: Binding(get: { reason }, set: { key = ""; reason = $0 }), axis: .vertical)
                            .lineLimit(3...6)
                    }
                    if !error.isEmpty { Text(verbatim: error).foregroundStyle(CYColor.dangerText) }
                    Button(PlayerCapabilityCopy.text("提交评价", "Submit", locale)) { Task { await submit() } }
                        .disabled(!canSubmit)
                        .accessibilityIdentifier("merchant.safety.submit")
                }
            }
            .navigationTitle(PlayerCapabilityCopy.text("安全感受评价", "Safety rating", locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PlayerCapabilityCopy.text("关闭", "Close", locale)) { dismiss() }.disabled(submitting)
                }
            }
        }
        .interactiveDismissDisabled(submitting)
        .task { await load() }
    }

    private func load() async {
        loading = true; error = ""
        do { levels = try await CommunityTrustPlayerService(client: client).safetyLevels() }
        catch { self.error = PlayerCapabilityCopy.failure(error, fallback: "网络异常，评价选项没有加载") }
        loading = false
    }

    private func submit() async {
        guard canSubmit, merchantID > 0 else { error = "没有找到这家商家"; return }
        submitting = true; error = ""
        if key.isEmpty { key = CommunityTrustPlayerService.safetyKey(merchantID: merchantID) }
        do {
            receipt = try await CommunityTrustPlayerService(client: client)
                .submitSafetyRating(merchantID: merchantID, level: level, reason: reason, idempotencyKey: key)
        } catch {
            self.error = PlayerCapabilityCopy.failure(error, fallback: "评价没有提交成功，请稍后重试")
        }
        submitting = false
    }
}

/// One appeal attempt on the report detail. The detail view keeps this across a reload that
/// temporarily drops `flow.detail`, so an unconfirmed send is not replaced by a new id.
struct ReportAppealRetention: Equatable {
    var reason = ""
    var requestID = ""
    var lockedReason = ""
    var phase: ReportAppealSheetPhase = .form
    var showsSheet = false
    var result: String?
}

/// BL-52 text-only report appeal: fill in the reason, confirm, then the result.
/// The request id is written before the first send. A failed or unconfirmed retry sends that same id.
/// PLY-29-4 uses `CommunityTrustPlayerService.appeal` (`community-trust/reports/appeal`).
struct ReportAppealSection: View {
    let reportID: Int
    let client: PlayerCapabilityClient
    let stageLabel: (String) -> String?
    let readBack: () -> Void
    var retention: Binding<ReportAppealRetention>? = nil
    @Environment(\.locale) private var locale
    @State private var owned = ReportAppealRetention()

    private var draft: Binding<ReportAppealRetention> { retention ?? $owned }

    var body: some View {
        let value = draft.wrappedValue
        Section {
            if let result = value.result, !result.isEmpty {
                Label { Text(verbatim: result) } icon: { Image(systemName: "checkmark.circle") }
                    .accessibilityIdentifier("report.appeal.receipt")
            } else {
                Button(PlayerCapabilityCopy.text("提交申诉", "Submit appeal", locale)) {
                    var next = draft.wrappedValue
                    if next.phase != .busy, next.requestID.isEmpty { next.phase = .form }
                    next.showsSheet = true
                    draft.wrappedValue = next
                }
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("report.appeal.open")
            }
        } header: { Text(verbatim: PlayerCapabilityCopy.text("申诉", "Appeal", locale)) }
        .cySheet(isPresented: showsSheet) {
            ReportAppealSheetView(phase: draft.wrappedValue.phase, reason: reasonText,
                onToConfirm: {
                    var next = draft.wrappedValue
                    let text = next.reason.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty, text.count <= CommunityTrustPlayerService.appealMax else { return }
                    next.phase = .confirm
                    draft.wrappedValue = next
                },
                onBackToForm: {
                    var next = draft.wrappedValue
                    next.phase = .form
                    draft.wrappedValue = next
                },
                onSubmit: { Task { await submit() } },
                onClose: {
                    var next = draft.wrappedValue
                    if next.phase != .busy {
                        next.showsSheet = false
                        draft.wrappedValue = next
                    }
                })
            .interactiveDismissDisabled(draft.wrappedValue.phase == .busy)
            .accessibilityIdentifier("report.appeal.sheet")
        }
    }

    private var showsSheet: Binding<Bool> {
        Binding(get: { draft.wrappedValue.showsSheet }, set: { shown in
            var next = draft.wrappedValue
            if next.phase == .busy, !shown { return }
            next.showsSheet = shown
            draft.wrappedValue = next
        })
    }

    private var reasonText: Binding<String> {
        Binding(get: { draft.wrappedValue.reason }, set: { text in
            var next = draft.wrappedValue
            guard next.requestID.isEmpty else { return }
            next.reason = text
            draft.wrappedValue = next
        })
    }

    private func submit() async {
        var next = draft.wrappedValue
        guard next.phase != .busy,
              let send = CommunityTrustPlayerService.appealSubmission(
                existingRequestID: next.requestID, lockedReason: next.lockedReason, reason: next.reason, reportID: reportID)
        else { return }
        next.requestID = send.requestID
        next.lockedReason = send.reason
        next.phase = .busy
        next.result = nil
        draft.wrappedValue = next
        let sentID = send.requestID
        do {
            let receipt = try await CommunityTrustPlayerService(client: client)
                .appeal(reportID: reportID, reason: send.reason, requestID: sentID, stageLabel: stageLabel)
            guard !receipt.isEmpty else {
                markUnconfirmed(sentID)
                return
            }
            var done = draft.wrappedValue
            guard done.requestID == sentID else { return }
            done.result = receipt
            done.phase = .ok(receiptText: receipt)
            draft.wrappedValue = done
            readBack()
        } catch PlayerCapabilityFailure.outcomeUnknown {
            markUnconfirmed(sentID)
        } catch {
            var failed = draft.wrappedValue
            guard failed.requestID == sentID else { return }
            failed.result = nil
            failed.phase = .fail(message: PlayerCapabilityCopy.failure(error, fallback: appLocalized("report.appeal.failed", locale: locale)))
            draft.wrappedValue = failed
        }
    }

    /// Unknown and transport failure stay unconfirmed. The id written before the send is left in place.
    private func markUnconfirmed(_ sentID: String) {
        var next = draft.wrappedValue
        guard next.requestID == sentID else { return }
        next.result = nil
        next.phase = .unknown
        draft.wrappedValue = next
        readBack()
    }
}

/// `pages/member` / `pages/mylike`: my community posts and bookmarks (`GET api/v1/community/me/posts|bookmarks`).
struct SquareMineListView: View {
    let list: SquareMineList
    let service: SquareService
    let token: String
    @Environment(\.locale) private var locale
    @State private var items: [SquarePost] = []
    @State private var cursor: SquareCursor?
    @State private var hasMore = false
    @State private var loading = false
    @State private var failed = false

    var body: some View {
        List {
            ForEach(items) { post in
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: String((post.contents ?? "").prefix(140)))
                        .cyText(.body).foregroundStyle(CYColor.textPrimary).lineLimit(4)
                }
                .accessibilityIdentifier("square.mine.\(list.rawValue).\(post.id)")
            }
            if hasMore { Button(PlayerCapabilityCopy.text("加载更多", "Load more", locale)) { Task { await load(reset: false) } }.disabled(loading) }
            if failed { Text(verbatim: PlayerCapabilityCopy.text("加载失败，请重试", "Couldn't load", locale)).foregroundStyle(CYColor.textSecondary) }
            if !loading && !failed && items.isEmpty {
                Text(verbatim: list == .posts ? PlayerCapabilityCopy.text("还没有发过帖文", "No posts yet", locale)
                                              : PlayerCapabilityCopy.text("还没有收藏", "No bookmarks yet", locale))
                    .foregroundStyle(CYColor.textSecondary)
            }
        }
        .navigationTitle(list == .posts ? PlayerCapabilityCopy.text("我的帖文", "My posts", locale)
                                        : PlayerCapabilityCopy.text("我的收藏", "Bookmarks", locale)).navigationBarTitleDisplayMode(.inline)
        .refreshable { await load(reset: true) }
        .task { await load(reset: true) }
        .cyDomainScreen(.player)
    }

    private func load(reset: Bool) async {
        guard !loading else { return }
        loading = true; failed = false
        do {
            let page = try await service.mine(list, cursor: reset ? nil : cursor, token: token)
            items = reset ? page.items : items + page.items.filter { row in !items.contains { $0.id == row.id } }
            cursor = page.nextCursor; hasMore = page.hasMore && page.nextCursor != nil
        } catch { failed = true }
        loading = false
    }
}
