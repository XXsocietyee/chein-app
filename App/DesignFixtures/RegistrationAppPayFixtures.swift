import SwiftUI

/// Sweep fixtures `t5-baoming-paying` / `t5-baoming-paid` (owner check 11-28 05:35): the 订单支付 section after
/// `pay/app` returned WeChat APP params. A stub provider stands in for the WeChat SDK; nothing leaves the device.
@MainActor struct RegistrationAppPayFixtureHost: View {
    @Environment(\.locale) private var locale
    let paid: Bool

    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    private var context: RegistrationAppPayContext {
        let paid = paid
        return RegistrationAppPayContext(
            isAvailable: { true },
            launch: { _, _ in
                if paid { return .returned }
                try? await Task.sleep(nanoseconds: 3_600_000_000_000)
                return .unknown
            },
            readPaymentStatus: { _ in paid ? 2 : 1 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(c.t("待支付金额", "Amount due")) {
                        Text(verbatim: "¥68.00").monospacedDigit()
                    }
                    RegistrationAppPayRows(context: context, registrationID: 9001,
                                           parameters: ["prepayid": "fixture", "package": "Sign=WXPay"])
                } header: {
                    Text(c.t("订单支付", "Order payment"))
                }
            }
            .appNavigationTitle("registration.form.title")
        }
    }
}
