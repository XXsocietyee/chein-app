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
    var onSignIn: (() -> Void)? = nil
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
    /// Field label with the source required marker (`*`, hidden from VoiceOver) (FIN-15-6).
    private func requiredLabel(_ key: String) -> some View {
        HStack(spacing: 2) {
            invoiceText(key)
            Text(verbatim: "*").foregroundStyle(.red).accessibilityHidden(true)
        }
    }

    init(model: InvoiceLaunchPresentation, title: InvoiceLaunchTitle?, onSignIn: (() -> Void)? = nil) {
        self.model = model; self.title = title; self.onSignIn = onSignIn
        _type = State(initialValue: title?.titleType ?? "COMPANY")
        _name = State(initialValue: title?.titleName ?? "")
        _isDefault = State(initialValue: title?.isDefault ?? false)
        // Masked tax projection is display-only and must never enter an editable draft.
    }
    var body: some View {
        Form {
            InvoiceLaunchStateSection(model: model, sessionTitle: "u9cde.invoice.login.titles", onSignIn: onSignIn, loadFailedKey: "titlesLoadFailed")
            if saveLocked, !model.unresolved {
                // R7-MEM-14-1: shown only when the shared state section is not already stating it.
                // Source 保存结果未确认 · 确认前请勿重复保存. The request number is never shown (FIN-15-2).
                Section {
                    invoiceText("write.save.unknown").font(.body)
                    invoiceText("write.save.unknown.sub")
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("invoice.title.pendingRequest")
                }
            }
            Section {
                Picker(selection: $type) {
                    invoiceText("COMPANY").tag("COMPANY")
                    invoiceText("PERSONAL").tag("PERSONAL")
                } label: { requiredLabel("titleType") }.pickerStyle(.segmented)
                TextField(text: $name) { requiredLabel("titleName") }
                    .accessibilityIdentifier("invoice.title.name")
                if type == "COMPANY" {
                    // Editing never pre-fills the masked number: the source asks for the full one again (FIN-15-4).
                    TextField(text: $tax) { invoiceText(title == nil ? "taxNo" : "taxNo.reenter") }
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .privacySensitive().accessibilityIdentifier("invoice.title.tax")
                    if !tax.isEmpty, !InvoiceLaunchTitleRules.isValidTax(tax) {
                        invoiceText("taxInvalid").font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("invoice.title.taxHint")
                    }
                }
                Toggle(isOn: $isDefault) { invoiceText("setDefault") }
                if case .ready(let form) = screen {
                    Text(verbatim: form.taxNoMaskedText).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("invoice.title.taxMask")
                }
            } footer: { invoiceText("requiredHint") }
            .disabled(!model.allows(.saveTitle) || saveLocked)
            if invalid { Label { invoiceText("notSaved") } icon: { Image(systemName: "exclamationmark.circle") }.foregroundStyle(.red) }
            // A server refusal keeps the form and says why: 发票抬头未保存 · reason (FIN-15-3).
            if let notice = model.writeNotice, notice.action == .saveTitle, notice.kind != .unknown {
                Section { InvoiceLaunchWriteNoticeView(notice: notice) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.allows(.saveTitle), !saveLocked {
                CYFooterBar {
                    Button {
                        do {
                            let draft = try InvoiceLaunchTitleRules.draft(id: title?.id, type: type,
                                name: name, tax: tax, isDefault: isDefault)
                            invalid = false
                            Task { if await model.save(draft) { tax = ""; dismiss() } }
                        } catch { invalid = true }
                    } label: {
                        Text("save", tableName: "InvoiceLaunchUI").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(!InvoiceLaunchTitleRules.canSubmit(type: type, name: name, tax: tax))
                    .accessibilityIdentifier("invoice.title.save")
                }
            }
        }
        .cyPushedChrome(domain: .player)
        // MP invoice-title-edit: `cy-page-title title="发票抬头"` for both new and edit.
        .cyPageTitle(verbatim: invoiceString("titles"))
        .onChange(of: type) { _, _ in tax = "" }
        // Source limits: 抬头名称 100, 税号 20 (FIN-15-4).
        .onChange(of: name) { _, value in if value.count > 100 { name = String(value.prefix(100)) } }
        .onChange(of: tax) { _, value in if value.count > 20 { tax = String(value.prefix(20)) } }
        // Only the full tax number leaves memory in the background; the typed name stays (FIN-15-1).
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { tax = "" }
        }
        .onChange(of: model.identityRevision) { _, _ in tax = ""; name = ""; dismiss() }
        .onDisappear { tax = ""; name = "" }
    }
}
