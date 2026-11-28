import XCTest
@testable import QuestifyCore

/// Owns the ledger the way `SessionBackgroundLocationTracker` does. A strong driver inside the ledger
/// would keep this object alive after the test drops it.
@MainActor private final class LedgerOwningDriver: SessionLocationDriving {
    private(set) lazy var ledger = SessionLocationHoldLedger(driver: self)
    var starts: [Bool] = []
    func startUpdates(background: Bool) { starts.append(background) }
    func stopUpdates() {}
}

/// A fake `CLLocationManager` driver: records every start/stop and the background flag it was given.
@MainActor private final class FakeLocationDriver: SessionLocationDriving {
    var starts: [Bool] = []
    var stops = 0
    var running = false
    var background = false
    func startUpdates(background: Bool) { starts.append(background); running = true; self.background = background }
    func stopUpdates() { stops += 1; running = false; background = false }
}

/// WP-11. Each test names the completeness row it closes.
@MainActor final class WP11SessionLocationTests: XCTestCase {
    // MARK: OWN-D-07.a — reference-counted holds, background flags only while held

    func testOwnD07aReferenceCountedHoldsStopOnlyAtZero() {
        let driver = FakeLocationDriver(), ledger = SessionLocationHoldLedger(driver: driver)
        XCTAssertTrue(ledger.acquire("roam", foregroundOnly: false))
        XCTAssertFalse(ledger.acquire("roam", foregroundOnly: false)) // owner key is the idempotency key
        XCTAssertTrue(ledger.acquire("play:t1", foregroundOnly: true))
        XCTAssertEqual(ledger.count, 2); XCTAssertEqual(driver.starts, [true])
        ledger.release("play:t1")
        XCTAssertTrue(driver.running); XCTAssertEqual(driver.stops, 0)
        ledger.release("roam")
        XCTAssertFalse(driver.running); XCTAssertEqual(driver.stops, 1)
        XCTAssertFalse(ledger.isRunning); XCTAssertFalse(ledger.isBackground)
    }

    func testOwnD07aBackgroundFlagsOnlyWhileABackgroundHoldExists() {
        let driver = FakeLocationDriver(), ledger = SessionLocationHoldLedger(driver: driver)
        ledger.acquire("play:t1", foregroundOnly: true)
        XCTAssertEqual(driver.starts, [false]); XCTAssertFalse(ledger.isBackground)
        ledger.acquire("roam", foregroundOnly: false)
        XCTAssertEqual(driver.starts, [false, true]); XCTAssertTrue(ledger.isBackground)
        ledger.release("roam")
        XCTAssertEqual(driver.starts, [false, true, false]); XCTAssertFalse(driver.background)
        XCTAssertTrue(driver.running)
    }

    // MARK: OWN-D-07.d — stop rules

    func testOwnD07dNoHoldMeansNoUpdatesAndBackgroundIsNotARelease() {
        let driver = FakeLocationDriver(), ledger = SessionLocationHoldLedger(driver: driver)
        // No session: nothing ever starts.
        XCTAssertTrue(driver.starts.isEmpty); XCTAssertFalse(ledger.isRunning)
        ledger.acquire("roam", foregroundOnly: false)
        // The ledger has no foreground/background input at all: only a release, revoke or account change stops it.
        XCTAssertTrue(ledger.isRunning); XCTAssertEqual(driver.stops, 0)
    }

    func testOwnD07dAccountChangeReleasesWithinOneCallback() {
        let driver = FakeLocationDriver(), ledger = SessionLocationHoldLedger(driver: driver)
        var account = 9001
        ledger.acquire("roam", foregroundOnly: false, isCurrent: { account == 9001 })
        XCTAssertFalse(ledger.dropStaleOwners())
        account = 9002
        XCTAssertTrue(ledger.dropStaleOwners()) // the first location callback after the switch
        XCTAssertFalse(ledger.isRunning); XCTAssertEqual(driver.stops, 1)
        XCTAssertFalse(ledger.acquire("roam", foregroundOnly: false, isCurrent: { account == 9001 }))
    }

    func testOwnD07dRevokeMovesRevisionNotifiesAndKeepsOtherPurposes() {
        let driver = FakeLocationDriver(), ledger = SessionLocationHoldLedger(driver: driver)
        var heard = 0
        let cancel = ledger.observeRevocation("roam") { heard += 1 }
        ledger.acquire("roam", foregroundOnly: false); ledger.acquire("play:t1", foregroundOnly: true)
        ledger.revoke(.roam)
        XCTAssertEqual(heard, 1); XCTAssertEqual(ledger.revision("roam"), 1)
        XCTAssertFalse(ledger.hasOwner("roam")); XCTAssertTrue(ledger.isRunning); XCTAssertFalse(ledger.isBackground)
        cancel(); ledger.acquire("roam", foregroundOnly: false); ledger.revoke("roam")
        XCTAssertEqual(heard, 1)
        ledger.revoke(.play)
        XCTAssertFalse(ledger.isRunning); XCTAssertGreaterThanOrEqual(driver.stops, 1)
    }

    func testOwnD07dDriverFailureEndsEveryHoldAndTellsItsOwner() {
        let driver = FakeLocationDriver(), ledger = SessionLocationHoldLedger(driver: driver)
        var failed = 0
        ledger.acquire("roam", foregroundOnly: false, onFailure: { _ in failed += 1 })
        ledger.driverFailed(APIError.unauthorized)
        XCTAssertEqual(failed, 1); XCTAssertEqual(ledger.count, 0); XCTAssertFalse(driver.running)
    }

    // MARK: OWN-D-07.e — which purposes hold location now

    func testOwnD07ePurposesListedForThePrivacyPage() {
        let ledger = SessionLocationHoldLedger(driver: FakeLocationDriver())
        XCTAssertEqual(ledger.activePurposes, [])
        ledger.acquire("play:41:9001:1", foregroundOnly: true)
        ledger.acquire("roam", foregroundOnly: false)
        XCTAssertEqual(ledger.activePurposes, [.roam, .play])
        XCTAssertEqual(SessionLocationHoldLedger.Purpose.of(key: "unknown"), nil)
    }

    func testSessionLocationDriverThatOwnsItsLedgerDeallocates() {
        weak var released: LedgerOwningDriver?
        do {
            let driver = LedgerOwningDriver()
            released = driver
            XCTAssertTrue(driver.ledger.acquire("roam", foregroundOnly: false))
            XCTAssertTrue(driver.ledger.isRunning)
            XCTAssertEqual(driver.starts, [true])
            driver.ledger.release("roam")
            XCTAssertFalse(driver.ledger.isRunning)
        }
        XCTAssertNil(released)
    }

    // MARK: OWN-10.3 — content contract v1 (C2)

    func testOwn10_3UnconfirmedNeverBlocksAndUnsupportedNamesMissingKeys() throws {
        // OWN-10.3.a: no or malformed declaration is unconfirmed and does not block a start.
        for raw in [#"{"requiredCapabilities":[{"key":"chapter.blocks","minVersion":1}],"declared":false,"missingCapabilities":[],"supported":null,"source":"UNDECLARED"}"#,
                    #"{"requiredCapabilities":[],"declared":false,"missingCapabilities":[],"supported":null,"source":"MALFORMED"}"#] {
            let value = try XCTUnwrap(PlayContentCompatibility(raw: PlayExperienceSyntheticFixtures.wire(raw)))
            guard case .unconfirmed = value.verdict else { return XCTFail(raw) }
            XCTAssertFalse(value.blocksStart); XCTAssertEqual(value.missingKeys, [])
        }
        // OWN-10.3.b: a compared declaration with missing keys blocks only this content, and the reason is the keys.
        let refused = try XCTUnwrap(PlayContentCompatibility(raw: PlayExperienceSyntheticFixtures.wire(#"{"requiredCapabilities":[{"key":"game.hangman","minVersion":2}],"declared":true,"missingCapabilities":[{"key":"game.hangman","minVersion":2,"declaredVersion":1}],"supported":false,"source":"DECLARED"}"#)))
        XCTAssertTrue(refused.blocksStart); XCTAssertEqual(refused.missingKeys, ["game.hangman"])
        let supported = try XCTUnwrap(PlayContentCompatibility(raw: PlayExperienceSyntheticFixtures.wire(#"{"requiredCapabilities":[],"declared":true,"missingCapabilities":[],"supported":true,"source":"DECLARED"}"#)))
        XCTAssertFalse(supported.blocksStart)
    }

    // MARK: OWN-OPT-042.a — audio interruption

    func testOwnOPT042aResumeOnlyWhatWasPlayingAndNeverFromBackground() {
        var policy = PlatformAudioInterruptionResume()
        XCTAssertEqual(policy.decide(.interruptionBegan, playing: true, ownsConfiguration: true), .pauseForInterruption)
        XCTAssertEqual(policy.decide(.interruptionEnded(shouldResume: false), playing: false, ownsConfiguration: true), .resume)
        XCTAssertEqual(policy.decide(.interruptionEnded(shouldResume: true), playing: true, ownsConfiguration: true), .ignore)
        // User-paused audio is untouched by a call and not resumed after it.
        XCTAssertEqual(policy.decide(.interruptionBegan, playing: false, ownsConfiguration: true), .ignore)
        XCTAssertEqual(policy.decide(.interruptionEnded(shouldResume: true), playing: false, ownsConfiguration: true), .ignore)
        // A user action during the call cancels the pending resume.
        _ = policy.decide(.interruptionBegan, playing: true, ownsConfiguration: true); policy.userActed()
        XCTAssertEqual(policy.decide(.interruptionEnded(shouldResume: true), playing: false, ownsConfiguration: true), .ignore)
        // Background stops and clears; the following interruption end resumes nothing.
        _ = policy.decide(.interruptionBegan, playing: true, ownsConfiguration: true)
        XCTAssertEqual(policy.decide(.enteredBackground, playing: false, ownsConfiguration: true), .stop)
        XCTAssertEqual(policy.decide(.interruptionEnded(shouldResume: true), playing: false, ownsConfiguration: true), .ignore)
        // Nothing loaded yet: a call still stops the pending start.
        XCTAssertEqual(policy.decide(.interruptionBegan, playing: nil, ownsConfiguration: true), .stop)
    }

    // MARK: OWN-OPT-072 — copyable, non-sensitive request reference

    func testOwnOPT072RequestReferenceIsSanitizedScopedAndFresh() {
        let ledger = RequestReferenceLedger(), now = Date(timeIntervalSince1970: 1_800_000_000)
        ledger.record(path: "/api/play/nodes", headerValue: "d81d7c38d3bc4ede9ca68a6191299c6e", now: now)
        ledger.record(path: "/api/roam/reveal", headerValue: "Bearer eyJhbGciOi.secret", now: now)
        XCTAssertEqual(ledger.latest(pathFragment: "/api/play/", now: now), "d81d7c38d3bc4ede9ca68a6191299c6e")
        XCTAssertNil(ledger.latest(pathFragment: "/api/roam/", now: now))
        XCTAssertNil(ledger.latest(pathFragment: "/api/play/", now: now.addingTimeInterval(121)))
        XCTAssertNil(RequestReferenceLedger.sanitize("13900000001 token"))
        XCTAssertNil(RequestReferenceLedger.sanitize("短"))
    }

    // MARK: OWN-D-01 (WP-11 brief) — spend rules and the two points refusal reasons

    func testOwnD01aSpendRulesListedSeparatelyAndDeletedRowsDropped() throws {
        let rows = try JSONDecoder().decode([WalletPointsTask].self, from: Data(#"""
        [{"id":1,"status":1,"eventType":1,"title":"Check in","value":5},
         {"id":2,"status":1,"eventType":14,"title":"Unlock a hint","value":10},
         {"id":3,"status":1,"eventType":2,"title":"Deleted","delFlag":"2"},
         {"id":4,"status":0,"eventType":14,"title":"Disabled"},
         {"id":5,"status":1,"eventType":3,"title":"Numeric flag","delFlag":0}]
        """#.utf8))
        let rules = WalletPointsRules(rows)
        XCTAssertEqual(rules.earn.map(\.id), [1, 5])
        XCTAssertEqual(rules.spend.map(\.id), [2])
    }

    func testOwnD01bTwoRefusalReasonsFromTheServerQuote() throws {
        let zero = try JSONDecoder().decode(RegistrationQuote.self, from: Data(#"{"payAmount":20,"pointsDeductYuan":0,"pointsUsable":false,"quoteSign":"s"}"#.utf8))
        let some = try JSONDecoder().decode(RegistrationQuote.self, from: Data(#"{"payAmount":18,"pointsDeductYuan":2,"pointsUsable":true,"quoteSign":"s"}"#.utf8))
        XCTAssertEqual(RegistrationPointsRefusal(usePoints: true, quote: zero, availablePoints: 0), .noPoints)
        XCTAssertEqual(RegistrationPointsRefusal(usePoints: true, quote: zero, availablePoints: nil), .noPoints)
        XCTAssertEqual(RegistrationPointsRefusal(usePoints: true, quote: zero, availablePoints: 300), .ticketRefusesPoints)
        XCTAssertNil(RegistrationPointsRefusal(usePoints: false, quote: zero, availablePoints: 300))
        XCTAssertNil(RegistrationPointsRefusal(usePoints: true, quote: some, availablePoints: 300))
        XCTAssertEqual(RegistrationPointsRefusal.noPoints.localizationKey, "registration.form.points.noPoints")
    }

    func testOwnD01cClientPriceDoesNotApplyAPointRate() {
        let price = RegistrationCoreLoopRules.computeOrderPrice(
            unitPrice: 100, quantity: 2, memberDiscountRate: Decimal(string: "0.9"), couponDeductYuan: 10)
        XCTAssertEqual(price.pointsDeductYuan, 0)
        XCTAssertEqual(price.pointsUsed, 0)
        XCTAssertEqual(price.payAmount, 170)
    }

    func testOwnOPT042bCountdownUsesServerClockOrAnEmDash() throws {
        let window = try NativeTimeWindow(nativeWindow())
        XCTAssertEqual(window.countdownSeconds, 3_600)
        let raw = try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"sessionId":601,"activityId":41,"topicId":71,"nodeId":701,"version":2,"status":"RUNNING","deadlineAt":1790938800000}"#.utf8))
        let state = try PlayAdvancedState(raw)
        XCTAssertNotNil(state.deadlineAt)
        XCTAssertNil(state.remainingSeconds(nowMilliseconds: 1_790_935_200_000))
    }
}
