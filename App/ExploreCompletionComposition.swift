import Foundation
import SwiftUI

/// R11-MEM-17-1: MP scene-member-order-detail/index.js:833-835 reads `/api/registration/explore-completion`
/// for a paid explore order and index.wxml:289-311 shows 探店图鉴 stamps and 通关奖励 awards.
/// The lease is issued only when the reviewed deployment enables production gates.
extension AppCompositionRoot {
    func exploreCompletionReadApproval(_ context: RuntimeDependencyContext) -> ExploreCompletionReadApproval? {
        guard reviewed?.productionGatesEnabled == true else { return nil }
        return productionGateLeases.exploreCompletion(context)
    }
}

/// One stable reader per session and lease, so the provider owner (reader identity) stays the same across renders.
@MainActor final class ExploreCompletionReaderStore {
    static var entries: [ObjectIdentifier: (approval: ExploreCompletionReadApproval, reader: ExploreCompletionSessionReader)] = [:]
}

@MainActor extension AppSession {
    /// Modelled on `freeExploreBundleReadProvider`: bound to the fresh owned-order session and the same runtime context.
    var exploreCompletionProvider: ExploreCompletionProvider? {
        guard let context = currentRuntimeDependencyContext, let originSession = currentOwnedOrderSession,
              let approval = composition.exploreCompletionReadApproval(context), approval.matches(context),
              let reader = exploreCompletionReader(context: context, approval: approval) else { return nil }
        return ExploreCompletionProvider(origin: ownedOrderReader, originSession: originSession,
                                         currentOrigin: { [weak self] in self?.currentOwnedOrderSession }, reader: reader)
    }

    func exploreCompletionReader(context: RuntimeDependencyContext,
                                 approval: ExploreCompletionReadApproval) -> ExploreCompletionSessionReader? {
        let key = ObjectIdentifier(self)
        if let cached = ExploreCompletionReaderStore.entries[key], cached.approval === approval,
           cached.reader.matches(context: context) { return cached.reader }
        guard let api = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        let reader = ExploreCompletionSessionReader(configuration: api, http: compositionTransport, approval: approval,
            current: { [weak self] in self?.currentRuntimeDependencyContext },
            onUnauthorized: { [weak self] captured in
                self?.expireIfMatching(error: APIError.unauthorized, stamp: captured.session.epoch, credential: captured.session.token)
            })
        ExploreCompletionReaderStore.entries[key] = (approval, reader)
        return reader
    }
}
