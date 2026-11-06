import SwiftUI

/// Narrow bridge into the existing Project editor. Owns no draft files, requests or grants.
@MainActor final class NativeConditionAuthorProjectAdapter: NativeConditionAuthorDraftHosting {
    private weak var model: ProjectEditModel?
    private let attributes: (any NativeConditionAuthorAttributePicking)?
    private let catalog: (NativeConditionAuthorScope) -> NativeConditionAuthorCatalog?
    init(model: ProjectEditModel, attributes: (any NativeConditionAuthorAttributePicking)?,
         catalog: @escaping (NativeConditionAuthorScope) -> NativeConditionAuthorCatalog?) {
        self.model = model; self.attributes = attributes; self.catalog = catalog
    }
    func capture() -> NativeConditionAuthorCapture? {
        guard let model, model.fullEdit, let session = model.coordinator.session,
              let identity = model.coordinator.identity, let raw = model.draft.preserved["routeGraphJson"]?.nativeConditionText else { return nil }
        let scope = NativeConditionAuthorScope(accountID: session.accountID, namespace: session.storageNamespace,
            epoch: session.epoch, authorizationRevision: "\(session.viewerRevision):\(session.configurationRevision)",
            documentIdentity: identity.bucket, sourceRevision: model.draft.baseRevision + ":\(model.draftMutationRevision)",
            incarnation: model.editorIncarnation)
        guard let catalog = catalog(scope) else { return nil }
        return .init(scope: scope, raw: raw, surface: .routeGraph, catalog: catalog,
                     attributes: attributes?.references(for: scope), canEdit: model.fullEdit && model.coordinator.pending == nil)
    }
    func persistOriginalDraft(_ raw: String, replacing expected: NativeConditionAuthorCapture) throws -> NativeConditionAuthorCapture {
        guard let model, let current = capture(), current.scope == expected.scope, current.canEdit,
              current.raw.utf8.elementsEqual(expected.raw.utf8), let lease = model.captureStarterLease() else { throw NativeConditionAuthorError.staleEditor }
        let edited = try NativeConditionAuthorDocument(raw: raw, surface: .routeGraph, scope: current.scope)
        let diagnostics = NativeConditionAuthorValidation.issues(edited, catalog: current.catalog, attributes: current.attributes)
        guard diagnostics.isEmpty else { throw NativeConditionAuthorError.blocked(diagnostics) }
        // The field already travels in ProjectEditStoryContract.topicFields and ProjectEditContract.payload.
        // Keep routeMode, configVersion, every other owner field and the original pending journal untouched.
        var next = model.draft; next.preserved["routeGraphJson"] = .string(raw)
        guard model.persistLocalChange(next, lease: lease), let saved = capture(),
              saved.raw.utf8.elementsEqual(raw.utf8) else { throw NativeConditionAuthorError.persistenceFailed }
        return saved
    }
}

@MainActor extension ProjectEditModel {
    /// Root supplies real node/item/trigger projections and the attribute owner's picker.
    /// No inferred default catalog is installed into ordinary composition.
    func nativeConditionAuthorHost(attributes: (any NativeConditionAuthorAttributePicking)?,
        catalog: @escaping (NativeConditionAuthorScope) -> NativeConditionAuthorCatalog?) -> NativeConditionAuthorProjectAdapter {
        .init(model: self, attributes: attributes, catalog: catalog)
    }
}
