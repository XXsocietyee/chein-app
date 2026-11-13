import Foundation

/// Circle theme (`pages/play/circle/index`) on the session transport that already serves the shipped China
/// composition. Built only when that composition constructed the player grant for this viewer, so fixtures,
/// non-China builds and signed-out viewers keep no circle entry. Offers, card, open/join, answer and record
/// are the player's own non-money writes; `instance/configure` (merchant host write) is not reachable here.
extension AppSession {
    func productionPlayCircle(topicID: Int?) -> PlayCircleCoordinator? {
        guard let topicID, topicID > 0, let context = currentRuntimeDependencyContext,
              composition.playerWriteGrant(context) != nil,
              let api = regionalConfiguration?.apiConfiguration else { return nil }
        let epoch = context.session.epoch, account = context.session.accountID
        return PlayCircleProductionSlots.coordinator(session: self, topicID: topicID, epoch: epoch, accountID: account) {
            let service = PlayExperienceService(configuration: api, transport: self.runtimeHTTPTransport, enabled: [.reads, .circle])
            return PlayCircleCoordinator(topicID: topicID, service: service, currentSession: { [weak self] in
                guard let now = self?.currentRuntimeDependencyContext, now.session.epoch == epoch,
                      now.session.accountID == account else { return nil }
                return now.session
            })
        }
    }
}

/// One coordinator per session, account epoch and topic, so a redraw never forgets an unconfirmed write.
@MainActor enum PlayCircleProductionSlots {
    @MainActor private final class Slot {
        weak var session: AppSession?
        let key: String
        let model: PlayCircleCoordinator
        init(session: AppSession, key: String, model: PlayCircleCoordinator) { self.session = session; self.key = key; self.model = model }
    }
    private static var slots: [Slot] = []

    static func coordinator(session: AppSession, topicID: Int, epoch: some Hashable, accountID: Int,
                            make: () -> PlayCircleCoordinator) -> PlayCircleCoordinator {
        let key = "\(accountID):\(String(describing: epoch)):\(topicID)"
        slots.removeAll { $0.session == nil }
        if let existing = slots.first(where: { $0.session === session && $0.key == key }) { return existing.model }
        let model = make()
        slots.append(Slot(session: session, key: key, model: model))
        return model
    }
}
