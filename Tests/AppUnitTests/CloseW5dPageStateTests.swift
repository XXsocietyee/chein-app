import XCTest
@testable import Questify

final class CloseW5dPageStateTests: XCTestCase {
    func testPrecedenceDeniedThenCachedThenErrorThenLoading() {
        XCTAssertEqual(CloseW5dPageState.resolve(loading: true, failed: true, denied: true, hasContent: true, isEmpty: false), .denied)
        XCTAssertEqual(CloseW5dPageState.resolve(loading: true, failed: true, denied: false, hasContent: true, isEmpty: false), .content)
        XCTAssertEqual(CloseW5dPageState.resolve(loading: true, failed: true, denied: false, hasContent: false, isEmpty: false), .error)
        XCTAssertEqual(CloseW5dPageState.resolve(loading: true, failed: false, denied: false, hasContent: false, isEmpty: false), .loading)
        XCTAssertEqual(CloseW5dPageState.resolve(loading: false, failed: false, denied: false, hasContent: true, isEmpty: true), .empty)
        XCTAssertEqual(CloseW5dPageState.resolve(loading: false, failed: false, denied: false, hasContent: false, isEmpty: false), .content)
    }

    func testBlockingFlagsAndIdentifiersAreDistinct() {
        let all: [CloseW5dPageState] = [.loading, .content, .empty, .error, .denied]
        XCTAssertEqual(Set(all.map(\.accessibilityIdentifier)).count, all.count)
        XCTAssertFalse(CloseW5dPageState.content.blocksContent)
        XCTAssertTrue(CloseW5dPageState.error.blocksContent)
    }

    func testMerchantEngagementMapping() {
        XCTAssertEqual(MerchantEngagementPageState.resolve(loading: false, issue: "merchant.business.denied", hasAccess: false, hasIdentity: false), .denied)
        XCTAssertEqual(MerchantEngagementPageState.resolve(loading: false, issue: nil, hasAccess: true, hasIdentity: false), .denied)
        XCTAssertEqual(MerchantEngagementPageState.resolve(loading: false, issue: "merchant.business.loadFailed", hasAccess: false, hasIdentity: false), .error)
        XCTAssertEqual(MerchantEngagementPageState.resolve(loading: false, issue: "merchant.business.loadFailed", hasAccess: true, hasIdentity: true), .content)
        XCTAssertEqual(MerchantEngagementPageState.resolve(loading: true, issue: nil, hasAccess: false, hasIdentity: false), .loading)
        XCTAssertEqual(MerchantEngagementPageState.resolve(loading: false, issue: nil, hasAccess: true, hasIdentity: true), .content)
    }
}

final class CloseW5dMerchantOperationsHomeStateTests: XCTestCase {
    func testInactiveMerchantShowsOnboardingEmptyState() {
        XCTAssertEqual(MerchantOperationsHomeState.resolve(active: false, visibleEntryCount: 0), .empty)
        XCTAssertEqual(MerchantOperationsHomeState.resolve(active: false, visibleEntryCount: 5), .empty)
    }

    func testActiveWithoutVisibleEntriesIsPermissionDenied() {
        XCTAssertEqual(MerchantOperationsHomeState.resolve(active: true, visibleEntryCount: 0), .denied)
    }

    func testActiveWithEntriesShowsContent() {
        XCTAssertEqual(MerchantOperationsHomeState.resolve(active: true, visibleEntryCount: 1), .content)
    }
}
