import Foundation

// MARK: - Appeal model (IWP-7). Server is the authority; nothing here decides, refunds or consumes a unit.

/// Display mapping for a server appeal. `showsUnitAsRedeemed` is always false: only the server's unit status
/// (from a re-read of the order) may ever show a unit as redeemed. First backend slice never applies APPROVE.
public struct BundleAppealPresentation: Equatable {
    public enum Headline: Equatable { case submittedForReview, approvedNotYetApplied, notApproved, withdrawn, unknown }
    public let headline: Headline
    public let showsUnitAsRedeemed: Bool
    public let title: String
    public let detail: String?

    public init(_ appeal: BundleAppeal) {
        showsUnitAsRedeemed = false
        detail = appeal.decisionReason
        switch appeal.status {
        case "OPEN":
            headline = .submittedForReview
            title = W8Text.t("已提交，等待审核", "Submitted for review")
        case "APPROVED":
            headline = .approvedNotYetApplied
            title = W8Text.t("审核已通过，处理结果以服务器状态为准", "Review approved. The result will appear once the server applies it.")
        case "REJECTED":
            headline = .notApproved
            title = W8Text.t("审核未通过", "Not approved")
        case "WITHDRAWN":
            headline = .withdrawn
            title = W8Text.t("已撤回", "Withdrawn")
        default:
            headline = .unknown
            title = W8Text.t("已提交，状态更新中", "Submitted. Status is being updated.")
        }
    }
}

public enum BundleAppealState: Equatable {
    case idle
    case submitting
    case submitted(BundleAppeal)
    /// Request may have reached the server. The original command stays persisted; read back with the same key.
    case awaitingReadback
    /// Read-back said NOT_FOUND: still not proof of no write; only an explicit retry re-sends the SAME command.
    case readbackNotFound
    /// Definite server refusal (e.g. an appeal is already open for the unit). `serverCode` is shown as returned.
    case blocked(serverCode: String?)
    case loginRequired
    case storageFailed
    case unavailable
    case failed
}

@MainActor public final class BundleAppealModel: ObservableObject {
    @Published public private(set) var state: BundleAppealState = .idle
    @Published public private(set) var appeals: [BundleAppeal] = []
    private let service: any BundleAppealServing
    private let store: BundleAppealPendingStore
    private let makeKey: () -> String

    public init(service: any BundleAppealServing, store: BundleAppealPendingStore,
                makeKey: @escaping () -> String = { "appeal-" + UUID().uuidString.lowercased() }) {
        self.service = service; self.store = store; self.makeKey = makeKey
    }

    /// An unresolved persisted command (e.g. after relaunch) puts the model straight into read-back.
    public func restore() {
        guard state == .idle else { return }
        do { if try store.load() != nil { state = .awaitingReadback } } catch { state = .storageFailed }
    }

    public func submit(registrationID: FreeExploreLaunchID, unitID: FreeExploreLaunchID, reason: BundleAppealReason,
                       note: String, evidenceRefs: [String]) async {
        switch state {
        case .submitting, .awaitingReadback, .readbackNotFound: return
        default: break
        }
        let command: BundleAppealCommand
        do {
            command = try BundleAppealCommand(registrationId: registrationID, unitId: unitID, reasonCode: reason,
                                              note: note, evidenceRefs: evidenceRefs, idempotencyKey: makeKey())
        } catch { state = .failed; return }
        // Persist BEFORE any dispatch. If it cannot be stored, nothing is sent.
        do { try store.save(command) } catch { state = .storageFailed; return }
        await dispatch(command)
    }

    /// Reads back by the persisted command's SAME idempotency key. Never re-sends.
    public func recover() async {
        guard state == .awaitingReadback || state == .readbackNotFound else { return }
        let command: BundleAppealCommand
        do { guard let loaded = try store.load() else { state = .idle; return }; command = loaded }
        catch { state = .storageFailed; return }
        state = .submitting
        do {
            let receipt = try await service.receipt(idempotencyKey: command.idempotencyKey)
            switch receipt.receipt {
            case .found:
                guard let appeal = receipt.appeal else { state = .awaitingReadback; return }
                resolve(appeal)
            case .notFound:
                state = .readbackNotFound
            }
        } catch { map(error) }
    }

    /// Explicit user action after NOT_FOUND: re-sends the persisted command with its original key.
    public func retryOriginal() async {
        guard state == .readbackNotFound else { return }
        do { guard let command = try store.load() else { state = .idle; return }; await dispatch(command) }
        catch { state = .storageFailed }
    }

    public func refresh(registrationID: FreeExploreLaunchID) async {
        do { appeals = try await service.list(registrationID: registrationID) }
        catch { if case FreeExploreLaunchFailure.disabled = error { state = .unavailable } }
    }

    public func presentation(for appeal: BundleAppeal) -> BundleAppealPresentation { BundleAppealPresentation(appeal) }

    private func dispatch(_ command: BundleAppealCommand) async {
        state = .submitting
        do {
            let appeal = try await service.submit(command)
            guard appeal.idempotencyKey == command.idempotencyKey, appeal.unitId == command.unitId else {
                state = .awaitingReadback; return
            }
            resolve(appeal)
        } catch { map(error) }
    }

    private func resolve(_ appeal: BundleAppeal) {
        do { try store.clear() } catch { state = .storageFailed; return }
        appeals = appeals.filter { $0.id != appeal.id } + [appeal]
        state = .submitted(appeal)
    }

    private func map(_ error: Error) {
        switch error {
        case FreeExploreLaunchFailure.disabled:
            // Nothing was sent. Release the lock so a later attempt (once available) starts clean.
            try? store.clear(); state = .unavailable
        case FreeExploreLaunchFailure.response(_, _, let code, _):
            if code == "LOGIN_REQUIRED" { state = .loginRequired; return } // keep the pending command
            // Definite business refusal: the server did not record the appeal.
            do { try store.clear(); state = .blocked(serverCode: code) } catch { state = .storageFailed }
        case FreeExploreLaunchFailure.outcomeUnknown, FreeExploreLaunchFailure.malformed, FreeExploreLaunchFailure.staleSession:
            state = .awaitingReadback
        case is APIError:
            state = .loginRequired // keep the pending command
        default:
            state = .awaitingReadback
        }
    }
}
