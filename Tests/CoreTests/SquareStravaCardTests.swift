import XCTest
@testable import QuestifyCore

final class SquareStravaCardTests: XCTestCase {
    func testPostFollowFlagReusesTheCardDecodeAndStaysUnknown() throws {
        let followed = try JSONDecoder().decode(SquarePost.self, from: Data(#"{"id":3,"memberId":9,"isFollowTheUser":1}"#.utf8))
        XCTAssertEqual(followed.isFollowTheUser, true)
        XCTAssertEqual(followed.strava.followed, true)
        let alias = try JSONDecoder().decode(SquarePost.self, from: Data(#"{"id":3,"memberId":9,"viewerFollowing":false}"#.utf8))
        XCTAssertEqual(alias.isFollowTheUser, false)
        let missing = try JSONDecoder().decode(SquarePost.self, from: Data(#"{"id":3,"memberId":9}"#.utf8))
        XCTAssertNil(missing.isFollowTheUser)
        let junk = try JSONDecoder().decode(SquarePost.self, from: Data(#"{"id":3,"memberId":9,"isFollowTheUser":"maybe"}"#.utf8))
        XCTAssertNil(junk.isFollowTheUser)
    }
    func testTextPostStaysATextCard() {
        let card = SquareStravaCard.decode(json: ["nodeTotal": 6, "nodeDoneCount": 2, "completed": true], dataType: 2, dataID: 9)
        XCTAssertFalse(card.showsActivity)
        XCTAssertNil(card.activityID)
        XCTAssertEqual(SquareStravaCard.distanceText(nil), SquareCountDisplay.unknownMark)
        XCTAssertEqual(SquareStravaCard.nodeText(done: nil, total: 6), SquareCountDisplay.unknownMark)
        XCTAssertNotEqual(SquareStravaCard.distanceText(nil), "0 km")
    }

    func testLiteralZeroIsKeptAndActivitySignalsShowTheBlock() {
        let card = SquareStravaCard.decode(json: ["activityId": 4, "distance": 0, "nodeDoneCount": 0, "nodeTotal": 0, "durationSeconds": 0], dataType: 2, dataID: nil)
        XCTAssertTrue(card.showsActivity)
        XCTAssertEqual(card.activityID, 4)
        XCTAssertEqual(SquareStravaCard.distanceText(card.distanceKilometers), "0 km")
        XCTAssertEqual(SquareStravaCard.nodeText(done: card.nodeDone, total: card.nodeTotal), "0/0")
        XCTAssertEqual(SquareStravaCard.durationText(card.durationSeconds), "0s")
        let linked = SquareStravaCard.decode(json: [:], dataType: 1, dataID: 12)
        XCTAssertEqual(linked.activityID, 12)
        XCTAssertTrue(linked.showsActivity)
    }

    func testRouteNeedsTwoPointsAndDropsInvalidCoordinates() {
        XCTAssertTrue(SquareRouteCanvas.unitPoints([SquareRoutePoint(latitude: 1, longitude: 2)]).isEmpty)
        let card = SquareStravaCard.decode(json: [
            "routePolyline": [["lat": 31.2, "lng": 121.4], ["lat": 91.0, "lng": 121.5], ["latitude": 31.3, "longitude": 121.6]]
        ], dataType: 0, dataID: nil)
        XCTAssertEqual(card.route.count, 2)
        XCTAssertEqual(SquareRouteCanvas.unitPoints(card.route).count, 2)
    }

    func testShareOmitsPrivatePosts() {
        let hidden = SquareShareCard.build(id: 8, audience: "PRIVATE", lifecycle: "PUBLISHED", contents: "secret", images: ["https://cdn.example/a.jpg"])
        XCTAssertFalse(hidden.includesPost)
        XCTAssertEqual(hidden.title, SquareShareCard.genericTitle)
        XCTAssertEqual(hidden.path, "pages/talent/list/index?tab=feed")
        XCTAssertNil(hidden.imageURL)
        let shown = SquareShareCard.build(id: 8, audience: "PUBLIC", lifecycle: "PUBLISHED", contents: "hello", images: ["https://cdn.example/a.jpg", "file://local"])
        XCTAssertTrue(shown.includesPost)
        XCTAssertEqual(shown.path, "pages/square/detail/index?id=8")
        XCTAssertEqual(shown.imageURL, "https://cdn.example/a.jpg")
        XCTAssertEqual(SquareShareCard.build(id: 0, audience: "PUBLIC", lifecycle: "PUBLISHED", contents: "x", images: []).includesPost, false)
    }

    func testHostedActivitiesComeFirstAndDuplicateIdsDrop() {
        let hosted = SquareComposeActivityParse.hostedRows([["id": 3, "name": "Hosted"]])
        let joined = SquareComposeActivityParse.joinedRows([["ownerType": 2, "cmsActivity": ["id": 3, "name": "Joined same"]], ["ownerType": 1, "id": 9, "name": "Skipped"], ["id": 4, "name": "Joined"]])
        let merged = SquareComposeActivityParse.merge(hosted: hosted, joined: joined)
        XCTAssertEqual(merged.map(\.activityID), ["3", "4"])
        XCTAssertEqual(merged.first?.sourceLabel, "我主办的")
        XCTAssertEqual(merged.last?.sourceLabel, "我参加的")
    }

    func testDraftMemberMismatchAndUnknownLock() {
        let saved = Date(timeIntervalSince1970: 1_700_000_000)
        let envelope = SquareComposeDraftEnvelope(memberID: "7", savedAt: saved, contents: "draft")
        XCTAssertEqual(SquareComposeDraftRules.load(envelope, memberID: "8"), .memberMismatch)
        XCTAssertEqual(SquareComposeDraftRules.load(envelope, memberID: "7"), .ready("draft"))
        XCTAssertEqual(SquareComposeDraftRules.load(nil, memberID: "7"), .missing)
        let locked = SquareComposeLock(requestID: "req-1", phase: .unknown)
        XCTAssertEqual(locked.confirmResult(currentRequestID: "req-1", observed: .idle).phase, .unknown)
        XCTAssertEqual(locked.confirmResult(currentRequestID: "other", observed: .receipt).phase, .unknown)
        XCTAssertEqual(locked.confirmResult(currentRequestID: "req-1", observed: .receipt).phase, .receipt)
        XCTAssertEqual(locked.confirmResult(currentRequestID: "req-1", observed: .rejected).phase, .rejected)
    }

    func testPopoverStaysHiddenWithoutAnAnchorAndExcerptFallsBack() {
        let hidden = SquarePopoverLayout.place(anchor: nil, panelWidth: 200, panelHeight: 80, windowWidth: 390, windowHeight: 700, minTop: 8, safeBottom: 680)
        XCTAssertFalse(hidden.visible)
        let placed = SquarePopoverLayout.place(anchor: .init(left: 16, top: 40, bottom: 80), panelWidth: 200, panelHeight: 80, windowWidth: 390, windowHeight: 700, minTop: 8, safeBottom: 680)
        XCTAssertTrue(placed.visible)
        XCTAssertLessThan(placed.left + 200, 390)
        XCTAssertEqual(SquarePostExcerpt.text(nil), "(仅图片动态)")
        XCTAssertEqual(SquarePostExcerpt.text("  a   short "), "a short")
        XCTAssertTrue(SquarePostExcerpt.text(String(repeating: "城", count: 20)).hasSuffix("…"))
    }
}
