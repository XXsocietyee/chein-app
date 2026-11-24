import SwiftUI

/// flows-g2 (round 3): MP deep links into the decor sub-pages (`pages/merchant/decor/{gallery,coop-setting,ai-npc}`).
/// The MP page reads the merchant access in `onLoad`; here the same `MerchantOperationsReading.access()` decides
/// whether the page opens (`MerchantOperationsAccess.allows`), with the decor hub's states otherwise:
/// signed out → 登录, inactive → 去商家入驻, no grant → 当前身份不能装修店铺, failure → 品牌中心加载失败 + 重试.
/// The page itself is the session's existing destination (`AppSession.merchantOperationsDestination`).
@MainActor struct MerchantDecorLinkedPage: View {
    let reader: any MerchantOperationsReading
    let destination: MerchantOperationsDestination
    let open: (MerchantOperationsDestination, MerchantOperationsAccess) -> AnyView
    private enum Phase { case loading, signedOut, ready(MerchantOperationsAccess), inactive, denied, failed }
    @State private var phase: Phase = .loading
    @State private var attempt = 0

    var body: some View {
        content
            .task(id: "\(reader.scope)|\(attempt)") { await load() }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            CYSkeleton(variant: .formSection).padding(CYSpacing.pageHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("merchantCoop.decorLink.loading")
        case .signedOut:
            MerchantCoopSignInState(title: "merchant.gate.signIn", identifier: "merchantCoop.decorLink.signIn")
        case .inactive:
            MerchantCoopApplyState(title: "merchant.decor.state.empty.title", message: "merchant.decor.state.empty.message",
                                   actionTitle: "merchantCoop.decor.openApplication", identifier: "merchantCoop.decorLink.inactive")
        case .denied:
            MerchantCoopActionState(systemImage: "lock", title: "merchantCoop.decor.denied.title", identifier: "merchantCoop.decorLink.denied")
        case .failed:
            MerchantCoopActionState(systemImage: "exclamationmark.triangle", title: "merchantCoop.decor.failed.title",
                                    actionTitle: "action.retry", action: { attempt += 1 }, identifier: "merchantCoop.decorLink.failed")
        case .ready(let access):
            open(destination, access)
        }
    }

    private func load() async {
        let scope = reader.scope
        guard reader.isAuthenticated else { phase = .signedOut; return }
        if case .ready = phase {} else { phase = .loading }
        do {
            guard reader.isConfigured else { throw APIError.notConfigured }
            let access = try await reader.access()
            guard !Task.isCancelled, scope == reader.scope else { return }
            if !access.identity.active { phase = .inactive }
            else if access.allows(destination) { phase = .ready(access) }
            else { phase = .denied }
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), scope == reader.scope else { return }
            phase = error as? APIError == .unauthorized ? .signedOut : .failed
        }
    }
}
