import SwiftUI

/// US launch r1 (lane app-pay); fix 11-28 (audit P0-3 / P1-3). Session glue for the Stripe / Apple Pay channel of a
/// USD order. Behind the same switches as the China pay step: `ReviewedAreaSwitch.moneyPayments` and
/// `ReleaseMoneyWriteSwitch.paymentEnabled`. P1-3: there is no storefront-market gate any more. The backend decides
/// USD per topic, so the pay step picks Stripe from the quote / order `currency` + `paymentChannels`
/// (`StripePayEligibility.applies`); a China-storefront player on a USD topic gets Stripe, never a 409 from the
/// China route.
struct StripePayContext {
    let createIntent: @MainActor (StripeIntentRequest) async -> Result<StripeIntent, StripePayFailure>
    let confirmApplePay: @MainActor (StripeApplePayConfirmRequest) async -> Result<StripeConfirmResult, StripePayFailure>
    let checkout: @MainActor (StripeIntentRequest) async -> Result<StripeCheckoutSession, StripePayFailure>
    /// `api/registration/info` `paymentStatus` (2 = paid), the same server read the China pay rows use. Nil when unread.
    let readPaymentStatus: @MainActor (Int) async -> Int?
}

@MainActor enum StripePayBridge {
    static func context(_ session: AppSession) -> StripePayContext? {
        guard RegistrationPayBridge.paymentsOpen(session) else { return nil }
        return StripePayContext(
            createIntent: { body in await createIntent(session, body) },
            confirmApplePay: { body in await confirmApplePay(session, body) },
            checkout: { body in await checkout(session, body) },
            readPaymentStatus: { registrationID in
                await session.readRegistrationPaymentStatus(registrationID: registrationID)
            })
    }

    private static func createIntent(_ session: AppSession, _ body: StripeIntentRequest) async -> Result<StripeIntent, StripePayFailure> {
        await perform(session) { configuration, transport, token in
            await StripePayService.createIntent(body, configuration: configuration, transport: transport, token: token)
        }
    }

    private static func confirmApplePay(_ session: AppSession,
                                        _ body: StripeApplePayConfirmRequest) async -> Result<StripeConfirmResult, StripePayFailure> {
        await perform(session) { configuration, transport, token in
            await StripePayService.confirmApplePay(body, configuration: configuration, transport: transport, token: token)
        }
    }

    private static func checkout(_ session: AppSession, _ body: StripeIntentRequest) async -> Result<StripeCheckoutSession, StripePayFailure> {
        await perform(session) { configuration, transport, token in
            await StripePayService.checkout(body, configuration: configuration, transport: transport, token: token)
        }
    }

    private static func perform<Value>(_ session: AppSession,
                                       _ call: (APIConfiguration, any HTTPTransport, String) async -> Result<Value, StripePayFailure>)
        async -> Result<Value, StripePayFailure> {
        guard RegistrationPayBridge.paymentsOpen(session),
              let configuration = session.regionalConfiguration?.apiConfiguration else { return .failure(.closed) }
        guard let token = session.token, AuthRequestBuilder.isValidToken(token) else { return .failure(.signedOut) }
        let stamp = session.sessionRevision
        let transport = StripePayLease(underlying: session.composition.makeTransport(), expectedHost: configuration.baseURL.host)
        let result = await call(configuration, transport, token)
        if case .failure(.unauthorized) = result {
            session.expireIfMatching(error: APIError.unauthorized, stamp: stamp, credential: token)
        }
        return result
    }

    /// Strict app-side lease: a form-encoded POST (`ApiStripePayController` binds form parameters) to one of the three
    /// Stripe routes on the configured host, with the payment switch on. Everything else is refused before the network.
    struct StripePayLease: HTTPTransport {
        let underlying: any HTTPTransport
        let expectedHost: String?

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            guard Self.admits(request, expectedHost: expectedHost) else { throw APIError.notConfigured }
            return try await underlying.send(request)
        }

        static func admits(_ request: URLRequest, expectedHost: String?) -> Bool {
            guard request.httpMethod == "POST", let url = request.url, url.query == nil,
                  url.host == expectedHost,
                  let route = StripePayRoute.allCases.first(where: { url.path.hasSuffix("/" + $0.rawValue) }),
                  ReviewedAreaSwitch.moneyPayments(apiHost: url.host),
                  !ReleaseMoneyWriteSwitch.blocks(route.routePath),
                  request.value(forHTTPHeaderField: "Content-Type") == StripePayWire.contentType,
                  let body = request.httpBody, !body.isEmpty else { return false }
            return true
        }
    }
}

private struct StripePayContextKey: EnvironmentKey {
    static let defaultValue: StripePayContext? = nil
}

extension EnvironmentValues {
    /// Nil while payments are closed. Otherwise the pay step uses it only for a USD order (`StripePayEligibility.applies`).
    var stripePayContext: StripePayContext? {
        get { self[StripePayContextKey.self] }
        set { self[StripePayContextKey.self] = newValue }
    }
}
