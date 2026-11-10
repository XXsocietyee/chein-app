import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class PrivacyPageMemoryStorage: UsageConsentStorage {
    var values: [String: Data] = [:]
    func data(forKey key: String) -> Data? { values[key] }
    func set(_ value: Data?, forKey key: String) { values[key] = value }
}

private final class PrivacyPageHTTPFake: HTTPTransport {
    var requests: [URLRequest] = []
    var bodies: [String]
    var status = 200
    init(_ bodies: [String], status: Int = 200) { self.bodies = bodies; self.status = status }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let body = bodies.isEmpty ? #"{"code":500}"# : bodies.removeFirst()
        return (Data(body.utf8), status)
    }
}

@MainActor private final class PrivacyPageSessionBox {
    var session: ComplianceSession? = .init(accountID: 7, epoch: 1, market: "CN", namespace: "privacy-page")
}

@MainActor private final class PrivacyPageRecordingReader: PrivacyProtectionLatestConsentReading {
    weak var model: PrivacyProtectionPageModel?
    var phaseAtCall: PrivacyProtectionPagePhase?
    func latestRoamConsent(session: ComplianceSession) async throws -> ComplianceConsent? {
        phaseAtCall = model?.phase
        return nil
    }
}

@MainActor private final class PrivacyPageNestedReader: PrivacyProtectionLatestConsentReading {
    weak var model: PrivacyProtectionPageModel?
    var calls = 0
    var agreed: ComplianceConsent?
    var phaseAtFirstCall: PrivacyProtectionPagePhase?
    func latestRoamConsent(session: ComplianceSession) async throws -> ComplianceConsent? {
        calls += 1
        if calls == 1 {
            phaseAtFirstCall = model?.phase
            await model?.reload()
            return agreed
        }
        return nil
    }
}

@MainActor final class PrivacyProtectionPageModelTests: XCTestCase {
    private func policy() -> UsageConsentPolicy { UsageConsentPolicy(storage: PrivacyPageMemoryStorage()) }

    private func consent(_ json: String) throws -> ComplianceConsent {
        try JSONDecoder().decode(ComplianceConsent.self, from: Data(json.utf8))
    }

    private func service(_ fake: PrivacyPageHTTPFake, box: PrivacyPageSessionBox, readsEnabled: Bool) throws -> AccountComplianceService {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("journal.json")
        return AccountComplianceService(
            configuration: try APIConfiguration(baseURL: URL(string: "https://fixture.example")!),
            transport: fake, journal: ComplianceFileJournal(url: url), current: { box.session },
            token: { "synthetic-test-token" }, readsEnabled: readsEnabled, writesEnabled: false)
    }

    func testLoadingIsVisibleBeforeTheLatestConsentReturns() async throws {
        let box = PrivacyPageSessionBox()
        let reader = PrivacyPageRecordingReader()
        let model = PrivacyProtectionPageModel(policy: policy(), consent: reader, session: { box.session })
        reader.model = model
        await model.reload()
        XCTAssertEqual(reader.phaseAtCall, .loading)
        XCTAssertEqual(model.phase, .empty)
        XCTAssertEqual(model.phase.accessibilityIdentifier, PrivacyProtectionPageAccessibility.empty)
        XCTAssertFalse(model.deviceAgreementGranted)
    }

    func testMissingLatestAndNoDeviceGrantIsEmptyAndDoesNotRequestUsageRecords() async throws {
        let box = PrivacyPageSessionBox()
        let fake = PrivacyPageHTTPFake([#"{"code":200}"#])
        let model = PrivacyProtectionPageModel(policy: policy(), consent: try service(fake, box: box, readsEnabled: true), session: { box.session })
        await model.reload()
        XCTAssertEqual(model.phase, .empty)
        XCTAssertFalse(model.serverConsentHidden)
        XCTAssertEqual(fake.requests.count, 1)
        XCTAssertEqual(fake.requests[0].url?.host, "fixture.example")
        XCTAssertEqual(fake.requests[0].url?.path, "/api/compliance/consents/latest")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(fake.requests[0].httpBody)) as? [String: Any])
        XCTAssertEqual(body["docType"] as? String, "privacy_policy")
        XCTAssertEqual(body["scene"] as? String, "roam_location")
        XCTAssertFalse(fake.requests.contains { $0.url?.path.contains("usage-records") == true })
    }

    func testDeviceGrantWithoutAServerRowIsReady() async throws {
        let stored = policy()
        try stored.agree(agreementChecked: true)
        let model = PrivacyProtectionPageModel(policy: stored)
        await model.reload()
        guard case .ready(let snapshot) = model.phase else { return XCTFail("expected ready") }
        XCTAssertTrue(snapshot.deviceAgreementGranted)
        XCTAssertNil(snapshot.roamLocationEvent)
        XCTAssertTrue(snapshot.serverConsentHidden)
        XCTAssertTrue(snapshot.usageRecordHistoryHidden)
        XCTAssertTrue(snapshot.showsDeviceWithdrawal)
        XCTAssertEqual(model.phase.accessibilityIdentifier, PrivacyProtectionPageAccessibility.ready)
    }

    func testAgreeAndRevokeStayReady() async throws {
        let box = PrivacyPageSessionBox()
        let fake = PrivacyPageHTTPFake([
            #"{"code":200,"data":{"docType":"privacy_policy","scene":"roam_location","eventType":"AGREE","docVersion":"v2.1"}}"#,
            #"{"code":200,"data":{"docType":"privacy_policy","scene":"roam_location","eventType":"REVOKE","docVersion":"v2.1"}}"#
        ])
        let model = PrivacyProtectionPageModel(policy: policy(), consent: try service(fake, box: box, readsEnabled: true), session: { box.session })
        await model.reload()
        guard case .ready(let agreed) = model.phase else { return XCTFail("expected agree") }
        XCTAssertEqual(agreed.roamLocationEvent, "AGREE")
        XCTAssertFalse(agreed.serverConsentHidden)
        await model.reload()
        guard case .ready(let revoked) = model.phase else { return XCTFail("expected revoke") }
        XCTAssertEqual(revoked.roamLocationEvent, "REVOKE")
        XCTAssertFalse(revoked.deviceAgreementGranted)
    }

    func testUnknownEventIsNotZeroAndLiteralZeroStaysZero() async throws {
        let box = PrivacyPageSessionBox()
        let fake = PrivacyPageHTTPFake([
            #"{"code":200,"data":{"docType":"privacy_policy","scene":"roam_location","eventType":"UNKNOWN","recordCount":0}}"#,
            #"{"code":200,"data":{"docType":"activity_host_data_sharing","scene":"activity_signup","eventType":"AGREE"}}"#
        ])
        let model = PrivacyProtectionPageModel(policy: policy(), consent: try service(fake, box: box, readsEnabled: true), session: { box.session })
        await model.reload()
        XCTAssertEqual(model.phase, .unknown)
        XCTAssertEqual(model.phase.accessibilityIdentifier, PrivacyProtectionPageAccessibility.unknown)
        XCTAssertNil(PrivacyProtectionNumberFact.parse("UNKNOWN").literal)
        XCTAssertEqual(PrivacyProtectionNumberFact.parse("UNKNOWN").displayText, "—")
        XCTAssertEqual(PrivacyProtectionNumberFact.parse(nil).displayText, PrivacyProtectionNumberFact.unknownDisplay)
        XCTAssertNotEqual(PrivacyProtectionNumberFact.parse("UNKNOWN").displayText, "0")
        XCTAssertNotEqual(PrivacyProtectionNumberFact.parse("UNKNOWN").literal, 0)
        XCTAssertEqual(PrivacyProtectionNumberFact.parse("0").literal, 0)
        XCTAssertEqual(PrivacyProtectionNumberFact.parse("0").displayText, "0")
        XCTAssertNil(PrivacyProtectionNumberFact.parse("00").literal)
        XCTAssertNil(PrivacyProtectionNumberFact.parse("0.0").literal)
        XCTAssertEqual(PrivacyProtectionNumberFact.parse("00").displayText, "—")
        XCTAssertNil(model.usageRecordCountText(.unknown))
        XCTAssertNil(model.usageRecordCountText(.value(0)))
        await model.reload()
        XCTAssertEqual(model.phase, .unknown)
    }

    func testReadFailureIsErrorAndDisabledReadStaysHidden() async throws {
        let box = PrivacyPageSessionBox()
        let failed = PrivacyPageHTTPFake([#"{"code":400,"msg":"no"}"#])
        let failing = PrivacyProtectionPageModel(policy: policy(), consent: try service(failed, box: box, readsEnabled: true), session: { box.session })
        await failing.reload()
        XCTAssertEqual(failing.phase, .error(.init(token: "no")))
        XCTAssertEqual(failing.phase.accessibilityIdentifier, PrivacyProtectionPageAccessibility.error)
        let unavailable = PrivacyPageHTTPFake([])
        let hidden = PrivacyProtectionPageModel(policy: policy(), consent: try service(unavailable, box: box, readsEnabled: false), session: { box.session })
        await hidden.reload()
        XCTAssertEqual(hidden.phase, .empty)
        XCTAssertTrue(hidden.serverConsentHidden)
        XCTAssertTrue(unavailable.requests.isEmpty)
        box.session = .init(accountID: 0, epoch: 1, market: "CN", namespace: "privacy-page")
        let blocked = PrivacyPageHTTPFake([#"{"code":200,"data":{"docType":"privacy_policy","scene":"roam_location","eventType":"AGREE"}}"#])
        let model = PrivacyProtectionPageModel(policy: policy(), consent: try service(blocked, box: box, readsEnabled: true), session: { box.session })
        await model.reload()
        XCTAssertEqual(model.phase, .empty)
        XCTAssertTrue(blocked.requests.isEmpty)
    }

    func testWithdrawDeviceConsentDoesNotPost() async throws {
        let box = PrivacyPageSessionBox()
        let stored = policy()
        try stored.agree(agreementChecked: true)
        let fake = PrivacyPageHTTPFake([#"{"code":200,"data":{"docType":"privacy_policy","scene":"roam_location","eventType":"AGREE","docVersion":"v2.1"}}"#])
        let model = PrivacyProtectionPageModel(policy: stored, consent: try service(fake, box: box, readsEnabled: true), session: { box.session })
        await model.reload()
        XCTAssertEqual(fake.requests.count, 1)
        model.withdrawDeviceConsent()
        guard case .ready(let snapshot) = model.phase else { return XCTFail("expected ready after withdrawal") }
        XCTAssertFalse(snapshot.deviceAgreementGranted)
        XCTAssertFalse(snapshot.showsDeviceWithdrawal)
        XCTAssertEqual(snapshot.roamLocationEvent, "AGREE")
        XCTAssertFalse(stored.granted)
        XCTAssertFalse(UsageConsentPolicy.liveRecordingApproved)
        XCTAssertEqual(fake.requests.count, 1)
        model.withdrawDeviceConsent()
        XCTAssertEqual(fake.requests.count, 1)
    }

    func testStaleLatestConsentCannotReplaceTheCurrentRead() async throws {
        let box = PrivacyPageSessionBox()
        let reader = PrivacyPageNestedReader()
        reader.agreed = try consent(#"{"docType":"privacy_policy","scene":"roam_location","eventType":"AGREE","docVersion":"v2.1"}"#)
        let model = PrivacyProtectionPageModel(policy: policy(), consent: reader, session: { box.session })
        reader.model = model
        await model.reload()
        XCTAssertEqual(reader.calls, 2)
        XCTAssertEqual(reader.phaseAtFirstCall, .loading)
        XCTAssertEqual(model.phase, .empty)
        XCTAssertFalse(model.serverConsentHidden)
    }

    func testMoneyWritesAndUsageRecordRouteStayOff() {
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        XCTAssertFalse(UsageConsentPolicy.liveRecordingApproved)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/compliance/usage-records"), .missing)
        XCTAssertTrue(PrivacyProtectionPageModel.usageRecordHistoryHidden)
        XCTAssertTrue(PrivacyProtectionPageModel.latestConsentRouteIsLive)
        XCTAssertNotEqual(PrivacyProtectionNumberFact.unknownDisplay, "0")
    }

#if DEBUG
    func testFixtureDataDecodesKnownEventsAndCountTokens() throws {
        let agreed = try PrivacyProtectionPageFixtureData.consent(PrivacyProtectionPageFixtureData.agreed)
        let revoked = try PrivacyProtectionPageFixtureData.consent(PrivacyProtectionPageFixtureData.revoked)
        let unknown = try PrivacyProtectionPageFixtureData.consent(PrivacyProtectionPageFixtureData.unknownEvent)
        XCTAssertTrue(agreed.matches(.roamLocation, event: .agree))
        XCTAssertTrue(revoked.matches(.roamLocation, event: .revoke))
        XCTAssertFalse(unknown.matches(.roamLocation, event: .agree))
        XCTAssertFalse(unknown.matches(.roamLocation, event: .revoke))
        XCTAssertEqual(PrivacyProtectionNumberFact.parse(PrivacyProtectionPageFixtureData.unknownCountToken), .unknown)
        XCTAssertEqual(PrivacyProtectionNumberFact.parse(PrivacyProtectionPageFixtureData.literalZeroCountToken), .value(0))
        XCTAssertEqual(PrivacyProtectionNumberFact.parse(PrivacyProtectionPageFixtureData.paddedZeroCountToken), .unknown)
    }
#endif
}
