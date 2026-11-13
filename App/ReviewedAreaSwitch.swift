import Foundation

/// TEST and DEBUG builds may open payout, payments, merchant writes, and password login
/// only when the API host is present and is not the production host. Production stays closed.
/// External games follow the host only.
enum ReviewedAreaSwitch {
    static let productionAPIHost = "www.chengyinhub.com"

    static var compiledTestOrDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

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
