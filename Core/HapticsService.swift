import Foundation

/// Low-level UIKit feedback generator styles mapped by `HapticsService`.
public enum HapticFeedbackStyle: String, Equatable, Sendable, CaseIterable {
    case selection
    case impactLight
    case impactMedium
    case impactHeavy
    case impactSoft
    case impactRigid
    case notificationSuccess
    case notificationWarning
    case notificationError
}

/// Canonical gameplay and UI tactile events mapped to `HapticFeedbackStyle`.
public enum HapticEvent: String, Equatable, Sendable, CaseIterable {
    // Core kit events (backed by CYHaptics)
    case selection
    case success
    case warning
    case error
    case impactLight
    case impactMedium
    case impactHeavy
    case impactRigid

    // Gameplay & progression events
    case checkInSuccess
    case wrongAnswer
    case diceRoll
    case diceLand
    case rewardOrMedal
    case medalCycle
    case claimSuccess
    case levelUp

    // Sensor challenges
    case sensorShakeHit
    case sensorShakeComplete
    case sensorQuietWarn
    case sensorQuietComplete
    case sensorStillComplete
    case sensorStillFailed
    case sensorCompassAlign
    case sensorCompassComplete
    case sensorShoutTick
    case sensorShoutComplete
    case sensorStepsProgress
    case sensorStepsComplete

    // Interactive mini-games
    case scratchRub
    case scratchReveal
    case jigsawSwap
    case jigsawSolved

    /// Generator + style specified in `docs/design/haptics-map.md`.
    public var style: HapticFeedbackStyle {
        switch self {
        case .selection, .medalCycle, .sensorCompassAlign, .jigsawSwap:
            return .selection
        case .success, .checkInSuccess, .rewardOrMedal, .claimSuccess, .levelUp,
             .sensorShakeComplete, .sensorQuietComplete, .sensorStillComplete,
             .sensorCompassComplete, .sensorShoutComplete, .sensorStepsComplete,
             .scratchReveal, .jigsawSolved:
            return .notificationSuccess
        case .warning, .sensorQuietWarn:
            return .notificationWarning
        case .error, .wrongAnswer, .sensorStillFailed:
            return .notificationError
        case .impactLight, .sensorStepsProgress:
            return .impactLight
        case .impactMedium, .diceRoll:
            return .impactMedium
        case .impactHeavy, .diceLand, .sensorShoutTick:
            return .impactHeavy
        case .impactRigid, .sensorShakeHit:
            return .impactRigid
        case .scratchRub:
            return .impactSoft
        }
    }

    /// Streaming/repetitive events share one continuous 120 ms throttle bucket so bursts never saturate the Taptic Engine,
    /// while terminal feedback (e.g. `diceLand` right after `diceRoll`) can still land crisply.
    public var isContinuous: Bool {
        switch self {
        case .selection, .impactLight, .impactMedium, .impactHeavy, .impactRigid,
             .diceRoll, .sensorShakeHit, .sensorQuietWarn, .sensorCompassAlign,
             .sensorShoutTick, .sensorStepsProgress, .scratchRub:
            return true
        default:
            return false
        }
    }
}

@MainActor public protocol HapticsFeedbackDriver: AnyObject {
    func prepare(_ style: HapticFeedbackStyle)
    func trigger(_ style: HapticFeedbackStyle)
}

@MainActor public protocol HapticsPreferenceReading: AnyObject {
    func isInAppHapticsEnabled() -> Bool
    func isSystemHapticsEnabled() -> Bool
}

@MainActor public final class DefaultHapticsPreferenceReader: HapticsPreferenceReading {
    private let defaults: UserDefaults
    private let systemHapticsCheck: () -> Bool

    public init(
        defaults: UserDefaults = .standard,
        systemHapticsCheck: @escaping () -> Bool = {
            !ProcessInfo.processInfo.arguments.contains("--uitesting-disable-haptics")
        }
    ) {
        self.defaults = defaults
        self.systemHapticsCheck = systemHapticsCheck
    }

    public func isInAppHapticsEnabled() -> Bool {
        guard let data = defaults.data(forKey: SettingsSoundPreferences.storageKey),
              let prefs = try? SettingsSoundPreferences.decodeStored(data) else {
            return SettingsSoundPreferences.defaults.haptics
        }
        return prefs.haptics
    }

    public func isSystemHapticsEnabled() -> Bool {
        systemHapticsCheck()
    }
}

@MainActor public final class NoopHapticsDriver: HapticsFeedbackDriver {
    public init() {}
    public func prepare(_ style: HapticFeedbackStyle) {}
    public func trigger(_ style: HapticFeedbackStyle) {}
}

/// Central haptics coordinator honoring system haptics policy, in-app `SettingsSoundPreferences.haptics`,
/// and a minimum 120 ms cooldown (`HapticFeedbackAndMotionReduceComplianceAudit`).
@MainActor public final class HapticsService {
    nonisolated public static let minimumCooldownSeconds: TimeInterval = 0.12
    public static let shared = HapticsService()

    private var driver: any HapticsFeedbackDriver
    private var preferences: any HapticsPreferenceReading
    private let clock: () -> TimeInterval
    private let minimumInterval: TimeInterval
    private var lastTriggerByBucket: [String: TimeInterval] = [:]

    public init(
        driver: (any HapticsFeedbackDriver)? = nil,
        preferences: (any HapticsPreferenceReading)? = nil,
        minimumInterval: TimeInterval = HapticsService.minimumCooldownSeconds,
        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.driver = driver ?? NoopHapticsDriver()
        self.preferences = preferences ?? DefaultHapticsPreferenceReader()
        self.minimumInterval = minimumInterval
        self.clock = clock
    }

    public func install(driver: any HapticsFeedbackDriver, preferences: (any HapticsPreferenceReading)? = nil) {
        self.driver = driver
        if let preferences {
            self.preferences = preferences
        }
    }

    public var isEnabled: Bool {
        preferences.isSystemHapticsEnabled() && preferences.isInAppHapticsEnabled()
    }

    public func prepare(_ event: HapticEvent) {
        guard isEnabled else { return }
        driver.prepare(event.style)
    }

    @discardableResult
    public func play(_ event: HapticEvent) -> Bool {
        guard isEnabled else { return false }
        let bucket = event.isContinuous ? "__continuous__" : event.rawValue
        let now = clock()
        if let previous = lastTriggerByBucket[bucket], now - previous < minimumInterval {
            return false
        }
        lastTriggerByBucket[bucket] = now
        driver.trigger(event.style)
        return true
    }

    public func resetThrottleHistory() {
        lastTriggerByBucket.removeAll()
    }
}
