import Foundation

public struct SquareReadSession: Equatable {
    public let accountID: Int
    public let epoch: UInt64
    fileprivate let token: String
    public init(accountID: Int, epoch: UInt64, token: String) throws {
        guard accountID > 0, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        self.accountID = accountID; self.epoch = epoch; self.token = token
    }
}
@MainActor public protocol SquareReading: AnyObject {
    var isConfigured: Bool { get }
    var isOfflineExample: Bool { get }
    var isSignedIn: Bool { get }
    var scope: UUID { get }
    func squareFeed(query: SquareQuery, cursor: SquareCursor?) async throws -> SquareFeedPage
    func squareDetail(id: Int) async throws -> SquarePost
    func squareComments(postID: Int, pageNumber: Int) async throws -> SquareCommentPage
    func squareDetail(route: SquareContentRoute) async throws -> SquarePost
    func squareComments(route: SquareContentRoute, pageNumber: Int) async throws -> SquareCommentPage
    func ownCreativeSquareIDs() async throws -> [Int]
    func deleteOwnCreativeSquare(postID: Int) async throws -> [Int]
    func deleteOwnLegacyComment(commentID: Int) async throws
}
public extension SquareReading {
    func squareDetail(route: SquareContentRoute) async throws -> SquarePost {
        guard route.valid else { throw APIError.invalidRequest }
        let value = try await squareDetail(id: route.id)
        guard value.generation == route.generation else { throw APIError.invalidRequest }; return value
    }
    func squareComments(route: SquareContentRoute, pageNumber: Int) async throws -> SquareCommentPage {
        guard route.valid else { throw APIError.invalidRequest }
        let value = try await squareComments(postID: route.id, pageNumber: pageNumber)
        guard value.items.allSatisfy({ $0.generation == route.generation }) else { throw APIError.invalidRequest }; return value
    }
    func ownCreativeSquareIDs() async throws -> [Int] { throw APIError.notConfigured }
    func deleteOwnCreativeSquare(postID: Int) async throws -> [Int] { throw APIError.notConfigured }
    func deleteOwnLegacyComment(commentID: Int) async throws { throw APIError.notConfigured }
}
public struct SquareCommunityFeatures: Equatable {
    public let read: Bool
    public let write: Bool
    public init(read: Bool, write: Bool) { self.read = read; self.write = write }
}
/// Owner-bound community gate (source `canUseCommunity`). Results belong to the reader scope that produced them.
@MainActor public protocol SquareCommunityFeatureReading: AnyObject {
    var scope: UUID { get }
    func communityFeatures() async throws -> SquareCommunityFeatures
}
@MainActor public final class SquareSessionReader: SquareReading, SquareCommunityFeatureReading {
    private let service: SquareService?
    private let currentSession: () -> SquareReadSession?
    private let onUnauthorized: (SquareReadSession) -> Void
    private var snapshot: SquareReadSession?
    private var stamp = UUID()
    public var isConfigured: Bool { service != nil }
    public var isOfflineExample: Bool { false }
    public var isSignedIn: Bool { currentSession() != nil }
    public var scope: UUID {
        let current = currentSession()
        if current != snapshot { snapshot = current; stamp = UUID() }
        return stamp
    }
    public init(service: SquareService?, currentSession: @escaping () -> SquareReadSession?, onUnauthorized: @escaping (SquareReadSession) -> Void = { _ in }) {
        self.service = service; self.currentSession = currentSession; self.onUnauthorized = onUnauthorized
        snapshot = currentSession()
    }
    public func squareFeed(query: SquareQuery, cursor: SquareCursor?) async throws -> SquareFeedPage {
        try await read { try await $0.feed(query: query, cursor: cursor, token: $1) }
    }
    /// Relation feed lane: GET `api/v1/community/feeds/LATEST` with `limit=20`, the rewrite of
    /// `/api/creativesquare/list` when `is_my` is 0.
    public func relationCreativeSquare(cursor: Int?) async throws -> SquareFeedPage {
        let feedCursor = cursor.map { SquareCursor(id: $0) }
        return try await read { try await $0.feed(query: .init(mode: .latest), cursor: feedCursor, token: $1, limit: 20) }
    }
    public func squareDetail(id: Int) async throws -> SquarePost {
        try await read { try await $0.detail(id: id, token: $1) }
    }
    public func squareDetailBody(id: Int) async throws -> Data {
        try await read { try await $0.detailBody(id: id, token: $1) }
    }
    public func squareCommentsBody(postID: Int, pageNumber: Int) async throws -> Data {
        try await read { try await $0.commentsBody(postID: postID, pageNumber: pageNumber, token: $1) }
    }
    public func aigcFilingNumber() async throws -> String? {
        try await read { try await $0.aigcFilingNumber(token: $1) }
    }
    public func communityFeatures() async throws -> SquareCommunityFeatures {
        try await read { try await $0.communityFeatures(token: $1) }
    }
    public func squareComments(postID: Int, pageNumber: Int) async throws -> SquareCommentPage {
        try await read { try await $0.comments(postID: postID, pageNumber: pageNumber, token: $1) }
    }
    public func squareDetail(route: SquareContentRoute) async throws -> SquarePost {
        try await read { try await $0.detail(route: route, token: $1) }
    }
    public func squareComments(route: SquareContentRoute, pageNumber: Int) async throws -> SquareCommentPage {
        try await read { try await $0.comments(route: route, pageNumber: pageNumber, token: $1) }
    }
    public func ownCreativeSquareIDs() async throws -> [Int] {
        try await read { service, token in
            guard let token else { throw APIError.unauthorized }
            return try await service.ownCreativeSquareIDs(token: token)
        }
    }
    public func deleteOwnCreativeSquare(postID: Int) async throws -> [Int] {
        guard let author = currentSession()?.accountID else { throw APIError.unauthorized }
        return try await read { service, token in
            guard let token, self.currentSession()?.accountID == author else { throw APIError.unauthorized }
            return try await service.deleteOwnCreativeSquare(postID: postID, authorMemberID: author, viewerMemberID: author, token: token)
        }
    }
    public func deleteOwnLegacyComment(commentID: Int) async throws {
        guard let author = currentSession()?.accountID else { throw APIError.unauthorized }
        try await read { (service: SquareService, token: String?) -> Void in
            guard let token, self.currentSession()?.accountID == author else { throw APIError.unauthorized }
            try await service.deleteOwnLegacyComment(commentID: commentID, token: token)
        }
    }
    private func read<T>(_ operation: (SquareService, String?) async throws -> T) async throws -> T {
        guard let service else { throw APIError.notConfigured }
        let session = currentSession(), startedScope = scope
        try Task.checkCancellation()
        do {
            let value = try await operation(service, session?.token)
            try Task.checkCancellation()
            guard currentSession() == session, scope == startedScope else { throw CancellationError() }
            return value
        } catch {
            guard !Task.isCancelled, currentSession() == session, scope == startedScope else { throw CancellationError() }
            if error as? APIError == .unauthorized, let session { onUnauthorized(session) }
            throw error
        }
    }
}
public struct SquareFeedPagination {
    public private(set) var items: [SquarePost] = []
    public private(set) var nextCursor: SquareCursor?
    public private(set) var hasMore = true
    public private(set) var continuationInvalid = false
    private var seenCursors = Set<SquareCursor>()
    public private(set) var hasLoadedPage = false
    public init() {}
    public mutating func accept(_ page: SquareFeedPage, requestedCursor: SquareCursor?) throws {
        guard requestedCursor == nextCursor, (!hasLoadedPage || requestedCursor != nil), hasMore else { throw APIError.invalidRequest }
        hasLoadedPage = true
        var ids = Set(items.map(\.id))
        items += page.items.filter { ids.insert($0.id).inserted }
        if let requestedCursor { seenCursors.insert(requestedCursor) }
        continuationInvalid = page.hasMore && (page.nextCursor == nil || (page.nextCursor?.id ?? 0) <= 0 || page.nextCursor.map { seenCursors.contains($0) } == true)
        hasMore = page.hasMore && !continuationInvalid
        nextCursor = hasMore ? page.nextCursor : nil
    }
}
public struct SquareCommentPagination {
    public private(set) var items: [SquareComment] = []
    public private(set) var nextPage = 1
    public private(set) var hasMore = true
    public init() {}
    public mutating func accept(_ page: SquareCommentPage) throws {
        guard hasMore, page.pageNumber == nextPage, page.pageSize > 0 else { throw APIError.invalidRequest }
        var ids = Set(items.map(\.id))
        items += page.items.filter { ids.insert($0.id).inserted }
        hasMore = page.hasMore && nextPage < Int.max
        if nextPage < Int.max { nextPage += 1 }
    }
}
