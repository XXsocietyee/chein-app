import Foundation

/// Stub-ledger row 21. Read-only: one signed-in `POST api/topic/info-to-user` through
/// `TopicService.detailDocument`, then verified road geometry from that same body.
/// No verified road hides the map. Stop names that are missing are an em dash.
@MainActor final class SquareRouteMapProvider: SquareRouteMapProviding {
    private let document: @MainActor (Int) async throws -> TopicDetailDocument

    init(document: @escaping @MainActor (Int) async throws -> TopicDetailDocument) {
        self.document = document
    }

    func route(topicID: Int) async throws -> CYSquareRoutePreview {
        guard topicID > 0 else { throw APIError.invalidRequest }
        let read = try await document(topicID)
        guard read.detail.id == topicID else { throw TopicReadFailure.unavailable }
        guard let route = SquareRouteMapVerified.project(detail: read.detail, body: read.body) else {
            return CYSquareRoutePreview(nodes: [], roadSegments: [])
        }
        var roadID = 0
        let segments = route.segments.map { segment in
            segment.map { point in
                roadID -= 1
                return CYSquareRoutePreview.Node(
                    id: roadID,
                    title: SquareRouteMapVerified.unknownTitle,
                    latitude: point.latitude,
                    longitude: point.longitude)
            }
        }
        return CYSquareRoutePreview(
            nodes: route.stops.map {
                CYSquareRoutePreview.Node(id: $0.id, title: $0.title, latitude: $0.latitude, longitude: $0.longitude)
            },
            roadSegments: segments)
    }
}
