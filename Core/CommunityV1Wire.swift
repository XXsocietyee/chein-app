import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// L5 does not move money. Payment, wallet, withdrawal, order and IAP paths are refused.
public enum CloudL5Money {
    public static let enabled = false

    public static func isPaymentPath(_ path: String) -> Bool {
        let value = path.lowercased()
        return value.contains("pay") || value.contains("wallet") || value.contains("withdraw") || value.contains("/order") || value.contains("iap")
    }
}

public enum CommunityWireBlock: Error, Equatable {
    case unsupported
    case refreshPost
    case refreshComment
    case stalePage
    case unsupportedLink
    case attachmentClosed
    case moneyOff
    case invalid
}

public enum CommunityJSON: Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case null
    case array([CommunityJSON])
    case object([String: CommunityJSON])

    var object: Any {
        switch self {
        case .string(let value): return value
        case .int(let value): return value
        case .bool(let value): return value
        case .null: return NSNull()
        case .array(let values): return values.map(\.object)
        case .object(let fields): return fields.mapValues(\.object)
        }
    }
}

public struct CommunityV1Call: Equatable {
    public let method: String
    public let path: String
    public let query: [String: String]
    public let body: CommunityJSON?

    public init(method: String, path: String, query: [String: String] = [:], body: CommunityJSON? = nil) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
    }

    public func urlRequest(configuration: APIConfiguration, token: String) throws -> URLRequest {
        guard CloudL5Money.enabled == false, !CloudL5Money.isPaymentPath(path) else { throw CommunityWireBlock.moneyOff }
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        guard var components = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidRequest
        }
        if !query.isEmpty {
            components.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) }
        }
        guard let url = components.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body.object, options: [.sortedKeys])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}

/// `community-post-api.js` `stableCommand`. The id is kept until a 2xx or 4xx answer.
/// 5xx, 3xx and a lost response keep the same id. A proposed id is used only for the first attempt.
public struct CommunityCommandLedger: Equatable {
    private var commands: [String: String] = [:]

    public init() {}

    public func current(_ key: String) -> String? { commands[key] }

    public mutating func id(for key: String, proposed: String?, mint: () -> String) -> String {
        if let existing = commands[key] { return existing }
        let trimmed = proposed?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let value = trimmed.isEmpty ? mint() : trimmed
        commands[key] = value
        return value
    }

    public mutating func settle(key: String, requestID: String, code: Int?) {
        guard let code, commands[key] == requestID else { return }
        if (200..<300).contains(code) || (400..<500).contains(code) { commands[key] = nil }
    }
}

public enum CommunityPageCursor: Equatable {
    case start
    case token(String)
}

/// One feed or comment page book. Page 1 opens the book. A page that was never recorded is stale.
public struct CommunityPageBook: Equatable {
    private var pages: [Int: CommunityPageCursor] = [:]

    public init() {}

    public static func firstPage() -> CommunityPageBook {
        var book = CommunityPageBook()
        book.pages[1] = .start
        return book
    }

    public func cursor(page: Int) -> CommunityPageCursor? { pages[page] }

    public mutating func recordNext(page: Int, next: String?) {
        pages[page + 1] = next.map(CommunityPageCursor.token) ?? .start
    }
}

/// Legacy `/api/creativesquare/*` and `/api/comment/*` reads and writes, expressed only as
/// `/api/v1/community/*`. Writes include PATCH and DELETE, not only POST.
public struct CommunityV1Wire: Equatable {
    public static let base = "api/v1/community"
    public static let actionSource = "APP_SQUARE"
    public private(set) var ledger = CommunityCommandLedger()
    public private(set) var books: [String: CommunityPageBook] = [:]

    public init() {}

    public mutating func list(page: Int, pageSize: Int, favoriteOnly: Bool, mine: Bool, authorID: Int?) -> Result<CommunityV1Call, CommunityWireBlock> {
        let key = Self.pageKey(favoriteOnly: favoriteOnly, mine: mine, authorID: authorID)
        if page == 1 { books[key] = .firstPage() }
        guard let cursor = books[key]?.cursor(page: page) else { return .failure(.stalePage) }
        var query = ["limit": String(pageSize)]
        if case .token(let token) = cursor { query["cursor"] = token }
        if let authorID, authorID > 0 { query["authorId"] = String(authorID) }
        let path: String
        if favoriteOnly { path = "\(Self.base)/me/bookmarks" }
        else if mine { path = "\(Self.base)/me/posts" }
        else { path = "\(Self.base)/feeds/LATEST" }
        return .success(CommunityV1Call(method: "GET", path: path, query: query))
    }

    public mutating func noteListPage(favoriteOnly: Bool, mine: Bool, authorID: Int?, page: Int, next: String?) {
        let key = Self.pageKey(favoriteOnly: favoriteOnly, mine: mine, authorID: authorID)
        guard var book = books[key] else { return }
        book.recordNext(page: page, next: next)
        books[key] = book
    }

    public func detail(id: Int) -> Result<CommunityV1Call, CommunityWireBlock> {
        guard id > 0 else { return .failure(.invalid) }
        return .success(CommunityV1Call(method: "GET", path: "\(Self.base)/posts/\(id)"))
    }

    public func comments(postID: Int, page: Int, pageSize: Int, book: CommunityPageBook) -> Result<CommunityV1Call, CommunityWireBlock> {
        guard postID > 0, let cursor = book.cursor(page: page) else { return .failure(postID > 0 ? .stalePage : .invalid) }
        var query = ["limit": String(pageSize)]
        if case .token(let token) = cursor { query["cursor"] = token }
        return .success(CommunityV1Call(method: "GET", path: "\(Self.base)/posts/\(postID)/comments", query: query))
    }

    public mutating func postAction(id: Int, kind: String, enabled: Bool, knownPost: Bool, proposedID: String?, mint: () -> String) -> Result<CommunityV1Call, CommunityWireBlock> {
        guard id > 0, kind == "LIKE" || kind == "BOOKMARK" else { return .failure(.invalid) }
        // Like needs the cached post. Bookmark does not: the source only refuses an unknown like.
        if kind == "LIKE", !knownPost { return .failure(.refreshPost) }
        let requestID = ledger.id(for: "action:\(id):\(kind):\(enabled)", proposed: proposedID, mint: mint)
        if enabled {
            return .success(CommunityV1Call(method: "POST", path: "\(Self.base)/posts/\(id)/actions", body: .object([
                "actionType": .string(kind), "requestId": .string(requestID), "source": .string(Self.actionSource)
            ])))
        }
        return .success(CommunityV1Call(method: "DELETE", path: "\(Self.base)/posts/\(id)/actions/\(kind)", body: .object(["requestId": .string(requestID)])))
    }

    /// Legacy like accepts only `type == 1`. The enabled flag is the opposite of the known liked state.
    public mutating func like(id: Int, type: Int, viewerLiked: Bool?, proposedID: String?, mint: () -> String) -> Result<CommunityV1Call, CommunityWireBlock> {
        guard type == 1 else { return .failure(.unsupported) }
        guard let viewerLiked else { return .failure(.refreshPost) }
        return postAction(id: id, kind: "LIKE", enabled: !viewerLiked, knownPost: true, proposedID: proposedID, mint: mint)
    }

    public mutating func bookmark(id: Int, bookmark: Int, knownPost: Bool, proposedID: String?, mint: () -> String) -> Result<CommunityV1Call, CommunityWireBlock> {
        postAction(id: id, kind: "BOOKMARK", enabled: bookmark == 1, knownPost: knownPost, proposedID: proposedID, mint: mint)
    }

    public mutating func deletePost(id: Int, version: Int?, knownPost: Bool, proposedID: String?, mint: () -> String) -> Result<CommunityV1Call, CommunityWireBlock> {
        guard knownPost, let version, id > 0 else { return .failure(knownPost ? .invalid : .refreshPost) }
        let requestID = ledger.id(for: "delete:\(id):\(version)", proposed: proposedID, mint: mint)
        return .success(CommunityV1Call(method: "DELETE", path: "\(Self.base)/posts/\(id)", body: .object([
            "expectedVersion": .int(version), "requestId": .string(requestID)
        ])))
    }

    public mutating func likeComment(id: Int, viewerLiked: Bool?, proposedID: String?, mint: () -> String) -> Result<CommunityV1Call, CommunityWireBlock> {
        guard let viewerLiked, id > 0 else { return .failure(.refreshComment) }
        let enabled = !viewerLiked
        let requestID = ledger.id(for: "comment-like:\(id):\(enabled)", proposed: proposedID, mint: mint)
        let path = "\(Self.base)/comments/\(id)/actions" + (enabled ? "" : "/LIKE")
        return .success(CommunityV1Call(method: enabled ? "POST" : "DELETE", path: path, body: .object(["requestId": .string(requestID)])))
    }

    public mutating func deleteComment(postID: Int, commentID: Int, version: Int?, known: Bool, proposedID: String?, mint: () -> String) -> Result<CommunityV1Call, CommunityWireBlock> {
        guard known, let version, postID > 0, commentID > 0 else { return .failure(known ? .invalid : .refreshComment) }
        let requestID = ledger.id(for: "delete-comment:\(commentID):\(version)", proposed: proposedID, mint: mint)
        return .success(CommunityV1Call(method: "DELETE", path: "\(Self.base)/posts/\(postID)/comments/\(commentID)", body: .object([
            "expectedVersion": .int(version), "requestId": .string(requestID)
        ])))
    }

    public mutating func settle(key: String, requestID: String, code: Int?) {
        ledger.settle(key: key, requestID: requestID, code: code)
    }

    static func pageKey(favoriteOnly: Bool, mine: Bool, authorID: Int?) -> String {
        let author = authorID.flatMap { $0 > 0 ? String($0) : nil } ?? "LATEST"
        return "list:\(favoriteOnly ? "BOOKMARKS" : mine ? "OWN" : author)"
    }

    public func drafts(limit: Int = 100) -> CommunityV1Call {
        CommunityV1Call(method: "GET", path: "\(Self.base)/drafts", query: ["limit": String(limit)])
    }

    /// Activity, topic and route links. An unknown type is refused. Closed attachments are refused.
    /// The client request id is the caller's stable wire key; this method does not mint a replacement.
    public func publish(contents: String, dataType: Int?, dataID: Int?, clientRequestID: String, guidelineID: Int, editing: CommunityEditTarget?, closedAttachment: Bool) -> Result<CommunityV1Call, CommunityWireBlock> {
        if closedAttachment { return .failure(.attachmentClosed) }
        guard guidelineID > 0, !clientRequestID.isEmpty else { return .failure(.invalid) }
        let reference = CommunityLink.reference(dataType: dataType, dataID: dataID)
        if let dataID, dataID > 0, reference == nil { return .failure(.unsupportedLink) }
        var fields: [String: CommunityJSON] = [
            "clientRequestId": .string(clientRequestID),
            "body": .string(contents.trimmingCharacters(in: .whitespacesAndNewlines)),
            "postType": .string(reference?.postType ?? "MOMENT"),
            "audience": .string("PUBLIC"),
            "commentPolicy": .string("EVERYONE"),
            "guidelineVersionId": .int(guidelineID),
            "mediaIds": .array([]),
            "references": .array(reference.map { [.object(["referenceType": .string($0.type), "referenceId": .int($0.id)])] } ?? []),
            "locationPrecision": .string("NONE")
        ]
        let method: String
        let path: String
        if let editing {
            guard editing.id > 0 else { return .failure(.invalid) }
            fields["expectedVersion"] = .int(editing.expectedVersion)
            method = "PATCH"
            path = "\(Self.base)/posts/\(editing.id)"
        } else {
            method = "POST"
            path = "\(Self.base)/posts"
        }
        return .success(CommunityV1Call(method: method, path: path, body: .object(fields)))
    }

    public func publishDraft(id: Int, expectedVersion: Int, requestID: String) -> Result<CommunityV1Call, CommunityWireBlock> {
        guard id > 0, expectedVersion >= 0, !requestID.isEmpty else { return .failure(.invalid) }
        return .success(CommunityV1Call(method: "POST", path: "\(Self.base)/posts/\(id)/publish", body: .object([
            "expectedVersion": .int(expectedVersion), "requestId": .string(requestID)
        ])))
    }
}

public struct CommunityEditTarget: Equatable {
    public let id: Int
    public let expectedVersion: Int
    public init(id: Int, expectedVersion: Int) {
        self.id = id
        self.expectedVersion = expectedVersion
    }
}

public struct CommunityLink: Equatable {
    public let type: String
    public let id: Int
    public let postType: String

    /// `data_type` 1 activity, 2 topic, 3 route. Topic posts stay `MOMENT`.
    public static func reference(dataType: Int?, dataID: Int?) -> CommunityLink? {
        guard let dataID, dataID > 0, let dataType else { return nil }
        switch dataType {
        case 1: return CommunityLink(type: "ACTIVITY", id: dataID, postType: "ACTIVITY_RECAP")
        case 2: return CommunityLink(type: "TOPIC", id: dataID, postType: "MOMENT")
        case 3: return CommunityLink(type: "ROUTE", id: dataID, postType: "ROUTE_DISCOVERY")
        default: return nil
        }
    }
}

public struct CommunityDraftMatch: Equatable {
    public struct Item: Equatable {
        public let id: Int
        public let clientRequestID: String
        public init(id: Int, clientRequestID: String) {
            self.id = id
            self.clientRequestID = clientRequestID
        }
    }

    public enum Outcome: Equatable {
        case found(Int)
        case absent
        case ambiguous
        case unreadable
    }

    /// Unknown create recovery: the draft page must be complete (`hasMore === false`) and the wire key unique.
    public static func match(items: [Item]?, hasMore: Bool?, wireKey: String) -> Outcome {
        guard hasMore == false, let items else { return .unreadable }
        let hits = items.filter { $0.clientRequestID == wireKey }
        if hits.count > 1 { return .ambiguous }
        if let only = hits.first { return .found(only.id) }
        return .absent
    }
}

public struct CommunityPostProjection: Equatable {
    public enum LegacyStatus: Equatable { case published, unpublished, other(String) }

    public let id: String
    public let body: String
    public let following: Int?
    public let legacyStatus: LegacyStatus
    public let lifecycleLabel: String
    public let dataType: Int
    public let dataID: String?
    public let sportTopicID: String?
    public let pics: String

    /// `normalizePost`. `viewerFollowing` true/false becomes 1/0. Any other value is omitted.
    /// Activity links keep a positive topic projection as `sportTopicId`. The geohash is not copied.
    public static func normalize(postID: String, body: String, lifecycle: String, viewerFollowing: Bool?, mediaURLs: [String], referenceType: String?, referenceID: String?, topicProjection: String?) -> CommunityPostProjection? {
        guard !postID.isEmpty else { return nil }
        let labels = ["DRAFT": "草稿", "CHECKING": "审核中", "LIMITED": "展示受限", "HIDDEN": "已隐藏", "REMOVED": "已移除"]
        let status: LegacyStatus = lifecycle == "PUBLISHED" ? .published : (lifecycle == "DRAFT" || lifecycle == "CHECKING" ? .unpublished : .other(lifecycle))
        var dataType = 0
        var dataID: String?
        var sportTopic: String?
        if let referenceType, let referenceID, !referenceID.isEmpty {
            switch referenceType {
            case "ACTIVITY": dataType = 1
            case "TOPIC": dataType = 2
            case "ROUTE": dataType = 3
            default: dataType = 0
            }
            if dataType > 0 {
                dataID = referenceID
                if referenceType == "TOPIC" { sportTopic = referenceID }
                if referenceType == "ACTIVITY", let topic = IMSystemCardTarget.positiveID(topicProjection) { sportTopic = String(topic) }
            }
        }
        return CommunityPostProjection(
            id: postID,
            body: CommunityDisplayText.decode(body),
            following: viewerFollowing.map { $0 ? 1 : 0 },
            legacyStatus: status,
            lifecycleLabel: labels[lifecycle] ?? "",
            dataType: dataType,
            dataID: dataID,
            sportTopicID: sportTopic,
            pics: mediaURLs.filter { !$0.isEmpty }.joined(separator: ";")
        )
    }
}
