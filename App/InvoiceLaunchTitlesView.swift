import SwiftUI

@MainActor struct InvoiceLaunchTitlesView: View {
    @ObservedObject var model: InvoiceLaunchPresentation
    @State private var deleteID: Int64?
    private var titleFacts: InvoiceLaunchTitlesPage.Facts {
        InvoiceLaunchTitlesPage.facts(.init(
            signedIn: model.issue != "session",
            unavailable: model.issue == "unavailable",
            loading: model.busy && model.overview == nil,
            failed: model.issue != nil && model.overview == nil,
            pendingSave: model.unresolved,
            pendingRequestKnown: model.overview?.pending?.titleRequestID != nil,
            writing: model.busy,
            allowsSave: model.allows(.saveTitle),
            allowsDelete: model.allows(.deleteTitle),
            titles: model.overview?.titles))
    }
    var body: some View {
        let facts = titleFacts
        List {
            InvoiceLaunchStateSection(model: model, sessionTitle: "u9cde.invoice.login.titles")
            if facts.readOnly, let key = facts.readOnlyKey {
                Section { invoiceText(key).foregroundStyle(.secondary) }
                    .accessibilityIdentifier(facts.readOnlyIdentifier ?? "invoice.titlesReadOnly")
            }
            if facts.phase == .empty, model.overview != nil {
                CYEmptyState(systemImage: "person.text.rectangle", "noTitles", tableName: "InvoiceLaunchUI")
                    .frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
            if facts.showsPendingSave {
                Section { invoiceText("unknown").foregroundStyle(.secondary) }
                    .accessibilityIdentifier("invoice.titles.unknown")
                    .accessibilityValue(Text(verbatim: model.overview?.pending?.titleRequestID ?? InvoiceLaunchTitlesPage.unknownDisplay))
            }
            ForEach(facts.rows, id: \.id) { title in
                Section {
                    LabeledContent { invoiceText(title.typeKey == InvoiceLaunchTitlesPage.unknownDisplay ? "unknown" : title.typeKey) } label: {
                        Text(verbatim: title.titleName.isEmpty ? "—" : title.titleName).fixedSize(horizontal: false, vertical: true)
                    }
                    if let tax = title.taxText { Text(verbatim: tax) }
                    if title.showsDefault { invoiceText("defaultTitle") }
                    if title.canEdit, let source = model.overview?.titles.first(where: { $0.id == title.id }) {
                        NavigationLink { InvoiceLaunchTitleEditor(model: model, title: source) } label: { invoiceText("edit") }
                            .accessibilityIdentifier("invoice.title.edit.\(title.id)")
                    }
                    if title.canDelete {
                        Button(role: .destructive) { deleteID = title.id } label: { invoiceText("delete") }
                            .accessibilityIdentifier("invoice.title.delete.\(title.id)")
                    }
                }
            }
            if facts.canAdd {
                NavigationLink { InvoiceLaunchTitleEditor(model: model, title: nil) } label: { invoiceText("addTitle") }
                    .accessibilityIdentifier("invoice.title.add")
            }
        }
        .listStyle(.insetGrouped).navigationTitle(invoiceText("titles"))
        .task { await model.refresh() }.refreshable { await model.refresh() }
        .sheet(isPresented: Binding(
            get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
            MemberInvoiceTitleDeleteConfirmSheet {
                if let id = deleteID { Task { _ = await model.delete(id) } }
                deleteID = nil
            }
        }
        .cyDomainScreen(.player)
    }
}
