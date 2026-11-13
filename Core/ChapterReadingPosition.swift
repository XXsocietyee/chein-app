import Foundation

/// U04-04 reading resume (mini-program `story-resume.js` `pos`). Where the reader was in a
/// chapter, per account + namespace + run scope + content identity + chapter. It stores a
/// segment id only (no text), is never sent anywhere and is not progress: arrival, completion
/// and rewards stay server facts. A missing identity stores and reads nothing.
public struct ChapterReadingPositionStore {
    static let prefix = "cy.chapterRead.v1:"
    static let limit = 40
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// `runIdentity` is `PlayExperienceCoordinator.identity`; `contentVersion` nil (unknown) does not store.
    public static func key(runIdentity: String?, contentVersion: String?, chapterID: Int) -> String? {
        guard let runIdentity, !runIdentity.isEmpty, let contentVersion, !contentVersion.isEmpty, chapterID > 0 else { return nil }
        return prefix + runIdentity + "|" + contentVersion + "|" + String(chapterID)
    }
    public func read(_ key: String?) -> String? {
        guard let key else { return nil }
        return defaults.string(forKey: key)
    }
    public func save(_ segmentID: String, key: String?) {
        guard let key, !segmentID.isEmpty, segmentID.utf8.count <= 128, read(key) != segmentID else { return }
        defaults.set(segmentID, forKey: key)
        var order = defaults.stringArray(forKey: Self.prefix + "order") ?? []
        order.removeAll { $0 == key }; order.append(key)
        // Bounded: the oldest chapters drop first.
        while order.count > Self.limit { defaults.removeObject(forKey: order.removeFirst()) }
        defaults.set(order, forKey: Self.prefix + "order")
    }
    /// Segment to scroll back to: only one still rendered, and never the very first (stay at the top).
    public static func resumeTarget(saved: String?, rendered: [String]) -> String? {
        guard let saved, let index = rendered.firstIndex(of: saved), index > 0 else { return nil }
        return saved
    }
}
