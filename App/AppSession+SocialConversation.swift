import SwiftUI

extension AppSession {
    /// A2-03 (发消息): the IM chat for an acknowledged `api/im/start` conversation, the same screen the
    /// `subpackageB/pages/im/chat/index` link opens. Injected as `\.socialConversationDestination` by profile hosts.
    var socialConversationDestination: @MainActor (Int) -> AnyView {
        { [unowned self] id in
            AnyView(MessagingHistoryView(conversationID: id, reader: messagingReader, sender: messageSender(for: id),
                                         mediaReader: socialMessageMediaReader, expanded: imExpandedNavigation)
                .id(messagingViewIdentity))
        }
    }
}
