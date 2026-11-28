import PassKit
import SafariServices
import SwiftUI

/// US launch r1 (lane app-pay); fix 11-28 P0-3. How the Apple Pay sheet ended. None of these is settlement:
/// after `.authorized` / `.unknown` the caller always reads the registration status back from the server.
enum ApplePaySheetOutcome: Equatable {
    case notPresented
    case cancelled
    /// `POST /api/pay/stripe/applepay` accepted the token. `paymentStatus` in the result is the server's order state.
    case authorized(StripeConfirmResult)
    /// The server refused the token or the order (declined, expired, signed out, consent missing…). No charge was made.
    case refused(StripePayFailure)
    /// The confirm call's result is unknown (timeout / transport / PAYMENT_OUTCOME_UNKNOWN / already paid).
    /// The charge may have landed: the status read decides.
    case unknown
}

/// `PKPaymentAuthorizationController` for a USD order. Merchant id, networks, capability, country and currency
/// come from `StripePayWire`; the amount is the server's PaymentIntent `amount` in cents, shown in dollars. The PassKit token is handed to
/// `confirm` (→ `POST /api/pay/stripe/applepay`) exactly once per sheet.
@MainActor final class ApplePayStripeAuthorizer: NSObject, PKPaymentAuthorizationControllerDelegate {
    static let supportedNetworks: [PKPaymentNetwork] = [.visa, .masterCard, .amex, .discover]
    static let merchantCapabilities: PKMerchantCapability = .threeDSecure

    /// The device supports Apple Pay. The button stays visible even with no card yet (Apple's setup flow).
    static var canMakePayments: Bool {
        PKPaymentAuthorizationController.canMakePayments()
    }
    /// A card on one of the supported networks with 3-D Secure is already in Wallet.
    static var hasUsableCard: Bool {
        PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks, capabilities: merchantCapabilities)
    }

    typealias Confirm = @MainActor (PKPayment) async -> Result<StripeConfirmResult, StripePayFailure>

    private var controller: PKPaymentAuthorizationController?
    private var confirm: Confirm?
    private var confirmed = false
    private var outcome: ApplePaySheetOutcome = .cancelled
    private var continuation: CheckedContinuation<ApplePaySheetOutcome, Never>?

    static func paymentRequest(intent: StripeIntent, label: String) -> PKPaymentRequest? {
        guard intent.currency == StripePayWire.currency, intent.amountMinor > 0 else { return nil }
        let request = PKPaymentRequest()
        request.merchantIdentifier = StripePayWire.merchantIdentifier
        request.supportedNetworks = supportedNetworks
        request.merchantCapabilities = merchantCapabilities
        request.countryCode = StripePayWire.countryCode
        request.currencyCode = StripePayWire.currency
        request.paymentSummaryItems = [
            // Backend `amount` is minor units (2500 = $25.00); PassKit takes major units.
            PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(decimal: StripePayMoney.major(fromMinor: intent.amountMinor)),
                                 type: .final)
        ]
        return request
    }

    /// Presents the sheet once and returns when it is dismissed.
    func present(intent: StripeIntent, label: String, confirm: @escaping Confirm) async -> ApplePaySheetOutcome {
        guard controller == nil, continuation == nil,
              let request = Self.paymentRequest(intent: intent, label: label) else { return .notPresented }
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        self.controller = controller
        self.confirm = confirm
        confirmed = false
        outcome = .cancelled
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.present { [weak self] presented in
                Task { @MainActor [weak self] in
                    guard let self, !presented else { return }
                    self.outcome = .notPresented
                    self.finish()
                }
            }
        }
    }

    private func authorize(_ payment: PKPayment) async -> PKPaymentAuthorizationResult {
        guard !confirmed, let confirm else { return PKPaymentAuthorizationResult(status: .failure, errors: nil) }
        confirmed = true
        let result = await confirm(payment)
        outcome = Self.sheetOutcome(for: result)
        return PKPaymentAuthorizationResult(status: Self.sheetStatus(for: outcome), errors: nil)
    }

    /// The confirm answer → how the sheet ended. Only a Stripe status that accepted the token ends in `.authorized`.
    static func sheetOutcome(for result: Result<StripeConfirmResult, StripePayFailure>) -> ApplePaySheetOutcome {
        switch result {
        case .success(let value) where value.authorizedOrProcessing || value.serverMarkedPaid:
            return .authorized(value)
        case .success:
            return .refused(.declined(nil))
        case .failure(.alreadyPaid), .failure(.outcomeUnknown), .failure(.unknown):
            // Transport unknown or a payment that already landed: the status read decides.
            return .unknown
        case .failure(let failure):
            return .refused(failure)
        }
    }

    static func sheetStatus(for outcome: ApplePaySheetOutcome) -> PKPaymentAuthorizationStatus {
        if case .authorized = outcome { return .success }
        return .failure
    }

    private func finish() {
        controller?.dismiss(completion: nil)
        let result = outcome
        let waiting = continuation
        reset()
        waiting?.resume(returning: result)
    }

    private func reset() {
        controller?.delegate = nil
        controller = nil
        confirm = nil
        continuation = nil
    }

    nonisolated func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                                    didAuthorizePayment payment: PKPayment,
                                                    handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }
            completion(await self.authorize(payment))
        }
    }

    nonisolated func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        Task { @MainActor [weak self] in self?.finish() }
    }
}

/// Apple Pay button. iOS 16+ SwiftUI `PayWithApplePayButton` (deployment target is 17.0).
struct StripeApplePayButton: View {
    let action: () -> Void

    var body: some View {
        PayWithApplePayButton(.plain, action: action)
            .payWithApplePayButtonStyle(.automatic)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}

/// Stripe Checkout in `SFSafariViewController` (card fallback). Closing Safari returns to the pay step,
/// which then runs the order-status poll.
struct StripeCheckoutSafariView: UIViewControllerRepresentable {
    let url: URL
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = false
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .close
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { onFinish() }
    }
}
