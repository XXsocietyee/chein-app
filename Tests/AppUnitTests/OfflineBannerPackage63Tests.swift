import XCTest
import SwiftUI
@testable import Questify
@testable import QuestifyCore

@MainActor
final class OfflineBannerPackage63Tests: XCTestCase {

    func testNetworkReachabilityDeduplicatesUpdatesAndSyncsSharedState() {
        let reachability = NetworkReachability()
        SharedNetworkReachabilityState.shared.setOnline(true)

        XCTAssertFalse(reachability.isOffline)
        reachability.applyConnectivity(online: false)
        XCTAssertTrue(reachability.isOffline)
        XCTAssertFalse(SharedNetworkReachabilityState.shared.isOnline)

        // Recheck without live NWPathMonitor flags stillOfflineAfterRecheck honestly
        XCTAssertFalse(reachability.recheck())
        XCTAssertTrue(reachability.stillOfflineAfterRecheck)

        reachability.applyConnectivity(online: true)
        XCTAssertFalse(reachability.isOffline)
        XCTAssertTrue(SharedNetworkReachabilityState.shared.isOnline)
        XCTAssertFalse(reachability.stillOfflineAfterRecheck)
        XCTAssertNotNil(reachability.lastConnectedAt)
    }

    func testCYStatusOfflineBannerCapturesSeriousAndCachedOptions() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let banner = CYStatusOfflineBanner(
            messageKey: "cy.state.offline.banner.title",
            detailKey: "cy.state.offline.queue.moneyNoAutoReplay",
            cachedAt: now,
            stillOffline: true,
            serious: true,
            actionTitleKey: "cy.state.offline.banner.retry",
            onRetry: {}
        )
        XCTAssertEqual(banner.messageKey, "cy.state.offline.banner.title")
        XCTAssertEqual(banner.detailKey, "cy.state.offline.queue.moneyNoAutoReplay")
        XCTAssertEqual(banner.cachedAt, now)
        XCTAssertTrue(banner.stillOffline)
        XCTAssertTrue(banner.serious)
    }
}
