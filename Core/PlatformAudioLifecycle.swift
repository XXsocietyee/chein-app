import Foundation

/// Platform-neutral reading of one OS audio lifecycle notification. The App layer maps
/// AVAudioSession/UIApplication notifications here so the decision table stays testable.
public enum PlatformAudioLifecycleSignal: Equatable, Sendable {
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case routeOldDeviceUnavailable
    case routeNewDeviceAvailable
    case routeCategoryChange
    case routeOther
    case mediaServicesReset
    case enteredBackground
    case unknown
}
public enum PlatformAudioLifecycleAction: Equatable, Sendable { case ignore, stop }
/// Calls, Siri, alarms, recording preemption, headphone unplug, media reset and backgrounding
/// all stop and release. Nothing here ever resumes: an interruption end (even with
/// `shouldResume`) is not a user intent, so only an explicit tap can start audio again.
public enum PlatformAudioLifecyclePolicy {
    /// `ownsConfiguration` is true while the shared session still carries this owner's own
    /// category, so its own setCategory echo or a newly attached output does not stop it.
    public static func action(for signal: PlatformAudioLifecycleSignal, ownsConfiguration: Bool) -> PlatformAudioLifecycleAction {
        switch signal {
        case .interruptionEnded: return .ignore
        case .routeCategoryChange, .routeNewDeviceAvailable: return ownsConfiguration ? .ignore : .stop
        case .interruptionBegan, .routeOldDeviceUnavailable, .routeOther, .mediaServicesReset, .enteredBackground, .unknown:
            return .stop
        }
    }
}

/// OWN-OPT-042.a: a call or alarm pauses only audio that was playing, and its end resumes only that audio
/// (`mp:pages/play/utils/audio-session.js:18-42`). A user pause cancels the pending resume. Going to the
/// background still stops and releases; nothing resumes on return from the background.
public struct PlatformAudioInterruptionResume: Equatable, Sendable {
    public enum Decision: Equatable, Sendable { case ignore, stop, pauseForInterruption, resume }
    public private(set) var interrupted = false
    public init() {}
    /// `playing` is nil when nothing is loaded yet (a download in flight), true while audible, false when paused.
    public mutating func decide(_ signal: PlatformAudioLifecycleSignal, playing: Bool?, ownsConfiguration: Bool) -> Decision {
        switch signal {
        case .interruptionBegan:
            guard let playing else { interrupted = false; return .stop }
            guard playing else { return .ignore } // Already paused by the player: nothing to resume later.
            interrupted = true
            return .pauseForInterruption
        case .interruptionEnded:
            guard interrupted else { return .ignore }
            interrupted = false
            return .resume
        default:
            let action = PlatformAudioLifecyclePolicy.action(for: signal, ownsConfiguration: ownsConfiguration)
            if action == .stop { interrupted = false; return .stop }
            return .ignore
        }
    }
    /// An explicit pause, resume or stop by the player always wins over a pending interruption resume.
    public mutating func userActed() { interrupted = false }
}
