import SwiftUI

@MainActor struct ModInstallationQaEditorView: View {
    @State var editor: ModInstallationQaEditor
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var review: ModInstallationQaEditPending?
    var body: some View {
        Group {
            if editor.isCurrent { content }
            else { Text("modInstallation.qaEdit.unavailable", tableName: "ModInstallation") }
        }.onChange(of: session.sessionRevision) { _, _ in review = nil; editor.cancelReview() }
    }
    private var content: some View {
        Form {
            CYHeroHeader("modInstallation.qaEdit.title", tableName: "ModInstallation")
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            Section {
                Text("modInstallation.graph.qaBoundary", tableName: "ModInstallation")
                Text("modInstallation.qaEdit.scope", tableName: "ModInstallation").font(.caption)
                if let state = editor.state { Text(verbatim: state.locale + " · #" + String(state.topicId)).font(.caption) }
            }
            if let state = editor.state {
                Section {
                    ForEach(state.nodes) { node in
                        Button { editor.select(node) } label: {
                            Text(verbatim: node.sourceNodeId + " · " + node.title + (node.id == editor.node?.id ? " ✓" : ""))
                        }.disabled(!editor.canEdit)
                    }
                }
            }
            if let node = editor.node {
                Section {
                    Text(verbatim: node.sourceNodeId + " · #" + String(node.templateId)).font(.caption)
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
                            Text(verbatim: option.correct ? "✓ " : "○ ") + Text("modInstallation.graph.qaAnswer", tableName: "ModInstallation")
                        }
                    }
                }.disabled(!editor.canEdit)
                Section {
                    Button {
                        editor.prepareReview(); review = editor.review
                    } label: { Text("modInstallation.qaEdit.review", tableName: "ModInstallation") }.disabled(!editor.canEdit)
                }
            }
            Section {
                if let pending = editor.pending {
                    Text(verbatim: pending.command.editRequestId).font(.caption.monospaced())
                    if let receipt = pending.receipt {
                        Text("modInstallation.qaEdit.saved", tableName: "ModInstallation")
                        Text(verbatim: receipt.resultDraftHash).font(.caption.monospaced()).textSelection(.enabled)
                    } else { Text("modInstallation.qaEdit.unknown", tableName: "ModInstallation") }
                }
                if editor.retryOriginalAvailable {
                    Button { Task { await editor.retryOriginal() } } label: { Text("modInstallation.retryOriginal", tableName: "ModInstallation") }
                        .disabled(editor.busy || !editor.isCurrent)
                }
                if let key = editor.messageKey { Text(LocalizedStringKey("modInstallation." + key), tableName: "ModInstallation") }
                if editor.busy { CYSkeleton() }
                Button { Task { await editor.open() } } label: { Text("modInstallation.recover", tableName: "ModInstallation") }.disabled(editor.busy || !editor.isCurrent)
            }
        }
        .cyHeroScreen()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("modInstallation.back", tableName: "ModInstallation") } } }
        .task { await editor.open() }
        .sheet(item: $review) { original in
            NavigationStack {
                Form {
                    Text("modInstallation.qaEdit.scope", tableName: "ModInstallation")
                    Text(verbatim: original.command.sourceNodeId + " · #" + String(original.templateId))
                    Text(verbatim: original.command.expectedDraftHash).font(.caption.monospaced())
                    // The complete reviewed request is plain owner-only text, including every answer and optional setting.
                    Text(verbatim: original.command.configJSON).font(.caption.monospaced()).textSelection(.enabled)
                    Button {
                        review = nil; Task { await editor.confirm(original) }
                    } label: { Text("modInstallation.qaEdit.confirm", tableName: "ModInstallation") }
                        .disabled(!editor.canEdit || editor.review != original)
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button { editor.cancelReview(); review = nil } label: { Text("modInstallation.back", tableName: "ModInstallation") } } }
            }
        }
    }
    private func text(_ key: String, option: Int? = nil) -> Binding<String> {
        .init(get: { editor.text(key, option: option) }, set: { editor.setText(key, value: $0, option: option) })
    }
}
