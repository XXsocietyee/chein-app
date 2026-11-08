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

final class CloseW5dMerchantReviewsStateTests: XCTestCase {
    func testDeniedOnlyForDeniedKey() {
        XCTAssertTrue(MerchantReviewsPageState.isDenied(failureKey: "merchant.business.denied"))
        XCTAssertFalse(MerchantReviewsPageState.isDenied(failureKey: "merchant.business.loadFailed"))
        XCTAssertFalse(MerchantReviewsPageState.isDenied(failureKey: nil))
    }

    func testGatedNoticeOnlyOnSettledListWithoutFailure() {
        XCTAssertTrue(MerchantReviewsPageState.showsGatedNotice(hasSnapshot: true, failureKey: nil, isBusy: false, reviewSourceOpen: false))
        XCTAssertFalse(MerchantReviewsPageState.showsGatedNotice(hasSnapshot: false, failureKey: nil, isBusy: false, reviewSourceOpen: false))
        XCTAssertFalse(MerchantReviewsPageState.showsGatedNotice(hasSnapshot: true, failureKey: "merchant.business.denied", isBusy: false, reviewSourceOpen: false))
        XCTAssertFalse(MerchantReviewsPageState.showsGatedNotice(hasSnapshot: true, failureKey: nil, isBusy: true, reviewSourceOpen: false))
        XCTAssertFalse(MerchantReviewsPageState.showsGatedNotice(hasSnapshot: true, failureKey: nil, isBusy: false, reviewSourceOpen: true))
    }
}

final class CloseW5dStampAlbumErrorTests: XCTestCase {
    func testForbiddenIsDeniedRegardlessOfLoadedStamps() {
        XCTAssertEqual(StampAlbumErrorPresentation.resolve(error: APIError.httpStatus(403), hasStamps: false), .denied)
        XCTAssertEqual(StampAlbumErrorPresentation.resolve(error: APIError.businessCode(403), hasStamps: true), .denied)
    }

    func testUnauthorizedIsSignInPrompt() {
        XCTAssertEqual(StampAlbumErrorPresentation.resolve(error: APIError.unauthorized, hasStamps: false), .signIn)
    }

    func testOtherFailureIsWholePageRetryOnlyWhenNothingLoaded() {
        XCTAssertEqual(StampAlbumErrorPresentation.resolve(error: APIError.httpStatus(500), hasStamps: false), .retryWholePage)
        XCTAssertEqual(StampAlbumErrorPresentation.resolve(error: APIError.httpStatus(500), hasStamps: true), .retryContinuation)
    }
}
