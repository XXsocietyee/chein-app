import XCTest
@testable import QuestifyCore

final class StampCameraPageReadyTests: XCTestCase {
    private let dash = StampCameraPageReady.unknownMark

    func testLoadingWinsAndShowsNeitherDashNorZero() {
        let album = StampCameraPageReady.albumTotal(loading: true, failure: "stale", confirmedTotal: 0, listIsEmpty: true)
        let created = StampCameraPageReady.createdIdentifier(loading: true, failure: "stale", id: 29)
        let screen = StampCameraPageReady.screen(phase: .uploading, hasSelection: true)
        for value in [album, created, screen] {
            XCTAssertEqual(value.phase, .loading)
            XCTAssertEqual(value.text, "")
            XCTAssertNotEqual(value.text, dash)
            XCTAssertNotEqual(value.text, "0")
        }
        XCTAssertEqual(StampCameraPageReady.screen(phase: .creating, hasSelection: false).phase, .loading)
    }

    func testEmptyAlbumAndEmptyScreenUseTheDash() {
        let album = StampCameraPageReady.albumTotal(loading: false, confirmedTotal: 0, listIsEmpty: true)
        XCTAssertEqual(album.phase, .empty)
        XCTAssertEqual(album.text, dash)
        let screen = StampCameraPageReady.screen(phase: .ready, hasSelection: false)
        XCTAssertEqual(screen.phase, .empty)
        XCTAssertEqual(screen.text, dash)
        XCTAssertEqual(StampCameraPageReady.screen(coordinatorPhase: .ready, hasSelection: false), screen)
    }

    func testKnownCaptionLengthZeroStaysZero() {
        let empty = StampCameraPageReady.captionUnits("")
        XCTAssertEqual(empty.phase, .ready)
        XCTAssertEqual(empty.text, "0")
        XCTAssertEqual(StampCameraPageReady.captionUnits(String(repeating: "字", count: 30)).text, "30")
        let missing = StampCameraPageReady.captionUnits(nil)
        XCTAssertEqual(missing.phase, .unknown)
        XCTAssertEqual(missing.text, dash)
        XCTAssertEqual(StampCameraPageReady.captionUnits(String(repeating: "字", count: 31)).phase, .error)
    }

    func testUnknownMissingAndNonPositiveCreatedIDAreDash() {
        for id in [Int?.none, Optional(0), Optional(-1)] {
            let value = StampCameraPageReady.createdIdentifier(loading: false, id: id)
            XCTAssertEqual(value.phase, .unknown)
            XCTAssertEqual(value.text, dash)
            XCTAssertNotEqual(value.text, "0")
        }
        let created = StampCameraPageReady.createdIdentifier(loading: false, id: 29)
        XCTAssertEqual(created.phase, .ready)
        XCTAssertEqual(created.text, "29")
    }

    func testNumericStringAndUnknownTokenAreNotGuessed() {
        for token in ["UNKNOWN", "unknown", "0", "0.0", "12", "—", "  "] {
            let value = StampCameraPageReady.albumTotal(loading: false, failure: token, confirmedTotal: 4)
            XCTAssertEqual(value.phase, .unknown, token)
            XCTAssertEqual(value.text, dash, token)
        }
        XCTAssertEqual(StampCameraPageReady.albumTotal(loading: false, confirmedTotal: nil).text, dash)
        XCTAssertEqual(StampCameraPageReady.albumTotal(loading: false, confirmedTotal: -3).phase, .unknown)
        XCTAssertEqual(StampCameraPageReady.albumTotal(loading: false, confirmedTotal: 0, listIsEmpty: false).phase, .unknown)
        XCTAssertEqual(StampCameraPageReady.project(.count(-2)).text, dash)
    }

    func testConfirmedAlbumCountStaysLiteral() {
        let value = StampCameraPageReady.albumTotal(loading: false, confirmedTotal: 4, listIsEmpty: false)
        XCTAssertEqual(value.phase, .ready)
        XCTAssertEqual(value.text, "4")
        XCTAssertEqual(StampCameraPageReady.project(.count(0)).text, "0")
    }

    func testErrorKeepsANonNumericMessage() {
        let value = StampCameraPageReady.albumTotal(loading: false, failure: "unavailable")
        XCTAssertEqual(value.phase, .error)
        XCTAssertEqual(value.text, "unavailable")
        XCTAssertEqual(StampCameraPageReady.screen(phase: .failed, hasSelection: true).text, "failed")
        XCTAssertEqual(StampCameraPageReady.screen(phase: .unknown, hasSelection: true).phase, .unknown)
        XCTAssertEqual(StampCameraPageReady.screen(coordinatorPhase: .unavailable, hasSelection: false).text, dash)
        XCTAssertEqual(StampCameraPageReady.screen(phase: .review, hasSelection: true).phase, .ready)
        XCTAssertEqual(StampCameraPageReady.screen(coordinatorPhase: .created(29), hasSelection: false).reason, "ready")
    }

    /// MP-first (owner 2026-11-25): create and exchange are shown like the MP (stamp-camera/index/index.js:391,
    /// citystamp/index.js:288-296); the list path still needs an album reader and no route is registered.
    func testWritesStayHiddenAndListStaysUnregistered() {
        XCTAssertTrue(RoamExperienceCapabilities.mediaUpload)
        XCTAssertTrue(RoamExperienceCapabilities.stampExchange)
        XCTAssertEqual(StampCameraPageReady.createPath, "api/roam/stamp/create")
        XCTAssertEqual(StampCameraPageReady.exchangePath, "api/roam/stamp/exchange")
        XCTAssertEqual(StampCameraPageReady.listPath, RoamAlbumMetadataReadRoute.path)
        let hidden = StampCameraPageContract(hasAlbumReader: false)
        XCTAssertTrue(hidden.showsCreate)
        XCTAssertTrue(hidden.showsExchange)
        XCTAssertEqual(hidden.createPath, "api/roam/stamp/create")
        XCTAssertEqual(hidden.exchangePath, "api/roam/stamp/exchange")
        XCTAssertNil(hidden.listPath)
        XCTAssertFalse(hidden.registersRoute)
        XCTAssertFalse(hidden.marksRouteLive)
        let read = StampCameraPageContract(hasAlbumReader: true)
        XCTAssertEqual(read.listPath, "api/roam/stamp/list")
        XCTAssertEqual(read.createPath, "api/roam/stamp/create")
        XCTAssertEqual(read.exchangePath, "api/roam/stamp/exchange")
        XCTAssertFalse(read.registersRoute)
        XCTAssertFalse(read.marksRouteLive)
        XCTAssertFalse(StampCameraPageReady.showsMerchantChoice)
        XCTAssertFalse(StampCameraPageReady.paymentEnabled)
        XCTAssertFalse(StampCameraPageReady.payoutEnabled)
        XCTAssertFalse(StampCameraPageReady.withdrawalEnabled)
        XCTAssertFalse(StampCameraPageReady.virtualGoodsEnabled)
    }

    #if DEBUG
    func testFixtureDataMatchesTheProjection() {
        XCTAssertEqual(StampCameraPageFixtureData.unknownMark, "\u{2014}")
        XCTAssertEqual(StampCameraPageFixtureData.loading.phase, .loading)
        XCTAssertEqual(StampCameraPageFixtureData.loading.text, "")
        XCTAssertEqual(StampCameraPageFixtureData.empty.phase, .empty)
        XCTAssertEqual(StampCameraPageFixtureData.empty.text, dash)
        XCTAssertEqual(StampCameraPageFixtureData.unknown.phase, .unknown)
        XCTAssertEqual(StampCameraPageFixtureData.unknown.text, dash)
        XCTAssertEqual(StampCameraPageFixtureData.failed.phase, .error)
        XCTAssertEqual(StampCameraPageFixtureData.createdUnknown.phase, .unknown)
        XCTAssertNotEqual(StampCameraPageFixtureData.createdUnknown.text, "0")
        XCTAssertEqual(StampCameraPageFixtureData.hiddenContract.createPath, StampCameraPageReady.createPath)
        XCTAssertNil(StampCameraPageFixtureData.hiddenContract.listPath)
        XCTAssertEqual(StampCameraPageFixtureData.readContract.listPath, StampCameraPageReady.listPath)
        XCTAssertEqual(StampCameraPageFixtureData.readContract.exchangePath, StampCameraPageReady.exchangePath)
        XCTAssertFalse(StampCameraPageFixtureData.readContract.registersRoute)
    }
    #endif
}
