import XCTest
@testable import QuestifyCore

final class StampAlbumIndexPageModelTests: XCTestCase {
    private let dash = "\u{2014}"

    func testEmptyAndUnknownTextIsAnEmDash() {
        XCTAssertEqual(StampAlbumIndexPageState.emptyText, dash)
        XCTAssertEqual(StampAlbumIndexPageState.unknownText, dash)
        XCTAssertEqual(StampAlbumIndexPageState.unknownText.unicodeScalars.map(\.value), [0x2014])
        let empty = StampAlbumIndexPageModel.project(data: StampAlbumIndexFixtureData.empty)
        let unknown = StampAlbumIndexPageModel.project(data: StampAlbumIndexFixtureData.unknownTotal)
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertNotEqual(empty.phase, unknown.phase)
        XCTAssertEqual(empty.totalText, dash)
        XCTAssertEqual(unknown.totalText, dash)
        XCTAssertEqual(unknown.visibleText, dash)
        XCTAssertFalse(unknown.totalText.contains("0"))
        XCTAssertFalse(unknown.totalText.contains("1"))
    }

    func testLiteralTotalStaysAndNumericStringDoesNotBecomeZero() {
        let ready = StampAlbumIndexPageModel.project(data: StampAlbumIndexFixtureData.content)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.totalText, "3")
        XCTAssertEqual(ready.visibleText, "2")
        XCTAssertEqual(ready.slots.count, 2)
        XCTAssertEqual(ready.slots[0].rotationDegrees, -4)
        XCTAssertFalse(ready.showsCapture)
        let zeroString = StampAlbumIndexPageModel.project(data: StampAlbumIndexFixtureData.numericStringZero)
        XCTAssertEqual(zeroString.phase, .unknown)
        XCTAssertEqual(zeroString.totalText, dash)
        XCTAssertNotEqual(zeroString.phase, .empty)
        XCTAssertFalse(zeroString.totalText.contains("0"))
        let missing = StampAlbumIndexPageModel.project(data: StampAlbumIndexFixtureData.missingTotal)
        XCTAssertEqual(missing.phase, .unknown)
        XCTAssertEqual(missing.totalText, dash)
        XCTAssertFalse(missing.totalText.contains("1"))
    }

    func testKnownZeroVisibleRowsDoNotReplaceAPositiveTotal() {
        let hidden = Data(#"{"list":[{"id":7,"picUrl":"","checkState":2},{"id":8,"picUrl":"","checkState":99}],"total":2,"pageNum":1,"pageSize":20}"#.utf8)
        let state = StampAlbumIndexPageModel.project(data: hidden)
        XCTAssertEqual(state.phase, .ready)
        XCTAssertEqual(state.totalText, "2")
        XCTAssertEqual(state.visibleText, "0")
        XCTAssertTrue(state.slots.isEmpty)
        let negative = Data(#"{"list":[],"total":-1,"pageNum":1,"pageSize":20}"#.utf8)
        XCTAssertEqual(StampAlbumIndexPageModel.project(data: negative).phase, .unknown)
        XCTAssertEqual(StampAlbumIndexPageModel.project(data: negative).totalText, dash)
        let fraction = Data(#"{"list":[],"total":1.5,"pageNum":1,"pageSize":20}"#.utf8)
        XCTAssertEqual(StampAlbumIndexPageModel.project(data: fraction).totalText, dash)
    }

    func testLoadingHidesAStaleZeroAndAStaleFailure() {
        let loading = StampAlbumIndexPageModel.project(loading: true, loaded: true, failure: "0", serverTotal: 0, visibleCount: 0, retainsRows: true)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.totalText, "")
        XCTAssertEqual(loading.visibleText, "")
        XCTAssertNotEqual(loading.totalText, dash)
        XCTAssertFalse(loading.totalText.contains("0"))
        XCTAssertNil(loading.failure)
        let fromData = StampAlbumIndexPageModel.project(data: StampAlbumIndexFixtureData.empty, loading: true, failure: "album.failed")
        XCTAssertEqual(fromData.phase, .loading)
        XCTAssertEqual(fromData.totalText, "")
    }

    func testErrorTokenIsKeptAndBlankUnknownOrZeroTokensAreUnknown() {
        let failed = StampAlbumIndexPageModel.project(loading: false, loaded: true, failure: " album.readFailed ", serverTotal: 4, visibleCount: 1, retainsRows: false)
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.totalText, "album.readFailed")
        XCTAssertNotEqual(failed.totalText, dash)
        XCTAssertNotEqual(failed.totalText, "0")
        XCTAssertNotEqual(failed.totalText, "4")
        for token in ["", "  ", "UNKNOWN", "unknown", "0", dash] {
            let state = StampAlbumIndexPageModel.project(loading: false, loaded: true, failure: token, serverTotal: 4, visibleCount: 1, retainsRows: true)
            XCTAssertEqual(state.phase, .unknown, token)
            XCTAssertEqual(state.totalText, dash, token)
        }
    }

    func testDeniedAndSignInStayHiddenCounts() {
        let denied = StampAlbumIndexPageModel.project(data: StampAlbumIndexFixtureData.denied)
        XCTAssertEqual(denied.phase, .error)
        XCTAssertEqual(denied.access, "denied")
        XCTAssertEqual(denied.totalText, "403")
        XCTAssertEqual(denied.visibleText, dash)
        XCTAssertFalse(denied.showsCapture)
        XCTAssertFalse(denied.showsMerchantChoice)
        let login = StampAlbumIndexPageModel.project(loading: false, loaded: false, failure: "unauthorized", serverTotal: nil, visibleCount: nil, retainsRows: false)
        XCTAssertEqual(login.phase, .error)
        XCTAssertEqual(login.access, "login")
        XCTAssertEqual(login.totalText, "unauthorized")
        XCTAssertFalse(login.opensHost)
        XCTAssertEqual(StampAlbumIndexPageModel.failureToken(APIError.notConfigured), "notConfigured")
        XCTAssertEqual(StampAlbumIndexPageModel.failureToken(APIError.httpStatus(403)), "403")
        XCTAssertEqual(StampAlbumIndexPageModel.failureToken(APIError.businessCode(403)), "403")
        XCTAssertEqual(StampAlbumIndexPageModel.failureToken(APIError.httpStatus(503)), "http.503")
    }

    func testContinuationFailureKeepsTheKnownTotal() {
        let continued = StampAlbumIndexPageModel.project(loading: false, loaded: true, failure: "http.503", serverTotal: 3, visibleCount: 2, retainsRows: true)
        XCTAssertEqual(continued.phase, .ready)
        XCTAssertEqual(continued.totalText, "3")
        XCTAssertEqual(continued.visibleText, "2")
        XCTAssertTrue(continued.continuationFailed)
        XCTAssertEqual(continued.failure, "http.503")
        XCTAssertEqual(continued.slots.count, 2)
        let unread = StampAlbumIndexPageModel.project(loading: false, loaded: false, failure: nil, serverTotal: 0, visibleCount: 0, retainsRows: false)
        XCTAssertEqual(unread.phase, .unknown)
        XCTAssertEqual(unread.totalText, dash)
        XCTAssertNotEqual(unread.phase, .empty)
    }

    func testRouteStaysTheExistingListContractAndCaptureStaysHidden() {
        XCTAssertEqual(StampAlbumIndexPageModel.routePath, RoamAlbumMetadataReadRoute.path)
        XCTAssertFalse(StampAlbumIndexPageModel.registersRoute)
        XCTAssertFalse(StampAlbumIndexPageModel.marksRouteLive)
        XCTAssertFalse(StampAlbumIndexPageModel.opensHost)
        XCTAssertFalse(StampAlbumIndexPageModel.showsCapture)
        XCTAssertFalse(StampAlbumIndexPageModel.showsMerchantChoice)
        XCTAssertTrue(RoamExperienceCapabilities.mediaUpload)
        XCTAssertTrue(RoamExperienceCapabilities.stampExchange)
        XCTAssertEqual(StampAlbumIndexPageModel.sourcePageSize, 50)
        XCTAssertEqual(StampAlbumIndexPageModel.fixturePageSize, 20)
        XCTAssertEqual(StampAlbumIndexPageModel.accessibilityIdentifiers.first, "roam.experience.album")
        XCTAssertTrue(StampAlbumIndexPageModel.accessibilityIdentifiers.contains("roam.experience.album.empty"))
    }

    func testPaymentSwitchesStayFalse() {
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        for kind in ReleaseMoneyWriteKind.allCases {
            XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(kind))
        }
    }

    func testMalformedAndUnreadableCodeDoNotBecomeZero() {
        let malformed = StampAlbumIndexPageModel.project(data: Data("not-json".utf8))
        XCTAssertEqual(malformed.phase, .error)
        XCTAssertEqual(malformed.totalText, "malformed")
        let code = StampAlbumIndexPageModel.project(data: Data(#"{"code":"403","data":{"total":0,"list":[]}}"#.utf8))
        XCTAssertEqual(code.phase, .unknown)
        XCTAssertEqual(code.totalText, dash)
        XCTAssertNil(code.access)
        let nullData = StampAlbumIndexPageModel.project(data: Data(#"{"code":200,"data":null}"#.utf8))
        XCTAssertEqual(nullData.phase, .unknown)
        XCTAssertEqual(nullData.totalText, dash)
    }
}

@MainActor final class StampAlbumIndexPagerProjectionTests: XCTestCase {
    private let dash = "\u{2014}"

    func testUnreadPagerIsUnknownAndAReadKeepsTheServerTotal() async throws {
        let reader = StampAlbumIndexReader()
        reader.pageJSON = String(decoding: StampAlbumIndexFixtureData.content, as: UTF8.self)
        let pager = RoamAlbumPager(reader: reader)
        let idle = StampAlbumIndexPageModel.project(pager)
        XCTAssertEqual(idle.phase, .unknown)
        XCTAssertEqual(idle.totalText, dash)
        XCTAssertFalse(idle.totalText.contains("0"))
        await pager.loadNext()
        let ready = StampAlbumIndexPageModel.project(pager)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.totalText, "3")
        XCTAssertEqual(ready.visibleText, "2")
        XCTAssertFalse(ready.continuationFailed)
        XCTAssertFalse(ready.showsCapture)
    }

    func testDeniedReadDoesNotBecomeAnEmptyAlbum() async {
        let reader = StampAlbumIndexReader()
        reader.error = APIError.httpStatus(403)
        let pager = RoamAlbumPager(reader: reader)
        await pager.loadNext()
        let denied = StampAlbumIndexPageModel.project(pager)
        XCTAssertEqual(denied.phase, .error)
        XCTAssertEqual(denied.access, "denied")
        XCTAssertEqual(denied.totalText, "403")
        XCTAssertNotEqual(denied.phase, .empty)
        XCTAssertFalse(denied.showsCapture)
    }
}

@MainActor private final class StampAlbumIndexReader: RoamExperienceReading {
    var identity: RoamExperienceIdentity? = RoamExperienceIdentity(
        scope: try! RoamHistoryScope(market: "cn", deployment: URL(string: "https://example.com/synthetic-roam")!, accountID: 1),
        epoch: 1)
    var isConfigured = true
    var isOfflineExample = true
    var pageJSON = ""
    var error: Error?
    func history() throws -> [RoamHistoryRecord] { [] }
    func sessionFact(_ query: RoamRecoveryQuery) async throws -> RoamSessionFact { throw APIError.notConfigured }
    func album(page: Int, pageSize: Int) async throws -> RoamAlbumPage {
        if let error { throw error }
        return try JSONDecoder().decode(RoamAlbumPage.self, from: Data(pageJSON.utf8))
    }
    func tilePage(afterID: Int, limit: Int) async throws -> RoamTileMemoryPage { throw APIError.notConfigured }
    func shopBadge() async throws -> RoamShopBadge? { nil }
}
