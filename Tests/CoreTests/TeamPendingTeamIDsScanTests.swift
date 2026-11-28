import XCTest
@testable import QuestifyCore

/// MP `subpackageRoam/utils/roam-team-recovery.js` mount: the list page lists this account's stored
/// unknown-outcome team commands (team targets only) and shows the storage error on a broken record.
@MainActor
final class TeamPendingTeamIDsScanTests: XCTestCase {
    func testScanListsOnlyThisOwnersTeamTargets() throws {
        let suite = "TeamPendingTeamIDsScanTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let journal = TeamDefaultsJournal(defaults: defaults)
        try journal.write(TeamPendingRecord(operationID: UUID(), ownerKey: "CN-a2V5-12", targetKey: "team-61"))
        try journal.write(TeamPendingRecord(operationID: UUID(), ownerKey: "CN-a2V5-12", targetKey: "team-7"))
        try journal.write(TeamPendingRecord(operationID: UUID(), ownerKey: "CN-a2V5-12", targetKey: "activity-5"))
        try journal.write(TeamPendingRecord(operationID: UUID(), ownerKey: "CN-a2V5-123", targetKey: "team-9"))
        XCTAssertEqual(try journal.pendingTeamIDs(ownerKey: "CN-a2V5-12"), [7, 61])
        XCTAssertEqual(try journal.pendingTeamIDs(ownerKey: "CN-a2V5-123"), [9])
        XCTAssertEqual(try journal.pendingTeamIDs(ownerKey: "CN-a2V5-99"), [])
    }

    func testBrokenRecordThrowsSoThePanelShowsTheStorageError() throws {
        let suite = "TeamPendingTeamIDsScanTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("not data", forKey: "questify.team.pending.v1.CN-a2V5-12.team-61")
        XCTAssertThrowsError(try TeamDefaultsJournal(defaults: defaults).pendingTeamIDs(ownerKey: "CN-a2V5-12"))
    }

    func testNearbySessionUsesTheTeamPageOwnerKey() throws {
        let nearby = NearbyTeamSession(accountID: 12, epoch: 1, region: "CN", namespace: "key", role: "player")
        XCTAssertEqual(nearby.teamOwnerKey, TeamSession.ownerKey(region: "CN", storageNamespace: "key", accountID: 12))
        XCTAssertEqual(nearby.teamOwnerKey, "CN-a2V5-12")
    }
}
