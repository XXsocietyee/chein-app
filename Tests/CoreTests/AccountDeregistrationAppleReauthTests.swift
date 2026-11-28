import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class AppleDeregisterHTTPFake: HTTPTransport {
    var requests: [URLRequest] = []
    var responses: [String]
    init(_ responses: [String]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.timedOut) }
        return (Data(responses.removeFirst().utf8), 200)
    }
}
@MainActor private final class AppleDeregisterAuthFake: AuthChannelServing {
    var smsCalls = 0
    func sendSMSCode(phone: String) async throws { smsCalls += 1 }
    func loginWithPhone(phone: String, code: String) async throws -> LoginResult { throw ComplianceFailure.unavailable }
    func loginWithApple(identityToken: String) async throws -> LoginResult { throw ComplianceFailure.unavailable }
    func currentAccount(token: String) async throws -> Account { throw ComplianceFailure.unavailable }
}
@MainActor private final class AppleDeregisterEffectsFake: ComplianceRoamEffects {
    func stopTracking() async throws {}
    func clearMapPrivacy() async throws {}
    func invalidateMapPrivacyCaches() {}
}

/// P0-6 (App Store 5.1.1(v)): an account created with Sign in with Apple has no phone and no WeChat openid.
/// The backend precheck reports APPLE; the app re-authenticates with Apple and posts `identityToken`
/// (+ `authorizationCode`) to `/api/user/deregister/apply` instead of an SMS code.
@MainActor final class AccountDeregistrationAppleReauthTests: XCTestCase {
    private var session: ComplianceSession? = .init(accountID: 7, epoch: 1, market: "US", namespace: "deregister-apple")
    private var invalidated = 0
    private let token = "eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJhcHBsZSJ9.c2ln"

    private func coordinator(_ fake: AppleDeregisterHTTPFake, auth: AppleDeregisterAuthFake = AppleDeregisterAuthFake()) throws -> AccountComplianceCoordinator {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("journal.json")
        let service = AccountComplianceService(configuration: try APIConfiguration(baseURL: URL(string: "https://fixture.example")!), transport: fake,
                                               journal: ComplianceFileJournal(url: url), current: { [unowned self] in self.session }, token: { "synthetic-test-token" },
                                               readsEnabled: true, writesEnabled: true, legalApproved: { _, _ in true }, authoritativeMerchantID: { nil })
        return AccountComplianceCoordinator(service: service, auth: auth, effects: AppleDeregisterEffectsFake(),
                                            current: { [unowned self] in self.session }, invalidateSession: { [unowned self] _ in self.invalidated += 1 })
    }

    private func body(_ request: URLRequest) -> String { String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "" }

    func testAppleMethodIsUsableOnThisDevice() throws {
        let value = try JSONDecoder().decode(ComplianceDeregistration.self, from: Data(#"{"status":"ELIGIBLE","verificationMethod":"APPLE"}"#.utf8))
        XCTAssertTrue(value.verificationAvailableOnThisDevice)
        XCTAssertTrue(value.verifiesWithApple)
        XCTAssertEqual(DeregistrationStatusRules.evaluatePrecheck(value), .eligible(.apple))
        let precheck = AccountPublishMPContract.deregisterPrecheck(from: Data(#"{"code":200,"data":{"status":"ELIGIBLE","blockers":[],"verificationMethod":"APPLE"}}"#.utf8))
        XCTAssertEqual(precheck?.verificationMethod, "APPLE")
    }

    func testAppleProofRejectsNonJWTInput() {
        XCTAssertNil(DeregistrationAppleProof(identityToken: "", authorizationCode: nil))
        XCTAssertNil(DeregistrationAppleProof(identityToken: "not-a-jwt", authorizationCode: nil))
        XCTAssertNil(DeregistrationAppleProof(identityToken: String(repeating: "a", count: 9000) + ".b.c", authorizationCode: nil))
        let proof = DeregistrationAppleProof(identityToken: " a.b.c ", authorizationCode: "  ")
        XCTAssertEqual(proof?.identityToken, "a.b.c")
        XCTAssertNil(proof?.authorizationCode)
    }

    func testApplyRequestCarriesAppleProofFieldsAndNoSMSCode() throws {
        let proof = try XCTUnwrap(DeregistrationAppleProof(identityToken: token, authorizationCode: "c0de"))
        let request = try AccountPublishMPContract.deregisterApplyRequest(baseURL: URL(string: "https://example.com")!, requestID: "deregister-1", appleProof: proof)
        XCTAssertEqual(request.url?.path, "/api/user/deregister/apply")
        XCTAssertEqual(body(request), "requestId=deregister-1&identityToken=\(token)&authorizationCode=c0de")
        XCTAssertThrowsError(try AccountPublishMPContract.deregisterApplyRequest(baseURL: URL(string: "https://example.com")!, requestID: "deregister-1",
                                                                                 smsCode: "123456", appleProof: proof))
        XCTAssertThrowsError(try AccountPublishMPContract.deregisterApplyRequest(baseURL: URL(string: "https://example.com")!, requestID: "deregister-1"))
    }

    func testApplyRefusalTextIsReadOnlyForFailures() {
        XCTAssertEqual(AccountPublishMPContract.deregisterApplyRefusal(from: Data(#"{"code":500,"msg":"Apple 身份校验失败"}"#.utf8)), "Apple 身份校验失败")
        XCTAssertNil(AccountPublishMPContract.deregisterApplyRefusal(from: Data(#"{"code":200,"data":{"status":"PENDING"}}"#.utf8)))
        XCTAssertNil(AccountPublishMPContract.deregisterApplyRefusal(from: Data(#"{"code":500,"msg":" "}"#.utf8)))
    }

    func testServicePathReauthenticatesWithAppleAndSignsOutOnPending() async throws {
        let fake = AppleDeregisterHTTPFake([
            #"{"code":200,"data":{"status":"NORMAL"}}"#,
            #"{"code":200,"data":{"status":"ELIGIBLE","blockers":[],"verificationMethod":"APPLE"}}"#,
            #"{"code":200,"data":{"status":"PENDING","executeAfter":"2026-12-12T10:00:00.000+08:00"}}"#
        ])
        let auth = AppleDeregisterAuthFake()
        let value = try coordinator(fake, auth: auth)
        await value.load()
        await value.precheckAndAgree(documentRead: true, explicitAgreement: true, recordConsent: false)
        XCTAssertEqual(value.state.step, .verify)
        value.prepareAppleReview(identityToken: token, authorizationCode: "c0de")
        XCTAssertEqual(value.state.step, .review)
        XCTAssertEqual(value.reviewedAppleProof?.identityToken, token)
        await value.apply(explicitlyConfirmed: true)
        XCTAssertEqual(value.state.step, .freshLogin)
        XCTAssertEqual(invalidated, 1)
        XCTAssertEqual(auth.smsCalls, 0)
        let apply = try XCTUnwrap(fake.requests.last)
        XCTAssertEqual(apply.url?.path, "/api/user/deregister/apply")
        XCTAssertTrue(body(apply).contains("identityToken=\(token)"))
        XCTAssertTrue(body(apply).contains("authorizationCode=c0de"))
        XCTAssertFalse(body(apply).contains("smscode"))
        XCTAssertNil(value.reviewedAppleProof)
    }

    func testAppleReviewIsRefusedForSMSAccounts() async throws {
        let fake = AppleDeregisterHTTPFake([
            #"{"code":200,"data":{"status":"NORMAL"}}"#,
            #"{"code":200,"data":{"status":"ELIGIBLE","blockers":[],"verificationMethod":"SMS"}}"#
        ])
        let value = try coordinator(fake)
        await value.load()
        await value.precheckAndAgree(documentRead: true, explicitAgreement: true, recordConsent: false)
        XCTAssertEqual(value.state.step, .verify)
        value.prepareAppleReview(identityToken: token, authorizationCode: nil)
        XCTAssertEqual(value.state.step, .verify)
        XCTAssertNil(value.reviewedAppleProof)
    }

    func testContractLaneRefusalReturnsToVerificationWithClearErrorThenSucceeds() async throws {
        let value = try coordinator(AppleDeregisterHTTPFake([#"{"code":200,"data":{"status":"NORMAL"}}"#]))
        await value.load()
        let precheck = try XCTUnwrap(AccountPublishMPContract.deregisterPrecheck(from: Data(#"{"code":200,"data":{"status":"ELIGIBLE","blockers":[],"verificationMethod":"APPLE"}}"#.utf8)))
        value.adoptContractPrecheck(precheck, documentRead: true, explicitAgreement: true)
        XCTAssertEqual(value.state.step, .verify)

        value.noteAppleReauthFailed(cancelled: true)
        XCTAssertNil(value.state.error)
        value.noteAppleReauthFailed(cancelled: false)
        XCTAssertEqual(value.state.error, AccountComplianceCoordinator.appleReauthFailed)

        value.prepareAppleReview(identityToken: token, authorizationCode: nil)
        XCTAssertEqual(value.state.step, .review)
        XCTAssertNil(value.state.error)
        let consented = await value.prepareContractApplyConsent(recordNoticeConsent: false, expectedConsentVersion: nil)
        XCTAssertTrue(consented)
        await value.adoptContractApply(nil, refusal: "Apple 身份与当前账号不一致")
        XCTAssertEqual(value.state.step, .verify)
        XCTAssertEqual(value.state.error, AccountComplianceCoordinator.appleReauthRejected)
        XCTAssertNil(value.reviewedAppleProof)
        XCTAssertEqual(invalidated, 0)

        value.prepareAppleReview(identityToken: token, authorizationCode: "c0de")
        XCTAssertEqual(value.state.step, .review)
        await value.adoptContractApply(.pending(executeAfter: ""))
        XCTAssertEqual(value.state.step, .freshLogin)
        XCTAssertEqual(invalidated, 1)
    }
}
