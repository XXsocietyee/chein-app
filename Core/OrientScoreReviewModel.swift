import Foundation

// MARK: - Orient score appeal / dispute form (confirm-then-submit, injected submitter)
// Validation (trimmed, 1...500 UTF-16 units) is the same rule the coordinator enforces. The submitter is
// the only write path: in production it wraps `OrientSessionCoordinator.appeal/dispute(confirmed: true,
// reason:key:)`. With no submitter the form says "Not available yet". The idempotency key is created when
// the player reaches the confirm step and is reused for every retry until the server accepts, so a retry
// can never become a second appeal.

@MainActor public final class OrientScoreReviewModel: ObservableObject {
    public enum Kind: Equatable { case appeal, dispute }

    public enum State: Equatable {
        case idle
        case awaitingConfirmation(kind: Kind, reason: String)
        case submitting
        case submitted(Kind)
        case failed(String)
        case unavailable
    }

    public typealias Submitter = (_ kind: Kind, _ reason: String, _ key: String) async throws -> Void

    @Published public private(set) var state: State = .idle
    private let submitter: Submitter?
    private let makeKey: () -> String
    private var retainedKey: String?

    public init(submitter: Submitter?, makeKey: @escaping () -> String) {
        self.submitter = submitter
        self.makeKey = makeKey
    }

    /// Validates the text and moves to the confirm step. Nothing is sent here.
    public func review(kind: Kind, reason raw: String) {
        if case .submitting = state { return }
        guard submitter != nil else { state = .unavailable; return }
        guard let reason = try? OrientSessionScoreReason.normalized(raw) else {
            state = .failed(W8Text.t("请填写 1 到 500 字的理由", "Enter a reason of 1 to 500 characters"))
            return
        }
        if retainedKey == nil { retainedKey = makeKey() }
        state = .awaitingConfirmation(kind: kind, reason: reason)
    }

    public func confirm() async {
        guard case .awaitingConfirmation(let kind, let reason) = state, let submitter, let key = retainedKey else { return }
        state = .submitting
        do {
            try await submitter(kind, reason, key)
            retainedKey = nil
            state = .submitted(kind)
        } catch {
            // Key kept: the next confirm replays the same request.
            state = .failed(error.localizedDescription)
        }
    }

    public func cancel() {
        if case .submitting = state { return }
        state = .idle
    }
}
