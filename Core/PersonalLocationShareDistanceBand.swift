import Foundation

/// Client-derived, banded distance. Only computed from fixes the receiver is already entitled to show,
/// and the exact distance never leaves this function: the output carries a band, nothing finer.
/// Band edges are `MapDistanceBand`'s display candidates, pending review; they are not approved policy.
public struct PersonalLocationShareBandedDistance: Equatable, Sendable {
    public let grantId: String
    public let band: MapDistanceBand
    public let stale: Bool
}

public enum PersonalLocationShareDistanceBanding {
    private static let earthRadiusMeters = 6_371_008.8
    public static func band(observerLatitude: Double, observerLongitude: Double, latitude: Double, longitude: Double) -> MapDistanceBand? {
        meters(observerLatitude, observerLongitude, latitude, longitude).flatMap { MapDistanceBand.band(meters: $0) }
    }
    /// Internal only: raw metres never cross the module's public presentation surface.
    static func meters(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double? {
        guard isValid(lat1, lon1), isValid(lat2, lon2) else { return nil }
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dp = p2 - p1, dl = (lon2 - lon1) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(a)))
    }
    static func isValid(_ latitude: Double, _ longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
    /// Sorted by band, then grant id. Never by the hidden exact distance.
    public static func present(_ visible: [PersonalLocationShareReceiverProjection.Visible], observerLatitude: Double,
                               observerLongitude: Double, uptime: TimeInterval) -> [PersonalLocationShareBandedDistance] {
        guard isValid(observerLatitude, observerLongitude) else { return [] }
        let order = MapDistanceBand.allCases
        return visible.compactMap { item -> PersonalLocationShareBandedDistance? in
            guard uptime < item.deadlineUptime,
                  let band = band(observerLatitude: observerLatitude, observerLongitude: observerLongitude,
                                  latitude: item.observation.latitude, longitude: item.observation.longitude) else { return nil }
            return .init(grantId: item.grant.grantId, band: band, stale: item.isStale(at: uptime))
        }.sorted {
            let l = order.firstIndex(of: $0.band) ?? 0, r = order.firstIndex(of: $1.band) ?? 0
            return l != r ? l < r : $0.grantId < $1.grantId
        }
    }
}
