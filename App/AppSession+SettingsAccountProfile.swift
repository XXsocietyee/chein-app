import Foundation

/// pages/shezhi reads the account again on every show (`onShow` → `POST /api/user/info`), and `pickClub`
/// routes by owned clubs plus `isClubLeader`. These wrap Cursor's Core clients with the session credentials.
extension AppSession {
    /// B-SZ-14-r7 / B-SZ-09: fresh role + `isClubLeader`; a 403 is `.denied` (the row says so and taps re-read).
    /// Nil when there is nothing to read (not configured or signed out); the page then uses the session facts.
    func refreshSettingsAccountProfile() async -> SettingsAccountProfileAccess? {
        guard isConfigured, isSignedIn, let memberID = account?.id, let token,
              let config = regionalConfiguration?.apiConfiguration else { return nil }
        return await SettingsAccountProfileClient(configuration: config, transport: compositionTransport)
            .refresh(memberID: memberID, token: token)
    }

    /// B-SZ-05: shezhi `pickClub`. Any owned club opens its manage tab; a leader without one creates; others apply.
    func resolveSettingsClubHostRoute(isClubLeader: Bool) async -> SettingsClubHostRoute {
        guard isConfigured, isSignedIn,
              let config = regionalConfiguration?.apiConfiguration else { return .applyForHost }
        return await SettingsClubPickerService(configuration: config, transport: compositionTransport)
            .resolveHostRoute(token: token, isClubLeader: isClubLeader)
    }
}
