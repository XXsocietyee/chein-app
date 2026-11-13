import Foundation

/// Production host www.chengyinhub.com keeps moneyPayments, payout, merchantWrites and passwordLogin false.
/// Those four open only for a TEST or DEBUG build whose API host is present and is not the production host.
/// External games: `externalGames(apiHost:)` follows the host only; `externalGames(host:testOrDebug:)` also needs TEST/DEBUG.
/// Two label sets exist because the cur-be-gap branches were written separately; both share one host check.
enum ReviewedAreaSwitch {
    static let productionAPIHost = "www.chengyinhub.com"
    static let productionHost = productionAPIHost

    static var compiledTestOrDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: apiHost: labels

    static func payout(apiHost: String?, testOrDebug: Bool = compiledTestOrDebug) -> Bool {
        openMoney(apiHost: apiHost, testOrDebug: testOrDebug)
    }

    static func moneyPayments(apiHost: String?, testOrDebug: Bool = compiledTestOrDebug) -> Bool {
        openMoney(apiHost: apiHost, testOrDebug: testOrDebug)
    }

    static func merchantWrites(apiHost: String?, testOrDebug: Bool = compiledTestOrDebug) -> Bool {
        openMoney(apiHost: apiHost, testOrDebug: testOrDebug)
    }

    static func passwordLogin(apiHost: String?, testOrDebug: Bool = compiledTestOrDebug) -> Bool {
        openMoney(apiHost: apiHost, testOrDebug: testOrDebug)
    }

    static func externalGames(apiHost: String?) -> Bool {
        guard let host = normalizedHost(apiHost) else { return false }
        return host != productionAPIHost
    }

    // MARK: host: labels

    static func moneyPayments(host: String, testOrDebug: Bool) -> Bool {
        openMoney(apiHost: host, testOrDebug: testOrDebug)
    }

    static func payout(host: String, testOrDebug: Bool) -> Bool {
        openMoney(apiHost: host, testOrDebug: testOrDebug)
    }

    static func merchantWrites(host: String, testOrDebug: Bool) -> Bool {
        openMoney(apiHost: host, testOrDebug: testOrDebug)
    }

    static func passwordLogin(host: String, testOrDebug: Bool) -> Bool {
        openMoney(apiHost: host, testOrDebug: testOrDebug)
    }

    static func externalGames(host: String, testOrDebug: Bool) -> Bool {
        openMoney(apiHost: host, testOrDebug: testOrDebug)
    }

    // MARK: shared

    private static func openMoney(apiHost: String?, testOrDebug: Bool) -> Bool {
        guard testOrDebug, let host = normalizedHost(apiHost), host != productionAPIHost else { return false }
        return true
    }

    private static func normalizedHost(_ apiHost: String?) -> String? {
        guard let apiHost else { return nil }
        let host = apiHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.isEmpty { return nil }
        return host
    }
}
