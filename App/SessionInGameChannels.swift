import SwiftUI

/// Environment dependency carrying everything needed to summarize, resolve, and
/// present an in-game IM channel without coupling feature screens to `AppSession`.
@MainActor struct InGameChannelHost {
    let reader: any InGameChannelReading
    let messagingReader: any MessagingReading
    let messageSender: @MainActor (Int) -> MessageActionCoordinator?
    let mediaReader: (any SocialMessageMediaReading)?
    let expanded: IMExpandedNavigationContext?
    let viewIdentity: @MainActor () -> String
}

private struct InGameChannelHostKey: EnvironmentKey {
    static let defaultValue: InGameChannelHost? = nil
}

extension EnvironmentValues {
    var inGameChannelHost: InGameChannelHost? {
        get { self[InGameChannelHostKey.self] }
        set { self[InGameChannelHostKey.self] = newValue }
    }
}

extension AppSession {
    /// In-game channels have no MP feature and no backend route (`/api/im/ingame/*` dropped);
    /// the reader stays unconfigured so game screens hide the channel entry.
    var inGameChannelReader: InGameChannelReader {
        InGameChannelReader(service: nil, session: { nil })
    }

    /// Host bundle injected into Activity, Play, Roam, and City game screens.
    var inGameChannelHost: InGameChannelHost {
        InGameChannelHost(
            reader: inGameChannelReader,
            messagingReader: messagingReader,
            messageSender: { [weak self] conversationID in self?.messageSender(for: conversationID) },
            mediaReader: socialMessageMediaReader,
            expanded: imExpandedNavigation,
            viewIdentity: { [weak self] in self?.messagingViewIdentity ?? "signed-out" }
        )
    }
}
