import SwiftUI

/// Original Project Model is the only source of topic/version/scope/editor incarnation.
/// This bridge never saves a project, issues an approval, or mutates either journal.
@MainActor final class NativeAttributeAuthorProjectHost {
    private weak var model: ProjectEditModel?
    private let configuration: APIConfiguration
    let scope: NativeConditionAuthorScope
    let binding: NativeAttributeAuthorBinding

    init?(model: ProjectEditModel, configuration: APIConfiguration) {
        guard let source = Self.capture(model, configuration: configuration) else { return nil }
        self.model = model; self.configuration = configuration
        scope = source.0; binding = source.1
    }
    private static func capture(_ model: ProjectEditModel, configuration: APIConfiguration)
        -> (NativeConditionAuthorScope, NativeAttributeAuthorBinding)? {
        // Reuse the independently reviewed F1 same-Model source binding, not a second
        // identity derivation or a requested scope pasted onto a different author's data.
        guard let source = NativeConditionAuthorProjectReadbackAdapter.Source.capture(model: model),
              model.coordinator.pending == nil,
              let snapshot = model.coordinator.snapshot,
              let version = snapshot.draft.preserved["configVersion"]?.integer, version >= 0,
              model.draft.preserved["configVersion"]?.integer == version,
              let binding = try? NativeAttributeAuthorBinding(server: configuration.baseURL.absoluteString,
                  namespace: source.session.storageNamespace, accountID: Int64(source.session.accountID),
                  epoch: source.session.epoch,
                  authorizationRevision: "\(source.session.viewerRevision):\(source.session.configurationRevision)",
                  topicID: Int64(source.topicID), sourceConfigVersion: Int64(version),
                  requestScope: source.owner.rawValue) else { return nil }
        return (source.scope, binding)
    }
    func currentBinding() -> NativeAttributeAuthorBinding? {
        guard let model, let current = Self.capture(model, configuration: configuration), current.0 == scope else { return nil }
        return current.1
    }
    func binding(for requested: NativeConditionAuthorScope) -> NativeAttributeAuthorBinding? {
        requested == scope ? currentBinding() : nil
    }
    /// First-party E16/37 collector selection for the original versioned author host.
    /// This supplies semantics, not authority: the same live references-read grant and
    /// source incarnation are checked before/final-forward/after every original GET.
    func e16ReferenceReader(transport: any NativeAttributeAuthorTransport,
                            endpointAllowed: @escaping (NativeAttributeAuthorHostEndpoint) -> Bool,
                            currentAccess: @escaping () -> Bool) -> NativeAttributeAuthorService.ReferenceReader {
        let reader = NativeAttributeAuthorE16References(transport: transport, current: { [self] in
            currentAccess() && endpointAllowed(.references) ? currentBinding() : nil
        })
        return { binding, key, requestKey in
            try await reader.read(binding: binding, key: key, requestKey: requestKey)
        }
    }
    /// Existing storage and approved transport are mandatory inputs. The optional complete
    /// reader is supplied only after the original e16 server semantics are actually installed.
    func dependencies(transport: any NativeAttributeAuthorTransport, storage: any TemplateAuthoringStorage,
                      references: NativeAttributeAuthorService.ReferenceReader? = nil,
                      projectFlow: (any NativeAttributeAuthorProjectFlow)? = nil,
                      conditionEditor: (any NativeAttributeAuthorConditionEditing)? = nil,
                      conditionCatalog: ((NativeConditionAuthorScope) -> NativeConditionAuthorCatalog?)? = nil,
                      conditionCatalogReader: NativeAttributeAuthorConditionCatalogReader? = nil,
                      endpointAllowed: @escaping (NativeAttributeAuthorHostEndpoint) -> Bool = { _ in true },
                      onSourceRetired: ((NativeAttributeAuthorBinding) -> Void)? = nil,
                      currentAccess: @escaping () -> Bool = { true }) -> NativeAttributeAuthorDependencies? {
        guard currentAccess(), currentBinding() == binding else { return nil }
        let service = NativeAttributeAuthorService(transport: transport, current: { [self] in currentAccess() ? currentBinding() : nil },
                                                   references: references, contract: .versionedCandidate, endpointAllowed: endpointAllowed)
        let editor: (any NativeAttributeAuthorConditionEditing)?
        if let conditionEditor { editor = conditionEditor }
        else if let conditionCatalogReader {
            editor = NativeAttributeAuthorConditionEditor(source: { [self] requested in
                guard currentAccess(), currentBinding() == requested,
                      let value = conditionCatalogReader.attributeRuleCatalog(for: scope) else { return nil }
                return (scope, value)
            }, refreshSource: {
                guard currentAccess() else { throw NativeAttributeAuthorError.staleSource }
                try await conditionCatalogReader.refresh()
                guard currentAccess() else { throw NativeAttributeAuthorError.staleSource }
            })
        } else if let conditionCatalog {
            editor = NativeAttributeAuthorConditionEditor(source: { [self] requested in
                guard currentAccess(), currentBinding() == requested, let value = conditionCatalog(scope) else { return nil }
                return (scope, value)
            })
        } else { editor = nil }
        return .init(binding: binding, service: service, store: .init(storage: storage),
                     projectFlow: projectFlow, conditionEditor: editor, onSourceRetired: onSourceRetired)
    }
    /// Existing same-source local recovery only. No fresh registry, no fabricated baseline,
    /// no pending operation, and no attribute endpoint transport can enter this dependency.
    func localDraftDependencies(storage: any TemplateAuthoringStorage,
                                conditionCatalogReader: NativeAttributeAuthorConditionCatalogReader,
                                currentAccess: @escaping () -> Bool) -> NativeAttributeAuthorDependencies? {
        guard currentAccess(), currentBinding() == binding else { return nil }
        let store = NativeAttributeAuthorLocalStore(storage: storage)
        guard let recovered = try? store.load(binding: binding), recovered.pending == nil,
              recovered.draft.binding == binding else { return nil }
        let service = NativeAttributeAuthorService(current: { [self] in currentAccess() ? currentBinding() : nil }, contract: .versionedCandidate)
        let editor = NativeAttributeAuthorConditionEditor(source: { [self] requested in
            guard currentAccess(), requested == currentBinding(),
                  let catalog = conditionCatalogReader.attributeRuleCatalog(for: scope) else { return nil }
            return (scope, catalog)
        }, refreshSource: { try await conditionCatalogReader.refresh() })
        return .init(binding: binding, service: service, store: store, projectFlow: nil,
                     conditionEditor: editor, localDraftOnly: true)
    }

    func conditionProjection(service: NativeAttributeAuthorService) -> NativeAttributeAuthorConditionProjection {
        .init(service: service, binding: { [self] in binding(for: $0) })
    }
}

/// Root supplies the original deployment-approved factory for the very same Project model.
/// Default nil is not acceptance: this source makes no grant and does not silently enable HTTP.
@MainActor struct NativeAttributeAuthorProjectFactory {
    let make: (ProjectEditModel) -> NativeAttributeAuthorDependencies?
    var published: ((ProjectEditModel) -> NativeAttributeAuthorPublishedHost?)? = nil
}
private struct NativeAttributeAuthorProjectFactoryKey: EnvironmentKey {
    static let defaultValue: NativeAttributeAuthorProjectFactory? = nil
}
extension EnvironmentValues {
    var nativeAttributeAuthorProjectFactory: NativeAttributeAuthorProjectFactory? {
        get { self[NativeAttributeAuthorProjectFactoryKey.self] }
        set { self[NativeAttributeAuthorProjectFactoryKey.self] = newValue }
    }
}
@MainActor final class NativeAttributeAuthorProjectPresentation: Identifiable {
    enum Content {
        case editing(NativeAttributeAuthorDependencies, NativeAttributeAuthorCoordinator)
        case published(NativeAttributeAuthorPublishedHost)
    }
    let visit: NativeAuthorProjectVisit
    let content: Content
    var id: UUID { visit.id }
    private(set) var confirmedSourceChange = false // Original coordinator says this source is retired, not a new mutation grant.
    init(visit: NativeAuthorProjectVisit, content: Content) {
        self.visit = visit; self.content = content
        if case .editing(_, let coordinator) = content {
            visit.onRetire { [weak coordinator] in coordinator?.retire() }
        }
    }
    func sourceRetired(_ binding: NativeAttributeAuthorBinding) {
        guard !confirmedSourceChange, visit.isCurrent, case .editing(let dependencies, let coordinator) = content,
              coordinator.retiredSourceBinding == binding else { return }
        confirmedSourceChange = true; dependencies.onSourceRetired?(binding)
    }
    var needsOriginalReadback: Bool {
        if confirmedSourceChange { return true }
        if case .editing(_, let coordinator) = content { return coordinator.retiredSourceBinding != nil }
        return false
    }
}

@MainActor struct NativeAttributeAuthorProjectEntrySection: View {
    @ObservedObject var model: ProjectEditModel
    @Environment(\.nativeAttributeAuthorProjectFactory) private var factory
    @Environment(\.scenePhase) private var scenePhase
    @State private var presentation: NativeAttributeAuthorProjectPresentation?
    @State private var pendingReadback: NativeAuthorProjectVisit?
    @State private var returnTicket = UUID()
    private func text(_ key: String, table: String = "NativeAttributeAuthor") -> String {
        NSLocalizedString(key, tableName: table, bundle: .main, comment: "")
    }
    var body: some View {
        let original = presentation
        Group {
            if model.fullEdit {
                if let dependencies = factory?.make(model) {
                    Section {
                        Button { openEditor() } label: {
                            Label(text(dependencies.localDraftOnly ? "nativeAttribute.localDraft" : "nativeAttribute.title"), systemImage: "slider.horizontal.3")
                        }.accessibilityIdentifier("nativeAttribute.entry")
                    }
                }
                if factory?.published?(model) != nil {
                    Section {
                        Button { openPublished() } label: {
                            Label(text("nativeAttribute.published"), systemImage: "lock.fill")
                        }.accessibilityIdentifier("nativeAttribute.publishedEntry")
                    }
                }
                if let pendingReadback {
                    Section {
                        Text(verbatim: text("nativeCondition.originalReadbackDeferred", table: "NativeConditionAuthor"))
                        Button(text("nativeCondition.readOriginalProject", table: "NativeConditionAuthor")) {
                            requestReadback(pendingReadback)
                        }.disabled(scenePhase != .active || presentation != nil)
                    }
                }
            }
        }
        .sheet(item: Binding<NativeAttributeAuthorProjectPresentation?>(get: {
            guard scenePhase == .active, let presentation, presentation.visit.isCurrent else { return nil }; return presentation
        }, set: { next in if next == nil, let original { close(original) } })) { original in Group {
            NavigationStack {
                Group {
                    if original.visit.isCurrent {
                        switch original.content {
                        case .editing(let dependencies, let coordinator):
                            NativeAttributeAuthorView(coordinator: coordinator, conditionEditor: dependencies.conditionEditor,
                                moduleReportRenderer: dependencies.moduleReportRenderer,
                                onSourceRetired: { original.sourceRetired($0) }, close: { close(original) })
                        case .published(let host):
                            NativeAttributeAuthorPublishedDestination(model: model, host: host, visit: original.visit,
                                close: { close(original) })
                        }
                    } else { Text("nativeCondition.unavailable") }
                }
            }.interactiveDismissDisabled()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active, let original = presentation { close(original, readback: false) } }
        .onChange(of: presentation?.visit.isCurrent) { _, current in
            if current == false, let original = presentation { close(original, readback: false) }
        }
        .onChange(of: model.editorIncarnation) { _, _ in pendingReadback = nil; returnTicket = UUID() }
        .onDisappear {
            returnTicket = UUID()
            if let original = presentation { close(original, readback: false) }
            pendingReadback = nil
        }
    }
    private func openEditor() {
        guard scenePhase == .active, presentation == nil,
              let visit = NativeAuthorProjectVisit(model: model), let dependencies = factory?.make(model) else { return }
        returnTicket = UUID()
        let coordinator = NativeAttributeAuthorCoordinator(binding: dependencies.binding, service: dependencies.service,
            store: dependencies.store, projectFlow: dependencies.projectFlow, localDraftOnly: dependencies.localDraftOnly)
        presentation = .init(visit: visit, content: .editing(dependencies, coordinator))
    }
    private func openPublished() {
        guard scenePhase == .active, presentation == nil,
              let visit = NativeAuthorProjectVisit(model: model), let host = factory?.published?(model) else { return }
        returnTicket = UUID(); presentation = .init(visit: visit, content: .published(host))
    }
    private func close(_ original: NativeAttributeAuthorProjectPresentation, readback: Bool = true) {
        guard presentation?.id == original.id else { return }
        let shouldRead = original.visit.isCurrent && original.needsOriginalReadback
        original.visit.retire(); presentation = nil
        if shouldRead {
            pendingReadback = original.visit
            if readback, scenePhase == .active { requestReadback(original.visit) }
        }
        // UNKNOWN stays in the original42 store and never triggers a source replacement.
    }
    private func requestReadback(_ original: NativeAuthorProjectVisit) {
        guard scenePhase == .active, presentation == nil, pendingReadback?.id == original.id else { return }
        returnTicket = UUID(); let ticket = returnTicket
        Task {
            guard ticket == returnTicket, scenePhase == .active, presentation == nil else { return }
            let requested = await original.requestOriginalReadback()
            guard ticket == returnTicket else { return }
            if requested, pendingReadback?.id == original.id { pendingReadback = nil }
        }
    }
}

/// Only the original private project reader is supplied. The immutable snapshot remains
/// separate from today's mutable registry and cannot settle a pending save/publication.
@MainActor final class NativeAttributeAuthorPublishedHost {
    private let project: NativeAttributeAuthorProjectHost
    private let reader: NativeAttributeAuthorPublishedReader
    private let currentAccess: () -> Bool
    init(project: NativeAttributeAuthorProjectHost, reader: NativeAttributeAuthorPublishedReader, currentAccess: @escaping () -> Bool) {
        self.project = project; self.reader = reader; self.currentAccess = currentAccess
    }
    var isCurrent: Bool { currentAccess() && project.currentBinding() == project.binding }
    func load() async throws -> NativeAttributeAuthorCoordinator {
        guard isCurrent else { throw NativeAttributeAuthorError.staleSource }
        let inspected = try await reader.inspect(project.binding)
        guard isCurrent, !Task.isCancelled else { throw NativeAttributeAuthorError.staleSource }
        let service = NativeAttributeAuthorService(current: { [self] in isCurrent ? inspected.binding : nil },
            locked: { [self] requested in
                guard isCurrent, requested == inspected.binding else { throw NativeAttributeAuthorError.staleSource }
                return inspected.source
            }, contract: .versionedCandidate)
        // No mutable store, endpoint transport, condition editor, or publication flow.
        let coordinator = NativeAttributeAuthorCoordinator(binding: inspected.binding, service: service)
        await coordinator.load()
        guard isCurrent, !Task.isCancelled, coordinator.draft != nil else { throw NativeAttributeAuthorError.staleSource }
        return coordinator
    }
}

@MainActor private struct NativeAttributeAuthorPublishedDestination: View {
    @ObservedObject var model: ProjectEditModel
    let host: NativeAttributeAuthorPublishedHost
    let visit: NativeAuthorProjectVisit
    let close: () -> Void
    @State private var coordinator: NativeAttributeAuthorCoordinator?
    @State private var loading = false
    @State private var failed = false
    @State private var retry = 0
    var body: some View {
        Group {
            if !visit.isCurrent || !host.isCurrent { Text("nativeCondition.unavailable") }
            else if let coordinator { NativeAttributeAuthorView(coordinator: coordinator, close: close) }
            else if loading { ProgressView() }
            else if failed {
                VStack {
                    Text(NSLocalizedString("nativeAttribute.publishedUnavailable", tableName: "NativeAttributeAuthor", bundle: .main, comment: ""))
                    Button("nativeCondition.readAuthoritative") { retry += 1 }.disabled(loading)
                }
            }
        }.task(id: retry) {
            guard coordinator == nil, visit.isCurrent, host.isCurrent else { return }
            loading = true; failed = false
            defer { loading = false }
            do {
                let value = try await host.load()
                guard !Task.isCancelled, visit.isCurrent, host.isCurrent else { value.retire(); return }
                visit.onRetire { [weak value] in value?.retire() }
                coordinator = value
            } catch { if !Task.isCancelled { failed = true } }
        }
        .toolbar {
            if coordinator == nil { ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("nativeAttribute.close", tableName: "NativeAttributeAuthor", bundle: .main, comment: ""), action: close)
            } }
        }
        // The presentation owner retires the reader on close/background/true parent leave,
        // not when a nested row is pushed inside this modal NavigationStack.
    }
}
