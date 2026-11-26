import SwiftUI

/// The one session host for the 票夹 (MP `subpackageMember/signup/index`). Every wallet entry (我的, home today
/// tickets, topic page, participation, activity, deep link) goes through it, so each one gets the same play entry
/// (开始游戏, PLY-21-3), the same pending-order route, a working 登录 (PLY-21-7) and focus by topic or registration
/// (PLY-21-2). Reads and gates are unchanged: the providers still match the reader and session revision before use.
@MainActor struct SessionTicketWalletHost: View {
    @EnvironmentObject private var session: AppSession
    /// Sheet hosts pass a close action; pushed hosts leave it nil and set `isPushed`.
    var onClose: (() -> Void)? = nil
    var isPushed = false
    var focusTopicID: Int? = nil
    var focusRegistrationID: Int? = nil
    @State private var login = false
    @Environment(\.rootTabSwitch) private var rootTabSwitch

    /// PLY-21-7: MP「+ 去探索主题」is `wx.switchTab('/pages/index/index')` (signup/index.js:701).
    /// Only the root TabView installs a live switch, so hosts outside it keep the button hidden.
    private var explore: (() -> Void)? {
        guard rootTabSwitch.isAvailable else { return nil }
        let close = onClose, select = rootTabSwitch
        return { close?(); select(.home) }
    }

    var body: some View {
        TicketWalletView(reader: session.ticketWalletReader, onClose: onClose, onSignIn: { login = true },
                         makeTeamCoordinator: { session.makeTeamCoordinator() },
                         orderLifecycleCoordinator: session.orderLifecycleCoordinator,
                         onExplore: explore,
                         focusTopicID: focusTopicID, focusRegistrationID: focusRegistrationID, isPushed: isPushed)
            .environment(\.ticketWalletPlayProvider, SessionTicketWalletProviders.play(session))
            .environment(\.ticketWalletPendingOrderProvider, SessionTicketWalletProviders.pendingOrder(session))
            .id(session.ticketWalletReader.scope)
            .cySheet(isPresented: $login) { LoginView(intent: .player) }
            .onChange(of: session.sessionRevision) { _, _ in login = false }
    }
}

/// Shared provider factories, so the pass sheet and every wallet host build the same play destination.
@MainActor enum SessionTicketWalletProviders {
    static func play(_ session: AppSession) -> TicketWalletPlayProvider {
        TicketWalletPlayProvider(reader: session.ticketWalletReader, revision: session.sessionRevision,
            currentRevision: { session.sessionRevision }) { entry in
            AnyView(SessionPlayRuntimeView(session: session, destination: .journey(entry.scope))
                .environment(\.playThemeAuxiliaryProvider, session.playThemeAuxiliaryProvider)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            TicketWalletDetailView(id: entry.registrationID, reader: session.ticketWalletReader)
                                .environment(\.ticketWalletPlayProvider, nil)
                                .id(session.ticketWalletReader.scope)
                        } label: { Label("ticketWallet.detail", systemImage: "ticket") }
                        .accessibilityIdentifier("ticketWallet.play.ticket")
                    }
                })
        }
    }

    static func pendingOrder(_ session: AppSession) -> TicketWalletPendingOrderProvider {
        TicketWalletPendingOrderProvider(reader: session.ticketWalletReader, coordinator: session.orderLifecycleCoordinator,
            revision: session.sessionRevision, currentRevision: { session.sessionRevision })
    }
}
