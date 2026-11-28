import Foundation

/// Latest home-city consent row. `requestID` stays off `ComplianceConsent` so other scenes keep their decode.
public struct HomeCityLocationConsentBaseline: Equatable {
    public let consent: ComplianceConsent?
    public let requestID: String?
    public init(consent: ComplianceConsent?, requestID: String?) {
        self.consent = consent
        self.requestID = requestID
    }
}

/// Mini-program `createConsentClient` for `privacy_policy` / `home_city_location`, plus the card's ask/hide rule.
public enum HomeCityLocationConsentRecord {
    public static let docType = "privacy_policy"
    public static let scene = "home_city_location"
    /// A blank token or the word UNKNOWN is not a city and not zero.
    public static let unknownDisplay = "—"

    public static func cityLabel(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || trimmed.compare("UNKNOWN", options: .caseInsensitive) == .orderedSame { return unknownDisplay }
        return trimmed
    }

    /// No row means ask. A current agreement or a revoke hides the card. Any other event still asks.
    public static func shouldAsk(_ baseline: HomeCityLocationConsentBaseline) -> Bool {
        guard let consent = baseline.consent else { return true }
        if isRevoke(consent) { return false }
        if isAgreement(consent, requestID: baseline.requestID) { return false }
        return true
    }

    /// `expectedRequestId` the location consent write requires. No row sends an empty id, not a guessed one.
    /// `scene` is `home_city_location` or `roam_location` (E2E-20261112 F3); both share this contract.
    public static func expectedRequestID(_ prior: ComplianceConsent?, rawRequestID: Any?, scene: String = scene) throws -> String {
        guard let prior else {
            guard rawRequestID == nil else { throw ComplianceFailure.malformed }
            return ""
        }
        guard let rawRequestID, let request = rawRequestID as? String else { throw ComplianceFailure.malformed }
        let trimmed = request.trimmingCharacters(in: .whitespacesAndNewlines)
        let version = prior.docVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard prior.docType == docType, prior.scene == scene, prior.scopeType == nil, prior.scopeId == nil,
              prior.eventType == ComplianceEvent.agree.rawValue || prior.eventType == ComplianceEvent.revoke.rawValue,
              !version.isEmpty, !trimmed.isEmpty else { throw ComplianceFailure.malformed }
        return trimmed
    }

    /// Other scenes ignore the raw request id. A location agree (home city or roam) accepts only this request id
    /// and the current policy version.
    public static func acceptsEcho(_ result: ComplianceConsent, subject: ComplianceSubject, event: ComplianceEvent,
                                   requestID: String, rawRequestID: Any?) -> Bool {
        guard subject.isLocationScene, event == .agree else { return true }
        guard let rawRequestID, let echoed = rawRequestID as? String, echoed == requestID else { return false }
        return result.docType == docType && result.scene == subject.scene
            && result.docVersion == UsageConsentDocument.privacyPolicy.currentVersion
    }

    /// mp-home r3 (continue 32): MP `getHomeCityLocation({userInitiated})` (pages/index/index.js:1322-1323) stops
    /// silently on a REVOKE row; any current agreement lets a user tap locate at once.
    public static func isRevoked(_ baseline: HomeCityLocationConsentBaseline) -> Bool {
        guard let consent = baseline.consent else { return false }
        return isRevoke(consent)
    }

    private static func isRevoke(_ consent: ComplianceConsent) -> Bool {
        consent.docType == docType && consent.scene == scene && consent.scopeType == nil && consent.scopeId == nil
            && consent.eventType == ComplianceEvent.revoke.rawValue
    }

    private static func isAgreement(_ consent: ComplianceConsent, requestID: String?) -> Bool {
        let id = requestID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return consent.docType == docType && consent.scene == scene && consent.scopeType == nil && consent.scopeId == nil
            && consent.eventType == ComplianceEvent.agree.rawValue
            && consent.docVersion == UsageConsentDocument.privacyPolicy.currentVersion && !id.isEmpty
    }
}

extension ComplianceSubject {
    /// Location consents whose AGREE carries `expectedRequestId` and reuses an unresolved request id.
    public var isLocationScene: Bool { self == .homeCityLocation || self == .roamLocation }
}
