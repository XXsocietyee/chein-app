import Foundation

/// ROAM-r11-9 发到广场 from the walk share card (MP pages/roam/index.js:5136-5233).
/// Request ids live in `intents` for the app run (keyed by account inside); the poster is rebuilt when
/// the session object or the region's base URL changes. Kept out of AppSession.swift (line ratchet).
@MainActor final class RoamSquareShareHolder {
    static let shared = RoamSquareShareHolder()
    let intents = RoamSquareShareIntents()
    var poster: RoamSquareSharePoster?
    var baseURL: URL?
    var owner: ObjectIdentifier?
}

extension AppSession {
    var roamSquareShare: RoamSquareSharePoster? {
        guard let configuration = regionalConfiguration?.apiConfiguration else { return nil }
        let holder = RoamSquareShareHolder.shared
        if holder.poster == nil || holder.baseURL != configuration.baseURL || holder.owner != ObjectIdentifier(self) {
            let service = SquareWorkspaceService(configuration: configuration, transport: runtimeHTTPTransport)
            holder.poster = RoamSquareSharePoster(service: service,
                identity: { [weak self] in
                    guard let self, let account = self.account, let token = self.token else { return nil }
                    return RoamSquareSharePoster.Identity(accountID: account.id, token: token)
                },
                communityWrite: { [weak self] in
                    guard let self else { return false }
                    return (try? await self.squareReader.communityFeatures())?.write == true
                },
                intents: holder.intents)
            holder.baseURL = configuration.baseURL; holder.owner = ObjectIdentifier(self)
        }
        return holder.poster
    }
}
