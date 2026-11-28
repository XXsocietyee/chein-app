import SwiftUI

@MainActor
private final class WeChatAppAuthModel: ObservableObject {
    let coordinator: WeChatAppAuthCoordinator
    @Published var phase: WeChatAppAuthCoordinator.Phase
    @Published var issue: WeChatAppAuthError?
    init(_ coordinator: WeChatAppAuthCoordinator) {
        self.coordinator = coordinator; phase = coordinator.phase; issue = coordinator.issue
        coordinator.onChange = { [weak self] in
            guard let self else { return }
            self.phase = coordinator.phase; self.issue = coordinator.issue
        }
    }
}

/// Additive CN-only host control; existing password/phone/Apple affordances stay intact.
@MainActor
struct WeChatAppAuthSection: View {
    @StateObject private var model: WeChatAppAuthModel
    let context: AuthChannelSessionSnapshot
    init(coordinator: WeChatAppAuthCoordinator, context: AuthChannelSessionSnapshot) {
        _model = StateObject(wrappedValue: WeChatAppAuthModel(coordinator)); self.context = context
    }
    var body: some View {
        if model.coordinator.isOffered || model.coordinator.isWorking {
            section
        }
    }
    /// Sweep 04:50: the same full-width, 50 pt button as Sign in with Apple and phone sign-in; status in the footer.
    private var section: some View {
        Section {
            Button { model.coordinator.start() } label: {
                Label("auth.wechat.signIn", systemImage: "bubble.left.and.bubble.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!model.coordinator.canStart)
            .accessibilityIdentifier("auth.wechat.signIn")
            .accessibilityHint(Text("auth.wechat.hint"))
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            statusFooter
        }
        .onChange(of: context) { _, _ in model.coordinator.cancel() }
        .onDisappear { model.coordinator.cancel() }
    }
    @ViewBuilder private var statusFooter: some View {
        if model.coordinator.isWorking {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView("auth.wechat.working")
                Button("action.cancel") { model.coordinator.cancel() }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("auth.wechat.cancel")
            }
        } else if let issue = model.issue {
            Text(LocalizedStringKey(issue.localizationKey)).foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier("auth.wechat.error")
        }
    }
}
