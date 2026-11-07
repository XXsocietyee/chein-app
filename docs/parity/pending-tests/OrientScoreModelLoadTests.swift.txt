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
}
