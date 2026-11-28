import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - MP pages/publish/fabu/index.wxml:1959-2000 (carryPicker sheet stacked on 初始状态)
// pages/publish/fabu/theme-initial-carry.js openCarryPicker / onCarryQuery / onCarryToggle / onCarryCreateOpen /
// onCarryKind / createCarryKey / confirmCarryPicker (搜索 + 多选主题已有的线索 / 标签，第一行就地新建)

/// 开局带着 → 添加: the topic's clue / tag keys (`api/topic/state-keys`, the same rows 线索与物品 lists), searchable,
/// multi-select; the first row creates a new key in place and selects it. 添加 hands the picks to the 初始状态 buffer;
/// nothing is saved until 完成 on that sheet (MP: the picker only edits `initialStateEditor.rules.attributes`).
@MainActor struct ProjectInitialStateCarryPicker: View {
    @StateObject private var store: ProjectEditTopicKeysStore
    let taken: Set<String>
    let confirm: ([(key: String, label: String)]) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected: Set<String> = []
    @State private var creating = false
    @State private var newKind: ProjectEditTopicKeys.Kind = .clue
    @State private var newName = ""
    @State private var issue: ProjectEditTopicKeys.NameIssue?
    @State private var tooMany = false

    init(store: @escaping () -> ProjectEditTopicKeysStore, taken: Set<String>,
         confirm: @escaping ([(key: String, label: String)]) -> Bool) {
        _store = StateObject(wrappedValue: store())
        self.taken = taken
        self.confirm = confirm
    }

    private static let kinds: [ProjectEditTopicKeys.Kind] = [.clue, .tag]

    var body: some View {
        NavigationStack {
            List {
                createSection
                if store.state == .loading {
                    Section {
                        ProgressView { Text("cy.state.loading") }
                            .frame(maxWidth: .infinity)
                    }
                } else if store.state == .failed {
                    Section {
                        Label { Text("projectInitialState.picker.loadFailed", tableName: "ProjectInitialState") } icon: {
                            Image(systemName: "exclamationmark.circle")
                        }
                        .foregroundStyle(CYColor.dangerText)
                        Button { Task { await store.load() } } label: { Text("action.retry") }
                            .buttonStyle(.borderless)
                    }
                }
                ForEach(Self.kinds) { kind in
                    let rows = filtered(kind)
                    if !rows.isEmpty {
                        Section {
                            ForEach(rows, id: \.id) { row in
                                keyRow(row)
                            }
                        } header: {
                            Text(LocalizedStringKey(kind.labelKey))
                        }
                    }
                }
                if tooMany {
                    Section {
                        Text("projectInitialState.picker.tooMany \(ProjectInitialState.maxAttributeRows)", tableName: "ProjectInitialState")
                            .foregroundStyle(CYColor.dangerText)
                    }
                }
                if let errorKey = store.errorKey {
                    Section {
                        Text(LocalizedStringKey(errorKey))
                            .foregroundStyle(CYColor.dangerText)
                    }
                }
            }
            .searchable(text: $query, prompt: Text("projectInitialState.picker.search", tableName: "ProjectInitialState"))
            .onChange(of: query) { _, value in
                newName = value
                issue = nil
                tooMany = false
            }
            .navigationTitle(Text("projectInitialState.picker.title", tableName: "ProjectInitialState"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("projectInitialState.picker.back", tableName: "ProjectInitialState") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { add() } label: { Text("projectInitialState.add", tableName: "ProjectInitialState") }
                        .disabled(selected.isEmpty)
                        .accessibilityLabel(Text("projectInitialState.picker.addSelected", tableName: "ProjectInitialState"))
                        .accessibilityIdentifier("projectInitialState.picker.confirm")
                }
            }
            .task { await store.load() }
        }
    }

    /// MP first row: 新建… / 新建「query」, then 线索 | 标签 and 名称 · 新建.
    @ViewBuilder private var createSection: some View {
        Section {
            Button {
                creating.toggle()
                newName = query
                issue = nil
            } label: {
                Label {
                    if query.isEmpty {
                        Text("projectInitialState.picker.new", tableName: "ProjectInitialState")
                    } else {
                        Text("projectInitialState.picker.newNamed \(query)", tableName: "ProjectInitialState")
                    }
                } icon: {
                    Image(systemName: "plus")
                }
            }
            .accessibilityIdentifier("projectInitialState.picker.new")
            if creating {
                Picker(selection: $newKind) {
                    Text("projectInitialState.kind.clue", tableName: "ProjectInitialState").tag(ProjectEditTopicKeys.Kind.clue)
                    Text("projectInitialState.kind.tag", tableName: "ProjectInitialState").tag(ProjectEditTopicKeys.Kind.tag)
                } label: {
                    Text("projectInitialState.picker.kind", tableName: "ProjectInitialState")
                }
                .cyAdaptiveSegmented()
                .onChange(of: newKind) { _, _ in issue = nil }
                HStack {
                    TextField(text: $newName) { Text("mpPublish.keys.name") }
                        .submitLabel(.done)
                        .onSubmit { Task { await create() } }
                    Button { Task { await create() } } label: {
                        Text("projectInitialState.picker.create", tableName: "ProjectInitialState")
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .disabled(trimmedName.isEmpty || store.saving)
                }
                if let issue {
                    Text(issueText(issue))
                        .font(.footnote)
                        .foregroundStyle(CYColor.dangerText)
                }
            }
        }
    }

    private func keyRow(_ row: TopicStateKeyRow) -> some View {
        let added = taken.contains(row.id)
        let on = selected.contains(row.id)
        return Button { toggle(row.id) } label: {
            LabeledContent {
                if added {
                    Text("projectInitialState.added", tableName: "ProjectInitialState")
                } else if on {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            } label: {
                Text(verbatim: row.label)
            }
        }
        .disabled(added)
        .accessibilityAddTraits(on || added ? .isSelected : [])
        .accessibilityIdentifier("projectInitialState.picker.row." + row.id)
    }

    private var trimmedName: String { newName.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// MP `_carryGroups`: named clue / tag keys whose name contains the query.
    private func filtered(_ kind: ProjectEditTopicKeys.Kind) -> [TopicStateKeyRow] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.rows(kind).filter { !$0.label.isEmpty && (q.isEmpty || $0.label.contains(q)) }
    }

    private func toggle(_ key: String) {
        guard !taken.contains(key) else { return }
        if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
        tooMany = false
    }

    /// MP `createCarryKey`: same-kind name checks, the server names the key, the new key comes back selected.
    private func create() async {
        let name = trimmedName
        guard !name.isEmpty, !store.saving else { return }
        let kind = newKind
        if let found = ProjectEditTopicKeys.nameIssue(name, taken: store.rows(kind).map { $0.label }, kind: kind) {
            issue = found
            return
        }
        let before = Set(store.rows(kind).map { $0.id })
        guard await store.create(kind, name: name) else { return }
        let fresh = store.rows(kind).filter { !before.contains($0.id) }
        if let row = fresh.first(where: { $0.label == name }) ?? fresh.first { selected.insert(row.id) }
        creating = false
        query = ""
        newName = ""
    }

    /// MP `confirmCarryPicker`: hands the picks over; past 32 rows the MP says 最多 32 项 and keeps the picker open.
    private func add() {
        guard !selected.isEmpty else { return }
        let picks: [(key: String, label: String)] = store.keys
            .filter { selected.contains($0.id) && !taken.contains($0.id) }
            .map { (key: $0.id, label: $0.label) }
        if confirm(picks) { dismiss() } else { tooMany = true }
    }

    private func issueText(_ issue: ProjectEditTopicKeys.NameIssue) -> LocalizedStringKey {
        switch issue {
        case .tooLong: return "mpPublish.keys.tooLong"
        case .taken(let kind): return LocalizedStringKey("mpPublish.keys.taken." + kind.rawValue)
        }
    }
}
