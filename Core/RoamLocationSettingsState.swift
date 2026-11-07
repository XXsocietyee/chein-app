import Foundation

/// System authorization is information, never a Roam live/background capability grant.
public enum RoamSystemLocationAuthorization: String, CaseIterable, Sendable {
    case notDetermined, denied, restricted, whenInUse, always, unknown
}

public struct RoamLocationSettingsSnapshot: Equatable, Sendable {
    public let authorization: RoamSystemLocationAuthorization
    public let servicesEnabled: Bool
    public init(authorization: RoamSystemLocationAuthorization, servicesEnabled: Bool) {
        self.authorization = authorization; self.servicesEnabled = servicesEnabled
    }
    public var foregroundAuthorized: Bool { authorization == .whenInUse || authorization == .always }
    public var alwaysAuthorized: Bool { authorization == .always }
    // These are OS permission facts only. They do not assert recording, reminders, or live approval.
}

/// W5 Deliverable 5 contract: Location permissions, background/foreground behaviour, and privacy copy.
/// Enforces When-In-Use (`whenInUse`) authorization only (no Always-On location request), immediate
/// suspension of location/reads on background transition, and bilingual privacy disclosure copy.
public struct RoamLocationPrivacyPolicyContract: Equatable, Sendable {
    public static let requiredAuthorizationScope: RoamSystemLocationAuthorization = .whenInUse
    public static let requestsAlwaysOnLocation: Bool = false
    public static let suspendsImmediatelyOnBackground: Bool = true
    public static let requiresExplicitFreshScopeOnForeground: Bool = true
    public static let privacyCopyZhHans = "仅在前台使用期间请求定位权限 (When In Use) 用于校验漫游点位到达（水平精度 ≤ 50m）；切入后台立即挂起定位与实时读回，绝不请求后台常驻定位。"
    public static let privacyCopyEn = "Requests When-In-Use location only while active in the foreground to verify POI arrival (horizontal accuracy <= 50m); suspends location and live reads immediately on background transition and never requests Always-On location."

    public let requestsAlwaysOn: Bool
    public let suspendsOnBackground: Bool
    public let requiresFreshForegroundScope: Bool
    public let copyZhHans: String
    public let copyEn: String

    public init(
        requestsAlwaysOn: Bool = Self.requestsAlwaysOnLocation,
        suspendsOnBackground: Bool = Self.suspendsImmediatelyOnBackground,
        requiresFreshForegroundScope: Bool = Self.requiresExplicitFreshScopeOnForeground,
        copyZhHans: String = Self.privacyCopyZhHans,
        copyEn: String = Self.privacyCopyEn
    ) {
        self.requestsAlwaysOn = requestsAlwaysOn
        self.suspendsOnBackground = suspendsOnBackground
        self.requiresFreshForegroundScope = requiresFreshForegroundScope
        self.copyZhHans = copyZhHans
        self.copyEn = copyEn
    }

    public var isPolicyCompliant: Bool {
        !requestsAlwaysOn
            && suspendsOnBackground
            && requiresFreshForegroundScope
            && !copyZhHans.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !copyEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct RoamLocationSettingsState: Equatable {
    public enum Phase: Equatable { case idle, loading, loaded(RoamLocationSettingsSnapshot), failed }
    public private(set) var phase: Phase = .idle
    public private(set) var settingsOpenFailed = false
    private var readAttempt: UUID?
    private var settingsAttempt: UUID?
    public var isOpeningSettings: Bool { settingsAttempt != nil }
    public init() {}
    public mutating func beginRead() -> UUID {
        let attempt = UUID(); readAttempt = attempt; phase = .loading
        settingsAttempt = nil; settingsOpenFailed = false
        return attempt
    }
    @discardableResult public mutating func finishRead(_ attempt: UUID, snapshot: RoamLocationSettingsSnapshot?) -> Bool {
        guard readAttempt == attempt else { return false }
        readAttempt = nil
        phase = snapshot.map(Phase.loaded) ?? .failed
        return true
    }
    public mutating func beginSettingsOpen() -> UUID? {
        guard settingsAttempt == nil else { return nil }
        let attempt = UUID(); settingsAttempt = attempt; settingsOpenFailed = false; return attempt
    }
    public func acceptsSettingsOpen(_ attempt: UUID) -> Bool { settingsAttempt == attempt }
    @discardableResult public mutating func finishSettingsOpen(_ attempt: UUID, opened: Bool) -> Bool {
        guard settingsAttempt == attempt else { return false }
        settingsAttempt = nil; settingsOpenFailed = !opened; return true
    }
    public mutating func invalidate() {
        readAttempt = nil; settingsAttempt = nil; phase = .idle; settingsOpenFailed = false
    }
}
