import SwiftUI

/// TEST and DEBUG hosts other than the China production host. Production stays closed.
enum ReviewedAreaSwitch {
    static let productionHost = "www.chengyinhub.com"

    static func merchantWrites(host: String?) -> Bool { open(host: host) }
    static func moneyPayments(host: String?) -> Bool { open(host: host) }

    /// A missing host is a fixture, not the production server.
    static func merchantWritesBlocked(host: String?) -> Bool {
        guard let normalizedHost = normalized(host) else { return false }
        return !open(host: normalizedHost)
    }

    static func open(host: String?) -> Bool {
        guard let normalizedHost = normalized(host), normalizedHost != productionHost else { return false }
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
