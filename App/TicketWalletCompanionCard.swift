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
    private var cover: URL? {
        guard let url = URL(string: seat.coverURL), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let cover {
                    AsyncImage(url: cover) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { CYColor.bgSurfaceStrong }
                    }
                    .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                    .clipped()
                    .accessibilityHidden(true)
                } else {
                    ZStack(alignment: .topTrailing) {
                        LinearGradient(colors: [CYColor.gameAccent.opacity(0.55), CYColor.bgSurfaceStrong],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        MPAsset.BannerCover.coverRoute.resizable().scaledToFit().frame(width: 100, height: 100)
                            .opacity(0.35).offset(x: 70, y: -10).accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                    .clipped()
                    .accessibilityHidden(true)
                }
                CYStatusChip("ticketWallet.companion.type", tone: .info)
                    .padding(CYSpacing.md)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: seat.title.isEmpty ? "—" : seat.title)
                    .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                if !seat.usableUntil.isEmpty {
                    Text(verbatim: seat.usableUntil).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                if let scope {
                    NavigationLink {
                        SessionPlayRuntimeView(session: session, destination: .journey(scope))
                            .environment(\.playThemeAuxiliaryProvider, session.playThemeAuxiliaryProvider)
                    } label: {
                        Label { Text("playerJourney.start") } icon: { TicketWalletPlayGlyph() }
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.cyPrimary(fullWidth: true))
                    .accessibilityIdentifier("ticketWallet.companion.play.\(seat.invitationID)")
                }
            }
            .padding(CYSpacing.md)
        }
        .background(CYColor.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ticketWallet.companion.\(seat.invitationID)")
    }
}
