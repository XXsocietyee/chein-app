import Foundation

/// Which location card to show before the system prompt (roam-fog-engine §1d: priming first, denied card with Open Settings).
/// Pure decision; it never asks for permission itself.
public enum RoamLocationPrimerStep: Equatable {
    /// Explain first, once, on the first GO while the OS has not been asked.
    case priming
    /// The OS answered "no": explain and offer Open Settings.
    case denied

    /// nil = show no card: either go straight to the OS prompt (card already seen) or location is already authorized.
    public static func resolve(authorization: WalkingLocationAuthorization, primerSeen: Bool) -> Self? {
        switch authorization {
        case .notDetermined: return primerSeen ? nil : .priming
        case .denied: return .denied
        case .authorized: return nil
        }
    }

    /// True only when the caller may now trigger the system prompt.
    public static func mayRequestSystemPrompt(authorization: WalkingLocationAuthorization, primerSeen: Bool) -> Bool {
        authorization == .notDetermined && primerSeen
    }
}
