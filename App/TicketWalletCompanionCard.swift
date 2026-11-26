import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// R8-MEM-21-1: MP signup merges claimed companion seats into the deck as 同伴席位 cards
/// (`subpackageMember/signup/index.js:293-300`). They show no entry code (index.js:374, the code belongs to
/// the buyer's order), and 开始游戏 opens play with `entry=ticket` and no `registrationId` (index.js:246-247):
/// the play page checks the claimed seat with the server.
@MainActor struct TicketWalletCompanionCard: View {
    let seat: WalletSeatInvitation
    @EnvironmentObject private var session: AppSession

    private var scope: PlaySessionScope? {
        guard let owner = Int(seat.ownerID), owner > 0 else { return nil }
        return seat.ownerType == 2 ? .activity(owner) : .topic(owner)
    }

    /// native-r2: a plain list row (Wallet-style pass row), no card chrome. MP image via the seat cover only.
    var body: some View {
        Group {
            LabeledContent {
                Text("ticketWallet.companion.type")
            } label: {
                Text(verbatim: seat.title.isEmpty ? "—" : seat.title)
                if !seat.usableUntil.isEmpty {
                    Text(verbatim: seat.usableUntil)
                }
            }
            .accessibilityIdentifier("ticketWallet.companion.\(seat.invitationID)")
            if let scope {
                NavigationLink {
                    SessionPlayRuntimeView(session: session, destination: .journey(scope))
                        .environment(\.playThemeAuxiliaryProvider, session.playThemeAuxiliaryProvider)
                } label: {
                    Label("playerJourney.start", systemImage: "play.fill")
                }
                .accessibilityIdentifier("ticketWallet.companion.play.\(seat.invitationID)")
            }
        }
    }
}
