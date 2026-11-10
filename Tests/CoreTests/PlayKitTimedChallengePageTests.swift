import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

@available(macOS 14.0, *)
@MainActor final class PlayKitTimedChallengePageTests: XCTestCase {
    private func page(kind: PlayKitScreenKind = .countdown, playKit: PlayWireValue? = nil, phase: String = "ready",
        advanced: Bool = true, read: Bool = true, action: Bool = true) -> PlayKitTimedChallengePage {
        PlayKitTimedChallengePage.project(kind: kind, playKit: playKit, coordinatorPhase: phase,
            advancedEnabled: advanced, showsReadRoute: read, showsActionRoute: action)
    }
    private func kit(_ kind: String, _ fields: [String: PlayWireValue]) -> PlayWireValue {
        .object([kind: .object(fields)])
    }

    func testUnknownNumbersStayAnEmDashAndLiteralZeroStaysZero() {
        XCTAssertEqual(PlayKitTimedChallengePage.Fact.unknownDisplay, "—")
        XCTAssertNotEqual(PlayKitTimedChallengePage.Fact.unknownDisplay, "0")
        for value in [PlayWireValue.null, .string("UNKNOWN"), .string("0"), .string("30"), .bool(false), .number(.nan), .number(.infinity)] {
            let fact = PlayKitTimedChallengePage.number(value)
            XCTAssertNil(fact.literal)
            XCTAssertEqual(fact.displayText, "—")
        }
        XCTAssertEqual(PlayKitTimedChallengePage.number(.integer(0)).displayText, "0")
        XCTAssertEqual(PlayKitTimedChallengePage.number(.number(0)).literal, Optional(0.0))
        XCTAssertEqual(PlayKitTimedChallengePage.number(.integer(30)).displayText, "30")
    }

    func testMissingSecondsAreNotTreatedAsZero() throws {
        let missing = page(playKit: kit("countdown", ["submitted": .bool(false)]))
        XCTAssertEqual(missing.phase, .ready)
        XCTAssertEqual(missing.targetSeconds.displayText, "—")
        XCTAssertNil(missing.targetSeconds.literal)
        XCTAssertFalse(missing.configurationValid)
        XCTAssertFalse(missing.startReviewAllowed)
        XCTAssertThrowsError(try missing.acknowledgedStartPayload()) { error in
            XCTAssertEqual(error as? PlayExperienceError, .disabled)
        }
        let zero = page(playKit: kit("countdown", ["seconds": .integer(0)]))
        XCTAssertEqual(zero.targetSeconds.displayText, "0")
        XCTAssertEqual(zero.targetSeconds.literal, Optional(0.0))
        XCTAssertFalse(zero.startReviewAllowed)
        let ready = page(playKit: kit("countdown", ["seconds": .integer(30)]))
        XCTAssertEqual(ready.targetSeconds.displayText, "30")
        XCTAssertEqual(ready.readouts.map(\.accessibilityIdentifier), ["playkit.timed.target"])
        XCTAssertEqual(ready.copyKey, "playkit.timed.ready")
        XCTAssertEqual(try ready.acknowledgedStartPayload(), ["game": .string("countdown")])
        XCTAssertEqual(ready.offeredPaths, [PlayKitTimedChallengePage.readPath, PlayKitTimedChallengePage.actionPath])
        XCTAssertFalse(ready.offeredPaths.contains { $0.contains("city/nodes") || $0.contains("poi-challenge") })
    }

    func testLoadingEmptyErrorAndUnknownPhases() {
        XCTAssertEqual(page(phase: "loading").phase, .loading)
        XCTAssertEqual(page(phase: "idle").accessibilityIdentifier, "playkit.timed.loading")
        XCTAssertEqual(page(phase: "loading").targetSeconds.displayText, "—")
        let empty = page(playKit: .object([:]))
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.accessibilityIdentifier, "playkit.timed.empty")
        XCTAssertTrue(empty.readouts.isEmpty)
        XCTAssertEqual(page(phase: "rejected").phase, .error)
        XCTAssertEqual(page(phase: "disabled").phase, .error)
        XCTAssertEqual(page(phase: "stale").phase, .error)
        let unknown = page(playKit: kit("countdown", ["seconds": .integer(30)]), phase: "unknown")
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertEqual(unknown.copyKey, "playkit.timed.unknown")
        XCTAssertNil(unknown.targetSeconds.literal)
        XCTAssertEqual(unknown.targetSeconds.displayText, "—")
        XCTAssertTrue(unknown.readouts.isEmpty)
        XCTAssertEqual(page(phase: "retryable").phase, .unknown)
        let malformed = page(playKit: .object(["countdown": .string("UNKNOWN")]))
        XCTAssertEqual(malformed.phase, .unknown)
        XCTAssertNil(malformed.targetSeconds.literal)
    }

    func testMissingCapabilityOrRouteStaysHidden() throws {
        for hidden in [
            page(advanced: false),
            page(read: false),
            page(action: false),
            page(kind: .qa, playKit: kit("qa", ["finished": .bool(false)]))
        ] {
            XCTAssertTrue(hidden.hidden)
            XCTAssertNil(hidden.phase)
            XCTAssertNil(hidden.accessibilityIdentifier)
            XCTAssertTrue(hidden.offeredPaths.isEmpty)
            XCTAssertFalse(hidden.startReviewAllowed)
            XCTAssertEqual(hidden.targetSeconds.displayText, "—")
            XCTAssertThrowsError(try hidden.acknowledgedStartPayload())
        }
        XCTAssertFalse(PlayKitTimedChallengePage.cityNodeCompleteOffered)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
    }

    func testChinaHostUsesExistingRoutesAndDoesNotRevealAClosedGrant() throws {
        let offline = try RegionalConfiguration(market: .china)
        let closed = PlayKitTimedChallengePage.project(kind: .countdown, playKit: kit("countdown", ["seconds": .integer(30)]),
            coordinatorPhase: "ready", advancedEnabled: true, configuration: offline)
        XCTAssertTrue(closed.hidden)
        XCTAssertFalse(offline.showsRoute(PlayKitTimedChallengePage.readPath))
        let china = try RegionalConfiguration(market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs)
        XCTAssertTrue(china.showsRoute(PlayKitTimedChallengePage.readPath))
        XCTAssertTrue(china.showsRoute(PlayKitTimedChallengePage.actionPath))
        XCTAssertFalse(china.showsRoute("/api/play/advanced/time-window"))
        XCTAssertFalse(china.showsRoute("/api/play/poi-challenge"))
        let revealed = PlayKitTimedChallengePage.project(kind: .countdown, playKit: kit("countdown", ["seconds": .integer(30)]),
            coordinatorPhase: "ready", advancedEnabled: true, configuration: china)
        XCTAssertEqual(revealed.offeredPaths, [PlayKitTimedChallengePage.readPath, PlayKitTimedChallengePage.actionPath])
        let dormant = PlayKitTimedChallengePage.project(kind: .countdown, playKit: kit("countdown", ["seconds": .integer(30)]),
            coordinatorPhase: "ready", advancedEnabled: false, configuration: china)
        XCTAssertTrue(dormant.hidden)
    }

    func testReactionDoesNotGuessThreeRoundsAndTypeInKeepsLiteralZero() throws {
        let reaction = page(kind: .reaction, playKit: kit("reaction", ["submitted": .bool(false)]))
        XCTAssertEqual(reaction.rounds.displayText, "—")
        XCTAssertNil(reaction.rounds.literal)
        XCTAssertTrue(reaction.startReviewAllowed)
        XCTAssertEqual(try reaction.acknowledgedStartPayload(), ["game": .string("reaction")])
        let typed = page(kind: .typeIn, playKit: kit("typeIn", ["seconds": .integer(0), "target": .string("synthetic"), "attempts": .integer(0)]))
        XCTAssertEqual(typed.targetSeconds.displayText, "0")
        XCTAssertEqual(typed.attempts.displayText, "0")
        XCTAssertEqual(typed.attemptLimit.displayText, "—")
        XCTAssertTrue(typed.configurationValid)
        XCTAssertEqual(typed.typeInTarget?.displayText, "synthetic")
        let blank = page(kind: .typeIn, playKit: kit("typeIn", ["seconds": .string("UNKNOWN"), "target": .null]))
        XCTAssertEqual(blank.targetSeconds.displayText, "—")
        XCTAssertEqual(blank.typeInTarget?.displayText, "—")
        XCTAssertFalse(blank.configurationValid)
    }

    func testDisabledAdvancedGrantDoesNotSend() async throws {
        let wire = PlayRecoveryRecordingTransport()
        let service = PlayExperienceService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!),
            transport: wire, enabled: [])
        let session = try PlayExperienceSession(accountID: 9001, epoch: 1, namespace: "synthetic-cn", token: "synthetic-token")
        let model = PlayAdvancedCoordinator(activityID: 41, topicID: 71, nodeID: 701, service: service, currentSession: { session })
        let china = try RegionalConfiguration(market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs)
        await model.start()
        XCTAssertEqual(wire.requests.count, 0)
        XCTAssertEqual(model.phase, "disabled")
        let page = model.timedChallengePage(kind: .countdown, configuration: china)
        XCTAssertTrue(page.hidden)
        XCTAssertTrue(page.offeredPaths.isEmpty)
        XCTAssertFalse(page.startReviewAllowed)
    }

#if DEBUG
    func testDebugFixtureLoadsCountdownWithoutInventingARoute() async throws {
        let state = try PlayKitTimedChallengeFixtureData.state(PlayKitTimedChallengeFixtureData.countdownState)
        XCTAssertEqual(state.playKit["countdown"]["seconds"].integer, 30)
        let wire = PlayRecoveryRecordingTransport()
        wire.responses["/api/play/advanced/start"] = .reply(Data(("{\"code\":200,\"data\":" + PlayKitTimedChallengeFixtureData.countdownState + "}").utf8), 200)
        let service = PlayExperienceService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!),
            transport: wire, enabled: [.advanced])
        let session = try PlayExperienceSession(accountID: 9001, epoch: 1, namespace: "synthetic-cn", token: "synthetic-token")
        let model = PlayAdvancedCoordinator(activityID: 41, topicID: 71, nodeID: 701, service: service, currentSession: { session })
        await model.start()
        XCTAssertEqual(model.phase, "ready")
        XCTAssertEqual(wire.requests.compactMap { $0.url?.path }, ["/api/play/advanced/start"])
        let china = try RegionalConfiguration(market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs)
        let loaded = model.timedChallengePage(kind: .countdown, configuration: china)
        XCTAssertEqual(loaded.phase, .ready)
        XCTAssertEqual(loaded.targetSeconds.displayText, "30")
        XCTAssertEqual(try loaded.acknowledgedStartPayload(), ["game": .string("countdown")])
        let unknown = try PlayKitTimedChallengeFixtureData.wire(PlayKitTimedChallengeFixtureData.unknownSegment)
        XCTAssertEqual(PlayKitTimedChallengePage.number(unknown["seconds"]).displayText, "—")
        XCTAssertEqual(PlayKitTimedChallengePage.number(try PlayKitTimedChallengeFixtureData.wire(PlayKitTimedChallengeFixtureData.literalZeroSegment)["seconds"]).displayText, "0")
    }
#endif
}
