import XCTest
@testable import QuestifyCore

final class WP08DeepLinkAuditCoverageTests: XCTestCase {
    private let hosts: Set<String> = ["link.example.test"]
    private let guest = DeepLinkAndUniversalLinkSafetyAudit.SessionContext(
        realmIdentifier: "cn",
        isAuthenticated: false,
        accountID: 0
    )
    private let signedIn = DeepLinkAndUniversalLinkSafetyAudit.SessionContext(
        realmIdentifier: "cn",
        isAuthenticated: true,
        accountID: 7
    )

    func testEveryAppEntryURLShapeHasAClassification() throws {
        let shapes: [(String, DeepLinkAndUniversalLinkSafetyAudit.SessionContext, DeepLinkAndUniversalLinkSafetyAudit.AuditDecision)] = [
            ("https://link.example.test/topic?topicId=108", guest, .allowReadOnly(.publicTopicDetail(topicID: 108))),
            ("https://link.example.test/pages/topic/index?id=9", guest, .allowReadOnly(.publicTopicDetail(topicID: 9))),
            ("https://link.example.test/profile?memberId=42", guest, .allowReadOnly(.publicMemberProfile(memberID: 42))),
            ("https://link.example.test/profile?memberId=0", guest, .incompleteProfileLinkFallback(fallbackLocalizationKey: "social.incompleteLink")),
            ("https://link.example.test/team/join?code=INVITE_2026", guest, .allowReadOnly(.teamInvitation(inviteCode: "INVITE_2026"))),
            ("https://link.example.test/merchant/public-home?merchantId=5", guest, .allowReadOnly(.publicMerchantHome(merchantID: 5))),
            ("https://link.example.test/member/orders", guest, .authenticationRequired(target: .memberOrders)),
            ("https://link.example.test/member/orders?orderId=ORD-9001", signedIn, .allowReadOnly(.orderDetail(orderID: "ORD-9001"))),
            ("https://link.example.test/club/workspace?clubId=88", guest, .authenticationRequired(target: .clubWorkspace(clubID: 88))),
            ("https://link.example.test/merchant/workbench?merchantId=4", guest, .authenticationRequired(target: .merchantWorkbench(merchantID: 4))),
            ("http://link.example.test/topic?topicId=108", guest, .rejected(.nonHTTPSScheme("http"))),
            ("javascript:alert(1)", guest, .rejected(.nonHTTPSScheme("javascript"))),
            ("chein://roam/go", guest, .rejected(.nonHTTPSScheme("chein"))),
            ("chein://ticket/15", guest, .rejected(.nonHTTPSScheme("chein"))),
            ("chein://club/4/join", guest, .rejected(.nonHTTPSScheme("chein"))),
            ("https://link.example.test/pay", guest, .rejected(.paymentOrPasswordRoute("/pay"))),
            ("https://link.example.test/payment/checkout", guest, .rejected(.paymentOrPasswordRoute("/payment/checkout"))),
            ("https://link.example.test/password", guest, .rejected(.paymentOrPasswordRoute("/password"))),
            ("https://link.example.test/login", guest, .rejected(.paymentOrPasswordRoute("/login"))),
            ("https://link.example.test/pages/auth/sign-in", guest, .rejected(.paymentOrPasswordRoute("/pages/auth/sign-in"))),
            ("https://link.example.test/reset-password", guest, .rejected(.paymentOrPasswordRoute("/reset-password"))),
            ("https://link.example.test/api/registration/pay", guest, .rejected(.paymentOrPasswordRoute("/api/registration/pay"))),
            ("https://link.example.test/api/registration/pay/app", guest, .rejected(.paymentOrPasswordRoute("/api/registration/pay/app"))),
            ("https://link.example.test/api/login", guest, .rejected(.paymentOrPasswordRoute("/api/login"))),
            ("https://link.example.test/api/pay/create", guest, .rejected(.paymentOrPasswordRoute("/api/pay/create"))),
            ("https://user:secret@link.example.test/topic?topicId=108", guest, .rejected(.paymentOrPasswordRoute("/topic"))),
            ("https://link.example.test/topic?topicId=108&password=nope", guest, .rejected(.paymentOrPasswordRoute("/topic"))),
            ("https://link.example.test/topic?topicId=108&realm=us", guest, .rejected(.crossRealmRejected(linkRealm: .unitedStates, sessionRealm: .china))),
            ("https://untrusted.example/topic?topicId=108", guest, .rejected(.untrustedHost("untrusted.example"))),
            ("https://link.example.test/does-not-exist", guest, .rejected(.unsupportedRoute("/does-not-exist"))),
            ("https://link.example.test/door?scene=abc", guest, .rejected(.unsupportedRoute("/door"))),
            ("https://link.example.test/topic?topicId=108&autoPay=1", guest, .rejected(.writeOrPaymentIntentRejected(keys: ["autoPay"]))),
            ("wx123456://oauth", guest, .rejected(.nonHTTPSScheme("wx123456"))),
            ("weixin://wap/pay", guest, .rejected(.paymentOrPasswordRoute("/pay"))),
        ]
        for (raw, session, expected) in shapes {
            let url = try XCTUnwrap(URL(string: raw), raw)
            let decision = DeepLinkSafetyAudit.classify(url: url, session: session, verifiedHTTPSHosts: hosts)
            XCTAssertEqual(decision, expected, raw)
        }
    }

    func testNavigationIntentOpensOnlyPublicTopicTeamAndMerchant() {
        let topic = DeepLinkSafetyAudit.navigationIntent(for: .publicTopicDetail(topicID: 108))
        XCTAssertEqual(topic, NativeContentTarget(kind: .topic, id: 108).map(NativeEntryIntent.content))
        XCTAssertNotNil(DeepLinkSafetyAudit.navigationIntent(for: .teamInvitation(inviteCode: "INVITE_2026")))
        XCTAssertNotNil(DeepLinkSafetyAudit.navigationIntent(for: .publicMerchantHome(merchantID: 5)))
        XCTAssertNil(DeepLinkSafetyAudit.navigationIntent(for: .publicMemberProfile(memberID: 42)))
        XCTAssertNil(DeepLinkSafetyAudit.navigationIntent(for: .memberOrders))
        XCTAssertNil(DeepLinkSafetyAudit.navigationIntent(for: .orderDetail(orderID: "ORD-9001")))
        XCTAssertNil(DeepLinkSafetyAudit.navigationIntent(for: .clubWorkspace(clubID: 88)))
        XCTAssertNil(DeepLinkSafetyAudit.navigationIntent(for: .merchantWorkbench(merchantID: 4)))
    }

    func testClosedSegmentsCannotBeReclassifiedAsSafeDestinations() throws {
        for segment in DeepLinkAndUniversalLinkSafetyAudit.closedPaymentAndPasswordSegments {
            let url = try XCTUnwrap(URL(string: "https://link.example.test/\(segment)"))
            let decision = DeepLinkSafetyAudit.classify(url: url, session: guest, verifiedHTTPSHosts: hosts)
            guard case .rejected(.paymentOrPasswordRoute(_)) = decision else {
                return XCTFail("\(segment) classified as \(decision)")
            }
        }
    }
}
