import Foundation

/// Production U08-02 read. Rows come from `POST api/activity/list` through the play read capability.
/// A transport refusal or an empty page yields no card.
public final class ProductionPlayFinishRouteReader: PlayFinishRouteReading {
    private let service: PlayExperienceService
    private let token: @MainActor () -> String?
    public init(service: PlayExperienceService, token: @escaping @MainActor () -> String?) {
        self.service = service
        self.token = token
    }
    public func rows(origin: PlayFinishOrigin) async throws -> [PlayFinishRouteRow] {
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else { throw APIError.unauthorized }
        return try await service.finishRouteRows(origin: origin, token: token)
    }
}
