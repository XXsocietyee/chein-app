import SwiftUI

@MainActor struct ModInstallationTemplateEditorView: View {
    @State var editor: ModInstallationTemplateEditor
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var review: ModInstallationTemplateEditPending?
    @State private var rehearsal: ModInstallationSavedRehearsal?
    @State private var rehearsalReadGeneration = UUID()
    @State private var rehearsalUnavailable = false
    private func rehearsalText(_ key: String) -> String { installedRehearsalLocalized(key, locale: locale) }
    var body: some View {
        Group {
            if editor.isCurrent { content }
            else { Text("modInstallation.templateEdit.unavailable", tableName: "ModInstallation") }
        }.onChange(of: session.sessionRevision) { _, _ in review = nil; editor.cancelReview(); retireRehearsal() }
            .onChange(of: session.modInstallationApproval?.revision) { _, _ in retireRehearsal() }
            .onChange(of: editor.savedRehearsalReadEnabled) { _, enabled in if !enabled { retireRehearsal() } }
            .onChange(of: scenePhase) { _, phase in if phase != .active { retireRehearsal() } }
            .onDisappear { retireRehearsal() }
    }
    private var content: some View {
        Form {
            Section {
                Text("modInstallation.templateEdit.scope", tableName: "ModInstallation")
                Text(verbatim: editor.installation.requestId).font(.caption.monospaced())
                if let state = editor.state {
                    Text(verbatim: "#\(state.templateId) · \(state.draftContentHash)").font(.caption.monospaced())
                    if !state.editable { Text("modInstallation.templateEdit.locked", tableName: "ModInstallation") }
                    if let task = state.auditTaskId { Text(verbatim: "audit-task:\(task) · \(state.auditStatus ?? -1)").font(.caption) }
                    Text("modInstallation.templateEdit.auditStatus", tableName: "ModInstallation").font(.caption)
                }
            }
            if let state = editor.state {
                Section {
                    ForEach(ModInstallationTemplateEditCommand.editable, id: \.self) { key in
                        TextField(text: .init(get: { editor.draft[key] ?? "" }, set: { editor.setText(key, value: $0) }), axis: .vertical) { Text(LocalizedStringKey("modInstallation.field." + key), tableName: "ModInstallation") }
                    }
                }.disabled(!editor.canEdit)
                if let advanced = state.advancedConfigJson, !advanced.isEmpty {
                    Section {
                        Text("modInstallation.templateEdit.graphReadOnly", tableName: "ModInstallation")
                        Text(verbatim: advanced).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                Section {
                    Text(rehearsalText("savedOnly")).font(.caption)
                    if editor.hasChanges { Text(rehearsalText("unsavedPreserved")).font(.caption) }
                    Button { readSavedRehearsal() } label: { Text(rehearsalText("entry")) }
                        .disabled(!editor.canReadSavedRehearsal || scenePhase != .active)
                        .accessibilityIdentifier("installedRehearsal.entry")
                    if !editor.savedRehearsalReadEnabled || rehearsalUnavailable { Text(rehearsalText("unavailable")).font(.caption) }
                }
                Section {
                    Button { prepare("SAVE") } label: { Text("modInstallation.templateEdit.save", tableName: "ModInstallation") }.disabled(!editor.canEdit || !editor.hasChanges)
                    Button { prepare("CONFIRM_FACTS") } label: { Text("modInstallation.templateEdit.facts", tableName: "ModInstallation") }.disabled(!editor.canConfirmFacts)
                    Button { prepare("REVIEW") } label: { Text("modInstallation.templateEdit.submit", tableName: "ModInstallation") }.disabled(!editor.canSubmitReview)
                    Text("modInstallation.templateEdit.reviewBoundary", tableName: "ModInstallation").font(.caption)
                }
                DisclosureGroup { Text(verbatim: state.snapshotJson).font(.caption.monospaced()).textSelection(.enabled) } label: { Text("modInstallation.templateEdit.fullSnapshot", tableName: "ModInstallation") }
            }
            Section {
                if let pending = editor.pending {
                    Text(verbatim: pending.command.action + " · " + pending.command.editRequestId).font(.caption.monospaced())
                    if let receipt = pending.receipt {
                        Text("modInstallation.templateEdit.received", tableName: "ModInstallation")
                        Text(verbatim: receipt.resultDraftHash).font(.caption.monospaced()).textSelection(.enabled)
                        if let task = receipt.auditTaskId { Text(verbatim: "audit-task:\(task)") }
                    } else { Text("modInstallation.templateEdit.unknown", tableName: "ModInstallation") }
                }
                if editor.retryOriginalAvailable {
                    Button { Task { await editor.retryOriginal() } } label: { Text("modInstallation.retryOriginal", tableName: "ModInstallation") }.disabled(editor.busy || !editor.isCurrent)
                }
                if let key = editor.messageKey { Text(LocalizedStringKey("modInstallation." + key), tableName: "ModInstallation") }
                if editor.busy { ProgressView() }
                Button { Task { await editor.open() } } label: { Text("modInstallation.recover", tableName: "ModInstallation") }.disabled(editor.busy || !editor.isCurrent)
            }
        }
        .navigationTitle(Text("modInstallation.templateEdit.title", tableName: "ModInstallation"))
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("modInstallation.back", tableName: "ModInstallation") } } }
        .task { if editor.state == nil { await editor.open() } }
        .sheet(item: $rehearsal, onDismiss: { editor.invalidateSavedRehearsal() }) { visit in
            ModInstallationSavedRehearsalView(rehearsal: visit)
        }
        .sheet(item: $review) { original in
            NavigationStack {
                Form {
                    Text("modInstallation.templateEdit.scope", tableName: "ModInstallation")
                    Text(verbatim: original.command.action + " · #" + String(original.installation.draftId ?? 0))
                    Text(verbatim: original.command.expectedDraftHash).font(.caption.monospaced())
                    ForEach(original.installation.bindings) { binding in
                        Text(verbatim: binding.kind.rawValue + " · " + binding.label + " (#\(binding.resourceId))")
                        Text(verbatim: binding.fingerprint).font(.caption.monospaced())
                    }
                    // Owner sees the complete current audit snapshot before factual confirmation or review submission.
                    Text(verbatim: original.reviewedSnapshotJson).font(.caption.monospaced()).textSelection(.enabled)
                    ForEach(original.command.fields.keys.sorted(), id: \.self) { key in
                        Text(LocalizedStringKey("modInstallation.field." + key), tableName: "ModInstallation").font(.headline)
                        Text(verbatim: original.command.fields[key] ?? "").textSelection(.enabled)
                    }
                    Text("modInstallation.templateEdit.reviewBoundary", tableName: "ModInstallation")
                    Button { review = nil; Task { await editor.confirm(original) } } label: { Text("modInstallation.templateEdit.confirm", tableName: "ModInstallation") }
                        .disabled(!editor.canEdit || editor.review != original)
                }.toolbar { ToolbarItem(placement: .cancellationAction) { Button { editor.cancelReview(); review = nil } label: { Text("modInstallation.back", tableName: "ModInstallation") } } }
            }
        }
    }
    private func prepare(_ action: String) { retireRehearsal(); editor.prepare(action); review = editor.review }
    private func retireRehearsal() {
        rehearsalReadGeneration = UUID(); editor.invalidateSavedRehearsal()
        rehearsal?.retire(); rehearsal = nil
    }
    private func readSavedRehearsal() {
        guard scenePhase == .active, editor.canReadSavedRehearsal else { return }
        retireRehearsal(); rehearsalUnavailable = false; let ticket = rehearsalReadGeneration
        Task {
            do {
                let visit = try await editor.readSavedRehearsal()
                guard scenePhase == .active, rehearsalReadGeneration == ticket else { visit.retire(); return }
                rehearsal = visit
            } catch {
                guard scenePhase == .active, rehearsalReadGeneration == ticket else { return }
                rehearsalUnavailable = true
            }
        }
    }
}
