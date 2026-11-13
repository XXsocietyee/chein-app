import Foundation

/// Area switches for handover 21. Each flag is on only for a DEBUG build whose API host
/// is set and is not the production host. Release builds, an empty host, and
/// `www.chengyinhub.com` stay off. Screens stay visible; a cash action reads the flag
/// and refuses instead of reporting success.
enum ReviewedAreaSwitch {
    static let productionHost = "www.chengyinhub.com"

    static var moneyPayments: Bool { enabled }
    static var payout: Bool { enabled }
    static var merchantWrites: Bool { enabled }
    static var passwordLogin: Bool { enabled }
    static var externalGames: Bool { enabled }

    private static var enabled: Bool {
        #if DEBUG
        return configuredHostIsOffProduction
        #else
        return false
        #endif
    }

    private static var configuredHostIsOffProduction: Bool {
        let raw = Bundle.main.object(forInfoDictionaryKey: "QuestifyAPIBaseURL") as? String ?? ""
        guard let host = URL(string: raw)?.host?.lowercased(), host.isEmpty == false else { return false }
        return host != productionHost
    }
}
