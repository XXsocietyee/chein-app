import SwiftUI

// MARK: - MP pages/publish/fabu/runtime-structure-editor.wxml:35-52 (kind 'endings', 运行结局)
// theme-runtime-structure.js addStructureEnding / onStructureEnding / chooseStructureFallbackEnding /
// removeStructureEnding / saveStructure; opened by locatePublishIssue → _locateStructureIssue('endings')

enum ProjectRunEndingsCopy {
    static let table = "ProjectRunEndings"

    /// Keys of this table, or the shared editor keys (unreadable config) in Localizable.
    static func text(_ key: String) -> Text {
        if key.hasPrefix("projectRunEndings.") { return Text(LocalizedStringKey(key), tableName: table) }
        return Text(LocalizedStringKey(key))
    }
}

/// 玩法规则 row shown only while the MP publish check would stop on 运行结局 (the MP's locator row);
/// it opens the editor sheet, like 去修改 in the MP publish check.
@MainActor struct ProjectEditRunEndingsIssueRow: View {
    let issueKey: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text("projectRunEndings.title", tableName: ProjectRunEndingsCopy.table)
                    } icon: {
                        Image(systemName: "flag.checkered")
                    }
                    ProjectRunEndingsCopy.text(issueKey)
                        .font(.footnote)
                        .foregroundStyle(CYColor.dangerText)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("projectRunEndings.open.hint", tableName: ProjectRunEndingsCopy.table))
        .accessibilityIdentifier("projectEdit.rules.endings")
    }
}

/// MP endings layer: 退出 / 完成 → title 运行结局 → error line → lead → one card per 结局
/// (结局 N · 默认收尾 tag · 删除 / 名称 / 结局说明 / 设为默认收尾) → 添加结局.
/// Native: a stacked sheet with 取消 / 完成; 完成 runs the MP checks and keeps the sheet open on a problem.
@MainActor struct ProjectEditRunEndingsSheet: View {
    @ObservedObject var model: ProjectEditModel
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [ProjectEditRunEndings.Row] = []
    @State private var errorKey: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                if let errorKey {
                    Section {
                        Label {
                            ProjectRunEndingsCopy.text(errorKey)
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                        }
                        .foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("projectEdit.endings.error")
                    }
                }
                Section {
                    Text("projectRunEndings.lead", tableName: ProjectRunEndingsCopy.table)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach($rows) { $row in
                    endingSection($row)
                }
                Section {
                    Button(action: add) {
                        Label {
                            Text("projectRunEndings.add", tableName: ProjectRunEndingsCopy.table)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(rows.count >= ProjectEditRunEndings.limit)
                    .accessibilityIdentifier("projectEdit.endings.add")
                }
            }
            .navigationTitle(Text("projectRunEndings.title", tableName: ProjectRunEndingsCopy.table))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done", action: save)
                        .accessibilityIdentifier("projectEdit.endings.done")
                }
            }
            .onAppear(perform: load)
        }
    }

    private func number(of id: String) -> Int {
        (rows.firstIndex { $0.id == id } ?? 0) + 1
    }

    private func endingSection(_ row: Binding<ProjectEditRunEndings.Row>) -> some View {
        let id = row.wrappedValue.id
        let index = number(of: id)
        let fallback = row.wrappedValue.fallback
        return Section {
            TextField(text: row.title, prompt: Text("projectRunEndings.name.placeholder", tableName: ProjectRunEndingsCopy.table)) {
                Text("projectRunEndings.name", tableName: ProjectRunEndingsCopy.table)
            }
            .accessibilityIdentifier("projectEdit.endings.title." + id)
            TextField(text: row.summary, prompt: Text("projectRunEndings.summary.placeholder", tableName: ProjectRunEndingsCopy.table), axis: .vertical) {
                Text("projectRunEndings.summary", tableName: ProjectRunEndingsCopy.table)
            }
            .lineLimit(3...8)
            .accessibilityIdentifier("projectEdit.endings.summary." + id)
            Button {
                chooseFallback(id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("projectRunEndings.fallback", tableName: ProjectRunEndingsCopy.table)
                            .foregroundStyle(.primary)
                        Text("projectRunEndings.fallback.hint", tableName: ProjectRunEndingsCopy.table)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if fallback {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .accessibilityAddTraits(fallback ? .isSelected : [])
            .accessibilityIdentifier("projectEdit.endings.fallback." + id)
            Button(role: .destructive) {
                remove(id)
            } label: {
                Text("projectRunEndings.delete", tableName: ProjectRunEndingsCopy.table)
            }
            .accessibilityLabel(Text("projectRunEndings.delete.label \(index)", tableName: ProjectRunEndingsCopy.table))
            .accessibilityIdentifier("projectEdit.endings.delete." + id)
        } header: {
            HStack {
                Text("projectRunEndings.ending \(index)", tableName: ProjectRunEndingsCopy.table)
                if fallback {
                    Text("projectRunEndings.fallback.tag", tableName: ProjectRunEndingsCopy.table)
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        rows = ProjectEditRunEndings.rows(in: model.draft)
    }

    private func add() {
        do {
            rows = try ProjectEditRunEndings.adding(to: rows)
            errorKey = nil
        } catch ProjectEditRuntimeActsError.refused(let key) {
            errorKey = key
        } catch {
            errorKey = ProjectEditRunEndings.Copy.unreadable
        }
    }

    private func chooseFallback(_ id: String) {
        rows = ProjectEditRunEndings.choosingFallback(id, in: rows)
        errorKey = nil
    }

    private func remove(_ id: String) {
        do {
            rows = try ProjectEditRunEndings.removing(id, from: rows, in: model.draft)
            errorKey = nil
        } catch ProjectEditRuntimeActsError.refused(let key) {
            errorKey = key
        } catch {
            errorKey = ProjectEditRunEndings.Copy.unreadable
        }
    }

    private func save() {
        do {
            model.draft = try ProjectEditRunEndings.save(rows, in: model.draft)
            dismiss()
        } catch ProjectEditRuntimeActsError.refused(let key) {
            errorKey = key
        } catch {
            errorKey = ProjectEditRunEndings.Copy.unreadable
        }
    }
}
