import SwiftUI

/// All dependencies are supplied by the original owner. No generic project transport, runtime
/// flag, or server capability field is converted into attribute-author access here.
@MainActor struct NativeAttributeAuthorDependencies {
    let binding: NativeAttributeAuthorBinding
    let service: NativeAttributeAuthorService
    let store: NativeAttributeAuthorLocalStore
    let projectFlow: (any NativeAttributeAuthorProjectFlow)?
    let conditionEditor: (any NativeAttributeAuthorConditionEditing)?
    var localDraftOnly = false
    var moduleReportRenderer: (any NativeAttributeAuthorModuleReportRendering)? = nil
    /// Notification only. The original host reloads/re-authorizes its source; this is no grant.
    var onSourceRetired: ((NativeAttributeAuthorBinding) -> Void)? = nil

    func entry() -> AnyView {
        AnyView(NativeAttributeAuthorEntry(makeCoordinator: {
            NativeAttributeAuthorCoordinator(binding: binding, service: service, store: store, projectFlow: projectFlow, localDraftOnly: localDraftOnly)
        }, localDraftOnly: localDraftOnly, conditionEditor: conditionEditor, moduleReportRenderer: moduleReportRenderer, onSourceRetired: onSourceRetired))
    }
}
