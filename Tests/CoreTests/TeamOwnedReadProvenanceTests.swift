import XCTest
@testable import QuestifyCore

@MainActor final class TeamOwnedReadProvenanceTests: XCTestCase {
    func testUnstartedAndFailedReadsAreNotSuccessfulEmptyLists() async throws {
        let session = try TeamSyntheticFixtures.session()
        let service = try TeamSyntheticService(scenario: .retry)
        let model = TeamCoordinator(service: service, journal: TeamMemoryJournal(), currentSession: { session })
        XCTAssertFalse(model.hasCurrentTeamsRead)
        await model.loadTeams()
        XCTAssertFalse(model.hasCurrentTeamsRead)
        XCTAssertNotNil(model.messageKey)
        await model.loadTeams()
        XCTAssertTrue(model.hasCurrentTeamsRead)
        XCTAssertFalse(model.currentTeams.isEmpty)
        XCTAssertNil(model.messageKey)
        XCTAssertTrue(service.submissions.isEmpty)
    }
    func testSuccessfulEmptyReadHasExplicitProvenance() async throws {
        let session = try TeamSyntheticFixtures.session()
        let model = TeamCoordinator(service: try TeamSyntheticService(scenario: .empty), journal: TeamMemoryJournal(), currentSession: { session })
        await model.loadTeams()
        XCTAssertTrue(model.hasCurrentTeamsRead)
        XCTAssertTrue(model.currentTeams.isEmpty)
    }
    func testChangedIdentityImmediatelyHidesRawRowsBeforeSynchronization() async throws {
        var current: TeamSession? = try TeamSyntheticFixtures.session()
        let model = TeamCoordinator(service: try TeamSyntheticService(), journal: TeamMemoryJournal(), currentSession: { current })
        await model.loadTeams()
        XCTAssertFalse(model.teams.isEmpty)
        current = nil
        XCTAssertFalse(model.hasCurrentTeamsRead)
        XCTAssertTrue(model.currentTeams.isEmpty)
        XCTAssertFalse(model.teams.isEmpty, "The projection guard must work before lifecycle synchronization")
        model.synchronizeSession()
        XCTAssertTrue(model.teams.isEmpty)
        XCTAssertFalse(model.hasCurrentTeamsRead)
    }
    func testCancelledRefreshDoesNotPublishACompletedRead() async throws {
        let session = try TeamSyntheticFixtures.session()
        let service = try TeamSyntheticService()
        let model = TeamCoordinator(service: service, journal: TeamMemoryJournal(), currentSession: { session })
        await model.loadTeams()
        let rows = model.currentTeams
        service.beforeRead = { withUnsafeCurrentTask { $0?.cancel() } }
        await Task { @MainActor in await model.loadTeams() }.value
        XCTAssertFalse(model.hasCurrentTeamsRead)
        XCTAssertEqual(model.currentTeams, rows)
        XCTAssertFalse(model.loading)
        XCTAssertTrue(service.submissions.isEmpty)
    }
}
