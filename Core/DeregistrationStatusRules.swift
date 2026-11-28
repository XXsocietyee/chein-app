import Foundation

/// Pure rules of mini-program `utils/deregister-flow.js` that the native compliance layer did not encode:
/// precheck shape validation, the cooling-off clock, apply gating and unknown-apply reconciliation.
/// Performs no I/O and holds no session state (see Core/AccountComplianceCoordinator.swift for that).
public enum DeregistrationStatusRules {
    /// Source `verificationMethod` normalization. Absent keeps the established SMS contract; a present
    /// but unknown value is never treated as usable.
    public enum Verification: String, Equatable { case sms = "SMS", wechat = "WECHAT", apple = "APPLE", unavailable = "UNAVAILABLE" }

    public enum PrecheckVerdict: Equatable {
        case eligible(Verification)
        case blocked([String])
        /// Source `_statusFailure`: ELIGIBLE with blockers, BLOCKED without, blank blocker text, unknown status.
        case malformed
    }

    /// Source `loadPrecheck`.
    public static func evaluatePrecheck(status: String, blockers: [String], verificationMethod: String?) -> PrecheckVerdict {
        let trimmed = blockers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !trimmed.contains(where: \.isEmpty) else { return .malformed }
        switch status {
        case "ELIGIBLE":
            guard trimmed.isEmpty else { return .malformed }
            return .eligible(verificationMethod.map { Verification(rawValue: $0) ?? .unavailable } ?? .sms)
        case "BLOCKED":
            return trimmed.isEmpty ? .malformed : .blocked(trimmed)
        default:
            return .malformed
        }
    }

    public static func evaluatePrecheck(_ value: ComplianceDeregistration) -> PrecheckVerdict {
        evaluatePrecheck(status: value.status, blockers: value.blockers, verificationMethod: value.verificationMethod)
    }

    /// Source `executeAfterPassed` (F-R2S-07): between the end of the cooling-off period and the daily
    /// batch the application can still be cancelled, but the screen switches its explanation.
    /// Accepts the same shapes as `datetime.toTimestamp`: 10-digit seconds, 13-digit milliseconds,
    /// ISO-8601 with an offset, or a zone-less string read as China time (UTC+8).
    public static func executeAfterPassed(_ value: String?, now: Date) -> Bool {
        guard let at = timestamp(value) else { return false }
        return at.timeIntervalSince1970 > 0 && at <= now
    }

    static func timestamp(_ value: String?) -> Date? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let digits = text.utf8.allSatisfy { (48...57).contains($0) }
        if digits, text.utf8.count == 10, let seconds = Double(text) { return Date(timeIntervalSince1970: seconds) }
        if digits, text.utf8.count == 13, let millis = Double(text) { return Date(timeIntervalSince1970: millis / 1000) }
        let hasZone = text.range(of: #"[zZ]$|[+-]\d\d:?\d\d$"#, options: .regularExpression) != nil
        if hasZone {
            let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text) { return date }
            let loose = DateFormatter()
            loose.locale = Locale(identifier: "en_US_POSIX")
            for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSxxx", "yyyy-MM-dd'T'HH:mm:ssxxx", "yyyy-MM-dd HH:mm:ssxxx", "yyyy-MM-dd'T'HH:mm:ssZ"] {
                loose.dateFormat = format
                if let date = loose.date(from: text) { return date }
            }
            return nil
        }
        let china = DateFormatter()
        china.locale = Locale(identifier: "en_US_POSIX"); china.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            china.dateFormat = format
            if let date = china.date(from: text) { return date }
        }
        return nil
    }

    public enum ApplyGate: Equatable {
        case ready
        /// Not in the ELIGIBLE step (or already submitting): the tap does nothing.
        case ignored
        case needsConfirmation
        case verificationUnavailable
        case needsCode
    }

    /// Source `apply()` guard order: submitting/not eligible -> unconfirmed -> method not SMS/WECHAT -> empty SMS code.
    public static func applyGate(eligible: Bool, submitting: Bool, confirmed: Bool, method: Verification, smsCode: String) -> ApplyGate {
        guard eligible, !submitting else { return .ignored }
        guard confirmed else { return .needsConfirmation }
        guard method == .sms || method == .wechat else { return .verificationUnavailable }
        if method == .sms, smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .needsCode }
        return .ready
    }

    /// Source `refreshApplyState`: the submit button is enabled only when eligible, confirmed and
    /// (WECHAT, or SMS with a non-blank code).
    public static func canApply(eligible: Bool, confirmed: Bool, method: Verification, smsCode: String) -> Bool {
        guard eligible, confirmed else { return false }
        switch method {
        // fix/1128-apple-delete: Apple-only accounts confirm with a Sign in with Apple re-auth proof, checked by the coordinator.
        case .wechat, .apple: return true
        case .sms: return !smsCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .unavailable: return false
        }
    }

    /// Source `_reconcileApply`: after an apply whose reply was lost, a read-only status check switches
    /// to the cooling-off card only when the server says PENDING and the form is still the ELIGIBLE form.
    /// Any other answer keeps the typed code and confirmation untouched.
    public static func adoptPendingAfterUnknownApply(serverStatus: String?, localEligible: Bool) -> Bool {
        serverStatus == "PENDING" && localEligible
    }

    /// Source `loadStatus` routing of the first status read.
    public enum StatusRoute: Equatable { case pending, precheck, unconfirmed }
    public static func route(status: String) -> StatusRoute {
        switch status {
        case "PENDING": return .pending
        case "NORMAL", "CANCELLED", "FAILED": return .precheck
        default: return .unconfirmed
        }
    }
}

/// Read-only projection of the cancellation screen. It does not send a request and does not
/// add `GET api/user/deregister/result`. That path is absent from the reviewed route catalog,
/// so the screen keeps using the status read the service already performs.
public enum DeregisterIndexReadPhase: Equatable {
    case loading
    case empty
    case error(key: String)
    case unknown
    case ready
}

public struct DeregisterIndexImpactLine: Equatable {
    public let key: String
    public let valueText: String
    public init(key: String, valueText: String) {
        self.key = key
        self.valueText = valueText
    }
}

public struct DeregisterIndexPageModel: Equatable {
    /// Missing and UNKNOWN quantities use this mark. They are never shown as 0.
    public static let unknownMark = "—"
    public static let knownStatuses: Set<String> = ["NORMAL", "PENDING", "ELIGIBLE", "BLOCKED", "CANCELLED", "FAILED", "COMPLETED", "WAITING"]
    public let phase: DeregisterIndexReadPhase
    public let statusText: String
    public let executeAfterText: String
    public let impactLines: [DeregisterIndexImpactLine]
    public let emptyKey: String
    public let loadingKey: String
    public let unknownKey: String
    public let errorKey: String?

    public init(state: ComplianceState) {
        emptyKey = "deregisterIndex.empty"
        loadingKey = "compliance.loading"
        unknownKey = "compliance.unknown"
        let trimmedError = state.error?.trimmingCharacters(in: .whitespacesAndNewlines)
        let reportedError = (trimmedError?.isEmpty == false) ? trimmedError : nil
        if state.busy {
            phase = .loading
            errorKey = nil
        } else if let reportedError {
            phase = .error(key: reportedError)
            errorKey = reportedError
        } else if state.step == .unknown || Self.unknownStatus(state.status?.status) {
            phase = .unknown
            errorKey = nil
        } else if state.status == nil && state.step == .idle {
            phase = .empty
            errorKey = nil
        } else {
            phase = .ready
            errorKey = nil
        }
        statusText = Self.statusText(state.status?.status)
        executeAfterText = Self.executeAfterText(state.status?.executeAfter)
        impactLines = state.status?.impact?.items.map {
            DeregisterIndexImpactLine(key: $0.key, valueText: Self.tokenText($0.value))
        } ?? []
    }

    /// True only when the reviewed catalog already admits the result route. It does not today.
    public var offersResultRoute: Bool {
        let path = "/api/user/deregister/result"
        return ChinaReviewedRouteCapability.mark(for: path) == .liveInProduction
            && ChinaReviewedRouteCapability.admitsChinaProductionCall(path)
    }

    public static func unknownStatus(_ raw: String?) -> Bool {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return text.isEmpty || text.uppercased() == "UNKNOWN"
    }

    public static func tokenText(_ raw: String?) -> String {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return unknownMark }
        if text.uppercased() == "UNKNOWN" { return unknownMark }
        return text
    }

    /// A canonical non-negative integer stays as written, including "0".
    /// UNKNOWN, blank, padded zeros, and non-integers stay an em dash.
    public static func countText(_ raw: String?) -> String {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return unknownMark }
        if text.uppercased() == "UNKNOWN" { return unknownMark }
        if text == "0" { return "0" }
        guard let first = text.utf8.first, first != 48, text.utf8.allSatisfy({ (48...57).contains($0) }) else { return unknownMark }
        return text
    }

    public static func statusText(_ raw: String?) -> String {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), knownStatuses.contains(text) else { return unknownMark }
        return text
    }

    public static func executeAfterText(_ raw: String?) -> String {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, text.uppercased() != "UNKNOWN" else { return unknownMark }
        guard DeregistrationStatusRules.timestamp(text) != nil else { return unknownMark }
        return text
    }
}

extension AccountComplianceCoordinator {
    public var deregisterIndexPage: DeregisterIndexPageModel { DeregisterIndexPageModel(state: state) }
}

#if DEBUG
public enum DeregisterIndexFixtureData {
    public static let revision = String(repeating: "ab", count: 32)
    public static let unknownStatus: String = {
        let impact = #"{"schemaVersion":1,"actorId":7,"revision":""# + revision
            + #"","items":[{"key":"POINTS","value":"UNKNOWN","source":"ledger","effect":"held"},{"key":"ACTIVE_ORDERS","value":"0","source":"orders","effect":"held"}],"unknownCoverage":["POINTS"]}"#
        return #"{"status":"UNKNOWN","blockers":[],"impact":"# + impact + "}"
    }()
    public static let normalStatus = #"{"status":"NORMAL","blockers":[]}"#
    public static let pendingStatus = #"{"status":"PENDING","blockers":[],"executeAfter":"2027-01-15T16:00:00+08:00"}"#
    public static let blockedCountStatus: String = {
        let impact = #"{"schemaVersion":1,"actorId":7,"revision":""# + revision
            + #"","items":[{"key":"BALANCE","value":"00","source":"wallet","effect":"held"},{"key":"POINTS","value":"12","source":"ledger","effect":"held"}],"unknownCoverage":[]}"#
        return #"{"status":"BLOCKED","blockers":["open order"],"impact":"# + impact + "}"
    }()

    public static func deregistration(_ json: String) throws -> ComplianceDeregistration {
        try JSONDecoder().decode(ComplianceDeregistration.self, from: Data(json.utf8))
    }

    public static func page(step: ComplianceStep = .notice, busy: Bool = false, error: String? = nil, statusJSON: String? = nil) throws -> DeregisterIndexPageModel {
        var state = ComplianceState()
        state.step = step
        state.busy = busy
        state.error = error
        if let statusJSON { state.status = try deregistration(statusJSON) }
        return DeregisterIndexPageModel(state: state)
    }

    public static func loadingPage() -> DeregisterIndexPageModel {
        var state = ComplianceState()
        state.busy = true
        return DeregisterIndexPageModel(state: state)
    }

    public static func emptyPage() -> DeregisterIndexPageModel {
        DeregisterIndexPageModel(state: ComplianceState())
    }

    public static func errorPage(key: String = "compliance.failed") -> DeregisterIndexPageModel {
        var state = ComplianceState()
        state.step = .notice
        state.error = key
        return DeregisterIndexPageModel(state: state)
    }
}
#endif
