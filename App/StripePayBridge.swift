import SwiftUI

/// US launch r1 (lane app-pay). Session glue for the Stripe / Apple Pay channel of a USD order.
/// Behind the same switches as the China pay step: `ReviewedAreaSwitch.moneyPayments` and
/// `ReleaseMoneyWriteSwitch.paymentEnabled`, plus the US market. The China flow never reaches this type.
/// One-app (owner 2026-11-27): "US market" is the per-user market (`RegionalLaunchConfiguration.storefrontMarket`),
/// not the deployment's market, which is China for both markets on the one shared backend.
struct StripePayContext {
    let market: RegionalMarket?
    let createIntent: @MainActor (StripeIntentRequest) async -> Result<StripeIntent, StripePayFailure>
    let confirmApplePay: @MainActor (StripeApplePayConfirmRequest) async -> Result<StripeConfirmResult, StripePayFailure>
    let checkoutURL: @MainActor (StripeIntentRequest) async -> Result<URL, StripePayFailure>
    /// The existing order-status poll (`OrderPaymentVerifier` through `PaymentProviderReturnFlow`).
    let makeReturnFlow: @MainActor (Int) -> PaymentProviderReturnFlow
}

@MainActor enum StripePayBridge {
    static func context(_ session: AppSession) -> StripePayContext? {
        guard RegistrationPayBridge.paymentsOpen(session),
              RegionalLaunchConfiguration.storefrontMarket == .unitedStates else { return nil }
        return StripePayContext(
            market: RegionalLaunchConfiguration.storefrontMarket,
            createIntent: { body in
                await perform(session) { configuration, transport, token in
                    await StripePayService.createIntent(body, configuration: configuration, transport: transport, token: token)
                }
            },
            confirmApplePay: { body in
                await perform(session) { configuration, transport, token in
                    await StripePayService.confirmApplePay(body, configuration: configuration, transport: transport, token: token)
                }
            },
            checkoutURL: { body in
                await perform(session) { configuration, transport, token in
                    await StripePayService.checkoutURL(body, configuration: configuration, transport: transport, token: token)
                }
            },
            makeReturnFlow: { registrationID in
                let reader = session.orderLifecycleReader
                return PaymentProviderReturnFlow(
                    registrationID: registrationID,
                    verifier: OrderPaymentVerifier(currentScope: { reader.scope }, read: { id in try await reader.detail(id: id) }),
                    currentScope: { reader.scope })
            })
    }

    private static func perform<Value>(_ session: AppSession,
                                       _ call: (APIConfiguration, any HTTPTransport, String) async -> Result<Value, StripePayFailure>)
        async -> Result<Value, StripePayFailure> {
        guard RegistrationPayBridge.paymentsOpen(session), RegionalLaunchConfiguration.storefrontMarket == .unitedStates,
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

    /// Strict app-side lease: a JSON POST to one of the three Stripe routes on the configured host, with the
    /// payment switch on. Everything else is refused before it reaches the network.
    struct StripePayLease: HTTPTransport {
        let underlying: any HTTPTransport
        let expectedHost: String?

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            guard request.httpMethod == "POST", let url = request.url, url.query == nil,
                  url.host == expectedHost,
                  let route = StripePayRoute.allCases.first(where: { url.path.hasSuffix("/" + $0.rawValue) }),
                  ReviewedAreaSwitch.moneyPayments(apiHost: url.host),
                  !ReleaseMoneyWriteSwitch.blocks(route.routePath),
                  request.value(forHTTPHeaderField: "Content-Type") == "application/json",
                  let body = request.httpBody, !body.isEmpty else {
                throw APIError.notConfigured
            }
            return try await underlying.send(request)
        }
    }
}

private struct StripePayContextKey: EnvironmentKey {
    static let defaultValue: StripePayContext? = nil
}

extension EnvironmentValues {
    /// Nil outside the US market or while payments are closed; the pay step then keeps the China flow.
    var stripePayContext: StripePayContext? {
        get { self[StripePayContextKey.self] }
        set { self[StripePayContextKey.self] = newValue }
    }
}
