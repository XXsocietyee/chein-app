import XCTest
#if canImport(QuestifyApp)
@testable import QuestifyApp
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif
#else
@testable import Questify
#endif

/// Acceptance R2 (flows 08-11): F-12 growth, F-13 withdrawal entry, F-14 topic publish on the TEST host,
/// F-16 merchant workbench reads, F-17 payout account reload, F-18 verification result ids.
@MainActor final class AcceptanceR2GateTests: XCTestCase {
    static let base = "https://api.example.com"
    static let token = "synthetic-7"

    final class Vault: AppTokenStorage {
        var value: String?
        func read() throws -> String? { value }
        func write(_ token: String) throws { value = token }
        func clear() throws { value = nil }
    }
    final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
        }
    }

    private func composition(gates: Bool, wire: Wire) throws -> AppCompositionRoot {
        let suite = "acceptance-r2-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let build = RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: Self.base,
            bundleIdentifier: "com.questify.ios", realm: "acceptance-r2-" + UUID().uuidString.lowercased())
        let deployment = try ReviewedAppDeployment(market: .china, baseURL: Self.base, approvedBaseURLs: [.china: [Self.base]],
            verifiedCapabilities: [.domesticChinaPhone], bundleIdentifier: "com.questify.ios", realm: build.realm!,
            reads: [], productionGatesEnabled: gates)
        let vault = Vault()
        return RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in vault }), makeTransport: { wire })
    }

    private func context(_ root: AppCompositionRoot, role: String = "player") throws -> RuntimeDependencyContext {
        RuntimeDependencyContext(market: .china, baseURL: try XCTUnwrap(URL(string: Self.base)), role: role,
            session: try PlayExperienceSession(accountID: 7, epoch: 1, namespace: root.reviewed?.storageScope.service ?? "unconfigured",
                token: Self.token, role: role))
    }

    // MARK: F-12 growth center

    /// The Growth Center's own reads were never given an approval, so every card said 成长功能暂不可用.
    /// The reviewed production gate bundle now issues one (non-money own-account reads), stable per viewer.
    func testGrowthReadApprovalIsIssuedWithTheReviewedProductionGates() throws {
        let root = try composition(gates: true, wire: Wire())
        for role in ["player", "club", "merchant"] {
            let viewer = try context(root, role: role)
            let approval = try XCTUnwrap(root.growthNormalReadApproval(viewer), role)
            XCTAssertTrue(approval.matches(viewer))
            XCTAssertTrue(root.growthNormalReadApproval(viewer) === approval, "the transport's identity fence needs a stable lease")
        }
        XCTAssertNil(root.growthNormalReadApproval(try context(root, role: "guest")))
    }

    func testGrowthReadApprovalStaysClosedWithoutProductionGates() throws {
        let root = try composition(gates: false, wire: Wire())
        XCTAssertNil(root.growthNormalReadApproval(try context(root)))
    }

    // MARK: F-13 withdrawal entry (owner rule: money is TEST/DEBUG only)

    func testWithdrawalEntryOpensOnlyForTestOrDebugOffTheProductionHost() {
        XCTAssertTrue(WalletPayoutCapability.decision(testOrDebug: true, apiHost: "8120.example.test"), "DEBUG/TEST build on the TEST host")
        XCTAssertTrue(WalletPayoutCapability.decision(testOrDebug: false, apiHost: "8120.example.test"), "Release build on a test host")
        XCTAssertTrue(WalletPayoutCapability.decision(testOrDebug: false, apiHost: ReviewedAreaSwitch.productionAPIHost), "production release")
        XCTAssertTrue(WalletPayoutCapability.decision(testOrDebug: true, apiHost: ReviewedAreaSwitch.productionAPIHost), "production host")
        XCTAssertTrue(WalletPayoutCapability.decision(testOrDebug: true, apiHost: "WWW.CHENGYINHUB.COM"))
        XCTAssertFalse(WalletPayoutCapability.decision(testOrDebug: true, apiHost: nil))
        XCTAssertFalse(WalletPayoutCapability.decision(testOrDebug: true, apiHost: "  "))
    }

    /// The runtime flag follows the withdrawal switch the composition installs from its own host.
    func testRuntimeWithdrawalEntryFollowsTheInstalledHostDerivation() {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(WalletPayoutCapability.isOn)
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: "8120.example.test")
        XCTAssertTrue(WalletPayoutCapability.isOn)
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: ReviewedAreaSwitch.productionAPIHost)
        XCTAssertTrue(WalletPayoutCapability.isOn)
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: nil)
        XCTAssertFalse(WalletPayoutCapability.isOn)
    }

    // MARK: F-14 topic publish on the TEST host

    /// A DEBUG e2e run names the production base URL; the TEST-only topic edit-request routes are admitted only while
    /// the e2e composition says so. Production keeps them closed.
    func testTopicPublishRoutesOpenOnlyForTheE2ETestHost() throws {
        defer { TestHostOnlyRouteAdmission.testHostActive = false }
        let production = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        func submitGranted() -> Bool {
            ReviewedProductionGateLeases.projectEditorRoutes(baseURL: production)[.projectWrite]?
                .contains(where: { $0.path == ProjectEditRequestContract.submitPath }) == true
        }
        TestHostOnlyRouteAdmission.testHostActive = false
        // P2-6 (11-28): r3 production serves the edit-request routes, so they are granted without the TEST host too.
        XCTAssertTrue(submitGranted())
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + ProjectEditRequestContract.submitPath))
        TestHostOnlyRouteAdmission.testHostActive = true
        XCTAssertTrue(submitGranted())
        for path in [ProjectEditRequestContract.submitPath, ProjectEditRequestContract.readPath,
                     ProjectEditRequestContract.resumePostProcessingPath, TopicPublicationPath.status] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
    }

    // MARK: F-16 merchant workbench reads

    private func merchantRequest(_ path: String, events: Bool = false) throws -> URLRequest {
        let url = try XCTUnwrap(URL(string: Self.base)).appendingPathComponent(path)
        var request = try AuthRequestBuilder.makeFormRequest(url: url, fields: [:], token: Self.token, includesBody: false)
        if events {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("{}".utf8)
        }
        return request
    }

    func testCompositionAdmitsTheMerchantWorkbenchReadsForASignedInMerchant() async throws {
        let wire = Wire()
        let transport = try composition(gates: true, wire: wire).transport()
        transport.current = { .init(epoch: 1, accountID: 7, role: "merchant", token: Self.token, viewerRevision: 1) }
        _ = try await transport.send(try merchantRequest("api/merchant/dashboard"))
        _ = try await transport.send(try merchantRequest("api/merchant/todo-summary"))
        _ = try await transport.send(try merchantRequest("api/merchant/events", events: true))
        XCTAssertEqual(wire.requests.compactMap { $0.url?.path }, ["/api/merchant/dashboard", "/api/merchant/todo-summary", "/api/merchant/events"])
    }

    func testMerchantWorkbenchReadsStayClosedForPlayersAndWithoutGates() async throws {
        for (gates, role) in [(true, "player"), (false, "merchant")] {
            let wire = Wire()
            let transport = try composition(gates: gates, wire: wire).transport()
            transport.current = { .init(epoch: 1, accountID: 7, role: role, token: Self.token, viewerRevision: 1) }
            do { _ = try await transport.send(try merchantRequest("api/merchant/dashboard")); XCTFail("\(gates) \(role)") } catch {}
            XCTAssertTrue(wire.requests.isEmpty)
        }
        let base = try XCTUnwrap(URL(string: Self.base))
        var withBody = try merchantRequest("api/merchant/dashboard"); withBody.httpBody = Data("{\"merchantId\":31}".utf8)
        XCTAssertFalse(ReviewedMerchantWorkbenchReadRoute.accepts(withBody, baseURL: base, token: Self.token))
        XCTAssertFalse(ReviewedMerchantWorkbenchReadRoute.accepts(try merchantRequest("api/merchant/orders"), baseURL: base, token: Self.token))
        XCTAssertFalse(ReviewedMerchantWorkbenchReadRoute.accepts(try merchantRequest("api/merchant/access/me"), baseURL: base, token: Self.token))
        XCTAssertFalse(ReviewedMerchantWorkbenchReadRoute.accepts(try merchantRequest("api/merchant/dashboard"), baseURL: base, token: "synthetic-8"))
    }

    // MARK: F-17 payout account reload

    func testEverySettledPayoutAccountStateOffersReload() {
        XCTAssertFalse(PayoutPageState<Int>.loading.needsSeparateReload)
        XCTAssertFalse(PayoutPageState<Int>.failed(.network).needsSeparateReload, "the failure card carries its own reload")
        XCTAssertTrue(PayoutPageState<Int>.empty.needsSeparateReload)
        XCTAssertTrue(PayoutPageState<Int>.ready(1).needsSeparateReload)
    }

    // MARK: F-18 verification result

    func testConfirmedVerificationAlwaysEndsOnAnIdentifiedResult() {
        XCTAssertEqual(NativeVerificationOutcome.make(phase: .result, outcome: .redeemed, issueKey: nil), .redeemed)
        XCTAssertEqual(NativeVerificationOutcome.make(phase: .result, outcome: .failed, issueKey: nil), .rejected)
        XCTAssertEqual(NativeVerificationOutcome.make(phase: .choosing, outcome: .needsChoice, issueKey: nil), .choose)
        // An invalid code the server refuses (or a failed send) is a result too, never a blank screen.
        XCTAssertEqual(NativeVerificationOutcome.make(phase: .result, outcome: nil, issueKey: "verification.failed"), .failed("verification.failed"))
        XCTAssertEqual(NativeVerificationOutcome.make(phase: .result, outcome: .needsChoice, issueKey: "verification.notConfigured"), .failed("verification.notConfigured"))
        XCTAssertEqual(NativeVerificationOutcome.make(phase: .result, outcome: nil, issueKey: nil), .failed("verification.failed"))
        for phase: NativeVerificationWorkflow.Phase in [.idle, .loading, .reviewing, .submitting, .unknown, .disabled] {
            XCTAssertNil(NativeVerificationOutcome.make(phase: phase, outcome: .redeemed, issueKey: nil), phase.rawValue)
        }
        XCTAssertEqual(NativeVerificationOutcome.redeemed.identifier, "verification.result.redeemed")
        XCTAssertEqual(NativeVerificationOutcome.rejected.identifier, "verification.result.rejected")
        XCTAssertEqual(NativeVerificationOutcome.failed("x").identifier, "verification.result.failed")
        XCTAssertEqual(NativeVerificationOutcome.choose.identifier, "verification.result.choose")
        XCTAssertTrue(NativeVerificationOutcome.failed("x").isFailure)
        XCTAssertFalse(NativeVerificationOutcome.rejected.isFailure)
    }
}
