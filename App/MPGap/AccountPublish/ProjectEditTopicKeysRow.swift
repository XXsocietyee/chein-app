import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - MP pages/publish/fabu/topic-detail-sheet.wxml:264-268 (线索与物品, last card of the 主题详情 sheet)
// pages/publishkit/components/topic-state-keys/index.{wxml,js} + rules.js (row, sheet, groups 线索 / 物品 / 标签)
// pages/publish/fabu/theme-keys-items.js (物品 = themeRuntimeConfig.items kind ITEM, itemUsedIn, onKeysItemChange)

/// 线索与物品 in the 主题详情 sheet, after 发布到创意广场 (MP order). A saved topic shows the row with
/// `N 项` and opens the sheet; a new draft shows the MP note 保存为主题后…. Signed out / fixtures (no
/// creator service) render nothing for a saved topic, like 可玩时段.
@MainActor struct ProjectEditTopicKeysRow: View {
    @ObservedObject var model: ProjectEditModel
    @Environment(\.topicPlaySetupSource) private var source

    var body: some View {
        if let topicID = model.coordinator.publicationTopicID, topicID > 0 {
            if let source, let service = source.make() {
                ProjectEditTopicKeysLoadedRow(model: model, makeStore: { ProjectEditTopicKeysStore(service: service, topicID: Int64(topicID)) })
                    .id(topicID)
            }
        } else {
            Section {
                Text("mpPublish.keys.saveFirst")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("mpPublish.keys.title")
            }
            .accessibilityIdentifier("projectEdit.topicDetail.keys.saveFirst")
        }
    }
}

/// The clue / tag rows of `api/topic/state-keys`, the MP load / write states, and the remembered
/// 用在 places of a refused delete (MP keeps them until the list read carries them).
@MainActor final class ProjectEditTopicKeysStore: ObservableObject {
    enum LoadState { case loading, ready, failed }
    let service: TopicCreatorEditorService
    let topicID: Int64
    @Published private(set) var state = LoadState.loading
    @Published private(set) var keys: [TopicStateKeyRow] = []
    @Published private(set) var saving = false
    @Published private(set) var deleting: String?
    @Published var errorKey: String?
    @Published var blocked: Blocked?
    private var knownUsedIn: [String: [String]] = [:]

    struct Blocked: Identifiable {
        let id = UUID()
        let name: String
        let places: [String]
    }

    init(service: TopicCreatorEditorService, topicID: Int64) {
        self.service = service
        self.topicID = topicID
    }

    /// MP `normalizeKeys` + `_view`: only `clue.*` and `tag.*` rows are listed here.
    func rows(_ kind: ProjectEditTopicKeys.Kind) -> [TopicStateKeyRow] {
        keys.filter { $0.kind == kind.rawValue }
    }

    func usedIn(_ row: TopicStateKeyRow) -> [String] {
        let listed = row.usedIn
        return listed.isEmpty ? (knownUsedIn[row.id] ?? []) : listed
    }

    func load() async {
        if keys.isEmpty { state = .loading }
        do {
            keys = try await service.stateKeys(topicID: topicID)
            state = .ready
        } catch {
            state = .failed
        }
    }

    /// MP `onSave` for 线索 / 标签: the server names the key; the list is read again.
    func create(_ kind: ProjectEditTopicKeys.Kind, name: String) async -> Bool {
        guard !saving else { return false }
        saving = true
        errorKey = nil
        defer { saving = false }
        do {
            _ = try await service.createNamedStateKey(topicID: topicID, kind: kind.rawValue, label: name)
            await load()
            return true
        } catch {
            errorKey = "mpPublish.keys.saveFailed"
            return false
        }
    }

    /// MP `onRename`: PUT the row with only the label replaced.
    func rename(_ row: TopicStateKeyRow, to name: String) async -> Bool {
        guard !saving else { return false }
        saving = true
        errorKey = nil
        defer { saving = false }
        do {
            try await service.renameStateKey(topicID: topicID, row: row, label: name)
            await load()
            return true
        } catch {
            errorKey = "mpPublish.keys.saveFailed"
            return false
        }
    }

    /// MP `onConfirmDelete`: a refusal that names places marks the row as used and explains where.
    func delete(_ row: TopicStateKeyRow, name: String) async {
        guard deleting == nil else { return }
        deleting = row.id
        errorKey = nil
        defer { deleting = nil }
        do {
            try await service.deleteStateKey(topicID: topicID, key: row.id)
            await load()
        } catch TopicCreatorEditorIssue.rejected(let message) {
            let places = ProjectEditTopicKeys.usedIn(fromRefusal: message)
            if places.isEmpty {
                errorKey = "mpPublish.keys.deleteFailed"
            } else {
                knownUsedIn[row.id] = places
                objectWillChange.send()
                blocked = Blocked(name: name, places: places)
            }
        } catch TopicCreatorEditorIssue.outcomeUnknown {
            errorKey = "mpPublish.keys.deleteUnknown"
        } catch {
            errorKey = "mpPublish.keys.deleteFailed"
        }
    }
}

@MainActor private struct ProjectEditTopicKeysLoadedRow: View {
    @ObservedObject var model: ProjectEditModel
    @StateObject private var store: ProjectEditTopicKeysStore
    @State private var open = false

    init(model: ProjectEditModel, makeStore: @escaping () -> ProjectEditTopicKeysStore) {
        self.model = model
        _store = StateObject(wrappedValue: makeStore())
    }

    private var total: Int {
        store.rows(.clue).count + store.rows(.tag).count + ProjectEditTopicKeys.items(in: model.draft).count
    }

    var body: some View {
        Section {
            Button {
                open = true
            } label: {
                LabeledContent {
                    if store.state == .loading {
                        ProgressView()
                    } else {
                        Text("mpPublish.keys.count \(total)")
                    }
                } label: {
                    Label("mpPublish.keys.title", systemImage: "key")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("projectEdit.topicDetail.keys")
        }
        .task { await store.load() }
        .sheet(isPresented: $open) {
            ProjectEditTopicKeysSheet(model: model, store: store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// MP `topic-state-keys` sheet: 线索 → 物品 → 标签, each row opens 名称 · 用在 · 删除, each group ends
/// with 添加…; the read failure line retries; a read-only topic says so. 完成 saves a pending name first.
@MainActor private struct ProjectEditTopicKeysSheet: View {
    @ObservedObject var model: ProjectEditModel
    @ObservedObject var store: ProjectEditTopicKeysStore
    @Environment(\.dismiss) private var dismiss
    @State private var expanded: String?
    @State private var editName = ""
    @State private var adding: ProjectEditTopicKeys.Kind?
    @State private var addName = ""
    @State private var issueKind: ProjectEditTopicKeys.Kind?
    @State private var issue: ProjectEditTopicKeys.NameIssue?
    @State private var confirmDelete: PendingDelete?
    @FocusState private var addFocused: Bool

    private struct PendingDelete: Identifiable {
        let id: String
        let name: String
        let kind: ProjectEditTopicKeys.Kind
    }

    private struct Row: Identifiable {
        let id: String
        let name: String
        let usedIn: [String]
    }

    private var readOnly: Bool { !model.fullEdit }

    private func rows(_ kind: ProjectEditTopicKeys.Kind) -> [Row] {
        let fallback = String(localized: String.LocalizationValue(kind.labelKey))
        if kind == .item {
            return ProjectEditTopicKeys.items(in: model.draft).map { item in
                Row(id: "item:" + item.id, name: item.name.isEmpty ? fallback : item.name, usedIn: item.usedIn.map(placeText))
            }
        }
        return store.rows(kind).map { row in
            Row(id: row.id, name: row.label.isEmpty ? fallback : row.label, usedIn: store.usedIn(row))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.state == .loading {
                    Section {
                        ProgressView { Text("cy.state.loading") }
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(ProjectEditTopicKeys.Kind.allCases) { kind in
                        group(kind)
                    }
                }
                if store.state == .failed {
                    Section {
                        Label("mpPublish.keys.loadFailed", systemImage: "exclamationmark.circle")
                            .foregroundStyle(CYColor.dangerText)
                        Button("action.retry") { Task { await store.load() } }
                            .buttonStyle(.borderless)
                    }
                } else if readOnly {
                    Section {
                        Text("mpPublish.keys.readOnly")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let errorKey = store.errorKey {
                    Section {
                        Label(LocalizedStringKey(errorKey), systemImage: "exclamationmark.circle")
                            .foregroundStyle(CYColor.dangerText)
                            .accessibilityIdentifier("projectEdit.keys.error")
                    }
                }
            }
            .navigationTitle(Text("mpPublish.keys.title"))
            .navigationBarTitleDisplayMode(.inline)
            .disabled(store.saving)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { Task { await done() } }
                        .disabled(store.saving)
                        .accessibilityIdentifier("projectEdit.keys.done")
                }
            }
            .confirmationDialog(deleteTitle, isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), titleVisibility: .visible) {
                Button(role: .destructive) {
                    if let pending = confirmDelete { Task { await performDelete(pending) } }
                    confirmDelete = nil
                } label: {
                    Text("mpPublish.keys.delete")
                }
            }
            .alert(blockedTitle, isPresented: Binding(get: { store.blocked != nil }, set: { if !$0 { store.blocked = nil } })) {
                Button("action.done") { store.blocked = nil }
            } message: {
                if let blocked = store.blocked, !blocked.places.isEmpty {
                    Text("mpPublish.keys.blockedMessage \(blocked.places.formatted(.list(type: .and)))")
                }
            }
        }
    }

    @ViewBuilder private func group(_ kind: ProjectEditTopicKeys.Kind) -> some View {
        Section {
            ForEach(rows(kind)) { row in
                if readOnly {
                    Text(verbatim: row.name)
                } else {
                    DisclosureGroup(isExpanded: Binding(get: { expanded == row.id }, set: { toggle(row, open: $0, kind: kind) })) {
                        TextField(text: Binding(get: { editName }, set: { editName = $0; issue = nil })) {
                            Text("mpPublish.keys.name")
                        }
                        .submitLabel(.done)
                        .onSubmit { Task { _ = await rename(row, kind: kind) } }
                        .accessibilityIdentifier("projectEdit.keys.rename")
                        if !row.usedIn.isEmpty {
                            Text("mpPublish.keys.usedIn")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            ForEach(row.usedIn, id: \.self) { place in
                                Label { Text(verbatim: place) } icon: { Image(systemName: "link") }
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button(role: .destructive) {
                            askDelete(row, kind: kind)
                        } label: {
                            Text(LocalizedStringKey(store.deleting == row.id ? "mpPublish.keys.deleting" : "mpPublish.keys.delete"))
                        }
                        .disabled(!row.usedIn.isEmpty || store.deleting != nil)
                    } label: {
                        Text(verbatim: row.name)
                    }
                }
            }
            if !readOnly && store.state != .failed {
                if adding == kind {
                    HStack {
                        TextField(text: Binding(get: { addName }, set: { addName = $0; issue = ProjectEditTopicKeys.nameIssue($0, taken: rows(kind).map(\.name), kind: kind); issueKind = kind })) {
                            Text("mpPublish.keys.name")
                        }
                        .focused($addFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { _ = await add(kind) } }
                        Button("mpPublish.keys.addAction") { Task { _ = await add(kind) } }
                            .buttonStyle(.borderless)
                            .disabled(addName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || issue != nil || store.saving)
                    }
                } else {
                    Button {
                        adding = kind
                        addName = ""
                        expanded = nil
                        issue = nil
                        issueKind = kind
                        addFocused = true
                    } label: {
                        Label(LocalizedStringKey(kind.addKey), systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("projectEdit.keys.add." + kind.rawValue)
                }
            }
        } header: {
            Text(LocalizedStringKey(kind.labelKey))
        } footer: {
            if issueKind == kind, let issue {
                Label(issueText(issue), systemImage: "exclamationmark.circle")
                    .foregroundStyle(CYColor.dangerText)
            }
        }
    }

    private var deleteTitle: Text {
        let name = confirmDelete?.name ?? ""
        return Text("mpPublish.keys.deleteTitle \(name)")
    }

    private var blockedTitle: Text {
        let name = store.blocked?.name ?? ""
        return Text("mpPublish.keys.blockedTitle \(name)")
    }

    private func issueText(_ issue: ProjectEditTopicKeys.NameIssue) -> LocalizedStringKey {
        switch issue {
        case .tooLong: return "mpPublish.keys.tooLong"
        case .taken(let kind): return LocalizedStringKey("mpPublish.keys.taken." + kind.rawValue)
        }
    }

    /// MP `itemUsedIn` places, localized.
    private func placeText(_ place: ProjectEditTopicKeys.Place) -> String {
        String(localized: placeResource(place))
    }

    private func placeResource(_ place: ProjectEditTopicKeys.Place) -> LocalizedStringResource {
        switch place {
        case .completionReward: return LocalizedStringResource("mpPublish.keys.place.completionReward")
        case .themeGrant: return LocalizedStringResource("mpPublish.keys.place.themeGrant")
        case .chapterGrant(let number): return LocalizedStringResource("mpPublish.keys.place.chapterGrant \(number)")
        case .chapterEgg(let number, let name):
            if name.isEmpty { return LocalizedStringResource("mpPublish.keys.place.chapterEggUnnamed \(number)") }
            return LocalizedStringResource("mpPublish.keys.place.chapterEgg \(number) \(name)")
        case .ration: return LocalizedStringResource("mpPublish.keys.place.ration")
        case .facility(let name):
            if name.isEmpty { return LocalizedStringResource("mpPublish.keys.place.facilityUnnamed") }
            return LocalizedStringResource("mpPublish.keys.place.facility \(name)")
        }
    }

    private func toggle(_ row: Row, open: Bool, kind: ProjectEditTopicKeys.Kind) {
        guard !store.saving else { return }
        if open {
            expanded = row.id
            editName = row.name
            adding = nil
            addName = ""
            issue = nil
            issueKind = kind
        } else if expanded == row.id {
            expanded = nil
            editName = ""
            issue = nil
        }
    }

    /// MP `onRename`: same-group duplicate and length checks, then the item table or the server row.
    private func rename(_ row: Row, kind: ProjectEditTopicKeys.Kind) async -> Bool {
        let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != row.name else { return true }
        let taken = rows(kind).map(\.name).filter { $0 != row.name }
        if let found = ProjectEditTopicKeys.nameIssue(name, taken: taken, kind: kind) {
            issue = found
            issueKind = kind
            return false
        }
        if kind == .item {
            let id = String(row.id.dropFirst("item:".count))
            do {
                model.draft = try ProjectEditTopicKeys.renameItem(id, to: name, in: model.draft)
            } catch {
                store.errorKey = "mpPublish.keys.saveFailed"
                return false
            }
            return true
        }
        guard let server = store.rows(kind).first(where: { $0.id == row.id }) else { return false }
        return await store.rename(server, to: name)
    }

    /// MP `onSave`: 物品 adds a runtime-config row; 线索 / 标签 create a server key.
    private func add(_ kind: ProjectEditTopicKeys.Kind) async -> Bool {
        let name = addName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return true }
        if let found = ProjectEditTopicKeys.nameIssue(name, taken: rows(kind).map(\.name), kind: kind) {
            issue = found
            issueKind = kind
            return false
        }
        if kind == .item {
            do {
                model.draft = try ProjectEditTopicKeys.addItem(named: name, id: ProjectEditTopicKeys.newItemID(), in: model.draft)
            } catch {
                store.errorKey = "mpPublish.keys.saveFailed"
                return false
            }
        } else {
            guard await store.create(kind, name: name) else { return false }
        }
        adding = nil
        addName = ""
        return true
    }

    /// MP `onAskDelete`: a used row explains where instead of asking.
    private func askDelete(_ row: Row, kind: ProjectEditTopicKeys.Kind) {
        if !row.usedIn.isEmpty {
            store.blocked = ProjectEditTopicKeysStore.Blocked(name: row.name, places: row.usedIn)
            return
        }
        confirmDelete = PendingDelete(id: row.id, name: row.name, kind: kind)
    }

    private func performDelete(_ pending: PendingDelete) async {
        if pending.kind == .item {
            let id = String(pending.id.dropFirst("item:".count))
            do {
                model.draft = try ProjectEditTopicKeys.deleteItem(id, in: model.draft)
                expanded = nil
            } catch {
                store.errorKey = "mpPublish.keys.deleteFailed"
            }
            return
        }
        guard let server = store.rows(pending.kind).first(where: { $0.id == pending.id }) else { return }
        await store.delete(server, name: pending.name)
        if store.errorKey == nil && store.blocked == nil { expanded = nil }
    }

    /// MP `onDone`: a typed name is saved first; the sheet closes only when that worked.
    private func done() async {
        if let kind = adding, !addName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard await add(kind) else { return }
        }
        if let id = expanded, let kind = ProjectEditTopicKeys.Kind.allCases.first(where: { kind in rows(kind).contains { $0.id == id } }),
           let row = rows(kind).first(where: { $0.id == id }) {
            guard await rename(row, kind: kind) else { return }
        }
        dismiss()
    }
}
