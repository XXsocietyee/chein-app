import Foundation

/// Reviewed production-host lease for the player journey reads and the public catalog.
/// Minted only by `ReviewedProductionGateLeases` for the shipped China composition.
/// Affiliate, city-pass purchase and referral-token issue are not in the grant.
public struct PWaveProductionReadLease: Equatable, Sendable {
    public let host: String

    public static let grantedFeatures: Set<PWaveFeature> = [
        .battleReport, .inviteLanding, .playMode, .ticketSeats, .themeCollection, .runMemory, .memberBoard
    ]

    /// Anonymous catalog posts the owner named. Map and ids stay off.
    public static let catalogPaths: Set<PWaveCatalogPath> = [.cityList, .list, .filters, .info]

    public init(host: String) {
        self.host = host.lowercased()
    }
}

/// Same host lease for `JourneyLoopSource`. Referral-token issue stays refused.
/// fix-r10 MKT-3-1b: gift claim left the refused set (MP `market/gift/index.js:101-123` sends only the
/// gift token; not money). The production route is admitted by `ChinaReviewedRouteCapability.memberGiftClaimOwnerGrant`.
/// The affiliate summary GET is the one read this lease sends.
public struct JourneyProductionLease: Equatable, Sendable {
    public let host: String

    public static let refused: Set<JourneyLoopSource.Journey> = [.issueReferral]

    public init(host: String) {
        self.host = host.lowercased()
    }
}
