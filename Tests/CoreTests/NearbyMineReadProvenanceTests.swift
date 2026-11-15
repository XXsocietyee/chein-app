import XCTest
@testable import QuestifyCore

@MainActor final class NearbyMineReadProvenanceTests: XCTestCase {
    private func make(_ steps: [NearbyTeamFakeTransport.Step]) -> (NearbyTeamCoordinator, NearbyTeamFakeTransport) {
        let fake = NearbyTeamFakeTransport(steps: steps)
        return (NearbyTeamCoordinator(service: .init(fake: fake),
            session: NearbyTeamSyntheticFixtures.session, locks: .init()), fake)
    }

    private var empty: NearbyTeamResponse {
        .init(data: Data(#"{"code":200,"data":[]}"#.utf8))
    }

    func testOnlySuccessfulMineReadEstablishesEmptyReadProvenance() async {
        let (model, _) = make([.failure, .response(empty)])
        XCTAssertFalse(model.hasLoadedMine)
        await model.loadMine()
        XCTAssertFalse(model.hasLoadedMine)
        XCTAssertEqual(model.messageKey, "nearby.loadFailed")
        await model.loadMine()
        XCTAssertTrue(model.hasLoadedMine)
        XCTAssertTrue(model.myApplications.isEmpty)
        XCTAssertNil(model.messageKey)
        XCTAssertFalse(model.busy)
        XCTAssertFalse(model.uncertain)
    }

    func testFailedRefreshInvalidatesSummaryWithoutDiscardingOriginalRows() async {
        let (model, _) = make([.response(NearbyTeamSyntheticFixtures.response(NearbyTeamSyntheticFixtures.applications)), .failure])
        await model.loadMine()
        let rows = model.myApplications
        XCTAssertFalse(rows.isEmpty)
        XCTAssertTrue(model.hasLoadedMine)
        await model.loadMine()
        XCTAssertFalse(model.hasLoadedMine)
        XCTAssertEqual(model.myApplications, rows)
        XCTAssertFalse(model.busy)
    }

    func testRebindingAndUnauthorizedRemoveReadProvenance() async {
        let unauthorized = NearbyTeamResponse(status: 401, data: Data())
        let (model, _) = make([.response(empty), .response(unauthorized), .response(empty)])
        await model.loadMine()
        XCTAssertTrue(model.hasLoadedMine)
        await model.loadMine()
        XCTAssertFalse(model.hasLoadedMine)
        XCTAssertNil(model.session)
        model.bind(NearbyTeamSyntheticFixtures.session)
        await model.loadMine()
        XCTAssertTrue(model.hasLoadedMine)
        model.bind(nil)
        XCTAssertFalse(model.hasLoadedMine)
        XCTAssertTrue(model.myApplications.isEmpty)
    }

    func testPrecancelledReadDoesNotInvalidateCompletedProjection() async {
        let (model, fake) = make([.response(empty)])
        await model.loadMine()
        let count = fake.requests.count
        await Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            await model.loadMine()
        }.value
        XCTAssertTrue(model.hasLoadedMine)
        XCTAssertEqual(fake.requests.count, count)
    }
}
