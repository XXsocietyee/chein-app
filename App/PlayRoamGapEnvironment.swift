import SwiftUI

/// ROAM-9a mount hook: `PlayRoamGapService` (Core/MPGap/PlayRoam/PlayRoamGapService.swift) had no production
/// construction. Built like `playerGapService` (App/PlayerGapViews.swift) from the signed-in runtime context only:
/// the MP sends `POST /api/roam/nearby-runners` for any signed-in walker (pages/roam/index.js:2827-2842).
private struct PlayRoamGapServiceKey: EnvironmentKey { static let defaultValue: PlayRoamGapService? = nil }
extension EnvironmentValues {
    /// Injected once by `SessionRootView`; fixtures and signed-out sessions leave it nil, so runners stay empty.
    var playRoamGapService: PlayRoamGapService? {
        get { self[PlayRoamGapServiceKey.self] }
        set { self[PlayRoamGapServiceKey.self] = newValue }
    }
}

extension AppSession {
    var playRoamGapService: PlayRoamGapService? {
        guard let context = currentRuntimeDependencyContext else { return nil }
        let epoch = context.session.epoch, account = context.session.accountID
        return PlayRoamGapService(baseURL: context.baseURL, token: { [weak self] in
            guard let now = self?.currentRuntimeDependencyContext, now.session.epoch == epoch,
                  now.session.accountID == account else { return nil }
            return now.session.token
        }, transport: runtimeHTTPTransport)
    }
}
