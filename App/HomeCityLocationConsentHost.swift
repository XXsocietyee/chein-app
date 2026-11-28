import SwiftUI

/// Mini-program `home_city_location_declined`. Decline remembers locally. Agree clears that memory.
enum HomeCityLocationDeclineStore {
    static let storageKey = "home_city_location_declined"

    static func read(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) != nil
    }

    static func saveLocationDeclined(_ declined: Bool, defaults: UserDefaults = .standard) {
        if declined { defaults.set(1, forKey: storageKey) }
        else { defaults.removeObject(forKey: storageKey) }
    }
}

/// Owns the non-blocking home-city consent card. Nil handlers keep the card hidden.
@MainActor final class HomeCityLocationConsentModel: ObservableObject {
    @Published private(set) var asks = false
    @Published var toast: LocalizedStringKey?
    private var generation: UInt64 = 0
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func refresh(_ session: AppSession) async {
        generation &+= 1
        let stamp = generation
        // Blank or UNKNOWN is an em dash. The hero city label stays on the explore home.
        _ = HomeCityLocationConsentRecord.cityLabel(session.roamArea?.label)
        guard UsageConsentEnvironment.policy.granted,
              let account = session.account, account.id > 0, session.token != nil,
              session.composition.isAccountComplianceEnabled,
              let coordinator = session.accountComplianceCoordinator,
              !HomeCityLocationDeclineStore.read(defaults) else {
            asks = false
            return
        }
        let baseline: HomeCityLocationConsentBaseline
        do { baseline = try await coordinator.latestHomeCityLocationConsent() }
        catch {
            guard stamp == generation else { return }
            asks = false
            return
        }
        guard stamp == generation else { return }
        asks = HomeCityLocationConsentRecord.shouldAsk(baseline)
    }

    func agree(_ session: AppSession) {
        generation &+= 1
        asks = false
        toast = nil
        HomeCityLocationDeclineStore.saveLocationDeclined(false, defaults: defaults)
        guard let coordinator = session.accountComplianceCoordinator else {
            toast = LocalizedStringKey("homeCityConsent.saveFailed")
            return
        }
        Task {
            do {
                _ = try await SessionOfflineSyncModel.shared.performWriteOptIn(
                    session: session,
                    routes: ["/api/compliance/consents"]
                ) {
                    try await coordinator.recordHomeCityLocationAgree()
                }
            }
            catch { toast = LocalizedStringKey("homeCityConsent.saveFailed") }
        }
    }

    /// mp-home r3 (continue 32): MP `onTapHomeCity` → `getHomeCityLocation({ userInitiated: true })`
    /// (pages/index/index.js:1294-1330, 1438). Signed in only (guests keep the manual city menu). A REVOKE row stops
    /// silently, as the MP; no agreement on record brings the consent card back (a local 暂不 is cleared, because the
    /// user asked); a current agreement returns `true` so the caller locates now. A failed read returns `false`.
    func userAsksToLocate(_ session: AppSession) async -> Bool {
        generation &+= 1
        let stamp = generation
        guard UsageConsentEnvironment.policy.granted,
              let account = session.account, account.id > 0, session.token != nil,
              session.composition.isAccountComplianceEnabled,
              let coordinator = session.accountComplianceCoordinator else { return false }
        let baseline: HomeCityLocationConsentBaseline
        do { baseline = try await coordinator.latestHomeCityLocationConsent() }
        catch { return false }
        guard stamp == generation else { return false }
        if HomeCityLocationConsentRecord.isRevoked(baseline) { return false }
        if HomeCityLocationConsentRecord.shouldAsk(baseline) {
            HomeCityLocationDeclineStore.saveLocationDeclined(false, defaults: defaults)
            asks = true
            return false
        }
        return true
    }

    func decline() {
        generation &+= 1
        asks = false
        toast = nil
        HomeCityLocationDeclineStore.saveLocationDeclined(true, defaults: defaults)
    }
}
