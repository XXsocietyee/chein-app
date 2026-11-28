import SwiftUI

/// Sweep 04:50 (mp-activity P1) / owner correction 11-28 04:45: a "Pay with" row under 费用明细.
/// CN: WeChat Pay (default) / Alipay. US: Apple Pay (default when the device can pay) / Card (Stripe).
/// Fix 11-28 P1-3: `market` is the order's pay market from the quote currency (`StripePayEligibility.payMarket`), not the
/// storefront; `paymentChannels` narrows the US options to what the backend offers for this order.
/// Official names as plain system rows (no logos). Free tickets show no row.
struct RegistrationPayMethodSection: View {
    @Environment(\.locale) private var locale
    @Binding var selection: RegistrationPayMethod?
    let price: Decimal?
    let market: RegionalMarket?
    var paymentChannels: [String]? = nil
    let applePayAvailable: Bool
    let enabled: Bool
    /// Sweep 13:15 P1 / P32 "fits on one screen": the registration sheet draws this row in its bottom bar, right above
    /// the consent switch, so the method stays in view next to the method-labelled button (no `Section` there).
    var inCheckoutBar: Bool = false
    /// fix-1128-alipay: the quote lists `APP_ALIPAY` and the app can open Alipay.
    var alipayOffered: Bool = RegistrationPayMethod.alipayReady

    private var options: [RegistrationPayMethod] {
        RegistrationPayMethod.options(market: market, applePayAvailable: applePayAvailable, alipayReady: alipayOffered,
                                      paymentChannels: paymentChannels)
    }

    private var current: RegistrationPayMethod {
        if let selection, options.contains(selection) { return selection }
        return options[0]
    }

    private var binding: Binding<RegistrationPayMethod> {
        Binding(get: { current }, set: { selection = $0 })
    }

    private func name(_ channel: RegistrationPayMethod) -> String {
        CoreLoopCopy(locale: locale).t(channel.names.zh, channel.names.en)
    }

    var body: some View {
        if (price ?? .zero) > .zero {
            if inCheckoutBar { barRow } else { listSection }
        }
    }

    private var barRow: some View {
        LabeledContent {
            Picker(selection: binding) {
                ForEach(options, id: \.self) { channel in
                    Text(verbatim: name(channel)).tag(channel)
                }
            } label: {
                Text(verbatim: CoreLoopCopy(locale: locale).t("支付方式", "Pay with"))
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(!enabled)
        } label: {
            Text(verbatim: CoreLoopCopy(locale: locale).t("支付方式", "Pay with"))
        }
        .font(.footnote)
        .accessibilityIdentifier("registration.form.payChannel")
    }

    @ViewBuilder private var listSection: some View {
        Section {
            Picker(selection: binding) {
                ForEach(options, id: \.self) { channel in
                    Text(verbatim: name(channel)).tag(channel)
                }
            } label: {
                Text(verbatim: CoreLoopCopy(locale: locale).t("支付方式", "Pay with"))
            }
            .pickerStyle(.menu)
            .disabled(!enabled)
            .accessibilityIdentifier("registration.form.payChannel")
            #if DEBUG
            if RegistrationPayMethod.showsAlipayComingSoon(market: market, alipayReady: alipayOffered) {
                LabeledContent {
                    Text(verbatim: CoreLoopCopy(locale: locale).t("即将上线", "Coming soon"))
                } label: {
                    Text(verbatim: name(.alipay))
                }
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("registration.form.payChannel.alipaySoon")
            }
            #endif
        }
    }
}
