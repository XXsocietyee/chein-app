import SwiftUI

/// Screens opened when a notification tap carries a subscribe-message `page` that public hengyin
/// actually sends. `MPNotificationTapRouter` still owns the tap. Types with an empty template id
/// are not cases here.
@MainActor struct SubscribeMessageTapEntry: View {
    let route: MPParityRoute
    @EnvironmentObject private var session: AppSession

    var body: some View {
        switch route {
        case .playerOrderList:
            ProfileOrdersView(reader: session.profileReader, lifecycleCoordinator: session.orderLifecycleCoordinator, ticketReader: session.ticketWalletReader)
        case .coopList(let direction):
            CooperationBrowserView(reader: session.cooperationReader, onClose: { session.dismissNativeEntry() },
                                   peerReader: session.cooperationFlowReader, initialDirection: direction,
                                   topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) })
        case .myProjects:
            SubscribeMessageProjectsEntry(session: session)
        case .merchantLedger:
            MerchantLedgerSettlementOverview(reader: session.merchantBusinessReader)
        default:
            CYEmptyState(systemImage: "tray", "mp.route.unavailable", messageIdentifier: "mp.route.unavailable")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// `subpackageA/pages/myproject/index`. The list is the existing projects screen. Opening a row uses
/// the same topic, activity, and template screens the publish hub already uses. Registration stays off.
@MainActor struct SubscribeMessageProjectsEntry: View {
    @ObservedObject var session: AppSession
    @State private var resource: PublishedResource?

    var body: some View {
        PublishingProjectsView(service: session.publishingService, account: session.publishingSession, openResource: { resource = $0 })
            .navigationDestination(item: $resource) { destination in
                switch destination.kind {
                case .topic:
                    SessionTopicDetailView(id: destination.value, session: session).id(session.topicReader.scope)
                case .activity:
                    ActivityDetailView(id: destination.value, reader: session, registrationEnabled: true)
                        .toolbar {
                            PublisherLifecycleNavigationLink(session: session, resource: destination)
                            if let editor = session.activityEditingController(id: destination.value) {
                                NavigationLink {
                                    ActivityEditingView(owner: editor, makeActivityCover: { session.makeActivityCoverService() }).id(session.publishingSession?.epoch)
                                } label: {
                                    Text("entry", tableName: "ActivityEditing")
                                }.accessibilityIdentifier("activityEdit.entry")
                            }
                        }
                case .template:
                    DiscoveryTemplateDetailView(id: destination.value, reader: session,
                        authoringFactory: { session.templateAuthoringEditor(adopting: $0) },
                        authoringRevision: session.sessionRevision).id(session.templateAuthoringViewIdentity)
                }
            }
            .onChange(of: session.publishingSession) { _, _ in
                session.publishingService?.invalidateReviews()
                resource = nil
            }
    }
}
