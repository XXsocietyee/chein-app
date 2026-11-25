import SwiftUI

@MainActor struct InvoiceLaunchTitlesView: View {
    @ObservedObject var model: InvoiceLaunchPresentation
    var onSignIn: (() -> Void)? = nil
    @State private var deleteID: Int64?
    @State private var adding = false
    @State private var toast: String?
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
            InvoiceLaunchStateSection(model: model, sessionTitle: "u9cde.invoice.login.titles", onSignIn: onSignIn, loadFailedKey: "titlesLoadFailed")
            if facts.readOnly, let key = facts.readOnlyKey {
                Section { invoiceText(key).foregroundStyle(.secondary) }
                    .accessibilityIdentifier(facts.readOnlyIdentifier ?? "invoice.titlesReadOnly")
            }
            if facts.phase == .empty, model.overview != nil {
                CYEmptyState(systemImage: "tray", "noTitles", tableName: "InvoiceLaunchUI")
                    .frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
            // R7-MEM-14-1: the shared state section already states an unresolved save with its 查询结果 row.
            if facts.showsPendingSave, !model.unresolved {
                // Source 上次保存结果未确认 · 确认前请勿修改抬头. Request numbers are never shown or spoken (FIN-14-2).
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        invoiceText("titleSave.unknown").cyText(.bodyMedium)
                        invoiceText("titleSave.unknown.sub").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                    .accessibilityIdentifier("invoice.titles.unknown")
            }
            if !facts.rows.isEmpty {
                // One row per title: name + 单位/个人 · 部分税号 · 默认, tap to edit, delete as a labelled trailing action (FIN-14-3).
                Section {
                    ForEach(facts.rows, id: \.id) { title in
                        titleRow(title)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        // Source footer primary 新增发票抬头 (FIN-14-5).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if facts.canAdd {
                CYFooterBar {
                    CYPillButton("addTitleLong", style: .primary, tableName: "InvoiceLaunchUI") { adding = true }
                        .accessibilityIdentifier("invoice.title.add")
                }
            }
        }
        .navigationDestination(isPresented: $adding) { InvoiceLaunchTitleEditor(model: model, title: nil) }
        .cyPageTitle(verbatim: invoiceString("titles"))
        .task { await model.refresh() }.refreshable { await model.refresh() }
        .sheet(isPresented: Binding(
            get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
            MemberInvoiceTitleDeleteConfirmSheet {
                if let id = deleteID { Task { _ = await model.delete(id) } }
                deleteID = nil
            }
        }
        // A refused or unconfirmed delete keeps the list (source toast 删除未完成 / 删除结果未确认，请刷新查看, FIN-14-1).
        .onChange(of: model.writeNotice) { _, notice in
            guard let notice, notice.action == .deleteTitle else { return }
            toast = invoiceString(notice.kind == .unknown ? "toast.deleteUnknown" : "write.delete.failed")
        }
        .cyToast(verbatimMessage: $toast, tone: .warning)
        .cyPushedChrome(domain: .player)
        .cyDomainScreen(.player)
    }

    @ViewBuilder private func titleRow(_ title: InvoiceLaunchTitlesPage.Row) -> some View {
        let source = model.overview?.titles.first(where: { $0.id == title.id })
        let name = title.titleName.isEmpty ? InvoiceLaunchTitlesPage.unknownDisplay : title.titleName
        HStack(spacing: CYSpacing.sm) {
            if title.canEdit, let source {
                NavigationLink { InvoiceLaunchTitleEditor(model: model, title: source) } label: { titleLabel(title, name: name) }
                    .accessibilityIdentifier("invoice.title.edit.\(title.id)")
            } else {
                titleLabel(title, name: name)
            }
            if title.canDelete {
                Button { deleteID = title.id } label: {
                    Image(systemName: "trash").foregroundStyle(CYColor.dangerText)
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(verbatim: invoiceString("delete") + name))
                .accessibilityIdentifier("invoice.title.delete.\(title.id)")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if title.canDelete {
                Button(role: .destructive) { deleteID = title.id } label: { invoiceText("delete") }
            }
        }
    }

    private func titleLabel(_ title: InvoiceLaunchTitlesPage.Row, name: String) -> some View {
        let type = title.typeKey == InvoiceLaunchTitlesPage.unknownDisplay ? "" : invoiceString(title.typeKey)
        let line = [type, title.taxText ?? "", title.showsDefault ? invoiceString("defaultShort") : ""]
            .filter { !$0.isEmpty }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).cyWrapText()
            if !line.isEmpty {
                Text(verbatim: line).cyText(.meta).foregroundStyle(CYColor.textSecondary).cyWrapText()
            }
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
