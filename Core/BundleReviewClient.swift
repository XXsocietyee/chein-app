import Foundation

// MARK: - Bundle reviews client contract (IWP-8a; wires nothing)
// Backend EP-BND-20 (POST /review), EP-BND-22 (GET /review/list, GET /review/mine) do NOT exist yet
// (bundle-gap.md rows 20/22; bundle-backend-spec.md B-20/B-22). So this file ships ONLY:
//   * the wire models (shape taken from bundle-backend-spec.md B-20; every field the spec does not
//     guarantee is optional), and
//   * an injected protocol with an `unavailable` default that never returns data.
// There is deliberately no HTTP implementation and no canned response. The `mine` response shape
// (eligibility flag + reason code) is an ASSUMPTION of this WP, flagged in iwp-8a-report.md.

/// `POST /review` body: `{ registrationId, rating 1...5, content <= 500, idempotencyKey }`.
public struct BundleReviewCommand: Codable, Equatable {
    public static let maxContentLength = 500
    public static let ratingRange = 1...5
    public let registrationId: FreeExploreLaunchID
    public let rating: Int
    public let content: String
    public let idempotencyKey: String

    public init(registrationId: FreeExploreLaunchID, rating: Int, content: String, idempotencyKey: String) throws {
        self.registrationId = registrationId
        self.rating = rating
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.idempotencyKey = idempotencyKey
        try validate()
    }

    public func validate() throws {
        guard Self.ratingRange.contains(rating),
              !content.isEmpty, content.count <= Self.maxContentLength,
              (1...64).contains(idempotencyKey.utf8.count),
              idempotencyKey.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 })
        else { throw FreeExploreLaunchFailure.invalid }
    }
}

/// A review row. Status is a free string (`PENDING/APPROVED/REJECTED/HIDDEN` per spec); unknown values decode.
public struct BundleReview: Decodable, Equatable {
    public let id: FreeExploreLaunchID
    public let registrationId: FreeExploreLaunchID?
    public let holderMemberId: FreeExploreLaunchID?
    public let topicId: FreeExploreLaunchID?
    public let rating: Int
    public let content: String
    public let status: String
    public let idempotencyKey: String?
    public let createTime: String?

    public init(id: FreeExploreLaunchID, registrationId: FreeExploreLaunchID?, holderMemberId: FreeExploreLaunchID?,
                topicId: FreeExploreLaunchID?, rating: Int, content: String, status: String,
                idempotencyKey: String?, createTime: String?) {
        self.id = id; self.registrationId = registrationId; self.holderMemberId = holderMemberId
        self.topicId = topicId; self.rating = rating; self.content = content; self.status = status
        self.idempotencyKey = idempotencyKey; self.createTime = createTime
    }
}

/// `GET /review/mine?registrationId=`. ASSUMED shape: the server decides eligibility (holder, active order,
/// at least one REDEEMED unit, one review per order); the client never derives it.
public struct BundleReviewMine: Decodable, Equatable {
    public let eligible: Bool
    /// Server business/reason code when not eligible; shown verbatim to the model, never interpreted.
    public let reasonCode: String?
    public let review: BundleReview?

    public init(eligible: Bool, reasonCode: String?, review: BundleReview?) {
        self.eligible = eligible; self.reasonCode = reasonCode; self.review = review
    }
}

/// `GET /review/list?topicId=&cursor=&limit=`.
public struct BundleReviewPage: Decodable, Equatable {
    public let items: [BundleReview]
    public let nextCursor: String?

    public init(items: [BundleReview], nextCursor: String?) {
        self.items = items; self.nextCursor = nextCursor
    }
}

@MainActor public protocol BundleReviewServing: AnyObject {
    func mine(registrationID: FreeExploreLaunchID) async throws -> BundleReviewMine
    func list(topicID: FreeExploreLaunchID, cursor: String?, limit: Int) async throws -> BundleReviewPage
    /// Must throw `.outcomeUnknown` (never a plain failure) when the request may have reached the server.
    func submit(_ command: BundleReviewCommand) async throws -> BundleReview
}

/// Default until the backend ships EP-BND-20/22: every call is refused with `.disabled`. Never returns data.
@MainActor public final class UnavailableBundleReviewClient: BundleReviewServing {
    public init() {}
    public func mine(registrationID: FreeExploreLaunchID) async throws -> BundleReviewMine { throw FreeExploreLaunchFailure.disabled }
    public func list(topicID: FreeExploreLaunchID, cursor: String?, limit: Int) async throws -> BundleReviewPage { throw FreeExploreLaunchFailure.disabled }
    public func submit(_ command: BundleReviewCommand) async throws -> BundleReview { throw FreeExploreLaunchFailure.disabled }
}
