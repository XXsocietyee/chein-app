import SwiftUI

/// Value identity drives preference updates; the live check fences a retained old close/tick.
struct TemplateAuthoringPublishResultSignal: Equatable {
    let result: TemplateAuthoringPublishResult
    let metadata: UUID
    let media: UUID
    let revision: Int
    let draft: Data
    let isCurrent: @MainActor () -> Bool
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.result == rhs.result && lhs.metadata == rhs.metadata && lhs.media == rhs.media &&
        lhs.revision == rhs.revision && lhs.draft == rhs.draft
    }
    @MainActor static func capture(model: TemplateAuthoringModel, eligible: Bool) -> Self? {
        guard eligible, !model.busy, model.review == nil, model.coordinator.review == nil,
              model.canReadMetadataDraft, let result = TemplateAuthoringPublishResult(coordinator: model.coordinator),
              let draft = snapshot(model.draft) else { return nil }
        let metadata = model.metadataGeneration, media = model.mediaReviewGeneration, revision = model.revision
        return .init(result: result, metadata: metadata, media: media, revision: revision, draft: draft, isCurrent: { [weak model] in
            guard let model else { return false }
            return !model.busy && model.review == nil && model.coordinator.review == nil && model.canReadMetadataDraft &&
                model.metadataGeneration == metadata && model.mediaReviewGeneration == media && model.revision == revision &&
                snapshot(model.draft) == draft && result.isCurrent(in: model.coordinator)
        })
    }
    private static func snapshot(_ draft: TemplateAuthoringDraft) -> Data? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try? encoder.encode(draft)
    }
}
/// Observing this exact editable visit is required before a receipt may show as a new success.
/// A terminal receipt restored when opening an editor is not a new save event.
struct TemplateAuthoringPublishResultObservation: Equatable {
    let state: TemplateAuthoringCoordinator.State
    let session: TemplateAuthoringSession?
    let identity: TemplateAuthoringIdentity
    let metadata: UUID
    let revision: Int
    let signal: TemplateAuthoringPublishResultSignal?
    let editableNow: @MainActor () -> Bool
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.state == rhs.state && lhs.session == rhs.session && lhs.identity == rhs.identity &&
        lhs.metadata == rhs.metadata && lhs.revision == rhs.revision && lhs.signal == rhs.signal
    }
    @MainActor static func capture(model: TemplateAuthoringModel, eligible: Bool) -> Self? {
        guard eligible else { return nil }
        let session = model.coordinator.session, identity = model.coordinator.identity
        let metadata = model.metadataGeneration, revision = model.revision
        return .init(state: model.coordinator.state, session: session, identity: identity, metadata: metadata, revision: revision,
                     signal: TemplateAuthoringPublishResultSignal.capture(model: model, eligible: eligible), editableNow: { [weak model] in
            guard let model, let session, let current = model.coordinator.session else { return false }
            return model.canEdit && !model.busy && model.coordinator.state == .editing && model.coordinator.identity == identity &&
                TemplateAuthoringSavedResult.exactSession(current, session) && model.metadataGeneration == metadata && model.revision == revision
        })
    }
}
struct TemplateAuthoringPublishResultPreferenceKey: PreferenceKey {
    static let defaultValue: TemplateAuthoringPublishResultObservation? = nil
    static func reduce(value: inout TemplateAuthoringPublishResultObservation?, nextValue: () -> TemplateAuthoringPublishResultObservation?) {
        if let next = nextValue() { value = next }
    }
}

@MainActor struct TemplateAuthoringPublishResultPanel: View {
    let result: TemplateAuthoringPublishResult
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    // MP cy-result-sheet (publish/temp `resultSheet`): badge → title → sub → meta 预计 N 分钟; no button,
    // the 2 s timer lands on the template library (`close` is kept for the controller's own clock).
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill").accessibilityHidden(true).font(.largeTitle).foregroundStyle(CYColor.successText)
                .symbolEffect(.bounce, value: arrived && !reduceMotion)
            Text("templatePublishResult.title", tableName: "CreatorPublishResult").cyText(.sheetTitle).multilineTextAlignment(.center)
            Text("templatePublishResult.detail", tableName: "CreatorPublishResult").multilineTextAlignment(.center).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let minutes = result.durationMinutes {
                Label { Text("templatePublishResult.meta \(minutes)", tableName: "CreatorPublishResult") } icon: { Image(systemName: "info.circle") }
                    .cyText(.bodyCompact).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity).padding(24).presentationDetents([.medium]).interactiveDismissDisabled(true)
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
            .sensoryFeedback(.success, trigger: arrived)
            .onAppear { arrived = true }
            .accessibilityIdentifier("templatePublishResult.panel")
    }
}
