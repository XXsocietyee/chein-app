import PassKit
import SwiftUI

/// US launch r1 (lane app-pay); fix 11-28 (audit P0-3 / P1-3, P32). The USD branch of the registration pay step, shown by
/// `RegistrationPaySection` in place of its China "Pay now" button when `StripePayEligibility.applies` is true for the
/// quote / order currency and channels (never the storefront market). Same preconditions as the China step (consent,
/// payment readiness, Release money switch); the China flow (WeChat / Alipay) is untouched.
///
/// Apple Pay: `POST /api/pay/stripe/intent` (`id`) → `PKPaymentAuthorizationController` (amount = backend cents / 100) →
/// `POST /api/pay/stripe/applepay` (`id`, `paymentData`, `transactionIdentifier`, `paymentNetwork`,
/// `paymentMethodDisplayName`). Card: `POST /api/pay/stripe/checkout` (`id`) → `checkoutUrl` in `SFSafariViewController`.
/// Both end in the registration status read (`api/registration/info`), and the rows mirror the China ones
/// (`RegistrationAppPayRows`): paid → "Paid. Your ticket is in the wallet." + View ticket; checking → Refresh;
/// not completed → Pay again. Only the server's `paymentStatus == 2` says paid.
@MainActor struct RegistrationStripePayRows: View {
    @Environment(\.locale) private var locale

    let context: StripePayContext
    let registrationID: Int
    let paymentChannels: [String]?
    /// The order's amount due, already formatted in USD for the card button label. Nil shows the plain label.
    let amountText: String?
    let consented: Bool
    /// The sheet's "Pay with" row choice (P32). Nil (order detail) uses the default and offers the other method too.
    let preferredMethod: RegistrationPayMethod?
    /// Called once the server says paid, so the host screen can read its order again.
    let onPaid: (() -> Void)?

    @State private var authorizer = ApplePayStripeAuthorizer()
    @State private var phase: Phase = .idle
    @State private var stage: StripePayStage = .idle
    @State private var applePayLocked = false
    @State private var checkout: CheckoutTarget?
    @State private var showsWallet = false
    @State private var working = false

    /// Status reads after a provider return before the rows settle on "Checking payment…" (webhook may lag).
    static let statusReads = 3
    static let statusReadSpacing: UInt64 = 2_000_000_000

    enum Phase: Equatable {
        case idle
        case preparing
        case inSheet
        case confirming
        case notice(String)
    }

    struct CheckoutTarget: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var busy: Bool { working || phase == .preparing || phase == .inSheet || phase == .confirming || checkout != nil }

    private var methods: [RegistrationPayMethod] {
        StripePayEligibility.methods(paymentChannels: paymentChannels,
                                     applePayAvailable: ApplePayStripeAuthorizer.canMakePayments && !applePayLocked)
    }

    /// P32: the button is the method. The sheet's choice when it is offered, else Apple Pay first, else Card.
    private var primaryMethod: RegistrationPayMethod? {
        if let preferredMethod, methods.contains(preferredMethod) { return preferredMethod }
        return methods.first
    }

    /// Order detail (no "Pay with" row): the other offered method as a secondary button.
    private var alternateMethods: [RegistrationPayMethod] {
        let primary = primaryMethod
        return methods.filter { $0 != primary }
    }

    var body: some View {
        Group {
            switch stage {
            case .paid: paidRows
            case .checking: checkingRows
            case .idle, .notCompleted: payRows
            }
        }
        .sheet(item: $checkout, onDismiss: checkoutClosed) { target in
            StripeCheckoutSafariView(url: target.url) { checkout = nil }
                .ignoresSafeArea()
        }
        .cySheet(isPresented: $showsWallet) { walletSheet }
        .sensoryFeedback(.success, trigger: stage, condition: Self.becamePaid)
    }

    private static func becamePaid(_ old: StripePayStage, _ new: StripePayStage) -> Bool {
        new == .paid && old != .paid
    }

    private var walletSheet: some View {
        SessionTicketWalletHost(onClose: { showsWallet = false }, focusRegistrationID: registrationID)
    }

    // MARK: Rows

    @ViewBuilder private var payRows: some View {
        statusRow
        if let primaryMethod {
            methodButton(primaryMethod, primary: true)
            if preferredMethod == nil {
                ForEach(alternateMethods, id: \.self) { other in
                    methodButton(other, primary: false)
                }
            }
        } else {
            Text("registration.stripe.noMethod")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("registration.pay.stripe.noMethod")
        }
    }

    @ViewBuilder private func methodButton(_ method: RegistrationPayMethod, primary: Bool) -> some View {
        switch method {
        case .applePay:
            StripeApplePayButton { Task { await payWithApplePay() } }
                .disabled(busy)
                .accessibilityIdentifier("registration.pay.applePay")
                .accessibilityLabel(Text(verbatim: c.t("使用 Apple Pay 支付", "Pay with Apple Pay")))
                .accessibilityHint(Text(verbatim: payHint))
        case .card:
            cardButton(primary: primary)
        case .wechatPay, .alipay:
            EmptyView()
        }
    }

    @ViewBuilder private func cardButton(primary: Bool) -> some View {
        if primary {
            Button { Task { await payWithCard() } } label: { cardLabel }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(busy)
                .accessibilityIdentifier("registration.pay.card")
                .accessibilityHint(Text(verbatim: c.t("在 Stripe 安全页面中打开", "Opens the secure Stripe checkout page")))
        } else {
            Button { Task { await payWithCard() } } label: { cardLabel }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(busy)
                .accessibilityIdentifier("registration.pay.card")
                .accessibilityHint(Text(verbatim: c.t("在 Stripe 安全页面中打开", "Opens the secure Stripe checkout page")))
        }
    }

    @ViewBuilder private var cardLabel: some View {
        if let amountText {
            Text("registration.stripe.payWithCard \(amountText)")
                .frame(maxWidth: .infinity)
        } else {
            Text(verbatim: c.t("使用银行卡支付", "Pay with card"))
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var statusRow: some View {
        switch phase {
        case .idle, .inSheet:
            if stage == .notCompleted {
                Text("registration.stripe.notCompleted")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("registration.pay.cancelled")
            }
        case .preparing:
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text(verbatim: c.t("正在准备支付…", "Preparing payment…"))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("registration.pay.stripe.preparing")
        case .confirming:
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text(verbatim: c.t("正在确认支付结果…", "Checking payment…"))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("registration.pay.checkingResult")
        case .notice(let text):
            Text(verbatim: text)
                .cyText(.body)
                .foregroundStyle(CYColor.warningText)
                .accessibilityIdentifier("registration.pay.stripe.notice")
        }
    }

    @ViewBuilder private var paidRows: some View {
        // P39 payment success, same moment as WeChat Pay and Alipay: one burst, none under Reduce Motion.
        // The success haptic stays on the stage change above. The View ticket button is unchanged.
        RegistrationPaidTicketMoment(message: Text(c.t("支付成功，票已放入票夹", "Paid. Your ticket is in the wallet.")))
            .accessibilityIdentifier("registration.pay.succeeded")
        Button {
            showsWallet = true
        } label: {
            Label(c.t("查看门票", "View ticket"), systemImage: "ticket")
        }
        .accessibilityIdentifier("registration.pay.openTicket")
    }

    @ViewBuilder private var checkingRows: some View {
        HStack(spacing: CYSpacing.sm) {
            ProgressView()
            Text(verbatim: c.t("正在确认支付结果…", "Checking payment…"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("registration.pay.checkingResult")
        Button(c.t("刷新", "Refresh")) {
            Task { await refresh() }
        }
        .buttonStyle(.bordered)
        .disabled(working)
        .accessibilityIdentifier("registration.pay.refresh")
    }

    private var payHint: String {
        c.t("金额以订单为准，由服务器确认支付结果。", "The order sets the amount. The server confirms the payment.")
    }

    // MARK: Actions

    /// Same gates as the China step before any money call. Readiness is the order's own Stripe channels
    /// (`StripePayEligibility.readiness`), not the WeChat-only `payment-readiness` probe.
    private func preflight() async -> StripeIntentRequest? {
        guard ReleaseMoneyWriteSwitch.paymentEnabled,
              StripePayEligibility.applies(currency: StripePayWire.currency, paymentChannels: paymentChannels) else {
            phase = .notice(c.t("支付开关未开启", "Payment switch is closed")); return nil
        }
        guard consented else {
            phase = .notice(c.t("请先阅读并同意报名须知", "Agree to the registration terms first.")); return nil
        }
        return try? StripeIntentRequest(registrationID: registrationID)
    }

    private func payWithApplePay() async {
        guard !busy, !applePayLocked else { return }
        phase = .preparing
        guard let body = await preflight() else { return }
        let intent: StripeIntent
        switch await context.createIntent(body) {
        case .success(let value):
            intent = value
        case .failure(.alreadyPaid), .failure(.outcomeUnknown):
            await settle(confirm: nil, afterCheckout: false); return
        case .failure(let failure):
            show(failure); return
        }
        if intent.alreadySettling {
            // A previous token is still settling: no second sheet, the status read decides.
            applePayLocked = true
            await settle(confirm: nil, afterCheckout: false); return
        }
        phase = .inSheet
        let outcome = await authorizer.present(intent: intent, label: c.t("城瘾", "Chein"),
                                               confirm: Self.confirmer(context: context, body: body))
        switch outcome {
        case .notPresented:
            phase = .notice(c.t("无法打开 Apple Pay", "Apple Pay could not open."))
        case .cancelled:
            phase = .idle
        case .refused(let failure):
            show(failure)
        case .authorized(let result):
            // A token went to the server: no second Apple Pay attempt for this order.
            applePayLocked = true
            await settle(confirm: result, afterCheckout: false)
        case .unknown:
            applePayLocked = true
            await settle(confirm: nil, afterCheckout: false)
        }
    }

    /// The PassKit token → the backend's exact `applepay` fields.
    private static func confirmer(context: StripePayContext, body: StripeIntentRequest) -> ApplePayStripeAuthorizer.Confirm {
        let confirm: ApplePayStripeAuthorizer.Confirm = { payment in
            let token = payment.token
            guard let request = try? StripeApplePayConfirmRequest(
                intent: body, paymentData: token.paymentData,
                paymentMethodDisplayName: token.paymentMethod.displayName,
                paymentNetwork: token.paymentMethod.network?.rawValue,
                transactionIdentifier: token.transactionIdentifier) else { return .failure(.invalid) }
            return await context.confirmApplePay(request)
        }
        return confirm
    }

    private func payWithCard() async {
        guard !busy else { return }
        phase = .preparing
        guard let body = await preflight() else { return }
        switch await context.checkout(body) {
        case .success(let session):
            phase = .idle
            checkout = CheckoutTarget(url: session.url)
        case .failure(.alreadyPaid):
            await settle(confirm: nil, afterCheckout: false)
        case .failure(let failure):
            show(failure)
        }
    }

    private func checkoutClosed() {
        Task { await settle(confirm: nil, afterCheckout: true) }
    }

    /// Reads `api/registration/info` up to `statusReads` times until paid, then settles the rows.
    private func settle(confirm: StripeConfirmResult?, afterCheckout: Bool) async {
        guard stage != .paid else { return }
        working = true
        phase = .confirming
        var status = await context.readPaymentStatus(registrationID)
        var reads = 1
        while !RegistrationAppPayResolver.isPaid(status), reads < Self.statusReads, !Task.isCancelled {
            do { try await Task.sleep(nanoseconds: Self.statusReadSpacing) } catch { break }
            status = await context.readPaymentStatus(registrationID)
            reads += 1
        }
        working = false
        phase = .idle
        if afterCheckout {
            apply(StripePayStageResolver.afterCheckout(paymentStatus: status))
        } else {
            apply(StripePayStageResolver.afterApplePay(confirm: confirm, paymentStatus: status))
        }
    }

    private func refresh() async {
        guard !working else { return }
        working = true
        let status = await context.readPaymentStatus(registrationID)
        working = false
        apply(StripePayStageResolver.refreshed(paymentStatus: status))
    }

    private func apply(_ next: StripePayStage) {
        stage = next
        if next == .paid { onPaid?() }
    }

    private func show(_ failure: StripePayFailure) {
        switch failure {
        case .outcomeUnknown:
            Task { await settle(confirm: nil, afterCheckout: false) }
        default:
            phase = .notice(message(failure))
        }
    }

    private func localized(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), locale: locale))
    }

    private func message(_ failure: StripePayFailure) -> String {
        switch failure {
        case .closed: return c.t("支付开关未开启", "Payment switch is closed")
        case .signedOut, .unauthorized: return c.t("登录已过期，请重新登录", "Session expired. Sign in again.")
        case .rejected(let text): return text ?? c.t("支付请求暂未成功", "Payment request was not accepted.")
        case .declined: return localized("registration.stripe.declined")
        case .expired: return localized("registration.stripe.expired")
        case .alreadyPaid, .outcomeUnknown: return c.t("正在确认支付结果…", "Checking payment…")
        case .invalid, .unknown: return c.t("支付服务暂不可用", "Payment service unavailable")
        }
    }
}
