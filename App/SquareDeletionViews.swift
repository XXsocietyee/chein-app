import SwiftUI

private struct SquareDeletionKey: EnvironmentKey { static let defaultValue: SquareDeletionCoordinator? = nil }
extension EnvironmentValues {
    /// Nil (the default) keeps delete visible but disabled; no host supplies an approved coordinator yet.
    var squareDeletion: SquareDeletionCoordinator? {
        get { self[SquareDeletionKey.self] }
        set { self[SquareDeletionKey.self] = newValue }
    }
}

/// Source danger-confirm sheets `club.post.delete` / `club.comment.delete`.
struct SquareDeletionConfirmView: View {
    let target: SquareDeletionTarget
    let excerpt: String?
    let coordinator: SquareDeletionCoordinator
    @Environment(\.locale) private var locale

    private var titleText: String {
        switch target {
        case .post:
            if let excerpt {
                return appLocalized("square.xcx.delete.postTitle \(excerpt)", locale: locale)
            }
            return appLocalized("square.xcx.delete.postTitleImageOnly", locale: locale)
        case .comment:
            return appLocalized("square.xcx.delete.commentTitle", locale: locale)
        }
    }

    private var messageText: String {
        switch target {
        case .post:
            return appLocalized("square.xcx.delete.postCascade", locale: locale)
        case .comment:
            return appLocalized("square.xcx.delete.commentIrreversible", locale: locale)
        }
    }

    private var confirmText: String {
        switch target {
        case .post:
            return appLocalized("square.xcx.delete.postConfirm", locale: locale)
        case .comment:
            return appLocalized("square.xcx.delete.commentConfirm", locale: locale)
        }
    }

    private var consequences: [(systemImage: String, text: String)] {
        switch target {
        case .post:
            return [
                (systemImage: "bubble.left.and.exclamationmark.bubble.right", text: appLocalized("square.delete.c1", locale: locale)),
                (systemImage: "exclamationmark.triangle", text: appLocalized("square.delete.c2", locale: locale))
            ]
        case .comment:
            return [
                (systemImage: "exclamationmark.triangle", text: appLocalized("square.delete.c2", locale: locale))
            ]
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Array(consequences.enumerated()), id: \.offset) { _, item in
                        Label { Text(verbatim: item.text) } icon: { Image(systemName: item.systemImage).foregroundStyle(.red) }
                    }
                } header: {
                    Text(verbatim: titleText)
                } footer: {
                    Text(verbatim: messageText)
                }
                Section {
                    Button(role: .destructive) { Task { await coordinator.confirm() } } label: {
                        HStack {
                            Text(verbatim: confirmText)
                            if coordinator.isBusy {
                                Spacer(minLength: 0)
                                ProgressView()
                            }
                        }
                    }
                    .disabled(coordinator.isBusy)
                    .accessibilityIdentifier("square.delete.confirm")
                }
            }
            .navigationTitle(Text(verbatim: confirmText))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { coordinator.cancel() } label: { Text(verbatim: appLocalized("action.cancel", locale: locale)) }
                }
            }
        }
        .accessibilityIdentifier("square.delete.sheet")
        .presentationDetents([.medium, .large])
        .cyDomainScreen(.player)
    }
    /// Source excerpt: first 12 characters plus "…", or nil for an image-only post.
    static func excerpt(_ contents: String?) -> String? {
        let text = (contents ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return text.count > 12 ? String(text.prefix(12)) + "…" : text
    }
}

/// Inline status for terminal and unknown deletion results.
struct SquareDeletionStatusView: View {
    let coordinator: SquareDeletionCoordinator
    let verify: () -> Void
    var body: some View {
        switch coordinator.phase {
        case .done(let target):
            if case .post = target {
                Label { Text("square.xcx.delete.postDone") } icon: { Image(systemName: "checkmark.circle").foregroundStyle(.green) }
                    .accessibilityIdentifier("square.delete.done")
            } else {
                Label { Text("square.xcx.delete.commentDone") } icon: { Image(systemName: "checkmark.circle").foregroundStyle(.green) }
                    .accessibilityIdentifier("square.delete.done")
            }
        case .rejected(_, let message):
            VStack(alignment: .leading, spacing: 4) {
                Label { Text("square.xcx.delete.failed") } icon: { Image(systemName: "exclamationmark.triangle").foregroundStyle(.red) }
                    .accessibilityIdentifier("square.delete.failed")
                if let message, !message.isEmpty { Text(verbatim: message).font(.caption).foregroundStyle(.secondary) }
            }
        case .unknown:
            VStack(alignment: .leading, spacing: 6) {
                Text("square.xcx.delete.unknown").accessibilityIdentifier("square.delete.unknown")
                Button("square.xcx.delete.verify", action: verify)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("square.delete.verify")
            }
        case .disabled:
            Text("square.xcx.delete.unavailable").font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("square.delete.unavailable")
        default: EmptyView()
        }
    }
}
