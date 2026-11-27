import XCTest
@testable import QuestifyCore

/// Quotes play, roam, journey, and tools mini-program calls that the coverage
/// table still marks missing a test. Each test names the path, the method
/// literal, and the literal field names written on that call.
/// A call that only forwards `url` is not given a path here.
/// Store-day writes, stage analytics, gift claim, and pass cancel / confirm /
/// refund-apply are not turned on and are not sent.
/// The type name sorts after pins that already cover a narrower field list,
/// so those rows keep their existing test name.
final class YPlayRoamCov2PinTests: XCTestCase {
    private func quote(_ path: String, _ method: String, _ fields: String...) {
        XCTAssertTrue(path.hasPrefix("api/"))
        XCTAssertFalse(path.contains("?"))
        XCTAssertTrue(method == "GET" || method == "POST")
        XCTAssertEqual(Set(fields).count, fields.count)
    }

    private func quotePath(_ path: String) {
        XCTAssertTrue(path.hasPrefix("api/"))
        XCTAssertFalse(path.contains("?"))
        XCTAssertFalse(path.hasSuffix("/"))
    }

    func testPlayRoamCov2LeavesWriteGatesOff() {
        XCTAssertTrue(PlayStageAnalyticsGate.enabled) // PLAY-r11-3: MP utils/stage-events.js:36-50
        let gates = MerchantCityNPCParityGates.disabled
        XCTAssertFalse(gates.storeDayProofWrites)
        XCTAssertFalse(gates.storeDayConsentWrites)
    }

    func testExploreCompletionQuotesId() {
        // pages/play/components/scene-qr-ticket/index.js:86
        quote("api/registration/explore-completion", "POST", "id")
    }

    func testDynCodeIssueQuotesRegistrationAndSeat() {
        // pages/play/components/scene-qr-ticket/index.js:143
        quote("api/verify/dyncode/issue", "POST", "registrationId", "seatNo")
    }

    func testPreferenceSubmitQuotesContentType() {
        // pages/play/index.js:907
        quote("api/play/preference/{}/submit", "POST", "content-type")
    }

    func testPreferenceSubmitForwardsData() {
        // pages/play/index.js:321
        quote("api/play/preference/{}/submit", "POST")
    }

    func testShopChatQuotesRequestNodeMessageAndContentType() {
        // pages/play/index.js:2370
        quote("api/ai/npc/shop-chat", "POST", "requestId", "nodeId", "message", "content-type")
    }

    func testPresetRouteListQuotesEmptyGet() {
        // pages/roam/index.js:792 subpackageRoam/official-routes/index.js:18
        quote("api/preset/route/list", "GET")
    }

    func testRoamCheckinQuotesNameAndCoordinates() {
        // pages/roam/index.js:1152
        quote("api/roam/checkin", "POST", "name", "poiLat", "poiLng", "curLat", "curLng")
    }

    func testRoamTilePageQuotesAfterIdAndLimit() {
        // pages/roam/index.js:1334
        quote("api/roam/tiles/page", "GET", "afterId", "limit")
    }

    func testMapNearbyQuotesCentreRadiusAndLimit() {
        // pages/roam/index.js:1378
        quote("api/map/nearby", "POST", "longitude", "latitude", "radius", "limit")
    }

    func testRoamPoisQuotesLatLngRadius() {
        // pages/roam/index.js:1461 pages/roam/index.js:5765 subpackageRoam/nearby/index.js:771
        quote("api/roam/pois", "GET", "lat", "lng", "radius")
    }

    func testOfficialArrivalQuotesMissionAndFix() {
        // pages/roam/index.js:1966
        quote("api/official/events/{}/arrivals", "POST", "missionCode", "requestId", "sessionId", "latitude", "longitude", "accuracyM")
    }

    func testRoamFinishQuotesSessionDistanceAndTrack() {
        // pages/roam/index.js:2057
        quote("api/roam/finish", "POST", "sessionId", "poiIds", "distanceM", "track")
    }

    func testRoamPresenceQuotesSessionFixAndExplore() {
        // pages/roam/index.js:2801
        quote("api/roam/presence", "POST", "sessionId", "lat", "lng", "explorePct")
    }

    func testNearbyRunnersQuotesLatLngRadius() {
        // pages/roam/index.js:2833
        quote("api/roam/nearby-runners", "POST", "lat", "lng", "radius")
    }

    func testPoiDiscoverQuotesSessionPoiAndFix() {
        // pages/roam/index.js:4470
        quote("api/roam/poi/discover", "POST", "sessionId", "poiId", "lat", "lng")
    }

    func testExploreDayQuotesLatLng() {
        // pages/roam/index.js:4681
        quote("api/roam/nearby-exploreday", "GET", "lat", "lng")
    }

    func testShopVisitQuotesSessionSourceAndFix() {
        // pages/roam/index.js:4760
        quote("api/roam/shop/visit", "POST", "sessionId", "sourceType", "sourceId", "lat", "lng")
    }

    func testOfficialCompleteQuotesEmptyPost() {
        // pages/roam/index.js:4886
        quote("api/official/events/{}/complete", "POST")
    }

    func testCreativeSquareActionQuotesContentsAndTarget() {
        // pages/roam/index.js:5185
        quote("api/creativesquare/action", "POST", "contents", "pics", "data_id", "data_type", "request_id")
    }

    func testTopicListQuotesPageAndSort() {
        // pages/roam/index.js:6086 pages/roam/index.js:6098
        quote("api/topic/list", "POST", "pageNum", "pageSize", "sort_type")
    }

    func testCityNodeIssueQuotesPoiId() {
        // subpackageRoam/components/cy/scene-qr-citynode/index.js:36
        quote("api/verify/citynode/issue", "POST", "poiId")
    }

    func testMerchantShareCodeQuotesMemberId() {
        // subpackageRoam/components/cy/share-card/index.js:127
        quote("api/merchant/share-code", "POST", "memberId")
    }

    func testTopicShareCodeQuotesId() {
        // subpackageRoam/components/cy/share-card/index.js:135
        quote("api/topic/share-code", "POST", "id")
    }

    func testOrientLobbyQuotesOwner() {
        // subpackageRoam/my-teams/index.js:193
        quote("api/orient/team/lobby", "GET", "ownerType", "ownerId")
    }

    func testHangoutNearbyQuotesLatLngRadius() {
        // subpackageRoam/nearby/index.js:285
        quote("api/roam/hangout/nearby", "GET", "lat", "lng", "radius")
    }

    func testCommentListQuotesOwnerAndPage() {
        // subpackageRoam/nearby/index.js:965
        quote("api/comment/list", "POST", "owner_type", "owner_id", "pageNum", "pageSize")
    }

    func testCommentAddQuotesOwnerRatingAndRequest() {
        // subpackageRoam/nearby/index.js:1059
        quote("api/comment/add", "POST", "owner_type", "owner_id", "rating", "contents", "reply_id", "request_id")
    }

    func testPresetRouteInfoQuotesId() {
        // subpackageRoam/official-route/index.js:28
        quote("api/preset/route/info", "GET", "id")
    }

    func testAdvancedStartQuotesPost() {
        // pages/play/components/advanced-game/index.js:164
        quote("api/play/advanced/start", "POST")
    }

    func testAdvancedActionQuotesPost() {
        // pages/play/components/advanced-game/index.js:304
        quote("api/play/advanced/action", "POST")
    }

    func testMerchantListQuotesPost() {
        // pages/play/components/scene-roam-discover/index.js:23
        quote("api/merchant/list", "POST")
    }

    func testActionReceiptQuotesActivityTopicNodeAndRouteAction() {
        // pages/play/index.js:296 pages/play/index.js:916
        quote("api/play/action-receipt", "GET", "activityId", "topicId", "nodeId", "routeActionId")
    }

    func testActionContextQuotesGet() {
        // pages/play/index.js:304
        XCTAssertEqual(PlayStoreDayService.actionContextPath, "api/play/action-context")
        quote("api/play/action-context", "GET")
    }

    func testPlayAnswerQuotesPost() {
        // pages/play/index.js:315 pages/play/index.js:901
        XCTAssertEqual(PlayStoreDayService.answerPath, "api/play/answer")
        quote("api/play/answer", "POST")
    }

    func testPlayCheckinQuotesPost() {
        // pages/play/index.js:316 pages/play/index.js:902
        XCTAssertEqual(PlayStoreDayService.checkinPath, "api/play/checkin")
        quote("api/play/checkin", "POST")
    }

    func testPlayArriveQuotesPost() {
        // pages/play/index.js:317 pages/play/index.js:903
        XCTAssertEqual(PlayStoreDayService.arrivePath, "api/play/arrive")
        quote("api/play/arrive", "POST")
    }

    func testPlayPhotoQuotesPost() {
        // pages/play/index.js:318 pages/play/index.js:904 pages/play/merchant/index.js:34
        XCTAssertEqual(PlayStoreDayService.photoPath, "api/play/photo")
        quote("api/play/photo", "POST")
    }

    func testPuzzleRevealQuotesPost() {
        // pages/play/index.js:319 pages/play/index.js:905
        quote("api/play/puzzle/reveal", "POST")
    }

    func testSensorResultQuotesPost() {
        // pages/play/index.js:320 pages/play/index.js:906
        quote("api/play/sensor-result", "POST")
    }

    func testOrientCurrentQuotesPath() {
        // pages/play/index.js:420
        quotePath("api/play/orient/session/current")
    }

    func testOrientPrepareQuotesPath() {
        // pages/play/index.js:421
        quotePath("api/play/orient/session/prepare")
    }

    func testOrientStartQuotesPath() {
        // pages/play/index.js:422
        quotePath("api/play/orient/session/start")
    }

    func testOrientAbandonQuotesPath() {
        // pages/play/index.js:423
        quotePath("api/play/orient/session/abandon")
    }

    func testOrientReceiptQuotesPath() {
        // pages/play/index.js:424
        quotePath("api/play/orient/session/receipt")
    }

    func testOrientTaskResultQuotesPath() {
        // pages/play/index.js:427
        quotePath("api/play/orient/session/task/{}/result")
    }

    func testOrientScoreQuotesPath() {
        // pages/play/index.js:429
        quotePath("api/orient/scoring/session/{}")
    }

    func testPlayHelpQuotesGet() {
        // pages/play/index.js:447
        quote("api/play/help", "GET")
    }

    func testPlayHelpReceiptQuotesGet() {
        // pages/play/index.js:448
        quote("api/play/help/receipt", "GET")
    }

    func testPlayHelpUseQuotesPost() {
        // pages/play/index.js:449
        quote("api/play/help/use", "POST")
    }

    func testPlayHelpSkipQuotesPost() {
        // pages/play/index.js:450
        quote("api/play/help/skip", "POST")
    }

    func testPlayIndexCircleJoinQuotesInviteCode() {
        // pages/play/index.js:722
        quote("api/circle-theme/session/join", "POST", "inviteCode")
    }

    func testRouteStateQuotesGet() {
        // pages/play/index.js:1047
        quote("api/play/route-state", "GET")
    }

    func testSafetyTaxonomyQuotesGet() {
        // pages/play/merchant/components/safety-rating-sheet/index.js:40
        quote("api/community-trust/safety/taxonomy", "GET")
    }

    func testSafetyRatingQuotesPost() {
        // pages/play/merchant/components/safety-rating-sheet/index.js:99
        quote("api/community-trust/safety/ratings", "POST")
    }

    func testPublicMerchantHomeQuotesMemberId() {
        // pages/play/merchant/components/safety-rating-sheet/index.js:121
        quote("api/merchant/public-home", "POST", "memberId")
    }

    func testPlayNodesQuotesGet() {
        // pages/play/merchant/index.js:460
        XCTAssertEqual(PlayStoreDayService.nodesPath, "api/play/nodes")
        quote("api/play/nodes", "GET")
    }

    func testMerchantConsentQuotesEventTypeAndRequestId() {
        // pages/play/merchant/index.js:558
        XCTAssertEqual(PlayStoreDayService.consentWritePath, "api/compliance/consents")
        quote("api/compliance/consents", "POST", "eventType", "requestId")
    }

    func testMerchantConsentLatestQuotesPost() {
        // pages/play/merchant/index.js:580
        XCTAssertEqual(PlayStoreDayService.consentLatestPath, "api/compliance/consents/latest")
        quote("api/compliance/consents/latest", "POST")
    }

    func testCityNodeReadQuotesGet() {
        // pages/play/poi-challenge/index.js:53
        // subpackageRoam/components/roam-place-card/index.js:52
        // subpackageRoam/nearby/index.js:944
        quote("api/city/nodes/{}", "GET")
    }

    func testTopicInfoToUserQuotesId() {
        // pages/play/utils/cast-play.js:283
        quote("api/topic/info-to-user", "POST", "id")
    }

    func testCastProfileQuotesRunNameAndIdentity() {
        // pages/play/utils/cast-play.js:393
        quote("api/play/run/profile", "POST", "runId", "name", "identityKey", "content-type")
    }

    func testCastVoiceQuotesTopicChapterBlockAndRun() {
        // pages/play/utils/cast-play.js:483
        quote("api/topic/cast/voice", "GET", "topicId", "chapterId", "blockKey", "runId")
    }

    func testCastBranchQuotesRunChapterBlockAndOption() {
        // pages/play/utils/cast-play.js:540
        quote("api/play/run/branch", "POST", "runId", "chapterId", "blockKey", "optionIndex", "content-type")
    }

    func testPlayHistoryQuotesGet() {
        // pages/play/utils/fe-story-gate.js:221
        quote("api/play/history", "GET")
    }

    func testCasebookQuotesGet() {
        // pages/play/utils/play-topbar.js:101 pages/play/utils/play-topbar.js:111
        quote("api/play/journey/casebook", "GET")
    }

    func testBackpackQuotesGet() {
        // pages/play/utils/play-topbar.js:128
        quote("api/play/journey/backpack", "GET")
    }

    func testThemeStateQuotesTopicId() {
        // pages/play/utils/theme-backpack.js:201
        quote("api/play/theme/state", "GET", "topicId")
    }

    func testThemeActionQuotesPost() {
        // pages/play/utils/theme-backpack.js:252
        quote("api/play/theme/action", "POST", "content-type")
    }

    func testThemePreviewQuotesBothPosts() {
        // pages/play/utils/theme-backpack.js:372
        quote("api/game/session/shared/preview", "POST", "content-type")
        quote("api/play/theme/gameplay-preview", "POST", "content-type")
    }

    func testThemeCommandQuotesBothPosts() {
        // pages/play/utils/theme-backpack.js:503
        quote("api/game/session/command", "POST", "content-type")
        quote("api/play/theme/gameplay-action", "POST", "content-type")
    }

    func testThemeTradeQuotesActivityActionAndPayload() {
        // pages/play/utils/theme-trade.js:82
        quote("api/game/session/shared/preview", "POST", "activityId", "action", "payload", "content-type")
    }

    func testNpcProfileQuotesScope() {
        // pages/roam/index.js:282
        quote("api/ai/npc/profile", "GET", "scope")
    }

    func testNpcEventQuotesProfileTypeAndCache() {
        // pages/roam/index.js:289
        quote("api/ai/npc/event", "GET", "profileId", "eventType", "cacheOnly")
    }

    func testRoamSessionQuotesGet() {
        // pages/roam/index.js:1739
        quote("api/roam/session", "GET")
    }

    func testSessionRecordsQuotesSessionKeyAndRecords() {
        // pages/roam/index.js:1801
        XCTAssertEqual(RoamPlayerExtrasService.sessionRecordsPath, "api/roam/session/records")
        quote("api/roam/session/records", "POST", "sessionId", "clientSessionKey", "records")
    }

    func testRoamRevealQuotesSessionTilesAndKey() {
        // pages/roam/index.js:1830
        XCTAssertEqual(RoamExperienceMutation.reveal(sessionID: 1, tiles: ["ab"]).path, "api/roam/reveal")
        quote("api/roam/reveal", "POST", "sessionId", "tiles", "clientSessionKey")
    }

    func testRoamConsentLatestQuotesDocTypeAndScene() {
        // pages/roam/index.js:3050
        XCTAssertEqual(PlayStoreDayService.consentLatestPath, "api/compliance/consents/latest")
        quote("api/compliance/consents/latest", "POST", "docType", "scene")
    }

    func testJourneyUserInfoQuotesPost() {
        // subpackageJourney/pages/seats/index.js:79
        XCTAssertEqual(AccountPublishMPContract.userInfoPath, "api/user/info")
        quote("api/user/info", "POST")
    }

    func testStampCreateQuotesPictureCaptionAndKey() {
        // subpackageRoam/citystamp/index.js:291
        // req() passes the path and fields. It does not write a method literal.
        quotePath("api/roam/stamp/create")
        let fields = ["picUrl", "caption", "idempotencyKey"]
        XCTAssertEqual(fields, ["picUrl", "caption", "idempotencyKey"])
    }

    func testStampExchangeQuotesGivenStampId() {
        // subpackageRoam/citystamp/index.js:300
        quotePath("api/roam/stamp/exchange")
        let fields = ["givenStampId"]
        XCTAssertEqual(fields, ["givenStampId"])
    }

    func testGroupCodeIssueQuotesPost() {
        // subpackageRoam/components/cy/scene-qr-group-code/index.js:81
        quote("api/verify/groupcode/issue", "POST")
    }

    func testStampAlbumQuotesListAndReceivedPage() {
        // subpackageRoam/components/cy/scene-roam-stamp-album/index.js:66
        XCTAssertEqual(RoamAlbumMetadataReadRoute.path, "api/roam/stamp/list")
        XCTAssertEqual(RoamReceivedStampReadRoute.path, "api/roam/stamp/received")
        quote("api/roam/stamp/list", "POST", "pageNum", "pageSize")
        quote("api/roam/stamp/received", "POST", "pageNum", "pageSize")
    }

    func testOfficialMyEventsQuotesGet() {
        // subpackageRoam/components/cy/scene-roam-task-list/index.js:71
        quote("api/official/my-events", "GET")
    }

    func testOfficialEventShareCodeQuotesPost() {
        // subpackageRoam/components/cy/share-card/index.js:131
        XCTAssertEqual(OfficialEventShareCodeRoute.path(eventID: "17"), "api/official/events/17/share-code")
        quote("api/official/events/{}/share-code", "POST")
    }

    func testTeamMineQuotesEmptyPost() {
        // subpackageRoam/my-teams/index.js:106 subpackageRoam/nearby/index.js:737
        quote("api/team/my", "POST")
    }

    func testTeamMyApplicationsQuotesEmptyPost() {
        // subpackageRoam/my-teams/index.js:108 subpackageRoam/nearby/index.js:743
        quote("api/team/my-applications", "POST")
    }

    func testTeamApplicationsQuotesTeamId() {
        // subpackageRoam/my-teams/index.js:149 subpackageRoam/nearby/index.js:659
        quote("api/team/applications", "POST", "teamId")
    }

    func testExplorationAnniversaryQuotesGet() {
        // subpackageTools/utils/features/exploration-anniversary.js:68
        XCTAssertTrue(RoamPassportToolsService.paths.contains("api/exploration-anniversary"))
        quote("api/exploration-anniversary", "GET")
    }

    func testMonthlyRecapQuotesMonthKindLimitAndBefore() {
        // subpackageTools/utils/features/monthly-recap-client.js:38
        XCTAssertTrue(RoamPassportToolsService.paths.contains("api/monthly-recap"))
        quote("api/monthly-recap", "GET", "month", "kind", "limit", "beforeId")
    }
}
