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
}
