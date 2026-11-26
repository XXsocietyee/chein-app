import SwiftUI

private struct TopicUnlikeControllerKey: EnvironmentKey { static let defaultValue: TopicUnlikeController? = nil }
extension EnvironmentValues {
    /// Present only when a reviewed approval exists; otherwise favorites stay read-only.
    var topicUnlikeController: TopicUnlikeController? {
        get { self[TopicUnlikeControllerKey.self] }
        set { self[TopicUnlikeControllerKey.self] = newValue }
    }
}

/// The heart on a liked-topic card (mini-program `mylike` topicUnlike).
struct TopicUnlikeButton: View {
    let topicID: Int
    let controller: TopicUnlikeController
    var body: some View {
        Button { controller.request(topicID: topicID) } label: {
            Image(systemName: "heart.fill")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(.red)
        .disabled(isBusy)
        .accessibilityLabel(Text("member.unlike.action", tableName: "MemberProfile"))
        .accessibilityIdentifier("member.unlike.\(topicID)")
    }
    private var isBusy: Bool {
        switch controller.phase {
        case .working, .checking: return true
        default: return false
        }
    }
}

/// Confirmation (提示 / 确定要取消点赞吗？) and the outcome line.
struct TopicUnlikeFlow: ViewModifier {
    let controller: TopicUnlikeController?
    let onRemoved: (Int) -> Void
    @State private var toastMessage: LocalizedStringKey?
    /// The confirm button was tapped: the dialog's dismissal must not cancel the pending unlike.
    @State private var confirmTapped = false
    @ViewBuilder func body(content: Content) -> some View {
        if let controller {
            content
                .confirmationDialog(
                    Text("member.unlike.confirmTitle", tableName: "MemberProfile"),
                    isPresented: Binding(
                        get: { if case .confirming = controller.phase { return true }; return false },
                        set: { presented in
                            guard !presented else { return }
                            if confirmTapped { confirmTapped = false } else { controller.cancel() }
                        }),
                    titleVisibility: .visible
                ) {
                    Button(role: .destructive) {
                        if case .confirming(_, let id) = controller.phase {
                            confirmTapped = true
                            Task { await controller.confirm(id) }
                        }
                    } label: { Text("member.unlike.confirm", tableName: "MemberProfile") }
                    Button(role: .cancel) {} label: { Text("member.unlike.cancel", tableName: "MemberProfile") }
                } message: {
                    Text("member.unlike.confirmMessage", tableName: "MemberProfile")
                }
                .safeAreaInset(edge: .bottom) { TopicUnlikeStatus(controller: controller) }
                .cyToast(message: $toastMessage, tone: .info)
                .onChange(of: controller.phase) { _, phase in
                    if case .confirming = phase { confirmTapped = false }
                    if case .removed(let id) = phase {
                        toastMessage = "topic.unlike.toast"
                        onRemoved(id)
                    }
                }
        } else {
            content
        }
    }
}

private struct TopicUnlikeStatus: View {
    let controller: TopicUnlikeController
    var body: some View {
        Group {
            switch controller.phase {
            case .working, .checking:
                HStack { ProgressView(); Text("member.unlike.working", tableName: "MemberProfile") }
            case .removed:
                Text("member.unlike.done", tableName: "MemberProfile").accessibilityIdentifier("member.unlike.done")
            case .failed(_, let message):
                Group {
                    if let message, !message.isEmpty { Text(verbatim: message) }
                    else { Text("member.unlike.failed", tableName: "MemberProfile") }
                }.accessibilityIdentifier("member.unlike.failed")
            case .unknown(let id):
                VStack(spacing: 6) {
                    Text("member.unlike.unknown", tableName: "MemberProfile")
                    Button { Task { await controller.checkUnresolved(topicID: id) } } label: {
                        Text("member.unlike.check", tableName: "MemberProfile")
                    }.accessibilityIdentifier("member.unlike.check")
                }.accessibilityIdentifier("member.unlike.unknown")
            case .idle, .confirming:
                EmptyView()
            }
        }
        .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(.bar)
    }
}
