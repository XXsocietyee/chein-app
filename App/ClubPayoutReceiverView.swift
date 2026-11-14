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
    @State private var bound = false
    @State private var generation = 0

    var body: some View {
        List {
            // Owner 2026-11-14: the status is a read and always shows; bind and unbind need the payout area.
            if !PayoutReceiverBridge.payoutOpen(session) { PayoutAreaClosedNote() }
            content
        }
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .navigationTitle(Text("payoutReceiver.title", tableName: "PayoutReceiver"))
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog(Text("payoutReceiver.bind.confirmTitle", tableName: "PayoutReceiver"), isPresented: $confirmingBind, titleVisibility: .visible) {
            Button { Task { await bind() } } label: { Text("payoutReceiver.bind", tableName: "PayoutReceiver") }
                .accessibilityIdentifier("payoutReceiver.bind.confirm")
        } message: { Text("payoutReceiver.bind.consent", tableName: "PayoutReceiver") }
        .confirmationDialog(Text("payoutReceiver.unbind.confirmTitle", tableName: "PayoutReceiver"), isPresented: $confirmingUnbind, titleVisibility: .visible) {
            Button(role: .destructive) { Task { await unbind() } } label: { Text("payoutReceiver.unbind", tableName: "PayoutReceiver") }
                .accessibilityIdentifier("payoutReceiver.unbind.confirm")
        } message: { Text("payoutReceiver.unbind.detail", tableName: "PayoutReceiver") }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            Section { CYLoadingStateView(rows: 2) }.accessibilityIdentifier("payoutReceiver.loading")
        case .empty:
            Section { CYEmptyState(systemImage: "person.3", "payoutReceiver.noClub", tableName: "PayoutReceiver", messageIdentifier: "payoutReceiver.noClub") }
        case .failed(let issue):
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("payoutReceiver.loadFailed", tableName: "PayoutReceiver").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                    PayoutReceiverIssueText(issue: issue, fallbackKey: "payoutReceiver.statusUnavailable")
                        .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    CYPillButton("payoutReceiver.reload", style: .secondary, tableName: "PayoutReceiver") { Task { await load() } }
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
                    PayoutReceiverIssueText(issue: notice, fallbackKey: "payoutReceiver.actionFailed")
                        .font(CYTypography.meta).foregroundStyle(CYColor.warningText)
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
                guard self.mine else { state = .failed(.rejected(code: "CLUB_REQUIRED", message: nil)); return }
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
        busy = true; notice = nil; bound = false
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
        busy = true; notice = nil; bound = false
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
            if !PayoutReceiverBridge.payoutOpen(session) {
                PayoutAreaClosedNote()
            } else {
                switch state {
                case .loading: Section { CYLoadingStateView(rows: 3) }
                case .empty:
                    Section { CYEmptyState(systemImage: "tray", "clubSettlement.empty", tableName: "PayoutReceiver", messageIdentifier: "clubSettlement.mine.empty") }
                case .failed(let issue):
                    Section {
                        PayoutReceiverIssueText(issue: issue, fallbackKey: "clubSettlement.unavailable")
                        CYPillButton("payoutReceiver.reload", style: .secondary, tableName: "PayoutReceiver") { Task { await load() } }
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
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .navigationTitle(Text("clubSettlement.title", tableName: "PayoutReceiver"))
        .refreshable { await load() }
        .task { await load() }
    }
    private func load() async {
        guard PayoutReceiverBridge.payoutOpen(session) else { return }
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
    var body: some View {
        List {
            if !PayoutReceiverBridge.payoutOpen(session) {
                PayoutAreaClosedNote()
            } else {
                switch state {
                case .loading: Section { CYLoadingStateView(rows: 3) }
                case .empty: Section { CYEmptyState(systemImage: "tray", "clubSettlement.empty", tableName: "PayoutReceiver") }
                case .failed(let issue):
                    Section {
                        PayoutReceiverIssueText(issue: issue, fallbackKey: "clubSettlement.unavailable")
                        CYPillButton("payoutReceiver.reload", style: .secondary, tableName: "PayoutReceiver") { Task { await load() } }
                    }
                case .ready(let summary): ready(summary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .navigationTitle(Text("clubSettlement.title", tableName: "PayoutReceiver"))
        .refreshable { await load() }
        .task { await load() }
    }

    @ViewBuilder private func ready(_ summary: ClubSettlementSummaryView) -> some View {
        if !summary.personal { ClubDirectLedgerSection(scope: .club(clubID: clubID, topicID: nil)) }
        if summary.isOwner { ClubPayoutReceiverLink(clubID: clubID) }
        if summary.isEmpty {
            Section { CYEmptyState(systemImage: "tray", "clubSettlement.empty", tableName: "PayoutReceiver", messageIdentifier: "clubSettlement.empty") }
        }
        if !summary.topics.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("clubSettlement.settled", tableName: "PayoutReceiver").font(CYTypography.label).foregroundStyle(CYColor.textSecondary)
                    if let amount = summary.settledAmountText {
                        Text(verbatim: amount).font(CYTypography.data2XL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                    } else {
                        Text("clubSettlement.amountUnverified", tableName: "PayoutReceiver").font(CYTypography.cardTitle).foregroundStyle(CYColor.warningText)
                    }
                    if summary.unverifiedSettledCount > 0 {
                        Text("clubSettlement.unverifiedCount \(summary.unverifiedSettledCount)", tableName: "PayoutReceiver")
                            .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("clubSettlement.settledCard")
            }
        }
        if !summary.sessions.isEmpty {
            Section {
                ForEach(summary.sessions) { row in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        HStack { Text(verbatim: row.name).font(CYTypography.cardTitle); Spacer(); Text(verbatim: row.netText).monospacedDigit() }
                        Text(verbatim: row.dateText).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        if let gross = row.grossText { Text("clubSettlement.gross \(gross)", tableName: "PayoutReceiver").font(CYTypography.meta) }
                        if let fee = row.feeText {
                            if let rate = row.feeRateText { Text("clubSettlement.feeWithRate \(rate) \(fee)", tableName: "PayoutReceiver").font(CYTypography.meta) }
                            else { Text("clubSettlement.fee \(fee)", tableName: "PayoutReceiver").font(CYTypography.meta) }
                        }
                        if let merchantFee = row.merchantFeeText { Text("clubSettlement.merchantFee \(merchantFee)", tableName: "PayoutReceiver").font(CYTypography.meta) }
                        Text(verbatim: row.payeeText).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("clubSettlement.session.\(row.activityID)")
                }
            } header: { Text("clubSettlement.sessions", tableName: "PayoutReceiver") }
        }
        if !summary.topics.isEmpty {
            Section {
                ForEach(summary.topics) { row in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        HStack {
                            Text(verbatim: row.name).font(CYTypography.cardTitle)
                            Spacer()
                            if let amount = row.amountText { Text(verbatim: amount).monospacedDigit() }
                            else { Text("clubSettlement.chip.unverified", tableName: "PayoutReceiver") }
                        }
                        Text("clubSettlement.original \(row.originalAmountText)", tableName: "PayoutReceiver").font(CYTypography.meta)
                        Text("clubSettlement.adjustment \(row.executedAdjustmentText)", tableName: "PayoutReceiver").font(CYTypography.meta)
                        Text("clubSettlement.net \(row.netAmountText)", tableName: "PayoutReceiver").font(CYTypography.meta)
                        Text(verbatim: row.arrivedText).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        if row.showsPaidText { Text(verbatim: row.paidText).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                        CYStatusChip(verbatim: payoutText(row.chipKey, locale),
                                     tone: row.status == "settled" && row.amountText != nil ? .success : .neutral)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("clubSettlement.topic.\(row.id)")
                }
            } header: { Text("clubSettlement.topics", tableName: "PayoutReceiver") }
        }
        Section {
            NavigationLink { WithdrawalSupportContactView() } label: { Text("clubSettlement.withdrawSupport", tableName: "PayoutReceiver") }
                .accessibilityIdentifier("clubSettlement.withdrawSupport")
        } footer: { Text("clubSettlement.withdrawSupportHint", tableName: "PayoutReceiver") }
    }

    private func load() async {
        guard PayoutReceiverBridge.payoutOpen(session) else { return }
        state = .loading
        do {
            let summary = try await PayoutReceiverBridge.call(session) { try await $0.settlementSummary(clubID: clubID, personal: personal, token: $1) }
            state = .ready(summary)
        } catch { state = .failed(error as? PayoutReceiverIssue ?? .network) }
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
        Group {
            if !PayoutReceiverBridge.payoutOpen(session) {
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
                    Text("directLedger.redemption \(String(row.redemptionID))", tableName: "PayoutReceiver").font(CYTypography.cardTitle)
                    HStack(spacing: CYSpacing.xs) {
                        Text(verbatim: row.timeText)
                        Text(verbatim: "·")
                        Text(LocalizedStringKey(row.statusKey), tableName: "PayoutReceiver")
                    }.font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    if let claim = row.claimNumber { Text("directLedger.claim \(claim)", tableName: "PayoutReceiver").font(CYTypography.meta) }
                    if let voucher = row.voucher { Text("directLedger.voucher \(voucher)", tableName: "PayoutReceiver").font(CYTypography.meta) }
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
            Text(LocalizedStringKey(key), tableName: "PayoutReceiver").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
            Text(verbatim: ClubDirectLedger.amountText(cents)).font(CYTypography.cardTitle).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        guard PayoutReceiverBridge.payoutOpen(session) else { return }
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
