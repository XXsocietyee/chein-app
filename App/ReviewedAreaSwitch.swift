import Foundation

/// TEST/DEBUG area switches for money, payout, merchant writes, and Apple session exchange.
/// Release builds stay closed. www.chengyinhub.com stays closed until the owner says money is on.
enum ReviewedAreaSwitch {
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
            if let parsed = URL(string: trimmed), let name = parsed.host {
                host = name
            } else {
                host = trimmed
            }
        } else {
            host = trimmed
        }
        return host.lowercased() == "www.chengyinhub.com"
    }

    private static func bundleBaseURL() -> String {
        let object = Bundle.main.object(forInfoDictionaryKey: "QuestifyAPIBaseURL")
        if let text = object as? String { return text }
        return ""
    }
}
