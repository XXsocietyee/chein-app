import Foundation
import XCTest
@testable import Questify

@MainActor final class OrientScoreModelLoadTests: XCTestCase {
    private struct LoaderFailure: Error {}

    private func score() throws -> OrientSessionScore {
        let json = "{\"sessionId\":9,\"topicId\":3,\"activityId\":0,\"status\":1,\"totalCenti\":1700,"
            + "\"byDimension\":{\"TASK\":2000,\"PUZZLE\":0,\"BONUS\":0,\"PENALTY\":-300,\"ADJUSTMENT\":0},"
            + "\"timeline\":[],\"settlement\":null,\"appeals\":[],\"disputes\":[]}"
        return try JSONDecoder().decode(OrientSessionScore.self, from: Data(json.utf8))
    }

    func testLoadShowsReadyOnlyForServerScoreAndFailureIsNeverReady() async throws {
        let value = try score()
        let ready = OrientScoreModel(loader: { value })
        XCTAssertTrue(ready.state.isLoading)
        await ready.load()
        guard case .ready(let summary) = ready.state else { return XCTFail("expected ready") }
        XCTAssertEqual(summary.total, "17.00")

        let empty = OrientScoreModel(loader: { nil })
        await empty.load()
        XCTAssertEqual(empty.state, .empty)

        let failing = OrientScoreModel(loader: { throw LoaderFailure() })
        await failing.load()
        guard case .failed(_, let retryable) = failing.state else { return XCTFail("expected failed") }
        XCTAssertTrue(retryable)
    }

    func testSeveralRoundsBecomeAChoiceAndAChosenRoundLoadsItsScore() async throws {
        let value = try score()
        let rounds = try JSONDecoder().decode([OrientSessionView].self, from: Data((
            "[{\"sessionId\":9,\"topicId\":3,\"activityId\":0,\"phase\":\"FINISHED\",\"status\":1,\"configVersion\":1,\"startedAt\":1,\"elapsedMs\":1,\"serverNow\":2},"
            + "{\"sessionId\":10,\"topicId\":3,\"activityId\":0,\"phase\":\"FINISHED\",\"status\":1,\"configVersion\":1,\"startedAt\":1,\"elapsedMs\":1,\"serverNow\":2}]").utf8))
        var asked: [Int?] = []
        let model = OrientScoreModel(rounds: { chosen in
            asked.append(chosen)
            return chosen == 9 ? .score(value) : .choose(rounds)
        })
        await model.load()
        XCTAssertEqual(model.state, .empty)
        XCTAssertEqual(model.choices?.map(\.sessionID), [9, 10])
        await model.choose(9)
        guard case .ready = model.state else { return XCTFail("expected ready") }
        XCTAssertNil(model.choices)
        XCTAssertTrue(model.canChooseOther)
        await model.chooseAnother()
        XCTAssertEqual(model.choices?.count, 2)
        XCTAssertEqual(asked, [nil, 9, nil])
    }

    func testMissingSessionAsksToSignIn() async {
        let model = OrientScoreModel(loader: { throw APIError.unauthorized })
        await model.load()
        XCTAssertTrue(model.needsSignIn)
    }
}
