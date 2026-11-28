import SwiftUI

/// A normal render is not a new messaging issuance. Keep the exact factory
/// reader until the session object or its authorization-bound view key changes.
/// This does not extend its live permission or replace the reader's own fences.
@MainActor final class SessionMessagingHomeReaderOwner: ObservableObject {
    private weak var session: AppSession?
    private var issuance: String?
    private var retained: MessagingSessionReader?

    func reader(for session: AppSession) -> MessagingSessionReader {
        let current = session.messagingViewIdentity
        if self.session === session, issuance == current, let retained { return retained }
        self.session = session
        issuance = current
        let reader = session.messagingReader
        retained = reader
        return reader
    }
}

/// The full session messaging home, as opened from 我的→消息. Shared so other
/// source entry points (club tab 站内消息 icon) open the identical page.
@MainActor struct SessionMessagingHome: View {
    @ObservedObject var session: AppSession
    @StateObject private var readerOwner = SessionMessagingHomeReaderOwner()
    @StateObject private var inviteReminder = IMInviteReminderController()
    @State private var showsFriends = false
    @State private var showsReportResults = false
    var body: some View {
        MessagingHomeView(reader: readerOwner.reader(for: session), mediaReader: session.socialMessageMediaReader,
            senderForConversation: { session.messageSender(for: $0) }, expanded: session.imExpandedNavigation,
            squareDestination: { close in AnyView(SessionSquareBrowserView(session: session, onClose: nil, onSignIn: close, embedsNavigationStack: false).id(session.squareReader.scope).cyPushedChrome()) },
            predictionEntry: { AnyView(SessionMerchantPredictionEntry(session: session)) },
            merchantChrome: session.account?.role == "merchant")
            .id(session.messagingViewIdentity)
            .environment(\.imCoopInviteStrip, IMCoopInviteStripFactory.make(reader: session.cooperationReader))
            // Local preference plus the notification primer. No server write and no push topic.
            .environment(\.imInviteReminder, inviteReminder)
            .environment(\.imReportProgressDestination, { AnyView(SquareReportProgressView(session: session)) })
            // Friends and report results share one … menu so the trailing toolbar stays short.
            // Both stay reachable even when the conversation/history reader is unavailable.
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showsFriends = true } label: {
                            Label { Text("friend.title", tableName: "NativeFriend") } icon: { Image(systemName: "person.2") }
                        }
                        .accessibilityIdentifier("friend.entry")
                        Button { showsReportResults = true } label: {
                            Label { Text("d7.messagingHome.reportResults") } icon: { Image(systemName: "clock.arrow.circlepath") }
                        }
                        .accessibilityIdentifier("channel.reportRecovery.normalEntry")
                    } label: {
                        Label { Text("d7.messagingHome.more") } icon: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
            .navigationDestination(isPresented: $showsFriends) { NativeFriendSessionDestination(session: session) }
            .navigationDestination(isPresented: $showsReportResults) { NativeChannelReportRecoveryEntry(session: session) }
    }
}

/// 站内消息 bell with the `unread-total` badge. Design hand-off r1 PL-11: the first trailing action on every tab root (was top-left, P-13).
/// Only for a signed-in account; the badge stays hidden unless its read is granted.
@MainActor struct SessionMessagingToolbarEntry: ViewModifier {
    @ObservedObject var session: AppSession
    func body(content: Content) -> some View {
        content.toolbar {
            // Design hand-off r1 PL-11: 消息 is the first trailing action, in the same place on all five tab roots.
            ToolbarItem(placement: .topBarTrailing) {
                if session.account != nil {
                    NavigationLink { SessionMessagingHome(session: session).cyPushedChrome() } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "bell")
                            IMUnreadEntryBadge(reader: session.imUnreadTotalReader)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("im.entry.inbox"))
                    }
                    .accessibilityIdentifier("im.entry.toolbar")
                }
            }
        }
    }
}
