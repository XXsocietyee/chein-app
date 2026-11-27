import SwiftUI

@MainActor struct ModInstallationQaEditorView: View {
    @State var editor: ModInstallationQaEditor
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var review: ModInstallationQaEditPending?
    var body: some View {
        Form {
            Section {
                CYHeroHeader("modInstallation.qaEdit.title", tableName: "ModInstallation")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if editor.isCurrent { editorSections }
            else {
                CYEmptyState(
                    systemImage: "questionmark.bubble",
                    "modInstallation.qaEdit.unavailable",
                    tableName: "ModInstallation",
                    kind: .failure
                )
            }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
        .onChange(of: session.sessionRevision) { _, _ in review = nil; editor.cancelReview() }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("modInstallation.back", tableName: "ModInstallation") } } }
        .task { await editor.open() }
        .cySheet(item: $review) { original in
            Group {
                NavigationStack { reviewSheet(original) }
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder private var editorSections: some View {
        Section {
            Text("modInstallation.graph.qaBoundary", tableName: "ModInstallation")
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("modInstallation.qaEdit.scope", tableName: "ModInstallation")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let state = editor.state {
                Text(verbatim: state.locale + " · #" + String(state.topicId))
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if let state = editor.state {
            Section {
                ForEach(state.nodes) { node in
                    Button { editor.select(node) } label: {
                        CYListRow(
                            verbatim: node.title,
                            meta: node.sourceNodeId,
                            trailing: node.id == editor.node?.id ? .value("✓") : .chevron
                        ) {
                            CYRowIcon(systemImage: "questionmark.bubble")
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!editor.canEdit)
                    .accessibilityLabel(Text(verbatim: node.sourceNodeId + " · " + node.title + (node.id == editor.node?.id ? " ✓" : "")))
                    .accessibilityAddTraits(node.id == editor.node?.id ? .isSelected : [])
                }
            }
        }
        if let node = editor.node {
            Section {
                Text(verbatim: node.sourceNodeId + " · #" + String(node.templateId))
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                TextField(text: text("title"), axis: .vertical) { Text("modInstallation.qaEdit.question", tableName: "ModInstallation") }
                TextField(text: text("lead"), axis: .vertical) { Text("modInstallation.qaEdit.lead", tableName: "ModInstallation") }
                Toggle(isOn: .init(get: { editor.answerSelection.isMultiple }, set: { editor.answer(.setMultiple($0)) })) {
                    Text("modInstallation.graph.qaMulti", tableName: "ModInstallation")
                }
                Stepper(value: .init(get: { editor.maxTries }, set: { editor.setMaxTries($0) }), in: 0...10) {
                    Text("modInstallation.graph.qaAttempts", tableName: "ModInstallation") + Text(verbatim: " · \(editor.maxTries)")
                }
                ForEach(editor.answerSelection.options) { option in
                    TextField(text: text("label", option: option.ordinal), axis: .vertical) { Text("modInstallation.qaEdit.option", tableName: "ModInstallation") }
                    TextField(text: text("fb", option: option.ordinal), axis: .vertical) { Text("modInstallation.qaEdit.feedback", tableName: "ModInstallation") }
                    Button { editor.answer(.chooseID(option.id)) } label: {
                        HStack(spacing: CYSpacing.sm) {
                            Text(verbatim: option.correct ? "✓ " : "○ ") + Text("modInstallation.graph.qaAnswer", tableName: "ModInstallation")
                            Spacer(minLength: CYSpacing.sm)
                        }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option.correct ? .isSelected : [])
                }
            }
            .disabled(!editor.canEdit)
            Section {
                CYPillButton("modInstallation.qaEdit.review", tableName: "ModInstallation") {
                    editor.prepareReview(); review = editor.review
                }
                .disabled(!editor.canEdit)
                .listRowBackground(Color.clear)
            }
        }
        Section {
            if let pending = editor.pending {
                Text(verbatim: pending.command.editRequestId.isEmpty ? "—" : pending.command.editRequestId)
                    .cyText(.meta).monospaced()
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let receipt = pending.receipt {
                    Text("modInstallation.qaEdit.saved", tableName: "ModInstallation")
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                    Text(verbatim: receipt.resultDraftHash.isEmpty ? "—" : receipt.resultDraftHash)
                        .cyText(.meta).monospaced()
                        .foregroundStyle(CYColor.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else { Text("modInstallation.qaEdit.unknown", tableName: "ModInstallation") }
            }
            if editor.retryOriginalAvailable {
                CYPillButton("modInstallation.retryOriginal", style: .secondary, tableName: "ModInstallation") { Task { await editor.retryOriginal() } }
                    .disabled(editor.busy || !editor.isCurrent)
                    .listRowBackground(Color.clear)
            }
            if let key = editor.messageKey {
                Text(LocalizedStringKey("modInstallation." + key), tableName: "ModInstallation")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if editor.busy { CYSkeleton(label: "uiCloud24.qa.loading") }
            CYPillButton("modInstallation.recover", style: .secondary, tableName: "ModInstallation") { Task { await editor.open() } }
                .disabled(editor.busy || !editor.isCurrent)
                .listRowBackground(Color.clear)
        }
    }

    private func reviewSheet(_ original: ModInstallationQaEditPending) -> some View {
        Form {
            Section {
                CYHeroHeader("modInstallation.qaEdit.review", tableName: "ModInstallation")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                Text("modInstallation.qaEdit.scope", tableName: "ModInstallation")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: original.command.sourceNodeId + " · #" + String(original.templateId))
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: original.command.expectedDraftHash.isEmpty ? "—" : original.command.expectedDraftHash)
                    .cyText(.meta).monospaced()
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // The complete reviewed request is plain owner-only text, including every answer and optional setting.
                Text(verbatim: original.command.configJSON.isEmpty ? "—" : original.command.configJSON)
                    .cyText(.meta).monospaced()
                    .foregroundStyle(CYColor.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                CYPillButton("modInstallation.qaEdit.confirm", tableName: "ModInstallation") {
                    review = nil; Task { await editor.confirm(original) }
                }
                .disabled(!editor.canEdit || editor.review != original)
                .listRowBackground(Color.clear)
            }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button { editor.cancelReview(); review = nil } label: { Text("modInstallation.back", tableName: "ModInstallation") } } }
    }

    private func text(_ key: String, option: Int? = nil) -> Binding<String> {
        .init(get: { editor.text(key, option: option) }, set: { editor.setText(key, value: $0, option: option) })
    }
}
