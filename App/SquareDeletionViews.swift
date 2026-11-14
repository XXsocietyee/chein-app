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

    private var consequences: [CYConfirmConsequence] {
        switch target {
        case .post:
            return [
                CYConfirmConsequence(systemImage: "bubble.left.and.exclamationmark.bubble.right", text: appLocalized("square.delete.c1", locale: locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: appLocalized("square.delete.c2", locale: locale))
            ]
        case .comment:
            return [
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: appLocalized("square.delete.c2", locale: locale))
            ]
        }
    }

    var body: some View {
        CYConfirmSheet(
            title: titleText,
            message: messageText,
            confirmTitle: confirmText,
            cancelTitle: appLocalized("action.cancel", locale: locale),
            isDestructive: true,
            confirmDisabled: coordinator.isBusy,
            confirmIdentifier: "square.delete.confirm",
            consequences: consequences,
            onCancel: { coordinator.cancel() },
            onConfirm: { Task { await coordinator.confirm() } }
        )
        .accessibilityIdentifier("square.delete.sheet")
        .cyDomainSheet(detents: [.half, .full])
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
            if case .post = target { CYStatusChip("square.xcx.delete.postDone", tone: .success, systemImage: "checkmark.circle").accessibilityIdentifier("square.delete.done") }
            else { CYStatusChip("square.xcx.delete.commentDone", tone: .success, systemImage: "checkmark.circle").accessibilityIdentifier("square.delete.done") }
        case .rejected(_, let message):
            VStack(alignment: .leading, spacing: 4) {
                CYStatusChip("square.xcx.delete.failed", tone: .danger, systemImage: "exclamationmark.triangle").accessibilityIdentifier("square.delete.failed")
                if let message, !message.isEmpty { Text(verbatim: message).font(.caption) }
            }
        case .unknown:
            VStack(alignment: .leading, spacing: 6) {
                Text("square.xcx.delete.unknown").accessibilityIdentifier("square.delete.unknown")
                CYPillButton("square.xcx.delete.verify", style: .secondary, action: verify).accessibilityIdentifier("square.delete.verify")
            }
        case .disabled:
            Text("square.xcx.delete.unavailable").font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("square.delete.unavailable")
        default: EmptyView()
        }
    }
}
