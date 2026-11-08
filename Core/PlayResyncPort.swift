import Foundation

/// Port of `pages/play` "重新同步本局状态" / "重试同步本局状态": when a loaded run shows a read-side
/// problem, the player may re-read the authoritative state. This only re-runs the existing
/// `PlayExperienceCoordinator.load()` (which already reconciles any pending completion); it never
/// resubmits a completion and offers nothing for server rejections (their message is shown as-is).
public enum PlayResyncPort {
    public static func offersResync(for issue: PlayExperienceError?) -> Bool {
        guard let issue else { return false }
        switch issue {
        case .staleSession, .malformed, .unknownResult, .persistenceUnavailable: return true
        case .disabled, .busy, .invalidAction, .unsupported, .rejected, .unauthorized: return false
        }
    }
}
