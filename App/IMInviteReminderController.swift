import SwiftUI
import UIKit
import UserNotifications

/// Local 「邀约提醒」 preference. The mini-program stores nothing: WeChat shows a one-shot
/// subscribe card. This switch stores the choice on device and asks for notification
/// permission through the existing primer. It does not write a server preference,
/// register for remote notifications, or invent a push topic.
@MainActor final class IMInviteReminderController: ObservableObject, IMInviteReminderBinding {
    static let storageKey = "imCoopInviteReminderEnabled"
    private let defaults: UserDefaults
    private let permission: any IMInviteReminderPermissionReading
    private let primer: any IMInviteReminderPriming
    private(set) var presentation: IMInviteReminderPresentation = .unknown
    /// System denial or alerts turned off. The switch then offers the existing notification Settings URL.
    private(set) var offersSettings = false
    var isEnabled: Bool { presentation.isEnabled }

    init(defaults: UserDefaults = .standard,
         permission: (any IMInviteReminderPermissionReading)? = nil,
         primer: (any IMInviteReminderPriming)? = nil) {
        self.defaults = defaults
        self.permission = permission ?? IMInviteReminderSystemPermission()
        self.primer = primer ?? IMInviteReminderSystemPrimer()
    }

    func reload() async {
        let reading = await permission.current()
        presentation = Self.resolve(stored: defaults.bool(forKey: Self.storageKey), permission: reading)
        offersSettings = Self.systemSettingsNeeded(reading)
    }

    func setEnabled(_ on: Bool) async -> Bool {
        if !on {
            defaults.set(false, forKey: Self.storageKey)
            await reload()
            return false
        }
        let reading = await permission.current()
        if reading == .unknown {
            defaults.set(false, forKey: Self.storageKey)
            presentation = .unknown
            offersSettings = false
            return false
        }
        if reading == .notDetermined {
            switch await primer.precedeNotification() {
            case .denied, .unavailable:
                defaults.set(false, forKey: Self.storageKey)
                presentation = .off
                offersSettings = false
                return false
            case .allowed:
                return apply(await permission.request())
            }
        }
        return apply(reading)
    }

    /// Denied, or alerts switched off, is the state that can only be changed in Settings.
    static func systemSettingsNeeded(_ reading: IMInviteReminderPermission) -> Bool {
        switch reading {
        case .denied, .authorized(alerts: false): return true
        default: return false
        }
    }

    /// A stored choice counts only together with a visible alert grant.
    /// Provisional, ephemeral, denied, and alerts-off stay off. Unreadable permission stays unknown.
    static func resolve(stored: Bool, permission: IMInviteReminderPermission) -> IMInviteReminderPresentation {
        switch permission {
        case .unknown: return .unknown
        case .authorized(alerts: true) where stored: return .on
        default: return .off
        }
    }

    private func apply(_ reading: IMInviteReminderPermission) -> Bool {
        let granted = reading == .authorized(alerts: true)
        defaults.set(granted, forKey: Self.storageKey)
        presentation = Self.resolve(stored: granted, permission: reading)
        offersSettings = Self.systemSettingsNeeded(reading)
        return presentation == .on
    }
}

enum IMInviteReminderPermission: Equatable {
    case notDetermined
    case denied
    case authorized(alerts: Bool)
    case provisional
    case ephemeral
    case unknown
}

enum IMInviteReminderPrimerOutcome: Equatable {
    case allowed, denied, unavailable
}

@MainActor protocol IMInviteReminderPermissionReading: AnyObject {
    func current() async -> IMInviteReminderPermission
    func request() async -> IMInviteReminderPermission
}

@MainActor protocol IMInviteReminderPriming: AnyObject {
    func precedeNotification() async -> IMInviteReminderPrimerOutcome
}

@MainActor final class IMInviteReminderSystemPermission: IMInviteReminderPermissionReading {
    private let center: UNUserNotificationCenter
    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    func current() async -> IMInviteReminderPermission {
        let settings = await center.notificationSettings()
        return Self.classify(authorization: settings.authorizationStatus, alerts: settings.alertSetting)
    }

    func request() async -> IMInviteReminderPermission {
        do { _ = try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
        catch { return .unknown }
        return await current()
    }

    static func classify(authorization: UNAuthorizationStatus, alerts: UNNotificationSetting) -> IMInviteReminderPermission {
        switch authorization {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized:
            switch alerts {
            case .enabled: return .authorized(alerts: true)
            case .disabled, .notSupported: return .authorized(alerts: false)
            @unknown default: return .unknown
            }
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        @unknown default: return .unknown
        }
    }
}

/// The same primer `CYPermissionSystemPrompt` shows before a notification prompt.
/// A missing window cannot present that card. XCTest still skips the card and reaches the request.
@MainActor final class IMInviteReminderSystemPrimer: IMInviteReminderPriming {
    func precedeNotification() async -> IMInviteReminderPrimerOutcome {
        if Self.suppressesInterface {
            return Self.outcome(await CYPermissionSystemPrompt.precede(.notification))
        }
        guard Self.hasWindowScene else { return .unavailable }
        return Self.outcome(await CYPermissionSystemPrompt.precede(.notification))
    }

    private static func outcome(_ allowed: Bool) -> IMInviteReminderPrimerOutcome {
        allowed ? .allowed : .denied
    }

    private static var hasWindowScene: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first) != nil
    }

    /// Same skip as `CYPermissionSystemPrompt`: the test host cannot tap the card.
    private static var suppressesInterface: Bool {
        let info = ProcessInfo.processInfo
        if info.environment["XCTestConfigurationFilePath"] != nil { return true }
        if info.environment["XCTestBundlePath"] != nil { return true }
        if info.environment["XCTestSessionIdentifier"] != nil { return true }
        return info.arguments.contains("-XCTest")
    }
}
