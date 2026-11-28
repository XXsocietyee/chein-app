import Foundation

/// fix-1128-alipay (audit P0-4): the registration pay step's Alipay path.
/// `POST /api/pay/alipay/order` (form `id`) → `orderString` → Alipay (SDK or URL hand-off) → one
/// `POST /api/pay/alipay/query` (form `id`) decides paid / cancelled / checking. Same money switches as WeChat Pay
/// (`ReleaseMoneyWriteSwitch.paymentEnabled`, `ReviewedAreaSwitch.moneyPayments`). No Alipay sign-in exists.
extension AppSession {
    /// The app can hand an order to Alipay now: money on, China player/club session, owner scheme configured.
    var alipayPaymentReady: Bool {
        ReleaseMoneyWriteSwitch.paymentEnabled && registrationAppPayAllowed && alipayPay.adapter.isConfigured
    }

    /// Alipay's app-switch return (`<scheme>://safepay/...`); only while an Alipay order is waiting.
    func handleAlipayReturn(_ url: URL) -> Bool {
        alipayPay.adapter.handle(url)
    }

    func alipayCreateOrder(registrationID: Int) async -> AlipayAppPayOrderOutcome {
        guard alipayPaymentReady, let configuration = regionalConfiguration?.apiConfiguration else {
            return .unavailable(message: nil)
        }
        guard let token, AuthRequestBuilder.isValidToken(token) else { return .unauthorized }
        let stamp = sessionRevision
        let transport = AlipayPayLease(underlying: composition.makeTransport(), expectedHost: configuration.baseURL.host)
        let outcome = await AlipayAppPayService.createOrder(configuration: configuration, transport: transport,
                                                            token: token, registrationID: registrationID)
        if outcome == .unauthorized {
            expireIfMatching(error: APIError.unauthorized, stamp: stamp, credential: token)
        }
        return outcome
    }

    /// Opens Alipay with the order string and waits for its answer (or the adapter's timeout).
    func alipayLaunch(registrationID: Int, order: AlipayAppPayOrder) async -> AlipayLaunchResult {
        let providerReturn = await alipayPay.adapter.pay(registrationID: registrationID,
                                                                  parameters: order.adapterParameters)
        return AlipayLaunchResult(providerReturn: providerReturn,
                                  alipayMissing: alipayPay.driver.lastLaunchFailedToOpen)
    }

    /// Ends a wait whose return URL never came (the player switched back by hand); the query decides.
    func alipayEndPendingWait() {
        alipayPay.adapter.cancelPending()
    }

    var alipayWaiting: Bool { alipayPay.adapter.pendingRegistrationID != nil }

    func alipayQuery(registrationID: Int) async -> AlipayAppPayQueryResult? {
        guard registrationID > 0, let configuration = regionalConfiguration?.apiConfiguration,
              let token, AuthRequestBuilder.isValidToken(token) else { return nil }
        let transport = AlipayPayLease(underlying: composition.makeTransport(), expectedHost: configuration.baseURL.host)
        return await AlipayAppPayService.query(configuration: configuration, transport: transport,
                                               token: token, registrationID: registrationID)
    }

    /// Strict app-side transport lease: only `POST api/pay/alipay/order|query` with a positive form `id`.
    struct AlipayPayLease: HTTPTransport {
        let underlying: any HTTPTransport
        let expectedHost: String?

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            guard Self.admits(request, expectedHost: expectedHost) else { throw APIError.notConfigured }
            return try await underlying.send(request)
        }

        static func admits(_ request: URLRequest, expectedHost: String?) -> Bool {
            guard request.httpMethod == "POST", request.url?.query == nil, let url = request.url,
                  let route = AlipayAppPayRoute.allCases.first(where: { url.path.hasSuffix($0.routePath) }),
                  url.host == expectedHost,
                  ReviewedAreaSwitch.moneyPayments(apiHost: url.host ?? expectedHost),
                  !ReleaseMoneyWriteSwitch.blocks(route.routePath),
                  let body = request.httpBody, let text = String(data: body, encoding: .utf8) else { return false }
            return RegistrationAlipayFormID.registrationID(inFormBody: text) != nil
        }
    }
}

/// fix-1128-alipay: the session's Alipay driver + adapter (kept out of AppSession.swift, which may not grow).
/// Same gates as the WeChat adapter: money payment switch on and money payments open for this API host.
@MainActor final class AlipayPayHub {
    let driver: AlipayPaymentDriver
    let adapter: AlipaySDKPaymentAdapter

    init(session: AppSession) {
        let driver = AlipayPaymentDriver()
        self.driver = driver
        self.adapter = AlipaySDKPaymentAdapter(driver: driver, configuration: AlipayPaymentDriver.configuration(),
                                               allowed: { [weak session] in Self.allowed(session) },
                                               context: { [weak session] in session?.currentRuntimeDependencyContext })
    }

    private static func allowed(_ session: AppSession?) -> Bool {
        guard let session, ReleaseMoneyWriteSwitch.paymentEnabled else { return false }
        return session.registrationAppPayAllowed
    }
}

/// What the Alipay hand-off returned, plus whether Alipay could not be opened at all.
struct AlipayLaunchResult: Equatable {
    let providerReturn: TopicSelfPlayProviderReturn
    let alipayMissing: Bool
}
