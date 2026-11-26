import XCTest
@testable import QuestifyCore

/// Page states for `subpackageMember/orient-score/index`. Existing score tests stay as they are.
final class OrientScorePageReadyTests: XCTestCase {
    private func json(_ text: String) throws -> OrientSessionJSON {
        try JSONDecoder().decode(OrientSessionJSON.self, from: Data(text.utf8))
    }

    private func ready(_ page: OrientScorePage) -> OrientScorePage.Facts? {
        guard case .ready(let facts) = page.phase else { return nil }
        return facts
    }

    func testMissingCapabilityStaysHiddenAndDoesNotInventARoute() throws {
        let score = try json("{\"sessionId\":9,\"totalCenti\":0}")
        let hidden = OrientScorePage.bind(clientCapabilityPresent: false, loading: true, value: score)
        XCTAssertNil(hidden.phase)
        XCTAssertFalse(hidden.showsContent)
        XCTAssertFalse(hidden.serverFactPresent)
        XCTAssertEqual(OrientScorePage.readPath, "api/orient/scoring/session/{}")
        XCTAssertFalse(hidden.showsMerchantChoice)
        XCTAssertFalse(hidden.appealEnabled)
        XCTAssertFalse(hidden.disputeEnabled)
        XCTAssertTrue(hidden.settleEnabled)
        XCTAssertTrue(hidden.syncEnabled)
        XCTAssertFalse(hidden.paymentEnabled)
        XCTAssertFalse(hidden.payoutEnabled)
        XCTAssertFalse(hidden.withdrawalEnabled)
    }

    func testLoadingEmptyErrorAndUnknownStayDistinct() throws {
        let loading = OrientScorePage.bind(clientCapabilityPresent: true, loading: true)
        XCTAssertEqual(loading.phase, .some(.loading))
        XCTAssertFalse(loading.showsContent)
        let idle = OrientScorePage.bind(clientCapabilityPresent: true)
        XCTAssertNil(idle.phase)
        XCTAssertFalse(idle.serverFactPresent)
        let empty = OrientScorePage.bind(clientCapabilityPresent: true, roundPresent: false)
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertEqual(OrientScorePage.bind(clientCapabilityPresent: true, value: .object([:])).phase, .some(.empty))
        XCTAssertEqual(OrientScorePage.bind(clientCapabilityPresent: true, failed: true).phase, .some(.error))
        XCTAssertEqual(OrientScorePage.bind(clientCapabilityPresent: true, value: .null).phase, .some(.unknown))
        XCTAssertEqual(OrientScorePage.bind(clientCapabilityPresent: true, value: .string("UNKNOWN")).phase, .some(.unknown))
        XCTAssertEqual(OrientScorePage.bind(clientCapabilityPresent: true, value: .string("0")).phase, .some(.unknown))
        XCTAssertEqual(OrientScorePage.bind(clientCapabilityPresent: true, value: .integer(0)).phase, .some(.unknown))
        XCTAssertEqual(OrientScorePage.bind(clientCapabilityPresent: true, value: .array([])).phase, .some(.unknown))
        let stringSession = try json("{\"sessionId\":\"9\",\"totalCenti\":0}")
        XCTAssertEqual(OrientScorePage.bind(clientCapabilityPresent: true, value: stringSession).phase, .some(.unknown))
        let zeroSession = try json("{\"sessionId\":0,\"totalCenti\":0}")
        XCTAssertEqual(OrientScorePage.bind(clientCapabilityPresent: true, value: zeroSession).phase, .some(.unknown))
    }

    func testLiteralIntegerScoreMatchesTheExistingSummaryIncludingZero() throws {
        let scored = "{\"sessionId\":9,\"topicId\":3,\"activityId\":0,\"status\":1,\"totalCenti\":1700,"
            + "\"byDimension\":{\"TASK\":2000,\"PUZZLE\":0,\"BONUS\":0,\"PENALTY\":-300,\"ADJUSTMENT\":0},"
            + "\"timeline\":[{\"entryId\":30,\"dimension\":\"TASK\",\"deltaCenti\":500,\"runningCenti\":500,\"reasonCode\":\"TASK_DONE\"}],"
            + "\"settlement\":null,\"appeals\":[],\"disputes\":[]}"
        let score = try JSONDecoder().decode(OrientSessionScore.self, from: Data(scored.utf8))
        XCTAssertNil(score.pendingReviewCount)
        XCTAssertTrue(score.canSync)
        XCTAssertTrue(score.canSettle)
        let facts = try XCTUnwrap(ready(OrientScorePage.bind(clientCapabilityPresent: true, value: try json(scored))))
        XCTAssertEqual(facts, OrientScorePage.facts(from: score))
        XCTAssertEqual(facts.totalText, "17.00")
        XCTAssertEqual(facts.dimensions.map(\.value), ["+20.00", "0.00", "0.00", "-3.00", "0.00"])
        XCTAssertEqual(facts.timeline.map(\.deltaText), ["+5.00"])
        XCTAssertEqual(facts.timeline.map(\.runningText), ["5.00"])
        XCTAssertEqual(facts.settlement, .absent)
        XCTAssertTrue(facts.timelineKnown)

        let zero = "{\"sessionId\":9,\"topicId\":3,\"activityId\":0,\"status\":0,\"totalCenti\":0,"
            + "\"byDimension\":{\"TASK\":0,\"PUZZLE\":0,\"BONUS\":0,\"PENALTY\":0,\"ADJUSTMENT\":0},"
            + "\"timeline\":[],"
            + "\"settlement\":{\"state\":\"SETTLED\",\"settlementId\":5,\"sessionId\":9,\"totalCenti\":0,\"pointsAwarded\":0,\"xpAwarded\":0,\"idempotencyKey\":\"k-s\"},"
            + "\"appeals\":[],\"disputes\":[]}"
        let zeroScore = try JSONDecoder().decode(OrientSessionScore.self, from: Data(zero.utf8))
        XCTAssertFalse(zeroScore.canSync)
        XCTAssertFalse(zeroScore.canSettle)
        let zeroFacts = try XCTUnwrap(ready(OrientScorePage.bind(clientCapabilityPresent: true, value: try json(zero))))
        XCTAssertEqual(zeroFacts, OrientScorePage.facts(from: zeroScore))
        XCTAssertEqual(zeroFacts.totalText, "0.00")
        XCTAssertEqual(zeroFacts.totalText, OrientScoreFormat.centi(0))
        XCTAssertEqual(zeroFacts.dimensions.map(\.value), ["0.00", "0.00", "0.00", "0.00", "0.00"])
        XCTAssertEqual(zeroFacts.phaseText, OrientScorePresentation.phase(status: 0))
        XCTAssertEqual(zeroFacts.settlement, .settled(total: "0.00", points: "0", xp: "0"))
        XCTAssertNotEqual(zeroFacts.totalText, OrientScorePage.unknownDisplay)
        let page = OrientScorePage.bind(clientCapabilityPresent: true, value: try json(zero))
        XCTAssertFalse(page.appealEnabled)
        XCTAssertFalse(page.disputeEnabled)
        XCTAssertTrue(page.settleEnabled)
        XCTAssertTrue(page.syncEnabled)
    }

    func testUnknownScoresAreAnEmDashAndAreNotStoredAsZero() throws {
        let raw = "{\"sessionId\":9,\"status\":\"UNKNOWN\",\"totalCenti\":null,"
            + "\"byDimension\":{\"TASK\":\"0\",\"PUZZLE\":null,\"BONUS\":\"UNKNOWN\",\"PENALTY\":1.5,\"ADJUSTMENT\":{\"value\":0}},"
            + "\"timeline\":[{\"entryId\":30,\"deltaCenti\":\"0\",\"runningCenti\":null},{\"entryId\":\"31\",\"deltaCenti\":0,\"runningCenti\":0},{\"entryId\":0,\"deltaCenti\":0,\"runningCenti\":0}],"
            + "\"settlement\":\"UNKNOWN\"}"
        XCTAssertThrowsError(try JSONDecoder().decode(OrientSessionScore.self, from: Data(raw.utf8)))
        let facts = try XCTUnwrap(ready(OrientScorePage.bind(clientCapabilityPresent: true, value: try json(raw))))
        XCTAssertEqual(facts.sessionID, 9)
        XCTAssertEqual(facts.phaseText, OrientScorePage.unknownDisplay)
        XCTAssertEqual(facts.totalText, "—")
        XCTAssertEqual(facts.dimensions.map(\.value), ["—", "—", "—", "—", "—"])
        XCTAssertEqual(facts.settlement, .unknown)
        XCTAssertTrue(facts.timelineKnown)
        XCTAssertEqual(facts.timeline.map(\.entryID), [30])
        XCTAssertEqual(facts.timeline.map(\.deltaText), ["—"])
        XCTAssertEqual(facts.timeline.map(\.runningText), ["—"])
        XCTAssertNotEqual(facts.totalText, "0")
        XCTAssertNotEqual(facts.totalText, "0.00")
        XCTAssertFalse(facts.dimensions.contains { $0.value == "0" || $0.value == "0.00" })

        let coerced = "{\"sessionId\":9,\"topicId\":3,\"activityId\":0,\"status\":1,\"totalCenti\":\"0\","
            + "\"byDimension\":{\"TASK\":\"0\",\"PUZZLE\":0,\"BONUS\":0,\"PENALTY\":0,\"ADJUSTMENT\":0},"
            + "\"timeline\":[],\"settlement\":null,\"appeals\":[],\"disputes\":[]}"
        let decoded = try JSONDecoder().decode(OrientSessionScore.self, from: Data(coerced.utf8))
        XCTAssertEqual(decoded.totalCenti, 0)
        XCTAssertEqual(decoded.byDimension["TASK"], 0)
        let shown = try XCTUnwrap(ready(OrientScorePage.bind(clientCapabilityPresent: true, value: try json(coerced))))
        XCTAssertEqual(shown.totalText, "—")
        XCTAssertEqual(shown.dimensions.first { $0.key == "TASK" }?.value, "—")
        XCTAssertEqual(shown.dimensions.first { $0.key == "PUZZLE" }?.value, "0.00")
        XCTAssertNotEqual(shown.totalText, OrientScorePage.facts(from: decoded).totalText)

        let missing = try XCTUnwrap(ready(OrientScorePage.bind(clientCapabilityPresent: true, value: try json("{\"sessionId\":9}"))))
        XCTAssertThrowsError(try JSONDecoder().decode(OrientSessionScore.self, from: Data("{\"sessionId\":9}".utf8)))
        XCTAssertEqual(missing.totalText, "—")
        XCTAssertEqual(missing.dimensions.map(\.value), ["—", "—", "—", "—", "—"])
        XCTAssertEqual(missing.settlement, .absent)
        XCTAssertFalse(missing.timelineKnown)
        XCTAssertTrue(missing.timeline.isEmpty)

        XCTAssertEqual(OrientScorePage.scoreText(.integer(0)), "0.00")
        XCTAssertEqual(OrientScorePage.scoreText(.integer(0), signed: true), "0.00")
        XCTAssertEqual(OrientScorePage.scoreText(.number(0)), "0.00")
        XCTAssertEqual(OrientScorePage.scoreText(.integer(-300), signed: true), "-3.00")
        XCTAssertEqual(OrientScorePage.scoreText(.number(1.5)), "—")
        XCTAssertEqual(OrientScorePage.scoreText(.string("0")), "—")
        XCTAssertEqual(OrientScorePage.scoreText(.string("UNKNOWN")), "—")
        XCTAssertEqual(OrientScorePage.scoreText(.null), "—")
        XCTAssertEqual(OrientScorePage.scoreText(.bool(false)), "—")
        XCTAssertEqual(OrientScorePage.scoreText(.object(["centi": .integer(0)])), "—")
        XCTAssertEqual(OrientScorePage.scoreText(nil), "—")
        XCTAssertEqual(OrientScorePage.countText(.integer(0)), "0")
        XCTAssertEqual(OrientScorePage.countText(.number(0)), "0")
        XCTAssertEqual(OrientScorePage.countText(.string("0")), "—")
        XCTAssertEqual(OrientScorePage.countText(.null), "—")
        XCTAssertNotEqual(OrientScorePage.countText(.string("0")), "0")

        let unsummed = OrientScorePage.bind(clientCapabilityPresent: true, value: .object([
            "sessionId": .integer(9),
            "timeline": .array([.object([
                "entryId": .integer(30),
                "deltaCenti": .integer(500),
                "runningCenti": .null
            ])])
        ]))
        let row = try XCTUnwrap(ready(unsummed)?.timeline.first)
        XCTAssertEqual(row.deltaText, "+5.00")
        XCTAssertEqual(row.runningText, "—")
        XCTAssertNotEqual(row.runningText, "5.00")
        XCTAssertNotEqual(row.runningText, "0")
    }

    func testRecoveriesMatchTheMiniProgramRowRules() throws {
        let base = "{\"sessionId\":9,\"topicId\":3,\"activityId\":0,\"status\":1,\"totalCenti\":1700,"
            + "\"byDimension\":{\"TASK\":2000,\"PUZZLE\":0,\"BONUS\":0,\"PENALTY\":-300,\"ADJUSTMENT\":0},"
            + "\"timeline\":[],\"settlement\":null,\"appeals\":[],\"disputes\":[]}"
        let plain = try JSONDecoder().decode(OrientSessionScore.self, from: Data(base.utf8))
        XCTAssertTrue(plain.recoveries.isEmpty)
        XCTAssertTrue(OrientScorePresentation.summary(from: plain).recoveries.isEmpty)
        let row = "{\"id\":4,\"sessionId\":9,\"kind\":\"SYNC\",\"status\":0,\"resolutionNote\":\"已核对\"}"
        let listed = base.replacingOccurrences(of: "\"disputes\":[]", with: "\"disputes\":[],\"recoveries\":[\(row)]")
        let score = try JSONDecoder().decode(OrientSessionScore.self, from: Data(listed.utf8))
        XCTAssertEqual(score.recoveries.map(\.note), ["已核对"])
        XCTAssertEqual(OrientScorePresentation.summary(from: score).recoveries.map(\.kind), ["SYNC"])
        let absent = base.replacingOccurrences(of: "\"disputes\":[]", with: "\"disputes\":[],\"recoveries\":null")
        XCTAssertTrue(try JSONDecoder().decode(OrientSessionScore.self, from: Data(absent.utf8)).recoveries.isEmpty)
        for bad in [
            "{\"id\":4,\"sessionId\":9,\"kind\":\"SYNC\",\"status\":2}",
            "{\"id\":4,\"sessionId\":8,\"kind\":\"SYNC\",\"status\":0}",
            "{\"id\":4,\"sessionId\":9,\"kind\":\"PAY\",\"status\":0}",
            "{\"id\":0,\"sessionId\":9,\"kind\":\"SYNC\",\"status\":0}"
        ] {
            let raw = base.replacingOccurrences(of: "\"disputes\":[]", with: "\"disputes\":[],\"recoveries\":[\(bad)]")
            XCTAssertThrowsError(try JSONDecoder().decode(OrientSessionScore.self, from: Data(raw.utf8)))
        }
    }
}
