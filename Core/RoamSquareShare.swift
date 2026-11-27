import Foundation

/// ROAM-r11-9 发到广场 for a saved walk. MP pages/roam/index.js:5136-5233 (`_shareToSquare`) and
/// :5235-5256 (`_uploadOne`): the rendered card goes to `api/common/uploadOSS` (bizType COMMUNITY_POST),
/// then `api/creativesquare/action {contents, pics, data_id: sessionId, data_type: 3, request_id}`.
public enum RoamSquareShareOutcome: Equatable, Sendable {
    /// Server answered PUBLISHED (已发到广场).
    case published
    /// Accepted, waiting for review (已提交审核).
    case submitted
    /// The post may have gone out; a repeat is refused until the player checks the square.
    case unknown
    /// Server or upload refused; nothing was posted.
    case rejected
    /// Signed out, account changed or community write closed.
    case closed
    /// Another post is in flight.
    case busy
}

/// Request ids per account + roam session (MP `publishIntent`, scope `square:roam:<sessionId>`).
/// A pending or unknown key is reused; an unknown one blocks a new post (MP index.js:5146).
/// Held for the app run, not on disk.
@MainActor public final class RoamSquareShareIntents {
    private struct Key: Hashable { let account: Int; let session: Int }
    private enum State { case pending(String), unknown(String) }
    private var states: [Key: State] = [:]
    public init() {}
    public func isUnknown(account: Int, session: Int) -> Bool {
        if case .unknown = states[Key(account: account, session: session)] { return true }
        return false
    }
    func begin(account: Int, session: Int) -> String {
        let key = Key(account: account, session: session)
        switch states[key] {
        case .pending(let id), .unknown(let id): return id
        case nil:
            let id = UUID().uuidString
            states[key] = .pending(id); return id
        }
    }
    func settle(account: Int, session: Int, unknown: Bool) {
        let key = Key(account: account, session: session)
        guard let state = states[key] else { return }
        if unknown {
            if case .pending(let id) = state { states[key] = .unknown(id) }
        } else {
            states[key] = nil
        }
    }
}

@MainActor public final class RoamSquareSharePoster {
    public struct Identity: Equatable { public let accountID: Int; public let token: String
        public init(accountID: Int, token: String) { self.accountID = accountID; self.token = token } }
    private let service: SquareWorkspaceService
    private let identity: @MainActor () -> Identity?
    private let communityWrite: @MainActor () async -> Bool
    private let intents: RoamSquareShareIntents
    private var inFlight = false

    public init(service: SquareWorkspaceService, identity: @escaping @MainActor () -> Identity?,
                communityWrite: @escaping @MainActor () async -> Bool, intents: RoamSquareShareIntents? = nil) {
        // Default built here: a `@MainActor` init can't run in a default-argument (caller, nonisolated) context.
        self.service = service; self.identity = identity; self.communityWrite = communityWrite; self.intents = intents ?? RoamSquareShareIntents()
    }

    /// MP `share.communityWrite` (`app.canUseCommunity(true)`): the 发到广场 entry shows only when true.
    public func canWrite() async -> Bool { identity() != nil ? await communityWrite() : false }

    public func isUnknown(sessionID: Int) -> Bool {
        guard let current = identity() else { return false }
        return intents.isUnknown(account: current.accountID, session: sessionID)
    }

    public func post(png: Data, contents: String, sessionID: Int) async -> RoamSquareShareOutcome {
        guard !inFlight else { return .busy }
        let text = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sessionID > 0, !text.isEmpty, !png.isEmpty else { return .rejected }
        guard let start = identity() else { return .closed }
        guard !intents.isUnknown(account: start.accountID, session: sessionID) else { return .unknown }
        inFlight = true
        defer { inFlight = false }
        guard await communityWrite(), identity() == start else { return .closed }
        let media: SquareWorkspaceMedia
        do {
            media = try await service.upload(bytes: png, mimeType: "image/png", communityProof: true, token: start.token)
        } catch {
            return .rejected // Nothing was posted yet.
        }
        guard identity() == start else { return .closed }
        let requestID = intents.begin(account: start.accountID, session: sessionID)
        var draft = SquareWorkspaceDraft(workflowID: requestID, body: text)
        draft.media = [media]
        draft.reference = SquareWorkspaceReference(type: "ROUTE", id: sessionID) // legacy data_type 3 (MP index.js:5181)
        do {
            let lifecycle = try await service.legacyPublishLifecycle(draft: draft, token: start.token)
            intents.settle(account: start.accountID, session: sessionID, unknown: false)
            return lifecycle == "PUBLISHED" ? .published : .submitted
        } catch SquareWorkspaceFailure.rejected(_) {
            intents.settle(account: start.accountID, session: sessionID, unknown: false)
            return .rejected
        } catch SquareWorkspaceFailure.invalid {
            intents.settle(account: start.accountID, session: sessionID, unknown: false)
            return .rejected
        } catch {
            intents.settle(account: start.accountID, session: sessionID, unknown: true)
            return .unknown
        }
    }
}
