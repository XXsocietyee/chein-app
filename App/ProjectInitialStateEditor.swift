import SwiftUI

@MainActor final class ProjectInitialStateController: ObservableObject {
    struct Presentation: Identifiable {
        let id = UUID()
        let generation: Int
        let incarnation: UUID
        let session: ProjectEditSession?
        let identity: ProjectEditDraftIdentity?
        let revision: Int
        let bytes: Data
        let initial: ProjectInitialState
    }
    let model: ProjectEditModel
    let chapterID: String
    private var generation = 0
    @Published private(set) var presentation: Presentation?
    init(model: ProjectEditModel, chapterID: String) { self.model = model; self.chapterID = chapterID }
    var available: Bool {
        model.fullEdit && model.draft.product == .city && !chapterID.isEmpty &&
        model.draft.chapters.first?.id.utf8.elementsEqual(chapterID.utf8) == true &&
        model.draft.chapters.filter { $0.id == chapterID }.count == 1
    }
    func open() {
        guard available, presentation == nil, let bytes = ProjectEditPendingMaterials.exactData(model.draft) else { return }
        presentation = .init(generation: generation, incarnation: model.editorIncarnation,
            session: model.coordinator.session, identity: model.coordinator.identity, revision: model.draftMutationRevision,
            bytes: bytes, initial: .init(raw: model.draft.preserved["journeyRules"]))
    }
    func isCurrent(_ original: Presentation) -> Bool {
        presentation?.id == original.id && original.generation == generation && available &&
        model.editorIncarnation == original.incarnation && model.coordinator.session == original.session &&
        model.coordinator.identity == original.identity && model.draftMutationRevision == original.revision &&
        ProjectEditPendingMaterials.exactData(model.draft) == original.bytes
    }
    @discardableResult func apply(_ buffer: ProjectInitialState, to original: Presentation) -> Bool {
        guard isCurrent(original) else { return false }
        do {
            let serialized = try buffer.serialized(matching: model.draft.preserved["journeyRules"])
            var next = model.draft; next.preserved["journeyRules"] = serialized
            if ProjectEditPendingMaterials.exactData(next) != original.bytes { model.draft = next }
            close(original); return true
        } catch { return false }
    }
    func close(_ original: Presentation) {
        guard presentation?.id == original.id else { return }; presentation = nil; generation += 1
    }
    func retire() { presentation = nil; generation += 1 }
    func binding(_ original: Presentation?) -> Binding<Presentation?> {
        .init(get: { guard let original, self.isCurrent(original) else { return nil }; return original },
              set: { if $0 == nil, let original { self.close(original) } })
    }
}

@MainActor struct ProjectInitialStateEntry: View {
    @ObservedObject private var model: ProjectEditModel
    @StateObject private var controller: ProjectInitialStateController
    @Environment(\.topicPlaySetupSource) private var source
    init(model: ProjectEditModel, chapterID: String) {
        self.model = model; _controller = StateObject(wrappedValue: .init(model: model, chapterID: chapterID))
    }
    var body: some View {
        let original = controller.presentation
        Section {
            Button { controller.open() } label: { ProjectInitialStateEntryLabel() }
                .disabled(!controller.available).accessibilityIdentifier("projectInitialState.open")
            ProjectInitialAttributesEntry(model: model, chapterID: controller.chapterID)
        }
        .cySheet(item: controller.binding(original)) { original in Group { ProjectInitialStateSheet(controller: controller, original: original, service: source?.make()) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
        .onChange(of: model.editorIncarnation) { _, _ in controller.retire() }
        .onDisappear { controller.retire() }
    }
}

@MainActor private struct ProjectInitialStateSheet: View {
    @ObservedObject var controller: ProjectInitialStateController
    @ObservedObject private var model: ProjectEditModel
    let original: ProjectInitialStateController.Presentation
    @State private var buffer: ProjectInitialState
    @State private var invalid = false
    @State private var pickingCarry = false
    @Environment(\.topicPlaySetupSource) private var source
    @StateObject private var registry: ProjectInitialStateRegistryStore
    init(controller: ProjectInitialStateController, original: ProjectInitialStateController.Presentation,
         service: TopicCreatorEditorService?) {
        self.controller = controller; self.original = original; model = controller.model
        _buffer = State(initialValue: original.initial)
        let topicID = controller.model.coordinator.publicationTopicID.flatMap { $0 > 0 ? Int64($0) : nil }
        let version = controller.model.draft.preserved["configVersion"]?.integer.flatMap { $0 > 0 ? String($0) : nil }
        _registry = StateObject(wrappedValue: ProjectInitialStateRegistryStore(service: service, topicID: topicID, configVersion: version))
    }
    private func resource(_ kind: ProjectInitialState.Kind) -> Binding<ProjectInitialState.Resource> { kind == .hp ? $buffer.hp : $buffer.luck }
    var body: some View {
        NavigationStack {
            Form {
                if !controller.isCurrent(original) { Text("projectStarter.stale") }
                else if buffer.readOnly { Text("projectInitialState.unsupported", tableName: "ProjectInitialState") }
                else {
                    if !buffer.carry.isEmpty || carryStore != nil {
                        ProjectInitialStateCarrySection(rows: buffer.carry, locked: buffer.carryLocked,
                                                        add: carryStore == nil ? nil : { pickingCarry = true }) { key in
                            buffer.removeCarry(key); invalid = false
                        }
                    }
                    // MP `fabu/index.wxml:1923-1928` 数值 card: the attribute-binding editor right after 开局带着.
                    ProjectInitialStateBindingSection(store: registry, rules: buffer.bindingRules, storedKeys: buffer.bindingEnabledKeys,
                                                      readOnly: !model.canEdit, confirm: { confirmed in
                        buffer.bind(confirmed); invalid = false
                    }, manage: {
                        controller.close(original)
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 450_000_000)
                            model.topicDetailAsk += 1
                        }
                    })
                    ForEach(ProjectInitialState.Kind.allCases.filter { resource($0).wrappedValue.enabled }, id: \.self) { kind in
                        ProjectInitialStateResourceSection(kind: kind, resource: resource(kind),
                            remove: { buffer.setEnabled(false, kind: kind); invalid = false }, edited: { invalid = false })
                    }
                    ForEach(buffer.counters) { row in
                        ProjectInitialStateCounterSection(row: row, locked: buffer.carryLocked) { value in
                            buffer.setCounterInitial(row.key, value: value); invalid = false
                        }
                    }
                    Section {
                        ForEach(ProjectInitialState.Kind.allCases, id: \.self) { kind in
                            ProjectInitialStateOptionRow(kind: kind, added: resource(kind).wrappedValue.enabled) {
                                buffer.setEnabled(true, kind: kind); invalid = false
                            }
                        }
                    } header: { Text("projectInitialState.addHeader", tableName: "ProjectInitialState") }
                    if !buffer.recoveryChanges.isEmpty {
                        Section {
                            Text("projectInitialState.recoveryNotice", tableName: "ProjectInitialState")
                            ForEach(buffer.recoveryChanges) { change in
                                LabeledContent {
                                    Text(verbatim: "\(change.before) → \(change.after)")
                                } label: { Text(LocalizedStringKey("projectInitialState.recovery." + change.key), tableName: "ProjectInitialState") }
                            }
                        }
                    }
                    if invalid { Text("projectInitialState.invalid", tableName: "ProjectInitialState") }
                }
            }
            .navigationTitle(Text("projectInitialState.title", tableName: "ProjectInitialState")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { controller.close(original) } label: { Text("projectInitialState.exit", tableName: "ProjectInitialState") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { invalid = !controller.apply(buffer, to: original) } label: {
                        Text("projectInitialState.done", tableName: "ProjectInitialState")
                    }
                    .disabled(!controller.isCurrent(original) || buffer.readOnly)
                    .accessibilityIdentifier("projectInitialState.confirm")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $pickingCarry) {
                if let carryStore {
                    ProjectInitialStateCarryPicker(store: carryStore, taken: Set(buffer.carry.map { $0.key })) { picks in
                        let added = buffer.addCarry(picks)
                        if added { invalid = false }
                        return added
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    /// MP `openCarryPicker` reads the topic's keys; a topic that is not saved yet, a bound registry or a
    /// session without the creator service has no 添加 row (the MP row is hidden when locked).
    private var carryStore: (() -> ProjectEditTopicKeysStore)? {
        guard !buffer.carryLocked, let topicID = model.coordinator.publicationTopicID, topicID > 0,
              let source, let service = source.make() else { return nil }
        return { ProjectEditTopicKeysStore(service: service, topicID: Int64(topicID)) }
    }
}

/// MP `fabu/index.wxml:1322` entry card: 初始状态 · 第一章开局数值 · 配置.
private struct ProjectInitialStateEntryLabel: View {
    var body: some View {
        LabeledContent {
            Text("projectInitialState.configure", tableName: "ProjectInitialState")
        } label: {
            Text("projectInitialState.title", tableName: "ProjectInitialState")
            Text("projectInitialState.entrySubtitle", tableName: "ProjectInitialState")
        }
    }
}

/// MP `fabu/index.wxml:1929-1940`: one card per added resource, its switch and the 开局 stepper.
/// The maximum lives in the topic's runtime values (MP: 上限归主题数值域设置；首章初始状态只改开局值).
private struct ProjectInitialStateResourceSection: View {
    let kind: ProjectInitialState.Kind
    @Binding var resource: ProjectInitialState.Resource
    let remove: () -> Void
    let edited: () -> Void
    private var lower: Int { kind == .hp ? 1 : 0 }
    private var upper: Int {
        let ceiling = kind == .hp ? 20 : 5
        let parsed = Int(resource.maximum) ?? lower
        return max(lower, min(parsed, ceiling))
    }
    private var start: Binding<Int> {
        Binding<Int>(get: { max(lower, min(Int(resource.initial) ?? lower, upper)) },
                     set: { (value: Int) in resource.initial = String(value); edited() })
    }
    var body: some View {
        Section {
            Toggle(isOn: Binding<Bool>(get: { true }, set: { (on: Bool) in if !on { remove() } })) {
                Text(kind == .hp ? "projectInitialState.hp" : "projectInitialState.luck", tableName: "ProjectInitialState")
            }
            Stepper(value: start, in: lower...upper) {
                LabeledContent {
                    Text(start.wrappedValue, format: .number).monospacedDigit()
                } label: {
                    Text(kind == .hp ? "projectInitialState.startHP" : "projectInitialState.startLuck", tableName: "ProjectInitialState")
                }
            }
        } footer: {
            Text("projectInitialState.range \(lower) \(upper)", tableName: "ProjectInitialState")
        }
    }
}

/// MP `fabu/index.wxml:1941-1945`: one card per `counter.*` value — name, `min 至 max`, 开局 stepper, and the
/// red 开局值超出当前范围 line. A bound registry owns the value, so the stepper is read-only there.
private struct ProjectInitialStateCounterSection: View {
    let row: ProjectInitialState.CounterRow
    let locked: Bool
    let change: (Int) -> Void
    private var start: Binding<Int> {
        Binding<Int>(get: { max(row.minimum, min(row.initial ?? row.minimum, row.maximum)) },
                     set: { (value: Int) in change(value) })
    }
    var body: some View {
        Section {
            LabeledContent {
                Text("projectInitialState.counterRange \(row.minimum) \(row.maximum)", tableName: "ProjectInitialState")
                    .monospacedDigit()
            } label: {
                Text(verbatim: row.label).font(.headline)
            }
            Stepper(value: start, in: row.minimum...max(row.minimum, row.maximum)) {
                LabeledContent {
                    Text(start.wrappedValue, format: .number).monospacedDigit()
                } label: {
                    Text("projectInitialState.counterStart \(row.label)", tableName: "ProjectInitialState")
                }
            }
            .disabled(locked)
            .accessibilityIdentifier("projectInitialState.counter." + row.key)
        } footer: {
            if row.invalid {
                Text("projectInitialState.counterInvalid", tableName: "ProjectInitialState").foregroundStyle(CYColor.dangerText)
            } else if locked {
                Text("projectInitialState.counterBound", tableName: "ProjectInitialState")
            }
        }
    }
}

/// MP `fabu/index.wxml:1946-1955` 添加初始状态 choices (`story-initial-state.js` OPTIONS).
private struct ProjectInitialStateOptionRow: View {
    let kind: ProjectInitialState.Kind
    let added: Bool
    let add: () -> Void
    var body: some View {
        Button(action: add) {
            LabeledContent {
                Text(added ? "projectInitialState.added" : "projectInitialState.add", tableName: "ProjectInitialState")
            } label: {
                Text(kind == .hp ? "projectInitialState.hp" : "projectInitialState.luck", tableName: "ProjectInitialState")
                Text(kind == .hp ? "projectInitialState.hpExample" : "projectInitialState.luckExample", tableName: "ProjectInitialState")
            }
        }
        .disabled(added)
        .accessibilityIdentifier("projectInitialState.add." + kind.rawValue)
    }
}

/// MP `fabu/index.wxml:1914-1923` 开局带着: clue / tag rows the player starts with, removable unless the registry is bound.
private struct ProjectInitialStateCarrySection: View {
    let rows: [ProjectInitialState.CarryRow]
    let locked: Bool
    let add: (() -> Void)?
    let remove: (String) -> Void
    var body: some View {
        Section {
            ForEach(rows) { row in
                HStack {
                    LabeledContent {
                        Text(row.isClue ? "projectInitialState.kind.clue" : "projectInitialState.kind.tag", tableName: "ProjectInitialState")
                    } label: {
                        Text(verbatim: row.label)
                    }
                    if !locked {
                        Button { remove(row.key) } label: {
                            Image(systemName: "xmark.circle.fill").imageScale(.large).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(Text("projectInitialState.removeCarry \(row.label)", tableName: "ProjectInitialState"))
                        .accessibilityIdentifier("projectInitialState.carry.remove." + row.key)
                    }
                }
            }
            if !locked, let add {
                Button(action: add) {
                    Label { Text("projectInitialState.add", tableName: "ProjectInitialState") } icon: { Image(systemName: "plus") }
                }
                .accessibilityLabel(Text("projectInitialState.carryAdd", tableName: "ProjectInitialState"))
                .accessibilityIdentifier("projectInitialState.carry.add")
            }
        } header: {
            Text("projectInitialState.carryHeader", tableName: "ProjectInitialState")
        }
    }
}
