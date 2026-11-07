import Foundation

/// Pure rules of mini-program `utils/deregister-flow.js` that the native compliance layer did not encode:
/// precheck shape validation, the cooling-off clock, apply gating and unknown-apply reconciliation.
/// Performs no I/O and holds no session state (see Core/AccountComplianceCoordinator.swift for that).
public enum DeregistrationStatusRules {
    /// Source `verificationMethod` normalization. Absent keeps the established SMS contract; a present
    /// but unknown value is never treated as usable.
    public enum Verification: String, Equatable { case sms = "SMS", wechat = "WECHAT", unavailable = "UNAVAILABLE" }

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
        case .wechat: return true
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
