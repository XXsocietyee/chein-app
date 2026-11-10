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
    @State var model: VerificationCodeCoordinator
    /// City voucher only: the node name shown as the title (mini-program `citynode-code`, default 据点).
    var title: String? = nil
    /// City voucher opened from a known node requests its code on appear. The approval gate is unchanged.
    var autoIssue = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var operation: Task<Void, Never>?
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if model.target.kind == .cityVoucher, autoIssue {
                    RoamCityVoucherHeading(title: title)
                } else {
                    CYHeroHeader(model.target.kind == .ticket ? "verificationCode.ticket.title" : "verificationCode.city.title")
                }
                content
                if model.target.kind == .ticket, model.readback != nil {
                    CYPillButton("verificationCode.checkOrder", style: .secondary) { run { await model.checkOrder() } }
                        .disabled(model.checkingOrder || model.phase == .loading)
                        .accessibilityIdentifier("verificationCode.checkOrder")
                    if model.checkingOrder { CYSkeleton() }
                    if model.readbackFailed { Text("verificationCode.readbackFailed").font(.footnote) }
                    if let detail = model.readback {
                        CYStatusChip(detail.registrationStatus == 2 ? "verificationCode.order.active" : "verificationCode.order.ended",
                                     tone: detail.registrationStatus == 2 ? .success : .neutral,
                                     systemImage: detail.registrationStatus == 2 ? "checkmark.circle" : "clock")
                            .accessibilityIdentifier("verificationCode.orderState")
                    }
                }
                Text(model.target.kind == .ticket ? "verificationCode.ticket.authority" : "verificationCode.city.authority")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding().frame(maxWidth: .infinity)
        }
        .cyHeroScreen().privacySensitive()
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
            VerificationLocalQRCode(code: code).cyCodeReveal()
            CYPillButton("verificationCode.retry", style: .secondary) { run { await model.present() } }
                .accessibilityIdentifier("verificationCode.refresh")
            if model.target.kind == .cityVoucher, autoIssue {
                Text("roamSub.w208.voucher.countdown \(model.remainingSeconds)").monospacedDigit()
                    .accessibilityIdentifier("roamSub.w208.voucher.countdown")
            } else {
                LabeledContent("verificationCode.remaining") { Text(model.remainingSeconds, format: .number).monospacedDigit() }
            }
        } else if model.phase == .loading {
            CYSkeleton()
        } else {
            Text(LocalizedStringKey(phaseKey))
                .multilineTextAlignment(.center).accessibilityIdentifier("verificationCode.phase")
            if [.review, .expired, .paused, .failed, .invalid].contains(model.phase) {
                CYPillButton(model.phase == .review ? "verificationCode.show" : "verificationCode.retry") { run { await model.present() } }
                    .accessibilityIdentifier("verificationCode.show")
            }
        }
    }
    private var phaseKey: String {
        if model.target.kind == .cityVoucher, autoIssue, let key = RoamCityVoucherCopy.phaseKey(model.phase) { return key }
        return "verificationCode.phase." + model.phase.rawValue
    }
    private func run(_ work: @escaping @MainActor () async -> Void) {
        operation?.cancel(); operation = Task { await work() }
    }
    private func cancel() { operation?.cancel(); operation = nil; model.pause() }
}

@MainActor private struct VerificationLocalQRCode: View {
    let code: String
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
                .frame(maxWidth: 280).padding(24).background(.white)
                .accessibilityLabel("verificationCode.image").accessibilityIdentifier("verificationCode.qr")
        } else { Text("verificationCode.renderFailed") }
    }
}
