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
    var body: some View {
        if embeddedQRSide != nil { lifecycle(stack) } else if model.target.kind == .cityVoucher, autoIssue {
            // RCODE-3: the node name is the system inline title (MP 据点核销码 nav title), not a heading in the content.
            lifecycle(ScrollView { stack.padding().frame(maxWidth: .infinity) }
                .cyPageTitle(verbatim: title ?? appLocalized("roamSub.w208.voucher.defaultName", locale: locale)))
        } else {
            // N-RCODE (r10): the page title is the system inline title (MP subpackageRoam/citynode-code nav title).
            lifecycle(ScrollView { stack.padding().frame(maxWidth: .infinity) }
                .cyPageTitle(String.LocalizationValue(stringLiteral: model.target.kind == .ticket ? "verificationCode.ticket.title" : "verificationCode.city.title")))
        }
    }
    private var stack: some View {
            VStack(spacing: 20) {
                // RCODE-3 / N-RCODE (r10): every variant is titled by the navigation bar; no in-content hero header.
                content
                if model.target.kind == .ticket, model.readback != nil {
                    // N-RCODE (r10): system buttons (MP subpackageRoam/citynode-code uses plain wx buttons).
                    Button("verificationCode.checkOrder") { run { await model.checkOrder() } }
                        .buttonStyle(.bordered)
                        .disabled(model.checkingOrder || model.phase == .loading)
                        .accessibilityIdentifier("verificationCode.checkOrder")
                    if model.checkingOrder { ProgressView() }
                    if model.readbackFailed { Text("verificationCode.readbackFailed").cyText(.bodyCompact) }
                    if let detail = model.readback {
                        Label(detail.registrationStatus == 2 ? "verificationCode.order.active" : "verificationCode.order.ended",
                              systemImage: detail.registrationStatus == 2 ? "checkmark.circle" : "clock")
                            .foregroundStyle(detail.registrationStatus == 2 ? Color.green : Color.secondary)
                            .accessibilityIdentifier("verificationCode.orderState")
                    }
                }
                // MP scene-qr-citynode shows only the code, the countdown and 出示给商家扫码领券; no authority line there.
                if !(model.target.kind == .cityVoucher && autoIssue) {
                    Text(model.target.kind == .ticket ? "verificationCode.ticket.authority" : "verificationCode.city.authority")
                        .cyText(.bodyCompact).foregroundStyle(.secondary)
                }
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
            VerificationLocalQRCode(code: code, side: embeddedQRSide,
                                    renderFailedKey: model.target.kind == .cityVoucher && autoIssue ? "roamSub.w208.voucher.renderFailed" : "verificationCode.renderFailed")
            if model.target.kind == .cityVoucher, autoIssue {
                // Source citynode-code: 「Ns 后自动刷新」 right under the code, then 出示给商家扫码领券; the code refreshes itself.
                Text("roamSub.w208.voucher.countdown \(model.remainingSeconds)").monospacedDigit()
                    .cyText(.meta).foregroundStyle(.secondary)
                    .accessibilityIdentifier("roamSub.w208.voucher.countdown")
                Text("roamSub.w208.voucher.desc").cyText(.bodyCompact).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                Button("verificationCode.retry") { run { await model.present() } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("verificationCode.refresh")
                LabeledContent("verificationCode.remaining") { Text(model.remainingSeconds, format: .number).monospacedDigit() }
            }
        } else if model.phase == .loading {
            // mp-states r3: P10 — the loader says what it is doing (正在获取实时码…), not a bare spinner.
            ProgressView { Text(LocalizedStringKey(phaseKey)) }
        } else if model.phase == .failed, model.target.kind == .ticket {
            // mp-states r3 (MP pages/play/components/scene-qr-ticket/index.wxml:3): cy-error 入场码没生成出来 · sub · 重试.
            ContentUnavailableView {
                Label("verificationCode.ticket.failedTitle", systemImage: "qrcode")
            } description: {
                Text(LocalizedStringKey(phaseKey)).accessibilityIdentifier("verificationCode.phase")
            } actions: {
                Button("action.retry") { run { await model.present() } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("verificationCode.show")
            }
        } else {
            Text(LocalizedStringKey(phaseKey))
                .multilineTextAlignment(.center).accessibilityIdentifier("verificationCode.phase")
            if [.review, .expired, .paused, .failed, .invalid].contains(model.phase) {
                Button(LocalizedStringKey(model.phase == .review ? "verificationCode.show" : (model.target.kind == .cityVoucher && autoIssue ? "roamSub.w208.voucher.retry" : "verificationCode.retry"))) { run { await model.present() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("verificationCode.show")
            } else if model.phase == .login, rootTabSwitch.isAvailable {
                // RCODE-1: MP access gate — 登录 instead of a dead-end line.
                Button("verificationCode.signIn") { rootTabSwitch(.mine) }
                    .buttonStyle(.borderedProminent)
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
    var renderFailedKey: LocalizedStringKey = "verificationCode.renderFailed"
    private var image: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        // "H": the MP cy-qr-voucher centre logo covers the middle of the code; level H keeps it readable.
        filter.message = Data(code.utf8); filter.correctionLevel = "H"
        guard let output = filter.outputImage,
              let bitmap = CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: bitmap)
    }
    var body: some View {
        if let image {
            Image(uiImage: image).resizable().interpolation(.none).scaledToFit()
                .overlay { VerificationQRCentreLogo() }
                .frame(width: side, height: side).frame(maxWidth: side == nil ? 280 : nil).padding(side == nil ? 24 : CYSpacing.lg).background(.white, in: RoundedRectangle(cornerRadius: side == nil ? 0 : CYRadius.lg, style: .continuous))
                .accessibilityLabel("verificationCode.image").accessibilityIdentifier("verificationCode.qr")
        } else { Text(renderFailedKey) }
    }
}

/// MP `cy-qr-voucher` `.qr__logo`: white round cut-out (96/440 of the code) holding the 城瘾 mark drawn black
/// (`filter: brightness(0)`, 56/440). Decoration: VoiceOver reads the code image label only.
@MainActor private struct VerificationQRCentreLogo: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(Color.white)
                    .frame(width: side * 96 / 440, height: side * 96 / 440)
                MPAsset.BrandLogo.cyLogoMark
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Color.black)
                    .frame(width: side * 56 / 440, height: side * 56 / 440)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
