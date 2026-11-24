import SwiftUI

/// Normal composition factory, retained by the presented child rather than rebuilt by body.
@MainActor struct NativeConditionAuthorProjectFactory {
    let make: (ProjectEditModel, NativeAuthorProjectVisit) -> NativeConditionAuthorProjectCatalogHost?
}
private struct NativeConditionAuthorProjectFactoryKey: EnvironmentKey {
    static let defaultValue: NativeConditionAuthorProjectFactory? = nil
}
extension EnvironmentValues {
    var nativeConditionAuthorProjectFactory: NativeConditionAuthorProjectFactory? {
        get { self[NativeConditionAuthorProjectFactoryKey.self] }
        set { self[NativeConditionAuthorProjectFactoryKey.self] = newValue }
    }
}

/// Uses only the approved original private Project reader and original local Project saver.
/// Catalog refresh never submits, registers definitions, repairs a journal, or grants access.
@MainActor final class NativeConditionAuthorProjectCatalogHost: ObservableObject,
        NativeConditionAuthorDraftHosting, NativeConditionAuthorAttributePicking, NativeConditionAuthorReadbackServing {
    @Published private(set) var ready = false
    @Published private(set) var failed = false
    private weak var model: ProjectEditModel?
    private let original: NativeConditionAuthorProjectReadbackAdapter.Source
    private let service: ProjectEditHTTPService
    private let currentAccess: () -> Bool
    private var generation = UUID()
    private var active = true
    private var materials: Data?
    private var projection: NativeConditionAuthorOriginalCatalog?
    private func originalAdapter() -> NativeConditionAuthorProjectAdapter? {
        guard let model else { return nil }
        return NativeConditionAuthorProjectAdapter(model: model, attributes: self,
            catalog: { [weak self] scope in self?.catalog(for: scope) })
    }

    init?(model: ProjectEditModel, service: ProjectEditHTTPService, currentAccess: @escaping () -> Bool) {
        guard let source = NativeConditionAuthorProjectReadbackAdapter.Source.capture(model: model),
              model.coordinator.pending == nil, currentAccess() else { return nil }
        self.model = model; original = source; self.service = service; self.currentAccess = currentAccess
    }
    private func originalSource() -> NativeConditionAuthorProjectReadbackAdapter.Source? {
        guard active, currentAccess(), let model, model.coordinator.pending == nil,
              let source = NativeConditionAuthorProjectReadbackAdapter.Source.capture(model: model),
              source.session == original.session, source.owner == original.owner, source.product == original.product,
              source.topicID == original.topicID, source.scope.accountID == original.scope.accountID,
              source.scope.epoch == original.scope.epoch, source.scope.namespace == original.scope.namespace,
              source.scope.authorizationRevision == original.scope.authorizationRevision,
              source.scope.documentIdentity == original.scope.documentIdentity,
              source.scope.incarnation == original.scope.incarnation else { return nil }
        return source
    }
    private func currentSource() -> NativeConditionAuthorProjectReadbackAdapter.Source? {
        guard let source = originalSource(), let model, let materials,
              (try? NativeConditionAuthorOriginalCatalog.sourceMaterials(model.draft)) == materials else { return nil }
        return source
    }
    func load() async {
        // Returning from a nested branch must not discard its retained unsaved condition editor.
        guard !ready else { return }
        generation = UUID(); let ticket = generation
        ready = false; failed = false; projection = nil; materials = nil
        do {
            guard let source = originalSource(), let model,
                  let version = model.draft.preserved["configVersion"]?.nativeConditionInteger,
                  let configVersion = Int(exactly: version), configVersion >= 0 else { throw NativeConditionAuthorError.staleEditor }
            let expectedMaterials = try NativeConditionAuthorOriginalCatalog.sourceMaterials(model.draft)
            let base = model.draft.baseRevision
            try Task.checkCancellation()
            let readback = try await service.readOriginalAuthorDetail(topicID: source.topicID, session: source.session)
            guard !Task.isCancelled, generation == ticket, let current = originalSource(), current.scope == source.scope,
                  readback.session == source.session, readback.owner == source.owner,
                  readback.snapshot.topicID == source.topicID, readback.snapshot.scope == .full,
                  readback.snapshot.draft.owner == source.owner, readback.snapshot.draft.product == source.product,
                  readback.snapshot.draft.baseRevision.utf8.elementsEqual(base.utf8),
                  try NativeConditionAuthorOriginalCatalog.sourceMaterials(readback.snapshot.draft) == expectedMaterials,
                  try NativeConditionAuthorOriginalCatalog.sourceMaterials(model.draft) == expectedMaterials else {
                throw NativeConditionAuthorError.staleEditor
            }
            let projected = try NativeConditionAuthorOriginalCatalog(raw: readback.raw, topicID: source.topicID, configVersion: configVersion)
            let nodeIDs = Set(model.draft.chapters.flatMap(\.nodes).compactMap { $0.localMetadata["id"]?.nativeConditionInteger.map(String.init) })
            guard Set(projected.catalog(for: source.scope).nodes.map(\.id)) == nodeIDs else { throw NativeConditionAuthorError.staleEditor }
            materials = expectedMaterials; projection = projected; ready = true
        } catch {
            guard generation == ticket else { return }
            projection = nil; materials = nil; ready = false; failed = true
        }
    }
    private func catalog(for scope: NativeConditionAuthorScope) -> NativeConditionAuthorCatalog? {
        guard ready, currentSource()?.scope == scope else { return nil }
        return projection?.catalog(for: scope)
    }
    func references(for scope: NativeConditionAuthorScope) -> NativeConditionAuthorAttributeProjection? {
        guard ready, currentSource()?.scope == scope else { return nil }
        return projection?.attributes(for: scope)
    }
    func capture() -> NativeConditionAuthorCapture? {
        guard ready, currentSource() != nil, model != nil else { return nil }
        return originalAdapter()?.capture()
    }
    func persistOriginalDraft(_ raw: String, replacing expected: NativeConditionAuthorCapture) throws -> NativeConditionAuthorCapture {
        guard ready, currentSource()?.scope == expected.scope, model != nil else { throw NativeConditionAuthorError.staleEditor }
        // Its existing atomic saver recaptures this same catalog at the new local revision.
        // Material changes cannot be rebound, while a valid conditions/edges edit can.
        guard let adapter = originalAdapter() else { throw NativeConditionAuthorError.staleEditor }
        return try adapter.persistOriginalDraft(raw, replacing: expected)
    }
    func readOriginalAuthorSource(for scope: NativeConditionAuthorScope) async throws -> NativeConditionAuthorReadback {
        guard currentSource()?.scope == scope else { throw NativeConditionAuthorError.staleEditor }
        let reader = NativeConditionAuthorProjectReadbackAdapter(service: service, current: { [weak self] in self?.currentSource() })
        return try await reader.readOriginalAuthorSource(for: scope)
    }
    func retire() { active = false; generation = UUID(); projection = nil; materials = nil; ready = false }
}

@MainActor struct NativeConditionAuthorCatalogDestination: View {
    @StateObject private var host: NativeConditionAuthorProjectCatalogHost
    let visit: NativeAuthorProjectVisit
    let close: () -> Void
    init(host: NativeConditionAuthorProjectCatalogHost, visit: NativeAuthorProjectVisit, close: @escaping () -> Void) {
        _host = StateObject(wrappedValue: host); self.visit = visit; self.close = close
    }
    var body: some View {
        Group {
            if host.ready && visit.isCurrent {
                NativeConditionAuthorView(host: host, reader: host, projectVisit: visit, close: close)
            } else {
                List {
                    if host.failed { Text("nativeCondition.sourceDependenciesMissing") }
                    else { ProgressView() }
                    if host.failed && visit.isCurrent {
                        Button("nativeCondition.readAuthoritative") { Task { await host.load() } }
                    }
                }.navigationTitle("nativeCondition.title").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) {
                        Button(NSLocalizedString("nativeCondition.close", tableName: "NativeConditionAuthor", bundle: .main, comment: "")) {
                            host.retire(); close()
                        }
                    } }
            }
        }.task { await host.load() }
        .onChange(of: visit.isCurrent) { _, current in if !current { host.retire() } }
    }
}
