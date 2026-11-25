import SwiftUI
import Observation
import CoreImage.CIFilterBuiltins
import UIKit

private struct CouponCodeFactoryKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Int) -> CouponCodeCoordinator)? = nil
}
extension EnvironmentValues {
    var couponCodeFactory: (@MainActor (Int) -> CouponCodeCoordinator)? {
        get { self[CouponCodeFactoryKey.self] }
        set { self[CouponCodeFactoryKey.self] = newValue }
    }
}

@MainActor struct CouponCodeView: View {
    @State var model: CouponCodeCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var review = false
    @State private var viewPresentation = CouponCodeViewPresentation()
    private struct TaskKey: Hashable { let active: Bool; let presentationID: UUID? }
    var body: some View {
        let appearance = viewPresentation
        let presentation = appearance.permit
        return ScrollView {
            VStack(spacing: 20) {
                if model.ownerIsCurrent {
                    // Source coupon-qr head card: coupon name over its usage note.
                    if model.couponName != nil || model.couponDescription != nil {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            if let name = model.couponName { Text(verbatim: name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                            if let description = model.couponDescription { Text(verbatim: description).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.lg)
                        .accessibilityElement(children: .combine)
                    }
                    // Source parity: validity is shown on the expired result only.
                    if model.phase == .expired, let end = AccountCollectionCoupon.calendarDay(model.endTime) {
                        LabeledContent("accountCollection.coupon.validUntil") { Text(verbatim: end) }
                    }
                }
                if model.historyID <= 0 {
                    // MP coupon-qr missing-param (index.wxml:31-39): 链接已失效 · 返回.
                    MemberMissingLinkState(identifier: "couponCode.missing")
                } else { content(presentation: presentation, appearance: appearance) }
                if model.pollDelayed { Text("couponCode.pollDelayed").cyText(.meta) }
                Text("couponCode.authority").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }.padding().frame(maxWidth: .infinity)
        }.cyPageTitle("couponCode.title")
            .cyDomainPageBackground()
            .privacySensitive().accessibilityIdentifier("couponCode.view")
            // MKT-9-4: MP coupon-qr vibrates once when the merchant scan lands (index.js:413-418).
            .cyHaptic(.success, trigger: model.phase == .used, where: { old, new in !old && new })
            .sheet(isPresented: $review) {
                MemberCouponShowConfirmSheet {
                    review = false
                    guard let offer = model.offerConfirmation(presentation: presentation) else { return }
                    appearance.actionTask?.cancel()
                    appearance.actionTask = Task { await model.confirmPresentation(permit: offer) }
                }
            }
            .onAppear {
                guard let permit = appearance.begin(model: model) else { return }
                if scenePhase == .active { resume(presentation: permit, appearance: appearance) } else { model.pause(presentation: permit) }
            }
            .task(id: TaskKey(active: scenePhase == .active, presentationID: presentation?.id)) {
                guard let presentation else { return }
                guard scenePhase == .active else { model.pause(presentation: presentation); return }
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    await model.tick(presentation: presentation)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard let presentation, model.presentation === presentation else { return }
                if phase == .active { resume(presentation: presentation, appearance: appearance) }
                else { review = false; appearance.actionTask?.cancel(); appearance.foregroundTask?.cancel(); model.pause(presentation: presentation) }
            }
            .onDisappear {
                if appearance.end(model: model) { review = false }
                if viewPresentation === appearance { viewPresentation = CouponCodeViewPresentation() }
            }
    }
    private func resume(presentation: CouponCodePresentationPermit?, appearance: CouponCodeViewPresentation) {
        guard let offer = model.offerResume(presentation: presentation) else { return }
        appearance.foregroundTask?.cancel()
        appearance.foregroundTask = Task { await model.resume(permit: offer) }
    }
    @ViewBuilder private func content(presentation: CouponCodePresentationPermit?, appearance: CouponCodeViewPresentation) -> some View {
        switch model.phase {
        case .review:
            Text("couponCode.review.detail")
            Button("couponCode.show") {
                guard !appearance.isClosed, let presentation, model.presentation === presentation else { return }
                review = true
            }.buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule).accessibilityIdentifier("couponCode.review")
        case .ready:
            if model.canDisplay {
                if let token = model.displayToken { CouponLocalQRImage(token: token) }
                else if let bytes = model.imageBytes, let image = UIImage(data: bytes) {
                    Image(uiImage: image).resizable().interpolation(.none).scaledToFit().frame(width: 240, height: 240)
                        .overlay { CouponQRLogoMark() }
                        .padding(24).background(.white).accessibilityLabel("couponCode.image")
                } else { CouponQRRenderFailed() }
                // Source: 二维码 Ns 后自动刷新 under the code. Page model countdown: hidden or unknown is an em dash, a displayed 0 stays 0.
                Group {
                    if model.remainingText == "—" {
                        LabeledContent("couponCode.remaining") { Text(verbatim: model.remainingText) }
                    } else {
                        Text("u9cde.coupon.autoRefresh \(model.remainingText)").monospacedDigit()
                            .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                            .animation(reduceMotion ? nil : CYMotion.standard, value: model.remainingText)
                    }
                }
                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("couponCode.remaining")
                Text("couponCode.presentToMerchant").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                retryButton("couponCode.refresh", identifier: "couponCode.refresh", presentation: presentation, appearance: appearance)
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
        case .loading: CYLoadingState("couponCode.loading", messageIdentifier: "couponCode.loading")
        case .waiting:
            Label("couponCode.waiting", systemImage: "clock")
            if let start = AccountCollectionCoupon.calendarDay(model.receipt?.startTime) {
                // MP sub line: `{start} 起可用`.
                Text("couponWallet.validFrom \(start)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("couponCode.waiting.start")
            }
            retryButton("couponCode.fetchAgain", identifier: "couponCode.fetchAgain", presentation: presentation, appearance: appearance)
        case .paused: Label("couponCode.paused", systemImage: "pause.circle")
        case .notMine:
            // MP: 无权查看该券 — the coupon is not in this account's wallet; no retry.
            // coupon-qr/index.wxml:28 `cy-empty … cta="返回" bind:cta="onClose"`.
            CYStateLayout(kind: .empty, title: Text("couponCode.notMine"),
                          primary: (title: "couponCode.notMine.back", action: { dismiss() }),
                          primaryIdentifier: "couponCode.notMine.back")
                .accessibilityIdentifier("couponCode.notMine")
        case .failed:
            // Source: 二维码暂时没能生成，请稍后重试 with one 重试 pill.
            CYEmptyState(systemImage: "exclamationmark.triangle", "u9cde.coupon.failed",
                         messageIdentifier: "couponCode.failed",
                         actionTitle: "action.retry",
                         actionIdentifier: "couponCode.retry",
                         kind: .failure) {
                guard let offer = model.offerRetry(presentation: presentation) else { return }
                appearance.actionTask?.cancel()
                appearance.actionTask = Task { await model.retry(permit: offer) }
            }
        case .used:
            // Source used state: a large success disc, 已核销, then the redemption time.
            VStack(spacing: CYSpacing.md) {
                Image(systemName: "checkmark.circle")
                    .cyText(.pageTitle, weight: .semibold)
                    .foregroundStyle(CYColor.successText)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(CYColor.successSoft))
                    .accessibilityHidden(true)
                Text("u9cde.coupon.used").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                if let time = model.useTime { Text(verbatim: time).cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary) }
            }
            .padding(.top, CYSpacing.xxl)
            .accessibilityElement(children: .combine)
        case .expired: Label("couponCode.expired", systemImage: "clock.badge.xmark")
        case .invalid: Label("couponCode.invalid", systemImage: "xmark.seal")
        case .unavailable: Label("couponCode.unavailable", systemImage: "nosign")
        case .disabled: Text("couponCode.disabled")
        case .serviceDisabled:
            ContentUnavailableView("couponCode.serviceDisabled", systemImage: "qrcode", description: Text("couponCode.serviceDisabled.detail"))
                .accessibilityIdentifier("couponCode.serviceDisabled")
            retryButton("action.retry", identifier: "couponCode.serviceDisabled.retry", presentation: presentation, appearance: appearance)
        case .login: Text("couponCode.login")
        case .stale: Text("couponCode.stale")
        }
    }
}
extension CouponCodeView {
    /// Manual re-issue (source retryNow). Captures the offer before creating its task.
    @ViewBuilder func retryButton(_ title: LocalizedStringKey, identifier: String, presentation: CouponCodePresentationPermit?,
                                  appearance: CouponCodeViewPresentation) -> some View {
        Button(title) {
            guard let offer = model.offerRetry(presentation: presentation) else { return }
            appearance.actionTask?.cancel()
            appearance.actionTask = Task { await model.retry(permit: offer) }
        }.accessibilityIdentifier(identifier)
    }
}
/// Tasks belong to this single appearance. Old disappearance callbacks can cancel only
/// their own tasks, and cannot borrow the coordinator's newly installed presentation.
@MainActor @Observable final class CouponCodeViewPresentation {
    private(set) var permit: CouponCodePresentationPermit?
    private(set) var isClosed = false
    var actionTask: Task<Void, Never>?
    var foregroundTask: Task<Void, Never>?
    func begin(model: CouponCodeCoordinator) -> CouponCodePresentationPermit? {
        guard !isClosed else { return nil }
        if let permit { return model.presentation === permit ? permit : nil }
        permit = model.beginPresentation(); return permit
    }
    @discardableResult func end(model: CouponCodeCoordinator) -> Bool {
        guard !isClosed else { return false }
        isClosed = true
        actionTask?.cancel(); actionTask = nil; foregroundTask?.cancel(); foregroundTask = nil
        return model.endPresentation(presentation: permit)
    }
}

/// Core Image encodes only the exact ephemeral token supplied by a validated issue receipt.
/// Never encode the qrcodeUrl as a new credential, invent an entitlement, or persist pixels.
@MainActor private struct CouponLocalQRImage: View {
    let token: String
    private var image: UIImage? {
        // "H": the MP voucher covers the centre with the brand mark, so keep the highest error correction.
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(token.utf8); filter.correctionLevel = "H"
        guard let output = filter.outputImage,
              let cg = CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
    var body: some View {
        if let image {
            Image(uiImage: image).resizable().interpolation(.none).scaledToFit().frame(width: 240, height: 240)
                .overlay { CouponQRLogoMark() }
                .padding(24).background(.white).accessibilityLabel("couponCode.image").accessibilityIdentifier("couponCode.qr")
        } else { CouponQRRenderFailed() }
    }
}

/// MP `cy-qr-voucher` centre mark (`qr__logo`, 96 rpx white disc, 56 rpx `/images/cy_logo_mark.png` with
/// `filter: brightness(0)`): the same catalog image as a black template, so it keeps its alpha outline.
private struct CouponQRLogoMark: View {
    var body: some View {
        MPAsset.BrandLogo.cyLogoMark
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(Color.black)
            .accessibilityHidden(true)
            .frame(width: 28, height: 28)
            .frame(width: 48, height: 48)
            .background(Circle().fill(Color.white))
    }
}

/// MP `qr__error`: `/images/no_data.svg` above 二维码未加载.
private struct CouponQRRenderFailed: View {
    var body: some View {
        VStack(spacing: CYSpacing.sm) {
            MPAsset.EmptyState.noData
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
                .frame(width: 64, height: 64)
            Text("couponCode.renderFailed").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
