import SwiftUI

/// What the pay result screen shows. The owner of the real order write maps the server outcome to one of these;
/// the view never decides that money moved on its own.
enum BundlePayResultPresentation: Equatable {
    /// Waiting for the payment provider / receipt read.
    case processing
    case success
    case failed
}

/// Pay result (docs/release/motion-spec-purchase.md). Player dark, one visible title, one primary action.
/// Success: ring + checkmark draw-on, soft confetti, `.success` haptic. Failure: cross + one nudge, `.warning`,
/// server reason verbatim, retry + back. Processing: rotating arc and skeleton rows. All gated on Reduce Motion.
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
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var landed = false
    @State private var burst = 0
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    private var markKind: CYResultMark.Kind {
        switch presentation {
        case .processing: return .pending
        case .success: return .success
        case .failed: return .failure
        }
    }
    private var tint: Color {
        switch presentation {
        case .processing: return palette.warning
        case .success: return palette.success
        case .failed: return palette.danger
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
        ZStack {
            palette.bgPage.ignoresSafeArea()
            RadialGradient(colors: [tint.opacity(0.28), .clear], center: .init(x: 0.5, y: 0.3), startRadius: 10, endRadius: 340)
                .ignoresSafeArea()
                .cyAnimation(value: presentation)
            ScrollView {
                VStack(spacing: CYSpacing.xxl) {
                    Spacer(minLength: CYSpacing.hero)
                    CYResultMark(kind: markKind, size: 132)
                        .accessibilityIdentifier("bundle.pay.mark")
                    VStack(spacing: CYSpacing.sm) {
                        Text(verbatim: title)
                            .cyText(.pageTitle)
                            .foregroundStyle(palette.textPrimary)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("bundle.pay.title")
                        Text(verbatim: message)
                            .cyText(.body)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .cyEntrance(delay: reduceMotion ? 0 : 0.3, scale: 1)
                    details
                        .cyEntrance(delay: reduceMotion ? 0 : 0.42, scale: 1)
                    Spacer(minLength: CYSpacing.lg)
                    VStack(spacing: CYSpacing.sm) {
                        CYPillButton(verbatim: resolvedPrimary, style: .primary, action: onPrimary)
                            .accessibilityIdentifier("bundle.pay.primary")
                        if let resolvedSecondary, let onSecondary {
                            CYPillButton(verbatim: resolvedSecondary, style: .tertiary, action: onSecondary)
                                .accessibilityIdentifier("bundle.pay.secondary")
                        }
                    }
                    .cyEntrance(delay: reduceMotion ? 0 : 0.5, scale: 1)
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.bottom, CYSpacing.xxl)
                .frame(maxWidth: .infinity)
            }
            CYConfettiBurst(trigger: burst, pieces: 26)
        }
        .cyHeroScreen()
        .themeDomain(.player)
        .cyHaptic(.success, trigger: landed) { _, new in new && presentation == .success }
        .cyHaptic(.warning, trigger: landed) { _, new in new && presentation == .failed }
        .onAppear { land() }
        .onChange(of: presentation) { _, _ in landed = false; land() }
    }

    /// Bundle, amount and order number. Processing shows content-shaped placeholders instead of blanks.
    @ViewBuilder private var details: some View {
        if presentation == .processing {
            CYSkeleton().accessibilityHidden(true)
        } else {
            VStack(spacing: 0) {
                detailRow(copy.t("套餐", "Bundle"), value: bundleName, icon: "shippingbox")
                if let amountText {
                    Divider().overlay(palette.borderSubtle).padding(.leading, 52)
                    detailRow(copy.t("金额", "Amount"), value: amountText, icon: "yensign.circle", numeric: true)
                }
                if let orderNumber, !orderNumber.isEmpty {
                    Divider().overlay(palette.borderSubtle).padding(.leading, 52)
                    detailRow(copy.t("订单号", "Order number"), value: orderNumber, icon: "number", numeric: true)
                }
            }
            .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.md)
        }
    }

    private func detailRow(_ title: String, value: String, icon: String, numeric: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            CYRowIcon(systemImage: icon)
            Text(verbatim: title).cyText(.body).foregroundStyle(palette.textSecondary)
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: value)
                .cyText(numeric ? .numericBody : .bodyMedium)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, CYSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private func land() {
        guard presentation != .processing else { return }
        if reduceMotion {
            landed = true
            return
        }
        Task { @MainActor in
            // The check finishes stroking at about 0.6 s (ring 0.35 s, stroke 0.4 s after 0.2 s).
            try? await Task.sleep(for: .milliseconds(560))
            landed = true
            if presentation == .success { burst += 1 }
        }
    }
}
