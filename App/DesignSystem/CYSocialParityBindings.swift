import SwiftUI
import CoreLocation

// Layout-side binding stubs for mini-program square pieces whose logic is not in Core yet.
// Every provider defaults to nil; a nil provider hides its entry (capability absent => hidden).
// Cursor owns the conformances: see docs/release/receipts/mp-mpsocial2.md.

/// Mini `square/utils/square-share.js`. Returns the public link for a post that is PUBLIC and published,
/// nil for everything else (the sheet then shows the generic card and no post content).
@MainActor protocol SquarePostShareLinkProviding: AnyObject {
    func shareURL(postID: Int) -> URL?
    /// Generic fallback (mini `/pages/talent/list/index?tab=feed`). Nil hides the share entry for private posts.
    var genericShareURL: URL? { get }
}

/// Mini `components/route-map`: topic chapter nodes, drawn only on verified road geometry.
@MainActor protocol SquareRouteMapProviding: AnyObject {
    func route(topicID: Int) async throws -> CYSquareRoutePreview
}

/// Mini `components/activity-picker`: `/api/play/my-completed?for_public_reference=true`.
@MainActor protocol SquareCompletedActivityProviding: AnyObject {
    func completedActivities() async throws -> [CYSquareCompletedActivity]
}

/// Mini `square/detail` `isFollowTheUser`, already decoded on `SquarePost`. Nil keeps the follow item hidden.
@MainActor protocol SquareAuthorFollowStateProviding: AnyObject {
    func isFollowing(memberID: Int) -> Bool?
}

struct CYSquareRoutePreview: Equatable {
    struct Node: Equatable, Identifiable {
        let id: Int
        let title: String
        let latitude: Double
        let longitude: Double
        var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    }
    let nodes: [Node]
    /// One verified road segment per chapter. Chapters are not joined.
    /// Empty, or any segment shorter than two points, means the map stays hidden.
    let roadSegments: [[Node]]
    var isRoad: Bool { !nodes.isEmpty && !roadSegments.isEmpty && roadSegments.allSatisfy { $0.count >= 2 } }
    var ready: Bool { isRoad }
}

struct CYSquareCompletedActivity: Equatable, Identifiable {
    let id: Int
    let name: String
    let cover: String?
    let doneCount: Int?
    let total: Int?
    let topicID: Int?
}

private struct SquareShareLinkKey: EnvironmentKey { static let defaultValue: (any SquarePostShareLinkProviding)? = nil }
private struct SquareRouteMapKey: EnvironmentKey { static let defaultValue: (any SquareRouteMapProviding)? = nil }
private struct SquareCompletedActivityKey: EnvironmentKey { static let defaultValue: (any SquareCompletedActivityProviding)? = nil }
private struct SquareAuthorFollowStateKey: EnvironmentKey { static let defaultValue: (any SquareAuthorFollowStateProviding)? = nil }
/// MP square/detail `david_npl_left`: the signed-in viewer's avatar (`app.getAvatar()`), bound to the account it belongs to.
struct SquareViewerAvatar: Equatable {
    let memberID: Int
    let avatar: String
}
private struct SquareViewerAvatarKey: EnvironmentKey { static let defaultValue: SquareViewerAvatar? = nil }

extension EnvironmentValues {
    var squareShareLink: (any SquarePostShareLinkProviding)? {
        get { self[SquareShareLinkKey.self] } set { self[SquareShareLinkKey.self] = newValue }
    }
    var squareRouteMap: (any SquareRouteMapProviding)? {
        get { self[SquareRouteMapKey.self] } set { self[SquareRouteMapKey.self] = newValue }
    }
    var squareCompletedActivities: (any SquareCompletedActivityProviding)? {
        get { self[SquareCompletedActivityKey.self] } set { self[SquareCompletedActivityKey.self] = newValue }
    }
    var squareAuthorFollowState: (any SquareAuthorFollowStateProviding)? {
        get { self[SquareAuthorFollowStateKey.self] } set { self[SquareAuthorFollowStateKey.self] = newValue }
    }
    var squareViewerAvatar: SquareViewerAvatar? {
        get { self[SquareViewerAvatarKey.self] } set { self[SquareViewerAvatarKey.self] = newValue }
    }
}
