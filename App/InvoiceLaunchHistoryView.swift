import SwiftUI

/// Mount only from a reviewed normal account entry, retaining the same model across child pages.
@MainActor struct InvoiceLaunchHistoryView: View {
    @ObservedObject var model: InvoiceLaunchPresentation
    /// Source 微信登录 on the signed-out state. Nil hides the button.
    var onSignIn: (() -> Void)? = nil
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var filter = "all"
    @State private var withdraw = InvoiceLaunchWithdrawFlow()
    @State private var toast: String?
    @ScaledMetric(relativeTo: .caption) private var metaIconSize: CGFloat = 12
    @State private var openTitles = false
    @State private var openApply = false
    private var rows: [InvoiceLaunchApplication] {
        InvoiceLaunchHistoryRules.rows(model.overview?.applications ?? [], filter: filter)
    }
    var body: some View {
        List {
            InvoiceLaunchStateSection(model: model, onSignIn: onSignIn, loadFailedKey: "historyLoadFailed")
            if let overview = model.overview {
                if !overview.applications.isEmpty {
                    // Source cy-tabs variant="chip": 全部 / 处理中 / 已开具 / 已驳回 / 已撤回 (FIN-11-8).
                    CYTabs(items: InvoiceLaunchHistoryRules.filterKeys.map { CYTabItem(id: $0, title: invoiceString($0)) },
                           selection: $filter, variant: .chip)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .accessibilityIdentifier("invoice.history.filter")
                }
                if withdraw.succeeded != nil {
                    Section {
                        Label { invoiceText("withdrawn") } icon: { Image(systemName: "checkmark.circle") }
                            .accessibilityIdentifier("invoice.history.withdrawn")
                    }
                }
                if rows.isEmpty {
                    CYEmptyState(systemImage: "tray", LocalizedStringKey(InvoiceLaunchHistoryRules.emptyKey(total: overview.applications.count, filter: filter)),
                                 tableName: "InvoiceLaunchUI")
                        .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                }
                ForEach(rows, id: \.id) { row in
                    Section {
                        NavigationLink {
                            InvoiceLaunchDetailView(model: model, applicationID: row.id, onSignIn: onSignIn)
                        } label: { historyRow(row) }
                        .accessibilityIdentifier("invoice.history.row.\(row.id)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if canWithdraw(row) {
                                Button(role: .destructive) { withdraw.ask(row.id) } label: { invoiceText("withdraw") }
                                    .accessibilityIdentifier("invoice.history.withdraw.\(row.id)")
                            }
                        }
                        .accessibilityAction(named: Text("withdraw", tableName: "InvoiceLaunchUI")) {
                            if canWithdraw(row) { withdraw.ask(row.id) }
                        }
                        // Source orderbut1 撤回申请 on SUBMITTED cards: a visible action, swipe stays a shortcut (FIN-11-3).
                        if canWithdraw(row) {
                            Button(role: .destructive) { withdraw.ask(row.id) } label: { invoiceText("withdraw").cyText(.label) }
                                .frame(minHeight: CYSpacing.minTouchTarget)
                                .accessibilityIdentifier("invoice.history.withdrawButton.\(row.id)")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        // Source cy-footer-bar 管理抬头 + 申请开票 stays visible above the list (FIN-11-9).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.overview != nil {
                CYFooterBar {
                    HStack(spacing: CYSpacing.md) {
                        CYPillButton("manageTitlesShort", style: .secondary, tableName: "InvoiceLaunchUI") { openTitles = true }
                            .accessibilityIdentifier("invoice.titles.entry")
                        if model.allows(.apply) {
                            CYPillButton("apply", style: .primary, tableName: "InvoiceLaunchUI") { openApply = true }
                                .accessibilityIdentifier("invoice.apply.entry")
                        }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $openTitles) { InvoiceLaunchTitlesView(model: model, onSignIn: onSignIn) }
        .navigationDestination(isPresented: $openApply) { InvoiceLaunchApplyView(model: model, onSignIn: onSignIn) }
        .cyPageTitle(verbatim: invoiceString("history"))
        .task { await model.refresh() }.refreshable { await model.refresh() }
        .sheet(isPresented: Binding(
            get: { withdraw.confirming != nil }, set: { if !$0 { withdraw.cancelAsk() } })) {
            MemberInvoiceWithdrawConfirmSheet(confirmIdentifier: "invoice.history.withdraw.confirm") {
                // Success is announced only after the service returns success.
                if let id = withdraw.confirm() {
                    Task { let ok = await model.cancel(id); withdraw.finish(id: id, success: ok) }
                }
            }
        }
        // A refused or unconfirmed withdraw keeps the list and says so (source toast 撤回未完成 / 撤回结果未确认，请刷新查看, FIN-11-2).
        .onChange(of: model.writeNotice) { _, notice in
            guard let notice, notice.action == .cancel else { return }
            toast = invoiceString(notice.kind == .unknown ? "toast.cancelUnknown" : "write.cancel.failed")
        }
        .cyToast(verbatimMessage: $toast, tone: .warning)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.invalidate() }
            else { Task { await model.refresh() } }
        }
        .cyPushedChrome(domain: .player)
        .cyDomainScreen(.player)
    }
    private func canWithdraw(_ row: InvoiceLaunchApplication) -> Bool {
        InvoiceLaunchHistoryRules.canWithdraw(row.status) && model.allows(.cancel)
    }
    /// Source card: status, title, 单位/个人 tag + masked tax, 申请于 time, issuer · N 笔订单, 开票金额 (FIN-11-5).
    private func historyRow(_ row: InvoiceLaunchApplication) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYStatusChip(verbatim: invoiceString(row.status.labelKey), tone: row.status.chipTone, systemImage: row.status.chipSymbol)
            Text(verbatim: row.titleName.isEmpty ? "—" : row.titleName)
                .cyText(.cardTitle)
                .cyWrapText()
            HStack(spacing: CYSpacing.xs) {
                if row.titleType == "COMPANY" || row.titleType == "PERSONAL" {
                    CYStatusChip(verbatim: invoiceString(row.titleType), tone: .neutral)
                }
                Text(verbatim: row.taxNoMasked.flatMap { $0.isEmpty ? nil : $0 } ?? invoiceString("personalTitle"))
                    .cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // MP `moh-ico`: d_orderIcon (申请于) and d_orderIcon2 (issuer · N 笔订单), 12 pt at the meta size.
            if row.createTime != nil {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                    metaIcon(MPAsset.FeatureIcon.dOrderIcon)
                    Text(verbatim: invoiceString("appliedAt") + " " + invoiceTime(row.createTime, locale: locale)).cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .cyWrapText()
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                metaIcon(MPAsset.FeatureIcon.dOrderIcon2)
                Text(verbatim: issuerLine(row)).cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .cyWrapText()
            }
            HStack(spacing: CYSpacing.xs) {
                invoiceText("invoiceAmount").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: invoiceLaunchDisplayedAmount(row.totalAmount, locale: locale))
                    .cyText(.numericBody)
                    .monospacedDigit()
                    .foregroundStyle(CYColor.textPrimary)
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
    }
    private func metaIcon(_ image: Image) -> some View {
        image.resizable().scaledToFit()
            .frame(width: metaIconSize, height: metaIconSize)
            .accessibilityHidden(true)
    }
    /// Source `{issuerName · }N 笔订单`.
    private func issuerLine(_ row: InvoiceLaunchApplication) -> String {
        let issuer = row.orders.lazy.compactMap { $0.issuerName?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        let count = String(format: invoiceString("orderCountFormat"), locale: locale, max(row.orderCount, row.orders.count))
        return issuer.map { $0 + " · " + count } ?? count
    }
}
