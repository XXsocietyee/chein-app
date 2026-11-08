import Foundation

/// One shelf row exactly as `GET /api/free-explore/bundle/shelf` (B-01) returns it.
/// Everything except the id is optional: the endpoint is not live yet and the shape comes from
/// `docs/owner-plan/bundle-backend-spec.md` only. `fromPrice` is a display string, never arithmetic input.
public struct BundleShelfItem: Decodable, Equatable {
    public let topicId: FreeExploreLaunchID
    public let topicName: String?
    public let coverUrl: String?
    public let chapterCount: Int?
    public let unitsPerHolder: Int?
    public let fromPrice: FreeExploreLaunchDecimal?
    public let validityDays: Int?
}

public struct BundleShelfPage: Decodable, Equatable {
    public let items: [BundleShelfItem]
    /// `nil` (or JSON null / absent) means this was the last page.
    public let nextCursor: String?
    public let saleEnabled: Bool?
    public let reservationEnabled: Bool?
}

public enum BundleShelfFailure: Error, Equatable {
    /// No backend shelf endpoint is wired. The UI shows nothing; it never invents cards.
    case unavailable
    case failed
}

/// Source of shelf pages. The real implementation is added by a later work package when B-01 exists.
@MainActor public protocol BundleShelfClient: AnyObject {
    func page(cursor: String?, limit: Int) async throws -> BundleShelfPage
}

/// Default client: always unavailable, never returns data.
@MainActor public final class UnavailableBundleShelfClient: BundleShelfClient {
    public init() {}
    public func page(cursor: String?, limit: Int) async throws -> BundleShelfPage {
        throw BundleShelfFailure.unavailable
    }
}
