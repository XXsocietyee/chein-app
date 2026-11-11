import Foundation

/// App-level typed destination. Strangler for the per-screen `*Destination` types: new routes are one case here.
/// Codable so a later step can persist a back-stack; ids are positive server ids and never inferred.
public enum AppRoute: Hashable, Codable, Sendable {
    case activity(Int)
    case topic(Int)
    case club(Int)
    case template(Int)
    case post(Int)
    case poi(Int)
    case roamSession(Int)
    /// A mini-program path the native app does not route yet. Carries the bare path; never presented as a screen.
    case unsupported(String)

    public static func activityID(_ id: Int) -> AppRoute? { id > 0 ? .activity(id) : nil }
    public static func topicID(_ id: Int) -> AppRoute? { id > 0 ? .topic(id) : nil }
    public static func clubID(_ id: Int) -> AppRoute? { id > 0 ? .club(id) : nil }
    public static func templateID(_ id: Int) -> AppRoute? { id > 0 ? .template(id) : nil }
    public static func postID(_ id: Int) -> AppRoute? { id > 0 ? .post(id) : nil }
    public static func poiID(_ id: Int) -> AppRoute? { id > 0 ? .poi(id) : nil }
    public static func roamSessionID(_ id: Int) -> AppRoute? { id > 0 ? .roamSession(id) : nil }

    /// Resolves a mini-program path (leading slash and query allowed) plus its `id` through the generated page table.
    public init(miniProgramPath path: String, id: Int? = nil) {
        if let page = MiniProgramPage(path: path) { self = page.route(id: id) }
        else { self = .unsupported(path) }
    }

    public init(_ destination: HomeFeedDestination) {
        switch destination {
        case .activity(let id): self = .activity(id)
        case .topic(let id): self = .topic(id)
        }
    }

    /// The Home feed's own destination for this route, if it has one.
    public var homeFeedDestination: HomeFeedDestination? {
        switch self {
        case .activity(let id): return .activity(id)
        case .topic(let id): return .topic(id)
        default: return nil
        }
    }
}
