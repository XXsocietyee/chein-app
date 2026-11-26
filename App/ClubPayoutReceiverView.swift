import SwiftUI

// WP-01. Ports mini-program pages/club/payout-receiver, pages/club/settlement (mine list and personal summary)
// and components/cy/club-direct-ledger. Every page stays visible; when the payout area is closed (production host,
// Release) it shows one sentence and sends nothing.

enum PayoutPageState<Value: Equatable>: Equatable {
    case loading
    case failed(PayoutReceiverIssue)
    case empty
    case ready(Value)
}

/// 「个人收款」: status, bind (consent), rebind when paused, unbind with a destructive confirm.
@MainActor struct ClubPayoutReceiverView: View {
    @Environment(\.locale) private var locale
    @EnvironmentObject private var session: AppSession
    /// nil with `mine` resolves the owner's first club from `/api/club/settlement/mine`.
    let clubID: Int?
    var mine = false
    @State private var resolvedClubID: Int?
    @State private var state: PayoutPageState<ClubPayoutReceiverStatus> = .loading
    @State private var busy = false
    @State private var confirmingBind = false
    @State private var confirmingUnbind = false
    @State private var notice: PayoutReceiverIssue?
    /// Round 4 copy: MP 绑定失败，请重试 / 解除失败，请重试 (payout-receiver index.js) name the action that failed.
    @State private var noticeFromUnbind = false
    @State private var bound = false
    @State private var generation = 0
    /// CLB-r7-D-03 (fix-r3-club-b): no club id and no `mine` — retrying can never succeed, so 返回 only.
    @State private var missingClub = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Owner 2026-11-14: the status is a read and always shows; bind and unbind need the payout area.
            if !PayoutReceiverBridge.payoutOpen(session) { PayoutAreaClosedNote() }
            content
        }
        // CLB-payout-receiver-03 (fix-r3-club-b): the domain screen paints the page; no second background.
        .scrollContentBackground(.hidden)
        .navigationTitle(Text("payoutReceiver.title", tableName: "PayoutReceiver")).navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $confirmingBind) {
            CYConfirmSheet(
                title: String(localized: LocalizedStringResource("payoutReceiver.bind.confirmTitle", table: "PayoutReceiver", locale: locale)),
                message: String(localized: LocalizedStringResource("payoutReceiver.bind.consent", table: "PayoutReceiver", locale: locale)),
                confirmTitle: String(localized: LocalizedStringResource("payoutReceiver.bind", table: "PayoutReceiver", locale: locale)),
                cancelTitle: appLocalized("action.cancel", locale: locale),
                isDestructive: false,
                confirmIdentifier: "payoutReceiver.bind.confirm",
                onCancel: { confirmingBind = false },
                onConfirm: {
                    confirmingBind = false
                    Task { await bind() }
                }
            )
            .cyDomainSheet(detents: [.peek, .half])
        }
        .sheet(isPresented: $confirmingUnbind) {
            CYConfirmSheet(
                // CLB-payout-receiver-02 (fix-r3-club-b): MP danger-actions `club.personal-receiver.unbind` copy.
                title: String(localized: LocalizedStringResource("clubR3b.payout.unbindTitle", locale: locale)),
                message: String(localized: LocalizedStringResource("clubR3b.payout.unbindDetail", locale: locale)),
                confirmTitle: String(localized: LocalizedStringResource("payoutReceiver.unbind", table: "PayoutReceiver", locale: locale)),
                cancelTitle: appLocalized("action.cancel", locale: locale),
                isDestructive: true,
                confirmIdentifier: "payoutReceiver.unbind.confirm",
                onCancel: { confirmingUnbind = false },
                onConfirm: {
                    confirmingUnbind = false
                    Task { await unbind() }
                }
            )
            .cyDomainSheet(detents: [.peek, .half])
        }
        .appSwitcherPrivacyShield()
        .cyDomainScreen(.player)
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            Section { CYLoadingStateView(rows: 2) }.accessibilityIdentifier("payoutReceiver.loading")
        case .empty:
            // CLB-r7-D-04 (fix-r3-club-b): MP 还没有自己的俱乐部 offers 创建俱乐部.
            Section {
                // Round 2 MP asset: cy-empty kind="empty" carries the MP two-layer illustration.
                ClubMPEmptyState(title: Text("payoutReceiver.noClub", tableName: "PayoutReceiver"), messageIdentifier: "payoutReceiver.noClub")
                ClubCreateMyClubLink(identity: session.clubIdentity, titleKey: "clubR3b.payout.createClub")
            }
        case .failed where missingClub:
            Section {
                CYEmptyState(systemImage: "exclamationmark.triangle", "clubR3b.payout.clubMissing", messageIdentifier: "payoutReceiver.clubMissing",
                             actionTitle: "clubR3b.checkin.back", actionStyle: .primary, kind: .failure) { dismiss() }
            }
        case .failed(let issue):
            // CLB-r9-native-03: the read failure is a system ContentUnavailableView (title, the reason, 重新加载).
            Section {
                ContentUnavailableView {
                    Label { Text("payoutReceiver.loadFailed", tableName: "PayoutReceiver") } icon: { Image(systemName: "exclamationmark.triangle") }
                } description: {
                    PayoutReceiverIssueText(issue: issue, fallbackKey: "payoutReceiver.statusUnavailable")
                } actions: {
                    Button { Task { await load() } } label: { Text("payoutReceiver.reload", tableName: "PayoutReceiver") }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("payoutReceiver.reload")
                }
            }
        case .ready(let status):
            Section {
                LabeledContent {
                    CYStatusChip(verbatim: payoutText(status.stateKey, locale),
                                 tone: tone(status.tone))
                } label: { Text("payoutReceiver.row.state", tableName: "PayoutReceiver") }
                    .accessibilityIdentifier("payoutReceiver.state." + status.pageState.rawValue)
                if status.paused {
                    LabeledContent { Text("payoutReceiver.pause.bindingRequired", tableName: "PayoutReceiver") }
                        label: { Text("payoutReceiver.row.reason", tableName: "PayoutReceiver") }
                }
                if status.payoutPending {
                    LabeledContent { Text("payoutReceiver.payoutPending", tableName: "PayoutReceiver") }
                        label: { Text("payoutReceiver.row.payout", tableName: "PayoutReceiver") }
                        .accessibilityIdentifier("payoutReceiver.payoutPending")
                }
            }
            if PayoutReceiverBridge.payoutOpen(session) { Section {
                if let key = status.bindKey {
                    CYPillButton(LocalizedStringKey(key), style: .primary, tableName: "PayoutReceiver") { if !busy { confirmingBind = true } }
                        .disabled(busy).accessibilityIdentifier("payoutReceiver.bind")
                }
                if status.pageState != .unbound, status.canUnbind {
                    CYPillButton("payoutReceiver.unbind", style: .secondary, tableName: "PayoutReceiver") { if !busy { confirmingUnbind = true } }
                        .disabled(busy).accessibilityIdentifier("payoutReceiver.unbind")
                }
                if busy { ProgressView() }
                if bound { CYStatusChip(verbatim: payoutText("payoutReceiver.bound", locale), tone: .success, systemImage: "checkmark") }
                if let notice {
                    PayoutReceiverIssueText(issue: notice, fallbackKey: noticeFromUnbind ? "payoutReceiver.unbindFailed" : "payoutReceiver.bindFailed")
                        .cyText(.meta).foregroundStyle(CYColor.warningText)
                        .accessibilityIdentifier("payoutReceiver.notice")
                }
            }
            .listRowBackground(Color.clear) }
        }
    }

    private func tone(_ raw: String) -> CYStatusTone {
        switch raw { case "success": return .success; case "warning": return .warning; default: return .neutral }
    }

    private func load() async {
        generation += 1
        let mine = generation
        state = .loading
        do {
            var club = resolvedClubID ?? clubID
            if club == nil {
                guard self.mine else { missingClub = true; state = .failed(.rejected(code: "CLUB_REQUIRED", message: nil)); return }
                let clubs = try await PayoutReceiverBridge.call(session) { try await $0.settlementClubs(token: $1) }
                guard mine == generation else { return }
                guard let first = clubs.first else { state = .empty; return }
                club = first.id; resolvedClubID = first.id
            }
            guard let club else { return }
            let status = try await PayoutReceiverBridge.call(session) { try await $0.receiverStatus(clubID: club, token: $1) }
            guard mine == generation else { return }
            state = .ready(status)
        } catch {
            guard mine == generation else { return }
            state = .failed(error as? PayoutReceiverIssue ?? .network)
        }
    }

    private func bind() async {
        guard !busy, let club = resolvedClubID ?? clubID else { return }
        busy = true; notice = nil; noticeFromUnbind = false; bound = false
        defer { busy = false }
        guard let code = await PayoutReceiverBridge.weChatCode?(), !code.isEmpty else {
            notice = .rejected(code: "WECHAT_MINI_IDENTITY_REQUIRED", message: nil); return
        }
        do {
            try await PayoutReceiverBridge.call(session) { try await $0.bind(clubID: club, jsCode: code, token: $1) }
            bound = true
            await load()
        } catch { notice = error as? PayoutReceiverIssue ?? .network }
    }

    private func unbind() async {
        guard !busy, let club = resolvedClubID ?? clubID else { return }
        busy = true; notice = nil; noticeFromUnbind = true; bound = false
        defer { busy = false }
        do {
            try await PayoutReceiverBridge.call(session) { try await $0.unbind(clubID: club, token: $1) }
            await load()
        } catch { notice = error as? PayoutReceiverIssue ?? .network }
    }
}

/// Mini-program `pages/club/settlement?mine=1`: the owner's clubs; each opens that club's personal settlement.
@MainActor struct ClubSettlementMineView: View {
    @EnvironmentObject private var session: AppSession
    @State private var state: PayoutPageState<[PayoutSettlementClub]> = .loading
    var body: some View {
        List {
            if !PayoutReceiverBridge.readsOpen(session) {
                PayoutAreaClosedNote()
            } else {
                switch state {
                case .loading: Section { CYLoadingStateView(rows: 3) }
                case .empty:
                    Section { ClubMPEmptyState(title: Text("clubSettlement.empty", tableName: "PayoutReceiver"), messageIdentifier: "clubSettlement.mine.empty") }
                case .failed(let issue):
                    Section {
                        // CLB-r9-native-03: system failure state with 重新加载.
                        ContentUnavailableView {
                            Label { PayoutReceiverIssueText(issue: issue, fallbackKey: "clubSettlement.unavailable") } icon: { Image(systemName: "exclamationmark.triangle") }
                        } actions: {
                            Button { Task { await load() } } label: { Text("payoutReceiver.reload", tableName: "PayoutReceiver") }
                                .buttonStyle(.bordered)
                        }
                    }
                case .ready(let clubs):
                    Section {
                        ForEach(clubs) { club in
                            NavigationLink { ClubPersonalSettlementView(clubID: club.id, personal: true) } label: { Text(verbatim: club.name) }
                                .accessibilityIdentifier("clubSettlement.mine.club.\(club.id)")
                        }
                    }
                }
            }
        }
        // CLB-payout-receiver-03 (fix-r3-club-b): the domain screen paints the page; no second background.
        .scrollContentBackground(.hidden)
        .navigationTitle(Text("clubSettlement.title", tableName: "PayoutReceiver"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .cyDomainScreen(.player)
    }
    private func load() async {
        guard PayoutReceiverBridge.readsOpen(session) else { return }
        state = .loading
        do {
            let clubs = try await PayoutReceiverBridge.call(session) { try await $0.settlementClubs(token: $1) }
            state = clubs.isEmpty ? .empty : .ready(clubs)
        } catch { state = .failed(error as? PayoutReceiverIssue ?? .network) }
    }
}

/// Mini-program `pages/club/settlement?clubId=&personal=1`: sessions (F-16), topics, the direct ledger (club view only)
/// and the personal receiver entry for the owner. Withdrawal goes to platform support, never a bank form.
@MainActor struct ClubPersonalSettlementView: View {
    @Environment(\.locale) private var locale
    @EnvironmentObject private var session: AppSession
    let clubID: Int
    var personal = false
    @State private var state: PayoutPageState<ClubSettlementSummaryView> = .loading
    @State private var fundsAvailability: ClubOwnerFundsAvailability = .unknown
    @State private var complaintWaiting = false
    var body: some View {
        // CLB-settlement-03 (fix-r3-club-b): the club view (`?clubId=` without personal=1) is the same page as
        // 管理 → 俱乐部结算, so it renders that one implementation (summary card, sessions, ledger, funds, topic rows).
        if !personal, let g = session.clubManagementContext.governance {
            ClubGovernanceReadView(operation: .settlement, scope: .init(clubID: clubID), identity: session.clubIdentity,
                                   access: g.access, coordinator: g.coordinator)
                .environment(\.clubOwnerRefundCoordinator, g.ownerRefund)
                .environment(\.clubOwnerFunds, g.ownerFunds)
                .environment(\.clubCustomerTopics, g.customerTopics)
        } else {
            personalBody
        }
    }

    private var personalBody: some View {
        List {
            if !PayoutReceiverBridge.readsOpen(session) {
                PayoutAreaClosedNote()
            } else {
                switch state {
                case .loading: Section { CYLoadingStateView(rows: 3) }
                case .empty: Section { ClubMPEmptyState(title: Text("clubSettlement.empty", tableName: "PayoutReceiver")) }
                case .failed(let issue):
                    Section {
                        // CLB-r9-native-03: system failure state with 重新加载.
                        ContentUnavailableView {
                            Label { PayoutReceiverIssueText(issue: issue, fallbackKey: "clubSettlement.unavailable") } icon: { Image(systemName: "exclamationmark.triangle") }
                        } actions: {
                            Button { Task { await load() } } label: { Text("payoutReceiver.reload", tableName: "PayoutReceiver") }
                                .buttonStyle(.bordered)
                        }
                    }
                case .ready(let summary): ready(summary)
                }
            }
        }
        // CLB-payout-receiver-03 (fix-r3-club-b): the domain screen paints the page; no second background.
        .scrollContentBackground(.hidden)
        .navigationTitle(Text("clubSettlement.title", tableName: "PayoutReceiver"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .cyDomainScreen(.player)
    }

    @ViewBuilder private func ready(_ summary: ClubSettlementSummaryView) -> some View {
        if !summary.personal { ClubDirectLedgerSection(scope: .club(clubID: clubID, topicID: nil)) }
        else { ClubFEReferenceSettlementHost() } // CLB-G17: MP shows the payer reference block on the personal view too.
        // CLB-r9-settlement-01 (MP settlement wxml:13): cy-funds-stages for the owner or the personal view.
        if summary.isOwner || summary.personal {
            ClubPersonalFundsStagesSection(context: session.clubOwnerFundsContext(),
                                           availability: $fundsAvailability, complaintWaiting: $complaintWaiting)
        }
        if summary.isOwner { ClubPayoutReceiverLink(clubID: clubID) }
        if summary.isEmpty {
            Section { ClubMPEmptyState(title: Text("clubSettlement.empty", tableName: "PayoutReceiver"), messageIdentifier: "clubSettlement.empty") }
        }
        if !summary.topics.isEmpty {
            Section {
                // CLB-settlement-07 (fix-r3-club-b), MC-29: the same card as 管理 → 结算: an unverified total is "—"
                // (VoiceOver: 金额待核验) and the unverified count is a warning chip.
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("clubSettlement.settled", tableName: "PayoutReceiver").cyText(.label).foregroundStyle(CYColor.textSecondary)
                    if let amount = summary.settledAmountText {
                        Text(verbatim: ClubMoneyText.display(amount)).cyText(.data2XL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                    } else {
                        Text(verbatim: ClubOpsGovernanceCount.unknownDisplay).cyText(.data2XL).monospacedDigit()
                            .foregroundStyle(CYColor.textPrimary)
                            .accessibilityLabel(Text("clubSettlement.amountUnverified", tableName: "PayoutReceiver"))
                    }
                    if summary.unverifiedSettledCount > 0 {
                        CYStatusChip(verbatim: String(localized: LocalizedStringResource("clubSettlement.unverifiedCount \(summary.unverifiedSettledCount)", table: "PayoutReceiver", locale: locale)),
                                     tone: .warning, systemImage: "questionmark.circle")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("clubSettlement.settledCard")
            }
        }
        ClubSettlementSessionsSection(sessions: summary.sessions)
        if !summary.topics.isEmpty {
            Section {
                ForEach(summary.topics) { row in
                    // CLB-settlement-04 (fix-r8-club): MP goTopicSettlement (js:243-254) opens coop/settlement-detail
                    // source=club by the row id (else topicId), keeping personal=1.
                    NavigationLink {
                        CoopClubSettlementScreen(reader: session.cooperationFlowReader, clubID: clubID,
                                                 recordID: String(row.id > 0 ? row.id : row.topicID), personal: summary.personal,
                                                 recordKey: row.id > 0 ? "id" : "topicId")
                    } label: {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        HStack {
                            Text(verbatim: row.name).cyText(.cardTitle)
                            Spacer()
                            if let amount = row.amountText { Text(verbatim: ClubMoneyText.display(amount)).monospacedDigit() }
                            else { Text("clubSettlement.chip.unverified", tableName: "PayoutReceiver") }
                        }
                        Text("clubSettlement.original \(ClubMoneyText.display(row.originalAmountText))", tableName: "PayoutReceiver").cyText(.meta)
                        Text("clubSettlement.adjustment \(ClubMoneyText.display(row.executedAdjustmentText))", tableName: "PayoutReceiver").cyText(.meta)
                        Text("clubSettlement.net \(ClubMoneyText.display(row.netAmountText))", tableName: "PayoutReceiver").cyText(.meta)
                        Text(verbatim: row.arrivedText).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        if row.showsPaidText { Text(verbatim: row.paidText).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                        CYStatusChip(verbatim: payoutText(row.chipKey, locale),
                                     tone: row.status == "settled" && row.amountText != nil ? .success : .neutral)
                    }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("clubSettlement.topic.\(row.id)")
                }
            } header: { Text("clubSettlement.topics", tableName: "PayoutReceiver") }
        }
        Section {
            // CLB-settlement-06 (MP settlement wxml:43-49): 联系平台客服提现 is disabled unless the funds stages read a
            // positive withdrawable amount. No write is sent either way; withdrawal is a support hand-off.
            NavigationLink { WithdrawalSupportContactView() } label: { Text("clubSettlement.withdrawSupport", tableName: "PayoutReceiver") }
                .disabled(!fundsAvailability.allowsWithdraw)
                .accessibilityIdentifier("clubSettlement.withdrawSupport")
        } footer: {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if fundsAvailability == .zero && complaintWaiting {
                    // MP wxml:48 客诉期结束后可提现.
                    Text("clubSettlement.withdraw.complaintWaiting").accessibilityIdentifier("clubSettlement.withdraw.complaintWaiting")
                } else if fundsAvailability == .unknown && !summary.isOwner && !summary.personal {
                    // MP wxml:49 仅主理人可发起提现.
                    Text("clubOps.settlement.withdraw.ownerOnly", tableName: "ClubOpsCustomer")
                }
                Text("clubSettlement.withdrawSupportHint", tableName: "PayoutReceiver")
            }
        }
    }

    private func load() async {
        guard PayoutReceiverBridge.readsOpen(session) else { return }
        state = .loading
        do {
            let summary = try await PayoutReceiverBridge.call(session) { try await $0.settlementSummary(clubID: clubID, personal: personal, token: $1) }
            state = .ready(summary)
        } catch { state = .failed(error as? PayoutReceiverIssue ?? .network) }
    }
}

/// 各场次结算 (F-16 session money, paid straight to the owner). Shared by the personal settlement page and the
/// 管理 → 结算 read (CLB-settlement-01), so both show the same rows.
struct ClubSettlementSessionsSection: View {
    let sessions: [ClubSettlementSummaryView.Session]
    var body: some View {
        if !sessions.isEmpty {
            Section {
                ForEach(sessions) { row in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        HStack { Text(verbatim: row.name).cyText(.cardTitle); Spacer(); Text(verbatim: row.netText).monospacedDigit() }
                        Text(verbatim: row.dateText).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        if let gross = row.grossText { Text("clubSettlement.gross \(gross)", tableName: "PayoutReceiver").cyText(.meta) }
                        if let fee = row.feeText {
                            if let rate = row.feeRateText { Text("clubSettlement.feeWithRate \(rate) \(fee)", tableName: "PayoutReceiver").cyText(.meta) }
                            else { Text("clubSettlement.fee \(fee)", tableName: "PayoutReceiver").cyText(.meta) }
                        }
                        if let merchantFee = row.merchantFeeText { Text("clubSettlement.merchantFee \(merchantFee)", tableName: "PayoutReceiver").cyText(.meta) }
                        Text(verbatim: row.payeeText).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("clubSettlement.session.\(row.activityID)")
                }
            } header: { Text("clubSettlement.sessions", tableName: "PayoutReceiver") }
        }
    }
}

/// Owner-only row on the club settlement page (mini-program `openPayoutReceiver`).
struct ClubPayoutReceiverLink: View {
    let clubID: Int
    var body: some View {
        Section {
            NavigationLink { ClubPayoutReceiverView(clubID: clubID) } label: {
                Label { Text("payoutReceiver.title", tableName: "PayoutReceiver") } icon: { Image(systemName: "person.crop.circle.badge.checkmark") }
            }
            .accessibilityIdentifier("clubSettlement.openPayoutReceiver")
        }
    }
}

/// `cy-club-direct-ledger`: 「商家计酬」 (club view) or 「俱乐部计酬」 (merchant view), paid by the club directly.
/// On the club settlement page a ready ledger with no rows is not drawn (k4: three ¥0.00 cells would read as a debt).
@MainActor struct ClubDirectLedgerSection: View {
    @EnvironmentObject private var session: AppSession
    let scope: ClubDirectLedger.Scope
    @State private var state: PayoutPageState<ClubDirectLedger> = .loading
    private var isClub: Bool { if case .club = scope { return true } else { return false } }

    var body: some View {
        ledgerBody
        // CLB-G17 / CLB-r7-D-01 (fix-r8-club): MP settlement wxml:9-11, the reference settlement follows the ledger.
        if isClub { ClubFEReferenceSettlementHost() }
    }

    private var ledgerBody: some View {
        Group {
            if !PayoutReceiverBridge.readsOpen(session) {
                EmptyView()
            } else if case .ready(let ledger) = state, isClub, ledger.rows.isEmpty {
                EmptyView()
            } else {
                Section {
                    switch state {
                    case .loading, .empty: CYLoadingStateView(rows: 1)
                    case .failed:
                        HStack {
                            Text("directLedger.failed", tableName: "PayoutReceiver").foregroundStyle(CYColor.textSecondary)
                            Spacer()
                            Button { Task { await load() } } label: { Text("payoutReceiver.retry", tableName: "PayoutReceiver") }
                                .accessibilityIdentifier("directLedger.retry")
                        }
                    case .ready(let ledger): rows(ledger)
                    }
                } header: {
                    HStack {
                        Text(LocalizedStringKey(isClub ? "directLedger.title.club" : "directLedger.title.merchant"), tableName: "PayoutReceiver")
                        Spacer()
                        if case .ready(let ledger) = state { Text("directLedger.count \(ledger.activeCount)", tableName: "PayoutReceiver").monospacedDigit() }
                    }
                } footer: { Text("directLedger.subtitle", tableName: "PayoutReceiver") }
            }
        }
        .task(id: scope) { await load() }
    }

    @ViewBuilder private func rows(_ ledger: ClubDirectLedger) -> some View {
        HStack(spacing: CYSpacing.md) {
            stat("directLedger.stat.open", ledger.openCents)
            stat("directLedger.stat.settled", ledger.settledCents)
            stat("directLedger.stat.refundDue", ledger.refundDueCents)
        }
        if ledger.rows.isEmpty {
            Text("directLedger.empty", tableName: "PayoutReceiver").foregroundStyle(CYColor.textSecondary)
        }
        ForEach(ledger.rows) { row in
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("directLedger.redemption \(String(row.redemptionID))", tableName: "PayoutReceiver").cyText(.cardTitle)
                    HStack(spacing: CYSpacing.xs) {
                        Text(verbatim: row.timeText)
                        Text(verbatim: "·")
                        Text(LocalizedStringKey(row.statusKey), tableName: "PayoutReceiver")
                    }.cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    if let claim = row.claimNumber { Text("directLedger.claim \(claim)", tableName: "PayoutReceiver").cyText(.meta) }
                    if let voucher = row.voucher { Text("directLedger.voucher \(voucher)", tableName: "PayoutReceiver").cyText(.meta) }
                }
                Spacer()
                Text(verbatim: ClubDirectLedger.amountText(row.amountCents)).monospacedDigit()
                    .strikethrough(row.status == "VOID")
                    .foregroundStyle(row.status == "VOID" ? CYColor.textTertiary : CYColor.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("directLedger.row.\(row.id)")
        }
        if !ledger.rows.isEmpty {
            NavigationLink { WithdrawalSupportContactView() } label: { Text("directLedger.support", tableName: "PayoutReceiver") }
        }
    }

    private func stat(_ key: String, _ cents: Int) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(LocalizedStringKey(key), tableName: "PayoutReceiver").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            Text(verbatim: ClubDirectLedger.amountText(cents)).cyText(.cardTitle).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        guard PayoutReceiverBridge.readsOpen(session) else { return }
        state = .loading
        do {
            let scope = self.scope
            state = .ready(try await PayoutReceiverBridge.call(session) { try await $0.directLedger(scope, token: $1) })
        } catch { state = .failed(error as? PayoutReceiverIssue ?? .network) }
    }
}

/// 「我的」 entries: club owners get 俱乐部结算 (mine list) and 个人收款 (mine=1); merchants get 收款账户.
@MainActor struct PayoutAccountLinks: View {
    @Environment(\.locale) private var locale
    enum Audience { case club, merchant }
    let audience: Audience
    var body: some View {
        switch audience {
        case .club:
            NavigationLink { ClubSettlementMineView() } label: {
                CYListRow(verbatim: payoutText("clubSettlement.title", locale), trailing: .none) { CYRowIcon(systemImage: "yensign.circle") }
            }.accessibilityIdentifier("account.clubSettlementMine")
            NavigationLink { ClubPayoutReceiverView(clubID: nil, mine: true) } label: {
                CYListRow(verbatim: payoutText("payoutReceiver.title", locale), trailing: .none) { CYRowIcon(systemImage: "person.crop.circle.badge.checkmark") }
            }.accessibilityIdentifier("account.payoutReceiver")
        case .merchant:
            NavigationLink { MerchantPayoutAccountView() } label: {
                CYListRow(verbatim: payoutText("payoutAccount.title", locale), trailing: .none) { CYRowIcon(systemImage: "building.columns") }
            }.accessibilityIdentifier("account.merchantPayoutAccount")
        }
    }
}
