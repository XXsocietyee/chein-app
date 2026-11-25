import Foundation

/// Page-ready facts for `pages/coop/nearby/index` over the existing consented nearby search
/// (`NearbyMerchantCoordinator`, `NearbyMerchantRow`). Presentation only: it starts no search,
/// asks for no location and builds no request. The page total is an em dash while the read is
/// missing, "0" only after a loaded read returned no usable row, and a literal distance of 0
/// stays "0 m". A missing distance draws no distance line. The count is never prefixed onto it.
@available(macOS 14.0, *)
public enum NearbyMerchantPage {
    public static let unknownMark = "\u{2014}"
    public static let distanceSuffix = "m"

    /// Source `pages/coop/nearby` states. Location and permission refusals keep their own recoverable state.
    public enum Phase: Equatable {
        /// Nothing was searched. Opening is inert.
        case idle
        case consentRequired
        case unavailable
        case loading
        case locationFailed
        case locationDenied
        case permissionDenied
        case error
        case empty
        case ready
    }

    public struct Card: Equatable, Identifiable {
        public let id: Int
        public let name: String
        public let address: String?
        /// `350 m`; nil when the server sent no usable distance.
        public let distanceText: String?
        public let callablePhone: String?
        /// Only a registered merchant with a member id opens its public home.
        public let opensPublicHome: Bool
    }

    public struct Resolution: Equatable {
        public let phase: Phase
        public let totalText: String
        public let cards: [Card]
    }

    public static func distanceText(_ meters: Double?) -> String? {
        guard let meters, meters.isFinite, meters >= 0 else { return nil }
        return String(format: "%.0f", meters) + " " + distanceSuffix
    }

    /// The total is "0" only for a loaded, empty result. Every other phase has no number to show.
    public static func totalText(phase: Phase, count: Int) -> String {
        switch phase {
        case .ready: return String(count)
        case .empty: return "0"
        default: return unknownMark
        }
    }

    public static func resolve(phase: NearbyMerchantCoordinator.Phase, rows: [NearbyMerchantRow]) -> Resolution {
        let mapped = mappedPhase(phase, rowCount: rows.count)
        // A failed refresh keeps the previous cards. Idle, consent, and permission states still hide them.
        let retained = (phase == .failed || phase == .locationFailed) && !rows.isEmpty
        let shown = mapped == .ready || retained
        let cards = shown ? rows.map(card) : []
        let display: Phase = retained ? .ready : mapped
        return Resolution(phase: display, totalText: totalText(phase: display, count: cards.count), cards: cards)
    }

    static func mappedPhase(_ phase: NearbyMerchantCoordinator.Phase, rowCount: Int) -> Phase {
        switch phase {
        case .idle: return .idle
        case .unavailable: return .unavailable
        case .consentRequired: return .consentRequired
        case .locating, .loading: return .loading
        case .locationFailed: return .locationFailed
        case .locationDenied: return .locationDenied
        case .permissionDenied: return .permissionDenied
        case .failed: return .error
        case .ready: return rowCount == 0 ? .empty : .ready
        }
    }

    static func card(_ row: NearbyMerchantRow) -> Card {
        Card(id: row.id, name: row.name, address: row.address, distanceText: distanceText(row.distance),
             callablePhone: row.callablePhone, opensPublicHome: row.memberID != nil)
    }
}
