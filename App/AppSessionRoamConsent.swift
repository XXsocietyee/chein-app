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
