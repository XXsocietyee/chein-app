import XCTest
@testable import Questify

/// §九 U08 (cloud-h7): the battle report, memory and boards read the real server wire.
@MainActor final class PostGameProjectionTests: XCTestCase {
    private func ok(_ json: String) -> JourneyEnvelope {
        JourneyEnvelope(httpStatus: 200, code: "200", netFail: false, message: nil, dataJSON: Data(json.utf8), receiptReread: false)
    }

    func testReportShowsServerResultScoreAndRank() {
        let scope = JourneyRunScope(activityID: nil, topicID: "9", runID: "77", topicName: "城", registrationID: nil)
        let phase = PlayerJourneyProjection.report(ok(#"""
        {"topicId":9,"runId":77,"scopeKind":"RUN","runState":"COMPLETED","completionKind":"LEGITIMATE_COMPLETION",
         "completedNodes":5,"totalNodes":5,"elapsedSeconds":61,"score":{"state":"SCORED","score":88,"penalties":0},
         "rank":{"rank":2,"score":5,"qualified":true},"nodes":[{"nodeId":3,"name":"桥","completionMode":"REVEALED","scored":false}]}
        """#), scope: scope)
        guard case .ready(let report) = phase else { return XCTFail("\(phase)") }
        XCTAssertEqual(report.result, .legitimate)
        XCTAssertEqual(report.nodesText, "5/5")
        XCTAssertEqual(report.elapsedText, "01:01")
        XCTAssertEqual(report.score, 88)
        XCTAssertNil(report.penaltyText, "0 penalties is no penalty row")
        XCTAssertEqual(report.rank, 2)
        XCTAssertEqual(report.rankBasisCount, 5)
        XCTAssertEqual(report.nodes.first?.mode, .revealed)
        XCTAssertNil(report.nodes.first?.score)
        XCTAssertTrue(report.finished)

        let other = PlayerJourneyProjection.report(ok(#"{"runId":78,"scopeKind":"RUN","runState":"COMPLETED"}"#), scope: scope)
        XCTAssertEqual(other, .gone, "another run is not shown as this one")
    }

    func testMemoryHidesPeerPhotosWithoutConsentAndRejectsAnotherRun() {
        let phase = PlayerJourneyProjection.memory(ok(#"""
        {"runId":77,"participantCount":2,"photoShareCapability":"UNAVAILABLE","moments":[{"nodeId":3,"name":"桥","picUrl":"https://cdn.example/a.jpg","checkinTime":"2026-11-08 10:00:00"}]}
        """#), runID: "77")
        guard case .ready(let memory) = phase else { return XCTFail("\(phase)") }
        XCTAssertTrue(memory.peerPhotosHidden)
        XCTAssertTrue(memory.hasPhotos)
        XCTAssertEqual(memory.participants, 2)
        XCTAssertEqual(memory.moments.first?.dayText, "2026.11.08")
        if case .ready = PlayerJourneyProjection.memory(ok(#"{"runId":78,"moments":[{"nodeId":3}]}"#), runID: "77") { XCTFail("another run") }
    }

    func testBoardsUseEntriesAndRefuseAnotherScope() {
        let json = #"{"scope":"quest","scopeId":9,"period":"all","scoreBasis":"COMPLETED_NODES","entries":[{"rank":1,"memberId":5,"nickname":"甲","score":null}],"coverage":{"unverifiedRuns":2}}"#
        guard case .ready(let board) = PlayerJourneyProjection.rank(ok(json), scope: "quest", scopeID: "9", period: "all") else { return XCTFail("board") }
        XCTAssertEqual(board.entries.first?.scoreText, "—", "unknown score is not 0")
        XCTAssertEqual(board.unverifiedRuns, 2)
        XCTAssertEqual(board.basis, .completedNodes)
        XCTAssertEqual(PlayerJourneyProjection.rank(ok(json), scope: "quest", scopeID: "10", period: "all"), .failed(nil))
        guard case .ready(let teams) = PlayerJourneyProjection.teams(ok(#"[{"rank":1,"teamId":3,"title":"红队","activeCount":2,"teamDoneCount":1,"totalTasks":4,"mine":true}]"#)) else {
            return XCTFail("teams")
        }
        XCTAssertEqual(teams.entries.first?.scoreText, "1/4")
        XCTAssertEqual(teams.stats.map(\.value), ["1/4", "2"])
        XCTAssertEqual(teams.basis, .wholeTeam)
        XCTAssertEqual(PlayerJourneyProjection.rankTabs(JourneyRunScope(activityID: "4", topicID: nil)).count, 0, "no quest tab without a topic id")
    }

    // JLAND-3: server keys SHARED_TEAM / INDEPENDENT (+ competition), rules from the scopes, nothing when unavailable.
    func testChoicesTilesReadServerKeys() {
        let tiles = PlayerJourneyProjection.tiles(ok(#"""
        {"configState":"TOPIC_DEFAULT","choices":[
         {"key":"SHARED_TEAM","available":true,"hintScope":"PER_TEAM","progressScope":"PER_TEAM","scoreScope":"PER_TEAM","teamCapacity":{"joinedCount":2,"maxMembers":5}},
         {"key":"INDEPENDENT","competition":true,"available":false,"unavailableReason":"TEAM_MODE_DISABLED","hintScope":"PER_MEMBER","progressScope":"PER_MEMBER","scoreScope":"PER_MEMBER"}]}
        """#))
        XCTAssertEqual(tiles.map(\.name), [.together, .compete])
        XCTAssertEqual(tiles.first?.sub, .teamScore)
        XCTAssertEqual(tiles.first?.rules.map(\.kind), [.hint, .progress, .score, .team])
        XCTAssertEqual(tiles.first?.rules.last?.teamText, "2/5")
        XCTAssertNotNil(tiles.last?.reason)
        XCTAssertEqual(PlayerJourneyProjection.activeMode(nil, tiles), "SHARED_TEAM")
        XCTAssertTrue(PlayerJourneyProjection.tiles(ok(#"{"configState":"UNAVAILABLE","choices":[{"key":"SHARED_TEAM"}]}"#)).isEmpty)
    }

    // JLAND-1 / JLAND-4: title from target, 报名已关闭, 去看看 only for VIEW_TARGET; gift claim-by from claimExpiresAt.
    func testLandingReadsTargetAndNextAction() {
        let referral = JourneyLandingLink(query: ["k": "r", "t": "tok"])!
        let json = #"{"state":"VALID","inviter":{"nickname":"甲"},"target":{"type":2,"id":31,"title":"夜游"},"expiresAt":"2026-11-30 20:00:00","registrationState":"CLOSED","nextAction":"VIEW_TARGET"}"#
        guard case .ready(let content) = PlayerJourneyProjection.landing(link: referral, envelope: ok(json), choices: nil, activeMode: nil) else { return XCTFail("ready") }
        XCTAssertEqual(content.title, "夜游")
        XCTAssertEqual(content.primary, .view)
        XCTAssertEqual(content.facts.map(\.kind), [.inviteValid, .signupClosed])
        XCTAssertEqual(content.facts.first?.value, "2026.11.30 20:00")
        XCTAssertEqual(PlayerJourneyProjection.landingTarget(kind: .referral, envelope: ok(json)), PlayerJourneyProjection.LandingTarget(isActivity: true, id: "31"))
        let noView = json.replacingOccurrences(of: "VIEW_TARGET", with: "NONE")
        guard case .ready(let hidden) = PlayerJourneyProjection.landing(link: referral, envelope: ok(noView), choices: nil, activeMode: nil) else { return XCTFail("ready") }
        XCTAssertNil(hidden.primary)

        let gift = JourneyLandingLink(query: ["k": "g", "t": "tok"])!
        let giftJSON = #"{"state":"VALID","product":{"topicId":9,"topicTitle":"城"},"claimExpiresAt":"2026-12-01 10:00","nextAction":"CLAIM_GIFT"}"#
        guard case .ready(let present) = PlayerJourneyProjection.landing(link: gift, envelope: ok(giftJSON), choices: nil, activeMode: nil) else { return XCTFail("gift") }
        XCTAssertEqual(present.title, "城")
        XCTAssertEqual(present.facts.map(\.kind), [.claimBy])
        XCTAssertEqual(present.primary, .claimGift)
        if case .invalid(_, let success) = PlayerJourneyProjection.landing(link: gift, envelope: ok(#"{"state":"CLAIMED"}"#), choices: nil, activeMode: nil) {
            XCTAssertTrue(success)
        } else { XCTFail("claimed gift is the calm invalid state") }
    }

    // JSEAT-1 / JSEAT-2: upper-case seat states, buyer-only invite, invited rows with cancel only when supported.
    func testSeatsReadServerStatesAndFlags() {
        let json = #"""
        {"registrationId":5,"topicId":9,"ownerType":2,"ownerId":31,"seatCount":3,"freeSeats":1,"buyerIsCaller":true,"readOnly":false,"seatCancelSupported":true,
         "seats":[{"seatNo":1,"state":"BUYER"},{"seatNo":2,"state":"INVITED","invitationId":44,"invitationExpiresAt":"2026-11-30 20:00:00"},{"seatNo":3,"state":"AVAILABLE"}]}
        """#
        guard case .ready(let lobby) = PlayerJourneyProjection.seats(ok(json), choices: nil, registrationID: "5") else { return XCTFail("ready") }
        XCTAssertEqual(lobby.circles.map(\.kind), [.me, .invited, .open])
        XCTAssertEqual(lobby.circles.map(\.tappable), [false, false, true])
        XCTAssertTrue(lobby.canInvite)
        XCTAssertEqual(lobby.occupied, 1)
        XCTAssertEqual(lobby.openCount, 1)
        XCTAssertEqual(lobby.invited.map(\.invitationID), ["44"])
        XCTAssertEqual(lobby.invited.first?.canCancel, true)
        XCTAssertTrue(lobby.canGoToStart)
        let facts = PlayerJourneyProjection.seatsFacts(ok(json))!
        XCTAssertEqual(PlayerJourneyProjection.playRoute(facts),
                       .screen(page: "pages/play/index", query: ["topicId": "9", "activityId": "31", "registrationId": "5"]))
        let invite = PlayerJourneyProjection.seatInviteURL(ok(#"{"token":"seat-token","invitationId":44}"#), facts: facts)
        XCTAssertEqual(invite?.path, "/subpackageJourney/pages/landing/index")
        XCTAssertTrue(invite?.query?.contains("k=s") == true && invite?.query?.contains("t=seat-token") == true && invite?.query?.contains("aid=31") == true)
    }

    // JSETTLE-2: activity first (owner type 2), else topic (1); a run id is never the owner.
    func testRatingOwnerPrefersActivity() {
        let both = JourneyRunScope(activityID: "31", topicID: "9", runID: "77")
        XCTAssertEqual(PlayerJourneyProjection.ratingOwner(report: nil, scope: both)?.type, 2)
        XCTAssertEqual(PlayerJourneyProjection.ratingOwner(report: nil, scope: both)?.id, "31")
        XCTAssertEqual(PlayerJourneyProjection.ratingOwner(report: nil, scope: JourneyRunScope(topicID: "9", runID: "77"))?.type, 1)
        XCTAssertNil(PlayerJourneyProjection.ratingOwner(report: nil, scope: JourneyRunScope(runID: "77")))
    }
}
