import Foundation

/// Mini-program pages/shezhi shows "成为俱乐部主理人" and "成为商家" only to a signed-in
/// player view (`!isMerchantView && !isClubView`); the server role decides, never a local choice.
public enum SettingsIdentityApplications {
    public static func isOffered(toRole role: String?) -> Bool {
        guard let role else { return false }
        return role != "merchant" && role != "club"
    }
}

/// pages/shezhi/shezhi facts for the session and market the settings form already reads.
/// This type does not open a route and does not mark one live. A missing market, a missing
/// count, or a numeric string is an em dash. A literal integer 0 stays "0".
public enum SettingsHomePage {
    public static let unknownDisplay = "—"
    public static let routeMarkedLive = false
    public static let knownRoles: Set<String> = ["player", "merchant", "club"]

    public enum Phase: Equatable {
        case loading
        case empty
        case error
        case unknown
        case ready
    }

    public enum SessionFact: Equatable {
        case loading
        case failed
        case signedOut
        case signedIn(role: String)
    }

    public enum Copy {
        public static let loading = "settings.home.loading"
        public static let error = "settings.home.error"
        public static let unknown = "settings.home.unknown"
        public static let signedOut = "member.settings.signedOut"
        public static let title = "settings.title"
    }

    public struct Facts: Equatable {
        public let phase: Phase
        public let marketText: String
        public let roleText: String
        public let offersIdentityApplications: Bool
        public let showsSignOut: Bool
        public let copyKey: String
        public let accessibilityIdentifier: String
    }

    /// Loading wins over a failure. A nil role is signed out. The raw role is kept;
    /// an empty role is not rewritten to player.
    public static func sessionFact(loading: Bool, failed: Bool, role: String?) -> SessionFact {
        if loading { return .loading }
        if failed { return .failed }
        guard let role else { return .signedOut }
        return .signedIn(role: role)
    }

    public static func marketText(_ market: RegionalMarket?) -> String {
        market?.rawValue ?? unknownDisplay
    }

    /// Nil is unknown. A literal 0 stays "0".
    public static func countText(_ count: Int?) -> String {
        guard let count else { return unknownDisplay }
        return String(count)
    }

    /// A numeric string is not a JSON number. `"0"` and a blank string stay unknown.
    public static func countText(numericString _: String) -> String { unknownDisplay }

    public static func facts(session: SessionFact, market: RegionalMarket?) -> Facts {
        let marketText = marketText(market)
        switch session {
        case .loading:
            return hidden(phase: .loading, marketText: marketText, copyKey: Copy.loading,
                          accessibilityIdentifier: "settings.home.loading")
        case .failed:
            return hidden(phase: .error, marketText: marketText, copyKey: Copy.error,
                          accessibilityIdentifier: "settings.home.error")
        case .signedOut:
            return Facts(phase: .empty, marketText: marketText, roleText: unknownDisplay,
                         offersIdentityApplications: false, showsSignOut: false,
                         copyKey: Copy.signedOut, accessibilityIdentifier: "settingsNative.profileSignedOut")
        case .signedIn(let role):
            let trimmed = role.trimmingCharacters(in: .whitespacesAndNewlines)
            guard knownRoles.contains(trimmed) else {
                return Facts(phase: .unknown, marketText: marketText, roleText: unknownDisplay,
                             offersIdentityApplications: false, showsSignOut: true,
                             copyKey: Copy.unknown, accessibilityIdentifier: "settings.home.unknown")
            }
            let offers = SettingsIdentityApplications.isOffered(toRole: trimmed)
            if market == nil {
                return Facts(phase: .unknown, marketText: unknownDisplay, roleText: trimmed,
                             offersIdentityApplications: offers, showsSignOut: true,
                             copyKey: Copy.unknown, accessibilityIdentifier: "settings.home.unknown")
            }
            return Facts(phase: .ready, marketText: marketText, roleText: trimmed,
                         offersIdentityApplications: offers, showsSignOut: true,
                         copyKey: Copy.title, accessibilityIdentifier: "settings.home.ready")
        }
    }

    private static func hidden(phase: Phase, marketText: String, copyKey: String,
                               accessibilityIdentifier: String) -> Facts {
        Facts(phase: phase, marketText: marketText, roleText: unknownDisplay,
              offersIdentityApplications: false, showsSignOut: false,
              copyKey: copyKey, accessibilityIdentifier: accessibilityIdentifier)
    }
}

#if DEBUG
/// Synthetic roles only. Not a support address, filing number, or legal body.
public enum SettingsHomeFixtureData {
    public static let unknownDisplay = SettingsHomePage.unknownDisplay
    public static let playerRole = "player"
    public static let merchantRole = "merchant"
    public static let clubRole = "club"
    public static let unknownRole = "UNKNOWN"
    public static let numericRole = "0"
    public static let blankRole = "  "
}
#endif
