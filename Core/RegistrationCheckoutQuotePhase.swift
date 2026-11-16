import Foundation

/// Acceptance R2 F-01/F-02. Where the sign-up price stands, as the checkout footer must say it.
/// `confirmationBlock` reports every missing, stale, refused or in-flight quote as `.quoteUnavailable`,
/// and the footer always rendered that as "正在核对价格…". A refused quote (`code 500 该主题尚未开售…`)
/// therefore looked like a check that never finished. The phase keeps "checking" for a request in
/// flight only; a settled refusal is terminal and carries the server sentence.
public enum RegistrationUIQuotePhase: Equatable {
    /// Quoting is off for this build/host.
    case disabled
    /// No request for the current selection has been made (or one was blocked before dispatch).
    case notRequested
    /// A quote request for the current selection is in flight.
    case checking
    case priced(RegistrationQuote)
    /// Terminal: the server refused (business code ≠ 200 or HTTP 4xx/5xx) or the request failed.
    /// `message` is the verified server sentence, when it sent one.
    case refused(message: String?)
}

extension RegistrationCoordinatorIssue {
    /// The structured server sentence (`msg`) of a business or HTTP refusal. Never an arbitrary
    /// error description (which may carry a URL, credential or participant data).
    public var serverMessage: String? {
        let raw: String?
        switch self {
        case .business(let failure): raw = failure.message
        case .http(let failure): raw = failure.response?.message
        default: raw = nil
        }
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}

extension RegistrationUIFlow {
    public var quotePhase: RegistrationUIQuotePhase {
        guard quoteEnabled else { return .disabled }
        if isQuoting { return .checking }
        switch quoteState {
        case .idle: return .notRequested
        case .loading: return .checking
        case .received(let quote): return .priced(quote)
        case .unavailable(let issue): return .refused(message: issue.serverMessage)
        }
    }

    /// The footer line under 立即报名, when the price or payment readiness is what blocks the sign-up.
    /// `paymentReadiness` is the last `payment-readiness` answer for the selected ticket (nil: not read).
    public func checkoutFooterNotice(paymentReadiness: RegistrationPaymentReadiness?) -> RegistrationCheckoutFooterNotice? {
        RegistrationCheckoutFooterNotice.resolve(
            block: confirmationBlock, quotePhase: quotePhase,
            needsConsentFirst: creationPolicy.recordsServerConsent && !consented,
            paidTicket: (selectedTicket?.price ?? .zero) > .zero,
            paymentReadiness: paymentReadiness)
    }
}

public enum RegistrationCheckoutFooterNotice: Equatable {
    /// Only while a quote request is in flight.
    case checkingPrice
    /// Terminal refusal: show the server sentence (or a generic one) with a retry.
    case priceRefused(message: String?)
    /// No usable fresh quote and nothing in flight: offer a retry instead of spinning.
    case priceNeeded
    /// The server checks the sign-up consent before quoting; agree first, then quote.
    case consentBeforePrice
    /// `payment-readiness` answered `ready: false` for a paid ticket: say so with its sentence.
    case paymentUnavailable(message: String?)

    public var offersQuoteRetry: Bool {
        switch self {
        case .priceRefused, .priceNeeded: return true
        case .checkingPrice, .consentBeforePrice, .paymentUnavailable: return false
        }
    }

    public static func resolve(block: RegistrationUIBlock?, quotePhase: RegistrationUIQuotePhase,
                               needsConsentFirst: Bool, paidTicket: Bool,
                               paymentReadiness: RegistrationPaymentReadiness?) -> RegistrationCheckoutFooterNotice? {
        if block == .quoteUnavailable {
            switch quotePhase {
            case .checking:
                return .checkingPrice
            case .refused(let message?):
                return .priceRefused(message: message)
            case .refused(.none):
                return needsConsentFirst ? .consentBeforePrice : .priceRefused(message: nil)
            case .notRequested, .priced, .disabled:
                return needsConsentFirst ? .consentBeforePrice : .priceNeeded
            }
        }
        if block == nil || block == .paymentRequired, paidTicket, let paymentReadiness, !paymentReadiness.ready {
            let text = paymentReadiness.message?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .paymentUnavailable(message: text?.isEmpty == false ? text : nil)
        }
        return nil
    }
}
