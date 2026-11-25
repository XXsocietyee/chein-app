import XCTest
@testable import Questify

/// R7-PC-B4-1 / R7-PC-B1-2 (MP-first rule, owner 2026-11-25): the shipped play lease carries the publisher lifecycle paths
/// the MP sends (pages/topic/pricing/index.js:128,443; pages/topic/index/index.js:1353,1417). Cancel-with-refund stays out.
@MainActor final class PublisherLifecycleMPFirstLeaseTests: XCTestCase {
    func test_publisher_paths_are_in_the_play_lease_and_refund_cancel_is_not() {
        let paths = ReviewedProductionGateLeases.playPaths
        for path in ["api/topic/pricing/preview", "api/topic/pricing/confirm", "api/topic/beta/graduate", "api/topic/transfer-to-club"] {
            XCTAssertTrue(paths.contains(path), path)
        }
        XCTAssertTrue(ReviewedProductionGateLeases.publisherLifecyclePaths.isSubset(of: paths))
        for money in ["api/topic/cancel", "api/activity/cancel", "api/registration/pay", "api/pay/create"] {
            XCTAssertFalse(ReviewedProductionGateLeases.publisherLifecyclePaths.contains(money), money)
        }
        XCTAssertFalse(ReleaseMoneyWriteSwitch.blocks("/api/topic/pricing/confirm"))
    }
}
