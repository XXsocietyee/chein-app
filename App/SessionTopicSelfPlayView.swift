import SwiftUI

@MainActor struct SessionTopicSelfPlayView: View {
    @ObservedObject var session: AppSession
    let topic: TopicDetail
    var ticketSource: TopicClubShareLink? = nil
    var body: some View {
        if let flow = session.topicSelfPlayFlow(topic: topic) {
            TopicSelfPlaySheet(flow: flow,
                orders: { AnyView(ProfileOrdersView(reader: session.profileReader, lifecycleCoordinator: session.orderLifecycleCoordinator)) },
                tickets: { AnyView(SessionTicketWalletHost(isPushed: true, focusTopicID: topic.id).environmentObject(session)) },
                play: { AnyView(SessionPlayRuntimeView(session: session, destination: .journey(.topic(topic.id)))) },
                consentService: { session.makeMarketingConsentService() })
                .id(session.sessionRevision)
                .onAppear {
                    flow.ticketAttribution = ticketSource?.topicID == topic.id ? ticketSource : nil
                }
        } else { TopicSelfPlayUnavailableSheet(topic: topic) }
    }
}
