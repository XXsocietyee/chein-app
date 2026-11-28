import SwiftUI

/// RM-02 payment bridge behind `ReviewedAreaSwitch.moneyPayments` (ON in TEST/DEBUG off `www.chengyinhub.com`,
/// OFF in Release & production) and `ReleaseMoneyWriteSwitch`. Single-shot only; never auto-retries.
@MainActor enum RegistrationPayBridge {
    static func paymentsOpen(_ session: AppSession) -> Bool {
        ReviewedAreaSwitch.moneyPayments(apiHost: session.regionalConfiguration?.apiConfiguration?.baseURL.host)
    }

    static func pay(_ session: AppSession,
                    registrationID: Int,
                    channel: RegistrationPayChannel = RegistrationAppPayResolver.inAppChannel,
                    readiness: RegistrationPaymentReadiness,
                    quoteUsable: Bool,
                    quoteFresh: Bool,
                    consented: Bool) async -> RegistrationPayOutcome {
        guard paymentsOpen(session),
              let configuration = session.regionalConfiguration?.apiConfiguration else {
            return .blocked(.moneyPaymentsClosed)
        }
        guard let token = session.token, AuthRequestBuilder.isValidToken(token) else {
            return .blocked(.signedOut)
        }
        let stamp = session.sessionRevision
        let transport = RegistrationPayLease(underlying: session.composition.makeTransport(),
                                             expectedHost: configuration.baseURL.host)
        let outcome = await RegistrationPayService.submit(
            configuration: configuration,
            transport: transport,
            token: token,
            registrationID: registrationID,
            readiness: readiness,
            quoteUsable: quoteUsable,
            quoteFresh: quoteFresh,
            consented: consented,
            channel: channel
        )
        if case .unauthorized = outcome {
            session.expireIfMatching(error: APIError.unauthorized, stamp: stamp, credential: token)
        }
        return outcome
    }

    /// Strict app-side transport lease for `POST /api/registration/pay` and `/pay/app`.
    struct RegistrationPayLease: HTTPTransport {
        let underlying: any HTTPTransport
        let expectedHost: String?

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            guard request.httpMethod == "POST",
                  request.url?.query == nil,
                  let url = request.url,
                  let channel = [RegistrationPayChannel.standard, .app].first(where: { url.path.hasSuffix("/" + $0.rawValue) }),
                  ReviewedAreaSwitch.moneyPayments(apiHost: url.host ?? expectedHost),
                  !ReleaseMoneyWriteSwitch.blocks(channel.routePath),
                  let token = request.value(forHTTPHeaderField: "Authorization"),
                  // fix/1128-cn-pay P0-2: `RegistrationPayService` sends the canonical multipart form (`id` only);
                  // the old URL-encoded parse never matched it, so every pay was refused here.
                  ReviewedProductionFormMutationRoute.singlePositiveFormField(request, url: url, key: "id", token: token) else {
                throw APIError.notConfigured
            }
            return try await underlying.send(request)
        }
    }
}

typealias RegistrationPayExecutor = @MainActor (Int, RegistrationPayChannel, RegistrationPaymentReadiness) async -> RegistrationPayOutcome

private struct RegistrationPayExecutorKey: EnvironmentKey {
    static let defaultValue: RegistrationPayExecutor? = nil
}

extension EnvironmentValues {
    var registrationPayExecutor: RegistrationPayExecutor? {
        get { self[RegistrationPayExecutorKey.self] }
        set { self[RegistrationPayExecutorKey.self] = newValue }
    }
}

@MainActor private final class RegistrationPayViewModel: ObservableObject {
    let model = RegistrationPayModel()
    @Published private(set) var revision: UInt64 = 0

    init() {
        model.onChange = { [weak self] in self?.revision &+= 1 }
    }
}

/// Paid-registration pay section: checks `payment-readiness`, validates quote & consent, and invokes
/// `POST /api/registration/pay` at most once (never auto-retries on 410 or transient failures).
@MainActor struct RegistrationPaySection: View {
    @Environment(\.locale) private var locale
    @Environment(\.registrationPaymentReadiness) private var readinessReader
    @Environment(\.registrationPayExecutor) private var payExecutor
    /// US launch r1: non-nil only in the US market with payments open. Nil keeps the China flow exactly as before.
    @Environment(\.stripePayContext) private var stripePay
    /// Owner check 11-28 05:35: the WeChat SDK hand-off for APP pay params. Nil keeps the status chip only.
    @Environment(\.registrationAppPay) private var appPay
    /// fix-1128-alipay (P0-4 / P32): the sheet's "Pay with" choice and the Alipay hand-off. Nil keeps WeChat Pay.
    @Environment(\.registrationPayMethodChoice) private var payMethodChoice
    @Environment(\.registrationAlipayPay) private var alipayPay

    let registrationID: Int
    let payableAmount: Decimal?
    let quote: RegistrationQuote?
    let quoteReceivedAt: Date?
    let consented: Bool
    let requiresFreshQuote: Bool
    let channel: RegistrationPayChannel
    let onExpiredRebuild: (() -> Void)?
    /// US r2: the order's own `currency` / `paymentChannels` (order detail has no quote). A quote wins when present.
    let orderCurrency: String?
    let orderPaymentChannels: [String]?
    /// P32: the sheet's 支付方式 choice; the pay button then reads 微信支付 ¥12.50. Nil (order detail) is WeChat Pay,
    /// the only China in-app method until Alipay is ready (fix/1128-cn-pay).
    let payMethod: RegistrationPayMethod?
    /// fix/1128-cn-pay P0-2: APP pay params the create already returned (MP baoming: create → requestPayment).
    /// Non-empty params open WeChat at once; no second `pay/app` call is made for them.
    let initialPayParams: [String: String]?
    /// fix/1128-cn-pay P1-2: the server read said paid; the host refreshes its order / registration status.
    let onSettled: (() -> Void)?

    @StateObject private var viewModel = RegistrationPayViewModel()
    @State private var readiness: RegistrationPaymentReadiness?
    @State private var payStepMethod: RegistrationPayMethod?

    init(registrationID: Int,
         payableAmount: Decimal?,
         quote: RegistrationQuote? = nil,
         quoteReceivedAt: Date? = nil,
         consented: Bool,
         requiresFreshQuote: Bool = true,
         channel: RegistrationPayChannel = RegistrationAppPayResolver.inAppChannel,
         onExpiredRebuild: (() -> Void)? = nil,
         orderCurrency: String? = nil,
         orderPaymentChannels: [String]? = nil,
         payMethod: RegistrationPayMethod? = nil,
         initialPayParams: [String: String]? = nil,
         onSettled: (() -> Void)? = nil) {
        self.registrationID = registrationID
        self.payableAmount = payableAmount
        self.quote = quote
        self.quoteReceivedAt = quoteReceivedAt
        self.consented = consented
        self.requiresFreshQuote = requiresFreshQuote
        self.channel = channel
        self.onExpiredRebuild = onExpiredRebuild
        self.orderCurrency = orderCurrency
        self.orderPaymentChannels = orderPaymentChannels
        self.payMethod = payMethod
        self.initialPayParams = initialPayParams
        self.onSettled = onSettled
    }

    /// Quote first (registration sheet), else the order detail's own fields; nil on a China order.
    private var payCurrency: String? { quote?.currency ?? orderCurrency }
    private var payChannels: [String]? { quote?.paymentChannels ?? orderPaymentChannels }

    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        let _ = viewModel.revision
        if showsPaySection {
            Section {
                if payExecutor == nil {
                    Label {
                        Text("paymentReadiness.closed", tableName: "PayoutReceiver")
                    } icon: {
                        Image(systemName: "lock")
                    }
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("registration.pay.closed")
                    .accessibilityLabel(Text("paymentReadiness.closed", tableName: "PayoutReceiver"))
                    .accessibilityHint(Text(verbatim: c.t("支付开关未开启", "Payment switch is closed")))
                } else {
                    LabeledContent(c.t("待支付金额", "Amount due")) {
                        Text(verbatim: amountText)
                            .monospacedDigit()
                            .foregroundStyle(CYColor.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(verbatim: c.t("待支付金额", "Amount due")))
                    .accessibilityValue(Text(verbatim: amountText))
                    .accessibilityHint(Text(verbatim: payOnceHint))
                    // One "Pay with" row: the picker when Alipay is offered (below), otherwise this read-only row.
                    if !usesStripePay, !alipayOffered {
                        payWithRow
                    }
                    statusView
                    if let stripePay, usesStripe(stripePay) {
                        RegistrationStripePayRows(context: stripePay, registrationID: registrationID,
                                                  paymentChannels: payChannels, consented: consented,
                                                  readiness: readiness)
                    } else if canTapPay, chosenPayMethod == .alipay, let alipayPay {
                        RegistrationPayStepMethodRow(selection: payStepMethodBinding, enabled: !alipayPay.isWaiting())
                        RegistrationAlipayPayRows(context: alipayPay, registrationID: registrationID,
                                                  amountText: amountText, onExpiredRebuild: onExpiredRebuild)
                    } else if let params = pendingInitialParams {
                        RegistrationAppPayRows(context: appPay, registrationID: registrationID,
                                               parameters: params, onSettled: onSettled)
                    } else if canTapPay {
                        if alipayOffered {
                            RegistrationPayStepMethodRow(selection: payStepMethodBinding, enabled: true)
                        }
                        if weChatCanOpen {
                            CYPillButton(verbatim: weChatPayTitle, style: .primary) {
                                startPay()
                            }
                            .accessibilityIdentifier("registration.pay.submit")
                            .accessibilityLabel(Text(verbatim: weChatPayTitle))
                            .accessibilityHint(Text(verbatim: payOnceHint))
                        } else {
                            // P32: the reason is a footnote, never a disabled button used as a message.
                            Text("registration.pay.weChatNotReady")
                                .font(.footnote)
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("registration.pay.weChatNotReady")
                        }
                    }
                }
            } header: {
                Text(c.t("订单支付", "Order payment"))
            } footer: {
                Text(c.t("单次发起支付，不自动重试；如需重建订单请重新确认报名。",
                         "Payment runs once with no automatic retry. Rebuild the order manually if it expires."))
            }
            .task(id: registrationID) {
                if readiness == nil, let readinessReader {
                    readiness = await readinessReader()
                }
            }
        }
    }

    /// fix-1128-alipay: Alipay is a choice for this CNY order (backend `APP_ALIPAY` + the app can open Alipay).
    private var alipayOffered: Bool {
        RegistrationAlipayBridge.offered(alipayPay, paymentChannels: payChannels)
    }

    private var chosenPayMethod: RegistrationPayMethod {
        RegistrationPayMethod.effective(selection: payStepMethod ?? payMethodChoice, market: .china,
                                        applePayAvailable: false, alipayOffered: alipayOffered,
                                        paymentChannels: payChannels)
    }

    private var payStepMethodBinding: Binding<RegistrationPayMethod> {
        Binding(get: { chosenPayMethod }, set: { payStepMethod = $0 })
    }

    /// P32: the button names the method ("Pay ¥12.50 with WeChat Pay").
    private var weChatPayTitle: String {
        RegistrationAlipayBridge.payButtonTitle(.wechatPay, amountText: amountText, locale: locale)
    }

    /// US launch r1: a USD quote listing `APPLE_PAY` / `APP_STRIPE` in the US market. China quotes never match.
    private func usesStripe(_ context: StripePayContext) -> Bool {
        StripePayEligibility.applies(market: context.market, currency: payCurrency, paymentChannels: payChannels)
    }

    private var usesStripePay: Bool {
        guard let stripePay else { return false }
        return usesStripe(stripePay)
    }

    /// The China in-app method shown on the row and the button: the sheet's choice, else WeChat Pay.
    private var shownPayMethod: RegistrationPayMethod { payMethod ?? .wechatPay }

    /// P32: ONE "Pay with" row showing the chosen method, plain text as in `RegistrationPayMethodSection`.
    private var payWithRow: some View {
        LabeledContent {
            Text(verbatim: c.t(shownPayMethod.names.zh, shownPayMethod.names.en))
                .foregroundStyle(CYColor.textPrimary)
        } label: {
            Text("registration.pay.payWith")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("registration.pay.payWith")
    }

    /// Create-returned params open WeChat once, until this section has made its own `pay/app` attempt.
    private var pendingInitialParams: [String: String]? {
        guard let initialPayParams, !initialPayParams.isEmpty,
              !viewModel.model.isLocked(registrationID: registrationID) else { return nil }
        return initialPayParams
    }

    /// A host without the WeChat hand-off (design fixtures) keeps the button; a session says whether WeChat opens.
    private var weChatCanOpen: Bool {
        guard let appPay else { return true }
        return appPay.isAvailable()
    }

    private func startPay() {
        Task { @MainActor in
            await viewModel.model.pay(
                registrationID: registrationID,
                paymentsOpen: true,
                readiness: readiness,
                readinessReader: { await readAndStoreReadiness() },
                quote: quote,
                quoteReceivedAt: quoteReceivedAt,
                consented: consented,
                requiresFreshQuote: requiresFreshQuote,
                channel: channel,
                executor: payExecutor
            )
        }
    }

    private func readAndStoreReadiness() async -> RegistrationPaymentReadiness? {
        let value = await readinessReader?()
        readiness = value
        return value
    }

    /// A missing amount stays on screen as an em dash. A decoded zero stays off this section.
    private var showsPaySection: Bool {
        guard registrationID > 0 else { return false }
        guard let payableAmount else { return true }
        return payableAmount > .zero
    }

    private var amountText: String {
        // US r2: the order currency picks the symbol; a backend without `currency` is the China one (MP shows ¥).
        RegistrationUIMoney.display(payableAmount, locale: locale,
                                    currencyCode: payCurrency ?? RegistrationUIMoney.yuanCurrencyCode) ?? "—"
    }

    /// P32: the button is the payment method plus the total; without a known amount it stays 立即支付.
    private var payButtonTitle: String {
        let method = shownPayMethod
        guard let total = RegistrationUIMoney.display(payableAmount, locale: locale,
                                                      currencyCode: payCurrency ?? RegistrationUIMoney.yuanCurrencyCode) else {
            return c.t("立即支付", "Pay now")
        }
        let title = method.payTitle(amount: total)
        return c.t(title.zh, title.en)
    }

    private var payOnceHint: String {
        c.t("单次发起支付，不自动重试；如需重建订单请重新确认报名。",
            "Payment runs once with no automatic retry. Rebuild the order manually if it expires.")
    }

    private var canTapPay: Bool {
        guard !viewModel.model.isLocked(registrationID: registrationID) else { return false }
        switch viewModel.model.outcome {
        case .checkingReadiness, .paying, .paidOrParametersReceived, .expiredNeedsRebuild:
            return false
        case .idle, .blocked, .rejected, .unauthorized, .outcomeUnknown:
            return true
        }
    }

    @ViewBuilder private var statusView: some View {
        switch viewModel.model.outcome {
        case .idle:
            if let readiness, !readiness.ready {
                Text(verbatim: readiness.message ?? c.t("支付服务暂不可用", "Payment service unavailable"))
                    .cyText(.body)
                    .foregroundStyle(CYColor.warningText)
                    .accessibilityIdentifier("registration.pay.notReady")
            }
        case .checkingReadiness:
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text("paymentReadiness.checking", tableName: "PayoutReceiver")
            }
            .accessibilityIdentifier("registration.pay.checking")
        case .paying:
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text(c.t("正在请求支付参数…", "Requesting payment…"))
            }
            .accessibilityIdentifier("registration.pay.submitting")
        case .blocked(let reason, let message):
            Text(verbatim: message ?? blockedCopy(reason))
                .cyText(.body)
                .foregroundStyle(CYColor.warningText)
                .accessibilityIdentifier("registration.pay.blocked")
        case .paidOrParametersReceived(let response):
            // P1-2: with or without provider params, the stage comes from one `api/registration/info` read.
            RegistrationAppPayRows(context: appPay, registrationID: response.registrationID,
                                   parameters: response.payParams ?? [:], onSettled: onSettled)
        case .expiredNeedsRebuild(let message):
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: message)
                    .cyText(.body)
                    .foregroundStyle(CYColor.warningText)
                    .accessibilityIdentifier("registration.pay.expired")
                if let onExpiredRebuild {
                    CYPillButton(verbatim: c.t("重新确认并下单", "Rebuild order"), style: .secondary) {
                        onExpiredRebuild()
                    }
                    .accessibilityIdentifier("registration.pay.rebuild")
                }
            }
        case .rejected(_, let message):
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: message)
                    .cyText(.body)
                    .foregroundStyle(CYColor.warningText)
                    .accessibilityIdentifier("registration.pay.rejected")
                if let row = RequestReferenceRow(pathFragment: "/api/registration/pay") { row }
            }
        case .unauthorized:
            Text(c.t("登录状态已过期，请重新登录", "Session expired, sign in again"))
                .cyText(.body)
                .foregroundStyle(CYColor.warningText)
        case .outcomeUnknown(let message):
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: message ?? c.t("支付结果未明，已锁定不自动重试，请查单确认。",
                                          "Payment outcome unknown. Auto-retry is disabled; check order status."))
                    .cyText(.body)
                    .foregroundStyle(CYColor.warningText)
                    .accessibilityIdentifier("registration.pay.unknown")
                if let row = RequestReferenceRow(pathFragment: "/api/registration/pay") { row }
            }
        }
    }

    private func blockedCopy(_ reason: RegistrationPayBlockReason) -> String {
        switch reason {
        case .moneyPaymentsClosed: return c.t("支付开关未开启", "Payment switch is closed")
        case .signedOut: return c.t("请先登录后再支付", "Sign in before paying")
        case .notReady: return c.t("支付服务未就绪，请先检查支付准备度", "Payment service is not ready")
        case .quoteUnavailable: return c.t("请先获取最新价格明细", "Refresh quote before paying")
        case .quoteStale: return c.t("报价已过期，请刷新价格后重试", "Quote expired; refresh price")
        case .missingConsent: return c.t("请先勾选并记录报名信息提供同意", "Confirm data-sharing consent first")
        case .invalidRegistrationID: return c.t("报名单号无效", "Invalid registration ID")
        case .alreadyAttempted: return c.t("本单已发起过支付，禁止自动重试", "Already attempted; auto-retry blocked")
        }
    }
}
