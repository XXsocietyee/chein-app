import Foundation

/// Pure rules of the mini-program `utils/club-post-repost.js` `toggleRepost` / `applyRepostState`.
/// It performs no I/O: callers send `Ticket.endpoint` with `{ postId }` and feed the outcome back.
/// Contract: POST api/club/post/repost and api/club/post/repost/undo answer `{ reposted, repostCount }`.
public struct ClubPostRepostToggle: Equatable {
    public enum Endpoint: String, Equatable {
        case repost = "api/club/post/repost"
        case undo = "api/club/post/repost/undo"
    }

    /// What a card shows: whether the viewer reposted it and the repost counter (never negative).
    public struct State: Equatable {
        public let reposted: Bool
        public let count: Int
        public init(reposted: Bool, count: Int) { self.reposted = reposted; self.count = max(0, count) }
    }

    /// A feed row reduced to what the toggle reads. `isCommunity` rows (source == "community") are
    /// never reposted: community and club post ids can collide.
    public struct Row: Equatable {
        public let id: String
        public let isCommunity: Bool
        public var state: State
        public init(id: String, isCommunity: Bool, state: State) { self.id = id; self.isCommunity = isCommunity; self.state = state }
    }

    public struct Ticket: Equatable {
        public let postID: String
        public let endpoint: Endpoint
        public let before: State
        public let optimistic: State
        let token: Int
    }

    public struct Response: Equatable {
        public let code: Int?
        public let message: String?
        public let reposted: Bool?
        public let repostCount: Int?
        public init(code: Int?, message: String?, reposted: Bool?, repostCount: Int?) {
            self.code = code; self.message = message; self.reposted = reposted; self.repostCount = repostCount
        }
    }

    public enum Result: Equatable { case response(Response), networkFailure }

    public enum Outcome: Equatable {
        /// A newer ticket owns this post (or none is pending): change nothing.
        case ignored
        /// Show the server's truth.
        case applied(State)
        /// Restore `State`; show the server message verbatim when present, else the generic failure copy.
        case rolledBack(State, serverMessage: String?)
        /// Restore `State`; show the generic network copy.
        case rolledBackNetwork(State)
    }

    private var pending: [String: Int] = [:]
    private var nextToken = 0
    public init() {}

    public func isPending(postID: String) -> Bool { pending[postID] != nil }

    /// Source: no row for the id (or a community row) -> false; a request still in flight for the same
    /// post -> false; otherwise flip optimistically, count never below zero.
    public mutating func begin(postID: String, rows: [Row]) -> Ticket? {
        guard let row = rows.first(where: { !$0.isCommunity && $0.id == postID }), pending[postID] == nil else { return nil }
        nextToken += 1
        let target = !row.state.reposted
        pending[postID] = nextToken
        return Ticket(postID: postID, endpoint: target ? .repost : .undo, before: row.state,
                      optimistic: State(reposted: target, count: row.state.count + (target ? 1 : -1)), token: nextToken)
    }

    /// Source `success`: only code 200 with a boolean `reposted` is accepted; a missing/non-integer count
    /// keeps the pre-request count. Anything else, and every network failure, rolls back.
    public mutating func resolve(_ ticket: Ticket, result: Result) -> Outcome {
        guard pending[ticket.postID] == ticket.token else { return .ignored }
        pending[ticket.postID] = nil
        switch result {
        case .networkFailure:
            return .rolledBackNetwork(ticket.before)
        case .response(let response):
            guard response.code == 200, let reposted = response.reposted else {
                return .rolledBack(ticket.before, serverMessage: response.message)
            }
            return .applied(State(reposted: reposted, count: response.repostCount ?? ticket.before.count))
        }
    }

    /// Source `applyRepostState`: one post may appear as the original and as repost entries; every
    /// non-community row with that id changes together.
    public static func apply(_ state: State, toPostID postID: String, in rows: [Row]) -> [Row] {
        rows.map { row in
            guard !row.isCommunity, row.id == postID else { return row }
            var copy = row; copy.state = state; return copy
        }
    }
}
