import SwiftUI

@MainActor struct InvoiceLaunchDetailView: View {
    @ObservedObject var model: InvoiceLaunchPresentation
    let applicationID: Int64
    var onSignIn: (() -> Void)? = nil
    @Environment(\.locale) private var locale
    @State private var confirmsCancel = false
    @State private var reapplying = false
    /// Source `cancelPending`: an unconfirmed withdraw of this application (FIN-12-4).
    private var cancelPending: Bool {
        guard let pending = model.overview?.pending else { return false }
        return pending.kind == .cancel && pending.targetID == applicationID
    }
    var body: some View {
        List {
            InvoiceLaunchStateSection(model: model, retry: { await model.loadDetail(applicationID) },
                                      onSignIn: onSignIn, loadFailedKey: "detailLoadFailed")
            // MP invoice-detail `cy-skeleton type="form-section" count="2"` while the detail loads
            // (the shared state section already shows its spinner when the overview is missing too).
            if model.detail?.id != applicationID, model.issue == nil, !(model.busy && model.overview == nil) {
                Section { CYSkeleton(variant: .formSection) }
                    .accessibilityIdentifier("invoice.detail.skeleton")
            }
            if let row = model.detail, row.id == applicationID {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        if cancelPending {
                            // Source 撤回结果未确认 · 待确认.
                            Label { Text(verbatim: invoiceString("pendingTag")) } icon: { Image(systemName: "clock.badge.questionmark").foregroundStyle(CYColor.warningText) }
                                .font(.footnote).foregroundStyle(.secondary)
                            invoiceText("write.cancel.unknown").font(.headline)
                        } else {
                            // MP invoice-detail state-notice tag: the issuing group reads 开具中 (list chips keep 处理中).
                            Label { Text(verbatim: invoiceString(row.status.playerState == .issuing ? "detailTag.issuing" : row.status.labelKey)) } icon: { Image(systemName: row.status.chipSymbol).foregroundStyle(row.status.chipTint) }
                                .font(.footnote).foregroundStyle(.secondary)
                            invoiceText(row.status.noticeKey).font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("invoice.detail.notice")
                    if row.status == .rejected, let reason = row.rejectReason, !reason.isEmpty {
                        LabeledContent { Text(verbatim: reason) } label: { invoiceText("rejectReason") }
                    }
                }
                Section {
                    LabeledContent { Text(verbatim: row.titleName) } label: { invoiceText("titleName") }
                    // MP: 抬头类型 hides when empty; anything but COMPANY reads 个人.
                    if !row.titleType.isEmpty {
                        LabeledContent { invoiceText(row.titleType == "COMPANY" ? "COMPANY" : "PERSONAL") } label: { invoiceText("titleType") }
                    }
                    if let tax = row.taxNoMasked, !tax.isEmpty {
                        LabeledContent { Text(verbatim: tax) } label: { invoiceText("taxNo") }
                    }
                    // Source 开票单位 (FIN-12-3): the issuer the orders were applied under.
                    if let issuer = issuerName(row) {
                        LabeledContent { Text(verbatim: issuer) } label: { invoiceText("issuer") }
                    }
                    if row.status == .issued {
                        if let number = row.invoiceNo, !number.isEmpty {
                            LabeledContent { Text(verbatim: number).textSelection(.enabled) } label: { invoiceText("invoiceNo") }
                        }
                        // Source hides 开具时间 when the server has none (FIN-12-6).
                        if row.issuedAt != nil {
                            LabeledContent { Text(verbatim: invoiceTime(row.issuedAt, locale: locale)) } label: { invoiceText("issuedAt") }
                        }
                    }
                } header: { invoiceText("information") }
                Section {
                    ForEach(row.orders, id: \.orderId) { order in
                        LabeledContent {
                            Text(verbatim: invoiceLaunchDisplayedAmount(order.amount, locale: locale)).monospacedDigit()
                        } label: { Text(verbatim: orderName(order)) }
                    }
                    LabeledContent {
                        Text(verbatim: invoiceLaunchDisplayedAmount(row.totalAmount, locale: locale)).monospacedDigit()
                    } label: { invoiceText("invoiceAmount") }
                } header: { invoiceText("includedOrders") }
                Section {
                    if row.status == .submitted && !cancelPending && model.allows(.cancel) {
                        Button(role: .destructive) { confirmsCancel = true } label: { invoiceText("withdraw") }
                            .accessibilityIdentifier("invoice.cancel")
                    }
                    // Source 重新申请 on a rejected application (FIN-12-1). Apply stays behind the existing permit.
                    if row.status == .rejected && !cancelPending && model.allows(.apply) {
                        Button { reapplying = true } label: { invoiceText("reapply") }
                            .accessibilityIdentifier("invoice.reapply")
                    }
                    if cancelPending {
                        Button { Task { await model.refresh(manual: true); await model.loadDetail(applicationID) } } label: { invoiceText("refresh") }
                            .disabled(model.busy)
                            .accessibilityIdentifier("invoice.detail.refresh")
                    }
                    // Source 联系客服 (FIN-12-2): the app's read-only support page.
                    NavigationLink { ParticipationSupportView() } label: {
                        Label { invoiceText("contactSupport") } icon: { Image(systemName: "message").accessibilityHidden(true) }
                    }
                    .accessibilityIdentifier("invoice.detail.support")
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyPageTitle(verbatim: invoiceString("detail"))
        .task(id: applicationID) {
            // A deep link lands here first: read the overview so permits and the pending state are known.
            if model.overview == nil { await model.refresh() }
            await model.loadDetail(applicationID)
        }
        .refreshable { await model.loadDetail(applicationID) }
        .cySheet(isPresented: $confirmsCancel) {
            MemberInvoiceWithdrawConfirmSheet(confirmIdentifier: "invoice.withdraw.confirm") {
                confirmsCancel = false
                Task { if await model.cancel(applicationID) { await model.loadDetail(applicationID) } }
            }
        }
        .navigationDestination(isPresented: $reapplying) { InvoiceLaunchApplyView(model: model, onSignIn: onSignIn) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let notice = model.writeNotice, notice.action == .cancel {
                InvoiceLaunchWriteNoticeView(notice: notice)
                    .padding()
                    .background(.bar)
            }
        }
        .cyPushedChrome(domain: .player)
        .cyDomainScreen(.player)
    }
    private func issuerName(_ row: InvoiceLaunchApplication) -> String? {
        row.orders.lazy.compactMap { $0.issuerName?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
    }
    /// Source `orderTitle · ticketName`.
    private func orderName(_ order: InvoiceLaunchOrder) -> String {
        let title = order.orderTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ticket = order.ticketName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let head = title.isEmpty ? InvoiceLaunchApplyPage.unknownDisplay : title
        return ticket.isEmpty ? head : head + " · " + ticket
    }
}
