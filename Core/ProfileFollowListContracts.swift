import Foundation

public enum ProfileFollowListKind: String, CaseIterable, Codable, Hashable {
    case following, followers
}
/// Only the server's public list projection. No contact, balance, birthday or friendship fields.
public struct ProfileFollowListMember: Decodable, Equatable, Identifiable {
    public let id: Int
    public let nickname: String?
    public let avatar: String?
    public let isFollow: Bool
}
public struct ProfileFollowListPage: Decodable, Equatable {
    public let ownerID: Int
    public let kind: ProfileFollowListKind
    public let rows: [ProfileFollowListMember]
    public let hasMore: Bool
    public let nextCursor: Int?
    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id", kind, rows, hasMore = "has_more", nextCursor = "next_cursor"
    }
    public func validate(owner: Int, kind: ProfileFollowListKind, cursor: Int, limit: Int = 50) throws {
        guard ownerID == owner, self.kind == kind, owner > 0, cursor >= 0, (1...50).contains(limit),
              rows.count <= limit, hasMore ? rows.count == limit && nextCursor == rows.last?.id : nextCursor == nil else {
            throw APIError.malformedResponse
        }
        var previous = cursor
        for row in rows {
            guard row.id > previous, row.id != owner, kind != .following || row.isFollow else { throw APIError.malformedResponse }
            previous = row.id
        }
    }
}
public struct ProfileFollowListSelection: Hashable, Identifiable {
    public let id = UUID()
    public let memberID: Int
    public let scope: UUID
}
@MainActor public protocol ProfileFollowListReading: SocialAccountReading {
    var scope: UUID { get }
    var isCurrent: Bool { get }
    func page(kind: ProfileFollowListKind, cursor: Int) async throws -> ProfileFollowListPage
    func makePublicProfileReader(memberID: Int, isCurrent: @escaping () -> Bool) -> ProfilePublicInfoReader?
}
