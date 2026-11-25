import Foundation

public enum ClubCommunityFailure: Error, Equatable {
    case invalid, unavailable, stale, forbidden, rejected(Int), unknown, locked
}

public struct ClubCommunityPost: Equatable, Identifiable {
    public let id: Int, clubID: Int?, authorMemberID: Int?, version: Int, type: Int
    public let content: String, images: [String], nickname: String, createTime: String
    public let clubName: String
    public let liked: Bool, pinned: Bool, edited: Bool, viewerCanManage: Bool
    public let likeCount: Int, commentCount: Int
    /// CLB-detail-03: MP utils/club-post-repost.js `viewerReposted` / `repostCount`.
    public let reposted: Bool, repostCount: Int
    public let refType: Int?, refID: Int?, sportTopicID: Int?
    public let sportName: String, sportCover: String
    public let isTopicTemplate: Bool
    /// Activity feed block. Empty when this club post has no activity, so the tile stays text and images.
    public let activityCard: SquareStravaCard
    public var hasContent: Bool { !content.isEmpty || !images.isEmpty || (!sportName.isEmpty && (refType == 1 || !sportCover.isEmpty)) }
    public var navigableTopicID: Int? { guard let id = sportTopicID, id > 0 else { return nil }; return id }
    public init(json: [String: Any]) throws {
        guard let id = json["id"] as? Int, id > 0 else { throw ClubCommunityFailure.invalid }
        self.id = id; clubID = json["clubId"] as? Int; authorMemberID = json["authorMemberId"] as? Int
        version = (json["version"] as? Int) ?? 0; type = (json["type"] as? Int) ?? 0
        content = CCWire.text(json["content"]); images = CCWire.images(json["images"])
        nickname = CCWire.text(json["nickname"]); createTime = CCWire.text(json["createTime"])
        clubName = CCWire.text(json["clubName"])
        liked = CCWire.bool(json["isLiked"] ?? json["liked"]); pinned = CCWire.bool(json["isPinned"])
        edited = CCWire.bool(json["edited"]); viewerCanManage = CCWire.bool(json["viewerCanManage"])
        likeCount = (json["likeCount"] as? Int) ?? 0; commentCount = (json["commentCount"] as? Int) ?? 0
        reposted = CCWire.bool(json["viewerReposted"] ?? json["reposted"]); repostCount = max(0, (json["repostCount"] as? Int) ?? 0)
        refType = json["refType"] as? Int; refID = json["refId"] as? Int; sportTopicID = json["sportTopicId"] as? Int
        sportName = CCWire.text(json["sportName"]); sportCover = CCWire.text(json["sportCover"]); isTopicTemplate = CCWire.bool(json["isTopicTemplate"])
        let linkedType = (json["dataType"] as? Int) ?? (refType == 1 ? 1 : 0)
        let linkedID = (json["dataId"] as? Int) ?? refID
        activityCard = SquareStravaCard.decode(json: json, dataType: linkedType, dataID: linkedID)
    }
}
public struct ClubCommunityComment: Equatable, Identifiable {
    public let id: Int, postID: Int?, memberID: Int?
    public let content: String, nickname: String, createTime: String
    public init(json: [String: Any]) throws {
        guard let id = json["id"] as? Int, id > 0 else { throw ClubCommunityFailure.invalid }
        self.id = id; postID = json["postId"] as? Int; memberID = json["memberId"] as? Int
        content = CCWire.text(json["content"]); nickname = CCWire.text(json["nickname"]); createTime = CCWire.text(json["createTime"])
    }
}
/// Public snapshots intentionally exclude editor/moderator identity.
public struct ClubCommunityRevision: Equatable, Identifiable {
    public let id: Int, snapshotVersion: Int
    public let content: String, images: [String], createTime: String
    public init(json: [String: Any]) throws {
        guard let id = json["id"] as? Int, id > 0 else { throw ClubCommunityFailure.invalid }
        self.id = id; snapshotVersion = (json["snapshotVersion"] as? Int) ?? 0
        content = CCWire.text(json["content"]); images = CCWire.images(json["images"]); createTime = CCWire.text(json["createTime"])
    }
}
enum CCWire {
    static func text(_ value: Any?) -> String { ((value as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    static func bool(_ value: Any?) -> Bool { (value as? Bool == true) || (value as? Int == 1) }
    static func images(_ value: Any?) -> [String] { text(value).split(whereSeparator: { $0 == ";" || $0 == "," }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
    static func rows(_ value: Any?) throws -> [[String: Any]] {
        if let rows = value as? [[String: Any]] { return rows }
        if let object = value as? [String: Any], let rows = object["rows"] as? [[String: Any]] { return rows }
        throw ClubCommunityFailure.invalid
    }
}
public struct ClubCommunitySession: Equatable {
    public let identity: ClubReadIdentity
    let token: String?
    public init(identity: ClubReadIdentity, token: String?) throws {
        guard identity.accountID == nil || (identity.accountID! > 0 && token.map(AuthRequestBuilder.isValidToken) == true) else { throw ClubCommunityFailure.invalid }
        self.identity = identity; self.token = token
    }
}
public enum ClubCommunityRead: Equatable {
    case posts(clubID: Int, beforeID: Int?, limit: Int), feed(limit: Int, beforeID: Int?)
    /// Compatibility is first-page only. A page number is not a backend cursor.
    public static func posts(clubID: Int, page: Int) -> Self {
        .posts(clubID: clubID, beforeID: nil, limit: page == 1 ? 20 : 0)
    }
    /// Page 1 is the first discover page. A later page number is not a cursor; pass `beforeID`.
    public static func feed(page: Int) -> Self { .feed(limit: page == 1 ? 20 : 0, beforeID: nil) }
    case comments(postID: Int, page: Int), history(postID: Int)
    var suffix: String { switch self { case .posts: return "list"; case .feed: return "feed"; case .comments: return "comment/list"; case .history: return "history" } }
    var fields: [String: Any] {
        switch self {
        case let .posts(id, beforeID, limit):
            var fields: [String: Any] = ["clubId": id, "limit": limit]
            if let beforeID { fields["beforeId"] = beforeID }
            return fields
        case let .feed(limit, beforeID):
            var fields: [String: Any] = ["limit": limit, "scope": "all"]
            if let beforeID { fields["beforeId"] = beforeID }
            return fields
        case let .comments(id, _): return ["postId": id]
        case let .history(id): return ["id": id]
        }
    }
}
public struct ClubCommunitySnapshot {
    public let posts: [ClubCommunityPost], comments: [ClubCommunityComment], history: [ClubCommunityRevision]
    public let clubCount: Int?
    public let postPage: ClubCommunityPostPage?
    public let feedItems: [ClubCommunityFeedItem]
    /// Server `hasMore` for `POST /api/club/post/feed`. Club post pages leave this false.
    public let feedHasMore: Bool
    /// `beforeId` sent for this feed page. Nil is the first page.
    public let feedRequestedBeforeID: Int?
    /// Last row id to send as the next `beforeId`.
    public let feedNextBeforeID: Int?
    public init(posts: [ClubCommunityPost], comments: [ClubCommunityComment], history: [ClubCommunityRevision], clubCount: Int?, postPage: ClubCommunityPostPage? = nil, feedItems: [ClubCommunityFeedItem]? = nil, feedHasMore: Bool = false, feedRequestedBeforeID: Int? = nil, feedNextBeforeID: Int? = nil) {
        self.posts = posts; self.comments = comments; self.history = history; self.clubCount = clubCount
        self.postPage = postPage; self.feedItems = feedItems ?? posts.map { .original($0) }
        self.feedHasMore = feedHasMore; self.feedRequestedBeforeID = feedRequestedBeforeID; self.feedNextBeforeID = feedNextBeforeID
    }
}
public enum ClubCommunityOperation: Equatable {
    /// CLB-detail-12: `notice` posts a 公告 (type 2), offered to the owner and administrators only (MP canAnnounce).
    /// CLB-G05 (MP `pages/club/detail/index.js:1969-2004`, `cy-post-compose` publish): `ref` is the play record picked
    /// from `/api/registration/my-joined`; it travels as `refType` / `refId` on `api/club/post/create`.
    case create(content: String, images: [String], notice: Bool = false, ref: ClubPostRefOption? = nil)
    case update(content: String, images: [String], requestID: String)
    case pin(Bool, requestID: String), delete, report, toggleLike
    /// CLB-detail-03: `true` reposts (api/club/post/repost), `false` undoes it (repost/undo); body `{ postId }`.
    case repost(Bool)
    case comment(String), deleteComment, reportComment
    public var labelKey: String {
        switch self { case .create: return "create"; case .update: return "edit"; case .pin: return "pin"; case .delete: return "delete"; case .report: return "report"; case .toggleLike: return "like"; case .repost(let on): return on ? "repost" : "unrepost"; case .comment: return "comment"; case .deleteComment: return "deleteComment"; case .reportComment: return "reportComment" }
    }
    var suffix: String {
        switch self { case .create: return "create"; case .update: return "update"; case .pin: return "pin"; case .delete: return "delete"; case .report: return "report"; case .toggleLike: return "like"; case .repost(let on): return on ? "repost" : "repost/undo"; case .comment: return "comment/create"; case .deleteComment: return "comment/delete"; case .reportComment: return "comment/report" }
    }
}
/// Must come from a fresh host membership read plus exact post/comment read under this epoch.
public struct ClubCommunityEvidence: Equatable {
    public let identity: ClubReadIdentity, clubID: Int, joined: Bool, owner: Bool, administrator: Bool
    public let post: ClubCommunityPost?, comment: ClubCommunityComment?
    public let observedAt: Date
    /// Nil means the detail read did not say. `false` is MP `memberPostAllowed == 0`.
    public let memberPostAllowed: Bool?
    public init(identity: ClubReadIdentity, clubID: Int, joined: Bool, owner: Bool, administrator: Bool, post: ClubCommunityPost? = nil, comment: ClubCommunityComment? = nil, observedAt: Date = Date(), memberPostAllowed: Bool? = nil) {
        self.identity = identity; self.clubID = clubID; self.joined = joined; self.owner = owner; self.administrator = administrator; self.post = post; self.comment = comment; self.observedAt = observedAt
        self.memberPostAllowed = memberPostAllowed
    }
    public func allows(_ operation: ClubCommunityOperation) -> Bool {
        guard let viewer = identity.accountID, viewer > 0, clubID > 0 else { return false }
        if let post, post.clubID != clubID { return false }
        if let comment, comment.postID != post?.id { return false }
        let mine = post?.authorMemberID == viewer
        let manager = owner || administrator || post?.viewerCanManage == true
        switch operation {
        case let .create(_, _, notice, _):
            if notice { return owner || administrator }
            if owner || administrator { return true }
            return joined && memberPostAllowed != false
        case .update: return post != nil && (post?.type == 2 ? manager : mine)
        case .pin: return post?.type == 2 && manager
        case .delete: return post != nil && (mine || manager)
        case .report: return post != nil && !mine
        case .toggleLike, .comment: return post != nil
        case .repost: return post != nil
        case .deleteComment: return comment != nil && (comment?.memberID == viewer || manager)
        case .reportComment: return comment != nil && comment?.memberID != viewer
        }
    }
}
public struct ClubCommunityReview: Equatable, Identifiable {
    public let id: UUID, operation: ClubCommunityOperation, evidence: ClubCommunityEvidence
    public init(operation: ClubCommunityOperation, evidence: ClubCommunityEvidence) throws {
        guard evidence.allows(operation) else { throw ClubCommunityFailure.forbidden }
        id = UUID(); self.operation = operation; self.evidence = evidence
        _ = try fields()
    }
    public var lockKey: String { "\(evidence.identity.accountID ?? 0):\(evidence.clubID):\(evidence.post?.id ?? 0):\(evidence.comment?.id ?? 0)" }
    func fields() throws -> [String: Any] {
        func body(_ content: String, _ images: [String]) throws {
            guard content.count <= 300, images.count <= 9, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty,
                  images.allSatisfy({ !$0.isEmpty && !$0.contains(";") }) else { throw ClubCommunityFailure.invalid }
        }
        let postID = evidence.post?.id ?? 0, commentID = evidence.comment?.id ?? 0
        switch operation {
        case let .create(content, images, notice, ref):
            try body(content, images); var fields: [String: Any] = ["clubId": evidence.clubID, "content": content]
            if !images.isEmpty { fields["images"] = images.joined(separator: ";") }
            if notice { fields["type"] = 2 }
            if let ref, ref.refID > 0 { fields["refType"] = ref.refType; fields["refId"] = ref.refID }
            return fields
        case let .update(content, images, key):
            try body(content, images); guard !key.isEmpty else { throw ClubCommunityFailure.invalid }
            return ["id": postID, "content": content, "images": images.joined(separator: ";"), "version": evidence.post!.version, "requestId": key]
        case let .pin(pinned, key):
            guard !key.isEmpty else { throw ClubCommunityFailure.invalid }
            return ["id": postID, "pinned": pinned, "version": evidence.post!.version, "requestId": key]
        case .delete, .report: return ["id": postID]
        case .toggleLike, .repost: return ["postId": postID]
        case let .comment(content):
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ClubCommunityFailure.invalid }
            return ["postId": postID, "content": content]
        case .deleteComment, .reportComment: return ["id": commentID]
        }
    }
}
