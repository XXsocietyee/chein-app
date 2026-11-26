import Foundation

/// Native r2 rollout switches. Each flow adds its own flag in an extension next to its files,
/// so the old screen can come back without a code change (`-<key> NO` launch argument or a
/// `UserDefaults` value of `false`).
enum NativeR2Flags {
    /// Default on. A stored or launch-argument `false` restores the screen the flow replaced.
    static func isEnabled(_ key: String, default value: Bool = true) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return value }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Free exploration (自由探索) native flow. `-nativeR2.freeExplore NO` restores the old screens.
    static var freeExplore: Bool { isEnabled("nativeR2.freeExplore") }
    /// Story route page, reader and in-place stage result.
    static var storyFlow: Bool { isEnabled("nativeR2.storyFlow") }
    /// Native game shell and the six kit templates (games A and B).
    static var games: Bool { isEnabled("nativeR2.games") }
}
