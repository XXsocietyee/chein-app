import SwiftUI

/// The account host's publisher-identity service, read by the topic editor's 票务设置 page.
/// Nil (signed out, preview, fixture) hides the section instead of showing a dead control.
struct PublisherIdentityRegistrationSource {
    let account: PublishingSession?
    let make: () -> PublisherIdentityRegistrationService?
}

private struct PublisherIdentityRegistrationSourceKey: EnvironmentKey {
    static let defaultValue: PublisherIdentityRegistrationSource? = nil
}

extension EnvironmentValues {
    var publisherIdentityRegistrationSource: PublisherIdentityRegistrationSource? {
        get { self[PublisherIdentityRegistrationSourceKey.self] }
        set { self[PublisherIdentityRegistrationSourceKey.self] = newValue }
    }
}

/// MP `publish/fabu/step3.wxml:329-347` 发布者实名: the last section of 票务设置, shown only when the topic
/// charges (`topicRequiresIdentity`). The native form is the shared `PublisherIdentityRegistrationSection`
/// (same fields, separate consent, status read-back), bound to this editor visit.
@MainActor struct ProjectEditIdentitySection: View {
    @ObservedObject var model: ProjectEditModel
    @Environment(\.publisherIdentityRegistrationSource) private var source
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var owner = PublisherIdentityRegistrationOwner()

    var body: some View {
        if let source, ProjectEditIdentityRule.requiresIdentity(model.draft) {
            let _ = owner.bind(account: source.account, topicEditor: model.editorIncarnation)
            PublisherIdentityRegistrationSection(owner: owner, makeService: source.make, enabled: model.canEdit)
                .id("project-issue-anchor-identity")
                .onAppear { owner.appear(active: scenePhase == .active) }
                .onDisappear { owner.disappear() }
                .onChange(of: scenePhase) { _, phase in owner.setActive(phase == .active) }
        }
    }
}
