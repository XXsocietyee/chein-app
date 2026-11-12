import SwiftUI

@MainActor struct InvoiceLaunchTitleEditor: View {
    @ObservedObject var model: InvoiceLaunchPresentation
    let title: InvoiceLaunchTitle?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var type: String
    @State private var name: String
    @State private var tax = ""
    @State private var isDefault: Bool
    @State private var invalid = false
    private var screen: InvoiceLaunchTitleEditorScreen {
        let source: InvoiceLaunchTitleEditorSource
        if model.issue == "session" { source = .login }
        else if model.issue == "unavailable" { source = .unavailable }
        else if model.busy, model.overview == nil { source = .loading }
        else if model.issue != nil, model.overview == nil, title != nil { source = .failed }
        else if let titles = model.overview?.titles { source = .titles(titles) }
        else { source = .loading }
        let saved = model.overview?.pending
        let pending: InvoiceLaunchPending? = saved?.kind == .saveTitle ? saved : nil
        return InvoiceLaunchTitleEditorRead.screen(source: source, editingID: title?.id, pending: pending)
    }
    private var saveLocked: Bool {
        if case .unknown = screen { return true }
        return false
    }
    private var lockedRequestID: String? {
        if case .unknown(_, let requestID) = screen { return requestID }
        return nil
    }

    init(model: InvoiceLaunchPresentation, title: InvoiceLaunchTitle?) {
        self.model = model; self.title = title
        _type = State(initialValue: title?.titleType ?? "COMPANY")
        _name = State(initialValue: title?.titleName ?? "")
        _isDefault = State(initialValue: title?.isDefault ?? false)
        // Masked tax projection is display-only and must never enter an editable draft.
    }
    var body: some View {
        Form {
            InvoiceLaunchStateSection(model: model, sessionTitle: "u9cde.invoice.login.titles")
            if saveLocked {
                Section {
                    invoiceText("unknown")
                    Text(verbatim: lockedRequestID?.isEmpty == false ? lockedRequestID! : InvoiceLaunchTitleEditorForm.unknownText)
                        .font(CYTypography.meta).foregroundStyle(.secondary)
                        .accessibilityIdentifier("invoice.title.pendingRequest")
                }
            }
            Section {
                Picker(selection: $type) {
                    invoiceText("COMPANY").tag("COMPANY")
                    invoiceText("PERSONAL").tag("PERSONAL")
                } label: { invoiceText("titleType") }.pickerStyle(.segmented)
                TextField(text: $name) { invoiceText("titleName") }
                    .accessibilityIdentifier("invoice.title.name")
                if type == "COMPANY" {
                    TextField(text: $tax) { invoiceText("taxNo") }
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .privacySensitive().accessibilityIdentifier("invoice.title.tax")
                    if !tax.isEmpty, !InvoiceLaunchTitleRules.isValidTax(tax) {
                        invoiceText("taxInvalid").font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("invoice.title.taxHint")
                    }
                }
                Toggle(isOn: $isDefault) { invoiceText("defaultTitle") }
                if case .ready(let form) = screen {
                    Text(verbatim: form.taxNoMaskedText).font(CYTypography.meta).foregroundStyle(.secondary)
                        .accessibilityIdentifier("invoice.title.taxMask")
                }
            }.disabled(!model.allows(.saveTitle) || saveLocked)
            if invalid { invoiceText("notSaved").font(.footnote).foregroundStyle(.red) }
        }
        .safeAreaInset(edge: .bottom) {
            if model.allows(.saveTitle), !saveLocked {
                CYPillButton("save", style: .primary, tableName: "InvoiceLaunchUI") {
                    do {
                        let draft = try InvoiceLaunchTitleRules.draft(id: title?.id, type: type,
                            name: name, tax: tax, isDefault: isDefault)
                        invalid = false
                        Task { if await model.save(draft) { tax = ""; dismiss() } }
                    } catch { invalid = true }
                }
                .disabled(!InvoiceLaunchTitleRules.canSubmit(type: type, name: name, tax: tax))
                .accessibilityIdentifier("invoice.title.save")
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
            }
        }
        .navigationTitle(invoiceText(title == nil ? "addTitle" : "editTitle"))
        .onChange(of: type) { _, _ in tax = "" }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { tax = ""; name = "" }
        }
        .onChange(of: model.identityRevision) { _, _ in tax = ""; name = ""; dismiss() }
        .onDisappear { tax = ""; name = "" }
    }
}
