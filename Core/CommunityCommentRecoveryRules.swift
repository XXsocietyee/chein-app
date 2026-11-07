import Foundation

/// Mini-program `utils/community-comment-recovery.js`: one durable pending comment per (member, post),
/// replayed with the same client request id until the server answers definitively. Pure transitions over
/// an in-memory row; persistence and the actual request stay with the caller.
public enum CommunityCommentRecoveryRules {
    public static let bodyLimit = 2000

    public struct Wire: Equatable {
        public let body: String
        public let parentID: String?
        public let clientRequestID: String
        public init(body: String, parentID: String?, clientRequestID: String) {
            self.body = body; self.parentID = parentID; self.clientRequestID = clientRequestID
        }
    }

    public enum Status: String, Equatable { case sending, unknown, rejected }

    public struct Row: Equatable {
        public let key: String
        public let memberID: String
        public let postID: String
        public let status: Status
        public let wire: Wire
        public init(key: String, memberID: String, postID: String, status: Status, wire: Wire) {
            self.key = key; self.memberID = memberID; self.postID = postID; self.status = status; self.wire = wire
        }
    }

    public enum Failure: Error, Equatable {
        /// 507: the local record could not be written / cleared.
        case storageFailed
        /// 409: stored record is incomplete or belongs to someone else.
        case incompleteRecord
        /// 409: identity or post id invalid.
        case invalidIdentity
        /// 400: body must be 1...2000 characters.
        case invalidBody
        /// 409: an earlier comment is unconfirmed and this one differs; retry the original first.
        case pendingDiffers(Wire)
        /// 400: client request id must be 8...96 characters.
        case invalidRequestID
        public var sourceCode: Int {
            switch self {
            case .storageFailed: return 507
            case .incompleteRecord, .invalidIdentity, .pendingDiffers: return 409
            case .invalidBody, .invalidRequestID: return 400
            }
        }
    }

    /// Source `exactId` (`exactSessionId`): canonical positive decimal, up to Int64.max.
    public static func isExactID(_ value: String) -> Bool {
        guard (1...19).contains(value.utf8.count), value.utf8.first != 48,
              value.utf8.allSatisfy({ (48...57).contains($0) }) else { return false }
        return value.utf8.count < 19 || value <= "9223372036854775807"
    }

    /// Source `validKey`: trimmed length 8...96 (UTF-16 units).
    public static func isValidKey(_ key: String) -> Bool {
        (8...96).contains(key.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count)
    }

    /// Source `pending`: a stored row is usable only when status, owner, post, key, body and parent agree.
    public static func validateStored(_ row: Row?, owner: String, post: String) -> Result<Row?, Failure> {
        guard isExactID(owner), isExactID(post) else { return .success(nil) }
        guard let row else { return .success(nil) }
        guard row.memberID == owner, row.postID == post, isValidKey(row.key),
              !row.wire.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              row.wire.clientRequestID == row.key,
              row.wire.parentID.map(isExactID) ?? true else { return .failure(.incompleteRecord) }
        return .success(row)
    }

    /// Source `prepare`. Returns the row to send and whether it is a replay of the stored one.
    /// `rejected` rows never block a new comment; `sending`/`unknown` rows must be retried verbatim.
    public static func prepare(stored: Row?, owner: String, post: String, wire: Wire) -> Result<(row: Row, reused: Bool), Failure> {
        guard isExactID(owner), isExactID(post) else { return .failure(.invalidIdentity) }
        guard !wire.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, wire.body.utf16.count <= bodyLimit else {
            return .failure(.invalidBody)
        }
        switch validateStored(stored, owner: owner, post: post) {
        case .failure(let failure): return .failure(failure)
        case .success(let row):
            if let row, row.status != .rejected {
                guard row.wire.body == wire.body, (row.wire.parentID ?? "") == (wire.parentID ?? "") else {
                    return .failure(.pendingDiffers(row.wire))
                }
                return .success((row, true))
            }
        }
        guard isValidKey(wire.clientRequestID) else { return .failure(.invalidRequestID) }
        return .success((Row(key: wire.clientRequestID, memberID: owner, postID: post, status: .sending, wire: wire), false))
    }

    public enum Settlement: Equatable {
        /// Nothing stored, or the stored row belongs to a newer attempt: leave it.
        case ignore
        /// Server accepted (200): clear the durable row.
        case clear
        /// Keep the row with this status.
        case keep(Status)
    }

    /// Source `finish`: 200 clears; a first-attempt 400/403/404 is a definite rejection (a later edit may use
    /// a new request id); everything else, and any failure of a replay, stays `unknown` and must be retried
    /// verbatim.
    public static func settle(stored: Row?, attempted: Row, reused: Bool, code: Int) -> Settlement {
        guard let stored, stored.key == attempted.key else { return .ignore }
        if code == 200 { return .clear }
        return .keep(!reused && [400, 403, 404].contains(code) ? .rejected : .unknown)
    }
}
