import SwiftUI

/// Sweep 04:50 (mp-activity P1) / owner correction 11-28 04:45: a "Pay with" row under 费用明细.
/// CN: WeChat Pay (default) / Alipay. US: Apple Pay (default when the device can pay) / Card (Stripe).
/// Official names as plain system rows (no logos). Free tickets show no row.
struct RegistrationPayMethodSection: View {
    @Environment(\.locale) private var locale
    @Binding var selection: RegistrationPayMethod?
    let price: Decimal?
    let market: RegionalMarket?
    let applePayAvailable: Bool
    let enabled: Bool

    private var options: [RegistrationPayMethod] {
        RegistrationPayMethod.options(market: market, applePayAvailable: applePayAvailable)
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
                if RegistrationPayMethod.showsAlipayComingSoon(market: market) {
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
}
