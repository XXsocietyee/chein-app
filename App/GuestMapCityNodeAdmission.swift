import Foundation

/// Plan H-04b. A pure guest may GET `/api/city/nodes` and `/api/city/nodes/{id}` when the
/// deployment grants manual map, the market is China, and a manual area is already selected
/// (the route exists only then). Places, nearby, and every other map read stay signed in.
enum GuestMapCityNodeAdmission {
    static func allows(_ route: ManualMapReadRoute?, identity: CompositionHTTPTransport.SessionIdentity, market: RegionalMarket, grantsManualMap: Bool) -> Bool {
        guard grantsManualMap, market == .china, identity.accountID == nil, identity.role == nil, identity.token == nil, let route else { return false }
        switch route {
        case .cityNodes, .cityNode: return true
        case .places, .nearby: return false
        }
    }
}
