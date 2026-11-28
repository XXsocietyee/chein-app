import SwiftUI

/// Gap #9 (1128 plan, O-05 / O-07, P32 checkout): order-detail re-pay carries the same "Pay with" choice as the
/// registration sheet. A USD order gets the `RegistrationPayMethodSection` picker (Apple Pay / Card, narrowed to the
/// order's own `paymentChannels`) and the pay rows follow that choice; a CNY order keeps the pay section's own row
/// (WeChat Pay, plus the `RegistrationPayStepMethodRow` picker while Alipay is offered). The pay itself is unchanged:
/// `RegistrationPaySection` → server read → `onSettled` / `onPaid` reload the order.
@MainActor struct OrderRepaySection: View {
    let detail: OrderLifecycleDetail
    let consented: Bool
    let onSettled: () -> Void
    let onPaid: () -> Void
    @State private var method: RegistrationPayMethod?

    private var market: RegionalMarket? {
        StripePayEligibility.payMarket(currency: detail.currency, paymentChannels: detail.paymentChannels)
    }

    private var isUSD: Bool {
        StripePayEligibility.isUSDOrder(currency: detail.currency, paymentChannels: detail.paymentChannels)
    }

    /// US only: the picker's method when it is still offered, else nil so the pay rows pick their default.
    private var chosen: RegistrationPayMethod? {
        OrderRepayChoice.method(currency: detail.currency, paymentChannels: detail.paymentChannels,
                                selection: method, applePayAvailable: ApplePayStripeAuthorizer.canMakePayments)
    }

    var body: some View {
        if isUSD {
            RegistrationPayMethodSection(selection: $method, price: detail.payableAmount, market: market,
                                         paymentChannels: detail.paymentChannels,
                                         applePayAvailable: ApplePayStripeAuthorizer.canMakePayments,
                                         enabled: true, alipayOffered: false)
        }
        RegistrationPaySection(
            registrationID: detail.id,
            payableAmount: detail.payableAmount,
            consented: consented,
            requiresFreshQuote: false,
            channel: RegistrationAppPayResolver.inAppChannel,
            orderCurrency: detail.currency,
            orderPaymentChannels: detail.paymentChannels,
            payMethod: chosen,
            onSettled: onSettled,
            onPaid: onPaid
        )
    }
}
