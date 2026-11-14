import SwiftUI

@MainActor struct InvoiceLaunchDetailView: View {
    @ObservedObject var model: InvoiceLaunchPresentation
    let applicationID: Int64
    @Environment(\.locale) private var locale
    @State private var confirmsCancel = false
    var body: some View {
        List {
            InvoiceLaunchStateSection(model: model, retry: { await model.loadDetail(applicationID) })
            if let row = model.detail, row.id == applicationID {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYStatusChip(verbatim: invoiceString(row.status.labelKey), tone: row.status.chipTone, systemImage: row.status.chipSymbol)
                        invoiceText(row.status.noticeKey).font(CYTypography.sectionTitle)
                        Text(verbatim: invoiceLaunchDisplayedAmount(row.totalAmount, locale: locale)).font(CYTypography.dataXL).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, CYSpacing.xs)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("invoice.detail.notice")
                    if row.status == .rejected, let reason = row.rejectReason, !reason.isEmpty {
                        LabeledContent { Text(verbatim: reason) } label: { invoiceText("rejectReason") }
                    }
                }
                Section {
                    LabeledContent { Text(verbatim: row.titleName) } label: { invoiceText("titleName") }
                    LabeledContent { invoiceText(row.titleType) } label: { invoiceText("titleType") }
                    if let tax = row.taxNoMasked, !tax.isEmpty {
                        LabeledContent { Text(verbatim: tax) } label: { invoiceText("taxNo") }
                    }
                    if row.status == .issued {
                        if let number = row.invoiceNo, !number.isEmpty {
                            LabeledContent { Text(verbatim: number).textSelection(.enabled) } label: { invoiceText("invoiceNo") }
                        }
                        LabeledContent { Text(verbatim: invoiceTime(row.issuedAt, locale: locale)) } label: { invoiceText("issuedAt") }
                    }
                } header: { invoiceText("information") }
                Section {
                    ForEach(row.orders, id: \.orderId) { order in
                        LabeledContent {
                            Text(verbatim: invoiceLaunchDisplayedAmount(order.amount, locale: locale))
                        } label: { Text(verbatim: order.orderTitle ?? InvoiceLaunchApplyPage.unknownDisplay) }
                    }
                    LabeledContent { Text(verbatim: invoiceLaunchDisplayedAmount(row.totalAmount, locale: locale)).bold() } label: { invoiceText("amount") }
                } header: { invoiceText("orders") }
                if row.status == .submitted && model.allows(.cancel) {
                    Section {
                        Button(role: .destructive) { confirmsCancel = true } label: { invoiceText("withdraw") }
                            .accessibilityIdentifier("invoice.cancel")
                    }
                }
            }
        }
        .listStyle(.insetGrouped).navigationTitle(invoiceText("detail"))
        .task(id: applicationID) { await model.loadDetail(applicationID) }
        .refreshable { await model.loadDetail(applicationID) }
        .sheet(isPresented: $confirmsCancel) {
            MemberInvoiceWithdrawConfirmSheet(confirmIdentifier: "invoice.withdraw.confirm") {
                confirmsCancel = false
                Task { if await model.cancel(applicationID) { await model.loadDetail(applicationID) } }
            }
        }
        .cyDomainScreen(.player)
    }
}
