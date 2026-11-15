import XCTest
@testable import QuestifyCore

@MainActor private final class CancelledLoadReader: OrderLifecycleReading {
    var accountID: Int? = 100
    var scope = UUID()
    var isConfigured = true
    var isOfflineExample = true
    var value = try! OrderLifecycleSyntheticFixtures.detail()
    var reads = 0
    var continuation: CheckedContinuation<OrderLifecycleDetail, Error>?
    var suspend = false
    func detail(id: Int) async throws -> OrderLifecycleDetail {
        reads += 1
        if suspend {
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }
        return value
    }
}

@MainActor final class OrderLifecycleCancelledLoadTests: XCTestCase {
    private func cancelledLoad(_ coordinator: OrderLifecycleCoordinator) async {
        let task = Task { @MainActor in await coordinator.load(id: 9701) }
        task.cancel()
        await task.value
    }

    func testCancelledEntryDoesNotReadOrPublishIssue() async {
        let reader = CancelledLoadReader()
        let coordinator = OrderLifecycleCoordinator(reader: reader)
        await cancelledLoad(coordinator)
        XCTAssertEqual(reader.reads, 0)
        XCTAssertNil(coordinator.detail)
        XCTAssertNil(coordinator.issue)
    }

    func testCancelledOldEntryPreservesCurrentDetailAndReview() async throws {
        let reader = CancelledLoadReader()
        let coordinator = OrderLifecycleCoordinator(reader: reader)
        await coordinator.load(id: 9701)
        coordinator.prepare(.cancel, orderID: 9701)
        let review = try XCTUnwrap(coordinator.review)
        await cancelledLoad(coordinator)
        XCTAssertEqual(reader.reads, 1)
        XCTAssertEqual(coordinator.detail?.id, 9701)
        XCTAssertEqual(coordinator.review?.id, review.id)
        XCTAssertNil(coordinator.issue)
    }

    func testCancelledOldEntryDoesNotInvalidateCurrentInFlightRead() async {
        let reader = CancelledLoadReader()
        reader.suspend = true
        let coordinator = OrderLifecycleCoordinator(reader: reader)
        let current = Task { @MainActor in await coordinator.load(id: 9701) }
        // A bounded cooperative wait prevents a broken test from waiting forever.
        for _ in 0..<100 where reader.continuation == nil { await Task.yield() }
        guard let pending = reader.continuation else {
            current.cancel()
            XCTFail("Current read did not start")
            return
        }
        await cancelledLoad(coordinator)
        pending.resume(returning: reader.value)
        await current.value
        XCTAssertEqual(reader.reads, 1)
        XCTAssertEqual(coordinator.detail?.id, 9701)
        XCTAssertNil(coordinator.issue)
    }
}
