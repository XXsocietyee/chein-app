import XCTest
@testable import QuestifyCore

/// Mini-program pages/talent/list (俱乐部 tab) presentation. Synthetic rows only.
final class ClubTabPresentationTests: XCTestCase {
    private func club(_ json: String) throws -> ClubRecord { try JSONDecoder().decode(ClubRecord.self, from: Data(json.utf8)) }
    private func home(_ json: String) throws -> ClubHome { try JSONDecoder().decode(ClubHome.self, from: Data(json.utf8)) }

    func testSectionMarksOwnerAndJoinedLikeSourceNormalization() throws {
        let row = try club(#"{"id":7,"name":"Synthetic"}"#)
        XCTAssertTrue(ClubTabPresentation.isOwner(row, in: .owned)); XCTAssertFalse(ClubTabPresentation.isOwner(row, in: .joined))
        XCTAssertTrue(ClubTabPresentation.isJoined(row, in: .joined)); XCTAssertFalse(ClubTabPresentation.isJoined(row, in: .nearby))
        XCTAssertFalse(ClubTabPresentation.tags(row, in: .owned).freeToJoin)
        XCTAssertFalse(ClubTabPresentation.tags(row, in: .joined).freeToJoin)
        XCTAssertTrue(ClubTabPresentation.tags(row, in: .nearby).freeToJoin)
        XCTAssertFalse(ClubTabPresentation.tags(try club(#"{"id":7,"isJoined":true}"#), in: .nearby).freeToJoin)
    }

    func testTagSplittingMatchesSourceSplitList() throws {
        let row = try club(#"{"id":7,"clubType":"[\"Walk\",\" Food \",3]","keywords":"Food，Night;Art、Walk"}"#)
        XCTAssertEqual(ClubTabPresentation.tags(row, in: .nearby).labels, ["Walk", "Food", "Night", "Art"])
        XCTAssertEqual(ClubTabPresentation.splitList("[broken"), [])
        XCTAssertEqual(ClubTabPresentation.splitList(nil), [])
    }

    func testLevelCopy() {
        XCTAssertEqual(ClubTabPresentation.levelKey(3).key, "club.tab.level.3")
        XCTAssertEqual(ClubTabPresentation.levelKey(7).fallback, "Lv.7")
        XCTAssertNil(ClubTabPresentation.levelKey(0).key); XCTAssertNil(ClubTabPresentation.levelKey(0).fallback)
    }

    func testEmptyStatesForPlayersAndMerchants() throws {
        let empty = try home("{}")
        XCTAssertTrue(ClubTabPresentation.isEmpty(empty, nearby: [], merchant: false))
        let owned = try home(#"{"owned":[{"id":1}]}"#)
        XCTAssertFalse(ClubTabPresentation.isEmpty(owned, nearby: [], merchant: false))
        XCTAssertTrue(ClubTabPresentation.isEmpty(owned, nearby: [], merchant: true), "merchants see only same-city clubs")
        XCTAssertTrue(ClubTabPresentation.emptyKeys(merchant: false).offersCreate)
        XCTAssertEqual(ClubTabPresentation.emptyKeys(merchant: true).title, "club.tab.empty.merchant")
        XCTAssertEqual(ClubTabPresentation.feedEmptyKeys(clubCount: 0).detail, "club.tab.feed.noClub.detail")
        XCTAssertEqual(ClubTabPresentation.feedEmptyKeys(clubCount: 2).detail, "club.tab.feed.empty.detail")
    }

    func testPriorityMemberBadgeAndTopicCountCopy() {
        let active = ClubPriorityMemberBadge(prioritySignup: true, topicCount: 3)
        XCTAssertEqual(active.badgeText, "成员优先报名")
        XCTAssertEqual(active.topicCountText, "3 个主题")

        let zeroTopics = ClubPriorityMemberBadge(prioritySignup: false, topicCount: 0)
        XCTAssertNil(zeroTopics.badgeText)
        XCTAssertNil(zeroTopics.topicCountText)

        let missingTopics = ClubPriorityMemberBadge(prioritySignup: true, topicCount: nil)
        XCTAssertEqual(missingTopics.badgeText, "成员优先报名")
        XCTAssertNil(missingTopics.topicCountText)
    }

    func testStrictShapeCheckValidatesClubHomeKeys() {
        let valid: [String: Any] = [
            "owned": [],
            "joined": [],
            "nearby": [],
            "leaderStatus": 1
        ]
        XCTAssertTrue(ClubHomeStrictShapeCheck.validate(jsonObject: valid))
        XCTAssertFalse(ClubHomeStrictShapeCheck.validate(jsonObject: ["owned": [], "joined": [], "nearby": []]))
        XCTAssertFalse(ClubHomeStrictShapeCheck.validate(jsonObject: ["owned": [], "joined": [], "nearby": [], "leaderStatus": NSNull()]))
    }
}

final class ClubTabTopTabTests: XCTestCase {
    func testTopTabsMatchSourceOrderAndCopy() {
        XCTAssertEqual(ClubTabPresentation.TopTab.allCases, [.feed, .club])
        XCTAssertEqual(ClubTabPresentation.TopTab.feed.key, "club.tab.top.feed")
        XCTAssertEqual(ClubTabPresentation.TopTab.club.key, "club.tab.top.club")
    }
}

/// pages/talent/list page model. Synthetic home objects only. No route is opened.
final class ClubTabPageModelTests: XCTestCase {
    private func object(_ json: String) throws -> [String: Any] { try ClubTabPageFixtureData.object(json) }

    func testUnknownMarkIsAnEmDash() {
        XCTAssertEqual(ClubTabPageModel.unknownMark.unicodeScalars.map(\.value), [0x2014])
        XCTAssertEqual(ClubTabPageModel.loadingIdentifier, "club.home.loading")
        XCTAssertEqual(ClubTabPageModel.emptyIdentifier, "clubTab.empty")
        XCTAssertEqual(ClubTabPageModel.errorIdentifier, "club.home.error")
        XCTAssertEqual(ClubTabPageModel.unknownIdentifier, "club.home.unknown")
        XCTAssertNotEqual(ClubTabPageModel.unknownMark, "0")
    }

    func testWithheldFailedAndLoadingStayDistinct() {
        let loading = ClubTabPageModel.project(homeData: nil, inFlight: true, failed: true)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.accessibilityIdentifier, ClubTabPageModel.loadingIdentifier)
        XCTAssertEqual(loading.titleKey, "club.loading")
        XCTAssertFalse(loading.showsCreateClub)
        XCTAssertEqual(loading.eventCount.text, ClubTabPageModel.unknownMark)

        let failed = ClubTabPageModel.project(homeData: nil, failed: true)
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.titleKey, "club.loadFailed")
        XCTAssertEqual(failed.detailKey, "club.retryHint")
        XCTAssertFalse(failed.showsCreateClub)

        let withheld = ClubTabPageModel.project(homeData: nil)
        XCTAssertEqual(withheld.phase, .unknown)
        XCTAssertEqual(withheld.titleKey, "club.tab.unknown")
        XCTAssertEqual(withheld.leader.ownedCount.text, ClubTabPageModel.unknownMark)
        XCTAssertEqual(withheld.leader.maxOwned.text, ClubTabPageModel.unknownMark)
        XCTAssertEqual(withheld.eventCount.text, ClubTabPageModel.unknownMark)
        XCTAssertFalse(withheld.showsCreateClub)
        XCTAssertFalse(withheld.leader.canCreate)
        assertCapabilitiesStayOff(withheld)
    }

    func testReadyHomeKeepsLiteralCountsAndExplicitCreate() throws {
        let home = try object(ClubTabPageFixtureData.ready)
        let model = ClubTabPageModel.project(homeData: home)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.accessibilityIdentifier, ClubTabPageModel.readyIdentifier)
        XCTAssertTrue(model.showsCreateClub)
        XCTAssertEqual(model.leader.isClubLeader, true)
        XCTAssertEqual(model.leader.ownedCount.text, "1")
        XCTAssertEqual(model.leader.maxOwned.text, "2")
        XCTAssertEqual(model.rows.map(\.id), [81, 82])
        XCTAssertEqual(model.rows[0].section, .owned)
        XCTAssertEqual(model.rows[0].memberCount.literal, 3)
        XCTAssertEqual(model.rows[0].topicCount.text, "2")
        XCTAssertEqual(model.rows[1].section, .nearby)
        XCTAssertEqual(model.rows[1].memberCount.text, ClubTabPageModel.unknownMark)
        XCTAssertEqual(model.rows[1].topicCount.text, ClubTabPageModel.unknownMark)
        XCTAssertEqual(model.events.map(\.id), [91])
        XCTAssertEqual(model.events[0].signupCount.text, "4")
        XCTAssertEqual(model.eventCount.text, "1")
        XCTAssertEqual(model.feedPhase, .unknown)
        XCTAssertEqual(model.feedClubCount.text, ClubTabPageModel.unknownMark)
        XCTAssertNil(model.unreadBadgeText)
        assertCapabilitiesStayOff(model)

        let merchant = ClubTabPageModel.project(homeData: home, merchant: true)
        XCTAssertEqual(merchant.phase, .ready)
        XCTAssertEqual(merchant.rows.map(\.id), [82])
        XCTAssertFalse(merchant.showsCreateClub)

        let refreshing = ClubTabPageModel.project(homeData: home, inFlight: true)
        XCTAssertEqual(refreshing.phase, .ready)
        let stale = ClubTabPageModel.project(homeData: home, failed: true)
        XCTAssertEqual(stale.phase, .error)
        XCTAssertFalse(stale.showsCreateClub)
        XCTAssertTrue(stale.rows.isEmpty)
    }

    func testEmptyListKeepsLiteralZeroAndHidesCreate() throws {
        let model = ClubTabPageModel.project(homeData: try object(ClubTabPageFixtureData.empty))
        XCTAssertEqual(model.phase, .empty)
        XCTAssertEqual(model.titleKey, "club.tab.empty")
        XCTAssertEqual(model.detailKey, "club.tab.empty.detail")
        XCTAssertEqual(model.eventCount.literal, 0)
        XCTAssertEqual(model.eventCount.text, "0")
        XCTAssertEqual(model.leader.ownedCount.text, "0")
        XCTAssertEqual(model.leader.isClubLeader, false)
        XCTAssertFalse(model.showsCreateClub)
        let merchant = ClubTabPageModel.project(homeData: try object(ClubTabPageFixtureData.empty), merchant: true)
        XCTAssertEqual(merchant.phase, .empty)
        XCTAssertEqual(merchant.titleKey, "club.tab.empty.merchant")
        XCTAssertFalse(merchant.showsCreateClub)
    }

    func testMissingCountsStayEmDashAndDoNotDropTheRow() throws {
        let model = ClubTabPageModel.project(homeData: try object(ClubTabPageFixtureData.unknownCounts))
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.rows[0].memberCount.text, ClubTabPageModel.unknownMark)
        XCTAssertNil(model.rows[0].memberCount.literal)
        XCTAssertEqual(model.rows[0].topicCount.text, ClubTabPageModel.unknownMark)
        XCTAssertEqual(model.events[0].signupCount.text, ClubTabPageModel.unknownMark)
        XCTAssertEqual(model.leader.ownedCount.text, ClubTabPageModel.unknownMark)
        XCTAssertEqual(model.leader.maxOwned.text, ClubTabPageModel.unknownMark)
        XCTAssertNil(model.leader.isClubLeader)
        XCTAssertFalse(model.showsCreateClub)
        XCTAssertNotEqual(model.rows[0].memberCount.text, "0")
        XCTAssertNotEqual(model.events[0].signupCount.text, "0")

        var zero = try object(ClubTabPageFixtureData.ready)
        var owned = zero["owned"] as! [Any]
        var row = owned[0] as! [String: Any]
        row["memberCount"] = 0
        owned[0] = row
        zero["owned"] = owned
        let zeroModel = ClubTabPageModel.project(homeData: zero)
        XCTAssertEqual(zeroModel.rows[0].memberCount.text, "0")
        XCTAssertEqual(zeroModel.rows[0].memberCount.literal, 0)

        row["memberCount"] = "3"
        owned[0] = row
        zero["owned"] = owned
        let textCount = ClubTabPageModel.project(homeData: zero)
        XCTAssertEqual(textCount.phase, .ready)
        XCTAssertEqual(textCount.rows[0].memberCount.text, ClubTabPageModel.unknownMark)
    }

    func testNonObjectLeaderStatusDoesNotUnlockCreate() throws {
        var home = try object(ClubTabPageFixtureData.empty)
        home["leaderStatus"] = 1
        let integer = ClubTabPageModel.project(homeData: home)
        XCTAssertEqual(integer.phase, .empty)
        XCTAssertFalse(integer.showsCreateClub)
        XCTAssertNil(integer.leader.isClubLeader)
        XCTAssertEqual(integer.leader.ownedCount.text, ClubTabPageModel.unknownMark)

        home["leaderStatus"] = ["isClubLeader": true, "ownedCount": 1, "maxOwned": 2, "canCreate": 1]
        let numericFlag = ClubTabPageModel.project(homeData: home)
        XCTAssertEqual(numericFlag.leader.isClubLeader, true)
        XCTAssertFalse(numericFlag.showsCreateClub)
        XCTAssertFalse(numericFlag.leader.canCreate)

        home.removeValue(forKey: "events")
        let missingEvents = ClubTabPageModel.project(homeData: home)
        XCTAssertEqual(missingEvents.phase, .empty)
        XCTAssertEqual(missingEvents.eventCount.text, ClubTabPageModel.unknownMark)
        XCTAssertNotEqual(missingEvents.eventCount.text, "0")

        let malformed = ClubTabPageModel.project(homeData: try object(ClubTabPageFixtureData.malformed))
        XCTAssertEqual(malformed.phase, .error)
        XCTAssertFalse(malformed.showsCreateClub)
        XCTAssertEqual(malformed.eventCount.text, ClubTabPageModel.unknownMark)
    }

    func testUnreadBadgeAndFeedDoNotGuessZero() throws {
        XCTAssertNil(ClubTabPageModel.unreadBadge(granted: false, data: 4))
        XCTAssertNil(ClubTabPageModel.unreadBadge(granted: true, data: 0))
        XCTAssertEqual(ClubTabPageModel.unreadBadge(granted: true, data: 4), "4")
        XCTAssertEqual(ClubTabPageModel.unreadBadge(granted: true, data: NSNull()), ClubTabPageModel.unknownMark)
        XCTAssertEqual(ClubTabPageModel.unreadBadge(granted: true, data: "0"), ClubTabPageModel.unknownMark)
        XCTAssertEqual(ClubTabPageModel.unreadBadge(granted: true, data: true), ClubTabPageModel.unknownMark)
        XCTAssertEqual(ClubTabPageModel.unreadBadge(granted: true, data: -1), ClubTabPageModel.unknownMark)
        XCTAssertEqual(ClubTabPageModel.unreadBadge(granted: true, data: 1.5), ClubTabPageModel.unknownMark)

        let home = try object(ClubTabPageFixtureData.empty)
        let unknownFeed = ClubTabPageModel.project(homeData: home, feedClubCount: nil, feedHasPosts: false)
        XCTAssertEqual(unknownFeed.feedPhase, .unknown)
        XCTAssertEqual(unknownFeed.feedTitleKey, "club.tab.unknown")
        XCTAssertEqual(unknownFeed.feedClubCount.text, ClubTabPageModel.unknownMark)
        XCTAssertNotEqual(unknownFeed.feedTitleKey, "club.tab.feed.noClub")

        let noClub = ClubTabPageModel.project(homeData: home, feedClubCount: 0, feedHasPosts: false)
        XCTAssertEqual(noClub.feedPhase, .empty)
        XCTAssertEqual(noClub.feedTitleKey, "club.tab.feed.noClub")
        XCTAssertEqual(noClub.feedDetailKey, "club.tab.feed.noClub.detail")
        XCTAssertEqual(noClub.feedClubCount.text, "0")

        let posts = ClubTabPageModel.project(homeData: home, unreadGranted: true, unreadData: NSNull(), feedClubCount: 2, feedHasPosts: false)
        XCTAssertEqual(posts.feedTitleKey, "club.tab.feed.empty")
        XCTAssertEqual(posts.unreadBadgeText, ClubTabPageModel.unknownMark)
        let loadingFeed = ClubTabPageModel.project(homeData: home, feedInFlight: true)
        XCTAssertEqual(loadingFeed.feedPhase, .loading)
        let failedFeed = ClubTabPageModel.project(homeData: home, feedFailed: true)
        XCTAssertEqual(failedFeed.feedPhase, .error)
    }

    private func assertCapabilitiesStayOff(_ model: ClubTabPageModel) {
        XCTAssertFalse(model.showsMerchantChoice)
        XCTAssertFalse(model.paymentEnabled)
        XCTAssertFalse(model.payoutEnabled)
        XCTAssertFalse(model.withdrawalEnabled)
        XCTAssertFalse(model.virtualGoodsEnabled)
    }
}
