import Foundation

/// The activity sheet, unlike other registration products, collects only these two fields.
/// Saved participants are autofill suggestions; edited values are what gets confirmed.
public struct RegistrationUIFormDraft: Equatable {
    public var realName: String
    public var phone: String
    public init(realName: String = "", phone: String = "") {
        self.realName = realName; self.phone = phone
    }
    public var trimmedName: String { realName.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var trimmedPhone: String { phone.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var validation: RegistrationUIValidation? {
        if trimmedName.isEmpty { return .nameRequired }
        if trimmedPhone.isEmpty { return .phoneRequired }
        // Source activity checkout uses ^1\d{10}$. Accept ASCII wire digits only.
        let bytes = Array(trimmedPhone.utf8)
        if bytes.count != 11 || bytes.first != 49 || !bytes.allSatisfy({ (48...57).contains($0) }) {
            return .invalidPhone
        }
        return nil
    }
    public var participantDetails: RegistrationParticipantDetails { details(waitlistOffer: nil) }
    public func details(waitlistOffer: RegistrationWaitlistOffer?) -> RegistrationParticipantDetails {
        RegistrationParticipantDetails(realName: trimmedName, phone: trimmedPhone, waitlistOffer: waitlistOffer)
    }
}

public enum RegistrationUIValidation: Equatable { case nameRequired, phoneRequired, invalidPhone }

/// UI confirmation is separate from the current server consent receipt. The production
/// service independently checks the scoped grant and maintains a durable replay lock.
public enum RegistrationUICreationPolicy: Equatable {
    case disabled
    /// A signed-in player may confirm only a known zero quote. Payment stays closed.
    case free
    case approved(RegistrationProductionApproval)
    #if DEBUG
    case offlineFixture
    #endif
    public var permitsCreation: Bool {
        switch self {
        case .disabled: return false
        case .free: return true
        case .approved(let grant): return Date() < grant.expiresAt
        #if DEBUG
        case .offlineFixture: return true
        #endif
        }
    }
    /// Approved grants and the free path both record server consent before quoting.
    public var recordsServerConsent: Bool {
        switch self {
        case .approved, .free: return true
        case .disabled: return false
        #if DEBUG
        case .offlineFixture: return false
        #endif
        }
    }
    public var isOfflineFixture: Bool {
        #if DEBUG
        return self == .offlineFixture
        #else
        return false
        #endif
    }
    public func permits(identity: ProfileReadIdentity?, activityID: Int, ticketID: Int?, now: Date) -> Bool {
        if case .free = self { return true }
        if case .approved(let grant) = self { return grant.permits(identity: identity, activityID: activityID, ticketID: ticketID, now: now) }
        return isOfflineFixture
    }
}

/// The quote/create wire contract has no currency field. Only the explicitly Yuan-named
/// deduction fields have a verified unit. A device locale never determines currency.
/// The one shared money-display formatter (owner ruling 2026-11-22, chengyin-ios `fix/owner-decisions-1122`).
/// Display only: stored, quoted and computed amounts never change.
///
/// SINGLE SWITCH: `MoneyDisplay.current`. Owner 2026-11-24 confirmed two decimals (¥12.50 / ¥39.00).
/// `.oneDecimal` remains only so an explicit rule can still be named; no money path passes it.
/// Text the server sends already formatted (for example `WalletAmount.text`) is shown as given.
public enum MoneyDisplay {
    public enum Rule: Equatable, Sendable {
        /// Current behaviour: always two decimal places (39 -> 39.00).
        case twoDecimals
        /// Named rule only. Production money uses `.twoDecimals` (owner 2026-11-24).
        case oneDecimal
    }
    /// The switch. Every money formatter reads this value; change nothing else to flip the rule.
    public static let current: Rule = .twoDecimals

    public static func minimumFractionDigits(_ rule: Rule = current) -> Int { rule == .oneDecimal ? 1 : 2 }
    public static let maximumFractionDigits = 2

    /// Invariant decimal text (no grouping). `.twoDecimals` rounds half-up to two places and pads;
    /// `.oneDecimal` never rounds and only guarantees one fractional digit.
    public static func plain(_ amount: Decimal, rule: Rule = current) -> String {
        var value = amount
        if rule == .twoDecimals {
            var rounded = Decimal()
            NSDecimalRound(&rounded, &value, 2, .plain)
            value = rounded
        }
        var text = NSDecimalNumber(decimal: value).stringValue
        let digits = minimumFractionDigits(rule)
        if !text.contains(".") { text += "." }
        let fraction = text.split(separator: ".", omittingEmptySubsequences: false).last?.count ?? 0
        if fraction < digits { text += String(repeating: "0", count: digits - fraction) }
        return text
    }
    /// "¥" followed by the plain text.
    public static func yuan(_ amount: Decimal, rule: Rule = current) -> String { "¥" + plain(amount, rule: rule) }

    /// Fen (cents) through the shared two-decimal rule. A negative amount is `-¥2.55`.
    public static func yuan(fen: Int) -> String {
        let cents = Decimal(abs(fen))
        let amount = cents / Decimal(100)
        let body = plain(amount)
        if fen < 0, amount != 0 { return "-¥" + body }
        return "¥" + body
    }
    /// Server decimal text in the same digits, lexically: no Decimal/Double conversion, so no
    /// rounding or overflow. Trailing zeros past the rule's minimum places are dropped and missing
    /// places are padded. Text that is not a plain decimal is shown as given.
    public static func text(_ raw: String, rule: Rule = current) -> String {
        guard raw.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil else { return raw }
        let digits = minimumFractionDigits(rule)
        guard let dot = raw.firstIndex(of: ".") else { return raw + "." + String(repeating: "0", count: digits) }
        var fraction = String(raw[raw.index(after: dot)...])
        while fraction.count > digits, fraction.last == "0" { fraction.removeLast() }
        if fraction.count < digits { fraction += String(repeating: "0", count: digits - fraction.count) }
        return String(raw[..<dot]) + "." + fraction
    }
}

public enum RegistrationUIMoney {
    public static let yuanCurrencyCode = "CNY"
    public static func display(_ amount: Decimal?, locale: Locale, currencyCode: String? = nil) -> String? {
        guard let amount, !amount.isNaN, amount >= .zero else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        if let currencyCode {
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatter.currencySymbol = currencyCode
        } else { formatter.numberStyle = .decimal }
        formatter.minimumFractionDigits = MoneyDisplay.minimumFractionDigits()
        formatter.maximumFractionDigits = MoneyDisplay.maximumFractionDigits
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }
}

/// Known registration labels are verified in the source order model. Keep payment and
/// verification codes separate; do not combine conflicting fields into a success verdict.
public enum RegistrationUIStatus {
    public static func registrationKey(_ code: Int?) -> String {
        switch code {
        case 1: return "registration.form.awaitingPayment"
        case 2: return "registration.form.registered"
        case 3: return "registration.form.cancelled"
        case 4: return "registration.form.expired"
        default: return "registration.form.unknownStatus"
        }
    }
}

/// Presentation only: capability and current status do not grant access or permit purchase.
public enum RegistrationUIWaitlistGuidance {
    public static func soldOutKey(available: Bool, status: RegistrationWaitlistStatus?,
                                  outcomeUnknown: Bool, now: Date) -> String {
        guard available else { return "registration.form.soldOutHint" }
        guard !outcomeUnknown else { return "registration.waitlist.unknown" }
        if status?.state == .waiting { return "registration.form.soldOutWaiting" }
        if status?.offer(at: now) != nil { return "registration.form.soldOutOffer" }
        return "registration.form.soldOutAvailable"
    }
}
