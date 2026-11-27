import SwiftUI

/// US launch r1 (lane app-pay). The USD branch of the registration pay step, shown by `RegistrationPaySection`
/// in place of its China "Pay now" button when `StripePayEligibility.applies` is true. Same preconditions as the
/// China step (consent, payment readiness, Release money switch); the China flow (WeChat / Alipay) is untouched.
///
/// Apple Pay: `POST /api/pay/stripe/intent` → `PKPaymentAuthorizationController` → token to
/// `POST /api/pay/stripe/applepay`. Card: Stripe Checkout URL in `SFSafariViewController`.
/// Both end in the existing order-status poll (`PaymentProviderReturnSheet`); only the server readback says "paid".
@MainActor struct RegistrationStripePayRows: View {
    @Environment(\.locale) private var locale
    @Environment(\.registrationPaymentReadiness) private var readinessReader

    let context: StripePayContext
    let registrationID: Int
    let paymentChannels: [String]?
    let consented: Bool
    let readiness: RegistrationPaymentReadiness?

    @State private var authorizer = ApplePayStripeAuthorizer()
    @State private var phase: Phase = .idle
    @State private var applePayLocked = false
    @State private var checkout: CheckoutTarget?
    @State private var returnFlow: PaymentProviderReturnFlow?

    enum Phase: Equatable {
        case idle
        case preparing
        case inSheet
        case notice(String)
        case finished
    }

    struct CheckoutTarget: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var busy: Bool { phase == .preparing || phase == .inSheet || returnFlow != nil || checkout != nil }

    var body: some View {
        Group {
            statusRow
            if phase != .finished {
                if StripePayEligibility.offersApplePay(paymentChannels: paymentChannels),
                   ApplePayStripeAuthorizer.canMakePayments, !applePayLocked {
                    StripeApplePayButton { Task { await payWithApplePay() } }
                        .disabled(busy)
                        .accessibilityIdentifier("registration.pay.applePay")
                        .accessibilityLabel(Text(verbatim: c.t("使用 Apple Pay 支付", "Pay with Apple Pay")))
                        .accessibilityHint(Text(verbatim: payHint))
                }
                if StripePayEligibility.offersCard(paymentChannels: paymentChannels) {
                    CYPillButton(verbatim: c.t("使用银行卡支付", "Pay with card"), style: .secondary) {
                        Task { await payWithCard() }
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("registration.pay.card")
                    .accessibilityLabel(Text(verbatim: c.t("使用银行卡支付", "Pay with card")))
                    .accessibilityHint(Text(verbatim: c.t("在 Stripe 安全页面中打开", "Opens the secure Stripe checkout page")))
                }
            }
        }
        .sheet(item: $checkout, onDismiss: { startReturnPoll() }) { target in
            StripeCheckoutSafariView(url: target.url) { checkout = nil }
                .ignoresSafeArea()
        }
        .sheet(item: $returnFlow) { flow in
            PaymentProviderReturnSheet(flow: flow) { result in
                returnFlow = nil
                switch result {
                case .paid, .accepted:
                    phase = .finished
                case .failed:
                    phase = .notice(c.t("支付未完成，请重试", "Payment not completed. Try again."))
                default:
                    phase = .notice(c.t("暂未确认支付结果，请稍后在订单中查看",
                                        "Payment not confirmed yet. Check the order again shortly."))
                }
            }
        }
    }

    @ViewBuilder private var statusRow: some View {
        switch phase {
        case .idle, .inSheet:
            EmptyView()
        case .preparing:
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text(verbatim: c.t("正在准备支付…", "Preparing payment…"))
            }
            .accessibilityIdentifier("registration.pay.stripe.preparing")
        case .notice(let text):
            Text(verbatim: text)
                .cyText(.body)
                .foregroundStyle(CYColor.warningText)
                .accessibilityIdentifier("registration.pay.stripe.notice")
        case .finished:
            CYStatusChip(verbatim: c.t("支付成功，票已放入票夹", "Paid. Your ticket is in the wallet."), tone: .success)
                .accessibilityIdentifier("registration.pay.succeeded")
        }
    }

    private var payHint: String {
        c.t("金额以订单为准，由服务器确认支付结果。", "The order sets the amount. The server confirms the payment.")
    }

    /// Same gates as the China step before any money call.
    private func preflight() async -> StripeIntentRequest? {
        guard ReleaseMoneyWriteSwitch.paymentEnabled, StripePayEligibility.applies(
            market: context.market, currency: StripePayWire.currency, paymentChannels: paymentChannels) else {
            phase = .notice(c.t("支付开关未开启", "Payment switch is closed")); return nil
        }
        guard consented else {
            phase = .notice(c.t("请先阅读并同意报名须知", "Agree to the registration terms first.")); return nil
        }
        var current = readiness
        if current == nil { current = await readinessReader?() }
        guard let current, current.ready else {
            phase = .notice(current?.message ?? c.t("支付服务暂不可用", "Payment service unavailable")); return nil
        }
        return try? StripeIntentRequest(registrationID: registrationID)
    }

    private func payWithApplePay() async {
        guard !busy, !applePayLocked else { return }
        phase = .preparing
        guard let body = await preflight() else { return }
        let intent: StripeIntent
        switch await context.createIntent(body) {
        case .success(let value): intent = value
        case .failure(let failure): phase = .notice(message(failure)); return
        }
        phase = .inSheet
        let outcome = await authorizer.present(intent: intent, label: c.t("城瘾", "Chein")) { payment in
            guard let request = try? StripeApplePayConfirmRequest(
                intent: body, paymentIntentID: intent.paymentIntentID, paymentData: payment.token.paymentData,
                instrumentName: payment.token.paymentMethod.displayName,
                paymentNetwork: payment.token.paymentMethod.network?.rawValue,
                transactionIdentifier: payment.token.transactionIdentifier) else { return .failure(.invalid) }
            return await context.confirmApplePay(request)
        }
        switch outcome {
        case .notPresented:
            phase = .notice(c.t("无法打开 Apple Pay", "Apple Pay could not open."))
        case .cancelled:
            phase = .idle
        case .declined(let text):
            phase = .notice(text ?? c.t("支付未完成，请重试", "Payment not completed. Try again."))
        case .authorized, .unknown:
            // A token went to the server: no second Apple Pay attempt for this order. The poll decides.
            applePayLocked = true
            phase = .idle
            startReturnPoll()
        }
    }

    private func payWithCard() async {
        guard !busy else { return }
        phase = .preparing
        guard let body = await preflight() else { return }
        var url: URL?
        if case .success(let intent) = await context.createIntent(body) { url = intent.checkoutURL }
        if url == nil {
            switch await context.checkoutURL(body) {
            case .success(let value): url = value
            case .failure(let failure): phase = .notice(message(failure)); return
            }
        }
        guard let url else { phase = .notice(message(.unknown)); return }
        phase = .idle
        checkout = CheckoutTarget(url: url)
    }

    private func startReturnPoll() {
        guard returnFlow == nil, phase != .finished else { return }
        returnFlow = context.makeReturnFlow(registrationID)
    }

    private func message(_ failure: StripePayFailure) -> String {
        switch failure {
        case .closed: return c.t("支付开关未开启", "Payment switch is closed")
        case .signedOut, .unauthorized: return c.t("登录已过期，请重新登录", "Session expired. Sign in again.")
        case .rejected(let text): return text ?? c.t("支付请求暂未成功", "Payment request was not accepted.")
        case .invalid, .unknown: return c.t("支付服务暂不可用", "Payment service unavailable")
        }
    }
}
