import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

private struct VerificationCodeFactoryKey: EnvironmentKey {
    static let defaultValue: (@MainActor (VerificationCodeTarget) -> VerificationCodeCoordinator)? = nil
}
extension EnvironmentValues {
    var verificationCodeFactory: (@MainActor (VerificationCodeTarget) -> VerificationCodeCoordinator)? {
        get { self[VerificationCodeFactoryKey.self] }
        set { self[VerificationCodeFactoryKey.self] = newValue }
    }
}

/// Native presentation uses the exact validated server payload and never a screenshot,
/// decorative QR, remote URL encoded as a token, or persistent credential/image cache.
@MainActor struct VerificationCodeView: View {
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @State var model: VerificationCodeCoordinator
    /// City voucher only: the node name shown as the title (mini-program `citynode-code`, default 据点).
    var title: String? = nil
    /// City voucher opened from a known node requests its code on appear. The approval gate is unchanged.
    var autoIssue = false
    /// Pass-sheet mode: no hero header, no own scroll or background, QR drawn at `qrSide` pt on white.
    var embeddedQRSide: CGFloat? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var operation: Task<Void, Never>?
    @State private var revealSweep = false
    var body: some View {
        if embeddedQRSide != nil { lifecycle(stack) } else if model.target.kind == .cityVoucher, autoIssue {
            // RCODE-3: the node name is the system inline title (MP 据点核销码 nav title), not a heading in the content.
            lifecycle(ScrollView { stack.padding().frame(maxWidth: .infinity) }
                .cyPageTitle(verbatim: title ?? appLocalized("roamSub.w208.voucher.defaultName", locale: locale)))
        } else {
            lifecycle(ScrollView { stack.padding().frame(maxWidth: .infinity) }.cyHeroScreen())
        }
    }
    private var stack: some View {
            VStack(spacing: 20) {
                if embeddedQRSide != nil {
                } else if model.target.kind == .cityVoucher, autoIssue {
                    // RCODE-3: titled by the navigation bar.
                } else {
                    CYHeroHeader(model.target.kind == .ticket ? "verificationCode.ticket.title" : "verificationCode.city.title")
                }
                content
                if model.target.kind == .ticket, model.readback != nil {
                    CYPillButton("verificationCode.checkOrder", style: .secondary) { run { await model.checkOrder() } }
                        .disabled(model.checkingOrder || model.phase == .loading)
                        .accessibilityIdentifier("verificationCode.checkOrder")
                    if model.checkingOrder { CYSkeleton() }
                    if model.readbackFailed { Text("verificationCode.readbackFailed").cyText(.bodyCompact) }
                    if let detail = model.readback {
                        CYStatusChip(detail.registrationStatus == 2 ? "verificationCode.order.active" : "verificationCode.order.ended",
                                     tone: detail.registrationStatus == 2 ? .success : .neutral,
                                     systemImage: detail.registrationStatus == 2 ? "checkmark.circle" : "clock")
                            .accessibilityIdentifier("verificationCode.orderState")
                    }
                }
                Text(model.target.kind == .ticket ? "verificationCode.ticket.authority" : "verificationCode.city.authority")
                    .cyText(.bodyCompact).foregroundStyle(.secondary)
            }
    }
    private func lifecycle<V: View>(_ view: V) -> some View {
        view.privacySensitive()
        .task(id: scenePhase) {
            guard scenePhase == .active else { cancel(); return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                await model.tick()
            }
        }
        .onChange(of: scenePhase) { _, value in if value != .active { cancel() } }
        .task {
            // Mirrors citynode-code onLoad -> issue(). Only from review: a paused or failed code waits for the player.
            guard autoIssue, model.target.kind == .cityVoucher, model.phase == .review else { return }
            run { await model.present() }
        }
        .onDisappear { operation?.cancel(); operation = nil; model.invalidate() }
        .accessibilityIdentifier("verificationCode.view")
    }
    @ViewBuilder private var content: some View {
        if model.phase == .ready, let code = model.displayCode {
            VerificationLocalQRCode(code: code, side: embeddedQRSide)
                .overlay { CYScanSweep(active: revealSweep, period: 1.4).allowsHitTesting(false) }
                .task(id: code) {
                    // One reveal pass over a freshly presented code, then the line rests.
                    revealSweep = true
                    try? await Task.sleep(for: .milliseconds(1400))
                    revealSweep = false
                }
            if model.target.kind == .cityVoucher, autoIssue {
                // Source citynode-code: 「Ns 后自动刷新」 right under the code, then 出示给商家扫码领券; the code refreshes itself.
                Text("roamSub.w208.voucher.countdown \(model.remainingSeconds)").monospacedDigit()
                    .cyText(.meta).foregroundStyle(.secondary)
                    .accessibilityIdentifier("roamSub.w208.voucher.countdown")
                Text("roamSub.w208.voucher.desc").cyText(.bodyCompact).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                CYPillButton("verificationCode.retry", style: .secondary) { run { await model.present() } }
                    .accessibilityIdentifier("verificationCode.refresh")
                LabeledContent("verificationCode.remaining") { Text(model.remainingSeconds, format: .number).monospacedDigit() }
            }
        } else if model.phase == .loading {
            CYSkeleton()
        } else {
            Text(LocalizedStringKey(phaseKey))
                .multilineTextAlignment(.center).accessibilityIdentifier("verificationCode.phase")
            if [.review, .expired, .paused, .failed, .invalid].contains(model.phase) {
                CYPillButton(model.phase == .review ? "verificationCode.show" : (model.target.kind == .cityVoucher && autoIssue ? "roamSub.w208.voucher.retry" : "verificationCode.retry")) { run { await model.present() } }
                    .accessibilityIdentifier("verificationCode.show")
            } else if model.phase == .login, rootTabSwitch.isAvailable {
                // RCODE-1: MP access gate — 登录 instead of a dead-end line.
                CYPillButton("verificationCode.signIn") { rootTabSwitch(.mine) }
                    .accessibilityIdentifier("verificationCode.signIn")
            }
        }
    }
    private var phaseKey: String {
        if model.target.kind == .cityVoucher, autoIssue, let key = RoamCityVoucherCopy.phaseKey(model.phase, network: model.failedOnNetwork) { return key }
        return "verificationCode.phase." + model.phase.rawValue
    }
    private func run(_ work: @escaping @MainActor () async -> Void) {
        operation?.cancel(); operation = Task { await work() }
    }
    private func cancel() { operation?.cancel(); operation = nil; model.pause() }
}

@MainActor private struct VerificationLocalQRCode: View {
    let code: String
    var side: CGFloat? = nil
    private var image: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(code.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let bitmap = CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: bitmap)
    }
    var body: some View {
        if let image {
            Image(uiImage: image).resizable().interpolation(.none).scaledToFit()
                .frame(width: side, height: side).frame(maxWidth: side == nil ? 280 : nil).padding(side == nil ? 24 : CYSpacing.lg).background(.white, in: RoundedRectangle(cornerRadius: side == nil ? 0 : CYRadius.lg, style: .continuous))
                .accessibilityLabel("verificationCode.image").accessibilityIdentifier("verificationCode.qr")
        } else { Text("verificationCode.renderFailed") }
    }
}
