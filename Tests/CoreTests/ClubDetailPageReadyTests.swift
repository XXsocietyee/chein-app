import XCTest
@testable import QuestifyCore

final class ClubDetailPageReadyTests: XCTestCase {
    private let dash = ClubDetailPageModel.unknownMark

    private func state(_ json: String?, loading: Bool = false, failure: Error? = nil, signedIn: Bool = true,
                       grant: ClubDetailManageGrant? = nil, hasCommunity: Bool = false, hasGovernance: Bool = false,
                       events: ClubDetailEventsSummary? = nil) -> ClubDetailPageState {
        ClubDetailPageModel.resolve(
            loading: loading,
            payload: json.map { Data($0.utf8) },
            failure: failure,
            signedIn: signedIn,
            grant: grant,
            hasCommunity: hasCommunity,
            hasGovernance: hasGovernance,
            eventsSummary: events
        )
    }

    private func ready(_ json: String, signedIn: Bool = true, grant: ClubDetailManageGrant? = nil,
                       hasCommunity: Bool = false, hasGovernance: Bool = false,
                       events: ClubDetailEventsSummary? = nil) throws -> ClubDetailPageContent {
        guard case .ready(let content) = state(json, signedIn: signedIn, grant: grant, hasCommunity: hasCommunity, hasGovernance: hasGovernance, events: events) else {
            XCTFail("expected a ready club")
            throw TestFailure()
        }
        return content
    }

    func testMissingHostCityAndLevelUsePendingCopy() {
        XCTAssertEqual(ClubDetailHeaderFact.known(" 阿青 "), "阿青")
        XCTAssertNil(ClubDetailHeaderFact.known(" "))
        XCTAssertNil(ClubDetailHeaderFact.known(nil))
        XCTAssertNil(ClubDetailHeaderFact.known(dash))
        XCTAssertEqual(ClubDetailHeaderFact.pendingKey, "club.detail.factPending")
        XCTAssertEqual(ClubDetailPageModel.countText(nil), dash)
        XCTAssertEqual(ClubDetailPageModel.levelText(0), dash)
    }

    func testUnknownMarkIsAnEmDashAndNotZero() {
        XCTAssertEqual(dash.unicodeScalars.map(\.value), [0x2014])
        XCTAssertNotEqual(dash, "0")
        XCTAssertNotEqual(dash, "0.0")
        XCTAssertEqual(ClubDetailPageModel.countText(nil), dash)
        XCTAssertEqual(ClubDetailPageModel.countText(0), "0")
        XCTAssertEqual(ClubDetailPageModel.countText(-1), dash)
        XCTAssertEqual(ClubDetailPageModel.levelText(nil), dash)
        XCTAssertEqual(ClubDetailPageModel.levelText(0), dash)
        XCTAssertEqual(ClubDetailPageModel.levelText(6), dash)
        XCTAssertEqual(ClubDetailPageModel.levelText(3), "L3")
    }

    func testLoadingEmptyAndErrorStaySeparate() {
        XCTAssertEqual(state(nil, loading: true), .loading)
        XCTAssertEqual(state("   \n", loading: true), .loading)
        XCTAssertEqual(state(nil, loading: false), .empty)
        XCTAssertEqual(state("{}", loading: false), .empty)
        XCTAssertEqual(state("null", loading: false), .empty)
        XCTAssertEqual(state(#"{"code":200,"data":null}"#), .empty)
        XCTAssertEqual(state(#"{"code":200,"data":{}}"#), .empty)
        XCTAssertEqual(state(#"{"code":401,"msg":"请先登录"}"#), .error(titleKey: "club.signInRequired"))
        XCTAssertEqual(state(#"{"code":403}"#), .error(titleKey: "club.accessDenied"))
        XCTAssertEqual(state(#"{"code":500}"#), .error(titleKey: "club.loadFailed"))
        XCTAssertEqual(state(#"{"id":0}"#), .error(titleKey: "club.loadFailed"))
        XCTAssertEqual(state(#"{"id":"81"}"#), .error(titleKey: "club.loadFailed"))
        XCTAssertEqual(state("[]"), .error(titleKey: "club.loadFailed"))
        XCTAssertEqual(state(#"{"id":81,"memberCount":true}"#), .error(titleKey: "club.loadFailed"))
        XCTAssertEqual(state(#"{"id":81,"memberCount":1.5}"#), .error(titleKey: "club.loadFailed"))
        XCTAssertEqual(state(#"{"id":81,"memberCount":"2"}"#), .error(titleKey: "club.loadFailed"))
        let payload = #"{"id":81,"name":"Kept"}"#
        XCTAssertEqual(state(payload, failure: ClubReadFailure.unauthorized(message: "hidden")), .error(titleKey: "club.signInRequired"))
        XCTAssertEqual(ClubDetailPageModel.titleKey(for: ClubReadFailure.forbidden(message: nil)), "club.accessDenied")
        XCTAssertEqual(ClubDetailPageModel.titleKey(for: ClubReadFailure.membershipRequired), "club.membersUnavailable")
        XCTAssertEqual(ClubDetailPageModel.titleKey(for: APIError.notConfigured), "club.unavailable")
        XCTAssertEqual(ClubDetailPageModel.titleKey(for: APIError.malformedResponse), "club.loadFailed")
    }

    func testOmittedNumbersStayUnknownAndLiteralZeroStaysZero() throws {
        let omitted = try ready(#"{"id":81,"name":"Synthetic Club"}"#)
        XCTAssertEqual(omitted.memberCountText, dash)
        XCTAssertEqual(omitted.levelText, dash)
        XCTAssertEqual(omitted.leaderText, dash)
        XCTAssertEqual(omitted.cityText, dash)
        XCTAssertEqual(omitted.typeText, dash)
        XCTAssertTrue(omitted.facts.allSatisfy(\.isUnknown))
        XCTAssertEqual(omitted.facts.map(\.id), [
            ClubDetailPageAccessibility.leader, ClubDetailPageAccessibility.level,
            ClubDetailPageAccessibility.city, ClubDetailPageAccessibility.memberCount,
        ])

        let nulled = try ready(#"{"id":81,"name":"Synthetic Club","memberCount":null,"level":null,"leaderName":"  ","city":""}"#)
        XCTAssertEqual(nulled.memberCountText, dash)
        XCTAssertEqual(nulled.levelText, dash)
        XCTAssertEqual(nulled.leaderText, dash)
        XCTAssertEqual(nulled.cityText, dash)
        XCTAssertEqual(nulled.name, "Synthetic Club")

        let zero = try ready(#"{"id":81,"name":"Synthetic Club","memberCount":0,"level":0}"#)
        XCTAssertEqual(zero.memberCountText, "0")
        XCTAssertEqual(zero.levelText, dash)
        XCTAssertFalse(zero.facts.first { $0.id == ClubDetailPageAccessibility.memberCount }?.isUnknown ?? true)
        XCTAssertTrue(zero.facts.first { $0.id == ClubDetailPageAccessibility.level }?.isUnknown ?? false)

        let negative = try ready(#"{"id":81,"memberCount":-3,"level":-1}"#)
        XCTAssertEqual(negative.memberCountText, dash)
        XCTAssertEqual(negative.levelText, dash)
        XCTAssertEqual(negative.name, "")
    }

    func testKnownFactsAndBlankCityDoNotBorrowAnotherField() throws {
        let club = try ready(#"{"id":81,"name":" 山野社 ","leaderName":" 阿青 ","city":" 杭州 ","address":"Other","clubType":"户外","memberCount":12,"level":4,"joinPolicy":1,"joinPolicySupported":true}"#)
        XCTAssertEqual(club.name, "山野社")
        XCTAssertEqual(club.leaderText, "阿青")
        XCTAssertEqual(club.cityText, "杭州")
        XCTAssertEqual(club.typeText, "户外")
        XCTAssertEqual(club.memberCountText, "12")
        XCTAssertEqual(club.levelText, "L4")
        XCTAssertEqual(club.joinPolicyKey, "club.detail.joinPolicy.review")

        let omittedCity = try ready(#"{"id":81,"address":"西湖","clubTypes":"徒步","joinPolicySupported":true}"#)
        XCTAssertEqual(omittedCity.cityText, "西湖")
        XCTAssertEqual(omittedCity.typeText, "徒步")
        XCTAssertEqual(omittedCity.joinPolicyKey, "club.detail.joinPolicy.open")

        let blankCity = try ready(#"{"id":81,"city":" ","address":"西湖","clubType":" ","clubTypes":"徒步"}"#)
        XCTAssertEqual(blankCity.cityText, dash)
        XCTAssertEqual(blankCity.typeText, dash)
        XCTAssertNil(blankCity.joinPolicyKey)
    }

    func testManagementStaysCapabilityGatedAndMissingChannelsStayHidden() throws {
        let guest = try ready(#"{"id":81,"isOwner":true,"isJoined":true,"viewerIsAdmin":true}"#, signedIn: false)
        XCTAssertFalse(guest.showsManageTab)
        XCTAssertEqual(guest.tabs, ClubDetailTab.publicTabs)
        XCTAssertFalse(guest.showsRoleManagement)
        XCTAssertFalse(guest.showsAppealEntry)
        XCTAssertFalse(guest.showsChat)
        XCTAssertFalse(guest.showsChannels)
        XCTAssertFalse(guest.showsLeaderboard)
        XCTAssertFalse(guest.showsOwnerAI)

        let member = try ready(#"{"id":81,"isJoined":true}"#)
        XCTAssertFalse(member.showsManageTab)
        XCTAssertFalse(member.showsRoleManagement)
        XCTAssertTrue(member.showsAppealEntry)
        XCTAssertTrue(member.showsChat)
        // 2026-11-13: `/api/club/channels` is live on TEST r2 aa3dcc89d, so members see Channels (owner rule: nothing hidden).
        XCTAssertTrue(member.showsChannels)
        XCTAssertTrue(member.showsLeaderboard)
        XCTAssertFalse(member.showsOwnerAI)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/club/channels"), .liveInProduction)
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/channels"))

        let owner = try ready(#"{"id":81,"isOwner":true,"isJoined":true}"#)
        XCTAssertTrue(owner.showsManageTab)
        XCTAssertEqual(owner.tabs, ClubDetailTab.publicTabs + [.manage])
        XCTAssertTrue(owner.showsRoleManagement)
        XCTAssertTrue(owner.showsMemberManagement)
        XCTAssertTrue(owner.showsCooperationEntry)
        XCTAssertTrue(owner.showsOwnerAI)

        let grant = ClubDetailManageGrant(clubID: 81, permissions: ["club:write"], hasEventScope: false)
        let delegated = try ready(#"{"id":81,"isJoined":true}"#, grant: grant)
        XCTAssertTrue(delegated.showsManageTab)
        XCTAssertFalse(delegated.showsRoleManagement)

        let foreign = ClubDetailManageGrant(clubID: 99, permissions: ["club:role:manage", "club:write"], hasEventScope: true)
        let narrowed = try ready(#"{"id":81,"isJoined":true}"#, grant: foreign)
        XCTAssertFalse(narrowed.showsManageTab)
        XCTAssertFalse(narrowed.showsRoleManagement)

        let unavailable = try ready(#"{"id":81,"isOwner":true,"viewerIdentityUnavailable":true}"#, grant: grant)
        XCTAssertFalse(unavailable.showsManageTab)
        XCTAssertFalse(unavailable.showsChat)
        XCTAssertFalse(unavailable.showsLeaderboard)
        XCTAssertFalse(unavailable.showsOwnerAI)
    }

    func testPostsEventsAndMoneyFlags() throws {
        let bare = try ready(#"{"id":81,"isJoined":true}"#)
        XCTAssertEqual(bare.posts, .unavailable)
        XCTAssertEqual(bare.events, .unavailable)
        XCTAssertFalse(bare.showsSettlementWithdraw)
        XCTAssertFalse(bare.paymentEnabled)
        XCTAssertFalse(bare.payoutEnabled)
        XCTAssertFalse(bare.withdrawalEnabled)
        XCTAssertFalse(bare.virtualGoodsEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)

        let hosted = try ready(#"{"id":81,"isJoined":true}"#, hasCommunity: true, hasGovernance: true)
        XCTAssertEqual(hosted.posts, .ready)
        XCTAssertEqual(hosted.events, .loading)
        let emptyEvents = try ready(#"{"id":81}"#, hasGovernance: true, events: ClubDetailEventsSummary(state: .empty))
        XCTAssertEqual(emptyEvents.events, .empty)
        let failedEvents = try ready(#"{"id":81}"#, hasGovernance: true, events: ClubDetailEventsSummary(state: .failed(localizationKey: "club.gov.denied")))
        XCTAssertEqual(failedEvents.events, .error(titleKey: "club.gov.denied"))
        let loadedEvents = try ready(#"{"id":81}"#, hasGovernance: true, events: ClubDetailEventsSummary(state: .loaded(current: 0, ended: 2, upcoming: [])))
        XCTAssertEqual(loadedEvents.events, .ready)
    }

    func testAcceptedPayloadWinsOverTheLoadingFlag() throws {
        let club = try ready(#"{"id":81,"name":"Synthetic Club","memberCount":2}"#)
        XCTAssertEqual(club.memberCountText, "2")
        guard case .ready(let same) = state(#"{"id":81,"name":"Synthetic Club","memberCount":2}"#, loading: true) else {
            return XCTFail("an accepted payload is not loading")
        }
        XCTAssertEqual(same, club)
    }

#if DEBUG
    func testDebugFixtureDataCoversReadyUnknownZeroAndEmpty() throws {
        let readyClub = try ready(ClubDetailPageFixtureData.ready)
        XCTAssertEqual(readyClub.id, 81)
        XCTAssertEqual(readyClub.memberCountText, "2")
        XCTAssertEqual(readyClub.levelText, "L3")
        XCTAssertEqual(readyClub.joinPolicyKey, "club.detail.joinPolicy.review")
        XCTAssertTrue(readyClub.showsChat)
        XCTAssertTrue(readyClub.showsChannels)

        let unknown = try ready(ClubDetailPageFixtureData.unknownNumbers)
        XCTAssertEqual(unknown.memberCountText, dash)
        XCTAssertEqual(unknown.levelText, dash)
        XCTAssertEqual(unknown.leaderText, dash)

        let zero = try ready(ClubDetailPageFixtureData.literalZeroMembers)
        XCTAssertEqual(zero.memberCountText, "0")
        XCTAssertEqual(zero.levelText, dash)

        XCTAssertEqual(state(ClubDetailPageFixtureData.emptyObject), .empty)
        guard case .ready(let envelope) = state(ClubDetailPageFixtureData.envelope) else {
            return XCTFail("envelope data is the same detail contract")
        }
        XCTAssertEqual(envelope.id, 81)
        XCTAssertEqual(envelope.memberCountText, dash)
        XCTAssertFalse(ClubDetailPageFixtureData.ready.contains("http"))
        XCTAssertFalse(ClubDetailPageFixtureData.envelope.contains("http"))
    }
#endif
}

private struct TestFailure: Error {}
