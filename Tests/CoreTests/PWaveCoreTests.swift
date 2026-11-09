import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Chapter 24 fixtures for P7, P1, P4, and P5. Responses are synthetic and stay in this test target.
final class PWaveCoreTests: XCTestCase {
    func testDisplayOrderAndContractAreNotRun() {
        XCTAssertEqual(PWaveFeature.displayOrder, [.battleReport, .inviteLanding, .playMode, .ticketSeats])
        XCTAssertEqual(PWaveReader.contractExecution, "NOT_RUN")
    }

    func testLoadingBindsOnlyWhenTheClientCapabilityIsPresent() {
        let waiting = PWavePresentation<PWaveBattleReportFact>.loading(clientCapabilityPresent: true)
        XCTAssertEqual(waiting.phase, .some(.loading))
        XCTAssertTrue(waiting.hidden)
        XCTAssertFalse(waiting.serverFactPresent)
        let blocked = PWavePresentation<PWaveBattleReportFact>.loading(clientCapabilityPresent: false)
        XCTAssertNil(blocked.phase)
        XCTAssertTrue(blocked.hidden)
    }

    func testUnknownNumbersAreNeverZero() {
        let unknownScore = PWaveNumberFact.parse(.string("UNKNOWN"))
        let missing = PWaveNumberFact.parse(.null)
        let quotedZero = PWaveNumberFact.parse(.string("0"))
        let objectZero = PWaveNumberFact.parse(.object(["total": .integer(0)]))
        XCTAssertNil(unknownScore.literal)
        XCTAssertNil(missing.literal)
        XCTAssertNil(quotedZero.literal)
        XCTAssertNil(objectZero.literal)
        XCTAssertNotEqual(unknownScore.literal, 0)
        XCTAssertEqual(PWaveNumberFact.parse(.integer(0)).literal, 0)
        let run = PWaveIdentifierFact.parse(.string("UNKNOWN"))
        XCTAssertNil(run.literalInteger)
        XCTAssertEqual(PWaveIdentifierFact.parse(.integer(0)).literalInteger, 0)
    }

    func testBattleReportKeepsUnknownScoreAndRankOffZero() throws {
        let fact = try readyReport(#"{"scopeKind":"RUN","score":"UNKNOWN","rank":null,"elapsedSource":"UNAVAILABLE_OTHER_RUN","rewardsScope":"TOPIC_ACTIVITY"}"#)
        XCTAssertNil(fact.score.literal)
        XCTAssertNil(fact.rank.literal)
        XCTAssertTrue(fact.elapsedIsUnknown)
        XCTAssertFalse(PWaveBattleReportFact.elapsedAmountIsKnown)
        XCTAssertTrue(fact.rewardsAreTopicOrActivityBackpack)
        XCTAssertFalse(PWaveBattleReportFact.labelsRewardsAsThisRun)
        XCTAssertFalse(PWaveBattleReportFact.showsSuccessSettlement)
        XCTAssertFalse(PWaveBattleReportFact.rankIsPuzzleNetScore)
        XCTAssertNil(fact.isSingleRun)
        XCTAssertNil(fact.mayFillCurrentContent)
    }

    func testLiteralZeroScoreStaysZeroAndLegacyScopeIsNotOneRun() throws {
        let scored = try readyReport(#"{"score":0,"rank":0}"#)
        XCTAssertEqual(scored.score.literal, 0)
        XCTAssertEqual(scored.rank.literal, 0)
        let legacy = try readyReport(#"{"scopeKind":"LEGACY_TOPIC_SCOPE","runState":"ENDED"}"#)
        XCTAssertEqual(legacy.isSingleRun, Optional(false))
        XCTAssertFalse(PWaveBattleReportFact.showsSuccessSettlement)
        let unattributed = try readyReport(#"{"scopeKind":"UNATTRIBUTED_RUN"}"#)
        XCTAssertEqual(unattributed.mayFillCurrentContent, Optional(false))
        let shaped = try readyReport(#"{"scopeKind":"RUN","score":{"total":0}}"#)
        XCTAssertNil(shaped.score.literal)
    }

    func testReportWithoutAClassifiedFieldIsUnknownNotAnEmptyZero() {
        let fact = PWaveBattleReport.decode(data: envelope(#"{"score":"UNKNOWN","rank":null}"#), status: 200)
        XCTAssertEqual(fact, .unknown)
        let presented = PWaveGate.presentation(clientCapabilityPresent: true, fact: fact)
        XCTAssertEqual(presented.phase, .some(.unknown))
        XCTAssertFalse(presented.hidden)
    }

    func testRunMismatchDoesNotOpenAnotherRunOrItsScore() {
        let body = Data(#"{"code":200,"msg":"RUN_NOT_FOUND","data":{"score":0,"rank":3}}"#.utf8)
        let fact = PWaveBattleReport.decode(data: body, status: 200)
        guard case .error(let error) = fact else { return XCTFail("expected error") }
        XCTAssertEqual(error.runErrorToken, "RUN_NOT_FOUND")
        XCTAssertFalse(error.didSubstituteAnotherRun)
        let mismatch = PWaveBattleReport.decode(data: envelope(#"{"scopeKind":"RUN_SCOPE_MISMATCH","score":0}"#), status: 200)
        guard case .error(let other) = mismatch else { return XCTFail("expected mismatch") }
        XCTAssertEqual(other.runErrorToken, "RUN_SCOPE_MISMATCH")
        XCTAssertFalse(other.didSubstituteAnotherRun)
    }

    func testReferralUnknownRegistrationDoesNotPromiseASignup() throws {
        let fact = try readyReferral(#"""
        {"state":"VALID","inviter":{"nickname":"Ada","avatar":"https://example.test/a.png","memberId":9,"phone":"15500001111","email":"ada@example.test"},
         "target":{"title":"hidden","phone":"15500001111"},"expiresAt":"UNKNOWN","registrationState":"UNKNOWN","freeSelfPlay":true,
         "nextAction":"VIEW","token":"landing-credential"}
        """#)
        XCTAssertEqual(fact.headline, "朋友邀请你一起玩")
        XCTAssertEqual(fact.inviterNickname, "Ada")
        XCTAssertTrue(fact.targetPresent)
        XCTAssertTrue(fact.registrationStateIsUnknown)
        XCTAssertTrue(fact.expiresAtIsUnknown)
        XCTAssertTrue(fact.freeEntryOpen)
        XCTAssertFalse(fact.drawsGuaranteedSignup)
        XCTAssertFalse(fact.performsClaim)
        XCTAssertFalse(strings(in: fact).contains("landing-credential"))
        XCTAssertFalse(strings(in: fact).contains("15500001111"))
        XCTAssertFalse(strings(in: fact).contains("ada@example.test"))
        let blocked = try readyReferral(#"{"state":"NOT_ON_SALE","freeSelfPlay":true,"registrationState":"UNKNOWN"}"#)
        XCTAssertNil(blocked.headline)
        XCTAssertTrue(blocked.freeEntryOpen)
        XCTAssertFalse(blocked.drawsGuaranteedSignup)
        let noFree = try readyReferral(#"{"state":"NOT_ON_SALE","freeSelfPlay":false}"#)
        XCTAssertFalse(noFree.freeEntryOpen)
    }

    func testGiftClaimedDoesNotOfferReclaimOrBuyerIdentity() throws {
        let fact = try readyGift(#"""
        {"state":"CLAIMED","product":{"name":"ticket","buyerId":4,"phone":"15500002222"},"claimExpiresAt":"UNKNOWN","recipientBound":true,"token":"landing-credential"}
        """#)
        XCTAssertEqual(fact.state, "CLAIMED")
        XCTAssertTrue(fact.productPresent)
        XCTAssertTrue(fact.claimExpiresAtIsUnknown)
        XCTAssertEqual(fact.recipientBound, Optional(true))
        XCTAssertFalse(fact.reclaimOffered)
        XCTAssertFalse(fact.performsClaim)
        XCTAssertFalse(strings(in: fact).contains("landing-credential"))
        XCTAssertFalse(strings(in: fact).contains("15500002222"))
        let unbound = try readyGift(#"{"state":"CLAIMED","recipientBound":"true"}"#)
        XCTAssertNil(unbound.recipientBound)
        XCTAssertFalse(unbound.reclaimOffered)
    }

    func testPlayModeStaysHiddenUntilRequiredCapabilitiesAreSatisfied() {
        let denied = PWavePlayMode.decode(data: envelope(#"""
        {"configState":"PUBLISHED","choices":[{"label":"together"}],"requiredCapabilities":null,"teamModeSource":"CURRENT_TOPIC_COLUMN"}
        """#), status: 200, supportedServerCapabilities: ["theme.runtime"])
        XCTAssertFalse(denied.serverCapabilitySatisfied)
        XCTAssertEqual(denied.serverCapabilitiesDeclared, Optional(false))
        let hidden = PWaveGate.presentation(clientCapabilityPresent: false, fact: denied.fact,
                                            serverCapabilitiesDeclared: false)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)

        let missing = PWavePlayMode.decode(data: envelope(#"""
        {"configState":"PUBLISHED","choices":[{}],"requiredCapabilities":["theme.runtime"]}
        """#), status: 200, supportedServerCapabilities: [])
        XCTAssertEqual(missing.unsatisfiedServerCapabilities, ["theme.runtime"])
        XCTAssertFalse(missing.serverCapabilitySatisfied)
        let emptyList = PWavePlayMode.decode(data: envelope(#"""
        {"configState":"PUBLISHED","choices":[{}],"requiredCapabilities":[]}
        """#), status: 200, supportedServerCapabilities: [])
        XCTAssertEqual(emptyList.serverCapabilitiesDeclared, Optional(true))
        XCTAssertFalse(emptyList.serverCapabilitySatisfied)
    }

    func testSupportedModeDoesNotSubmitOrShareAPerMemberPool() throws {
        let decision = PWavePlayMode.decode(data: envelope(#"""
        {"configState":"FROZEN_RUN","runtimeScope":"RUN","worldMode":"CITY","routeMode":"LINEAR",
         "requiredCapabilities":["theme.runtime"],"teamModeSource":"CURRENT_TOPIC_COLUMN",
         "choices":[{"id":"a","pool":"PER_MEMBER"},{"id":"b"}]}
        """#), status: 200, supportedServerCapabilities: ["theme.runtime"])
        guard case .ready(let fact) = decision.fact else { return XCTFail("expected ready") }
        XCTAssertTrue(decision.serverCapabilitySatisfied)
        XCTAssertEqual(fact.configState, .frozenRun)
        XCTAssertEqual(fact.choiceCount, 2)
        XCTAssertEqual(fact.perMemberHintAndScore, Optional(true))
        XCTAssertEqual(fact.topicColumnIsFrozen, Optional(false))
        XCTAssertFalse(fact.teamSharedDeductionOffered)
        XCTAssertFalse(fact.modeSubmissionAvailable)
        XCTAssertFalse(PWavePlayModeFact.teamSharedPoolImplemented)
        XCTAssertEqual(fact.requiredCapabilities, ["theme.runtime"])
        let presented = PWaveGate.presentation(clientCapabilityPresent: true, fact: decision.fact,
                                              serverCapabilitiesDeclared: true)
        XCTAssertFalse(presented.hidden)
        XCTAssertEqual(presented.phase, .some(.ready(fact)))
    }

    func testUnavailableConfigIsEmptyAndNullChoicesAreNotAZeroList() {
        XCTAssertTrue(PWaveConfigState.unavailable.forcesEmptyChoices)
        let forced = PWavePlayMode.decode(data: envelope(#"""
        {"configState":"UNAVAILABLE","choices":[{"id":"borrowed"}],"requiredCapabilities":["theme.runtime"]}
        """#), status: 200, supportedServerCapabilities: ["theme.runtime"])
        XCTAssertEqual(forced.fact, .empty)
        let missing = PWavePlayMode.decode(data: envelope(#"""
        {"configState":"RUN_CONFIG_SNAPSHOT_MISSING","requiredCapabilities":["theme.runtime"],"choices":[{"id":"current"}]}
        """#), status: 200, supportedServerCapabilities: ["theme.runtime"])
        XCTAssertEqual(missing.fact, .empty)
        let nullChoices = PWavePlayMode.decode(data: envelope(#"""
        {"configState":"PUBLISHED","choices":null,"requiredCapabilities":["theme.runtime"]}
        """#), status: 200, supportedServerCapabilities: ["theme.runtime"])
        XCTAssertEqual(nullChoices.fact, .unknown)
        let silent = PWavePlayMode.decode(data: envelope(#"""
        {"configState":"PUBLISHED","requiredCapabilities":["theme.runtime"],"choices":[{},{}]}
        """#), status: 200, supportedServerCapabilities: ["theme.runtime"])
        guard case .ready(let fact) = silent.fact else { return XCTFail("expected ready") }
        XCTAssertNil(fact.perMemberHintAndScore)
        XCTAssertFalse(fact.teamSharedDeductionOffered)
        XCTAssertNil(fact.topicColumnIsFrozen)
    }

    func testSeatProjectionDoesNotInventCountsOrAdmitPlay() throws {
        let fact = try readySeats(#"""
        {"expiresAt":"UNKNOWN","originalPaid":true,"pending":1,"claimed":1,"free":0,"orderNum":4,"token":"plain-credential","state":"CLAIMED"}
        """#)
        XCTAssertEqual(fact.rows.count, 1)
        XCTAssertTrue(fact.rows[0].expiresAtIsUnknown)
        XCTAssertEqual(fact.rows[0].originalPaid, Optional(true))
        XCTAssertFalse(fact.playAdmissionSatisfied)
        XCTAssertFalse(fact.writesAvailable)
        XCTAssertFalse(fact.releaseAvailable)
        XCTAssertFalse(fact.appliesDefaultTTL)
        XCTAssertFalse(strings(in: fact).contains("plain-credential"))
        XCTAssertFalse(strings(in: fact).contains("CLAIMED"))
        let absentPaid = try readySeats(#"{"expiresAt":"2026-11-09T00:00:00Z"}"#)
        XCTAssertNil(absentPaid.rows[0].originalPaid)
        XCTAssertEqual(PWaveSeatRead.decode(data: envelope("[]"), status: 200), .empty)
        XCTAssertEqual(PWaveSeatRead.decode(data: envelope("[{}]"), status: 200), .unknown)
        let same = try PWaveSeatWriteDraft(invite: "reg-1", seatNo: "2", requestID: "req-1")
        let replay = try PWaveSeatWriteDraft(invite: "reg-1", seatNo: "2", requestID: "req-1")
        let conflict = try PWaveSeatWriteDraft(invite: "reg-1", seatNo: "3", requestID: "req-1")
        XCTAssertTrue(same.matchesReplay(of: replay))
        XCTAssertFalse(same.matchesReplay(of: conflict))
        XCTAssertFalse(same.available)
    }

    func testReaderHidesEveryFeatureUntilTheGrantAndDoesNotCallTheTransport() async throws {
        let wire = Wire()
        let reader = try makeReader(wire, granted: [])
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        let report = try await reader.battleReport(activityID: "12", token: "session-token", scope: scope, currentScope: { scope })
        let referral = try await reader.referralLanding(credential: "landing-credential", token: "session-token", scope: scope, currentScope: { scope })
        let modes = try await reader.playModes(topicID: "9", token: "session-token", scope: scope, currentScope: { scope })
        let seats = try await reader.seats(registrationID: "reg-1", token: "session-token", scope: scope, currentScope: { scope })
        XCTAssertNil(report.phase)
        XCTAssertNil(referral.phase)
        XCTAssertNil(modes.phase)
        XCTAssertNil(seats.phase)
        XCTAssertTrue(report.hidden && referral.hidden && modes.hidden && seats.hidden)
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testReaderDecodesReportAndDiscardsAStaleAccount() async throws {
        let wire = Wire(body: envelope(#"{"scopeKind":"RUN","score":4,"rank":2,"runId":"run-9"}"#))
        var current = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        let reader = try makeReader(wire, granted: [.battleReport])
        let seen = try await reader.battleReport(activityID: "12", runID: "run-9", token: "session-token",
                                                 scope: current, currentScope: { current })
        guard case .ready(let fact)? = seen.phase else { return XCTFail("expected ready") }
        XCTAssertFalse(seen.hidden)
        XCTAssertEqual(fact.score.literal, 4)
        XCTAssertEqual(fact.rank.literal, 2)
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].httpMethod, "GET")
        XCTAssertEqual(wire.requests[0].url?.path, "/api/play/player-journey/report")
        XCTAssertTrue(wire.requests[0].url?.query?.contains("activityId=12") == true)
        XCTAssertTrue(wire.requests[0].url?.query?.contains("runId=run-9") == true)
        XCTAssertEqual(wire.requests[0].value(forHTTPHeaderField: "Authorization"), "session-token")

        wire.body = envelope(#"{"score":9}"#)
        wire.onSend = { current = try! PWaveSessionScope(accountID: 8, epoch: 2, namespace: "cn") }
        let stale = try await reader.battleReport(activityID: "12", token: "session-token",
                                                  scope: try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn"),
                                                  currentScope: { current })
        XCTAssertNil(stale.phase)
        XCTAssertTrue(stale.hidden)
        XCTAssertEqual(wire.requests.count, 2)
    }

    func testReferralAndGiftReadsDoNotClaim() async throws {
        let wire = Wire(body: envelope(#"{"state":"VALID","freeSelfPlay":true,"registrationState":"UNKNOWN"}"#))
        let reader = try makeReader(wire, granted: [.inviteLanding])
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        let referral = try await reader.referralLanding(credential: "landing-credential", token: "session-token",
                                                        scope: scope, currentScope: { scope })
        guard case .ready(let fact)? = referral.phase else { return XCTFail("expected referral") }
        XCTAssertEqual(fact.headline, PWaveReferralFact.ordinaryHeadline)
        XCTAssertFalse(fact.performsClaim)
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/referral/landing/referral")
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String]
        XCTAssertEqual(body, ["token": "landing-credential"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "session-token")

        wire.body = envelope(#"{"state":"CLAIMED","product":{"name":"ticket"},"recipientBound":false}"#)
        let gift = try await reader.giftLanding(credential: "gift-credential", token: "session-token",
                                                scope: scope, currentScope: { scope })
        guard case .ready(let giftFact)? = gift.phase else { return XCTFail("expected gift") }
        XCTAssertFalse(giftFact.reclaimOffered)
        XCTAssertEqual(wire.requests[1].url?.path, "/api/referral/landing/gift")
        XCTAssertEqual(wire.requests.count, 2)
    }

    func testPlayModeAndSeatsUseTheNamedReadsAndRefuseWrites() async throws {
        let wire = Wire(body: envelope(#"""
        {"configState":"PUBLISHED","requiredCapabilities":["theme.runtime"],"choices":[{},{}]}
        """#))
        let reader = try makeReader(wire, granted: [.playMode, .ticketSeats], supported: ["theme.runtime"])
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        let modes = try await reader.playModes(topicID: "9", token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let mode)? = modes.phase else { return XCTFail("expected modes") }
        XCTAssertEqual(mode.choiceCount, 2)
        XCTAssertFalse(mode.modeSubmissionAvailable)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/play/player-journey/choices")
        XCTAssertTrue(wire.requests[0].url?.query?.contains("topicId=9") == true)

        wire.body = envelope(#"{"expiresAt":"2026-11-09T00:00:00Z","originalPaid":false}"#)
        let seats = try await reader.seats(registrationID: "reg-1", token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let list)? = seats.phase else { return XCTFail("expected seats") }
        XCTAssertEqual(list.rows[0].originalPaid, Optional(false))
        XCTAssertFalse(list.playAdmissionSatisfied)
        XCTAssertEqual(wire.requests[1].url?.path, "/api/play/player-journey/seats")
        XCTAssertTrue(wire.requests[1].url?.query?.contains("registrationId=reg-1") == true)

        wire.body = envelope("[]")
        let invitations = try await reader.seatInvitations(registrationID: "reg-1", token: "session-token", scope: scope, currentScope: { scope })
        XCTAssertEqual(invitations.phase, .some(.empty))
        XCTAssertEqual(wire.requests[2].url?.path, "/api/play/seat-invitations")

        wire.body = envelope(#"{"expiresAt":"2026-11-09T00:00:00Z","token":"plain-credential"}"#)
        let one = try await reader.seatInvitation(id: "inv-1", token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let row)? = one.phase else { return XCTFail("expected one seat") }
        XCTAssertFalse(strings(in: row).contains("plain-credential"))
        XCTAssertEqual(wire.requests[3].url?.path, "/api/play/seat-invitations/inv-1")
        XCTAssertNil(wire.requests[3].url?.query)

        XCTAssertThrowsError(try reader.invite(registrationID: "reg-1", requestID: "req-1", token: "session-token")) {
            XCTAssertEqual($0 as? PWaveRefusal, .writesNotAvailable)
        }
        XCTAssertThrowsError(try reader.claim(credential: "landing-credential", requestID: "req-1", token: "session-token"))
        XCTAssertThrowsError(try reader.cancel(invitationID: "inv-1", requestID: "req-1", token: "session-token"))
        XCTAssertThrowsError(try reader.release(invitationID: "inv-1", requestID: "req-1", token: "session-token"))
        XCTAssertEqual(wire.requests.count, 4)
    }

    func testBothScopeIdentifiersAndAZeroAccountAreRejectedBeforeASend() async throws {
        let wire = Wire()
        let reader = try makeReader(wire, granted: [.battleReport])
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        do {
            _ = try await reader.battleReport(activityID: "12", topicID: "9", token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("both ids")
        } catch PWaveRefusal.invalidRequest {}
        do {
            _ = try await reader.battleReport(token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("no id")
        } catch PWaveRefusal.invalidRequest {}
        XCTAssertThrowsError(try PWaveSessionScope(accountID: 0, epoch: 1, namespace: "cn"))
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testProductionEndpointsAreRefusedAndSendNothing() throws {
        let wire = Wire()
        let hosts = [
            "https://cn-gateway.chengyinhub.com",
            "https://us-gateway.chengyinhub.com",
            "https://www.chengyinhub.com",
            "https://api.chengyinhub.cn",
            "https://47.103.124.64"
        ]
        for host in hosts {
            XCTAssertThrowsError(try makeReader(wire, granted: [.battleReport], url: host))
        }
        XCTAssertThrowsError(try makeReader(wire, granted: [.battleReport], endpoint: .production)) {
            XCTAssertEqual($0 as? PWaveRefusal, .productionEndpoint)
        }
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testCoreSourcesDoNotCarryFixturesALiveSessionOrAWallet() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let files = FileManager.default
        while !files.fileExists(atPath: root.appendingPathComponent("Core/PWaveReader.swift").path) {
            let parent = root.deletingLastPathComponent()
            if parent.path == root.path { throw TestFailure() }
            root = parent
        }
        let sources = try files.contentsOfDirectory(at: root.appendingPathComponent("Core").resolvingSymlinksInPath(), includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("PWave") && $0.pathExtension == "swift" }
        XCTAssertEqual(sources.count, 11)
        let banned = ["URLSession", "168", "朋友送你一局", "跳过", "宝石", "Gem", "Wallet", "mock", "fixture", "synthetic", "elapsedSeconds"]
        for source in sources {
            let text = try String(contentsOf: source, encoding: .utf8)
            for token in banned {
                XCTAssertFalse(text.contains(token), "\(source.lastPathComponent) contains \(token)")
            }
        }
    }

    private func readyReport(_ data: String) throws -> PWaveBattleReportFact {
        let fact = PWaveBattleReport.decode(data: envelope(data), status: 200)
        guard case .ready(let value) = fact else { throw TestFailure() }
        return value
    }

    private func readyReferral(_ data: String) throws -> PWaveReferralFact {
        let fact = PWaveInviteLanding.decodeReferral(data: envelope(data), status: 200)
        guard case .ready(let value) = fact else { throw TestFailure() }
        return value
    }

    private func readyGift(_ data: String) throws -> PWaveGiftLandingFact {
        let fact = PWaveInviteLanding.decodeGift(data: envelope(data), status: 200)
        guard case .ready(let value) = fact else { throw TestFailure() }
        return value
    }

    private func readySeats(_ data: String) throws -> PWaveSeatListFact {
        let fact = PWaveSeatRead.decode(data: envelope(data), status: 200)
        guard case .ready(let value) = fact else { throw TestFailure() }
        return value
    }

    private func envelope(_ data: String) -> Data {
        Data(#"{"code":200,"msg":"ok","data":\#(data)}"#.utf8)
    }

    private func makeReader(_ wire: Wire, granted: Set<PWaveFeature>, supported: Set<String> = [],
                            url: String = "https://example.test",
                            endpoint: PWaveReader.PWaveEndpointClass = .nonProduction) throws -> PWaveReader {
        try PWaveReader(configuration: APIConfiguration(baseURL: URL(string: url)!), transport: wire,
                        endpointClass: endpoint,
                        capabilities: PWaveCapability(granted: granted, supportedServerCapabilities: supported))
    }

    private func strings(in value: Any, depth: Int = 0) -> [String] {
        if depth > 8 { return [] }
        if let text = value as? String { return [text] }
        return Mirror(reflecting: value).children.flatMap { strings(in: $0.value, depth: depth + 1) }
    }

    private struct TestFailure: Error {}

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var body: Data
        var status: Int
        var onSend: () -> Void = {}
        init(body: Data = Data(), status: Int = 200) {
            self.body = body
            self.status = status
        }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            onSend()
            return (body, status)
        }
    }
}
