import Foundation

/// Mini-program app.js + utils/compliance/usage-consent.js: before sign-in the user sees a
/// privacy gate (暂不同意 / 同意并继续) with an unchecked agreement checkbox. Agreeing stores
/// the document versions locally; declining keeps guest browsing without any sign-in.
/// A version bump makes the stored choice stale, so the gate shows again.
public enum UsageConsentDocument: String, CaseIterable, Codable {
    case privacyPolicy = "privacy_policy"
    case userServiceAgreement = "user_service_agreement"

    /// Versions the mini-program stores (cy_usage_choice_v1) and the server whitelists for
    /// scene app_launch. The server remains authoritative and rejects a stale version.
    public var currentVersion: String {
        switch self {
        case .privacyPolicy: return "v2.1"
        case .userServiceAgreement: return "v2.2"
        }
    }
}

public protocol UsageConsentStorage: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Data?, forKey key: String)
}

/// Mini-program privacy page when agree cannot be recorded because the viewer is signed out.
public enum UsageConsentOfflineRecord: Equatable, Sendable {
    public static let signedOutCopy = "已同意，联网后会自动补记同意记录"
    case none
    case owedWhileSignedOut
}

public enum UsageConsentFailure: Error, Equatable {
    /// Mini-program: 请先阅读并勾选用户服务协议
    case agreementNotChecked
}

/// One AGREE record per document for scene app_launch, with a request ID that stays
/// stable across relaunches until the server confirms it (uncertain outcomes reuse it).
public struct UsageConsentRecordRequest: Equatable {
    public let accountID: Int
    public let document: UsageConsentDocument
    public let requestID: String
    public let scene = "app_launch"
    public let eventType = "AGREE"
}

public final class UsageConsentPolicy {
    static let choiceKey = "questify.usageConsent.choice.v1"
    static func pendingKey(accountID: Int) -> String { "questify.usageConsent.pending.v1." + String(accountID) }

    /// Live recording goes through /api/compliance/consents, which is not on the reviewed
    /// per-market endpoint allowlist. Until it is, records are planned but never dispatched.
    public static let liveRecordingApproved = false

    private let storage: UsageConsentStorage
    private let makeRequestID: () -> String
    public init(storage: UsageConsentStorage, makeRequestID: @escaping () -> String = { "consent-" + UUID().uuidString.lowercased() }) {
        self.storage = storage; self.makeRequestID = makeRequestID
    }

    private var storedChoice: [String: String]? {
        guard let data = storage.data(forKey: Self.choiceKey) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// Granted only when every current document version matches what was agreed.
    public var granted: Bool {
        guard let choice = storedChoice else { return false }
        return UsageConsentDocument.allCases.allSatisfy { choice[$0.rawValue] == $0.currentVersion }
    }

    public func agree(agreementChecked: Bool) throws {
        guard agreementChecked else { throw UsageConsentFailure.agreementNotChecked }
        let choice = Dictionary(uniqueKeysWithValues: UsageConsentDocument.allCases.map { ($0.rawValue, $0.currentVersion) })
        storage.set(try? JSONEncoder().encode(choice), forKey: Self.choiceKey)
    }

    /// Mini-program declineUsageConsent removes the stored choice; browsing stays available.
    public func decline() { storage.set(nil, forKey: Self.choiceKey) }

    /// Records still owed to the server for this account. Request IDs persist per account and
    /// document, so a lost response is retried with the same ID instead of a new record.
    public func pendingRecords(accountID: Int) -> [UsageConsentRecordRequest] {
        guard granted, accountID > 0 else { return [] }
        var ids = pendingIDs(accountID: accountID)
        var changed = false
        let requests = UsageConsentDocument.allCases.map { document -> UsageConsentRecordRequest in
            if ids[document.rawValue] == nil { ids[document.rawValue] = makeRequestID(); changed = true }
            return UsageConsentRecordRequest(accountID: accountID, document: document, requestID: ids[document.rawValue]!)
        }
        if changed { storage.set(try? JSONEncoder().encode(ids), forKey: Self.pendingKey(accountID: accountID)) }
        return requests.filter { !confirmed(accountID: accountID).contains($0.document.rawValue) }
    }

    /// Only an exact server echo of the same request ID, document, scene and current version confirms.
    public func confirm(_ request: UsageConsentRecordRequest, echoedRequestID: String?, echoedDocType: String?,
                        echoedScene: String?, echoedVersion: String?) -> Bool {
        guard echoedRequestID == request.requestID, echoedDocType == request.document.rawValue,
              echoedScene == request.scene, echoedVersion == request.document.currentVersion else { return false }
        var ids = pendingIDs(accountID: request.accountID)
        ids["confirmed." + request.document.rawValue] = request.requestID
        storage.set(try? JSONEncoder().encode(ids), forKey: Self.pendingKey(accountID: request.accountID))
        return true
    }

    private func pendingIDs(accountID: Int) -> [String: String] {
        guard let data = storage.data(forKey: Self.pendingKey(accountID: accountID)) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
    private func confirmed(accountID: Int) -> Set<String> {
        Set(pendingIDs(accountID: accountID).keys.filter { $0.hasPrefix("confirmed.") }.map { String($0.dropFirst("confirmed.".count)) })
    }
}

/// Decides whether the launch gate is shown. Signed-in restorations are not interrupted;
/// declining once keeps the gate closed until the next launch or an explicit sign-in attempt.
public enum UsageConsentGateDecision {
    public static func showAtLaunch(granted: Bool, signedIn: Bool, declinedThisLaunch: Bool) -> Bool {
        !granted && !signedIn && !declinedThisLaunch
    }
    public static func signInRequiresGate(granted: Bool) -> Bool { !granted }
}

/// pages/privacy/index consent record. The device choice stays on `UsageConsentPolicy`.
/// The roam-location row is read through the existing latest-consent contract.
/// A missing route stays hidden and is not marked live. Unknown numbers are an em dash.
public enum PrivacyProtectionNumberFact: Equatable, Sendable {
    case unknown
    case value(Int)

    public static let unknownDisplay = "—"

    public var literal: Int? {
        if case .value(let number) = self { return number }
        return nil
    }

    public var displayText: String {
        switch self {
        case .unknown: return Self.unknownDisplay
        case .value(let number): return String(number)
        }
    }

    /// A canonical integer, including 0, stays a value. UNKNOWN, blank, and a padded or
    /// fractional token stay unknown. Nothing here substitutes 0.
    public static func parse(_ token: String?) -> PrivacyProtectionNumberFact {
        guard let token else { return .unknown }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), String(value) == trimmed else { return .unknown }
        return .value(value)
    }
}

public enum PrivacyProtectionPageAccessibility {
    public static let title = "privacy.page.title"
    public static let body = "privacy.page.body"
    public static let guide = "authEntry.privacy.guide"
    public static let agreement = "authEntry.privacy.agreement"
    public static let offlineSignedOut = "usageConsent.offline.signedOut"
    public static let guideUnavailable = "privacy.page.guideUnavailable"
    /// mp-settings r3: MP pages/privacy settled-state controls (首页城市自动定位 · 附近的人 · 漫游定位 · 待审媒体).
    public static let moreSettings = "privacy.page.moreSettings"
    public static let consentStatus = "authEntry.privacy.consentStatus"
    public static let consentGranted = "privacy.page.consentGranted"
    public static let consentMissing = "privacy.page.consentMissing"
    public static let consentWithdrawn = "privacy.page.consentWithdrawn"
    public static let manage = "privacy.page.manage"
    public static let withdrawConsent = "authEntry.privacy.withdrawConsent"
    public static let revoke = "privacy.page.revoke"
    public static let collectionScopeTitle = "privacy.guide.collection_scope.title"
    public static let collectionScopeDetail = "privacy.guide.collection_scope.detail"
    public static let permissionUsageTitle = "privacy.guide.permission_usage.title"
    public static let permissionUsageDetail = "privacy.guide.permission_usage.detail"
    public static let revokeAndDeregisterTitle = "privacy.guide.revoke_and_deregister.title"
    public static let revokeAndDeregisterDetail = "privacy.guide.revoke_and_deregister.detail"
    public static let loading = "privacy.page.state.loading"
    public static let empty = "privacy.page.state.empty"
    public static let error = "privacy.page.state.error"
    public static let unknown = "privacy.page.state.unknown"
    public static let ready = "privacy.page.state.ready"
    public static let summaryItems = "privacy.guide.summaryItems"
}

public struct PrivacyProtectionPageFailure: Equatable, Sendable {
    public let token: String
    public init(token: String) { self.token = token }
}

public struct PrivacyProtectionPageSnapshot: Equatable, Sendable {
    public let deviceAgreementGranted: Bool
    public let serverConsentHidden: Bool
    public let roamLocationEvent: String?
    public let usageRecordHistoryHidden: Bool
    public var showsDeviceWithdrawal: Bool { deviceAgreementGranted }
}

public enum PrivacyProtectionPagePhase: Equatable, Sendable {
    case loading
    case empty
    case error(PrivacyProtectionPageFailure)
    case unknown
    case ready(PrivacyProtectionPageSnapshot)

    public var accessibilityIdentifier: String {
        switch self {
        case .loading: return PrivacyProtectionPageAccessibility.loading
        case .empty: return PrivacyProtectionPageAccessibility.empty
        case .error: return PrivacyProtectionPageAccessibility.error
        case .unknown: return PrivacyProtectionPageAccessibility.unknown
        case .ready: return PrivacyProtectionPageAccessibility.ready
        }
    }
}

@MainActor public protocol PrivacyProtectionLatestConsentReading: AnyObject {
    func latestRoamConsent(session: ComplianceSession) async throws -> ComplianceConsent?
}

extension AccountComplianceService: PrivacyProtectionLatestConsentReading {
    public func latestRoamConsent(session: ComplianceSession) async throws -> ComplianceConsent? {
        try await latest(.roamLocation, session: session)
    }
}

@MainActor public final class PrivacyProtectionPageModel {
    public private(set) var phase: PrivacyProtectionPagePhase = .loading
    public private(set) var serverConsentHidden = true
    private let policy: UsageConsentPolicy
    private let consent: (any PrivacyProtectionLatestConsentReading)?
    private let session: () -> ComplianceSession?
    private var generation: UInt64 = 0
    private var lastConsent: ComplianceConsent?

    public init(policy: UsageConsentPolicy, consent: (any PrivacyProtectionLatestConsentReading)? = nil,
                session: @escaping () -> ComplianceSession? = { nil }) {
        self.policy = policy
        self.consent = consent
        self.session = session
    }

    public var deviceAgreementGranted: Bool { policy.granted }

    /// Usage-record history is hidden while that route is missing. This does not mark it live.
    public static var usageRecordHistoryHidden: Bool {
        ChinaReviewedRouteCapability.mark(for: UsageConsentReadRoute.history) != .liveInProduction
    }

    public static var latestConsentRouteIsLive: Bool {
        ChinaReviewedRouteCapability.mark(for: PlayStoreDayService.consentLatestPath) == .liveInProduction
    }

    public var usageRecordHistoryHidden: Bool { Self.usageRecordHistoryHidden }

    /// Nil while the usage-record route is missing, including when the fact is 0 or unknown.
    public func usageRecordCountText(_ fact: PrivacyProtectionNumberFact) -> String? {
        guard !Self.usageRecordHistoryHidden else { return nil }
        return fact.displayText
    }

    public func reload() async {
        generation &+= 1
        let stamp = generation
        phase = .loading
        guard let consent, let session = session(), session.valid, Self.latestConsentRouteIsLive else {
            apply(consent: nil, serverHidden: true)
            return
        }
        do {
            let latest = try await consent.latestRoamConsent(session: session)
            guard stamp == generation else { return }
            guard !Task.isCancelled, self.session() == session else {
                fail("failed")
                return
            }
            apply(consent: latest, serverHidden: false)
        } catch let error as ComplianceFailure {
            guard stamp == generation else { return }
            if case .unavailable = error {
                apply(consent: nil, serverHidden: true)
            } else {
                fail(Self.token(for: error))
            }
        } catch {
            guard stamp == generation else { return }
            fail("failed")
        }
    }

    /// Local device withdrawal only. App-launch recording stays off, so this does not post a consent.
    public func withdrawDeviceConsent() {
        guard policy.granted else { return }
        policy.decline()
        switch phase {
        case .loading, .error, .unknown:
            return
        case .empty, .ready:
            apply(consent: lastConsent, serverHidden: serverConsentHidden)
        }
    }

    private func apply(consent: ComplianceConsent?, serverHidden: Bool) {
        lastConsent = consent
        serverConsentHidden = serverHidden
        if let consent {
            phase = classify(consent)
            return
        }
        phase = policy.granted ? .ready(snapshot(event: nil, serverHidden: serverHidden)) : .empty
    }

    private func classify(_ consent: ComplianceConsent) -> PrivacyProtectionPagePhase {
        let agreed = consent.matches(.roamLocation, event: .agree)
        let revoked = consent.matches(.roamLocation, event: .revoke)
        guard agreed != revoked, let event = consent.eventType else { return .unknown }
        return .ready(snapshot(event: event, serverHidden: false))
    }

    private func snapshot(event: String?, serverHidden: Bool) -> PrivacyProtectionPageSnapshot {
        .init(deviceAgreementGranted: policy.granted, serverConsentHidden: serverHidden,
              roamLocationEvent: event, usageRecordHistoryHidden: Self.usageRecordHistoryHidden)
    }

    private func fail(_ token: String) {
        lastConsent = nil
        serverConsentHidden = false
        phase = .error(.init(token: token))
    }

    private static func token(for error: ComplianceFailure) -> String {
        guard case .rejected(let message) = error else { return "failed" }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "failed" : trimmed
    }
}

#if DEBUG
public enum PrivacyProtectionPageFixtureData {
    public static let agreed = #"{"docType":"privacy_policy","scene":"roam_location","eventType":"AGREE","docVersion":"v2.1"}"#
    public static let revoked = #"{"docType":"privacy_policy","scene":"roam_location","eventType":"REVOKE","docVersion":"v2.1"}"#
    public static let unknownEvent = #"{"docType":"privacy_policy","scene":"roam_location","eventType":"UNKNOWN"}"#
    public static let unknownCountToken = "UNKNOWN"
    public static let literalZeroCountToken = "0"
    public static let paddedZeroCountToken = "00"
    public static func consent(_ json: String) throws -> ComplianceConsent {
        try JSONDecoder().decode(ComplianceConsent.self, from: Data(json.utf8))
    }
}
#endif
