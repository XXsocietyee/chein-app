import XCTest
@testable import Questify

/// Components r1 C1: event countdown mapping, compatible content decoding, run buttons and the intent router.
@MainActor final class QuestLiveActivityComponentsTests: XCTestCase {
    /// 2027-01-15 16:00:00 Beijing time.
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func beijing(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private func ticket(id: Int, title: String = "City walk", usableFrom: String?, verified: Bool = false,
                        address: String? = "West Lake gate") throws -> TicketWalletTicket {
        var activity: [String: Any] = ["id": 9, "name": title]
        if let address { activity["addressName"] = address }
        var value: [String: Any] = ["id": id, "registrationStatus": 2, "paymentStatus": 2, "cmsActivity": activity]
        if let usableFrom { value["usableFrom"] = usableFrom }
        if verified { value["verificationStatus"] = 1 }
        return try JSONDecoder().decode(TicketWalletTicket.self, from: JSONSerialization.data(withJSONObject: value))
    }

    func testSoonestTimedTicketCountsDownWithPlaceAndNoIdentifier() throws {
        let later = try ticket(id: 1, title: "Later", usableFrom: beijing(now.addingTimeInterval(2 * 3600)))
        let soon = try ticket(id: 2, title: "Soon", usableFrom: beijing(now.addingTimeInterval(20 * 60)))
        let update = QuestLiveActivityMapping.event(tickets: [later, soon], now: now)
        guard case .show(let descriptor, let state) = update else { return XCTFail("expected show, got \(update)") }
        XCTAssertEqual(descriptor, QuestLiveActivityDescriptor(kind: .event, key: QuestLiveActivityMapping.eventKey,
                                                               title: "Soon", place: "West Lake gate"))
        XCTAssertEqual(state.startsAt, now.addingTimeInterval(20 * 60))
        XCTAssertEqual(state.startInterval(now: now), now...now.addingTimeInterval(20 * 60))
        XCTAssertNil(state.runToggle(kind: .event))
    }

    func testDateOnlyFarAndVerifiedTicketsEndTheCountdown() throws {
        let dateOnly = try ticket(id: 1, usableFrom: String(beijing(now).prefix(10)))
        let far = try ticket(id: 2, usableFrom: beijing(now.addingTimeInterval(5 * 3600)))
        let verified = try ticket(id: 3, usableFrom: beijing(now.addingTimeInterval(600)), verified: true)
        let past = try ticket(id: 4, usableFrom: beijing(now.addingTimeInterval(-3600)))
        XCTAssertEqual(QuestLiveActivityMapping.event(tickets: [dateOnly, far, verified, past], now: now),
                       .end(.event, key: QuestLiveActivityMapping.eventKey, last: nil))
    }

    func testStartedTicketStaysInsideTheGrace() throws {
        let started = try ticket(id: 1, usableFrom: beijing(now.addingTimeInterval(-10 * 60)))
        let state: QuestLiveActivityContent?
        if case .show(_, let content) = QuestLiveActivityMapping.event(tickets: [started], now: now) { state = content } else { state = nil }
        XCTAssertNotNil(state)
        XCTAssertNil(state?.startInterval(now: now))
    }

    func testContentEncodedByAnOlderBuildStillDecodes() throws {
        let old = Data(#"{"status":"active","elapsedSeconds":12,"stopName":"Gate"}"#.utf8)
        let state = try JSONDecoder().decode(QuestLiveActivityContent.self, from: old)
        XCTAssertEqual(state.stopName, "Gate")
        XCTAssertNil(state.deadline); XCTAssertNil(state.arrived); XCTAssertNil(state.score); XCTAssertNil(state.rank)
        XCTAssertNil(state.startsAt)
    }

    func testRunToggleFollowsStatusForTimedRunsOnly() {
        let running = QuestLiveActivityContent(status: .active, elapsedSeconds: 5, runningSince: now)
        let paused = QuestLiveActivityContent(status: .paused, elapsedSeconds: 5)
        let untimed = QuestLiveActivityContent(status: .active, stopName: "Gate")
        let finished = QuestLiveActivityContent(status: .finished, elapsedSeconds: 5)
        XCTAssertEqual(running.runToggle(kind: .play), true)
        XCTAssertEqual(paused.runToggle(kind: .roam), false)
        XCTAssertNil(untimed.runToggle(kind: .play))
        XCTAssertNil(finished.runToggle(kind: .play))
        XCTAssertNil(running.runToggle(kind: .story))
    }

    func testDeadlineCountsDownOnlyWhileAhead() {
        let state = QuestLiveActivityContent(status: .active, deadline: now.addingTimeInterval(300))
        XCTAssertEqual(state.deadlineInterval(now: now), now...now.addingTimeInterval(300))
        XCTAssertNil(state.deadlineInterval(now: now.addingTimeInterval(301)))
        XCTAssertEqual(QuestLiveActivityText.rank(3), "#3")
        XCTAssertEqual(QuestLiveActivityText.rank(nil), "—")
    }

    func testPlayMappingCarriesScoreAndRank() {
        let update = QuestLiveActivityMapping.play(key: "play:x", snapshot: nil, clockPhase: .idle, elapsedSeconds: 0,
                                                   now: now, score: 40, rank: 2)
        // Without a snapshot nothing shows; score / rank never start an activity by themselves.
        XCTAssertEqual(update, .end(.play, key: "play:x", last: nil))
    }

    func testRouterKeepsOnlyAnUnhandledCheckIn() {
        let saved = QuestLiveActivityActionRouter.handler
        defer { QuestLiveActivityActionRouter.handler = saved; _ = QuestLiveActivityActionRouter.takePending() }
        QuestLiveActivityActionRouter.handler = { _, _ in false }
        XCTAssertFalse(QuestLiveActivityActionRouter.route(.pause, kind: .play))
        XCTAssertNil(QuestLiveActivityActionRouter.pending)
        XCTAssertFalse(QuestLiveActivityActionRouter.route(.checkIn, kind: .play))
        XCTAssertEqual(QuestLiveActivityActionRouter.pending?.action, .checkIn)
        var taken: [QuestLiveActivityAction] = []
        QuestLiveActivityActionRouter.handler = { action, _ in taken.append(action); return true }
        XCTAssertTrue(QuestLiveActivityActionRouter.route(.resume, kind: .roam))
        XCTAssertNil(QuestLiveActivityActionRouter.pending)
        XCTAssertEqual(taken, [.resume])
    }
}
