import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// R11-MEM-17-2: MP order detail 查看记录 (scene-member-order-detail/index.wxml:358-360, `startPlay` index.js:559-569).
/// `resolvePrimaryCta` (index.js:187-194) returns 'record' only for a registered (2), paid (2), completed explore order
/// (purchaseKind 3, index.js:279-289) with an owner id (`playQuery`, index.js:204-212). `ticketHasGame`
/// (subpackageMember/utils/ticket-game.js) treats a missing activity projection as having a game, so it adds no check here.
/// The link opens play the way the ticket wallet does (`TicketWalletCompanionCard`).
struct ProfileOrderRecordSection: View {
    let order: ProfileOrder
    @EnvironmentObject private var session: AppSession

    static func scope(for order: ProfileOrder) -> PlaySessionScope? {
        guard order.registrationStatus == 2, order.paymentStatus == 2, order.purchaseKind == 3,
              order.historyState() == .completed, order.id > 0,
              let owner = order.ownerID, owner > 0 else { return nil }
        return order.ownerType == 2 ? .activity(owner) : .topic(owner)
    }

    var body: some View {
        if let scope = Self.scope(for: order) {
            Section {
                NavigationLink {
                    SessionPlayRuntimeView(session: session, destination: .journey(scope))
                        .environment(\.playThemeAuxiliaryProvider, session.playThemeAuxiliaryProvider)
                } label: {
                    Label("playerJourney.viewRecord", systemImage: "clock.arrow.circlepath")
                }
                .accessibilityIdentifier("profile.order.viewRecord")
            }
        }
    }
}
