import XCTest
@testable import Questify

@MainActor final class IMInviteReminderControllerTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!
    private var permission: IMInviteReminderPermissionFake!
    private var primer: IMInviteReminderPrimerFake!

    override func setUp() async throws {
        suite = "im-invite-reminder-" + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        permission = IMInviteReminderPermissionFake()
        primer = IMInviteReminderPrimerFake()
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func testUnknownMarkIsAnEmDash() {
        XCTAssertEqual(IMInviteReminderPresentation.unknownMark, "\u{2014}")
        XCTAssertNotEqual(IMInviteReminderPresentation.unknownMark, "-")
        XCTAssertNotEqual(IMInviteReminderPresentation.unknownMark, "0")
    }

    func testReloadKeepsUnknownPermissionAsUnknownAndOff() async {
        defaults.set(true, forKey: IMInviteReminderController.storageKey)
        permission.currentValue = .unknown
        let controller = make()
        await controller.reload()
        XCTAssertEqual(controller.presentation, .unknown)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(controller.presentation == .unknown ? IMInviteReminderPresentation.unknownMark : "", "\u{2014}")
    }

    func testStoredChoiceWithVisibleAlertsTurnsOn() async {
        defaults.set(true, forKey: IMInviteReminderController.storageKey)
        permission.currentValue = .authorized(alerts: true)
        let controller = make()
        await controller.reload()
        XCTAssertEqual(controller.presentation, .on)
        XCTAssertTrue(controller.isEnabled)
    }

    func testStoredChoiceWithoutAlertsStaysOff() async {
        defaults.set(true, forKey: IMInviteReminderController.storageKey)
        let controller = make()
        for value in [IMInviteReminderPermission.authorized(alerts: false), .denied, .provisional, .ephemeral, .notDetermined] {
            permission.currentValue = value
            await controller.reload()
            XCTAssertEqual(controller.presentation, .off, "\(value)")
            XCTAssertFalse(controller.isEnabled)
        }
    }

    func testDeniedPrimerStaysOffAndDoesNotRequest() async {
        permission.currentValue = .notDetermined
        primer.outcome = .denied
        let controller = make()
        let enabled = await controller.setEnabled(true)
        XCTAssertFalse(enabled)
        XCTAssertEqual(controller.presentation, .off)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(primer.calls, 1)
        XCTAssertEqual(permission.requestCount, 0)
        XCTAssertFalse(controller.offersSettings)
        XCTAssertFalse(defaults.bool(forKey: IMInviteReminderController.storageKey))
    }

    func testUnavailablePrimerStaysOffAndDoesNotClaimAGrant() async {
        permission.currentValue = .notDetermined
        permission.requestValue = .authorized(alerts: true)
        primer.outcome = .unavailable
        let controller = make()
        let enabled = await controller.setEnabled(true)
        XCTAssertFalse(enabled)
        XCTAssertEqual(controller.presentation, .off)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(permission.requestCount, 0)
        XCTAssertFalse(defaults.bool(forKey: IMInviteReminderController.storageKey))
    }

    func testAllowedPrimerAndVisibleAlertsTurnsOn() async {
        permission.currentValue = .notDetermined
        permission.requestValue = .authorized(alerts: true)
        primer.outcome = .allowed
        let controller = make()
        let enabled = await controller.setEnabled(true)
        XCTAssertTrue(enabled)
        XCTAssertEqual(controller.presentation, .on)
        XCTAssertEqual(permission.requestCount, 1)
        XCTAssertTrue(defaults.bool(forKey: IMInviteReminderController.storageKey))
    }

    func testAllowedPrimerWithSystemDenialStaysOff() async {
        permission.currentValue = .notDetermined
        permission.requestValue = .denied
        primer.outcome = .allowed
        let controller = make()
        let result = await controller.setEnabled(true)
        XCTAssertFalse(result)
        XCTAssertEqual(controller.presentation, .off)
        XCTAssertTrue(controller.offersSettings)
        XCTAssertFalse(defaults.bool(forKey: IMInviteReminderController.storageKey))
    }

    func testUnreadablePermissionAfterThePrimerStaysUnknown() async {
        permission.currentValue = .notDetermined
        permission.requestValue = .unknown
        primer.outcome = .allowed
        let controller = make()
        let result = await controller.setEnabled(true)
        XCTAssertFalse(result)
        XCTAssertEqual(controller.presentation, .unknown)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: IMInviteReminderController.storageKey))
    }

    func testUnreadableCurrentPermissionDoesNotPromptOrGrant() async {
        permission.currentValue = .unknown
        primer.outcome = .allowed
        permission.requestValue = .authorized(alerts: true)
        let controller = make()
        let result = await controller.setEnabled(true)
        XCTAssertFalse(result)
        XCTAssertEqual(controller.presentation, .unknown)
        XCTAssertEqual(primer.calls, 0)
        XCTAssertEqual(permission.requestCount, 0)
        XCTAssertFalse(defaults.bool(forKey: IMInviteReminderController.storageKey))
    }

    func testAlreadyDeniedDoesNotShowThePrimer() async {
        permission.currentValue = .denied
        primer.outcome = .allowed
        let controller = make()
        let result = await controller.setEnabled(true)
        XCTAssertFalse(result)
        XCTAssertEqual(controller.presentation, .off)
        XCTAssertTrue(controller.offersSettings)
        XCTAssertEqual(primer.calls, 0)
        XCTAssertEqual(permission.requestCount, 0)
    }

    func testExistingVisibleGrantStoresTheLocalChoiceWithoutASecondPrompt() async {
        permission.currentValue = .authorized(alerts: true)
        let controller = make()
        let result = await controller.setEnabled(true)
        XCTAssertTrue(result)
        XCTAssertEqual(controller.presentation, .on)
        XCTAssertEqual(primer.calls, 0)
        XCTAssertEqual(permission.requestCount, 0)
        XCTAssertTrue(defaults.bool(forKey: IMInviteReminderController.storageKey))
    }

    func testTurningOffClearsTheLocalChoiceWithoutClaimingAGrant() async {
        defaults.set(true, forKey: IMInviteReminderController.storageKey)
        permission.currentValue = .authorized(alerts: true)
        let controller = make()
        let result = await controller.setEnabled(false)
        XCTAssertFalse(result)
        XCTAssertEqual(controller.presentation, .off)
        XCTAssertFalse(defaults.bool(forKey: IMInviteReminderController.storageKey))
        XCTAssertEqual(primer.calls, 0)
        XCTAssertEqual(permission.requestCount, 0)
    }

    func testQuietAndUnknownSystemStatusesAreNotAVisibleGrant() {
        XCTAssertEqual(IMInviteReminderSystemPermission.classify(authorization: .authorized, alerts: .enabled), .authorized(alerts: true))
        XCTAssertEqual(IMInviteReminderSystemPermission.classify(authorization: .authorized, alerts: .disabled), .authorized(alerts: false))
        XCTAssertEqual(IMInviteReminderSystemPermission.classify(authorization: .authorized, alerts: .notSupported), .authorized(alerts: false))
        XCTAssertEqual(IMInviteReminderSystemPermission.classify(authorization: .provisional, alerts: .enabled), .provisional)
        XCTAssertEqual(IMInviteReminderSystemPermission.classify(authorization: .ephemeral, alerts: .enabled), .ephemeral)
        XCTAssertEqual(IMInviteReminderSystemPermission.classify(authorization: .denied, alerts: .enabled), .denied)
        XCTAssertEqual(IMInviteReminderSystemPermission.classify(authorization: .notDetermined, alerts: .notSupported), .notDetermined)
        XCTAssertEqual(IMInviteReminderSystemPermission.classify(authorization: UNAuthorizationStatus(rawValue: 91)!, alerts: .enabled), .unknown)
        XCTAssertEqual(IMInviteReminderSystemPermission.classify(authorization: .authorized, alerts: UNNotificationSetting(rawValue: 91)!), .unknown)
        XCTAssertEqual(IMInviteReminderController.resolve(stored: true, permission: .unknown), .unknown)
        XCTAssertFalse(IMInviteReminderController.resolve(stored: true, permission: .unknown).isEnabled)
        XCTAssertEqual(IMInviteReminderController.resolve(stored: true, permission: .provisional), .off)
        XCTAssertEqual(IMInviteReminderController.resolve(stored: false, permission: .authorized(alerts: true)), .off)
    }

    private func make() -> IMInviteReminderController {
        IMInviteReminderController(defaults: defaults, permission: permission, primer: primer)
    }
}

@MainActor final class IMInviteReminderPermissionFake: IMInviteReminderPermissionReading {
    var currentValue: IMInviteReminderPermission = .notDetermined
    var requestValue: IMInviteReminderPermission = .denied
    private(set) var requestCount = 0
    func current() async -> IMInviteReminderPermission { currentValue }
    func request() async -> IMInviteReminderPermission {
        requestCount += 1
        return requestValue
    }
}

@MainActor final class IMInviteReminderPrimerFake: IMInviteReminderPriming {
    var outcome: IMInviteReminderPrimerOutcome = .denied
    private(set) var calls = 0
    func precedeNotification() async -> IMInviteReminderPrimerOutcome {
        calls += 1
        return outcome
    }
}
