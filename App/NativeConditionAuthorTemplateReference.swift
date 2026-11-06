import SwiftUI

/// Reads the exact original Template source, including unknown future nodes. The supplied
/// source bundle has no recursive Template consumer/save/readback contract, so this bridge
/// cannot turn route language into a different Template language by changing its serializer.
@MainActor final class NativeConditionAuthorTemplateReference: NativeConditionAuthorDraftHosting {
    private weak var model: TemplateAuthoringModel?
    private let source: () -> TemplateAuthoringJSON?
    private let location: String
    private let surface: NativeConditionAuthorDocument.Surface
    private let incarnation = UUID()
    init(model: TemplateAuthoringModel, location: String, surface: NativeConditionAuthorDocument.Surface,
         source: @escaping () -> TemplateAuthoringJSON?) {
        self.model = model; self.location = location; self.surface = surface; self.source = source
    }
    func capture() -> NativeConditionAuthorCapture? {
        guard let model, model.canReadMetadataDraft, let session = model.coordinator.session,
              let source = source(), let data = try? JSONEncoder().encode(source) else { return nil }
        let scope = NativeConditionAuthorScope(accountID: session.accountID, namespace: session.namespace,
            epoch: session.epoch, authorizationRevision: session.authorizationRevision,
            documentIdentity: model.coordinator.identity.draftID.uuidString + ":" + location,
            sourceRevision: model.metadataGeneration.uuidString, incarnation: incarnation)
        return .init(scope: scope, raw: String(decoding: data, as: UTF8.self), surface: surface,
                     catalog: .init(nodes: [], items: [], medals: [], triggers: [], outcomes: []), attributes: nil, canEdit: false)
    }
    func persistOriginalDraft(_ raw: String, replacing expected: NativeConditionAuthorCapture) throws -> NativeConditionAuthorCapture {
        throw NativeConditionAuthorError.blocked([.init(path: location, code: "templateContract", detail: "原模板递归消费者与权威作者回读合同未提供。")])
    }
}
