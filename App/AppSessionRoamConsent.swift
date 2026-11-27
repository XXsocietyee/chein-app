import Foundation

extension AppSession {
    /// E2E-20261112 F3: the server refuses `/api/roam/reveal` until `roam_location` AGREE is on record.
    /// Nil unless the reviewed deployment enables account compliance.
    func roamLocationConsentHook() -> (@MainActor () async throws -> Void)? {
        guard composition.isAccountComplianceEnabled else { return nil }
        return { [weak self] in
            guard let coordinator = self?.accountComplianceCoordinator else { throw ComplianceFailure.unavailable }
            try await coordinator.ensureRoamLocationAgree()
        }
    }
}

extension AppSession {
    /// ROAM-r11-6: wipe this device's settled roam history for the signed-in player. False = storage refused.
    func clearRoamLocalHistory() -> Bool {
        (try? roamHistoryStoreForClear.clearAll()) != nil
    }
}

/// Roam privacy effects for the reviewed deployment: server readback, then stop, then clear.
@MainActor final class ReviewedComplianceRoamEffects: ComplianceRoamEffects {
    weak var session: AppSession?
    init(session: AppSession) { self.session = session }
    func stopTracking() async throws {
        session?.invalidatePersonalLocationShare()
        // OWN-D-07.e: a withdrawn roam consent also ends the roam session-location hold.
        SessionBackgroundLocationTracker.shared.ledger.revoke(.roam)
    }
    func clearMapPrivacy() async throws {
        session?.invalidatePersonalLocationShare()
        // A withdrawn roam consent asks again on the next GO instead of silently re-agreeing (RoamLiveSessionView).
        UserDefaults.standard.removeObject(forKey: "roamLivePurposeAcceptedV1")
    }
    func invalidateMapPrivacyCaches() {
        session?.invalidatePersonalLocationShare()
    }
}

/// ROAM-r11-6: the same per-account pending mark as `RoamShareRevokeRow`, for 清空本机缓存 (MP prepareShareRevocation).
enum RoamShareRevokePending {
    static func key(_ accountID: Int) -> String { "roam.share.revokePending.\(accountID)" }
    static func mark(_ pending: Bool, accountID: Int) { UserDefaults.standard.set(pending, forKey: key(accountID)) }
}
