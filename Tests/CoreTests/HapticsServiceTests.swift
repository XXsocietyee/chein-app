import Foundation
import XCTest
@testable import QuestifyCore

@MainActor private final class RecordingHapticsDriver: HapticsFeedbackDriver {
    var prepared: [HapticFeedbackStyle] = []
    var triggered: [HapticFeedbackStyle] = []

    func prepare(_ style: HapticFeedbackStyle) { prepared.append(style) }
    func trigger(_ style: HapticFeedbackStyle) { triggered.append(style) }
}

@MainActor private final class StubHapticsPreferenceReader: HapticsPreferenceReading {
    var inAppEnabled: Bool
    var systemEnabled: Bool

    init(inAppEnabled: Bool = true, systemEnabled: Bool = true) {
        self.inAppEnabled = inAppEnabled
        self.systemEnabled = systemEnabled
    }

    func isInAppHapticsEnabled() -> Bool { inAppEnabled }
    func isSystemHapticsEnabled() -> Bool { systemEnabled }
}

@MainActor final class HapticsServiceTests: XCTestCase {
    func testEventStyleMappingMatchesHapticsMap() {
        XCTAssertEqual(HapticEvent.checkInSuccess.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.wrongAnswer.style, .notificationError)
        XCTAssertEqual(HapticEvent.diceRoll.style, .impactMedium)
        XCTAssertEqual(HapticEvent.diceLand.style, .impactHeavy)
        XCTAssertEqual(HapticEvent.rewardOrMedal.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.medalCycle.style, .selection)
        XCTAssertEqual(HapticEvent.claimSuccess.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.levelUp.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.sensorShakeHit.style, .impactRigid)
        XCTAssertEqual(HapticEvent.sensorShakeComplete.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.sensorQuietWarn.style, .notificationWarning)
        XCTAssertEqual(HapticEvent.sensorQuietComplete.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.sensorStillComplete.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.sensorStillFailed.style, .notificationError)
        XCTAssertEqual(HapticEvent.sensorCompassAlign.style, .selection)
        XCTAssertEqual(HapticEvent.sensorCompassComplete.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.sensorShoutTick.style, .impactHeavy)
        XCTAssertEqual(HapticEvent.sensorShoutComplete.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.sensorStepsProgress.style, .impactLight)
        XCTAssertEqual(HapticEvent.sensorStepsComplete.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.scratchRub.style, .impactSoft)
        XCTAssertEqual(HapticEvent.scratchReveal.style, .notificationSuccess)
        XCTAssertEqual(HapticEvent.jigsawSwap.style, .selection)
        XCTAssertEqual(HapticEvent.jigsawSolved.style, .notificationSuccess)
    }

    func testHonorsInAppAndSystemToggles() {
        let driver = RecordingHapticsDriver()
        let prefs = StubHapticsPreferenceReader(inAppEnabled: false, systemEnabled: true)
        let service = HapticsService(driver: driver, preferences: prefs, clock: { 10.0 })

        XCTAssertFalse(service.play(.checkInSuccess))
        XCTAssertTrue(driver.triggered.isEmpty)

        prefs.inAppEnabled = true
        prefs.systemEnabled = false
        XCTAssertFalse(service.play(.checkInSuccess))
        XCTAssertTrue(driver.triggered.isEmpty)

        prefs.systemEnabled = true
        XCTAssertTrue(service.play(.checkInSuccess))
        XCTAssertEqual(driver.triggered, [.notificationSuccess])
    }

    func testReadsStoredSettingsSoundPreferencesFromUserDefaults() throws {
        let suiteName = "HapticsServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let reader = DefaultHapticsPreferenceReader(defaults: defaults, systemHapticsCheck: { true })
        XCTAssertTrue(reader.isInAppHapticsEnabled())

        var disabled = SettingsSoundPreferences.defaults
        disabled.haptics = false
        defaults.set(try JSONEncoder().encode(disabled), forKey: SettingsSoundPreferences.storageKey)
        XCTAssertFalse(reader.isInAppHapticsEnabled())
    }

    func testMinimum120MsCooldownThrottlesContinuousBurstWithoutDroppingTerminalLand() {
        let driver = RecordingHapticsDriver()
        let prefs = StubHapticsPreferenceReader()
        var now: TimeInterval = 1.0
        let service = HapticsService(driver: driver, preferences: prefs, minimumInterval: 0.12, clock: { now })

        XCTAssertTrue(service.play(.diceRoll))
        now = 1.05
        XCTAssertFalse(service.play(.diceRoll))
        // Discrete terminal event still fires crisply right after a continuous tick.
        XCTAssertTrue(service.play(.diceLand))
        now = 1.13
        XCTAssertTrue(service.play(.diceRoll))

        XCTAssertEqual(driver.triggered, [.impactMedium, .impactHeavy, .impactMedium])
    }
}
