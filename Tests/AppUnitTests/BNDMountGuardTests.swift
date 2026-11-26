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

/// IWP-9 mount guard. Shipped composition stays unconfigured, bundle providers stay nil,
/// reservation dispatch stays off, and the cancel factory stays gated. Money switches stay false.
@MainActor final class BNDMountGuardTests: XCTestCase {
    private static let base = "https://api.example.com"
    private static let token = "synthetic-7"

    private final class Vault: AppTokenStorage {
        var value: String?
        func read() throws -> String? { value }
        func write(_ token: String) throws { value = token }
        func clear() throws { value = nil }
    }
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(#"{"code":200,"data":{"registrationId":9,"state":"PROCESSING"}}"#.utf8), 200)
        }
    }

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    private func reviewed(wire: Wire) throws -> AppCompositionRoot {
        let suite = "bnd-mount-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let build = RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: Self.base,
            bundleIdentifier: "com.questify.ios", realm: "bnd-" + UUID().uuidString.lowercased())
        let deployment = try ReviewedAppDeployment(market: .china, baseURL: Self.base, approvedBaseURLs: [.china: [Self.base]],
            verifiedCapabilities: [.domesticChinaPhone], bundleIdentifier: "com.questify.ios", realm: build.realm!,
            reads: [], productionGatesEnabled: false)
        return RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in Vault() }), makeTransport: { wire })
    }

    private func context(_ composition: AppCompositionRoot) throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        return RuntimeDependencyContext(market: .china, baseURL: try XCTUnwrap(URL(string: Self.base)), role: "player",
            session: try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: Self.token))
    }

    func testShippedCompositionStillUnconfigured() {
        let root = RegionalLaunchConfiguration.makeComposition(reviewed: nil, build: .current)
        guard case .unconfigured = root.deployment else {
            return XCTFail("reviewed: nil must stay unconfigured")
        }
        XCTAssertNil(root.reviewed)
        let text = (try? source("App/RegionalLaunchConfiguration.swift")) ?? ""
        XCTAssertTrue(text.contains("makeComposition(reviewed: nil"))
        XCTAssertFalse(text.contains("bundleApprovals"))
    }

    func testNoBundleProviderNonNilInShippedBuild() throws {
        let suite = "bnd-session-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let stored = AppCompositionRoot(storage: .init(defaults: defaults, tokenStore: { _ in Vault() }))
        let session = AppSession(composition: stored)
        XCTAssertTrue(session.makeBundlePorts().providersAreNil)
        let shipped = RegionalLaunchConfiguration.makeComposition(reviewed: nil, build: .current)
        XCTAssertTrue(shipped.makeBundlePorts(session: session).providersAreNil)
        var reviewedRoot = try reviewed(wire: Wire())
        let live = try context(reviewedRoot)
        XCTAssertNil(reviewedRoot.bundleApprovals.read(live))
        XCTAssertNil(reviewedRoot.bundleApprovals.refund(live))
        XCTAssertNil(reviewedRoot.makeBundleReadTransport(registrationID: try FreeExploreLaunchID(9), receiptRequestIDs: [],
            context: live, approval: nil, current: { true }, denied: {}))
        XCTAssertNil(reviewedRoot.makeBundleRefundClient(registrationID: try FreeExploreLaunchID(9), context: live,
            approval: nil, current: { live }, unauthorized: {}))
        XCTAssertNil(reviewedRoot.makeBundleCancelTransport(context: live, approval: nil, current: { live }, denied: {}))
        let plain = AppCompositionRoot()
        let approval = try BundleFeatureApproval(context: live, feature: .read, expiresAt: Date().addingTimeInterval(60))
        defer { approval.revoke() }
        XCTAssertNil(plain.makeBundleReadTransport(registrationID: try FreeExploreLaunchID(9), receiptRequestIDs: [],
            context: live, approval: approval, current: { true }, denied: {}))
    }

    func testReservationDispatchStillOffByDefault() throws {
        let launch = try FreeExploreLaunchSession(baseURL: URL(string: "https://example.test")!, accountID: 5, market: "CN",
                                                  namespace: "test", role: "player", epoch: 1, token: "synthetic-test-credential")
        let service = FreeExploreLaunchService(session: launch, transport: Wire(), currentSession: { launch })
        XCTAssertFalse(service.permitsReservationDispatch)
        let text = try source("Core/FreeExploreLaunchService.swift")
        XCTAssertTrue(text.contains("reservationAllowed: @escaping () -> Bool = { false }"))
        let model = try source("App/FreeExploreBundleLaunchModel.swift")
        XCTAssertFalse(model.contains("permitsReservationDispatch: Bool { true }"))
    }

    func testCancelFactoryStillGatedByDefault() throws {
        let canceler = FreeExploreCancelFactory.makeCanceler()
        XCTAssertTrue(canceler is GatedFreeExploreReservationCanceler)
        let text = try source("App/FreeExploreCancelFactory.swift")
        XCTAssertTrue(text.contains("GatedFreeExploreReservationCanceler()"))
        XCTAssertFalse(text.contains("BundleCancelCanceler()"))
    }

    func testMoneySwitchesStayFalse() throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        XCTAssertFalse(BundleMoneyWriteGate.allowsRefundApply)
        let text = try source("Core/ChinaReviewedRouteCapability.swift")
        XCTAssertTrue(text.contains("public static var paymentEnabled: Bool { testDerivation?(.payment) ?? false }"))
        XCTAssertTrue(text.contains("public static var payoutEnabled: Bool { testDerivation?(.payout) ?? false }"))
        XCTAssertTrue(text.contains("public static var withdrawalEnabled: Bool { testDerivation?(.withdrawal) ?? false }"))
        XCTAssertTrue(text.contains("public static var virtualGoodsEnabled: Bool { testDerivation?(.virtualGoods) ?? false }"))
        XCTAssertFalse(text.contains("paymentEnabled = true"))
        XCTAssertFalse(text.contains("virtualGoodsEnabled = true"))
    }

    func testRefundAndReadFactoriesStayClosedWithoutAnApprovalAndDoNotSend() async throws {
        let wire = Wire()
        var root = try reviewed(wire: wire)
        let live = try context(root)
        let registration = try FreeExploreLaunchID(9)
        let refundApproval = try BundleFeatureApproval(context: live, feature: .refund, expiresAt: Date().addingTimeInterval(60), permitsWrites: true)
        let readApproval = try BundleFeatureApproval(context: live, feature: .read, expiresAt: Date().addingTimeInterval(60))
        defer { refundApproval.revoke(); readApproval.revoke() }
        root.bundleApprovals.refund = { $0 == live ? refundApproval : nil }
        root.bundleApprovals.read = { $0 == live ? readApproval : nil }
        let client = root.makeBundleRefundClient(registrationID: registration, context: live, approval: refundApproval,
            current: { live }, unauthorized: {})
        XCTAssertNotNil(client)
        XCTAssertFalse(client?.permitsWrites ?? true)
        let quote = try JSONDecoder().decode(FreeExploreLaunchRefundQuote.self, from: Data(#"{"route":"ORIGINAL_METHOD","amount":"49.75","totalValue":"80.00","remainingValue":"10.07","remainingRatio":"0.1259","afterSalesForMerchantBreach":false,"reason":"","policyVersion":"v"}"#.utf8))
        let model = BundleRefundProgressModel(quote: quote, registrationId: registration, orderUnitIDs: [try FreeExploreLaunchID(21)], client: client)
        await model.apply(idempotencyKey: "refund-key-1")
        XCTAssertTrue(wire.requests.isEmpty)
        XCTAssertFalse(model.canApply)
        let transport = root.makeBundleReadTransport(registrationID: registration, receiptRequestIDs: ["req-1"],
            context: live, approval: readApproval, current: { true }, denied: {})
        XCTAssertNotNil(transport)
        let refused = try BundleRefundTransport(context: live, registrationID: registration, underlying: wire, current: { live })
        var post = URLRequest(url: try XCTUnwrap(URL(string: Self.base + "/api/pay/create")))
        post.httpMethod = "POST"
        post.setValue(Self.token, forHTTPHeaderField: "Authorization")
        do { _ = try await refused.send(post); XCTFail("other paths must be refused") }
        catch { XCTAssertTrue(wire.requests.isEmpty) }
    }
}
