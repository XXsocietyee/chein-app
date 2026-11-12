import XCTest
@testable import QuestifyCore

final class SideQuestPlayerFlowTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 3_000_000)
    private let dash = "\u{2014}"

    private func instance(
        _ id: String = "i1",
        status: SideQuestSpawnInstance.Status = .open,
        capacity: Int? = 3,
        from: TimeInterval = -60,
        until: TimeInterval = 3600,
        title: String = "Synthetic side quest"
    ) throws -> SideQuestSpawnInstance {
        try .init(
            instanceID: id,
            definitionID: "d1",
            definitionVersion: 2,
            place: .init(type: .store, id: "77"),
            themeReleaseID: nil,
            visibleFrom: now.addingTimeInterval(from),
            visibleUntil: now.addingTimeInterval(until),
            status: status,
            remainingCapacity: capacity,
            title: title
        )
    }

    private func row(
        _ id: String = "i1",
        policy: SideQuestPlayerFlow.RepeatPolicy? = .unrestricted,
        capacity: Int? = 3,
        status: SideQuestSpawnInstance.Status = .open,
        from: TimeInterval = -60,
        until: TimeInterval = 3600,
        reward: String? = "12"
    ) throws -> SideQuestPlayerFlow.Row {
        SideQuestPlayerFlow.Row(
            instance: try instance(id, status: status, capacity: capacity, from: from, until: until),
            repeatPolicy: policy,
            rewardText: reward
        )
    }

    func testProductionEntryIsClosedBesideTheSearchMap() {
        let snapshot = SideQuestPlayerFlow.production
        XCTAssertFalse(SideQuestPlayerFlow.sourcePagePresent)
        XCTAssertEqual(SideQuestPlayerFlow.sourceRevision, "1c80c5aea8f721ca8575e6108048495b100f5576")
        XCTAssertFalse(SideQuestPlayerFlow.routeInstalled)
        XCTAssertFalse(SideQuestPlayerFlow.routeMarkedLive)
        XCTAssertEqual(snapshot.placement, .besideSearchMap)
        XCTAssertEqual(snapshot.phase, .sourceAbsent)
        XCTAssertEqual(snapshot.totalText, dash)
        XCTAssertEqual(snapshot.statusText, dash)
        XCTAssertTrue(snapshot.rows.isEmpty)
        XCTAssertFalse(snapshot.addsMarkerLayer)
        XCTAssertFalse(snapshot.sourcePagePresent)
        XCTAssertFalse(snapshot.showsAccept)
        XCTAssertFalse(snapshot.showsStart)
        XCTAssertFalse(snapshot.showsAnswer)
        XCTAssertFalse(snapshot.showsCancel)
    }

    func testMoneyAndAcceptStayOff() {
        XCTAssertFalse(SideQuestPlayerFlow.paymentEnabled)
        XCTAssertFalse(SideQuestPlayerFlow.payoutEnabled)
        XCTAssertFalse(SideQuestPlayerFlow.withdrawalEnabled)
        XCTAssertFalse(SideQuestPlayerFlow.virtualGoodsEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        XCTAssertFalse(SideQuestPlayerFlow.acceptEnabled)
        XCTAssertFalse(SideQuestFeature.acceptEnabled)
    }

    func testASuppliedReadStaysHiddenOnTheProductionEntry() throws {
        let read = SideQuestPlayerFlow.Read.loaded([try row()])
        let hidden = SideQuestPlayerFlow.project(read: read, now: now)
        XCTAssertEqual(hidden.phase, .sourceAbsent)
        XCTAssertEqual(hidden.totalText, dash)
        XCTAssertTrue(hidden.rows.isEmpty)
        XCTAssertFalse(hidden.addsMarkerLayer)
    }

    func testUnknownReadsUseAnEmDashAndALoadedEmptyReadUsesZero() throws {
        let flow = SideQuestPlayerFlow.self
        let reads: [SideQuestPlayerFlow.Read?] = [nil, .loading, .failed, .unknown]
        for read in reads {
            let snapshot = flow.project(read: read, now: now, presentSuppliedRead: true)
            XCTAssertEqual(snapshot.totalText, dash)
            XCTAssertEqual(snapshot.statusText, dash)
            XCTAssertTrue(snapshot.rows.isEmpty)
        }
        XCTAssertEqual(flow.project(read: nil, now: now, presentSuppliedRead: true).phase, .unknown)
        XCTAssertEqual(flow.project(read: .loading, now: now, presentSuppliedRead: true).phase, .loading)
        XCTAssertEqual(flow.project(read: .failed, now: now, presentSuppliedRead: true).phase, .error)
        let empty = flow.project(read: .loaded([]), now: now, presentSuppliedRead: true)
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.totalText, "0")
        XCTAssertEqual(empty.statusText, dash)
    }

    func testDiscoveryKeepsUnrestrictedRowsAndDropsEveryOtherPolicy() throws {
        let read = SideQuestPlayerFlow.Read.loaded([
            try row("open", capacity: nil, reward: nil),
            try row("zero", capacity: 0, reward: "0"),
            try row("once", policy: .once),
            try row("coupon", policy: SideQuestPlayerFlow.parsedRepeatPolicy("COUPON")),
            try row("blank", policy: SideQuestPlayerFlow.parsedRepeatPolicy("  ")),
            try row("lower", policy: SideQuestPlayerFlow.parsedRepeatPolicy("unrestricted")),
            try row("closed", status: .closed),
            try row("ended", until: -1),
            try row("paused", status: .paused, reward: "9")
        ])
        let snapshot = SideQuestPlayerFlow.project(read: read, now: now, presentSuppliedRead: true)
        XCTAssertEqual(snapshot.phase, .ready)
        XCTAssertEqual(snapshot.totalText, "3")
        XCTAssertEqual(snapshot.statusText, dash)
        XCTAssertEqual(snapshot.rows.map(\.id), ["open", "zero", "paused"])
        XCTAssertEqual(snapshot.rows.map(\.capacityText), [dash, "0", "3"])
        XCTAssertEqual(snapshot.rows.map(\.rewardText), [dash, dash, dash])
        XCTAssertEqual(snapshot.rows.map(\.offersServerAccept), [true, false, false])
        XCTAssertTrue(snapshot.rows.allSatisfy { $0.showsAccept == false })
        XCTAssertFalse(snapshot.addsMarkerLayer)
        XCTAssertFalse(snapshot.showsAccept)
    }

    func testFilteredOutReadIsAnEmptyZeroNotAnUnknownCount() throws {
        let read = SideQuestPlayerFlow.Read.loaded([try row(policy: .once)])
        let snapshot = SideQuestPlayerFlow.project(read: read, now: now, presentSuppliedRead: true)
        XCTAssertEqual(snapshot.phase, .empty)
        XCTAssertEqual(snapshot.totalText, "0")
        XCTAssertTrue(snapshot.rows.isEmpty)
    }

    func testRepeatPolicyParserDoesNotGuess() {
        XCTAssertEqual(SideQuestPlayerFlow.parsedRepeatPolicy("UNRESTRICTED"), .unrestricted)
        XCTAssertEqual(SideQuestPlayerFlow.parsedRepeatPolicy(" ONCE "), .once)
        XCTAssertNil(SideQuestPlayerFlow.parsedRepeatPolicy("COUPON"))
        XCTAssertNil(SideQuestPlayerFlow.parsedRepeatPolicy("unrestricted"))
        XCTAssertNil(SideQuestPlayerFlow.parsedRepeatPolicy(nil))
        XCTAssertNil(SideQuestPlayerFlow.parsedRepeatPolicy(""))
    }

    func testProductionActionsDoNotMutateTheBookOrRecordAChoice() throws {
        var book = SideQuestAttemptBook()
        let quest = try instance()
        let request = try book.prepareAcceptForContract(quest, now: now, requestID: UUID())
        book.finishAccept(request, attempt: nil)
        let before = book
        let read = SideQuestPlayerFlow.Read.loaded([try row()])
        for action in [
            SideQuestPlayerFlow.Action.start(instanceID: "i1"),
            .answer(instanceID: "i1", choice: "A"),
            .answer(instanceID: "i1", choice: nil),
            .answer(instanceID: "i1", choice: "0"),
            .cancel(instanceID: "i1")
        ] {
            let result = SideQuestPlayerFlow.perform(action, book: book, read: read, now: now, moneyWrite: true)
            XCTAssertEqual(result.refusal, .sourcePageAbsent)
            XCTAssertEqual(result.book, before)
            XCTAssertEqual(result.choiceText, dash)
            XCTAssertFalse(result.applied)
            XCTAssertEqual(book, before)
        }
    }

    func testGateOrderStopsAtTheFirstClosedSwitch() throws {
        var book = SideQuestAttemptBook()
        let quest = try instance()
        let request = try book.prepareAcceptForContract(quest, now: now, requestID: UUID())
        book.finishAccept(request, attempt: nil)
        let read = SideQuestPlayerFlow.Read.loaded([try row()])
        let action = SideQuestPlayerFlow.Action.answer(instanceID: "i1", choice: nil)
        XCTAssertEqual(reason(action, book: book, read: read, source: false, accept: true, money: true), .sourcePageAbsent)
        XCTAssertEqual(reason(action, book: book, read: read, source: true, accept: true, money: true), .moneyOff)
        XCTAssertEqual(reason(action, book: book, read: read, source: true, accept: false, money: false), .acceptDisabled)
        XCTAssertEqual(reason(action, book: book, read: read, source: true, accept: true, money: false), .unknownOutcome)
    }

    func testListedAnswerStillDoesNotWriteAReadback() throws {
        let book = SideQuestAttemptBook()
        let read = SideQuestPlayerFlow.Read.loaded([try row()])
        let present = SideQuestPlayerFlow.perform(
            .answer(instanceID: "i1", choice: "0"),
            book: book,
            read: read,
            now: now,
            sourcePagePresent: true,
            acceptEnabled: true
        )
        XCTAssertEqual(present.refusal, .noAuthoritativeReadback)
        XCTAssertEqual(present.book, book)
        XCTAssertEqual(present.choiceText, dash)
        XCTAssertFalse(present.applied)
        let missing = SideQuestPlayerFlow.perform(
            .answer(instanceID: "i1", choice: "  "),
            book: book,
            read: read,
            now: now,
            sourcePagePresent: true,
            acceptEnabled: true
        )
        XCTAssertEqual(missing.refusal, .missingChoice)
        XCTAssertEqual(missing.choiceText, dash)
        let hidden = SideQuestPlayerFlow.perform(
            .start(instanceID: "i1"),
            book: book,
            read: .loaded([try row(policy: .once)]),
            now: now,
            sourcePagePresent: true,
            acceptEnabled: true
        )
        XCTAssertEqual(hidden.refusal, .notListed)
        XCTAssertEqual(hidden.book, book)
        XCTAssertFalse(hidden.applied)
    }

    private func reason(
        _ action: SideQuestPlayerFlow.Action,
        book: SideQuestAttemptBook,
        read: SideQuestPlayerFlow.Read,
        source: Bool,
        accept: Bool,
        money: Bool
    ) -> SideQuestPlayerFlow.Refusal {
        SideQuestPlayerFlow.refusal(
            action: action,
            book: book,
            read: read,
            now: now,
            sourcePagePresent: source,
            acceptEnabled: accept,
            moneyWrite: money
        )
    }
}
