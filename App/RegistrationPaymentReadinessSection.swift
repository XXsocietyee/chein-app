import SwiftUI

/// WP-05. Mini-program `baoming.checkPaymentReadiness`: a paid ticket checks `POST /api/registration/payment-readiness`
/// and shows the server sentence, with 「重新检查支付服务」. Tickets are real-world event entry, not digital goods.
/// With the payment area closed (production host, Release) the reader is nil and the section says so instead.
private struct RegistrationPaymentReadinessKey: EnvironmentKey {
    static let defaultValue: (@MainActor () async -> RegistrationPaymentReadiness?)? = nil
}

extension EnvironmentValues {
    var registrationPaymentReadiness: (@MainActor () async -> RegistrationPaymentReadiness?)? {
        get { self[RegistrationPaymentReadinessKey.self] }
        set { self[RegistrationPaymentReadinessKey.self] = newValue }
    }
}

@MainActor struct RegistrationPaymentReadinessSection: View {
    @Environment(\.locale) private var locale
    @Environment(\.registrationPaymentReadiness) private var read
    /// The selected ticket's listed price; only a paid ticket checks readiness.
    let price: Decimal?
    /// Acceptance R2 F-02: the sheet's footer names a `ready: false` answer next to 立即报名 (nil: check failed).
    var onResult: ((RegistrationPaymentReadiness?) -> Void)? = nil
    @State private var checking = false
    @State private var result: RegistrationPaymentReadiness?
    @State private var failed = false

    var body: some View {
        if (price ?? .zero) > .zero {
            Section {
                if read == nil {
                    Label { Text("paymentReadiness.closed", tableName: "PayoutReceiver") } icon: { Image(systemName: "lock") }
                        .foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("paymentReadiness.closed")
                } else if checking {
                    HStack(spacing: CYSpacing.sm) { ProgressView(); Text("paymentReadiness.checking", tableName: "PayoutReceiver") }
                        .accessibilityIdentifier("paymentReadiness.checking")
                } else if let result {
                    LabeledContent {
                        CYStatusChip(verbatim: result.message ?? payoutText(result.ready ? "paymentReadiness.ready" : "paymentReadiness.notReady", locale),
                                     tone: result.ready ? .success : .warning)
                    } label: { Text("paymentReadiness.row", tableName: "PayoutReceiver") }
                        .accessibilityIdentifier(result.ready ? "paymentReadiness.ready" : "paymentReadiness.notReady")
                    if !result.ready {
                        CYPillButton("paymentReadiness.recheck", style: .secondary, tableName: "PayoutReceiver") { Task { await check() } }
                            .accessibilityIdentifier("paymentReadiness.recheck")
                    }
                } else if failed {
                    Text("paymentReadiness.checkFailed", tableName: "PayoutReceiver").foregroundStyle(CYColor.warningText)
                    if let row = RequestReferenceRow(pathFragment: "/api/registration/payment-readiness") { row }
                    CYPillButton("paymentReadiness.recheck", style: .secondary, tableName: "PayoutReceiver") { Task { await check() } }
                }
            } header: { Text("paymentReadiness.title", tableName: "PayoutReceiver") }
            .task(id: price) { await check() }
        }
    }

    private func check() async {
        guard let read, !checking else { return }
        checking = true; failed = false
        defer { checking = false }
        if let value = await read() { result = value } else { result = nil; failed = true }
        onResult?(result)
    }
}
