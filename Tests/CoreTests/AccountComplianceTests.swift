import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class ComplianceHTTPFake: HTTPTransport {
    var requests: [URLRequest] = []
    var responses: [String]
    var afterSend: (() -> Void)?
    init(_ responses: [String]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request); afterSend?()
        guard !responses.isEmpty else { throw URLError(.timedOut) }
        return (Data(responses.removeFirst().utf8), 200)
    }
}
@MainActor private final class ComplianceTestContext {
    var session: ComplianceSession? = .init(accountID: 7, epoch: 1, market: "CN", namespace: "test")
    var merchantID: Int? = 41
}
@MainActor final class AccountComplianceTests: XCTestCase {
    private func build(_ fake: ComplianceHTTPFake, context: ComplianceTestContext, enabled: Bool = true) throws -> (AccountComplianceService, ComplianceFileJournal, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("journal.json")
        let journal = ComplianceFileJournal(url: url)
        let service = AccountComplianceService(configuration: try APIConfiguration(baseURL: URL(string: "https://fixture.example")!), transport: fake, journal: journal, current: { context.session }, token: { "synthetic-test-token" }, readsEnabled: enabled, writesEnabled: enabled, legalApproved: { _, _ in enabled }, authoritativeMerchantID: { context.merchantID })
        return (service, journal, url)
    }
    func testMissingLatestIsNormalNoConsent() async throws {
        let context = ComplianceTestContext(); let fake = ComplianceHTTPFake([#"{"code":200}"#]); let (service, _, _) = try build(fake, context: context)
        let result = try await service.latest(.signup, session: context.session!)
        XCTAssertNil(result); XCTAssertEqual(fake.requests.first?.url?.path, "/api/compliance/consents/latest")
    }
    func testExactMerchantWriteReadbackAndNoClientVersion() async throws {
        let context = ComplianceTestContext(); let fake = ComplianceHTTPFake([#"{"code":200}"#, #"{"code":200,"data":{"docType":"merchant_onsite_data_sharing","scene":"merchant_redeem","scopeType":"MERCHANT","scopeId":41,"eventType":"AGREE","docVersion":"server-only"}}"#])
        let (service, journal, _) = try build(fake, context: context); let subject = ComplianceSubject.merchantOnsite(authoritativeMerchantID: 41)
        let record = try await service.consent(subject, event: .agree, requestID: "fixture", session: context.session!)
        XCTAssertTrue(record.matches(subject, event: .agree)); XCTAssertNil(try journal.pending(scope: context.session!.journalScope, operation: subject.operation))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: fake.requests[0].httpBody!) as? [String: Any])
        XCTAssertNil(json["docVersion"]); XCTAssertEqual(json["scopeId"] as? Int, 41)
    }
    func testMismatchLocksAcrossJournalRecreationAndPreventsRetry() async throws {
        let context = ComplianceTestContext(); let fake = ComplianceHTTPFake([#"{"code":200}"#, #"{"code":200,"data":{"docType":"privacy_policy","scene":"roam_location","eventType":"AGREE"}}"#])
        let (service, _, url) = try build(fake, context: context)
        do { _ = try await service.consent(.roamLocation, event: .revoke, requestID: "fixture", session: context.session!); XCTFail() } catch { XCTAssertEqual(error as? ComplianceFailure, .readbackMismatch) }
        XCTAssertNotNil(try ComplianceFileJournal(url: url).pending(scope: context.session!.journalScope, operation: ComplianceSubject.roamLocation.operation))
        do { _ = try await service.consent(.roamLocation, event: .revoke, requestID: "new", session: context.session!); XCTFail() } catch { XCTAssertEqual(error as? ComplianceFailure, .unresolved) }
        XCTAssertEqual(fake.requests.count, 2)
    }
    func testScopeChangeDuringReadbackIsRejected() async throws {
        let context = ComplianceTestContext(); let session = context.session!; let fake = ComplianceHTTPFake([#"{"code":200}"#]); let (service, _, _) = try build(fake, context: context)
        fake.afterSend = { context.merchantID = 42 }
        do { _ = try await service.consent(.merchantOnsite(authoritativeMerchantID: 41), event: .agree, requestID: "fixture", session: session); XCTFail() } catch { XCTAssertEqual(error as? ComplianceFailure, .staleSession) }
        XCTAssertEqual(fake.requests.count, 1)
    }
    func testSessionChangeDiscardsResponseAndRetainsLock() async throws {
        let context = ComplianceTestContext(); let session = context.session!; let fake = ComplianceHTTPFake([#"{"code":200}"#]); let (service, journal, _) = try build(fake, context: context)
        fake.afterSend = { context.session = .init(accountID: 8, epoch: 2, market: "CN", namespace: "test") }
        do { _ = try await service.consent(.roamLocation, event: .revoke, requestID: "fixture", session: session); XCTFail() } catch { XCTAssertEqual(error as? ComplianceFailure, .staleSession) }
        XCTAssertNotNil(try journal.pending(scope: session.journalScope, operation: ComplianceSubject.roamLocation.operation))
    }
    func testDefaultsSendNothing() async throws {
        let context = ComplianceTestContext(); let fake = ComplianceHTTPFake([]); let (service, _, _) = try build(fake, context: context, enabled: false)
        do { _ = try await service.status(session: context.session!); XCTFail() } catch { XCTAssertEqual(error as? ComplianceFailure, .unavailable) }
        XCTAssertTrue(fake.requests.isEmpty)
    }
    func testDeregisterUsesMultipartAndSameEpochCannotCancel() async throws {
        let context = ComplianceTestContext(); let fake = ComplianceHTTPFake([#"{"code":200,"data":{"status":"WAITING","executeAfter":"server-date","blockers":[]}}"#]); let (service, _, _) = try build(fake, context: context)
        let result = try await service.apply(smscode: "123456", requestID: "fixture", session: context.session!)
        XCTAssertTrue(result.pending); XCTAssertTrue(fake.requests[0].value(forHTTPHeaderField: "Content-Type")!.contains("multipart/form-data"))
        let body = String(data: fake.requests[0].httpBody!, encoding: .utf8)!
        XCTAssertTrue(body.contains("name=\"smscode\"")); XCTAssertTrue(body.contains("name=\"requestId\""))
        do { _ = try await service.cancel(session: context.session!); XCTFail() } catch { XCTAssertEqual(error as? ComplianceFailure, .staleSession) }
        XCTAssertEqual(fake.requests.count, 1)
    }
    func testBlockedAndUnknownNeverEligible() throws {
        let blocked = try JSONDecoder().decode(ComplianceDeregistration.self, from: Data(#"{"status":"BLOCKED","blockers":["server reason"]}"#.utf8))
        XCTAssertTrue(blocked.blocked); XCTAssertFalse(blocked.eligible); XCTAssertEqual(blocked.blockers, ["server reason"])
        let unknown = try JSONDecoder().decode(ComplianceDeregistration.self, from: Data("{}".utf8))
        XCTAssertFalse(unknown.eligible); XCTAssertFalse(unknown.pending); XCTAssertEqual(unknown.status, "UNKNOWN")
    }
    func testMarketingWrongOwnerNeverConfirms() async throws {
        let context = ComplianceTestContext(); let row = try JSONDecoder().decode(ComplianceMarketingConsent.self, from: Data(#"{"merchantRowId":41,"merchantOwnerMemberId":7,"inAppOptedIn":false,"couponOptedIn":false}"#.utf8))
        let fake = ComplianceHTTPFake([#"{"code":200}"#, #"{"code":200,"data":[{"merchantRowId":41,"merchantOwnerMemberId":8,"inAppOptedIn":true,"couponOptedIn":false}]}"#]); let (service, _, _) = try build(fake, context: context)
        do { _ = try await service.setMarketing(row, channel: .inApp, optedIn: true, requestID: "fixture", session: context.session!); XCTFail() } catch { XCTAssertEqual(error as? ComplianceFailure, .readbackMismatch) }
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: fake.requests[0].httpBody!) as? [String: Any])
        XCTAssertEqual(body["merchantOwnerMemberId"] as? Int, 7); XCTAssertEqual(body["channel"] as? String, "IN_APP")
    }
    func testMarketingConsentDecodesMerchantLogoAndDefaultsBlank() throws {
        let withLogo = try JSONDecoder().decode(ComplianceMarketingConsent.self, from: Data(#"{"merchantRowId":1,"merchantOwnerMemberId":2,"merchantName":"店","merchantLogo":" https://img.example/a.png ","inAppOptedIn":true,"couponOptedIn":false}"#.utf8))
        XCTAssertEqual(withLogo.merchantLogo, "https://img.example/a.png")
        XCTAssertEqual(withLogo.merchantName, "店")
        let missing = try JSONDecoder().decode(ComplianceMarketingConsent.self, from: Data(#"{"merchantRowId":41,"merchantOwnerMemberId":7,"inAppOptedIn":false,"couponOptedIn":false}"#.utf8))
        XCTAssertEqual(missing.merchantLogo, "")
    }
}

@MainActor private final class ComplianceAuthFake: AuthChannelServing {
    var smsCalls = 0
    var lastPhone: String?
    var failSMS = false
    func sendSMSCode(phone: String) async throws { smsCalls += 1; lastPhone = phone; if failSMS { throw ComplianceFailure.rejected("SMS failed") } }
    func loginWithPhone(phone: String, code: String) async throws -> LoginResult { throw ComplianceFailure.unavailable }
    func loginWithApple(identityToken: String) async throws -> LoginResult { throw ComplianceFailure.unavailable }
    func currentAccount(token: String) async throws -> Account { throw ComplianceFailure.unavailable }
}
@MainActor private final class ComplianceEffectsFake: ComplianceRoamEffects {
    var calls: [String] = []
    var failStop = false
    var failClear = false
    func stopTracking() async throws { calls.append("stop"); if failStop { throw ComplianceFailure.unavailable } }
    func clearMapPrivacy() async throws { calls.append("clear"); if failClear { throw ComplianceFailure.unavailable } }
    func invalidateMapPrivacyCaches() { calls.append("invalidate") }
}
extension AccountComplianceTests {
    func testConsentRejectionDoesNotReachSMS() async throws {
        let context = ComplianceTestContext(); let fake = ComplianceHTTPFake([#"{"code":200,"data":{"status":"NORMAL"}}"#, #"{"code":200,"data":{"status":"ELIGIBLE"}}"#, #"{"code":409,"msg":"consent failed"}"#]); let (service, _, _) = try build(fake, context: context)
        let auth = ComplianceAuthFake(); let coordinator = AccountComplianceCoordinator(service: service, auth: auth, effects: ComplianceEffectsFake(), current: { context.session }, invalidateSession: { _ in XCTFail() })
        await coordinator.load(); await coordinator.precheckAndAgree(documentRead: true, explicitAgreement: true)
        await coordinator.sendSMS(phone: "13800000000", explicitlyRequested: true)
        XCTAssertEqual(auth.smsCalls, 0); XCTAssertNotEqual(coordinator.state.step, .verify)
    }
    func testSMSFailureAndAcceptedApplyInvalidateOriginalSession() async throws {
        let context = ComplianceTestContext(); let original = context.session!
        let fake = ComplianceHTTPFake([#"{"code":200,"data":{"status":"NORMAL"}}"#, #"{"code":200,"data":{"status":"ELIGIBLE"}}"#, #"{"code":200}"#, #"{"code":200,"data":{"docType":"account_cancellation_notice","scene":"account_cancel","eventType":"AGREE"}}"#, #"{"code":200,"data":{"status":"WAITING","executeAfter":"server-date"}}"#]); let (service, _, _) = try build(fake, context: context)
        let auth = ComplianceAuthFake(); var invalidated: ComplianceSession?
        let coordinator = AccountComplianceCoordinator(service: service, auth: auth, effects: ComplianceEffectsFake(), current: { context.session }, invalidateSession: { invalidated = $0; context.session = nil })
        await coordinator.load(); await coordinator.precheckAndAgree(documentRead: true, explicitAgreement: true)
        auth.failSMS = true; await coordinator.sendSMS(phone: "13800000000", explicitlyRequested: true)
        XCTAssertFalse(coordinator.state.smsSent)
        coordinator.prepareReview(code: "123456"); XCTAssertEqual(coordinator.state.step, .verify)
        auth.failSMS = false; await coordinator.sendSMS(phone: "13800000000", explicitlyRequested: true)
        coordinator.prepareReview(code: "123456"); await coordinator.apply(explicitlyConfirmed: true)
        XCTAssertEqual(invalidated, original); XCTAssertEqual(coordinator.state.step, .freshLogin)
    }
    func testNoticePrecheckDoesNotRecordConsentAndBoundPhoneSMSUsesMemberInfo() async throws {
        let context = ComplianceTestContext()
        let fake = ComplianceHTTPFake([
            #"{"code":200,"data":{"status":"NORMAL"}}"#,
            #"{"code":200,"data":{"status":"ELIGIBLE","verificationMethod":"SMS"}}"#,
            #"{"code":200,"data":{"phone":"13800138000","role":"player"}}"#
        ])
        let (service, _, _) = try build(fake, context: context)
        let auth = ComplianceAuthFake()
        let coordinator = AccountComplianceCoordinator(service: service, auth: auth, effects: ComplianceEffectsFake(), current: { context.session }, invalidateSession: { _ in XCTFail() })
        await coordinator.load()
        await coordinator.precheckAndAgree(documentRead: true, explicitAgreement: true, recordConsent: false)
        XCTAssertEqual(coordinator.state.step, .verify)
        XCTAssertEqual(fake.requests.count, 2)
        let sent = Date(timeIntervalSince1970: 1_800_000_000)
        await coordinator.sendBoundPhoneSMS(explicitlyRequested: true, now: sent)
        XCTAssertEqual(auth.smsCalls, 1)
        XCTAssertEqual(auth.lastPhone, "13800138000")
        XCTAssertEqual(coordinator.state.smsNotice, "验证码已发送至尾号 8000 的手机号")
        XCTAssertTrue(coordinator.state.smsSent)
        let info = try XCTUnwrap(fake.requests.last)
        XCTAssertEqual(info.httpMethod, "POST")
        XCTAssertTrue(info.url?.path.hasSuffix("api/user/info") == true)
        let form = String(data: try XCTUnwrap(info.httpBody), encoding: .utf8)
        XCTAssertTrue(form?.contains("name=\"member_id\"\r\n\r\n7") == true)
        await coordinator.sendBoundPhoneSMS(explicitlyRequested: true, now: sent.addingTimeInterval(30))
        XCTAssertEqual(auth.smsCalls, 1)
        XCTAssertEqual(fake.requests.count, 3)
    }
    func testBoundPhoneMissingDoesNotSendSMS() async throws {
        let context = ComplianceTestContext()
        let fake = ComplianceHTTPFake([
            #"{"code":200,"data":{"status":"NORMAL"}}"#,
            #"{"code":200,"data":{"status":"ELIGIBLE","verificationMethod":"SMS"}}"#,
            #"{"code":200,"data":{"phone":"  ","role":"player"}}"#
        ])
        let (service, _, _) = try build(fake, context: context)
        let auth = ComplianceAuthFake()
        let coordinator = AccountComplianceCoordinator(service: service, auth: auth, effects: ComplianceEffectsFake(), current: { context.session }, invalidateSession: { _ in })
        await coordinator.load()
        await coordinator.precheckAndAgree(documentRead: true, explicitAgreement: true, recordConsent: false)
        await coordinator.sendBoundPhoneSMS(explicitlyRequested: true)
        XCTAssertEqual(auth.smsCalls, 0)
        XCTAssertEqual(coordinator.state.error, DeregistrationBoundPhone.missingMessage)
        XCTAssertFalse(coordinator.state.smsSent)
    }
    func testDeregistrationSMSPostsTheServerPhone() async throws {
        let transport = ComplianceHTTPFake([#"{"code":200}"#])
        let auth = AuthChannelService(configuration: try APIConfiguration(baseURL: URL(string: "https://fixture.example")!), transport: transport)
        try await auth.sendBoundDeregistrationCode(phone: "138****0000")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.hasSuffix("api/sms/send") == true)
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)
        XCTAssertTrue(body?.contains("name=\"phone\"\r\n\r\n138****0000") == true)
    }
    func testRoamPartialFailureResumesWithoutSecondWrite() async throws {
        let context = ComplianceTestContext(); let fake = ComplianceHTTPFake([#"{"code":200}"#, #"{"code":200}"#, #"{"code":200,"data":{"docType":"privacy_policy","scene":"roam_location","eventType":"REVOKE"}}"#]); let (service, _, _) = try build(fake, context: context)
        let effects = ComplianceEffectsFake(); effects.failStop = true
        let coordinator = AccountComplianceCoordinator(service: service, auth: ComplianceAuthFake(), effects: effects, current: { context.session }, invalidateSession: { _ in })
        await coordinator.revokeRoam(explicitlyConfirmed: true)
        XCTAssertEqual(coordinator.state.roamCleanup, .serverConfirmed); XCTAssertEqual(effects.calls, ["stop"])
        effects.failStop = false; effects.failClear = true; await coordinator.revokeRoam(explicitlyConfirmed: true)
        XCTAssertEqual(coordinator.state.roamCleanup, .trackingStopped); XCTAssertEqual(effects.calls, ["stop", "stop", "clear", "invalidate"])
        effects.failClear = false; await coordinator.revokeRoam(explicitlyConfirmed: true)
        XCTAssertEqual(coordinator.state.roamCleanup, .complete); XCTAssertEqual(fake.requests.count, 3)
    }
    func testFreshLoginAllowsCancelWithStatusReadback() async throws {
        let context = ComplianceTestContext(); let fake = ComplianceHTTPFake([#"{"code":200,"data":{"status":"WAITING","executeAfter":"server-date"}}"#, #"{"code":200,"data":{"status":"WAITING","executeAfter":"server-date"}}"#, #"{"code":200,"data":{"status":"NORMAL"}}"#, #"{"code":200,"data":{"status":"NORMAL"}}"#]); let (service, journal, _) = try build(fake, context: context)
        _ = try await service.apply(smscode: "123456", requestID: "fixture", session: context.session!)
        context.session = .init(accountID: 7, epoch: 2, market: "CN", namespace: "test")
        let result = try await service.cancel(session: context.session!)
        XCTAssertEqual(result.status, "NORMAL"); XCTAssertNil(try journal.pending(scope: context.session!.journalScope, operation: "deregister"))
        XCTAssertEqual(fake.requests.map { $0.url!.path }, ["/api/user/deregister/apply", "/api/user/deregister/status", "/api/user/deregister/cancel", "/api/user/deregister/status"])
    }

#if DEBUG
    func testDeregisterIndexPageReadsExistingStatusAndKeepsUnknownAsEmDash() async throws {
        let context = ComplianceTestContext()
        let fake = ComplianceHTTPFake([#"{"code":200,"data":"# + DeregisterIndexFixtureData.unknownStatus + "}"])
        let (service, _, _) = try build(fake, context: context)
        let coordinator = AccountComplianceCoordinator(service: service, auth: ComplianceAuthFake(), effects: ComplianceEffectsFake(), current: { context.session }, invalidateSession: { _ in XCTFail() })
        XCTAssertEqual(coordinator.deregisterIndexPage.phase, .empty)
        XCTAssertEqual(coordinator.deregisterIndexPage.statusText, "—")
        await coordinator.load()
        let page = coordinator.deregisterIndexPage
        XCTAssertEqual(page.phase, .unknown)
        XCTAssertEqual(page.statusText, "—")
        XCTAssertEqual(page.unknownKey, "compliance.unknown")
        XCTAssertEqual(page.impactLines.first { $0.key == "POINTS" }?.valueText, "—")
        XCTAssertEqual(page.impactLines.first { $0.key == "ACTIVE_ORDERS" }?.valueText, "0")
        XCTAssertNotEqual(page.impactLines.first { $0.key == "POINTS" }?.valueText, "0")
        XCTAssertEqual(fake.requests.map { $0.url?.path }, ["/api/user/deregister/status"])
        XCTAssertFalse(page.offersResultRoute)
        XCTAssertFalse(fake.requests.contains { $0.url?.path.contains("result") == true })
    }
#endif
}

/// Echoes the last posted `requestId` on the readback, like the backend's latest-row read.
private final class RoamConsentFake: HTTPTransport {
    var requests: [URLRequest] = []
    var latest: [String: Any]?
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if request.url?.path == "/api/compliance/consents/latest" {
            let body: [String: Any] = latest.map { ["code": 200, "data": $0] } ?? ["code": 200]
            return (try JSONSerialization.data(withJSONObject: body), 200)
        }
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        latest = ["docType": "privacy_policy", "scene": "roam_location", "eventType": fields["eventType"] as Any,
                  "docVersion": "v2.1", "requestId": fields["requestId"] as Any]
        return (Data(#"{"code":200}"#.utf8), 200)
    }
    var posted: [[String: Any]] {
        requests.filter { $0.url?.path == "/api/compliance/consents" }
            .compactMap { $0.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } }
    }
}
extension AccountComplianceTests {
    /// E2E-20261112 F3: "Agree and go" records `roam_location` AGREE with the backend's `expectedRequestId` contract.
    func testRoamAgreeSendsExpectedRequestIdAndIsIdempotent() async throws {
        let context = ComplianceTestContext(); let fake = RoamConsentFake()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("journal.json")
        let service = AccountComplianceService(configuration: try APIConfiguration(baseURL: URL(string: "https://fixture.example")!), transport: fake,
            journal: ComplianceFileJournal(url: url), current: { context.session }, token: { "synthetic-test-token" },
            readsEnabled: true, writesEnabled: true, legalApproved: { subject, _ in subject == .roamLocation }, authoritativeMerchantID: { nil })
        let coordinator = AccountComplianceCoordinator(service: service, auth: ComplianceAuthFake(), effects: ComplianceEffectsFake(),
            current: { context.session }, invalidateSession: { _ in })
        await coordinator.loadRoamConsent()
        XCTAssertEqual(coordinator.state.roamConsent, .notAgreed)
        try await coordinator.ensureRoamLocationAgree()
        XCTAssertEqual(fake.posted.count, 1)
        let first = try XCTUnwrap(fake.posted.first)
        XCTAssertEqual(first["scene"] as? String, "roam_location"); XCTAssertEqual(first["eventType"] as? String, "AGREE")
        XCTAssertEqual(first["expectedRequestId"] as? String, "", "no prior row sends an empty expectedRequestId")
        XCTAssertEqual(coordinator.state.roamConsent, .agreed)
        // A current AGREE on record is not posted again on the next start.
        try await coordinator.ensureRoamLocationAgree()
        XCTAssertEqual(fake.posted.count, 1)
        // After a withdraw, settings Agree chains expectedRequestId to the latest (revoke) row.
        await coordinator.revokeRoam(explicitlyConfirmed: true)
        XCTAssertEqual(coordinator.state.roamConsent, .notAgreed)
        let revokeID = try XCTUnwrap(fake.latest?["requestId"] as? String)
        await coordinator.agreeRoam(explicitlyConfirmed: true)
        XCTAssertEqual(fake.posted.count, 3)
        XCTAssertEqual(fake.posted.last?["expectedRequestId"] as? String, revokeID)
        XCTAssertEqual(coordinator.state.roamConsent, .agreed); XCTAssertEqual(coordinator.state.roamCleanup, .idle)
    }
}
