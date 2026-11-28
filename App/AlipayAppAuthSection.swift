import SwiftUI

@MainActor
private final class AlipayAppAuthModel: ObservableObject {
    let coordinator: AlipayAppAuthCoordinator
    @Published var phase: AlipayAppAuthCoordinator.Phase
    @Published var issue: AlipayAppAuthError?
    init(_ coordinator: AlipayAppAuthCoordinator) {
        self.coordinator = coordinator; phase = coordinator.phase; issue = coordinator.issue
        coordinator.onChange = { [weak self] in
            guard let self else { return }
            self.phase = coordinator.phase; self.issue = coordinator.issue
        }
    }
}

/// Owner 11-28 04:30: Alipay sign-in (CN), in the third-party row after WeChat. Gated off until the SDK driver,
/// provider and exchange are verified: while `isOffered` is false the section renders nothing (P27).
@MainActor
struct AlipayAppAuthSection: View {
    @StateObject private var model: AlipayAppAuthModel
    let context: AuthChannelSessionSnapshot
    init(coordinator: AlipayAppAuthCoordinator, context: AuthChannelSessionSnapshot) {
        _model = StateObject(wrappedValue: AlipayAppAuthModel(coordinator)); self.context = context
    }
    var body: some View {
        if model.coordinator.isOffered || model.coordinator.isWorking {
            section
        }
    }
    private var section: some View {
        Section {
            Button { model.coordinator.start() } label: {
                Label("auth.alipay.signIn", systemImage: "a.circle")
                    .frame(minHeight: 44)
            }
            .disabled(!model.coordinator.canStart)
            .accessibilityIdentifier("auth.alipay.signIn")
            if model.coordinator.isWorking {
                ProgressView("auth.alipay.working")
                Button("action.cancel") { model.coordinator.cancel() }
                    .accessibilityIdentifier("auth.alipay.cancel")
            }
            if let issue = model.issue {
                Text(LocalizedStringKey(issue.localizationKey)).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("auth.alipay.error")
            }
        }
        .onChange(of: context) { _, _ in model.coordinator.cancel() }
        .onDisappear { model.coordinator.cancel() }
    }
}

extension AppSession {
    /// The gated Alipay channel. No SDK driver or exchange service is wired in this build (no Alipay SDK binary yet),
    /// so `isOffered` is false and the login row renders nothing. Wiring = pass `AlipayAuthAdapter(driver:configuration:)`
    /// and `AlipayAppAuthService` once the owner's Alipay Open Platform app exists.
    func makeAlipayAuthCoordinator() -> AlipayAppAuthCoordinator {
        AlipayAppAuthCoordinator(context: { [weak self] in
            self?.weChatContext ?? WeChatAppAuthContext(session: .init(epoch: 0, accountID: nil, isBusy: true), market: nil, namespace: nil)
        }, commit: { [weak self] result, expected in
            guard let self, self.weChatContext == expected, expected.permitsLogin else { return false }
            return try self.commitChannelLogin(result, expected: expected.session)
        })
    }
}
