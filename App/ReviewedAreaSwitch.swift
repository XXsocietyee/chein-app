import SwiftUI

/// Production host www.chengyinhub.com keeps moneyPayments, payout, merchantWrites and passwordLogin false.
/// Those four open only for a TEST or DEBUG build whose API host is present and is not the production host.
/// External games: `externalGames(apiHost:)` follows the host only; `externalGames(host:testOrDebug:)` also needs TEST/DEBUG.
/// Two label sets exist because the cur-be-gap branches were written separately; both share one host check.
enum ReviewedAreaSwitch {
    static let productionAPIHost = "www.chengyinhub.com"
    static let productionHost = productionAPIHost

    /// The production host, except in a DEBUG `--e2e-test-host` run, where every request is rewritten to the TEST host.
    private static func isProduction(_ host: String) -> Bool {
        #if DEBUG
        if E2ETestHostOverride.active { return false }
        #endif
        return host == productionAPIHost
    }

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
        return !isProduction(host)
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

    // MARK: Core money-write switch (DEBUG/TEST only)

    #if DEBUG || TEST
    /// Owner 2026-11-13: money ON for TEST/DEBUG only. Core `ReleaseMoneyWriteSwitch` follows this host's area switch:
    /// payment from `moneyPayments`, payout and withdrawal from `payout`. Virtual goods stay off (no digital goods are sold).
    /// Release builds compile none of this and keep the Core constants false.
    static func installReleaseMoneyDerivation(host: String?) {
        ReleaseMoneyWriteSwitch.testDerivation = { kind in releaseMoneyDerivation(kind, host: host) }
    }

    static func releaseMoneyDerivation(_ kind: ReleaseMoneyWriteKind, host: String?) -> Bool {
        switch kind {
        // Owner 2026-11-24 (D2): refunds and host-cancel refunds count as money, so they share the payment gate.
        case .payment, .refund, .hostCancelRefund: return moneyPayments(host: host)
        case .payout, .withdrawal: return payout(host: host)
        case .virtualGoods: return false
        }
    }
    #endif

    // MARK: shared

    private static func openMoney(apiHost: String?, testOrDebug: Bool) -> Bool {
        guard testOrDebug, let host = normalizedHost(apiHost), !isProduction(host) else { return false }
        return true
    }

    private static func normalizedHost(_ apiHost: String?) -> String? {
        guard let apiHost else { return nil }
        let host = apiHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.isEmpty { return nil }
        return host
    }


    // MARK: cur-be-gap-play (one-argument host labels)

    static func merchantWrites(host: String?) -> Bool { open(host: host) }
    static func moneyPayments(host: String?) -> Bool { open(host: host) }

    /// A missing host is a fixture, not the production server.
    static func merchantWritesBlocked(host: String?) -> Bool {
        guard let normalizedHost = normalized(host) else { return false }
        return !open(host: normalizedHost)
    }

    /// TEST and DEBUG hosts other than the China production host. Production stays closed.
    static func open(host: String?) -> Bool {
        guard let normalizedHost = normalized(host), !isProduction(normalizedHost) else { return false }
        #if DEBUG
        return true
        #else
        return ProcessInfo.processInfo.environment["QUESTIFY_TEST_AREA_SWITCHES"] == "1"
        #endif
    }

    private static func normalized(_ host: String?) -> String? {
        guard let trimmed = host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    // MARK: cur-be-gap-rewards (handover 21): build-wide flags from the configured API host, DEBUG only.
    // Screens stay visible; a cash action reads the flag and refuses instead of reporting success.

    static var moneyPayments: Bool { configuredEnabled }
    static var payout: Bool { configuredEnabled }
    static var merchantWrites: Bool { configuredEnabled }
    static var passwordLogin: Bool { configuredEnabled }
    static var externalGames: Bool { configuredEnabled }

    private static var configuredEnabled: Bool {
        #if DEBUG
        return configuredHostIsOffProduction
        #else
        return false
        #endif
    }

    private static var configuredHostIsOffProduction: Bool {
        let raw = Bundle.main.object(forInfoDictionaryKey: "QuestifyAPIBaseURL") as? String ?? ""
        guard let host = URL(string: raw)?.host?.lowercased(), host.isEmpty == false else { return false }
        return !isProduction(host)
    }

    // MARK: cur-be-gap-workshop (handover 22). moneyPayments/merchantWrites(host: String?) are the play
    // branch's above; digital goods are not sold from these switches and external-game monetization stays NONE.

    static func payout(host: String?) -> Bool { areaOpen(host) }
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
        return !isProduction(trimmed.lowercased())
        #else
        return false
        #endif
    }

    // MARK: cur-be-gap-merchant: one Access value for money, payout, merchant writes and the Apple session exchange.
    // Release builds stay closed; www.chengyinhub.com stays closed until the owner says money is on.

    struct Access: Equatable {
        let moneyPayments: Bool
        let payout: Bool
        let merchantWrites: Bool
        let passwordLogin: Bool
    }

    static func admits(debug: Bool, apiBaseURL: String) -> Access {
        let open = debug && !isProductionHost(apiBaseURL)
        return Access(moneyPayments: open, payout: open, merchantWrites: open, passwordLogin: open)
    }

    static var current: Access {
        #if DEBUG
        return admits(debug: true, apiBaseURL: bundleBaseURL())
        #else
        return admits(debug: false, apiBaseURL: bundleBaseURL())
        #endif
    }

    static func isProductionHost(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let host: String
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            if let parsed = URL(string: trimmed), let name = parsed.host { host = name } else { host = trimmed }
        } else {
            host = trimmed
        }
        return isProduction(host.lowercased())
    }

    private static func bundleBaseURL() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "QuestifyAPIBaseURL") as? String) ?? ""
    }
}

private struct PlayGapAPIHostKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var playGapAPIHost: String? {
        get { self[PlayGapAPIHostKey.self] }
        set { self[PlayGapAPIHostKey.self] = newValue }
    }
}
