import XCTest
@testable import QuestifyCore

final class SquareStravaCardTests: XCTestCase {
    func testTextPostOmitsTheActivityCard() throws {
        let post = try decode(#"{"id":9,"contents":"hello","memberId":3}"#)
        XCTAssertFalse(post.strava.hasActivity)
        XCTAssertFalse(SquareStravaFacts(post: post).hasActivity)
        XCTAssertEqual(SquareStravaFacts(post: post).distanceText, SquareCountDisplay.unknownMark)
        XCTAssertEqual(SquareStravaFacts(post: post).paceText, SquareCountDisplay.unknownMark)
        XCTAssertEqual(SquareStravaFacts(post: post).durationText, SquareCountDisplay.unknownMark)
        XCTAssertFalse(SquareStravaFacts(post: post).showsRoute)
        XCTAssertFalse(SquareStravaFacts(post: post).showsKudos)
        XCTAssertFalse(SquareStravaFacts(post: post).showsComment)
        XCTAssertFalse(SquareStravaFacts(post: post).showsRepost)
        XCTAssertFalse(SquareStravaFacts(post: post).showsFollow(viewerID: 1, authorID: 3))
    }

    func testActivityCardKeepsUnknownMetricsAsAnEmDash() throws {
        let post = try decode(#"{"id":9,"memberId":3,"dataType":1,"activityId":4,"sportName":"Night ride","completed":true,"kudosUsers":[{"avatar":"a"},{"avatar":"b"}],"latestComment":{"nickname":"Ada","content":"Nice"},"isFollowTheUser":0,"reposted":false,"routePolyline":[{"latitude":31.2,"longitude":121.5},{"lat":31.3,"lng":121.6}]}"#)
        let facts = SquareStravaFacts(post: post)
        XCTAssertTrue(facts.hasActivity)
        XCTAssertEqual(facts.title, "Night ride")
        XCTAssertEqual(facts.distanceText, SquareCountDisplay.unknownMark)
        XCTAssertEqual(facts.durationText, SquareCountDisplay.unknownMark)
        XCTAssertEqual(facts.paceText, SquareCountDisplay.unknownMark)
        XCTAssertTrue(facts.cleared)
        XCTAssertTrue(facts.showsRoute)
        XCTAssertEqual(facts.kudosAvatars, ["a", "b"])
        XCTAssertTrue(facts.showsComment)
        XCTAssertEqual(facts.commentAuthor, "Ada")
        XCTAssertEqual(facts.reposted, false)
        XCTAssertNil(facts.repostCountText)
        XCTAssertTrue(facts.showsFollow(viewerID: 8, authorID: post.memberID))
        XCTAssertFalse(facts.showsFollow(viewerID: nil, authorID: post.memberID))
        XCTAssertFalse(facts.showsFollow(viewerID: post.memberID, authorID: post.memberID))
    }

    func testKnownStatsAndRejectedRoutePoints() throws {
        let post = try decode(#"{"id":9,"activityId":4,"distance":24.7,"durationSeconds":3725,"nodeDoneCount":5,"nodeTotal":5,"completed":false,"routePolyline":[{"latitude":91,"longitude":10},{"latitude":"bad","longitude":1},[31.1,121.4],[31.2,121.5]]}"#)
        let facts = SquareStravaFacts(post: post)
        XCTAssertEqual(facts.distanceText, "24.7")
        XCTAssertEqual(facts.durationText, "1:02:05")
        XCTAssertEqual(facts.paceText, "5/5")
        XCTAssertFalse(facts.cleared)
        XCTAssertEqual(facts.route.count, 2)
        XCTAssertTrue(facts.showsRoute)
        XCTAssertFalse(SquareStravaRouteMap.showsLine([facts.route[0], facts.route[0]]))
        let units = SquareStravaRouteMap.unitPoints(facts.route)
        XCTAssertEqual(units.count, 2)
        XCTAssertEqual(units[0].y, 1, accuracy: 0.001)
        XCTAssertEqual(units[1].y, 0, accuracy: 0.001)
    }

    func testFractionalDurationStaysUnknown() throws {
        let post = try decode(#"{"id":9,"dataType":1,"durationSeconds":1.5,"nodeTotal":0}"#)
        let facts = SquareStravaFacts(post: post)
        XCTAssertEqual(facts.durationText, SquareCountDisplay.unknownMark)
        XCTAssertEqual(facts.paceText, SquareCountDisplay.unknownMark + "/0")
    }

    func testRepostWriteStaysLockedUntilTheSameRequestIsReread() {
        var ledger = SquareStravaWriteLedger()
        ledger.noteNotSent()
        XCTAssertEqual(ledger.phase, .notSent)
        ledger.noteUnknown(requestID: "request-id-000001")
        XCTAssertTrue(ledger.locks)
        ledger.noteNotSent()
        XCTAssertEqual(ledger.lockedRequestID, "request-id-000001")
        ledger.apply(reread: .differentRequest, savedRequestID: "request-id-000001")
        XCTAssertEqual(ledger.phase, .locked(requestID: "request-id-000001"))
        ledger.apply(reread: .confirmedSameRequest, savedRequestID: "other-request-0001")
        XCTAssertEqual(ledger.phase, .locked(requestID: "request-id-000001"))
        ledger.apply(reread: .stillUnknown, savedRequestID: "request-id-000001")
        XCTAssertTrue(ledger.locks)
        ledger.apply(reread: .confirmedSameRequest, savedRequestID: "request-id-000001")
        XCTAssertEqual(ledger.phase, .confirmed(requestID: "request-id-000001"))
        var rejected = SquareStravaWriteLedger()
        rejected.noteUnknown(requestID: "request-id-000001")
        rejected.apply(reread: .rejected, savedRequestID: "request-id-000001")
        XCTAssertEqual(rejected.phase, .rejected(requestID: "request-id-000001"))
        XCTAssertFalse(SquareStravaWriteLedger.valid("short"))
    }

    func testDraftBoxKeepsTheAccountAndDropsAnEmptyBody() {
        var box = SquareStravaDraftBox()
        XCTAssertNil(box.save(accountID: 7, text: "  ", activityID: nil, activityName: nil, now: 10, id: "draft-1"))
        let saved = box.save(accountID: 7, text: "Night ride", activityID: 4, activityName: "River", now: 11, id: "draft-1")
        XCTAssertEqual(saved?.activityID, 4)
        XCTAssertEqual(box.drafts.count, 1)
        let updated = box.save(accountID: 7, text: "Night ride 2", activityID: 4, activityName: "River", now: 12, id: "draft-1")
        XCTAssertEqual(updated?.text, "Night ride 2")
        XCTAssertEqual(box.drafts.count, 1)
        XCTAssertTrue(box.delete(id: "draft-1", accountID: 7))
        XCTAssertTrue(box.drafts.isEmpty)
        XCTAssertFalse(box.delete(id: "draft-1", accountID: 7))
    }

    func testCompletedActivitiesNeedAnIdAndAName() {
        let rows = try! JSONDecoder().decode([GrowthCompletedActivity].self, from: Data(#"[{"activityId":4,"topicId":9,"name":"River","doneCount":5,"total":5},{"activityId":0,"topicId":1,"name":"Nope"},{"topicId":2,"name":"Missing"}]"#.utf8))
        let choices = SquareStravaActivityChoice.choices(from: rows)
        XCTAssertEqual(choices.map(\.id), [4])
        XCTAssertEqual(choices.first?.name, "River")
        XCTAssertEqual(choices.first?.doneCount, 5)
    }

    func testClubActivityUsesTheSameCardAndATopicPostDoesNot() throws {
        let activity = try ClubCommunityPost(json: ["id": 3, "content": "done", "refType": 1, "sportName": "River", "distance": 12.5, "completed": true])
        XCTAssertTrue(SquareStravaFacts(club: activity).hasActivity)
        XCTAssertEqual(SquareStravaFacts(club: activity).distanceText, "12.5")
        XCTAssertTrue(SquareStravaFacts(club: activity).cleared)
        let topic = try ClubCommunityPost(json: ["id": 4, "content": "note", "sportName": "Topic", "sportCover": "cover"])
        XCTAssertFalse(topic.strava.hasActivity)
        XCTAssertFalse(SquareStravaFacts(club: topic).hasActivity)
    }

    private func decode(_ json: String) throws -> SquarePost {
        try JSONDecoder().decode(SquarePost.self, from: Data(json.utf8))
    }
}
