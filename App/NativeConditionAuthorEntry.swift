import SwiftUI

/// Composition forwards the existing source owners. These closures issue no grants and
/// must bind catalog/readback to the exact scope argument rather than a mutable selection.
@MainActor struct NativeConditionAuthorDependencies {
    let attributes: (any NativeConditionAuthorAttributePicking)?
    let catalog: (NativeConditionAuthorScope) -> NativeConditionAuthorCatalog?
    let reader: ((ProjectEditModel) -> (any NativeConditionAuthorReadbackServing)?)?
}
private struct NativeConditionAuthorDependenciesKey: EnvironmentKey {
    static let defaultValue: NativeConditionAuthorDependencies? = nil
}
extension EnvironmentValues {
    var nativeConditionAuthorDependencies: NativeConditionAuthorDependencies? {
        get { self[NativeConditionAuthorDependenciesKey.self] }
        set { self[NativeConditionAuthorDependenciesKey.self] = newValue }
    }
}

/// Presentation lifetime only, not a source/endpoint grant. The original Project still
/// owns its visit, draft, journal and true leave. A child never calls model.leave().
@MainActor final class NativeAuthorProjectVisit: Identifiable {
    let id = UUID()
    private weak var model: ProjectEditModel?
    private let original: NativeConditionAuthorProjectReadbackAdapter.Source
    private var active = true
    private var retirement: (() -> Void)?
    init?(model: ProjectEditModel) {
        guard let original = NativeConditionAuthorProjectReadbackAdapter.Source.capture(model: model),
              model.coordinator.pending == nil else { return nil }
        self.model = model; self.original = original
    }
    private var matchesOwner: Bool {
        guard let model, let current = NativeConditionAuthorProjectReadbackAdapter.Source.capture(model: model) else { return false }
        // Local condition saves may advance draftMutationRevision in the same visit.
        // They do not change this presentation's account, source document or incarnation.
        return current.session == original.session && current.topicID == original.topicID &&
            current.owner == original.owner && current.product == original.product &&
            current.scope.incarnation == original.scope.incarnation &&
            current.scope.namespace == original.scope.namespace &&
            current.scope.authorizationRevision == original.scope.authorizationRevision &&
            current.scope.documentIdentity == original.scope.documentIdentity
    }
    var isCurrent: Bool { active && matchesOwner }
    func onRetire(_ action: @escaping () -> Void) {
        if active { retirement = action } else { action() }
    }
    func retire() {
        guard active else { return }; active = false
        let action = retirement; retirement = nil; action?()
    }
    /// Only the original Project reader may refresh after a confirmed source change.
    /// Preserve an unsaved Project draft through its original durable local-save path first.
    /// UNKNOWN attribute requests never request this method; they stay in their own journal.
    func requestOriginalReadback() async -> Bool {
        guard matchesOwner, let model, model.coordinator.pending == nil,
              let snapshot = model.coordinator.snapshot else { return false }
        // Synthesized Equatable folds canonically equivalent Swift strings. The original
        // Project observation boundary compares encoded bytes so NFC/NFD edits are not lost.
        guard let draftBytes = ProjectEditPendingMaterials.exactData(model.draft),
              let sourceBytes = ProjectEditPendingMaterials.exactData(snapshot.draft) else { return false }
        if draftBytes != sourceBytes, !model.saveLocalForExit() { return false }
        guard matchesOwner, model.coordinator.pending == nil, !Task.isCancelled else { return false }
        await model.load(force: true)
        return true // Reader invoked; its original model owns success, conflict and error presentation.
    }
}

@MainActor final class NativeAuthorConditionVisitHost: NativeConditionAuthorDraftHosting {
    private let original: any NativeConditionAuthorDraftHosting
    private weak var visit: NativeAuthorProjectVisit?
    init(original: any NativeConditionAuthorDraftHosting, visit: NativeAuthorProjectVisit) {
        self.original = original; self.visit = visit
    }
    func capture() -> NativeConditionAuthorCapture? { visit?.isCurrent == true ? original.capture() : nil }
    func persistOriginalDraft(_ raw: String, replacing expected: NativeConditionAuthorCapture) throws -> NativeConditionAuthorCapture {
        guard visit?.isCurrent == true else { throw NativeConditionAuthorError.staleEditor }
        return try original.persistOriginalDraft(raw, replacing: expected)
    }
}

@MainActor struct NativeConditionAuthorProjectEntrySection: View {
    @ObservedObject var model: ProjectEditModel
    @Environment(\.nativeConditionAuthorDependencies) private var dependencies
    @Environment(\.nativeConditionAuthorProjectFactory) private var factory
    @Environment(\.scenePhase) private var scenePhase
    @State private var visit: NativeAuthorProjectVisit?
    var body: some View {
        let original = visit
        Group {
            if model.draft.preserved["routeGraphJson"] != nil {
                Section("nativeCondition.title") {
                    if factory != nil || dependencies != nil {
                        Button("nativeCondition.title") {
                            guard scenePhase == .active, visit == nil else { return }
                            visit = NativeAuthorProjectVisit(model: model)
                        }.disabled(!model.fullEdit)
                    } else { Text("nativeCondition.sourceDependenciesMissing") }
                }
            }
        }
        // Same presentation shape as the original ProjectEditStarterPresentation. This
        // does not intercept or weaken ProjectEditView.onDisappear/model.leave().
        .sheet(item: Binding<NativeAuthorProjectVisit?>(get: {
            guard scenePhase == .active, let visit, visit.isCurrent else { return nil }; return visit
        }, set: { next in if next == nil, let original { close(original) } })) { original in Group {
            NavigationStack {
                NativeConditionAuthorProjectDestination(model: model, dependencies: dependencies, factory: factory,
                    visit: original, close: { close(original) })
            }.interactiveDismissDisabled()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active, let original = visit { close(original) } }
        .onChange(of: visit?.isCurrent) { _, current in if current == false, let original = visit { close(original) } }
        .onDisappear { if let original = visit { close(original) } }
    }
    private func close(_ original: NativeAuthorProjectVisit) {
        guard visit?.id == original.id else { return }
        original.retire(); visit = nil
        // Local condition saves already updated the retained original model and its durable
        // draft. Returning re-renders that source; no remote reload overwrites unsent edits.
    }
}

@MainActor private struct NativeConditionAuthorProjectDestination: View {
    @ObservedObject var model: ProjectEditModel
    let dependencies: NativeConditionAuthorDependencies?
    let factory: NativeConditionAuthorProjectFactory?
    let visit: NativeAuthorProjectVisit
    let close: () -> Void
    var body: some View {
        if visit.isCurrent, let factory, let host = factory.make(model, visit) {
            NativeConditionAuthorCatalogDestination(host: host, visit: visit, close: close)
        } else if visit.isCurrent, factory == nil, let dependencies {
            NativeConditionAuthorView(host: NativeAuthorConditionVisitHost(
                original: model.nativeConditionAuthorHost(attributes: dependencies.attributes, catalog: dependencies.catalog), visit: visit),
                reader: dependencies.reader?(model), projectVisit: visit, close: close)
        } else {
            Text("nativeCondition.unavailable").toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("nativeCondition.close", tableName: "NativeConditionAuthor", bundle: .main, comment: ""), action: close)
            } }
        }
    }
}

/// Concrete adapter over the existing ProjectEditServing.preflight author read. The
/// composition supplies its already approved reader and original current scope/session.
@MainActor final class NativeConditionAuthorProjectReadbackAdapter: NativeConditionAuthorReadbackServing {
    struct Source {
        let scope: NativeConditionAuthorScope
        let session: ProjectEditSession
        let topicID: Int
        let owner: ProjectEditOwner
        let product: ProjectEditProduct

        /// All expected identity facts are required. In ordinary composition use capture(model:)
        /// so they come from the same original editor visit, never sample/default values.
        init(scope: NativeConditionAuthorScope, session: ProjectEditSession, topicID: Int,
             owner: ProjectEditOwner, product: ProjectEditProduct) {
            self.scope = scope; self.session = session; self.topicID = topicID
            self.owner = owner; self.product = product
        }

        @MainActor static func capture(model: ProjectEditModel) -> Source? {
            guard model.fullEdit, let session = model.coordinator.session,
                  let identity = model.coordinator.identity, let topicID = identity.topicID, topicID > 0,
                  let snapshot = model.coordinator.snapshot, snapshot.topicID == topicID,
                  snapshot.draft.owner == model.draft.owner, snapshot.draft.product == model.draft.product,
                  !model.draft.baseRevision.isEmpty,
                  snapshot.draft.baseRevision.utf8.elementsEqual(model.draft.baseRevision.utf8) else { return nil }
            let scope = NativeConditionAuthorScope(accountID: session.accountID, namespace: session.storageNamespace,
                epoch: session.epoch, authorizationRevision: "\(session.viewerRevision):\(session.configurationRevision)",
                documentIdentity: identity.bucket, sourceRevision: model.draft.baseRevision + ":\(model.draftMutationRevision)",
                incarnation: model.editorIncarnation)
            return .init(scope: scope, session: session, topicID: topicID, owner: model.draft.owner, product: model.draft.product)
        }

        func matches(_ requested: NativeConditionAuthorScope) -> Bool {
            guard let identity = try? ProjectEditDraftIdentity(topicID: topicID) else { return false }
            return scope == requested && requested.accountID == session.accountID && requested.epoch == session.epoch &&
                requested.namespace == Data(session.storageNamespace.utf8) &&
                requested.authorizationRevision == Data("\(session.viewerRevision):\(session.configurationRevision)".utf8) &&
                requested.documentIdentity == Data(identity.bucket.utf8)
        }
    }
    private let service: any ProjectEditServing
    private let current: () -> Source?
    init(service: any ProjectEditServing, current: @escaping () -> Source?) { self.service = service; self.current = current }
    /// Uses the caller's existing approved author reader; this adapter creates no authority.
    convenience init(service: any ProjectEditServing, model: ProjectEditModel) {
        self.init(service: service, current: { [weak model] in
            guard let model else { return nil }; return Source.capture(model: model)
        })
    }
    func readOriginalAuthorSource(for scope: NativeConditionAuthorScope) async throws -> NativeConditionAuthorReadback {
        guard !Task.isCancelled, let source = current(), source.matches(scope) else { throw NativeConditionAuthorError.staleEditor }
        let result = try await service.preflight(topicID: source.topicID, session: source.session)
        guard !Task.isCancelled, let live = current(), live.matches(scope), live.session == source.session,
              live.topicID == source.topicID, live.owner == source.owner, live.product == source.product,
              let snapshot = result.snapshot, snapshot.topicID == source.topicID,
              snapshot.draft.owner == source.owner, snapshot.draft.product == source.product,
              let raw = snapshot.draft.preserved["routeGraphJson"]?.nativeConditionText,
              !snapshot.draft.baseRevision.isEmpty else { throw NativeConditionAuthorError.staleEditor }
        return .init(requestedScope: scope, raw: raw, serverRevision: snapshot.draft.baseRevision)
    }
}
