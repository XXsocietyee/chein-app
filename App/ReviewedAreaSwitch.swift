import Foundation

/// TEST/DEBUG area switches. Production, and any build pointed at www.chengyinhub.com, stays closed.
/// Digital goods are not sold from these switches. External-game monetization stays NONE.
enum ReviewedAreaSwitch {
    static let productionHost = "www.chengyinhub.com"

    static func moneyPayments(host: String?) -> Bool { areaOpen(host) }
    static func payout(host: String?) -> Bool { areaOpen(host) }
    static func merchantWrites(host: String?) -> Bool { areaOpen(host) }
    static func passwordLogin(host: String?) -> Bool { areaOpen(host) }
    static func externalGames(host: String?) -> Bool { areaOpen(host) }
    static func paymentsOpen(session: AppSession) -> Bool {
        moneyPayments(host: session.regionalConfiguration?.apiConfiguration?.baseURL.host)
    }
    static func payoutOpen(session: AppSession) -> Bool {
        payout(host: session.regionalConfiguration?.apiConfiguration?.baseURL.host)
    }

    private static func areaOpen(_ rawHost: String?) -> Bool {
        #if DEBUG || TEST
        guard let given = rawHost else { return false }
        let trimmed = given.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.compare(productionHost, options: .caseInsensitive) != .orderedSame
        #else
        return false
        #endif
    }
}
