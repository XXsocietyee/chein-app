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
    /// Authenticated reader for `/api/im/ingame/summary` and `/api/im/ingame/resolve`.
    var inGameChannelReader: InGameChannelReader {
        guard let runtime = imRuntimePaths([.inGameChannels]) else {
            return InGameChannelReader(service: nil, session: { nil })
        }
        let (factory, configuration, paths) = runtime
        let captured = factory.captured
        return InGameChannelReader(
            service: InGameChannelService(
                configuration: configuration,
                transport: factory.client([.inGameChannels]),
                enabledPaths: paths
            ),
            session: { [weak self] in
                guard let self, self.currentRuntimeDependencyContext == captured else { return nil }
                return self.currentIMSafetySession
            },
            onUnauthorized: { [weak self] snapshot in
                guard let self, self.currentRuntimeDependencyContext == captured else { return }
                self.expireIfMatching(error: APIError.unauthorized, stamp: snapshot.identity.epoch, credential: self.token)
            }
        )
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
