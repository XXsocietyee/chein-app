import XCTest
@testable import Questify

@MainActor final class WP08ReceiveNativeURLAuditTests: XCTestCase {
    private let host = "link.example.test"

    override func tearDown() {
        DeepLinkSafetyAudit.verifiedHTTPSHosts = []
        DeepLinkSafetySnapshot.latestIntake = nil
        super.tearDown()
    }

    func testUnsafeSchemeIsInertNoNavigation() throws {
        let session = AppSession()
        DeepLinkSafetyAudit.verifiedHTTPSHosts = [host]
        for raw in ["http://\(host)/topic?topicId=108", "javascript:alert(1)", "file:///tmp/topic"] {
            session.receiveNativeURL(try XCTUnwrap(URL(string: raw)))
            XCTAssertNil(session.nativeEntry, raw)
            XCTAssertNil(session.pendingDeepLink, raw)
        }
        XCTAssertEqual(DeepLinkSafetySnapshot.latestIntake?.lastEvaluatedOutcome, .rejectedUntrustedHostOrScheme)
        XCTAssertEqual(DeepLinkSafetySnapshot.latestIntake?.opensPaymentOrPasswordRoutes, false)
    }

    func testUnauthenticatedProtectedLinkDoesNotNavigate() throws {
        let session = AppSession()
        XCTAssertNil(session.account)
        DeepLinkSafetyAudit.verifiedHTTPSHosts = [host]
        let url = try XCTUnwrap(URL(string: "https://\(host)/club/workspace?clubId=88"))
        let decision = DeepLinkSafetyAudit.classify(
            url: url,
            session: DeepLinkAndUniversalLinkSafetyAudit.SessionContext(
                realmIdentifier: "cn", isAuthenticated: false, accountID: 0),
            verifiedHTTPSHosts: [host]
        )
        XCTAssertEqual(decision, .authenticationRequired(target: .clubWorkspace(clubID: 88)))
        session.receiveNativeURL(url)
        XCTAssertNil(session.nativeEntry)
        XCTAssertNil(session.pendingDeepLink)
        XCTAssertEqual(DeepLinkSafetySnapshot.latestIntake?.lastEvaluatedOutcome, .rejectedAuthenticationRequired)
    }

    func testWrongRealmRejected() throws {
        let session = AppSession()
        DeepLinkSafetyAudit.verifiedHTTPSHosts = [host]
        let opposed = session.operationalMarket == .unitedStates ? "cn-prod" : "us-prod"
        let url = try XCTUnwrap(URL(string: "https://\(host)/topic?topicId=108&realm=\(opposed)"))
        let explicit = DeepLinkSafetyAudit.classify(
            url: try XCTUnwrap(URL(string: "https://\(host)/topic?topicId=108&realm=us-prod")),
            session: DeepLinkAndUniversalLinkSafetyAudit.SessionContext(
                realmIdentifier: "cn", isAuthenticated: true, accountID: 7),
            verifiedHTTPSHosts: [host]
        )
        XCTAssertEqual(explicit, .rejected(.crossRealmRejected(linkRealm: .unitedStates, sessionRealm: .china)))
        session.receiveNativeURL(url)
        XCTAssertNil(session.nativeEntry)
        XCTAssertNil(session.pendingDeepLink)
        XCTAssertEqual(DeepLinkSafetySnapshot.latestIntake?.lastEvaluatedOutcome, .rejectedCrossMarketRealm)
    }

    func testSafePublicTopicLinkRoutes() throws {
        let session = AppSession()
        DeepLinkSafetyAudit.verifiedHTTPSHosts = [host]
        session.receiveNativeURL(try XCTUnwrap(URL(string: "https://\(host)/topic?topicId=108")))
        guard case .content(let target) = session.nativeEntry?.intent else {
            return XCTFail("expected a public topic route, got \(String(describing: session.nativeEntry?.intent))")
        }
        XCTAssertEqual(target.kind, .topic)
        XCTAssertEqual(target.id, 108)
        XCTAssertNil(session.pendingDeepLink)
        XCTAssertEqual(DeepLinkSafetySnapshot.latestIntake?.lastEvaluatedOutcome, .acceptedReadOnlyRoute)
        XCTAssertEqual(DeepLinkSafetySnapshot.latestIntake?.opensPaymentOrPasswordRoutes, false)
    }

    func testPaymentAndPasswordRoutesDoNotNavigate() throws {
        let session = AppSession()
        DeepLinkSafetyAudit.verifiedHTTPSHosts = [host]
        let raws = [
            "https://\(host)/pay",
            "https://\(host)/payment/checkout",
            "https://\(host)/password",
            "https://\(host)/login",
            "https://\(host)/api/registration/pay/app",
            "https://\(host)/api/login",
            "https://user:secret@\(host)/topic?topicId=108",
            "https://\(host)/topic?topicId=108&password=nope",
            "weixin://wap/pay",
        ]
        for raw in raws {
            session.receiveNativeURL(try XCTUnwrap(URL(string: raw)))
            XCTAssertNil(session.nativeEntry, raw)
            XCTAssertNil(session.pendingDeepLink, raw)
        }
        XCTAssertEqual(DeepLinkSafetySnapshot.latestIntake?.lastEvaluatedOutcome, .rejectedPaymentOrPasswordRoute)
        XCTAssertNil(DeepLinkSafetyAudit.navigationIntent(for: .orderDetail(orderID: "ORD-9001")))
        XCTAssertNil(DeepLinkSafetyAudit.navigationIntent(for: .memberOrders))
    }

    func testCheinLinkStillRecordsPendingWithoutOpeningPayment() throws {
        let session = AppSession()
        session.receiveNativeURL(try XCTUnwrap(URL(string: "chein://roam/go")))
        XCTAssertEqual(session.pendingDeepLink, .roamGo)
        XCTAssertNil(session.nativeEntry)
    }
}
