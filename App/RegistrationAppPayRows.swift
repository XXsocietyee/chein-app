import SwiftUI

/// Owner check 11-28 05:35 (P0): after `pay/app` returns WeChat APP params, hand them to the session's
/// WeChat SDK provider (the one self-play checkout and order lifecycle use), then read the registration once.
struct RegistrationAppPayContext {
    let isAvailable: @MainActor () -> Bool
    let launch: @MainActor (Int, [String: String]) async -> TopicSelfPlayProviderReturn
    let readPaymentStatus: @MainActor (Int) async -> Int?
}

private struct RegistrationAppPayContextKey: EnvironmentKey {
    static let defaultValue: RegistrationAppPayContext? = nil
}

extension EnvironmentValues {
    var registrationAppPay: RegistrationAppPayContext? {
        get { self[RegistrationAppPayContextKey.self] }
        set { self[RegistrationAppPayContextKey.self] = newValue }
    }
}

/// Rows under 订单支付 once the order has pay params: opening WeChat → paid / cancelled / checking.
/// fix/1128-cn-pay P1-2: with empty `parameters` (a pay response without provider params) nothing opens; the one
/// `api/registration/info` read alone decides paid / checking. No row ever says paid without that read.
@MainActor struct RegistrationAppPayRows: View {
    @Environment(\.locale) private var locale
    let context: RegistrationAppPayContext?
    let registrationID: Int
    let parameters: [String: String]
    /// Called once the server read says paid, so the host refreshes its order / registration status.
    var onSettled: (() -> Void)? = nil

    @State private var stage: RegistrationAppPayStage = .launching
    @State private var started = false
    @State private var working = false
    @State private var showsWallet = false

    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        Group {
            switch stage {
            case .launching: launchingRow
            case .paid: paidRows
            case .cancelled: cancelledRows
            case .checking: checkingRows
            case .weChatUnavailable: unavailableRow
            }
        }
        .task(id: registrationID) { await startOnce() }
        .sensoryFeedback(.success, trigger: stage, condition: Self.becamePaid)
        .sensoryFeedback(.warning, trigger: stage, condition: Self.becameCancelled)
        .onChange(of: stage) { old, new in
            if Self.becamePaid(old, new) { onSettled?() }
        }
        .cySheet(isPresented: $showsWallet) { walletSheet }
    }

    private static func becamePaid(_ old: RegistrationAppPayStage, _ new: RegistrationAppPayStage) -> Bool {
        new == .paid && old != .paid
    }

    private static func becameCancelled(_ old: RegistrationAppPayStage, _ new: RegistrationAppPayStage) -> Bool {
        new == .cancelled && old != .cancelled
    }

    private var walletSheet: some View {
        SessionTicketWalletHost(onClose: { showsWallet = false }, focusRegistrationID: registrationID)
    }

    private var launchingRow: some View {
        HStack(spacing: CYSpacing.sm) {
            ProgressView()
            Text(c.t("正在打开微信支付…", "Opening WeChat Pay…"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("registration.pay.launching")
    }

    @ViewBuilder private var paidRows: some View {
        Label {
            Text(c.t("支付成功，票已放入票夹", "Paid. Your ticket is in the wallet."))
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CYColor.successText)
                .symbolEffect(.bounce, value: stage == .paid)
        }
        .accessibilityIdentifier("registration.pay.paid")
        Button {
            showsWallet = true
        } label: {
            Label(c.t("查看门票", "View ticket"), systemImage: "ticket")
        }
        .accessibilityIdentifier("registration.pay.openTicket")
    }

    @ViewBuilder private var cancelledRows: some View {
        Text(c.t("支付已取消", "Payment cancelled"))
            .foregroundStyle(CYColor.textSecondary)
            .accessibilityIdentifier("registration.pay.cancelled")
        Button(c.t("重新支付", "Pay again")) {
            Task { await launch() }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(working)
        .accessibilityIdentifier("registration.pay.again")
    }

    @ViewBuilder private var checkingRows: some View {
        HStack(spacing: CYSpacing.sm) {
            ProgressView()
            Text(c.t("正在确认支付结果…", "Checking payment…"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("registration.pay.checkingResult")
        if context != nil {
            Button(c.t("刷新", "Refresh")) {
                Task { await refresh() }
            }
            .buttonStyle(.bordered)
            .disabled(working)
            .accessibilityIdentifier("registration.pay.refresh")
        }
    }

    private var unavailableRow: some View {
        Label {
            Text(c.t("未检测到可用的微信，请安装或更新微信后重试。",
                     "WeChat isn't available. Install or update WeChat, then try again."))
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .foregroundStyle(CYColor.warningText)
        .accessibilityIdentifier("registration.pay.weChatUnavailable")
    }

    private func startOnce() async {
        guard !started else { return }
        started = true
        await launch()
    }

    private func launch() async {
        guard !working else { return }
        if parameters.isEmpty {
            // P1-2: no provider step. Read once; paid only when the server says `paymentStatus == 2`.
            stage = .checking
            await refresh()
            return
        }
        guard let context, context.isAvailable() else {
            stage = .weChatUnavailable
            return
        }
        working = true
        stage = .launching
        let providerReturn = await context.launch(registrationID, parameters)
        let status = await context.readPaymentStatus(registrationID)
        stage = RegistrationAppPayResolver.stage(providerReturn: providerReturn, paymentStatus: status)
        working = false
    }

    private func refresh() async {
        guard !working, let context else { return }
        working = true
        let status = await context.readPaymentStatus(registrationID)
        stage = RegistrationAppPayResolver.refreshed(paymentStatus: status)
        working = false
    }
}

/// Builds the WeChat hand-off from the session. WeChat opens only while the session's provider is configured
/// (payment switch on, SDK linked, build-setting identity present); otherwise `isAvailable` is false.
@MainActor enum RegistrationAppPayBridge {
    /// fix/1128-cn-pay P1-2: always built for a session, so the one status read works even when WeChat is not
    /// configured; `isAvailable` alone says whether WeChat can open.
    static func context(_ session: AppSession) -> RegistrationAppPayContext? {
        RegistrationAppPayContext(
            isAvailable: { session.registrationPaymentProvider?.isConfigured == true },
            launch: { registrationID, parameters in
                guard let provider = session.registrationPaymentProvider else { return .unknown }
                return await provider.pay(registrationID: registrationID, parameters: parameters)
            },
            readPaymentStatus: { registrationID in
                await session.readRegistrationPaymentStatus(registrationID: registrationID)
            }
        )
    }
}
