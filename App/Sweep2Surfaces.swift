import SwiftUI

private struct Sweep2ClientEnvironmentKey: EnvironmentKey {
    static let defaultValue: Sweep2Client? = nil
}

private struct Sweep2AccountIDEnvironmentKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var sweep2Client: Sweep2Client? {
        get { self[Sweep2ClientEnvironmentKey.self] }
        set { self[Sweep2ClientEnvironmentKey.self] = newValue }
    }

    var sweep2AccountID: Int? {
        get { self[Sweep2AccountIDEnvironmentKey.self] }
        set { self[Sweep2AccountIDEnvironmentKey.self] = newValue }
    }
}

// MARK: - 1. Registration Payment Readiness (moneyPayments switch)

@MainActor struct RegistrationPaymentReadinessCard: View {
    let payableAmount: Decimal?
    @Environment(\.sweep2Client) private var client
    @Environment(\.locale) private var locale
    @State private var loading = false
    @State private var status: PaymentReadinessStatus?
    @State private var failed = false

    private var needsPaidCheck: Bool { (payableAmount ?? .zero) > .zero }
    private var paymentsOpen: Bool { ReviewedAreaSwitch.moneyPayments(apiHost: client?.baseURL.host) }

    var body: some View {
        if needsPaidCheck {
            if !paymentsOpen {
                CYStatusChip(
                    verbatim: ChannelCopy.text(
                        "线上支付暂未在当前版本开放",
                        "Online payment is closed in this release",
                        locale: locale
                    ),
                    tone: .neutral,
                    systemImage: "lock"
                )
                .accessibilityIdentifier("registration.paymentReadiness.closed")
            } else if loading {
                CYLoadingStateView(rows: 1)
                    .accessibilityIdentifier("registration.paymentReadiness.loading")
            } else if let status {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    CYStatusChip(
                        verbatim: status.ready
                            ? ChannelCopy.text("支付通道已就绪", "Payment service is ready", locale: locale)
                            : ChannelCopy.text(status.message ?? "支付服务暂不可用，请稍后重试", status.message ?? "Payment service is unavailable", locale: locale),
                        tone: status.ready ? .success : .warning,
                        systemImage: status.ready ? "checkmark.circle" : "exclamationmark.triangle"
                    )
                    if !status.ready {
                        CYPillButton(ChannelCopy.text("重新检查支付服务", "Recheck payment service", locale: locale), style: .secondary) {
                            Task { await check() }
                        }
                        .accessibilityIdentifier("registration.paymentReadiness.retry")
                    }
                }
                .accessibilityIdentifier("registration.paymentReadiness.status")
                .task(id: paymentsOpen) { await check() }
            } else if failed {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: ChannelCopy.text("支付服务检查失败，请检查网络后重试", "Payment readiness check failed. Retry.", locale: locale))
                        .font(CYTypography.caption)
                        .foregroundStyle(CYColor.textSecondary)
                    CYPillButton(ChannelCopy.text("重试检查", "Retry check", locale: locale), style: .secondary) {
                        Task { await check() }
                    }
                }
                .accessibilityIdentifier("registration.paymentReadiness.failed")
            } else {
                Color.clear.frame(height: 0)
                    .task(id: payableAmount) { await check() }
            }
        }
    }

    private func check() async {
        guard paymentsOpen, let client else { return }
        loading = true
        failed = false
        defer { loading = false }
        do {
            status = try await client.paymentReadiness()
        } catch {
            status = nil
            failed = true
        }
    }
}

// MARK: - 2. Project Audit Timeline & Appeal

struct ProjectAuditTarget: Identifiable, Equatable {
    let bizType: String
    let bizID: String
    let title: String
    var id: String { "\(bizType):\(bizID)" }
}

@MainActor struct ProjectAuditTimelineSheet: View {
    let target: ProjectAuditTarget
    @Environment(\.sweep2Client) private var client
    @Environment(\.sweep2AccountID) private var accountID
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    @State private var loading = true
    @State private var errorMessage: String?
    @State private var timeline: AuditTimelineDetail?
    @State private var reason = ""
    @State private var draft = AuditAppealDraft()
    @State private var submitting = false
    @State private var notice: String?

    private let store = AuditAppealStore()

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    Section { CYLoadingStateView(rows: 3) }
                } else if let errorMessage {
                    Section {
                        Text(verbatim: errorMessage).foregroundStyle(CYColor.textSecondary)
                        CYPillButton(t("重试", "Retry"), style: .secondary) { Task { await load() } }
                    }
                } else if let timeline {
                    if let appealState = timeline.appealState, !appealState.isEmpty {
                        Section(t("申诉状态", "Appeal Status")) {
                            CYStatusChip(verbatim: appealStateLabel(appealState), tone: .info)
                        }
                    }
                    Section(t("审核记录", "Audit Timeline")) {
                        if timeline.rows.isEmpty {
                            CYEmptyState(systemImage: "doc.text.magnifyingglass", verbatim: t("暂无审核记录", "No audit records yet"))
                        } else {
                            ForEach(timeline.rows) { row in
                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    Text(verbatim: row.label).font(CYTypography.cardTitle)
                                    if !row.detail.isEmpty {
                                        Text(verbatim: row.detail).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    if draft.pending, draft.command != nil {
                        Section(t("待确认申诉", "Pending Appeal Recovery")) {
                            Text(verbatim: t("原申诉结果待确认，请读取平台记录；不要修改原说明。", "Original appeal outcome is unconfirmed. Query the platform receipt before retrying."))
                                .font(CYTypography.caption)
                                .foregroundStyle(CYColor.warningText)
                            Text(verbatim: draft.reason).font(CYTypography.body)
                            CYPillButton(t("核对申诉回执", "Check appeal receipt"), style: .primary) {
                                Task { await recoverReceipt() }
                            }
                            .disabled(submitting)
                            .accessibilityIdentifier("myProject.audit.recover")
                        }
                    } else if timeline.canAppeal, !draft.confirmed {
                        Section(t("发起申诉（每条内容一次）", "Submit Appeal (Once Per Item)")) {
                            TextField(
                                t("写清你认为处理有误的理由（500 字内）", "Explain why you believe this decision is incorrect (max 500 chars)"),
                                text: $reason,
                                axis: .vertical
                            )
                            .lineLimit(3...6)
                            .disabled(submitting || draft.pending)
                            .accessibilityIdentifier("myProject.audit.reason")
                            CYPillButton(t("提交申诉", "Submit Appeal"), style: .primary) {
                                Task { await submitAppeal() }
                            }
                            .disabled(submitting || client == nil)
                            .accessibilityIdentifier("myProject.audit.submit")
                        }
                    }
                }
                if let notice, !notice.isEmpty {
                    Section {
                        Text(verbatim: notice).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("myProject.audit.notice")
                    }
                }
            }
            .navigationTitle(Text(verbatim: target.title.isEmpty ? t("审核记录", "Audit Record") : target.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("关闭", "Close")) { dismiss() }
                }
            }
            .task(id: target.id) { await load() }
        }
    }

    private func t(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    private func load() async {
        if let accountID, let saved = store.load(accountID: accountID, bizType: target.bizType, bizID: target.bizID) {
            draft = saved
            reason = saved.reason
        }
        guard let client else {
            loading = false
            errorMessage = t("审核服务暂未配置", "Audit service is not configured")
            return
        }
        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            timeline = try await client.auditTimeline(bizType: target.bizType, bizID: target.bizID)
        } catch {
            errorMessage = t("审核记录加载失败，请重试", "Couldn't load audit timeline")
        }
    }

    private func submitAppeal() async {
        guard let client, let accountID, !submitting else { return }
        if let validationError = AuditAppealValidation.validateReason(reason) {
            notice = t(validationError, "Please provide a valid appeal reason (1-500 chars)")
            return
        }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let reqID = draft.command?.requestId ?? "appeal-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8))"
        let cmd = AuditAppealCommand(requestId: reqID, bizType: target.bizType, bizId: target.bizID, reason: trimmed, attachments: draft.attachments)
        let pendingDraft = AuditAppealDraft(reason: trimmed, attachments: cmd.attachments, pending: true, confirmed: false, command: cmd)
        do {
            try store.save(pendingDraft, accountID: accountID, bizType: target.bizType, bizID: target.bizID)
            draft = pendingDraft
        } catch {
            notice = t("申诉草稿保存失败，请重试", "Couldn't persist appeal draft")
            return
        }
        submitting = true
        defer { submitting = false }
        do {
            _ = try await client.submitAuditAppeal(command: cmd)
            await recoverReceipt()
        } catch APIError.server(let code, let msg) where code == 400 {
            let reverted = AuditAppealDraft(reason: trimmed, attachments: cmd.attachments, pending: false, confirmed: false, command: nil)
            try? store.save(reverted, accountID: accountID, bizType: target.bizType, bizID: target.bizID)
            draft = reverted
            notice = msg ?? t("申诉参数未通过校验", "Appeal validation failed")
        } catch {
            notice = t("申诉结果待确认，请核对回执", "Appeal outcome unconfirmed; check receipt")
        }
    }

    private func recoverReceipt() async {
        guard let client, let accountID, let cmd = draft.command else { return }
        do {
            if let receipt = try await client.auditAppealReceipt(command: cmd, memberID: accountID) {
                let confirmed = AuditAppealDraft(reason: cmd.reason, attachments: cmd.attachments, pending: false, confirmed: true, command: cmd)
                try? store.save(confirmed, accountID: accountID, bizType: target.bizType, bizID: target.bizID)
                draft = confirmed
                notice = t("原申诉已确认，编号 \(receipt.appealID)", "Appeal confirmed (#\(receipt.appealID))")
                await load()
            } else {
                notice = t("原申诉结果未确认，保留原号和冻结输入", "Receipt not found yet; retaining frozen request ID")
            }
        } catch {
            notice = t("结果读取失败，保留原号和冻结输入，请重试读取", "Receipt check failed; retaining frozen request ID")
        }
    }

    private func appealStateLabel(_ state: String) -> String {
        switch state {
        case "SUBMITTED": return t("已提交申诉，等待处理", "Appeal submitted")
        case "REVIEWING": return t("申诉审核中", "Appeal under review")
        case "ACCEPTED": return t("申诉已通过", "Appeal accepted")
        case "REJECTED": return t("申诉已驳回", "Appeal rejected")
        case "WITHDRAWN": return t("申诉已撤回", "Appeal withdrawn")
        default: return state
        }
    }
}

// MARK: - 3. Club Compensation Editions Empty Reason

@MainActor struct ClubEditionEmptyReasonView: View {
    let clubID: Int?
    let reloadEditions: () -> Void
    @Environment(\.sweep2Client) private var client
    @Environment(\.locale) private var locale
    @State private var loading = false
    @State private var reasonCode: ClubEditionEmptyReasonCode?
    @State private var error = false

    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: titleText).font(CYTypography.cardTitle)
            if !subtitleText.isEmpty {
                Text(verbatim: subtitleText).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
            }
            if reasonCode?.allowsRetry == true || error {
                CYPillButton(ChannelCopy.text(reasonCode?.allowsRetry == true ? "重新加载期次" : "重试确认原因",
                                              reasonCode?.allowsRetry == true ? "Reload editions" : "Retry check",
                                              locale: locale),
                             style: .secondary) {
                    if reasonCode?.allowsRetry == true { reloadEditions() }
                    else { Task { await fetch() } }
                }
            }
        }
        .accessibilityIdentifier("club.editions.emptyReason")
        .task(id: clubID) { await fetch() }
    }

    private var titleText: String {
        if let reasonCode { return reasonCode.title(chinese: chinese) }
        return chinese ? "还没有可分享的自由探索期次" : "No shareable free-explore editions yet"
    }

    private var subtitleText: String {
        if let reasonCode { return reasonCode.subtitle(chinese: chinese) }
        if loading { return chinese ? "正在确认原因…" : "Checking reason…" }
        if error { return chinese ? "暂时无法确认原因" : "Couldn't confirm the reason" }
        return ""
    }

    private func fetch() async {
        guard let clubID, clubID > 0, let client else { return }
        loading = true
        error = false
        defer { loading = false }
        do {
            reasonCode = try await client.editionsEmptyReason(clubID: clubID)
            if reasonCode == nil { error = true }
        } catch {
            self.error = true
        }
    }
}

// MARK: - 4. Personal Settlement Clubs (/api/club/settlement/mine)

@MainActor struct ClubPersonalSettlementSection: View {
    @Environment(\.sweep2Client) private var client
    @Environment(\.locale) private var locale
    @State private var loading = false
    @State private var items: [ClubPersonalSettlementItem] = []
    @State private var failed = false

    private var payoutOpen: Bool { ReviewedAreaSwitch.payout(host: client?.baseURL.host) }

    var body: some View {
        Section(ChannelCopy.text("个人收款结算俱乐部", "Personal Settlement Clubs", locale: locale)) {
            if !payoutOpen {
                CYStatusChip(
                    verbatim: ChannelCopy.text("个人收款结算在当前版本暂未开放", "Personal payout settlement is closed in this release", locale: locale),
                    tone: .neutral,
                    systemImage: "lock"
                )
                .accessibilityIdentifier("club.settlement.mine.closed")
            } else if loading {
                CYLoadingStateView(rows: 2).accessibilityIdentifier("club.settlement.mine.loading")
            } else if failed {
                Text(verbatim: ChannelCopy.text("结算数据暂不可用", "Personal settlement data unavailable", locale: locale))
                    .foregroundStyle(CYColor.textSecondary)
                CYPillButton(ChannelCopy.text("重试", "Retry", locale: locale), style: .secondary) { Task { await load() } }
            } else if items.isEmpty {
                CYEmptyState(systemImage: "tray", verbatim: ChannelCopy.text("没有本人的历史结算记录", "No personal settlement clubs yet", locale: locale))
                    .accessibilityIdentifier("club.settlement.mine.empty")
            } else {
                ForEach(items) { item in
                    CYListRow(verbatim: item.name, trailing: .none) {
                        CYRowIcon(systemImage: "person.badge.shield.checkmark")
                    }
                    .accessibilityIdentifier("club.settlement.mine.row.\(item.clubID)")
                }
            }
        }
        .task(id: payoutOpen) { await load() }
    }

    private func load() async {
        guard payoutOpen, let client else { return }
        loading = true
        failed = false
        defer { loading = false }
        do {
            items = try await client.personalSettlementClubs()
        } catch {
            failed = true
        }
    }
}

// MARK: - 5. Club / Merchant Direct Receivable Ledger

@MainActor struct ClubDirectLedgerSection: View {
    let scope: ClubDirectLedgerScope
    @Environment(\.sweep2Client) private var client
    @Environment(\.locale) private var locale
    @State private var loading = false
    @State private var summary: ClubDirectLedgerSummary?
    @State private var failed = false

    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }

    var body: some View {
        Section(ChannelCopy.text("直收核销台账", "Direct Receivable Ledger", locale: locale)) {
            if loading {
                CYLoadingStateView(rows: 2).accessibilityIdentifier("directLedger.loading")
            } else if failed {
                Text(verbatim: ChannelCopy.text("台账暂不可用", "Direct ledger unavailable", locale: locale))
                    .foregroundStyle(CYColor.textSecondary)
                CYPillButton(ChannelCopy.text("重试", "Retry", locale: locale), style: .secondary) { Task { await load() } }
            } else if let summary {
                LabeledContent(ChannelCopy.text("待结清", "Open", locale: locale)) { Text(verbatim: summary.openTotalText).monospacedDigit() }
                LabeledContent(ChannelCopy.text("已结清", "Settled", locale: locale)) { Text(verbatim: summary.settledTotalText).monospacedDigit() }
                LabeledContent(ChannelCopy.text("待退回", "Refund due", locale: locale)) { Text(verbatim: summary.refundDueTotalText).monospacedDigit() }
                if summary.rows.isEmpty {
                    CYEmptyState(systemImage: "doc.plaintext", verbatim: ChannelCopy.text("暂无直收明细", "No direct ledger entries", locale: locale))
                } else {
                    ForEach(summary.rows) { row in
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            HStack {
                                Text(verbatim: row.amountText).font(CYTypography.cardTitle).monospacedDigit()
                                Spacer()
                                CYStatusChip(verbatim: row.status.label(chinese: chinese), tone: .neutral)
                            }
                            if !row.timeText.isEmpty || !row.claimNo.isEmpty {
                                Text(verbatim: [row.timeText, row.claimNo.isEmpty ? nil : "#\(row.claimNo)"].compactMap { $0 }.joined(separator: " · "))
                                    .font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                            }
                        }
                        .accessibilityIdentifier("directLedger.row.\(row.id)")
                    }
                }
            }
        }
        .task(id: client != nil) { await load() }
    }

    private func load() async {
        guard let client else { return }
        loading = true
        failed = false
        defer { loading = false }
        do {
            summary = try await client.directLedger(scope: scope)
        } catch {
            failed = true
        }
    }
}

// MARK: - 6. Play Lead Release Station + Unlock Chapter Receipt + Guard Appeal

@MainActor struct PlayLeadSweep2ToolsSection: View {
    let activityID: Int
    let members: [PlayLeadProgress.Member]
    let nodeID: Int?
    let pendingUnlockCommandID: String?
    let expectedChapterID: Int?
    let targetChapterID: Int?
    let onReload: () -> Void

    @Environment(\.sweep2Client) private var client
    @Environment(\.locale) private var locale
    @State private var releasingMember: PlayLeadProgress.Member?
    @State private var busy = false
    @State private var statusMessage: String?

    var body: some View {
        if client != nil {
            if let commandID = pendingUnlockCommandID, !commandID.isEmpty {
                CYPillButton(t("查询章节放行回执", "Check chapter unlock receipt"), style: .secondary) {
                    Task { await checkUnlockReceipt(commandID: commandID) }
                }
                .disabled(busy)
                .accessibilityIdentifier("playx.lead.unlockReceipt")
            }
            if let nodeID, nodeID > 0, !members.isEmpty {
                ForEach(members) { member in
                    Button(t("放行站台：\(member.name ?? "队员")", "Release station: \(member.name ?? "Member")")) {
                        releasingMember = member
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("playx.lead.releaseStation.\(member.id)")
                }
            }
            if let statusMessage, !statusMessage.isEmpty {
                Text(verbatim: statusMessage).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("playx.lead.sweep2Status")
            }
        }
        EmptyView()
            .confirmationDialog(
                t("放行这一站", "Release this station"),
                isPresented: Binding(get: { releasingMember != nil }, set: { if !$0 { releasingMember = nil } }),
                titleVisibility: .visible
            ) {
                Button(t("放行", "Release"), role: .destructive) {
                    if let target = releasingMember {
                        releasingMember = nil
                        Task { await release(memberID: target.id) }
                    }
                }
                Button(t("取消", "Cancel"), role: .cancel) { releasingMember = nil }
            } message: {
                Text(verbatim: t("让队员跳过这一站？这一站记 0 分。", "Allow this member to skip the current station with 0 points?"))
            }
    }

    private func t(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    private func release(memberID: Int) async {
        guard let client, let nodeID, nodeID > 0, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            statusMessage = try await client.releaseStation(activityID: activityID, memberID: memberID, nodeID: nodeID)
            onReload()
        } catch {
            statusMessage = t("放行没有发出去，请再试一次", "Release could not be sent. Retry.")
        }
    }

    private func checkUnlockReceipt(commandID: String) async {
        guard let client, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            switch try await client.unlockChapterReceipt(activityID: activityID, commandID: commandID, expectedChapterID: expectedChapterID, targetChapterID: targetChapterID) {
            case .applied:
                statusMessage = t("章节放行已确认", "Chapter unlock confirmed")
                onReload()
            case .pendingConfirmation:
                statusMessage = t("章节放行结果待确认，再点放行只查询原命令", "Unlock outcome pending; recheck queries original command only")
            case .conflicted(let msg):
                statusMessage = msg
            }
        } catch {
            statusMessage = t("章节放行结果待确认，再点放行只查询原命令", "Unlock check failed; retry receipt lookup")
        }
    }
}

@MainActor struct PlayGuardAppealSheet: View {
    let reference: PlayGuardReference
    @Environment(\.sweep2Client) private var client
    @Environment(\.sweep2AccountID) private var accountID
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    @State private var checking = true
    @State private var eligibility: PlayGuardEligibility?
    @State private var command: PlayGuardAppealCommand?
    @State private var reason = ""
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                if checking {
                    Section { CYLoadingStateView(rows: 2) }
                } else if let eligibility {
                    Section(t("守卫记录引用", "Guard Reference")) {
                        LabeledContent(t("记录编号", "Guard Log ID"), value: String(reference.guardLogID))
                        CYStatusChip(
                            verbatim: eligibility.canSubmit
                                ? t("可提交原局守卫申诉", "Eligible to submit guard appeal")
                                : t("原局不可新提交，仅保留查询", "Cannot submit new appeal; receipt lookup only"),
                            tone: eligibility.canSubmit ? .info : .neutral
                        )
                    }
                    if let command {
                        Section(t("已冻结申诉", "Frozen Appeal Command")) {
                            Text(verbatim: command.reason)
                            CYPillButton(t("查询申诉回执", "Check guard appeal receipt"), style: .secondary) {
                                Task { await queryReceipt(command) }
                            }
                            .disabled(busy)
                            .accessibilityIdentifier("playx.guardAppeal.receipt")
                        }
                    } else if eligibility.canSubmit {
                        Section(t("申诉理由", "Appeal Reason")) {
                            TextField(t("请填写1至500字申诉理由", "Enter 1-500 chars"), text: $reason, axis: .vertical)
                                .lineLimit(3...6)
                                .accessibilityIdentifier("playx.guardAppeal.reason")
                            CYPillButton(t("提交守卫申诉", "Submit Guard Appeal"), style: .primary) {
                                Task { await submit() }
                            }
                            .disabled(busy)
                            .accessibilityIdentifier("playx.guardAppeal.submit")
                        }
                    }
                }
                if let message, !message.isEmpty {
                    Section { Text(verbatim: message).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary) }
                }
            }
            .navigationTitle(Text(verbatim: t("原局守卫申诉", "Guard Appeal")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t("关闭", "Close")) { dismiss() } }
            }
            .task(id: reference.guardLogID) { await loadReference() }
        }
    }

    private func t(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    private func loadReference() async {
        guard let client else { checking = false; message = t("申诉服务未配置", "Appeal service unconfigured"); return }
        checking = true
        defer { checking = false }
        do {
            eligibility = try await client.guardReference(reference)
        } catch {
            message = t("原局引用读取失败", "Couldn't verify guard reference")
        }
    }

    private func submit() async {
        guard let client, !busy else { return }
        if let err = AuditAppealValidation.validateReason(reason) {
            message = t(err, "Reason must be 1-500 chars")
            return
        }
        let cmd = PlayGuardAppealCommand(
            guardLogId: reference.guardLogID,
            arrivalRequestId: reference.arrivalRequestID,
            requestId: "guard-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8))",
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        command = cmd
        busy = true
        defer { busy = false }
        do {
            try await client.submitGuardAppeal(command: cmd)
        } catch {
            // Retain frozen command and verify via receipt
        }
        await queryReceipt(cmd)
    }

    private func queryReceipt(_ cmd: PlayGuardAppealCommand) async {
        guard let client, let accountID else { return }
        do {
            if let receipt = try await client.guardAppealReceipt(command: cmd, memberID: accountID) {
                message = receipt.decisionReason ?? t("申诉已提交，等待处理", "Guard appeal submitted")
            } else {
                message = t("尚未取得原请求结果，保留原号，不重新提交", "Outcome not yet confirmed; retaining frozen request ID")
            }
        } catch {
            message = t("尚未取得原请求结果，保留原号，不重新提交", "Receipt lookup failed; retaining frozen request ID")
        }
    }
}

@MainActor struct PlayGuardAppealLookupView: View {
    @Environment(\.locale) private var locale
    @State private var guardLogText = ""
    @State private var routeSessionText = ""
    @State private var nodeIDText = ""
    @State private var arrivalRequestID = ""
    @State private var reference: PlayGuardReference?
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section(t("原局守卫引用", "Guard Reference")) {
                TextField(t("守卫记录编号 (guardLogId)", "Guard Log ID"), text: $guardLogText)
                    .keyboardType(.numberPad)
                TextField(t("路线局号 (routeSessionId)", "Route Session ID"), text: $routeSessionText)
                    .keyboardType(.numberPad)
                TextField(t("点位编号 (nodeId)", "Node ID"), text: $nodeIDText)
                    .keyboardType(.numberPad)
                TextField(t("到达请求号 (arrivalRequestId)", "Arrival Request ID"), text: $arrivalRequestID)
            }
            if let validationMessage {
                Section {
                    Text(verbatim: validationMessage).font(CYTypography.caption).foregroundStyle(CYColor.dangerText)
                }
            }
            Section {
                CYPillButton(t("读取原局申诉资格", "Verify Guard Appeal Eligibility"), style: .primary) {
                    let trimmedArrival = arrivalRequestID.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let guardID = Int(guardLogText), guardID > 0,
                          let sessionID = Int(routeSessionText), sessionID > 0,
                          let nodeID = Int(nodeIDText), nodeID > 0,
                          trimmedArrival.range(of: "^[A-Za-z0-9:_-]{1,80}$", options: .regularExpression) != nil else {
                        validationMessage = t("原到达引用不完整", "Guard reference fields are incomplete")
                        return
                    }
                    validationMessage = nil
                    reference = PlayGuardReference(guardLogID: guardID, routeSessionID: sessionID, nodeID: nodeID, arrivalRequestID: trimmedArrival)
                }
                .accessibilityIdentifier("playx.guardAppeal.open")
            }
        }
        .navigationTitle(Text(verbatim: t("原局守卫申诉", "Guard Appeal")))
        .sheet(isPresented: Binding(get: { reference != nil }, set: { if !$0 { reference = nil } })) {
            if let reference {
                PlayGuardAppealSheet(reference: reference)
            }
        }
    }

    private func t(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }
}
