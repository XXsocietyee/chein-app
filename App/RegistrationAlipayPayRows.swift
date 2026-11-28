import SwiftUI

/// fix-1128-alipay (audit P0-4): the CN pay step's Alipay path, beside the WeChat Pay rows.
/// `POST /api/pay/alipay/order` → Alipay → one `POST /api/pay/alipay/query`, then the same result states as
/// WeChat Pay: paid → ticket in the wallet; cancelled → Pay again; unknown → Checking payment… + Refresh.
struct RegistrationAlipayPayContext {
    let isAvailable: @MainActor () -> Bool
    let createOrder: @MainActor (Int) async -> AlipayAppPayOrderOutcome
    let launch: @MainActor (Int, AlipayAppPayOrder) async -> AlipayLaunchResult
    let query: @MainActor (Int) async -> AlipayAppPayQueryResult?
    let isWaiting: @MainActor () -> Bool
    let endPendingWait: @MainActor () -> Void
}

private struct RegistrationAlipayPayContextKey: EnvironmentKey {
    static let defaultValue: RegistrationAlipayPayContext? = nil
}

/// The registration sheet's "Pay with" choice, read by the pay step. Nil (order detail) means the market default.
private struct RegistrationPayMethodChoiceKey: EnvironmentKey {
    static let defaultValue: RegistrationPayMethod? = nil
}

extension EnvironmentValues {
    var registrationAlipayPay: RegistrationAlipayPayContext? {
        get { self[RegistrationAlipayPayContextKey.self] }
        set { self[RegistrationAlipayPayContextKey.self] = newValue }
    }

    var registrationPayMethodChoice: RegistrationPayMethod? {
        get { self[RegistrationPayMethodChoiceKey.self] }
        set { self[RegistrationPayMethodChoiceKey.self] = newValue }
    }
}

/// Builds the Alipay hand-off from the session. Nil while money payments are closed.
@MainActor enum RegistrationAlipayBridge {
    static func context(_ session: AppSession) -> RegistrationAlipayPayContext? {
        guard ReleaseMoneyWriteSwitch.paymentEnabled, session.registrationAppPayAllowed else { return nil }
        return RegistrationAlipayPayContext(
            isAvailable: { session.alipayPaymentReady },
            createOrder: { registrationID in await session.alipayCreateOrder(registrationID: registrationID) },
            launch: { registrationID, order in await session.alipayLaunch(registrationID: registrationID, order: order) },
            query: { registrationID in await session.alipayQuery(registrationID: registrationID) },
            isWaiting: { session.alipayWaiting },
            endPendingWait: { session.alipayEndPendingWait() }
        )
    }

    /// Alipay is a choice for this order: backend lists `APP_ALIPAY` and the app can open Alipay.
    static func offered(_ context: RegistrationAlipayPayContext?, paymentChannels: [String]?) -> Bool {
        AlipayAppPayChannel.offered(paymentChannels: paymentChannels, providerReady: context?.isAvailable() == true)
    }

    /// "Pay ¥12.50 with WeChat Pay" / "Pay ¥12.50 with Alipay" (P32: the button is the method).
    static func payButtonTitle(_ method: RegistrationPayMethod, amountText: String, locale: Locale) -> String {
        let format = appLocalized(String.LocalizationValue(method.payButtonKey), locale: locale)
        return String(format: format, amountText)
    }
}

/// Rows under 订单支付 when the player pays with Alipay.
@MainActor struct RegistrationAlipayPayRows: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    let context: RegistrationAlipayPayContext
    let registrationID: Int
    let amountText: String
    let onExpiredRebuild: (() -> Void)?

    @State private var stage: RegistrationAlipayStage = .ready
    @State private var working = false
    @State private var showsWallet = false

    var body: some View {
        Group {
            switch stage {
            case .ready: payButton
            case .requestingOrder: progressRow("alipay.pay.requesting")
            case .launching: progressRow("alipay.pay.opening")
            case .paid: paidRows
            case .cancelled: cancelledRows
            case .checking: checkingRows
            case .alipayUnavailable(let message): unavailableRows(message)
            case .expired(let message): expiredRows(message)
            case .rejected(let message): rejectedRows(message)
            case .signedOut: signedOutRow
            }
        }
        .onChange(of: scenePhase) { _, phase in appPhaseChanged(phase) }
        .sensoryFeedback(.success, trigger: stage, condition: Self.becamePaid)
        .cySheet(isPresented: $showsWallet) { walletSheet }
    }

    private static func becamePaid(_ old: RegistrationAlipayStage, _ new: RegistrationAlipayStage) -> Bool {
        new == .paid && old != .paid
    }

    private var walletSheet: some View {
        SessionTicketWalletHost(onClose: { showsWallet = false }, focusRegistrationID: registrationID)
    }

    private var payTitle: String {
        RegistrationAlipayBridge.payButtonTitle(.alipay, amountText: amountText, locale: locale)
    }

    private var payButton: some View {
        Button {
            Task { await pay() }
        } label: {
            Text(verbatim: payTitle).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(working)
        .accessibilityIdentifier("registration.pay.alipay.submit")
    }

    private func progressRow(_ key: LocalizedStringKey) -> some View {
        HStack(spacing: CYSpacing.sm) {
            ProgressView()
            Text(key)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("registration.pay.alipay.progress")
    }

    @ViewBuilder private var paidRows: some View {
        Label {
            Text("alipay.pay.paid")
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(CYColor.successText)
        }
        .accessibilityIdentifier("registration.pay.alipay.paid")
        Button {
            showsWallet = true
        } label: {
            Label("alipay.pay.viewTicket", systemImage: "ticket")
        }
        .accessibilityIdentifier("registration.pay.alipay.openTicket")
    }

    @ViewBuilder private var cancelledRows: some View {
        Text("alipay.pay.cancelled")
            .foregroundStyle(CYColor.textSecondary)
            .accessibilityIdentifier("registration.pay.alipay.cancelled")
        Button {
            Task { await pay() }
        } label: {
            Text("alipay.pay.again").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(working)
        .accessibilityIdentifier("registration.pay.alipay.again")
    }

    @ViewBuilder private var checkingRows: some View {
        HStack(spacing: CYSpacing.sm) {
            ProgressView()
            Text("alipay.pay.checking")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("registration.pay.alipay.checking")
        Button {
            Task { await refresh() }
        } label: {
            Text("alipay.pay.refresh")
        }
        .buttonStyle(.bordered)
        .disabled(working)
        .accessibilityIdentifier("registration.pay.alipay.refresh")
    }

    @ViewBuilder private func unavailableRows(_ message: String?) -> some View {
        Label {
            if let message {
                Text(verbatim: message)
            } else {
                Text("alipay.pay.unavailable")
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .foregroundStyle(CYColor.warningText)
        .accessibilityIdentifier("registration.pay.alipay.unavailable")
        Text("alipay.pay.useWeChat")
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
    }

    @ViewBuilder private func expiredRows(_ message: String?) -> some View {
        Group {
            if let message {
                Text(verbatim: message)
            } else {
                Text("alipay.pay.expired")
            }
        }
        .foregroundStyle(CYColor.warningText)
        .accessibilityIdentifier("registration.pay.alipay.expired")
        if let onExpiredRebuild {
            Button("alipay.pay.rebuild") { onExpiredRebuild() }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("registration.pay.alipay.rebuild")
        }
    }

    @ViewBuilder private func rejectedRows(_ message: String?) -> some View {
        Group {
            if let message {
                Text(verbatim: message)
            } else {
                Text("alipay.pay.rejected")
            }
        }
        .foregroundStyle(CYColor.warningText)
        .accessibilityIdentifier("registration.pay.alipay.rejected")
        payButton
    }

    private var signedOutRow: some View {
        Text("alipay.pay.signedOut")
            .foregroundStyle(CYColor.warningText)
            .accessibilityIdentifier("registration.pay.alipay.signedOut")
    }

    /// Order → Alipay → one query. Never retried automatically.
    private func pay() async {
        guard !working, RegistrationAlipayResolver.canPay(stage) else { return }
        guard context.isAvailable() else {
            stage = .alipayUnavailable(message: nil)
            return
        }
        working = true
        stage = .requestingOrder
        let outcome = await context.createOrder(registrationID)
        if let settled = RegistrationAlipayResolver.stage(orderOutcome: outcome) {
            stage = settled
            if settled == .checking { await readOnce(providerReturn: .unknown) }
            working = false
            return
        }
        guard case .order(let order) = outcome else {
            stage = .checking
            working = false
            return
        }
        stage = .launching
        let launched = await context.launch(registrationID, order)
        if launched.alipayMissing {
            stage = .alipayUnavailable(message: nil)
        } else {
            await readOnce(providerReturn: launched.providerReturn)
        }
        working = false
    }

    private func readOnce(providerReturn: TopicSelfPlayProviderReturn) async {
        let result = await context.query(registrationID)
        stage = RegistrationAlipayResolver.stage(providerReturn: providerReturn, query: result)
    }

    private func refresh() async {
        guard !working else { return }
        working = true
        let result = await context.query(registrationID)
        stage = RegistrationAlipayResolver.refreshed(query: result)
        working = false
    }

    /// The player came back from Alipay without the return URL (switched by hand): end the wait after a short
    /// grace so a late return URL still wins; the query then decides.
    private func appPhaseChanged(_ phase: ScenePhase) {
        guard phase == .active, stage == .launching else { return }
        Task { await endWaitAfterGrace() }
    }

    private func endWaitAfterGrace() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        guard stage == .launching, context.isWaiting() else { return }
        context.endPendingWait()
    }
}

/// P32 "Pay with" on the CN pay step itself (registration result and order detail): WeChat Pay (default) and
/// Alipay, shown only while Alipay is offered for this order. Official names, system menu picker, no logos.
struct RegistrationPayStepMethodRow: View {
    @Environment(\.locale) private var locale
    @Binding var selection: RegistrationPayMethod
    let enabled: Bool

    private func name(_ method: RegistrationPayMethod) -> String {
        CoreLoopCopy(locale: locale).t(method.names.zh, method.names.en)
    }

    var body: some View {
        Picker(selection: $selection) {
            Text(verbatim: name(.wechatPay)).tag(RegistrationPayMethod.wechatPay)
            Text(verbatim: name(.alipay)).tag(RegistrationPayMethod.alipay)
        } label: {
            Text("registration.payWith.label")
        }
        .pickerStyle(.menu)
        .disabled(!enabled)
        .accessibilityIdentifier("registration.pay.method")
    }
}
