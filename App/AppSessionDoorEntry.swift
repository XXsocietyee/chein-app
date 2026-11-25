import Foundation

extension AppSession {
    /// Anonymous reader for `subpackageRoam/session?shareToken=`; nil (page shows "unavailable") unless the reviewed deployment approves it.
    func makeRoamShareSnapshotReader() -> (any RoamShareSnapshotReading)? {
        RoamShareSnapshotReaderFactory.make(baseURL: regionalConfiguration?.apiConfiguration?.baseURL, transport: runtimeHTTPTransport,
            approval: composition.isRoamShareSnapshotApproved ? { [weak self] in self?.composition.isRoamShareSnapshotApproved == true } : nil)
    }
    var merchantMarketingCoordinator: MerchantMarketingCoordinator {
        if let retainedMarketing { return retainedMarketing }
        let service = MerchantMarketingService(configuration: regionalConfiguration?.apiConfiguration,
            transport: runtimeHTTPTransport, gates: composition.merchantMarketingGates,
            locks: safetyDirectory("MerchantPredictionLocks").map { MerchantPredictionFileLocks(directory: $0) },
            currentSession: { [weak self] in
                guard let self, let account = self.account, let token = self.token, let namespace = self.storageScope?.service else { return nil }
                return try? MerchantMarketingScope(namespace: namespace, accountID: account.id, epoch: self.gate.currentStamp, token: token)
            }, onUnauthorized: { [weak self] captured in
                guard let self, self.account?.id == captured.accountID, self.token == captured.token else { return }
                self.expireIfMatching(error: APIError.unauthorized, stamp: captured.epoch, credential: captured.token)
            })
        let model = MerchantMarketingCoordinator(service: service); retainedMarketing = model; return model
    }
    func prepareDoorRuntime() {
        guard retainedDoorQueue == nil, let configuration = regionalConfiguration?.apiConfiguration, let namespace = storageScope?.service,
              let directory = safetyDirectory("DoorReferralSafety/" + namespace) else { return }
        let service = DoorReferralService(configuration: configuration, transport: runtimeHTTPTransport,
            scanEnabled: false, bindingEnabled: false,
            currentSession: { [weak self] in self?.doorReferralSession ?? DoorReferralSession(accountID: nil, epoch: UUID(), token: nil, restored: false) })
        retainedDoorQueue = DoorReferralQueue(store: DoorReferralFileStore(url: directory.appendingPathComponent("referrals-v1.json")), service: service,
            currentSession: { [weak self] in self?.doorReferralSession ?? DoorReferralSession(accountID: nil, epoch: UUID(), token: nil, restored: false) })
        retainedDoorCoordinator = DoorEntryCoordinator(session: doorReferralSession, service: service)
    }
    var doorReferralQueue: DoorReferralQueue? { prepareDoorRuntime(); return retainedDoorQueue }
    var doorEntryCoordinator: DoorEntryCoordinator? { prepareDoorRuntime(); return retainedDoorCoordinator }
}
