import XCTest
@testable import QuestifyCore

@MainActor
final class TeamCancelledReadEntryTests: XCTestCase {
    func testCancelledReadEntriesPreserveCurrentReviewAndCreation() async throws {
        for entry in 0..<4 {
            let service = try TeamSyntheticService(), journal = TeamMemoryJournal()
            let session = try TeamSyntheticFixtures.session()
            let model = TeamCoordinator(service: service, journal: journal, currentSession: { session })
            await model.loadCreation(ownerID: 5101)
            await model.loadDetail(.id(4101))
            model.prepare(.leave(teamID: 4101))
            let review = try XCTUnwrap(model.review), creation = model.creation, detail = model.detail
            var reads = 0
            service.beforeRead = { reads += 1 }
            await Task { @MainActor in
                withUnsafeCurrentTask { $0?.cancel() }
                switch entry {
                case 0: await model.loadTeams()
                case 1: await model.loadDetail(.invitation("SYNTHETIC-TEAM"))
                case 2: await model.loadCreation(ownerID: 5101)
                default: await model.loadPostJoinDetail(teamID: 4101)
                }
            }.value
            XCTAssertEqual(reads, 0)
            XCTAssertEqual(model.review, review)
            XCTAssertEqual(model.creation, creation)
            XCTAssertEqual(model.detail, detail)
            model.prepare(review.action)
            XCTAssertNotNil(model.review, "Cancelled wrapper must not retire the original writable workflow")
            XCTAssertFalse(model.loading)
            XCTAssertTrue(service.submissions.isEmpty)
        }
    }
    func testCancelledDifferentTargetCannotEraseUnknownPendingPresentation() async throws {
        let service = try TeamSyntheticService(), journal = TeamMemoryJournal()
        let session = try TeamSyntheticFixtures.session()
        let record = TeamPendingRecord(operationID: UUID(), ownerKey: session.ownerKey, targetKey: "team-4101")
        try journal.write(record)
        let model = TeamCoordinator(service: service, journal: journal, currentSession: { session })
        await model.loadDetail(.id(4101))
        XCTAssertEqual(model.pending, record)
        XCTAssertEqual(model.writeState, .unknown)
        var reads = 0
        service.beforeRead = { reads += 1 }
        await Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            await model.loadDetail(.id(9999))
        }.value
        XCTAssertEqual(reads, 0)
        XCTAssertEqual(model.pending, record)
        XCTAssertEqual(model.writeState, .unknown)
        XCTAssertEqual(try journal.pending(ownerKey: session.ownerKey, targetKey: record.targetKey), record)
        XCTAssertTrue(service.submissions.isEmpty)
    }
    func testCancelledEntryStillSynchronizesChangedIdentityWithoutReading() async throws {
        let service = try TeamSyntheticService(), journal = TeamMemoryJournal()
        var current: TeamSession? = try TeamSyntheticFixtures.session()
        let model = TeamCoordinator(service: service, journal: journal, currentSession: { current })
        await model.loadDetail(.id(4101))
        XCTAssertNotNil(model.detail)
        current = nil
        var reads = 0
        service.beforeRead = { reads += 1 }
        await Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            await model.loadTeams()
        }.value
        XCTAssertNil(model.detail)
        XCTAssertNil(model.review)
        XCTAssertEqual(reads, 0)
    }
}
