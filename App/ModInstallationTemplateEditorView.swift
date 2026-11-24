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
    private enum Forward { case save, facts, submit, retry, recover }
    private var forward: Forward {
        if editor.canEdit && editor.hasChanges { return .save }
        if editor.canConfirmFacts { return .facts }
        if editor.canSubmitReview { return .submit }
        if editor.retryOriginalAvailable { return .retry }
        return .recover
    }
    var body: some View {
        Group {
            if editor.isCurrent { content }
            else {
                Cloud25Screen(title: installationString("templateEdit.title", locale: locale), seed: editor.installation.requestId, symbol: "square.and.pencil") {
                    CYEmptyState(systemImage: "lock.slash", "modInstallation.templateEdit.unavailable", tableName: "ModInstallation")
                }
            }
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("modInstallation.back", tableName: "ModInstallation") } } }
        .onChange(of: session.sessionRevision) { _, _ in review = nil; editor.cancelReview(); retireRehearsal() }
        .onChange(of: session.modInstallationApproval?.revision) { _, _ in retireRehearsal() }
        .onChange(of: editor.savedRehearsalReadEnabled) { _, enabled in if !enabled { retireRehearsal() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { retireRehearsal() } }
        .onDisappear { retireRehearsal() }
    }
    private var content: some View {
        Cloud25Screen(title: installationString("templateEdit.title", locale: locale), seed: editor.installation.requestId, symbol: "square.and.pencil") {
            CYInfoCard {
                installationText("templateEdit.scope").cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                CYListRow(verbatim: Cloud25Copy.value(editor.installation.requestId), trailing: .none) {
                    CYRowIcon(systemImage: "number")
                }
                if let state = editor.state {
                    Text(verbatim: "#\(state.templateId) · \(Cloud25Copy.value(state.draftContentHash))")
                        .cyText(.meta).monospaced().foregroundStyle(CYColor.textSecondary)
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if !state.editable {
                        CYNoteBanner(text: installationText("templateEdit.locked"), symbol: "lock", tone: .warning)
                    }
                    if let task = state.auditTaskId {
                        CYListRow(verbatim: "audit-task:\(task)", meta: state.auditStatus.map(String.init) ?? Cloud25Copy.dash, trailing: .none) {
                            CYRowIcon(systemImage: "checkmark.shield")
                        }
                        .accessibilityLabel(installationText("templateEdit.auditStatus") + Text(verbatim: " \(state.auditStatus.map(String.init) ?? Cloud25Copy.dash)"))
                    }
                    CYStatusChip(verbatim: state.auditStatus.map(String.init) ?? Cloud25Copy.dash, tone: .neutral, systemImage: "checkmark.shield")
                        .accessibilityLabel(installationText("templateEdit.auditStatus") + Text(verbatim: " \(state.auditStatus.map(String.init) ?? Cloud25Copy.dash)"))
                    installationText("templateEdit.auditStatus").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                }
            }
            if let state = editor.state {
                CYInfoCard {
                    ForEach(ModInstallationTemplateEditCommand.editable, id: \.self) { key in
                        TextField(text: .init(get: { editor.draft[key] ?? "" }, set: { editor.setText(key, value: $0) }), axis: .vertical) {
                            Text(LocalizedStringKey("modInstallation.field." + key), tableName: "ModInstallation")
                        }
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .padding(CYSpacing.md)
                        .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityLabel(Text(LocalizedStringKey("modInstallation.field." + key), tableName: "ModInstallation"))
                    }
                }
                .disabled(!editor.canEdit)
                if let advanced = state.advancedConfigJson, !advanced.isEmpty {
                    CYInfoCard {
                        CYNoteBanner(text: installationText("templateEdit.graphReadOnly"), symbol: "point.3.connected.trianglepath.dotted", tone: .info)
                        Text(verbatim: advanced).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                }
                CYInfoCard {
                    Text(verbatim: rehearsalText("savedOnly")).cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    if editor.hasChanges {
                        Text(verbatim: rehearsalText("unsavedPreserved")).cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Cloud25Pill(title: rehearsalText("entry"), primary: false, systemImage: "play.circle", enabled: editor.canReadSavedRehearsal && scenePhase == .active) {
                        readSavedRehearsal()
                    }
                    .accessibilityIdentifier("installedRehearsal.entry")
                    if !editor.savedRehearsalReadEnabled || rehearsalUnavailable {
                        CYNoteBanner(text: Text(verbatim: rehearsalText("unavailable")), symbol: "play.slash", tone: .warning)
                    }
                }
                CYInfoCard {
                    Cloud25Pill(title: installationString("templateEdit.save", locale: locale), key: "templateEdit.save", primary: forward == .save, systemImage: "square.and.arrow.down", enabled: editor.canEdit && editor.hasChanges) {
                        prepare("SAVE")
                    }
                    Cloud25Pill(title: installationString("templateEdit.facts", locale: locale), key: "templateEdit.facts", primary: forward == .facts, enabled: editor.canConfirmFacts) {
                        prepare("CONFIRM_FACTS")
                    }
                    Cloud25Pill(title: installationString("templateEdit.submit", locale: locale), key: "templateEdit.submit", primary: forward == .submit, enabled: editor.canSubmitReview) {
                        prepare("REVIEW")
                    }
                    installationText("templateEdit.reviewBoundary").cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                DisclosureGroup {
                    Text(verbatim: state.snapshotJson).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                } label: {
                    installationText("templateEdit.fullSnapshot").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                }
                .frame(minHeight: CYSpacing.minTouchTarget)
            }
            CYInfoCard {
                if let pending = editor.pending {
                    Text(verbatim: pending.command.action + " · " + pending.command.editRequestId)
                        .cyText(.meta).monospaced().foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let receipt = pending.receipt {
                        CYStatusChip(verbatim: installationString("templateEdit.received", locale: locale), tone: .success, systemImage: "checkmark")
                            .accessibilityLabel(installationText("templateEdit.received"))
                        Text(verbatim: receipt.resultDraftHash).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        if let task = receipt.auditTaskId {
                            CYListRow(verbatim: "audit-task:\(task)", trailing: .none) { CYRowIcon(systemImage: "checkmark.shield") }
                        }
                    } else {
                        CYNoteBanner(text: installationText("templateEdit.unknown"), symbol: "questionmark.circle", tone: .warning)
                    }
                }
                if editor.retryOriginalAvailable {
                    Cloud25Pill(title: installationString("retryOriginal", locale: locale), key: "retryOriginal", primary: forward == .retry, enabled: !editor.busy && editor.isCurrent) {
                        Task { await editor.retryOriginal() }
                    }
                }
                if let key = editor.messageKey {
                    CYNoteBanner(text: installationText(key), symbol: "info.circle", tone: .info)
                }
                if editor.busy { CYSkeleton().accessibilityLabel(Text("cy.state.loading")) }
                Cloud25Pill(title: installationString("recover", locale: locale), key: "recover", primary: forward == .recover, enabled: !editor.busy && editor.isCurrent) {
                    Task { await editor.open() }
                }
            }
        }
        .task { if editor.state == nil { await editor.open() } }
        .sheet(item: $rehearsal, onDismiss: { editor.invalidateSavedRehearsal() }) { visit in
            Group {
                ModInstallationSavedRehearsalView(rehearsal: visit)
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $review) { original in
            Group {
                NavigationStack {
                    Cloud25Screen(title: installationString("templateEdit.title", locale: locale), seed: original.command.editRequestId, symbol: "checkmark.seal") {
                        CYInfoCard {
                            installationText("templateEdit.scope").cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: original.command.action + " · #" + (original.installation.draftId.map(String.init) ?? Cloud25Copy.dash))
                                .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: original.command.expectedDraftHash).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            ForEach(original.installation.bindings) { binding in
                                CYListRow(verbatim: binding.kind.rawValue + " · " + binding.label, meta: "#\(binding.resourceId)", trailing: .none) {
                                    CYRowIcon(systemImage: "link")
                                }
                                Text(verbatim: binding.fingerprint).cyText(.meta).monospaced().foregroundStyle(CYColor.textTertiary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            }
                            // Owner sees the complete current audit snapshot before factual confirmation or review submission.
                            Text(verbatim: original.reviewedSnapshotJson).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            ForEach(original.command.fields.keys.sorted(), id: \.self) { key in
                                installationText("field." + key).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                Text(verbatim: original.command.fields[key] ?? "").cyText(.body).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            }
                            installationText("templateEdit.reviewBoundary").cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                            Cloud25Pill(title: installationString("templateEdit.confirm", locale: locale), key: "templateEdit.confirm", primary: true, enabled: editor.canEdit && editor.review == original) {
                                review = nil
                                Task { await editor.confirm(original) }
                            }
                        }
                        // Owner sees the complete current audit snapshot before factual confirmation or review submission.
                        Text(verbatim: original.reviewedSnapshotJson).font(.caption.monospaced()).textSelection(.enabled)
                        ForEach(original.command.fields.keys.sorted(), id: \.self) { key in
                            Text(LocalizedStringKey("modInstallation.field." + key), tableName: "ModInstallation").cyText(.cardTitle).accessibilityAddTraits(.isHeader)
                            Text(verbatim: original.command.fields[key] ?? "").textSelection(.enabled)
                        }
                        Text("modInstallation.templateEdit.reviewBoundary", tableName: "ModInstallation")
                        CYPillButton("modInstallation.templateEdit.confirm", tableName: "ModInstallation") { review = nil; Task { await editor.confirm(original) } }
                            .disabled(!editor.canEdit || editor.review != original).e1ActionRow()
                    }.formStyle(.grouped).cyGroupedSurface().toolbar { ToolbarItem(placement: .cancellationAction) { Button { editor.cancelReview(); review = nil } label: { Text("modInstallation.back", tableName: "ModInstallation") } } }
                }
            }
            .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
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
