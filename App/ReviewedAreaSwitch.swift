import Foundation

/// Production host www.chengyinhub.com keeps moneyPayments, payout, merchantWrites and passwordLogin false.
/// Those four are true only for a TEST or DEBUG build aimed at any other host.
/// externalGames follows the same rule: true only for TEST or DEBUG off the production host.
enum ReviewedAreaSwitch {
    static let productionHost = "www.chengyinhub.com"

    static func moneyPayments(host: String, testOrDebug: Bool) -> Bool {
        offProduction(host: host, testOrDebug: testOrDebug)
    }

    static func payout(host: String, testOrDebug: Bool) -> Bool {
        offProduction(host: host, testOrDebug: testOrDebug)
    }

    static func merchantWrites(host: String, testOrDebug: Bool) -> Bool {
        offProduction(host: host, testOrDebug: testOrDebug)
    }

    static func passwordLogin(host: String, testOrDebug: Bool) -> Bool {
        offProduction(host: host, testOrDebug: testOrDebug)
    }

    static func externalGames(host: String, testOrDebug: Bool) -> Bool {
        offProduction(host: host, testOrDebug: testOrDebug)
    }

    private static func offProduction(host: String, testOrDebug: Bool) -> Bool {
        testOrDebug && host.lowercased() != productionHost
    }
}
