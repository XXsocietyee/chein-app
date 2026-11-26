import SwiftUI

/// What the pay result screen shows. The owner of the real order write maps the server outcome to one of these;
/// the view never decides that money moved on its own.
enum BundlePayResultPresentation: Equatable {
    /// Waiting for the payment provider / receipt read.
    case processing
    case success
    case failed
}

/// Pay result. Native r2: a system list led by a `ContentUnavailableView`-style result (SF Symbol, title, message),
/// then detail rows and one prominent action. Success: `.success` haptic. Failure: `.warning`, server reason verbatim,
/// retry + back. Processing: a system progress row.
@MainActor struct BundlePayResultView: View {
    let presentation: BundlePayResultPresentation
    let bundleName: String
    var amountText: String? = nil
    var orderNumber: String? = nil
    /// Failure reason from the server; nothing is invented when it is nil.
    var reason: String? = nil
    var primaryTitle: String? = nil
    let onPrimary: () -> Void
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil

    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var reduceMotion
    @State private var landed = false
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    private var markSymbol: String {
        switch presentation {
        case .processing: return "clock"
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    private var tint: Color {
        switch presentation {
        case .processing: return .orange
        case .success: return .green
        case .failed: return .red
        }
    }
    private var title: String {
        switch presentation {
        case .processing: return copy.t("正在确认支付", "Confirming payment")
        case .success: return copy.t("支付成功", "Payment complete")
        case .failed: return copy.t("支付未完成", "Payment not completed")
        }
    }
    private var message: String {
        switch presentation {
        case .processing: return copy.t("正在等待支付渠道回执，通常只需几秒。", "Waiting for the payment provider. This usually takes a few seconds.")
        case .success: return copy.t("套餐已加入你的票夹。", "The bundle is in your ticket wallet.")
        case .failed: return reason.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
            ?? copy.t("未扣款。你可以重试，或返回套餐页。", "You were not charged. Try again or go back to the bundle.")
        }
    }
    private var resolvedPrimary: String {
        if let primaryTitle { return primaryTitle }
        switch presentation {
        case .processing: return copy.t("返回", "Back")
        case .success: return copy.t("查看订单", "View order")
        case .failed: return copy.t("重试", "Try again")
        }
    }
    private var resolvedSecondary: String? {
        if let secondaryTitle { return secondaryTitle }
        return presentation == .failed && onSecondary != nil ? copy.t("返回套餐", "Back to bundle") : nil
    }

    var body: some View {
        List {
            Section {
                ContentUnavailableView {
                    Label {
                        Text(verbatim: title)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("bundle.pay.title")
                    } icon: {
                        Image(systemName: markSymbol)
                            .foregroundStyle(tint)
                            .contentTransition(.symbolEffect(.replace))
                            .accessibilityIdentifier("bundle.pay.mark")
                    }
                } description: {
                    Text(verbatim: message)
                }
                .listRowBackground(Color.clear)
            }
            details
            Section {
                Button(action: onPrimary) {
                    Text(verbatim: resolvedPrimary).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .accessibilityIdentifier("bundle.pay.primary")
                if let resolvedSecondary, let onSecondary {
                    Button(action: onSecondary) {
                        Text(verbatim: resolvedSecondary).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.large)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("bundle.pay.secondary")
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyHeroScreen()
        .themeDomain(.player)
        .cyHaptic(.success, trigger: landed) { _, new in new && presentation == .success }
        .cyHaptic(.warning, trigger: landed) { _, new in new && presentation == .failed }
        .onAppear { land() }
        .onChange(of: presentation) { _, _ in landed = false; land() }
    }

    /// Bundle, amount and order number. Processing shows a system progress row instead of blanks.
    @ViewBuilder private var details: some View {
        if presentation == .processing {
            Section {
                ProgressView().frame(maxWidth: .infinity)
            }
        } else {
            Section {
                detailRow(copy.t("套餐", "Bundle"), value: bundleName, icon: "shippingbox")
                if let amountText {
                    detailRow(copy.t("金额", "Amount"), value: amountText, icon: "yensign.circle", numeric: true)
                }
                if let orderNumber, !orderNumber.isEmpty {
                    detailRow(copy.t("订单号", "Order number"), value: orderNumber, icon: "number", numeric: true)
                }
            }
        }
    }

    private func detailRow(_ title: String, value: String, icon: String, numeric: Bool = false) -> some View {
        LabeledContent {
            Text(verbatim: value)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        } label: {
            Label(title, systemImage: icon)
        }
        .accessibilityElement(children: .combine)
    }

    private func land() {
        guard presentation != .processing else { return }
        if reduceMotion {
            landed = true
            return
        }
        Task { @MainActor in
            // A short beat before the result haptic, as before.
            try? await Task.sleep(for: .milliseconds(560))
            landed = true
        }
    }
}
