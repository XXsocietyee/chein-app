import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class I00UserInfoTransport: HTTPTransport {
    let response: String
    var requests: [URLRequest] = []
    init(_ response: String) { self.response = response }
    func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (Data(response.utf8), 200) }
}

/// I00 baseline: the unconfigured build stays OFF, and a current-account projection that carries no
/// explicit server role (the hengyin master userInfo whitelist) never establishes a native session.
@MainActor final class I00SessionAdmissionBaselineTests: XCTestCase {
    private let endpoint = "https://cn.example.com/gateway"
    /// Exact key set of the master `userInfoView` whitelist, with sanitized synthetic values only.
    private func masterProjection(userType: Int) -> String {
        #"{"code":200,"msg":"操作成功","appUser":{"createBy":null,"createTime":null,"updateBy":null,"updateTime":null,"remark":null,"#
        + #""userId":17,"userName":"synthetic","nickName":"Synthetic","email":"","mobile":"","sex":"0","avatar":"","#
        + #""status":"1","delFlag":"0","loginIp":"","loginDate":null,"userType":\#(userType)}}"#
    }
    private func configuration() throws -> RegionalConfiguration {
        try RegionalConfiguration(market: .china, baseURL: endpoint, approvedBaseURLs: [.china: [endpoint]],
            verifiedCapabilities: [.domesticChinaPhone])
    }

    func testUnconfiguredBuildHasNoEndpointCapabilityOrVault() throws {
        for market in RegionalMarket.allCases {
            let config = try RegionalConfiguration(market: market)
            XCTAssertNil(config.apiConfiguration)
            XCTAssertTrue(config.availableCapabilities.isEmpty)
            XCTAssertThrowsError(try RegionalSessionStorageScope(configuration: config, bundleIdentifier: "example.native", realm: "cn-fixture"))
        }
        XCTAssertThrowsError(try RegionalConfiguration(market: .china, baseURL: endpoint)) {
            XCTAssertEqual($0 as? RegionalConfigurationError, .unapprovedBackend)
        }
        let unverified = try RegionalConfiguration(market: .china, baseURL: endpoint, approvedBaseURLs: [.china: [endpoint]])
        XCTAssertEqual(unverified.availability(of: .domesticChinaPhone), .verificationPending)
        XCTAssertFalse(unverified.canUseDomesticChinaPhone)
        let scope = try RegionalSessionStorageScope(configuration: unverified, bundleIdentifier: "example.native", realm: "cn-fixture")
        XCTAssertThrowsError(try CNAccountSessionService(configuration: unverified, storageScope: scope, transport: I00UserInfoTransport("{}")))
    }

    func testMasterUserInfoProjectionWithoutRoleCannotRestoreOrCompleteLogin() async throws {
        let config = try configuration()
        let scope = try RegionalSessionStorageScope(configuration: config, bundleIdentifier: "example.native", realm: "cn-fixture")
        let api = try XCTUnwrap(config.apiConfiguration)
        for userType in [1, 2] {
            let raw = masterProjection(userType: userType)
            struct Envelope: Decodable { let appUser: Account }
            let decoded = try JSONDecoder().decode(Envelope.self, from: Data(raw.utf8)).appUser
            XCTAssertEqual(decoded.id, 17); XCTAssertEqual(decoded.role, "", "The master whitelist carries no role key")
            XCTAssertEqual(decoded.effectiveRole, userType == 2 ? "merchant" : "player", "Presentation fallback exists but is never an admission")
            let restore = I00UserInfoTransport(raw)
            do { _ = try await CNAccountSessionService(configuration: config, storageScope: scope, transport: restore).currentAccount(token: "synthetic-session"); XCTFail("userType must not stand in for a server role") }
            catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
            XCTAssertEqual(restore.requests.count, 1)
            let readback = I00UserInfoTransport(raw)
            do { _ = try await AuthChannelService(configuration: api, transport: readback).currentAccount(token: "synthetic-session"); XCTFail("Login readback must not default a role") }
            catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
        }
    }

    func testExplicitServerRoleInSameProjectionIsTheOnlyAdmission() async throws {
        let config = try configuration()
        let scope = try RegionalSessionStorageScope(configuration: config, bundleIdentifier: "example.native", realm: "cn-fixture")
        let raw = masterProjection(userType: 1).replacingOccurrences(of: #""userType":1}"#, with: #""userType":1,"role":"club"}"#)
        let account = try await CNAccountSessionService(configuration: config, storageScope: scope, transport: I00UserInfoTransport(raw))
            .currentAccount(token: "synthetic-session")
        XCTAssertEqual(account.id, 17); XCTAssertEqual(account.role, "club"); XCTAssertEqual(account.effectiveRole, "club")
    }
}

@MainActor private final class G1CoreTestWire: HTTPTransport {
    var requests: [URLRequest] = []
    var omitRoleInUserInfo = false
    var account = 7
    var role = "player"
    private var marketingOptedIn = true
    private var marketingRecordedRequests: Set<String> = []
    private var topicLiked = true

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        if path.hasSuffix("/api/login/phone") {
            return (Data("{\"code\":200,\"token\":\"synthetic-\(account)\",\"data\":{\"id\":\(account),\"role\":\"\(role)\"}}".utf8), 200)
        }
        if path.hasSuffix("/api/login/apple") {
            return (Data("{\"code\":200,\"token\":\"synthetic-apple-\(account)\",\"data\":{\"id\":\(account),\"role\":\"\(role)\"}}".utf8), 200)
        }
        if path.hasSuffix("/api/userInfo") {
            if omitRoleInUserInfo {
                return (Data("{\"code\":200,\"appUser\":{\"userId\":\(account),\"nickName\":\"G1 Tester\",\"userType\":1}}".utf8), 200)
            }
            return (Data("{\"code\":200,\"appUser\":{\"userId\":\(account),\"nickName\":\"G1 Tester\",\"role\":\"\(role)\"}}".utf8), 200)
        }
        if path.hasSuffix("/api/user/deregister/status") {
            return (Data(#"{"code":200,"data":{"status":"NORMAL"}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/user/deregister/precheck") {
            return (Data(#"{"code":200,"data":{"status":"ELIGIBLE","verificationMethod":"SMS"}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/user/deregister/apply") {
            return (Data(#"{"code":200,"data":{"status":"PENDING","executeAfter":"2026-11-22 12:00:00"}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/compliance/consents") && !path.hasSuffix("/latest") {
            return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/compliance/consents/latest") {
            return (Data(#"{"code":200,"data":{"docType":"account_cancellation_notice","scene":"account_cancel","eventType":"AGREE","docVersion":"v1"}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/merchant/crm/marketing-consents/result") {
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let reqID = query.first(where: { $0.name == "requestId" })?.value ?? ""
            let channel = query.first(where: { $0.name == "channel" })?.value ?? "IN_APP"
            if marketingRecordedRequests.contains(reqID) {
                let eventType = marketingOptedIn ? "OPT_IN" : "OPT_OUT"
                let json = """
                {"code":200,"data":{"receiptVersion":1,"actorId":\(account),"merchantRowId":10,"merchantOwnerMemberId":20,"channel":"\(channel)","requestId":"\(reqID)","outcome":"RECORDED","consentId":101,"eventType":"\(eventType)","recordedAt":1762500000}}
                """
                return (Data(json.utf8), 200)
            }
            let json = """
            {"code":200,"data":{"receiptVersion":1,"actorId":\(account),"merchantRowId":10,"merchantOwnerMemberId":20,"channel":"\(channel)","requestId":"\(reqID)","outcome":"NOT_OBSERVED"}}
            """
            return (Data(json.utf8), 200)
        }
        if path.hasSuffix("/api/merchant/crm/marketing-consents") {
            if request.httpMethod == "POST",
               let body = request.httpBody,
               let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let reqID = obj["requestId"] as? String,
               let optedIn = obj["optedIn"] as? Bool {
                marketingOptedIn = optedIn
                marketingRecordedRequests.insert(reqID)
                return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
            }
            let json = """
            {"code":200,"data":[{"merchantRowId":10,"merchantOwnerMemberId":20,"merchantName":"测试商户","inAppOptedIn":\(marketingOptedIn),"couponOptedIn":false}]}
            """
            return (Data(json.utf8), 200)
        }
        if path.hasSuffix("/api/topic/like_list") {
            if topicLiked {
                return (Data(#"{"code":200,"data":{"rows":[{"id":88,"name":"收藏主题","memberId":12}]}}"#.utf8), 200)
            }
            return (Data(#"{"code":200,"data":{"rows":[]}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/topic/like") {
            topicLiked = false
            return (Data(#"{"code":200}"#.utf8), 200)
        }
        if path.hasSuffix("/api/coupon/qr-token") {
            return (Data(#"{"code":200,"data":{"expiresIn":60,"useStatus":0,"couponName":"满减券","token":"QR-TOKEN-31"}}"#.utf8), 200)
        }
        return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
    }
}

@MainActor private final class G1CoreComplianceAuthFake: AuthChannelServing {
    var smsCalls = 0
    var failSMS = false
    func sendSMSCode(phone: String) async throws { smsCalls += 1; if failSMS { throw ComplianceFailure.rejected("SMS failed") } }
    func loginWithPhone(phone: String, code: String) async throws -> LoginResult { throw ComplianceFailure.unavailable }
    func loginWithApple(identityToken: String) async throws -> LoginResult { throw ComplianceFailure.unavailable }
    func currentAccount(token: String) async throws -> Account { throw ComplianceFailure.unavailable }
}

@MainActor private final class G1CoreComplianceEffectsFake: ComplianceRoamEffects {
    var calls: [String] = []
    func stopTracking() async throws { calls.append("stop") }
    func clearMapPrivacy() async throws { calls.append("clear") }
    func invalidateMapPrivacyCaches() { calls.append("invalidate") }
}

@MainActor final class G1CoreProductionGatesTests: XCTestCase {
    private let baseURL = URL(string: "https://api.example.com")!

    func testG1RoleFallbackInAuthChannelCoordinatorAcceptsRolelessUserInfoWhenEnabledAndKeepsPasswordDisabled() async throws {
        let regional = try RegionalConfiguration(
            market: .china,
            baseURL: baseURL.absoluteString,
            approvedBaseURLs: [.china: [baseURL.absoluteString]],
            verifiedCapabilities: [.domesticChinaPhone]
        )
        XCTAssertTrue(regional.canUseDomesticChinaPhone)
        let api = try XCTUnwrap(regional.apiConfiguration)

        let wire = G1CoreTestWire()
        wire.omitRoleInUserInfo = true
        var committed: (String, Account)?

        let strictService = AuthChannelService(configuration: api, transport: wire, allowLoginRoleFallback: false)
        let strictCoordinator = AuthChannelCoordinator(
            service: strictService,
            appleSignInApproved: true,
            currentSession: { .init(epoch: 1, accountID: nil) },
            commitLogin: { result, _ in committed = (result.token, result.account); return true }
        )
        await strictCoordinator.loginWithPhone(phone: "13800138000", code: "123456")
        XCTAssertNil(committed, "Default strict AuthChannelService must reject roleless userInfo")

        let fallbackService = AuthChannelService(configuration: api, transport: wire, allowLoginRoleFallback: true)
        let fallbackCoordinator = AuthChannelCoordinator(
            service: fallbackService,
            appleSignInApproved: true,
            currentSession: { .init(epoch: 1, accountID: nil) },
            commitLogin: { result, _ in committed = (result.token, result.account); return true }
        )
        XCTAssertTrue(fallbackCoordinator.appleConfigurationVerified)
        await fallbackCoordinator.loginWithPhone(phone: "13800138000", code: "123456")
        XCTAssertEqual(committed?.0, "synthetic-7")
        XCTAssertEqual(committed?.1.id, 7)
        XCTAssertEqual(committed?.1.role, "player")

        committed = nil
        let fallbackAppleCoordinator = AuthChannelCoordinator(
            service: fallbackService,
            appleSignInApproved: true,
            currentSession: { .init(epoch: 2, accountID: nil) },
            commitLogin: { result, _ in committed = (result.token, result.account); return true }
        )
        guard let attempt = fallbackAppleCoordinator.beginAppleAuthorization() else {
            return XCTFail("Expected Apple authorization attempt")
        }
        await fallbackAppleCoordinator.completeAppleAuthorization(attempt, identityToken: "apple.jwt.token")
        XCTAssertEqual(committed?.0, "synthetic-apple-7")
        XCTAssertEqual(committed?.1.id, 7)
        XCTAssertEqual(committed?.1.role, "player")
    }

    func testG1AccountDeletionEndToEndAndLegalCatalogAndMarketingConsentWithdrawal() async throws {
        let unapprovedReader = SettingsBundledLegalReader(privacyPolicyApproved: false)
        let unapprovedDoc = try await unapprovedReader.document(type: .privacyPolicy, market: .china)
        XCTAssertEqual(unapprovedDoc, .missing(.pendingSourceText))

        let approvedReader = SettingsBundledLegalReader(privacyPolicyApproved: true)
        let approvedDoc = try await approvedReader.document(type: .privacyPolicy, market: .china)
        guard case .sourceDocument(let doc) = approvedDoc else {
            return XCTFail("Expected privacyPolicy v2.1 sourceDocument when approved")
        }
        XCTAssertEqual(doc.version, "v2.1")

        let wire = G1CoreTestWire()
        let api = try APIConfiguration(baseURL: baseURL)
        var currentSession: ComplianceSession? = .init(accountID: 7, epoch: 1, market: "CN", namespace: "g1-test")
        let runtimeContext = RuntimeDependencyContext(
            market: .china,
            baseURL: baseURL,
            role: "player",
            session: try .init(accountID: 7, epoch: 1, namespace: "g1-test", token: "synthetic-7", role: "player")
        )
        let marketingApproval = try MerchantMarketingConsentOriginalApproval(
            baseURL: baseURL,
            namespace: "g1-test",
            accountID: 7,
            allowsAllValidRows: true
        )
        let marketingClient = MerchantMarketingConsentOriginalClient(
            context: runtimeContext,
            approval: marketingApproval,
            transport: wire,
            current: { runtimeContext },
            stillApproved: { true }
        )
        let journalURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("journal.json")
        let journal = ComplianceFileJournal(url: journalURL)
        let service = AccountComplianceService(
            configuration: api,
            transport: wire,
            journal: journal,
            current: { currentSession },
            token: { "synthetic-7" },
            readsEnabled: true,
            writesEnabled: true,
            legalApproved: { _, _ in true },
            marketingOriginal: { marketingClient }
        )
        let auth = G1CoreComplianceAuthFake()
        var invalidated: ComplianceSession?
        let coordinator = AccountComplianceCoordinator(
            service: service,
            auth: auth,
            effects: G1CoreComplianceEffectsFake(),
            current: { currentSession },
            invalidateSession: { invalidated = $0; currentSession = nil }
        )

        await coordinator.loadMarketing()
        XCTAssertTrue(coordinator.state.marketingLoaded)
        guard let row = coordinator.state.marketing.first else {
            return XCTFail("Expected marketing row")
        }
        XCTAssertTrue(row.inAppOptedIn)
        guard let review = coordinator.reviewMarketing(row, channel: .inApp, optedIn: false) else {
            return XCTFail("Expected marketing review")
        }
        await coordinator.setMarketing(review, explicitlyConfirmed: true)
        XCTAssertEqual(coordinator.state.marketing.first?.inAppOptedIn, false)

        await coordinator.load()
        await coordinator.precheckAndAgree(documentRead: true, explicitAgreement: true)
        XCTAssertTrue(coordinator.state.step == .verify)
        auth.failSMS = true
        await coordinator.sendSMS(phone: "13800138000", explicitlyRequested: true)
        XCTAssertFalse(coordinator.state.smsSent)
        auth.failSMS = false
        await coordinator.sendSMS(phone: "13800138000", explicitlyRequested: true)
        XCTAssertTrue(coordinator.state.smsSent)
        coordinator.prepareReview(code: "123456")
        XCTAssertTrue(coordinator.state.step == .review)
        await coordinator.apply(explicitlyConfirmed: true)
        XCTAssertTrue(coordinator.state.step == .freshLogin)
        XCTAssertNotNil(invalidated)
    }
}
