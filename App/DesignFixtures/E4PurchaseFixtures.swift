#if DEBUG
import SwiftUI

/// e4 hero: purchase motion (docs/release/motion-spec-purchase.md). Mounts the REAL views on the labelled offline bundle
/// and animates the UI states on a timer. No checkout client exists here and `moneyMovingWrites` is false: nothing is bought.
/// `--design-fixture e4-purchase | e4-purchase-fail | e4-purchase-summary | e4-pay-success | e4-pay-failed | e4-pay-processing`.
enum E4PurchaseFixtures {
    /// The purchase write stays off in this lane. The hosts below only step through presentation states.
    static let moneyMovingWrites = false

    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "e4-purchase": return wrap(E4PurchaseFlowFixture(outcome: .success))
        case "e4-purchase-fail": return wrap(E4PurchaseFlowFixture(outcome: .failed))
        case "e4-purchase-summary": return wrap(E4PurchaseFlowFixture(outcome: .success, openSummary: true))
        case "e4-pay-success": return wrap(E4PayResultFixture(presentation: .success))
        case "e4-pay-failed": return wrap(E4PayResultFixture(presentation: .failed))
        case "e4-pay-processing": return wrap(E4PayResultFixture(presentation: .processing))
        default: return nil
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground().themeDomain(.player).preferredColorScheme(.dark))
    }

    static let exampleAmount = "¥199.00"
    static let exampleOrderNumber = "BND-20261110-0007 (offline example)"
    static let exampleReason = "Offline example: the payment provider returned a timeout."
}

/// Detail -> price pill -> summary sheet -> pay (1.2 s processing) -> result. Timer-driven, never a network call.
struct E4PurchaseFlowFixture: View {
    enum Route: Hashable { case result }
    let outcome: BundlePayResultPresentation
    var openSummary = false

    @State private var path: [Route] = []
    @State private var paying = false
    @State private var result: BundlePayResultPresentation = .processing

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let content = E1BundleFixture.exampleDetail(saleEnabled: true) {
                    E4PurchaseDetailHost(content: content, paying: paying, openSummary: openSummary, onPurchase: pay)
                } else {
                    Text(verbatim: "Offline example bundle failed to decode").padding()
                }
            }
            .navigationDestination(for: Route.self) { _ in
                BundlePayResultView(
                    presentation: result,
                    bundleName: "Old Town Night Walk bundle (offline example)",
                    amountText: E4PurchaseFixtures.exampleAmount,
                    orderNumber: result == .success ? E4PurchaseFixtures.exampleOrderNumber : nil,
                    reason: result == .failed ? E4PurchaseFixtures.exampleReason : nil,
                    onPrimary: { if result == .failed { retry() } else { path.removeAll() } },
                    onSecondary: { path.removeAll() }
                )
            }
        }
    }

    private func pay() {
        guard !paying, !E4PurchaseFixtures.moneyMovingWrites else { return }
        paying = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            paying = false
            result = .processing
            path = [.result]
            try? await Task.sleep(for: .milliseconds(1400))
            result = outcome
        }
    }

    private func retry() {
        result = .processing
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1400))
            result = outcome
        }
    }
}

/// Hosts the real detail view; `openSummary` asks it to present the sheet on appear so the compact detent can be shot.
private struct E4PurchaseDetailHost: View {
    let content: BundleDetailContent
    let paying: Bool
    let openSummary: Bool
    let onPurchase: () -> Void

    var body: some View {
        BundleDetailView(content: content, onPurchase: onPurchase, paying: paying, presentsSummaryOnAppear: openSummary)
    }
}

/// Result page alone, one state. Primary and secondary actions just toggle a counter so the press feel can be judged.
struct E4PayResultFixture: View {
    let presentation: BundlePayResultPresentation
    @State private var taps = 0

    var body: some View {
        NavigationStack {
            BundlePayResultView(
                presentation: presentation,
                bundleName: "Old Town Night Walk bundle (offline example)",
                amountText: E4PurchaseFixtures.exampleAmount,
                orderNumber: presentation == .success ? E4PurchaseFixtures.exampleOrderNumber : nil,
                reason: presentation == .failed ? E4PurchaseFixtures.exampleReason : nil,
                onPrimary: { taps += 1 },
                onSecondary: secondary
            )
        }
    }

    private var secondary: (() -> Void)? {
        guard presentation == .failed else { return nil }
        return { taps += 1 }
    }
}
#endif
