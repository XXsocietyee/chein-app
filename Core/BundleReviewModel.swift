import Foundation

// MARK: - Bundle reviews model (IWP-8a; unmounted)
// Rating 1...5, content <= 500 characters. Eligibility is whatever the SERVER says (`mine`); the client
// never derives it. A freshly submitted review is PENDING moderation and is shown to its author as
// "under review", never as published. The public list shows server-approved rows only.
// Write safety: the command is persisted BEFORE dispatch; an unknown outcome is read back via `mine`
// and may only be re-sent with the SAME idempotency key (never a fresh one). Login loss
// (business 409 LOGIN_REQUIRED) is not a refusal and keeps the pending command.

public enum BundleReviewStatusKind: Equatable {
    case underReview, published, rejected, hidden, unknown

    public init(status: String) {
        switch status {
        case "PENDING": self = .underReview
        case "APPROVED": self = .published
        case "REJECTED": self = .rejected
        case "HIDDEN": self = .hidden
        default: self = .unknown
        }
    }

    /// Author-facing label. New strings are listed in docs/owner-plan/iwp-8a-new-strings.md.
    public var label: String {
        switch self {
        case .underReview: return W8Text.t("审核中", "Under review")
        case .published: return W8Text.t("已发布", "Published")
        case .rejected: return W8Text.t("未通过审核", "Not approved")
        case .hidden: return W8Text.t("已隐藏", "Hidden")
        case .unknown: return W8Text.t("状态未知", "Status unknown")
        }
    }
}

extension BundleReview {
    public var statusKind: BundleReviewStatusKind { BundleReviewStatusKind(status: status) }
}

/// Owner-bound durable copy of the one unresolved review command (recovery metadata only: no token).
@MainActor public final class BundleReviewPendingStore {
    private let storage: any TemplateAuthoringStorage
    private let ownerKey: String
    private var key: String { "bundle-review.pending.v1." + Data(ownerKey.utf8).base64EncodedString() }
    private struct Record: Codable {
        let version: Int
        let ownerKey: String
        let command: BundleReviewCommand
    }

    public init(storage: any TemplateAuthoringStorage, session: FreeExploreLaunchSession) {
        self.storage = storage; ownerKey = session.ownerKey
    }

    public func load() throws -> BundleReviewCommand? {
        do {
            guard let data = try storage.read(key) else { return nil }
            guard data.count <= 16_384 else { throw FreeExploreLaunchFailure.storageUnavailable }
            let record = try JSONDecoder().decode(Record.self, from: data)
            guard record.version == 1, record.ownerKey == ownerKey else { throw FreeExploreLaunchFailure.storageUnavailable }
            try record.command.validate()
            return record.command
        } catch { throw FreeExploreLaunchFailure.storageUnavailable }
    }

    /// Never replaces a different unresolved command.
    public func save(_ command: BundleReviewCommand) throws {
        try command.validate()
        if let previous = try load() {
            guard previous == command else { throw FreeExploreLaunchFailure.pendingConflict }
            return
        }
        do {
            let data = try JSONEncoder().encode(Record(version: 1, ownerKey: ownerKey, command: command))
            try storage.write(data, key: key)
            guard try load() == command else { throw FreeExploreLaunchFailure.storageUnavailable }
        } catch let failure as FreeExploreLaunchFailure {
            throw failure
        } catch { throw FreeExploreLaunchFailure.storageUnavailable }
    }

    public func clear() throws {
        do {
            try storage.remove(key)
            guard try storage.read(key) == nil else { throw FreeExploreLaunchFailure.storageUnavailable }
        } catch { throw FreeExploreLaunchFailure.storageUnavailable }
    }
}

public enum BundleReviewComposeState: Equatable {
    case idle
    case loading
    /// Server says this holder may not review (reason code shown verbatim, never interpreted).
    case blocked(reasonCode: String?)
    case ready
    /// The server already holds a review for this order (one per order and holder).
    case alreadyReviewed(BundleReview)
    case submitting
    case submitted(BundleReview)
    /// Definite server refusal (e.g. duplicate): the server's business code, verbatim.
    case rejected(code: String?)
    /// The write may or may not have landed: read back, then (only if nothing landed) retry the SAME command.
    case outcomeUnknown
    case unavailable
    /// Nothing was sent (storage or stale session).
    case failed
}

@MainActor public final class BundleReviewComposeModel: ObservableObject {
    @Published public private(set) var state: BundleReviewComposeState = .idle
    /// True once a read-back found that the unknown write did not land; only then may it be re-sent.
    @Published public private(set) var readBackFoundNothing = false
    public let registrationID: FreeExploreLaunchID
    private let accountID: FreeExploreLaunchID
    private let service: any BundleReviewServing
    private let pendingStore: BundleReviewPendingStore?
    private let makeKey: () -> String

    public init(registrationID: FreeExploreLaunchID, accountID: FreeExploreLaunchID, service: any BundleReviewServing,
                pendingStore: BundleReviewPendingStore? = nil,
                makeKey: @escaping () -> String = { "rv-" + UUID().uuidString }) {
        self.registrationID = registrationID; self.accountID = accountID; self.service = service
        self.pendingStore = pendingStore; self.makeKey = makeKey
    }

    public var canRetryOriginal: Bool { state == .outcomeUnknown && readBackFoundNothing }

    /// Pure input check for the view (server re-validates).
    public static func isValidInput(rating: Int, content: String) -> Bool {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return BundleReviewCommand.ratingRange.contains(rating) && !text.isEmpty
            && text.count <= BundleReviewCommand.maxContentLength
    }

    public func load() async {
        switch state {
        case .loading, .submitting, .outcomeUnknown: return
        default: break
        }
        if let pendingStore {
            do {
                if let pending = try pendingStore.load() {
                    state = pending.registrationId == registrationID ? .outcomeUnknown : .failed
                    return
                }
            } catch { state = .failed; return }
        }
        state = .loading
        do {
            let mine = try await service.mine(registrationID: registrationID)
            if let review = mine.review { state = .alreadyReviewed(review) }
            else if mine.eligible { state = .ready }
            else { state = .blocked(reasonCode: mine.reasonCode) }
        } catch let failure as FreeExploreLaunchFailure where failure == .disabled {
            state = .unavailable
        } catch { state = .failed }
    }

    /// Returns false (state unchanged) for invalid input or when not in `.ready`.
    @discardableResult
    public func submit(rating: Int, content: String) async -> Bool {
        guard state == .ready else { return false }
        let command: BundleReviewCommand
        do {
            command = try BundleReviewCommand(registrationId: registrationID, rating: rating, content: content,
                                              idempotencyKey: makeKey())
        } catch { return false }
        if let pendingStore {
            do { try pendingStore.save(command) } catch { state = .failed; return false }
        }
        await dispatch(command)
        return true
    }

    /// After `.outcomeUnknown`: ask the server what it holds. Never sends a write.
    public func recover() async {
        guard state == .outcomeUnknown else { return }
        let command: BundleReviewCommand?
        do { command = try pendingStore?.load() } catch { return }
        do {
            let mine = try await service.mine(registrationID: registrationID)
            if let review = mine.review {
                try? pendingStore?.clear()
                if let command, review.idempotencyKey == command.idempotencyKey { state = .submitted(review) }
                else { state = .alreadyReviewed(review) }
            } else {
                readBackFoundNothing = true
            }
        } catch { /* stays unknown */ }
    }

    /// Re-sends the persisted original command with its ORIGINAL key, only after a read-back found nothing.
    public func retryOriginal() async {
        guard canRetryOriginal else { return }
        let command: BundleReviewCommand?
        do { command = try pendingStore?.load() } catch { state = .failed; return }
        guard let command else { return }
        await dispatch(command)
    }

    private func dispatch(_ command: BundleReviewCommand) async {
        state = .submitting
        do {
            let review = try await service.submit(command)
            guard review.idempotencyKey == command.idempotencyKey,
                  review.registrationId == command.registrationId,
                  review.holderMemberId == accountID else {
                state = .outcomeUnknown; return
            }
            try? pendingStore?.clear()
            readBackFoundNothing = false
            state = .submitted(review)
        } catch let failure as FreeExploreLaunchFailure {
            switch failure {
            case .disabled:
                try? pendingStore?.clear(); state = .unavailable
            case .response(_, _, let code, _) where code != "LOGIN_REQUIRED":
                try? pendingStore?.clear(); state = .rejected(code: code)
            default:
                state = .outcomeUnknown
            }
        } catch {
            state = .outcomeUnknown
        }
    }
}

public enum BundleReviewListState: Equatable {
    case idle, loading, loaded, empty, unavailable, failed
}

/// Public list: approved reviews only, even if a server bug returned others.
@MainActor public final class BundleReviewListModel: ObservableObject {
    public static let pageSize = 20
    @Published public private(set) var state: BundleReviewListState = .idle
    @Published public private(set) var items: [BundleReview] = []
    @Published public private(set) var hasMore = false
    private var cursor: String?
    private let topicID: FreeExploreLaunchID
    private let service: any BundleReviewServing

    public init(topicID: FreeExploreLaunchID, service: any BundleReviewServing) {
        self.topicID = topicID; self.service = service
    }

    public func load() async {
        guard state != .loading else { return }
        items = []; cursor = nil; hasMore = false
        await fetch(cursor: nil)
    }

    public func loadMore() async {
        guard state == .loaded, hasMore, let cursor else { return }
        await fetch(cursor: cursor)
    }

    private func fetch(cursor requested: String?) async {
        state = .loading
        do {
            let page = try await service.list(topicID: topicID, cursor: requested, limit: Self.pageSize)
            var seen = Set(items.map(\.id))
            for review in page.items where review.status == "APPROVED" && !seen.contains(review.id) {
                seen.insert(review.id); items.append(review)
            }
            cursor = page.nextCursor
            hasMore = page.nextCursor != nil && !(page.nextCursor ?? "").isEmpty
            state = items.isEmpty ? .empty : .loaded
        } catch let failure as FreeExploreLaunchFailure where failure == .disabled {
            state = .unavailable
        } catch {
            state = items.isEmpty ? .failed : .loaded
        }
    }
}
