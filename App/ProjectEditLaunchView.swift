import SwiftUI

/// Both routes are pure local authoring. Guests can edit/review only in memory;
/// account-scoped Keychain saving requires the configured, authenticated session.
@MainActor struct ProjectEditLaunchView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View {
        List {
            CYHeroHeader("projectEdit.title")
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            if session.account == nil {
                Section { Text("projectEdit.signIn") }
            }
            Section {
                NavigationLink { SessionPublishingModesView().id(session.publishingSession?.epoch) } label: {
                    CYListRow("publishModes.title", trailing: .none) { CYRowIcon(systemImage: "square.and.pencil") }
                }.accessibilityIdentifier("projectEdit.openPublishingModes")
            }
            Section("projectEdit.title") {
                NavigationLink {
                    ProjectEditView(coordinator: session.projectEditor(product: .city), sessionRevision: session.sessionRevision, publisherClient: session.publisherLifecycleContext?.client, publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) }, cloudDraftProjectsHost: { AnyView(SessionCreatorProjectsView(session: session)) }).id(session.projectEditorContextID)
                } label: { CYListRow("projectEdit.city", trailing: .none) { CYRowIcon(systemImage: "map") } }
                    .accessibilityIdentifier("projectEdit.openCity")
                NavigationLink {
                    ProjectEditView(coordinator: session.projectEditor(product: .freeExplore), sessionRevision: session.sessionRevision, publisherClient: session.publisherLifecycleContext?.client, publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) }, cloudDraftProjectsHost: { AnyView(SessionCreatorProjectsView(session: session)) }).id(session.projectEditorContextID)
                } label: { CYListRow("projectEdit.freeExplore", trailing: .none) { CYRowIcon(systemImage: "location.magnifyingglass") } }
                    .accessibilityIdentifier("projectEdit.openFreeExplore")
            }
            Section {
                NavigationLink { SessionCreatorProjectsView(session: session) } label: { CYListRow("creatorContent.projects", trailing: .none) { CYRowIcon(systemImage: "folder") } }
                    .accessibilityIdentifier("projectRemote.myProjects")
            }
        }.cyHeroScreen()
    }
}
