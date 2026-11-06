import XCTest
@testable import Questify

/// Exercises the same ticket owner used by all three asynchronous Form actions.
@MainActor final class ClubGovernanceFormLifecycleTests: XCTestCase {
    private func context(_ access: FormLifecycleAccess, _ coordinator: ClubGovernanceCoordinator,
                         identity: ClubReadIdentity? = .init(accountID: 701, epoch: 1),
                         operation: ClubGovernanceMutation = .saveTopicSettings,
                         scope: ClubGovernanceScope = ClubGovernanceFixtures.scope,
                         visible: Bool = true, active: Bool = true) -> ClubGovernanceFormLifecycle.Context {
        .init(identity: identity, access: access, coordinator: coordinator, operation: operation,
              scope: scope, visible: visible, active: active)
    }
    func testEachActionRejectsDoubleAdmissionAndOldDeferCannotFinishSameGenerationReplacement() throws {
        let access = FormLifecycleAccess(), coordinator = ClubGovernanceCoordinator(access: access)
        let current = context(access, coordinator)
        for work in [ClubGovernanceFormLifecycle.Work.prepare, .confirm, .customerEdit] {
            var owner = ClubGovernanceFormLifecycle()
            let first = try XCTUnwrap(owner.begin(work, in: current))
            XCTAssertTrue(owner.busy); XCTAssertNil(owner.begin(work, in: current))
            owner.finish(first)
            let replacement = try XCTUnwrap(owner.begin(work, in: current))
            owner.finish(first)
            XCTAssertTrue(owner.busy); XCTAssertTrue(owner.owns(replacement, in: current))
            owner.finish(replacement); XCTAssertFalse(owner.busy)
        }
    }
    func testBackgroundCloseAuthorizationAndRepeatedRetirementReleaseOnlyPresentation() throws {
        let access = FormLifecycleAccess(), coordinator = ClubGovernanceCoordinator(access: access)
        for operation in [ClubGovernanceMutation.issueGroupCode, .saveCustomer, .sendNotification, .hostApply] {
            for work in [ClubGovernanceFormLifecycle.Work.prepare, .confirm, .customerEdit] {
                var owner = ClubGovernanceFormLifecycle()
                let current = context(access, coordinator, operation: operation)
                let old = try XCTUnwrap(owner.begin(work, in: current))
                owner.retire(); owner.retire()
                XCTAssertFalse(owner.busy); XCTAssertFalse(owner.owns(old, in: current))
                XCTAssertNil(owner.begin(work, in: context(access, coordinator, operation: operation, active: false)))
                XCTAssertNil(owner.begin(work, in: context(access, coordinator, operation: operation, visible: false)))
                let fresh = try XCTUnwrap(owner.begin(work, in: current))
                owner.finish(old); XCTAssertTrue(owner.owns(fresh, in: current))
                owner.finish(fresh); XCTAssertFalse(owner.busy)
                XCTAssertEqual(coordinator.state, .idle); XCTAssertEqual(access.sends, 0)
            }
        }
    }
    func testContextFencesEpochABAApprovalRealmAccessCoordinatorOperationAndScope() throws {
        let access = FormLifecycleAccess(), coordinator = ClubGovernanceCoordinator(access: access)
        var owner = ClubGovernanceFormLifecycle()
        let old = try XCTUnwrap(owner.begin(.confirm, in: context(access, coordinator)))
        access.identity = .init(accountID: 702, epoch: 2)
        XCTAssertFalse(owner.owns(old, in: context(access, coordinator)))
        access.identity = .init(accountID: 701, epoch: 3)
        XCTAssertFalse(owner.owns(old, in: context(access, coordinator, identity: access.identity)))
        access.identity = .init(accountID: 701, epoch: 1)
        access.authorizationGeneration = UUID()
        XCTAssertFalse(owner.owns(old, in: context(access, coordinator)))
        owner.retire()
        let fresh = try XCTUnwrap(owner.begin(.prepare, in: context(access, coordinator)))
        access.isConfigured = false
        XCTAssertFalse(owner.owns(fresh, in: context(access, coordinator)))
        access.isConfigured = true
        let originalRealm = access.journalRealm
        access.journalRealm += "-other"
        XCTAssertFalse(owner.owns(fresh, in: context(access, coordinator)))
        access.journalRealm = originalRealm
        access.storageNamespace += "-other"
        XCTAssertFalse(owner.owns(fresh, in: context(access, coordinator)))
        access.storageNamespace = "form-lifecycle-tests"
        XCTAssertFalse(owner.owns(fresh, in: context(FormLifecycleAccess(), coordinator)))
        XCTAssertFalse(owner.owns(fresh, in: context(access, ClubGovernanceCoordinator(access: access))))
        XCTAssertFalse(owner.owns(fresh, in: context(access, coordinator, operation: .issueGroupCode)))
        XCTAssertFalse(owner.owns(fresh, in: context(access, coordinator, scope: .init(clubID: 82))))
        owner.retire(); owner.finish(old); owner.finish(fresh); XCTAssertFalse(owner.busy)
    }
    func testSignedOutHiddenAndUnconfiguredCannotBeginQueuedWork() {
        let access = FormLifecycleAccess(), coordinator = ClubGovernanceCoordinator(access: access)
        var owner = ClubGovernanceFormLifecycle()
        XCTAssertNil(owner.begin(.prepare, in: context(access, coordinator, identity: nil)))
        XCTAssertNil(owner.begin(.confirm, in: context(access, coordinator, visible: false)))
        XCTAssertNil(owner.begin(.customerEdit, in: context(access, coordinator, active: false)))
        access.isConfigured = false
        XCTAssertNil(owner.begin(.prepare, in: context(access, coordinator)))
        XCTAssertFalse(owner.busy); XCTAssertEqual(access.sends, 0)
    }
    func testSuspendedPrepareRetiresAndItsCompletionCannotPublishOrClearNewActivity() async throws {
        let access = FormLifecycleAccess(), coordinator = ClubGovernanceCoordinator(access: access)
        let owner = FormLifecycleBox(), gate = FormLifecycleGate()
        let current = context(access, coordinator)
        let old = try XCTUnwrap(owner.value.begin(.prepare, in: current))
        let task = Task { () throws -> Bool in
            defer { owner.value.finish(old) }
            await gate.wait()
            guard owner.value.owns(old, in: current) else { return false }
            _ = try await coordinator.prepare(ClubGovernanceFixtures.command(.saveTopicSettings))
            return true
        }
        await gate.entered()
        owner.value.retire()
        let fresh = try XCTUnwrap(owner.value.begin(.prepare, in: current))
        gate.release()
        let published = try await task.value
        XCTAssertFalse(published); XCTAssertTrue(owner.value.owns(fresh, in: current))
        XCTAssertEqual(access.reads, 0); XCTAssertEqual(access.sends, 0)
        owner.value.finish(fresh)
        let review = try await coordinator.prepare(ClubGovernanceFixtures.command(.saveTopicSettings))
        XCTAssertEqual(review.identity, access.identity)
    }
    func testPrepareAlreadyReadingCannotPublishAfterOwnerChangeAndNewEpochCanReview() async throws {
        let access = FormLifecycleAccess(), coordinator = ClubGovernanceCoordinator(access: access)
        let owner = FormLifecycleBox(), gate = FormLifecycleGate()
        access.readGate = gate
        let ticket = try XCTUnwrap(owner.value.begin(.prepare, in: context(access, coordinator)))
        let task = Task { () -> Bool in
            defer { owner.value.finish(ticket) }
            do {
                _ = try await coordinator.prepare(ClubGovernanceFixtures.command(.saveTopicSettings))
                return owner.value.owns(ticket, in: self.context(access, coordinator))
            } catch { return false }
        }
        await gate.entered()
        owner.value.retire(); coordinator.cancelReview()
        access.identity = .init(accountID: 701, epoch: 2); access.authorizationGeneration = UUID()
        gate.release()
        let published = await task.value
        XCTAssertFalse(published); XCTAssertFalse(owner.value.busy); XCTAssertEqual(access.sends, 0)
        let review = try await coordinator.prepare(ClubGovernanceFixtures.command(.saveTopicSettings))
        XCTAssertEqual(review.identity, access.identity)
    }
    func testConfirmRetiredDuringPreflightDoesNotReserveOrSend() async throws {
        let access = FormLifecycleAccess(), journal = FormLifecycleJournal()
        let coordinator = ClubGovernanceCoordinator(access: access, journal: journal)
        let review = try await coordinator.prepare(ClubGovernanceFixtures.command(.saveTopicSettings))
        let owner = FormLifecycleBox(), gate = FormLifecycleGate(); access.readGate = gate
        let ticket = try XCTUnwrap(owner.value.begin(.confirm, in: context(access, coordinator)))
        let task = confirming(review, owner: owner, ticket: ticket, access: access, coordinator: coordinator)
        await gate.entered()
        owner.value.retire(); coordinator.cancelReview(); gate.release()
        let callback = await task.value
        XCTAssertFalse(callback); XCTAssertFalse(owner.value.busy)
        XCTAssertTrue(journal.keys.isEmpty); XCTAssertEqual(access.sends, 0)
    }
    func testConfirmRetiredDuringDurableReserveKeepsReservationAndDoesNotDispatch() async throws {
        let access = FormLifecycleAccess(), journal = FormLifecycleJournal()
        let coordinator = ClubGovernanceCoordinator(access: access, journal: journal)
        let review = try await coordinator.prepare(ClubGovernanceFixtures.command(.saveTopicSettings))
        let owner = FormLifecycleBox(), gate = FormLifecycleGate(); journal.gate = gate
        let ticket = try XCTUnwrap(owner.value.begin(.confirm, in: context(access, coordinator)))
        let task = confirming(review, owner: owner, ticket: ticket, access: access, coordinator: coordinator)
        await gate.entered()
        XCTAssertEqual(journal.keys.count, 1)
        owner.value.retire(); coordinator.cancelReview(); gate.release()
        let callback = await task.value
        XCTAssertFalse(callback); XCTAssertFalse(owner.value.busy); XCTAssertEqual(access.sends, 0)
        XCTAssertEqual(journal.keys.count, 1)
        XCTAssertTrue(coordinator.isLocked(review.command, identity: review.identity))
        let rebuilt = ClubGovernanceCoordinator(access: access, journal: journal)
        XCTAssertTrue(rebuilt.isLocked(review.command, identity: review.identity))
    }
    func testLateAckUnknownAnd403AfterDispatchCannotCallOldOwnerOrReleaseJournal() async throws {
        for result in [ClubGovernanceFailure?.none, .unknown(message: nil), .forbidden] {
            let access = FormLifecycleAccess(), journal = FormLifecycleJournal()
            let coordinator = ClubGovernanceCoordinator(access: access, journal: journal)
            let review = try await coordinator.prepare(ClubGovernanceFixtures.command(.saveTopicSettings))
            let owner = FormLifecycleBox(), gate = FormLifecycleGate(); access.sendGate = gate; access.sendFailure = result
            let current = context(access, coordinator)
            let ticket = try XCTUnwrap(owner.value.begin(.confirm, in: current))
            let task = confirming(review, owner: owner, ticket: ticket, access: access, coordinator: coordinator)
            await gate.entered()
            XCTAssertNil(owner.value.begin(.confirm, in: current)); XCTAssertEqual(access.sends, 1)
            owner.value.retire()
            let newer = try XCTUnwrap(owner.value.begin(.prepare, in: current))
            gate.release()
            let callback = await task.value
            XCTAssertFalse(callback); XCTAssertTrue(owner.value.owns(newer, in: current))
            XCTAssertEqual(journal.keys.count, 1); XCTAssertEqual(access.sends, 1)
            XCTAssertTrue(coordinator.isLocked(review.command, identity: review.identity))
            XCTAssertEqual(coordinator.state, result == nil ? .acknowledged : .unknown)
            owner.value.finish(newer)
        }
    }
    func testCurrentAckCanReturnOnceAndUiFinishNeverUnlocksOriginalIntent() async throws {
        let access = FormLifecycleAccess(), journal = FormLifecycleJournal()
        let coordinator = ClubGovernanceCoordinator(access: access, journal: journal)
        let review = try await coordinator.prepare(ClubGovernanceFixtures.command(.saveTopicSettings))
        let owner = FormLifecycleBox()
        let ticket = try XCTUnwrap(owner.value.begin(.confirm, in: context(access, coordinator)))
        let task = confirming(review, owner: owner, ticket: ticket, access: access, coordinator: coordinator)
        let callback = await task.value
        XCTAssertTrue(callback); XCTAssertFalse(owner.value.busy); XCTAssertEqual(access.sends, 1)
        XCTAssertEqual(coordinator.state, .acknowledged); XCTAssertEqual(journal.keys.count, 1)
        XCTAssertTrue(coordinator.isLocked(review.command, identity: review.identity))
    }
    func testCancellationAfterDispatchKeepsUnknownAndReservationAcrossReentry() async throws {
        let access = FormLifecycleAccess(), journal = FormLifecycleJournal()
        let coordinator = ClubGovernanceCoordinator(access: access, journal: journal)
        let review = try await coordinator.prepare(ClubGovernanceFixtures.command(.saveTopicSettings))
        let owner = FormLifecycleBox(), gate = FormLifecycleGate(); access.sendGate = gate
        let ticket = try XCTUnwrap(owner.value.begin(.confirm, in: context(access, coordinator)))
        let task = confirming(review, owner: owner, ticket: ticket, access: access, coordinator: coordinator)
        await gate.entered()
        owner.value.retire(); task.cancel(); gate.release()
        let callback = await task.value
        XCTAssertFalse(callback); XCTAssertFalse(owner.value.busy)
        XCTAssertEqual(coordinator.state, .unknown); XCTAssertEqual(access.sends, 1)
        XCTAssertEqual(journal.keys.count, 1)
        let reopened = ClubGovernanceCoordinator(access: access, journal: journal)
        XCTAssertTrue(reopened.isLocked(review.command, identity: review.identity))
    }
    private func confirming(_ review: ClubGovernanceReview, owner: FormLifecycleBox,
                            ticket: ClubGovernanceFormLifecycle.Ticket, access: FormLifecycleAccess,
                            coordinator: ClubGovernanceCoordinator) -> Task<Bool, Never> {
        Task {
            defer { owner.value.finish(ticket) }
            do {
                _ = try await coordinator.confirm(review)
                return owner.value.owns(ticket, in: self.context(access, coordinator)) && !Task.isCancelled
            } catch { return false }
        }
    }
}

@MainActor private final class FormLifecycleBox { var value = ClubGovernanceFormLifecycle() }
@MainActor private final class FormLifecycleGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var hasEntered = false
    private var released = false
    func wait() async {
        hasEntered = true
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func entered() async {
        for _ in 0..<2_000 {
            if hasEntered { return }
            await Task.yield()
        }
        XCTFail("Expected real read/reserve/send to enter the controlled suspension")
        release()
    }
    func release() { released = true; continuation?.resume(); continuation = nil }
}
@MainActor private final class FormLifecycleJournal: ClubGovernanceIntentStoring {
    let isDurable = true
    private(set) var keys: Set<String> = []
    var gate: FormLifecycleGate?
    func contains(_ key: String) throws -> Bool { keys.contains(key) }
    func reserve(_ key: String) async throws {
        keys.insert(key)
        if let current = gate { gate = nil; await current.wait() }
    }
}
@MainActor private final class FormLifecycleAccess: ClubGovernanceAccess {
    var identity: ClubReadIdentity? = .init(accountID: 701, epoch: 1)
    var isConfigured = true
    var storageNamespace = "form-lifecycle-tests"
    var journalRealm = "form-lifecycle-realm"
    var authorizationGeneration: UUID? = UUID()
    let allowsOfflineWrites = false
    var readGate: FormLifecycleGate?
    var sendGate: FormLifecycleGate?
    var sendFailure: ClubGovernanceFailure?
    private(set) var reads = 0
    private(set) var sends = 0
    func canDispatch(_ command: ClubGovernanceCommand) -> Bool { isConfigured && identity != nil }
    func read(_ operation: ClubGovernanceRead, scope: ClubGovernanceScope,
              options: [String: ClubGovernanceValue]) async throws -> ClubGovernanceSnapshot {
        reads += 1
        if let current = readGate { readGate = nil; await current.wait() }
        let fixture = ClubGovernanceFixtureAccess(); fixture.identity = identity
        return try await fixture.read(operation, scope: scope, options: options)
    }
    func send(_ review: ClubGovernanceReview) async throws -> ClubGovernanceValue {
        sends += 1
        if let current = sendGate { sendGate = nil; await current.wait() }
        if let sendFailure { throw sendFailure }
        return ClubGovernanceFixtures.receipt(review.command.operation)
    }
}
