import SwiftUI

// MARK: - MP pages/publish/fabu/index.wxml:1022 (node row 到达与引导 · nodeStructureSummary)
// runtime-structure-editor.wxml kind 'quests': 到达地点 · 工作人员引导答题 → 找不到时换个方式 → 备用节点
// theme-runtime-structure.js openStructure / onStructureLocation / onStructureGuide / toggleStructureFallback / saveStructure

/// The saved topic and task the 找不到时换个方式 rows write to (`api/orient/task/alternative`).
struct ProjectNodeArrivalAlternative: Equatable {
    let topicID: Int
    let taskID: Int
}

enum ProjectNodeArrivalCopy {
    static let table = "ProjectNodeArrival"

    /// Keys of this table, or the shared editor keys (进行方式 refusals, unreadable config) in Localizable.
    static func text(_ key: String) -> Text {
        if key.hasPrefix("projectNodeArrival.") { return Text(LocalizedStringKey(key), tableName: table) }
        return Text(LocalizedStringKey(key))
    }

    static func place(_ place: ProjectEditNodeArrival.Place) -> Text {
        if !place.name.isEmpty { return Text(verbatim: place.name) }
        if let number = place.nodeNumber { return Text("projectNodeArrival.place.node \(number)", tableName: table) }
        return Text("projectNodeArrival.place.shared \(place.id)", tableName: table)
    }

    static func stop(_ stop: ProjectEditNodeArrival.Stop) -> Text {
        if !stop.name.isEmpty { return Text(verbatim: stop.name) }
        return Text("projectNodeArrival.place.node \(stop.id)", tableName: table)
    }
}

/// Node detail row: 到达与引导 with the MP summary (未配置 / place name / 需重选), pushing the page.
@MainActor struct ProjectNodeArrivalEntry: View {
    @ObservedObject var model: ProjectEditModel
    let nodeID: Int
    let alternative: ProjectNodeArrivalAlternative?

    var body: some View {
        Section {
            NavigationLink {
                ProjectNodeArrivalPage(model: model, nodeID: nodeID, alternative: alternative)
            } label: {
                LabeledContent {
                    summary
                } label: {
                    Label {
                        Text("projectNodeArrival.title", tableName: ProjectNodeArrivalCopy.table)
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                    }
                }
            }
            .accessibilityIdentifier("projectNodeArrival.open")
        }
    }

    private var summary: Text {
        switch ProjectEditNodeArrival.summary(nodeID: nodeID, in: model.draft) {
        case .key(let key): return ProjectNodeArrivalCopy.text(key)
        case .place(let place): return ProjectNodeArrivalCopy.place(place)
        }
    }
}

/// MP quests sheet as a pushed page (OWNER RULE 2: inline title, system rows). Every change applies at once,
/// like 进行方式; a refused change keeps the draft and shows the reason in the footer.
@MainActor struct ProjectNodeArrivalPage: View {
    @ObservedObject var model: ProjectEditModel
    let nodeID: Int
    let alternative: ProjectNodeArrivalAlternative?
    @State private var inputs: NativeRuntimeStructureAuthorInputs?
    @State private var loading = false
    @State private var loadFailed = false
    @State private var refusal: ProjectNodeArrivalRefusal?
    @State private var fallbackOpen = false

    private var currentInputs: NativeRuntimeStructureAuthorInputs? {
        guard let inputs, model.coordinator.runtimeStructureInputsAreCurrent(inputs) else { return nil }
        return inputs
    }

    var body: some View {
        let state = ProjectEditNodeArrival.state(nodeID: nodeID, in: model.draft)
        List {
            if let key = state.refusalKey {
                ProjectNodeArrivalRefusedSection(model: model, key: key)
            } else {
                placeSection(state)
            }
            if let alternative {
                OrientAlternativeEditorSection(topicID: alternative.topicID, taskID: alternative.taskID)
            }
            if state.refusalKey == nil {
                ProjectNodeArrivalFallbackSection(state: state, open: $fallbackOpen, editable: model.fullEdit) { ids in
                    apply(state, fallbackIDs: ids)
                }
            }
        }
        .navigationTitle(Text("projectNodeArrival.title", tableName: ProjectNodeArrivalCopy.table))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func placeSection(_ state: ProjectEditNodeArrival.State) -> some View {
        let allowed = ProjectEditNodeArrival.guideAllowed(nodeID: nodeID, in: model.draft, inputs: currentInputs)
        return Section {
            Picker(selection: placeBinding(state)) {
                if !state.places.contains(where: { $0.id == state.placeKey }) {
                    Text("projectNodeArrival.place.choose", tableName: ProjectNodeArrivalCopy.table).tag(String?.none)
                }
                ForEach(state.places) { place in
                    ProjectNodeArrivalCopy.place(place).tag(String?.some(place.id))
                }
            } label: {
                Text("projectNodeArrival.place", tableName: ProjectNodeArrivalCopy.table)
            }
            .accessibilityIdentifier("projectNodeArrival.place")
            Toggle(isOn: guideBinding(state)) {
                Text("projectNodeArrival.guide", tableName: ProjectNodeArrivalCopy.table)
            }
            .disabled(!state.guide && !allowed)
            .accessibilityIdentifier("projectNodeArrival.guide")
        } footer: {
            ProjectNodeArrivalFooter(refusal: refusal, loading: loading, loadFailed: loadFailed,
                                     guideBlocked: !state.guide && !allowed && !loading) {
                Task { await load() }
            }
        }
        .disabled(!model.fullEdit)
    }

    private func placeBinding(_ state: ProjectEditNodeArrival.State) -> Binding<String?> {
        Binding<String?>(get: { state.placeKey }, set: { (key: String?) in
            guard let key else { return }
            apply(state, placeKey: key)
        })
    }

    private func guideBinding(_ state: ProjectEditNodeArrival.State) -> Binding<Bool> {
        Binding<Bool>(get: { state.guide }, set: { (on: Bool) in apply(state, guide: on) })
    }

    private func apply(_ state: ProjectEditNodeArrival.State, placeKey: String? = nil, guide: Bool? = nil, fallbackIDs: [Int]? = nil) {
        guard model.fullEdit, let key = placeKey ?? state.placeKey else {
            refusal = .key("projectNodeArrival.refuse.place")
            return
        }
        do {
            model.draft = try ProjectEditNodeArrival.save(nodeID: nodeID, placeKey: key, guide: guide ?? state.guide,
                                                          fallbackIDs: fallbackIDs ?? state.fallbackIDs,
                                                          in: model.draft, inputs: currentInputs)
            refusal = nil
        } catch ProjectEditRuntimeActsError.refused(let reason) {
            refusal = .key(reason)
        } catch ProjectEditNodeArrivalError.issue(let text) {
            refusal = .text(text)
        } catch {
            refusal = .key(ProjectEditNodeArrival.Copy.unreadable)
        }
    }

    private func load() async {
        guard model.fullEdit, !loading else { return }
        loading = true
        loadFailed = false
        do {
            inputs = try await model.coordinator.runtimeStructureInputs(draft: model.draft)
        } catch {
            inputs = nil
            loadFailed = true
        }
        loading = false
    }
}

enum ProjectNodeArrivalRefusal: Equatable {
    case key(String)
    case text(String)
}

/// MP error line when the node has no quest yet; with no 进行方式 the MP opens that picker first.
@MainActor private struct ProjectNodeArrivalRefusedSection: View {
    @ObservedObject var model: ProjectEditModel
    let key: String

    var body: some View {
        Section {
            Label {
                ProjectNodeArrivalCopy.text(key)
            } icon: {
                Image(systemName: "info.circle")
            }
            .foregroundStyle(.secondary)
            if key == ProjectEditRuntimeActs.Copy.refuseMode {
                NavigationLink {
                    ProjectEditRunModePage(model: model)
                } label: {
                    Text("mpPublish.rules.mode")
                }
                .accessibilityIdentifier("projectNodeArrival.chooseMode")
            }
        }
    }
}

@MainActor private struct ProjectNodeArrivalFooter: View {
    let refusal: ProjectNodeArrivalRefusal?
    let loading: Bool
    let loadFailed: Bool
    let guideBlocked: Bool
    let retry: () -> Void

    var body: some View {
        if let refusal {
            Label {
                switch refusal {
                case .key(let key): ProjectNodeArrivalCopy.text(key)
                case .text(let text): Text(verbatim: text)
                }
            } icon: {
                Image(systemName: "exclamationmark.circle")
            }
            .foregroundStyle(CYColor.dangerText)
        } else if loading {
            Label {
                Text("mpPublish.rules.mode.loading")
            } icon: {
                ProgressView()
            }
        } else if loadFailed {
            VStack(alignment: .leading, spacing: 8) {
                Text("projectNodeArrival.matrixFailed", tableName: ProjectNodeArrivalCopy.table)
                Button("mpPublish.rules.mode.retry", action: retry)
                    .buttonStyle(.borderless)
            }
        } else if guideBlocked {
            Text("projectNodeArrival.refuse.guide", tableName: ProjectNodeArrivalCopy.table)
        }
    }
}

/// MP 备用节点 fold row: summary of the picked stops, opening to check rows of the other saved nodes (max 20).
@MainActor private struct ProjectNodeArrivalFallbackSection: View {
    let state: ProjectEditNodeArrival.State
    @Binding var open: Bool
    let editable: Bool
    let apply: ([Int]) -> Void

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $open) {
                if state.stops.isEmpty {
                    Text("projectNodeArrival.fallback.empty", tableName: ProjectNodeArrivalCopy.table)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.stops) { stop in
                        row(stop)
                    }
                }
            } label: {
                LabeledContent {
                    Text(verbatim: summary)
                } label: {
                    Text("projectNodeArrival.fallback", tableName: ProjectNodeArrivalCopy.table)
                }
            }
            .accessibilityIdentifier("projectNodeArrival.fallback")
        } footer: {
            Text("projectNodeArrival.fallback.footer \(ProjectEditNodeArrival.fallbackLimit)", tableName: ProjectNodeArrivalCopy.table)
        }
    }

    private var summary: String {
        let names = state.stops.filter { state.fallbackIDs.contains($0.id) }.map { $0.name.isEmpty ? "#\($0.id)" : $0.name }
        return ListFormatter.localizedString(byJoining: names)
    }

    private func row(_ stop: ProjectEditNodeArrival.Stop) -> some View {
        let selected = state.fallbackIDs.contains(stop.id)
        return Button {
            var ids = state.fallbackIDs
            if selected { ids.removeAll { $0 == stop.id } } else { ids.append(stop.id) }
            apply(ids)
        } label: {
            HStack {
                ProjectNodeArrivalCopy.stop(stop)
                    .foregroundStyle(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(!editable || (!selected && state.fallbackIDs.count >= ProjectEditNodeArrival.fallbackLimit))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("projectNodeArrival.fallback." + String(stop.id))
        .sensoryFeedback(.selection, trigger: selected)
    }
}
