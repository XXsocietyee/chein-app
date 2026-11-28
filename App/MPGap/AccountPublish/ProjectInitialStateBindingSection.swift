import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// MP `fabu loadAttributeRegistry`: the topic's registry snapshot for the 初始状态 sheet, read once per open
/// and again on 重新读取. A topic that is not saved yet gets the plain hint, not an error.
@MainActor final class ProjectInitialStateRegistryStore: ObservableObject {
    enum State: Equatable {
        case saveFirst
        case loading
        case ready(TopicAttributeRegistry)
        /// A localization key in `ProjectInitialState`, or MP / server copy shown as is.
        case failed(String)
    }
    @Published private(set) var state: State
    private let service: TopicCreatorEditorService?
    private let topicID: Int64?
    private let configVersion: String?
    private var generation = 0

    init(service: TopicCreatorEditorService?, topicID: Int64?, configVersion: String?) {
        self.service = service; self.topicID = topicID; self.configVersion = configVersion
        state = service == nil || topicID == nil || configVersion == nil ? .saveFirst : .loading
    }

    func load() async {
        guard let service, let topicID, let configVersion else { state = .saveFirst; return }
        generation += 1
        let mine = generation
        state = .loading
        do {
            let registry = try await service.attributeBinding(topicID: topicID, configVersion: configVersion)
            guard mine == generation else { return }
            state = .ready(registry)
        } catch TopicCreatorEditorIssue.rejected(let text) {
            guard mine == generation else { return }
            state = .failed(text)
        } catch {
            guard mine == generation else { return }
            state = .failed("projectInitialState.binding.readFailed")
        }
    }
}

/// MP `publish/components/attribute-binding-editor` inside the 初始状态 sheet's 数值 card: 启用的注册属性
/// checkboxes, one 定义差异 block per changed key with 我确认采用这项注册定义, then 确认启用 / 重新读取 / 调整定义.
/// Native: a `Form` section of toggles; the confirmed binding is staged in the sheet buffer until 完成.
@MainActor struct ProjectInitialStateBindingSection: View {
    @ObservedObject var store: ProjectInitialStateRegistryStore
    let rules: [String: ProjectEditJSON]
    let storedKeys: [String]
    let readOnly: Bool
    let confirm: ([String: ProjectEditJSON]) -> Void
    let manage: () -> Void
    @State private var enabled: [String]?
    @State private var accepted: Set<String> = []
    @State private var issue: ProjectAttributeBinding.Issue?

    private func text(_ key: String) -> Text { Text(LocalizedStringKey("projectInitialState.binding." + key), tableName: "ProjectInitialState") }

    var body: some View {
        Section {
            switch store.state {
            case .saveFirst:
                text("saveFirst").font(.footnote).foregroundStyle(.secondary)
            case .loading:
                ProgressView { text("notReady").font(.footnote).foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity)
            case .failed(let message):
                text("notReady").font(.footnote).foregroundStyle(.secondary)
                Label {
                    Text(LocalizedStringKey(message), tableName: "ProjectInitialState")
                } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                .foregroundStyle(CYColor.dangerText)
                .font(.footnote)
            case .ready(let registry):
                readyRows(registry)
            }
            actions
        } header: {
            text("title")
        }
        .task { await store.load() }
    }

    @ViewBuilder private func readyRows(_ registry: TopicAttributeRegistry) -> some View {
        let keys = enabled ?? storedKeys
        text("notice").font(.footnote).foregroundStyle(.secondary)
        ForEach(registry.definitions, id: \.stateKey) { definition in
            Toggle(isOn: Binding<Bool>(get: { keys.contains(definition.stateKey) }, set: { (on: Bool) in
                var next = keys.filter { $0 != definition.stateKey }
                if on { next.append(definition.stateKey) }
                enabled = next; accepted = []; issue = nil
            })) {
                Text(verbatim: definition.label.isEmpty ? definition.stateKey : definition.label)
            }
            .disabled(readOnly)
            .accessibilityIdentifier("projectInitialState.binding.key." + definition.stateKey)
        }
        let conflicts = (try? ProjectAttributeBinding.conflicts(rules: rules, registry: registry, enabledKeys: keys)) ?? []
        ForEach(conflicts) { conflict in
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("projectInitialState.binding.conflictTitle \(conflict.label)", tableName: "ProjectInitialState").font(.headline)
                ForEach(conflict.differences) { difference in
                    differenceLine(difference).font(.footnote).foregroundStyle(.secondary)
                }
                Toggle(isOn: Binding<Bool>(get: { accepted.contains(conflict.key) }, set: { (on: Bool) in
                    if on { accepted.insert(conflict.key) } else { accepted.remove(conflict.key) }
                    issue = nil
                })) {
                    text("accept")
                }
                .disabled(readOnly)
                .accessibilityIdentifier("projectInitialState.binding.accept." + conflict.key)
            }
        }
        if let issue {
            issueText(issue).font(.footnote).foregroundStyle(CYColor.dangerText)
        }
    }

    private func differenceLine(_ difference: ProjectAttributeBinding.Difference) -> Text {
        let field = Text(LocalizedStringKey("projectInitialState.binding.field." + difference.field), tableName: "ProjectInitialState")
        let previous = difference.previous.map { Text(verbatim: $0) } ?? text("unrecorded")
        let registered = difference.registered.map { Text(verbatim: $0) } ?? text("unset")
        return Text("projectInitialState.binding.difference \(field) \(previous) \(registered)", tableName: "ProjectInitialState")
    }

    private func issueText(_ issue: ProjectAttributeBinding.Issue) -> Text {
        switch issue {
        case .malformed: return text("issue.malformed")
        case .tooMany: return text("issue.tooMany")
        case .unaccepted: return text("issue.unaccepted")
        case .statLink(let key): return Text("projectInitialState.binding.issue.statLink \(key)", tableName: "ProjectInitialState")
        case .keyType(let key): return Text("projectInitialState.binding.issue.keyType \(key)", tableName: "ProjectInitialState")
        case .unregistered(let key): return Text("projectInitialState.binding.issue.unregistered \(key)", tableName: "ProjectInitialState")
        }
    }

    @ViewBuilder private var actions: some View {
        if case .ready(let registry) = store.state, !readOnly {
            Button {
                do {
                    let next = try ProjectAttributeBinding.confirm(rules: rules, registry: registry,
                        enabledKeys: enabled ?? storedKeys, acceptedKeys: accepted)
                    issue = nil; enabled = nil; accepted = []
                    confirm(next)
                } catch let failure as ProjectAttributeBinding.Issue {
                    issue = failure
                } catch {
                    issue = .malformed
                }
            } label: {
                text("confirm").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("projectInitialState.binding.confirm")
        }
        if store.state != .saveFirst {
            Button {
                enabled = nil; accepted = []; issue = nil
                Task { await store.load() }
            } label: {
                text("refresh").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(store.state == .loading)
            .accessibilityIdentifier("projectInitialState.binding.refresh")
        }
        Button(action: manage) {
            text("manage").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("projectInitialState.binding.manage")
    }
}
