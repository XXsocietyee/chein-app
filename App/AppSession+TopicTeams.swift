import Foundation

extension AppSession {
    /// RTEAMS-1 (MP topic `_loadTeams`): `GET /api/team/nearby` around a topic stop, 20 km, signed in only.
    /// nil = not signed in, not configured or the read failed (the topic hides its 组队 block).
    func topicNearbyTeams(latitude: Double, longitude: Double) async -> [NearbyTeam]? {
        let reader = makeNearbyTeamCoordinator()
        reader.bind(nearbyTeamSession)
        guard reader.configured, reader.authenticated else { return nil }
        let query = NearbyQueryContext(latitude: latitude, longitude: longitude, radius: 20000)
        guard query.valid else { return nil }
        await reader.loadNearby(query)
        return reader.messageKey == nil ? reader.teams : nil
    }
}
