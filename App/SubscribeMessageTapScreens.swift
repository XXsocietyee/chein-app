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
            // FIN-16-4: one host for 我的订单, whatever the entry (account row, notification, deep link).
            SessionOwnedOrdersView(session: session)
        case .coopList(let direction):
            CooperationBrowserView(reader: session.cooperationReader, onClose: { session.dismissNativeEntry() },
                                   peerReader: session.cooperationFlowReader, initialDirection: direction,
                                   topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) })
        case .myProjects:
            SubscribeMessageProjectsEntry(session: session)
        case .merchantLedger:
            MerchantLedgerSettlementOverview(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal)
        case .merchantLedgerSettlement:
            MerchantLedgerSettlementOverview(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal,
                                             initialView: .settlements)
        default:
            CYEmptyState(systemImage: "tray", "mp.route.unavailable", messageIdentifier: "mp.route.unavailable")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// `subpackageA/pages/myproject/index`. PC-D-1-1: the link opens the same 我的项目 screen as the in-app entry
/// (`SessionCreatorProjectsView`: covers, tabs, row ops menu), not the older publishing list.
@MainActor struct SubscribeMessageProjectsEntry: View {
    @ObservedObject var session: AppSession

    var body: some View {
        SessionCreatorProjectsView(session: session)
    }
}
