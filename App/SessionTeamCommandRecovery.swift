import Foundation

extension AppSession {
    /// MP my-teams / nearby `team-recovery-panel`: team ids with an unknown-outcome command stored for this account
    /// by the team page (`TeamDefaultsJournal`, same defaults and owner key); empty for guests.
    func pendingTeamCommandIDs() throws -> [Int] {
        guard let session = nearbyTeamSession else { return [] }
        return try TeamDefaultsJournal(defaults: composition.storage.defaults).pendingTeamIDs(ownerKey: session.teamOwnerKey)
    }
}
