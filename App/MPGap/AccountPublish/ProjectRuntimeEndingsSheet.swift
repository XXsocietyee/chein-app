import SwiftUI

// MARK: - MP pages/publish/fabu/runtime-structure-editor.wxml kind 'endings' (运行结局)
// theme-runtime-structure.js addStructureEnding / onStructureEnding / chooseStructureFallbackEnding /
// removeStructureEnding / saveStructure; opened only from the publish check (_locateStructureIssue('endings')).

/// Presents the 运行结局 sheet when the 发布前需要修改 row for `runtimeEndings` is tapped (MP `locatePublishIssue`).
struct ProjectRuntimeEndingsHost: ViewModifier {
    @ObservedObject var model: ProjectEditModel
    @Binding var isPresented: Bool
    let rootRequestID: UUID?
    let rootAnchor: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: rootRequestID) { _, _ in
                guard rootAnchor == ProjectEditRuntimeEndings.anchor else { return }
                isPresented = true
            }
            .sheet(isPresented: $isPresented) {
                ProjectRuntimeEndingsSheet(model: model)
                    .cySheet(detents: [.large])
            }
    }
}

/// MP layer: 退出 / 运行结局 / 完成; the lead line, one card per ending (结局 N · 默认收尾 tag · 删除,
/// 名称, 结局说明, 设为默认收尾), then 添加结局. Edits are staged; 完成 validates and writes, 退出 drops them.
@MainActor struct ProjectRuntimeEndingsSheet: View {
    @ObservedObject var model: ProjectEditModel
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [ProjectEditRuntimeEndings.Row] = []
    @State private var loaded = false
    @State private var errorKey: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("projectRuntimeEndings.lead")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let errorKey {
                        Label(LocalizedStringKey(errorKey), systemImage: "exclamationmark.circle")
                            .foregroundStyle(CYColor.dangerText)
                            .accessibilityIdentifier("projectRuntimeEndings.error")
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    endingSection(index: index, row: row)
                }
                Section {
                    Button {
                        add()
                    } label: {
                        Label("projectRuntimeEndings.add", systemImage: "plus")
                    }
                    .disabled(!model.fullEdit)
                    .accessibilityIdentifier("projectRuntimeEndings.add")
                }
            }
            .sensoryFeedback(.selection, trigger: rows.first(where: { $0.fallback })?.id)
            .navigationTitle(Text("projectRuntimeEndings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("projectRuntimeEndings.exit") { dismiss() }
                        .accessibilityIdentifier("projectRuntimeEndings.exit")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("projectRuntimeEndings.done") { save() }
                        .disabled(!model.fullEdit)
                        .accessibilityIdentifier("projectRuntimeEndings.done")
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            rows = ProjectEditRuntimeEndings.rows(in: model.draft)
        }
    }

    private func endingSection(index: Int, row: ProjectEditRuntimeEndings.Row) -> some View {
        Section {
            TextField(text: titleBinding(index), prompt: Text("projectRuntimeEndings.name.placeholder")) {
                Text("projectRuntimeEndings.name")
            }
            .accessibilityIdentifier("projectRuntimeEndings.name.\(row.id)")
            TextField(text: summaryBinding(index), prompt: Text("projectRuntimeEndings.summary.placeholder"), axis: .vertical) {
                Text("projectRuntimeEndings.summary")
            }
            .lineLimit(2...6)
            .accessibilityIdentifier("projectRuntimeEndings.summary.\(row.id)")
            Button {
                rows = ProjectEditRuntimeEndings.choosingFallback(index, in: rows)
                errorKey = nil
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("projectRuntimeEndings.fallback").foregroundStyle(.primary)
                        Text("projectRuntimeEndings.fallback.detail")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if row.fallback {
                        Image(systemName: "checkmark").foregroundStyle(CYColor.brand)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!model.fullEdit)
            .accessibilityAddTraits(row.fallback ? .isSelected : [])
            .accessibilityIdentifier("projectRuntimeEndings.fallback.\(row.id)")
            Button(role: .destructive) {
                remove(index)
            } label: {
                Text("projectRuntimeEndings.delete")
            }
            .disabled(!model.fullEdit)
            .accessibilityLabel(Text("projectRuntimeEndings.delete.a11y \(index + 1)"))
            .accessibilityIdentifier("projectRuntimeEndings.delete.\(row.id)")
        } header: {
            HStack(spacing: 8) {
                Text("projectRuntimeEndings.ending \(index + 1)")
                if row.fallback {
                    Text("projectRuntimeEndings.fallback.tag")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CYColor.brand)
                }
            }
        }
    }

    private func titleBinding(_ index: Int) -> Binding<String> {
        Binding {
            rows.indices.contains(index) ? rows[index].title : ""
        } set: { value in
            guard rows.indices.contains(index) else { return }
            rows[index].title = Self.clamped(value, ProjectEditRuntimeEndings.titleLimit)
            errorKey = nil
        }
    }

    private func summaryBinding(_ index: Int) -> Binding<String> {
        Binding {
            rows.indices.contains(index) ? rows[index].summary : ""
        } set: { value in
            guard rows.indices.contains(index) else { return }
            rows[index].summary = Self.clamped(value, ProjectEditRuntimeEndings.summaryLimit)
            errorKey = nil
        }
    }

    /// MP `maxlength` counts UTF-16 units, like the server check.
    private static func clamped(_ value: String, _ limit: Int) -> String {
        guard value.utf16.count > limit else { return value }
        var result = ""
        for character in value {
            if result.utf16.count + String(character).utf16.count > limit { break }
            result.append(character)
        }
        return result
    }

    private func add() {
        do {
            rows = try ProjectEditRuntimeEndings.adding(to: rows)
            errorKey = nil
        } catch ProjectEditRuntimeActsError.refused(let key) {
            errorKey = key
        } catch {
            errorKey = ProjectEditRuntimeEndings.Copy.unreadable
        }
    }

    private func remove(_ index: Int) {
        do {
            rows = try ProjectEditRuntimeEndings.removing(index, from: rows, in: model.draft)
            errorKey = nil
        } catch ProjectEditRuntimeActsError.refused(let key) {
            errorKey = key
        } catch {
            errorKey = ProjectEditRuntimeEndings.Copy.unreadable
        }
    }

    private func save() {
        do {
            model.draft = try ProjectEditRuntimeEndings.save(rows, into: model.draft)
            errorKey = nil
            dismiss()
        } catch ProjectEditRuntimeActsError.refused(let key) {
            errorKey = key
        } catch {
            errorKey = ProjectEditRuntimeEndings.Copy.unreadable
        }
    }
}
