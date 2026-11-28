import XCTest
@testable import Questify

/// MP club-director-incident-sheet (director.js:478-552, 688-760) and chapter-sheet (director.js:839-851, 1370-1411).
@MainActor final class PlayDirectorIncidentSheetTests: XCTestCase {
    private func projection() throws -> PlayDirectorProjection {
        let raw = try PlayExperienceSyntheticFixtures.wire(#"{"perspective":"CLUB","activityId":41,"sessionId":501,"revision":2,"status":"RUNNING","availableActions":["UNLOCK_CHAPTER","CLUB_STATION_PAUSE","CLUB_STATION_RESUME","CLUB_REJECT_SUBMISSION"],"club":{"stations":[{"nodeId":701,"nodeName":"Synthetic gate","status":"PAUSED","pauseReason":"Rain"},{"nodeId":702,"nodeName":"Synthetic court","status":"ACTIVE","pendingVerificationCount":3,"fallbackPlanOptions":[{"planCode":"INDOOR","version":1}]}],"submissions":[{"submissionId":91,"teamId":61,"nodeName":"Synthetic court","status":"PENDING"},{"submissionId":92,"teamId":62,"nodeName":"Synthetic court","status":"REJECTED","decisionReason":"Blurry"}],"chapterOptions":[{"chapterId":81,"title":"Synthetic next chapter","waitingTeams":2}]}}"#)
        return try PlayDirectorProjection(raw, activityID: 41)
    }

    func testIncidentRowsFollowMPOrderAndModes() throws {
        let rows = PlayDirectorIncidents.rows(try projection())
        XCTAssertEqual(rows.map(\.id), ["pause:701", "backlog:702", "sub:91", "sub:92"])
        XCTAssertEqual(rows.map { PlayDirectorIncidents.modes($0) }, [[.resume], [.pause], [.reject], []])
    }

    func testIncidentCommandsMatchMPPayloads() throws {
        let projection = try projection()
        let rows = PlayDirectorIncidents.rows(projection)
        let resume = PlayDirectorIncidents.command(rows[0], mode: .resume, reason: "", projection: projection)
        XCTAssertEqual(resume?.action, .resume); XCTAssertEqual(resume?.nodeID, 701); XCTAssertEqual(resume?.payload.isEmpty, true)
        XCTAssertNil(PlayDirectorIncidents.command(rows[1], mode: .pause, reason: "x", projection: projection))
        let pause = PlayDirectorIncidents.command(rows[1], mode: .pause, reason: " Queue ", projection: projection, now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(pause?.payload["reason"]?.text, "Queue")
        XCTAssertEqual(pause?.payload["resumeEta"]?.text, "1970-01-01 08:30:00")
        XCTAssertEqual(pause?.payload["fallbackPlanCode"]?.text, "INDOOR")
        let reject = PlayDirectorIncidents.command(rows[2], mode: .reject, reason: "Redo it", projection: projection)
        XCTAssertEqual(reject?.payload["submissionId"]?.integer, 91); XCTAssertEqual(reject?.payload["reasonCode"]?.text, "ONSITE_REJECT")
    }

    func testChapterReleaseSendsReasonOnlyWhenFilled() throws {
        let projection = try projection()
        XCTAssertEqual(PlayDirectorChapterRelease.chapters(projection).first?.waitingTeams, 2)
        XCTAssertEqual(PlayDirectorChapterRelease.payload(chapterID: 81, reason: "  ").keys.sorted(), ["chapterId"])
        XCTAssertEqual(PlayDirectorChapterRelease.payload(chapterID: 81, reason: " Late team ")["reason"]?.text, "Late team")
        let title = PlayDirectorChapterRelease.title(projection, locale: Locale(identifier: "zh-Hans"))
        XCTAssertTrue(title.contains("Synthetic next chapter"))
    }
}
