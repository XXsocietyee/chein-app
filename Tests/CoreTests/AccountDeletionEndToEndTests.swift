import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Full account-deletion path on a fixture host: status, precheck, consent, apply,
/// derived receipt, and recovery after a lost apply response. No live host is contacted.
@MainActor final class AccountDeletionEndToEndTests: XCTestCase {
    private let base = URL(string: "https://fixture.example/native")!

    func testDerivedReceiptJourneyRecordsTheHandoffAndNeverCallsTheMissingResultRoute() async throws {
        let flow = try Flow(base: base)
        defer { flow.cleanup() }
        await flow.reachReview()
        XCTAssertEqual(flow.coordinator.state.step, .review)
        await flow.coordinator.apply(explicitlyConfirmed: true)
        XCTAssertEqual(flow.coordinator.state.step, .freshLogin)
        XCTAssertEqual(flow.coordinator.state.status?.status, "PENDING")
        XCTAssertEqual(flow.paths, ["status", "precheck", "consents", "status", "apply", "status", "status"])
        XCTAssertFalse(flow.paths.contains("result"))
        XCTAssertEqual(flow.paths.filter { $0 == "apply" }.count, 1)
        let intent = try XCTUnwrap(try flow.journal.pending(scope: flow.session.journalScope, operation: "deregister"))
        XCTAssertTrue(try flow.journal.deregistrationApplyWasDispatched(scope: flow.session.journalScope, requestID: intent.requestID))
        let reopened = ComplianceFileJournal(url: flow.journalURL)
        XCTAssertTrue(try reopened.deregistrationApplyWasDispatched(scope: flow.session.journalScope, requestID: intent.requestID))
        let calls = flow.wire.requests.count
        await flow.coordinator.apply(explicitlyConfirmed: true)
        XCTAssertEqual(flow.wire.requests.count, calls, "a second apply tap must not post again")
    }

    func testLostApplyRecoversTheReceiptOnANewClientWithoutPostingAgain() async throws {
        let flow = try Flow(base: base)
        defer { flow.cleanup() }
        flow.loseApplyResponse = true
        await flow.reachReview()
        await flow.coordinator.apply(explicitlyConfirmed: true)
        XCTAssertEqual(flow.coordinator.state.step, .unknown)
        XCTAssertEqual(flow.paths.filter { $0 == "apply" }.count, 1)
        let intent = try XCTUnwrap(try flow.journal.pending(scope: flow.session.journalScope, operation: "deregister"))
        XCTAssertTrue(try flow.journal.deregistrationApplyWasDispatched(scope: flow.session.journalScope, requestID: intent.requestID))

        let recovered = try flow.reopen(epoch: 3)
        await recovered.coordinator.load()
        XCTAssertEqual(recovered.coordinator.state.step, .pending)
        XCTAssertEqual(recovered.coordinator.state.originalApplication?.outcome, "ACCEPTED")
        XCTAssertEqual(recovered.coordinator.state.originalApplication?.derivedFromStatus, true)
        XCTAssertEqual(recovered.coordinator.state.originalApplication?.requestId, intent.requestID)
        XCTAssertEqual(recovered.coordinator.state.originalApplicationRequestID, intent.requestID)
        XCTAssertFalse(recovered.paths.contains("result"))
        XCTAssertFalse(recovered.paths.contains("apply"), "recovery reads status and must not post apply again")
        XCTAssertEqual(flow.paths.filter { $0 == "apply" }.count, 1)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(recovered.coordinator.coolingOffHasPassed(now: now))
        XCTAssertFalse(recovered.coordinator.coolingOffHasPassed(now: Date(timeIntervalSince1970: 0)))
        let again = recovered.wire.requests.count
        await recovered.coordinator.apply(explicitlyConfirmed: true)
        XCTAssertEqual(recovered.wire.requests.count, again)
    }

    func testFailedStatusAfterHandoffStaysUnknownAndDoesNotResend() async throws {
        let flow = try Flow(base: base)
        defer { flow.cleanup() }
        flow.terminalStatus = "FAILED"
        await flow.reachReview()
        await flow.coordinator.apply(explicitlyConfirmed: true)
        XCTAssertEqual(flow.coordinator.state.step, .unknown)
        XCTAssertEqual(flow.coordinator.state.error, "compliance.unknown")
        XCTAssertEqual(flow.paths.filter { $0 == "apply" }.count, 1)
        let recovered = try flow.reopen(epoch: 4)
        await recovered.coordinator.load()
        XCTAssertEqual(recovered.coordinator.state.step, .unknown)
        XCTAssertNotEqual(recovered.coordinator.state.originalApplication?.outcome, "ACCEPTED")
        XCTAssertFalse(recovered.coordinator.state.originalApplication?.settled ?? false)
        XCTAssertFalse(recovered.paths.contains("apply"))
        XCTAssertEqual(flow.paths.filter { $0 == "apply" }.count, 1)
    }

    func testEligiblePrecheckWithBlockersNeverConsentsOrApplies() async throws {
        let flow = try Flow(base: base)
        defer { flow.cleanup() }
        flow.precheckBlockers = ["open order"]
        await flow.coordinator.load()
        await flow.coordinator.precheckAndAgree(documentRead: true, explicitAgreement: true, expectedConsentVersion: "synthetic-v1")
        XCTAssertEqual(flow.coordinator.state.step, .unknown)
        XCTAssertEqual(flow.paths, ["status", "precheck"])
        await flow.coordinator.sendSMS(phone: "13800000000", explicitlyRequested: true)
        await flow.coordinator.apply(explicitlyConfirmed: true)
        XCTAssertEqual(flow.auth.sms, 0)
        XCTAssertEqual(flow.paths, ["status", "precheck"])
    }

    func testPendingStatusBeforeApplyIsNotThisRequestsReceipt() async throws {
        let flow = try Flow(base: base)
        defer { flow.cleanup() }
        flow.initialStatus = "PENDING"
        let requestID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        let session = flow.session
        try flow.journal.begin(.init(scope: session.journalScope, operation: "deregister", requestID: requestID, epoch: session.epoch,
            deregistrationRealm: flow.base.absoluteString, deregistrationOriginalVersion: 1,
            deregistrationImpactRevision: String(repeating: "a", count: 64)))
        let receipt = try await flow.service.recoverOriginalApplication(session: session)
        XCTAssertEqual(receipt?.outcome, "UNKNOWN")
        XCTAssertEqual(receipt?.derivedFromStatus, true)
        XCTAssertFalse(receipt?.settled ?? true)
        XCTAssertFalse(try flow.journal.deregistrationApplyWasDispatched(scope: session.journalScope, requestID: requestID))
        XCTAssertEqual(flow.paths, ["status"])
    }
}

@MainActor private final class DeletionEndToEndWire: HTTPTransport {
    var requests: [URLRequest] = []
    var reply: (URLRequest) throws -> (Data, Int) = { _ in (Data(#"{"code":200,"data":{"status":"NORMAL"}}"#.utf8), 200) }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return try reply(request)
    }
}

@MainActor private final class DeletionEndToEndAuth: AuthChannelServing {
    var sms = 0
    func sendSMSCode(phone: String) async throws { sms += 1 }
    func loginWithPhone(phone: String, code: String) async throws -> LoginResult { throw ComplianceFailure.unavailable }
    func loginWithApple(identityToken: String) async throws -> LoginResult { throw ComplianceFailure.unavailable }
    func currentAccount(token: String) async throws -> Account { throw ComplianceFailure.unavailable }
}

@MainActor private final class DeletionEndToEndEffects: ComplianceRoamEffects {
    func stopTracking() async throws {}
    func clearMapPrivacy() async throws {}
    func invalidateMapPrivacyCaches() {}
}

@MainActor private final class Flow {
    let base: URL
    let wire = DeletionEndToEndWire()
    let auth = DeletionEndToEndAuth()
    let journalURL: URL
    let directory: URL
    var journal: ComplianceFileJournal
    var session: ComplianceSession
    var context: RuntimeDependencyContext
    var client: AccountDeregistrationOriginalClient
    var loseApplyResponse = false
    var terminalStatus = "PENDING"
    var initialStatus = "NORMAL"
    var precheckBlockers: [String] = []
    private var applied = false
    lazy var service: AccountComplianceService = AccountComplianceService(
        configuration: try! APIConfiguration(baseURL: base), transport: wire, journal: journal,
        current: { [unowned self] in self.session }, token: { "synthetic-token" },
        deregistrationOriginal: { [unowned self] in self.client })
    lazy var coordinator: AccountComplianceCoordinator = AccountComplianceCoordinator(
        service: service, auth: auth, effects: DeletionEndToEndEffects(),
        current: { [unowned self] in self.session }, invalidateSession: { _ in })

    var paths: [String] { wire.requests.map { $0.url!.lastPathComponent } }

    init(base: URL) throws {
        self.base = base
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        journalURL = directory.appendingPathComponent("operations.json")
        journal = ComplianceFileJournal(url: journalURL)
        session = .init(accountID: 7, epoch: 2, market: "CN", namespace: "deletion-e2e")
        context = RuntimeDependencyContext(market: .china, baseURL: base, role: "player",
            session: try .init(accountID: 7, epoch: 2, namespace: "deletion-e2e", token: "synthetic-token", role: "player"))
        let approval = try AccountDeregistrationOriginalApproval(endpoint: .init(baseURL: base, namespace: "deletion-e2e", accountID: 7,
            paths: AccountDeregistrationOriginalClient.readPaths.union(AccountDeregistrationOriginalClient.writePaths)),
            writes: true, legalApproved: true, issuanceID: UUID())
        client = AccountDeregistrationOriginalClient(context: context, approval: approval, transport: wire,
            current: { self.context }, stillApproved: { true }, onUnauthorized: {})
        client.receiptSource = .derivedFromStatus
        installReply()
    }

    func cleanup() { try? FileManager.default.removeItem(at: directory) }

    func reachReview() async {
        await coordinator.load()
        await coordinator.precheckAndAgree(documentRead: true, explicitAgreement: true, expectedConsentVersion: "synthetic-v1")
        await coordinator.sendSMS(phone: "13800000000", explicitlyRequested: true)
        coordinator.prepareReview(code: "123456")
    }

    /// A new client and coordinator over the same journal. `sent` starts empty, as after a process restart.
    func reopen(epoch: UInt64) throws -> Flow {
        let next = try Flow(base: base, directory: directory, journalURL: journalURL, epoch: epoch)
        next.loseApplyResponse = false
        next.terminalStatus = terminalStatus
        next.initialStatus = terminalStatus
        next.applied = true
        next.installReply()
        return next
    }

    private init(base: URL, directory: URL, journalURL: URL, epoch: UInt64) throws {
        self.base = base
        self.directory = directory
        self.journalURL = journalURL
        journal = ComplianceFileJournal(url: journalURL)
        session = .init(accountID: 7, epoch: epoch, market: "CN", namespace: "deletion-e2e")
        context = RuntimeDependencyContext(market: .china, baseURL: base, role: "player",
            session: try .init(accountID: 7, epoch: epoch, namespace: "deletion-e2e", token: "synthetic-token", role: "player"))
        let approval = try AccountDeregistrationOriginalApproval(endpoint: .init(baseURL: base, namespace: "deletion-e2e", accountID: 7,
            paths: AccountDeregistrationOriginalClient.readPaths.union(AccountDeregistrationOriginalClient.writePaths)),
            writes: true, legalApproved: true, issuanceID: UUID())
        client = AccountDeregistrationOriginalClient(context: context, approval: approval, transport: wire,
            current: { self.context }, stillApproved: { true }, onUnauthorized: {})
        client.receiptSource = .derivedFromStatus
    }

    private func installReply() {
        wire.reply = { [unowned self] request in
            var data: [String: Any]
            switch request.url!.lastPathComponent {
            case "status":
                if self.applied {
                    data = ["status": self.terminalStatus, "executeAfter": "2020-01-01T00:00:00Z"]
                } else {
                    data = ["status": self.initialStatus]
                }
            case "precheck":
                data = ["status": "ELIGIBLE", "verificationMethod": "SMS", "blockers": self.precheckBlockers, "impact": Self.impact]
            case "consents":
                let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
                data = ["requestId": body["requestId"]!, "docType": "account_cancellation_notice", "scene": "account_cancel",
                        "eventType": "AGREE", "docVersion": "synthetic-v1"]
            case "apply":
                self.applied = true
                if self.loseApplyResponse { throw URLError(.timedOut) }
                data = [:]
            default:
                XCTFail("Unexpected path \(request.url!.lastPathComponent)")
                throw ComplianceFailure.unavailable
            }
            return (try JSONSerialization.data(withJSONObject: ["code": 200, "data": data]), 200)
        }
    }

    private static var impact: [String: Any] {
        ["schemaVersion": 1, "actorId": 7, "revision": String(repeating: "a", count: 64),
         "items": [["key": "BALANCE", "value": "0", "source": "synthetic-ledger", "effect": "synthetic-effect"]],
         "unknownCoverage": []]
    }
}
