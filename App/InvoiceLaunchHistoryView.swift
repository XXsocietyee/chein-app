import SwiftUI

/// Mount only from a reviewed normal account entry, retaining the same model across child pages.
@MainActor struct InvoiceLaunchHistoryView: View {
    @ObservedObject var model: InvoiceLaunchPresentation
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var filter = "all"
    @State private var withdraw = InvoiceLaunchWithdrawFlow()
    private var rows: [InvoiceLaunchApplication] {
        InvoiceLaunchHistoryRules.rows(model.overview?.applications ?? [], filter: filter)
    }
    var body: some View {
        List {
            InvoiceLaunchStateSection(model: model)
            if let overview = model.overview {
                if !overview.applications.isEmpty {
                    Picker(selection: $filter) {
                        ForEach(InvoiceLaunchHistoryRules.filterKeys, id: \.self) { key in
                            invoiceText(key).tag(key)
                        }
                    } label: { invoiceText("status") }
                    .pickerStyle(.menu).accessibilityIdentifier("invoice.history.filter")
                }
                if withdraw.succeeded != nil {
                    Section {
                        Label { invoiceText("withdrawn") } icon: { Image(systemName: "checkmark.circle") }
                            .accessibilityIdentifier("invoice.history.withdrawn")
                    }
                }
                if rows.isEmpty {
                    ContentUnavailableView {
                        Label { invoiceText(InvoiceLaunchHistoryRules.emptyKey(total: overview.applications.count, filter: filter)) }
                            icon: { Image(systemName: "doc.text") }
                    }
                }
                ForEach(rows, id: \.id) { row in
                    NavigationLink {
                        InvoiceLaunchDetailView(model: model, applicationID: row.id)
                    } label: { historyRow(row) }
                    .accessibilityIdentifier("invoice.history.row.\(row.id)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if InvoiceLaunchHistoryRules.canWithdraw(row.status) && model.allows(.cancel) {
                            Button(role: .destructive) { withdraw.ask(row.id) } label: { invoiceText("withdraw") }
                                .accessibilityIdentifier("invoice.history.withdraw.\(row.id)")
                        }
                    }
                }
                Section {
                    NavigationLink { InvoiceLaunchTitlesView(model: model) } label: { invoiceText("titles") }
                        .accessibilityIdentifier("invoice.titles.entry")
                    if model.allows(.apply) {
                        NavigationLink { InvoiceLaunchApplyView(model: model) } label: { invoiceText("apply") }
                            .accessibilityIdentifier("invoice.apply.entry")
                    }
                }
            }
        }
        .listStyle(.insetGrouped).navigationTitle(invoiceText("history"))
        .task { await model.refresh() }.refreshable { await model.refresh() }
        .confirmationDialog(invoiceText("withdrawConfirm"), isPresented: Binding(
            get: { withdraw.confirming != nil }, set: { if !$0 { withdraw.cancelAsk() } }), titleVisibility: .visible) {
            Button(role: .destructive) {
                // Success is announced only after the service returns success.
                if let id = withdraw.confirm() {
                    Task { let ok = await model.cancel(id); withdraw.finish(id: id, success: ok) }
                }
            } label: { invoiceText("withdraw") }
            Button(role: .cancel) { withdraw.cancelAsk() } label: { invoiceText("keep") }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.invalidate() }
            else { Task { await model.refresh() } }
        }
    }
    private func historyRow(_ row: InvoiceLaunchApplication) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: row.titleName).font(.headline)
                Spacer()
                invoiceText(row.status.labelKey)
            }
            LabeledContent { invoiceText(row.titleType) } label: { invoiceText("titleType") }
            if let tax = row.taxNoMasked, !tax.isEmpty {
                LabeledContent { Text(verbatim: tax) } label: { invoiceText("taxNo") }
            }
            LabeledContent { Text(verbatim: invoiceTime(row.createTime, locale: locale)) } label: { invoiceText("created") }
            LabeledContent { Text(row.orderCount, format: .number) } label: { invoiceText("orderCount") }
            LabeledContent { Text(verbatim: invoiceAmount(row.totalAmount, locale: locale)) } label: { invoiceText("amount") }
        }.fixedSize(horizontal: false, vertical: true)
    }
}
