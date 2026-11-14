import Foundation
import SwiftUI

/// Composition root for cross-surface UGC 1.2 safety controls (reporting, user blocking,
/// blocked-content filtering, and moderation prechecks), kept outside `App/AppSession.swift`
/// to preserve the `check_appsession_ratchet` line-count ceiling.
@MainActor
private enum UGCSafetyStoreRegistry {
    private static var stores: [ObjectIdentifier: UGCBlockedUsersStore] = [:]

    static func blockedStore(for session: AppSession) -> UGCBlockedUsersStore {
        let key = ObjectIdentifier(session)
        if let existing = stores[key] {
            return existing
        }
        let store = UGCBlockedUsersStore(defaults: .standard)
        stores[key] = store
        return store
    }
}

extension AppSession {
    func makeUGCSafetyContext() -> UGCSafetyContext {
        let store = UGCSafetyStoreRegistry.blockedStore(for: self)
        let channelStore = ClubSafetyComposition.makeBlockedUsersStore()
        return UGCSafetyContext(
            blockedStore: store,
            channelBlockedStore: channelStore,
            serviceProvider: { [weak self] in
                guard let self, let configuration = self.regionalConfiguration?.apiConfiguration else {
                    return nil
                }
                return UGCContentSafetyHTTPService(
                    configuration: configuration,
                    transport: self.runtimeHTTPTransport
                )
            },
            tokenProvider: { [weak self] in
                self?.token
            },
            accountIDProvider: { [weak self] in
                self?.account?.id
            },
            realmProvider: { [weak self] in
                self?.regionalConfiguration?.apiConfiguration?.baseURL.absoluteString ?? "default"
            }
        )
    }
}
