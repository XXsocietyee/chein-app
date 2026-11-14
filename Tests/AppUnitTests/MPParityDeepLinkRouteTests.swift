import XCTest
@testable import Questify

/// Every page the Core link parser accepts maps to a parity route, so a deep link never lands on a page the
/// native router cannot open.
@MainActor final class MPParityDeepLinkRouteTests: XCTestCase {
    func testEveryReviewedPageMapsToARoute() {
        var samples: [String: [String: String]] = [
            "subpackageMember/market/pass/index": ["id": "p-1"],
            "subpackageMember/market/gift/index": ["token": "gift-token"],
            "subpackageJourney/pages/landing/index": ["k": "g", "t": "tok"],
            "subpackageJourney/pages/seats/index": ["registrationId": "9"],
        ]
        for (page, rule) in MiniProgramPageLink.reviewedPages where rule.required.contains("id") {
            samples[page] = ["id": "7"]
        }
        for page in MiniProgramPageLink.reviewedPages.keys {
            guard let link = MiniProgramPageLink(path: page, query: samples[page] ?? [:]) else { XCTFail(page); continue }
            XCTAssertNotNil(MPParityRoute(link: link), page)
        }
    }

    func testGiftAndJourneyLandingAreReachable() {
        let gift = MiniProgramPageLink(path: "/subpackageMember/market/gift/index", query: ["token": "gift-token"])!
        XCTAssertEqual(MPParityRoute(link: gift), .gift(token: "gift-token"))
        let landing = MiniProgramPageLink(journey: JourneyLinkIntake(kind: .referral, token: "ref", activityID: 4, topicID: nil))
        guard case .journeyLanding(let value) = MPParityRoute(link: landing) else { return XCTFail() }
        XCTAssertEqual(value.kind, .referral)
        XCTAssertEqual(value.token, "ref")
        XCTAssertEqual(value.activityID, "4")
        XCTAssertNil(value.topicID)
    }

    func testPageMapScreensUseTheScreenRoute() {
        let home = MiniProgramPageLink(path: "/pages/index/index", query: [:])!
        XCTAssertEqual(MPParityRoute(link: home), .screen(page: "pages/index/index", query: [:]))
        let order = MiniProgramPageLink(path: "subpackageMember/orderinfo/orderinfo", query: ["id": "7"])!
        XCTAssertEqual(MPParityRoute(link: order), .screen(page: "subpackageMember/orderinfo/orderinfo", query: ["id": "7"]))
        XCTAssertNil(MPParityRoute(miniProgramPath: "pages/club/governance/index", query: [:]))
        XCTAssertNil(MPParityRoute(miniProgramPath: "pages/merchant/customer/detail/index", query: [:]))
    }

    func testRevealFromALinkCarriesNoPaidFacts() {
        let reveal = MiniProgramPageLink(path: "subpackagePass/reveal/index", query: [:])!
        XCTAssertEqual(MPParityRoute(link: reveal), .reveal(paid: nil))
        XCTAssertEqual(
            MPParityRoute(miniProgramPath: "subpackagePass/reveal/index", query: ["mode": "paid", "count": "9", "until": "2099"]),
            .reveal(paid: nil)
        )
    }

    func testRejectsTraversalAndNonCanonicalParameters() {
        XCTAssertNil(MPParityRoute(miniProgramPath: "subpackageMember/market/pass/index", query: ["id": "../etc/passwd"]))
        XCTAssertNil(MPParityRoute(miniProgramPath: "subpackageMember/market/gift/index", query: [:]))
        XCTAssertNil(MPParityRoute(miniProgramPath: "subpackageMember/market/gift/index", query: ["token": ""]))
        XCTAssertNil(MPParityRoute(miniProgramPath: "subpackageJourney/pages/seats/index", query: ["registrationId": "007"]))
        XCTAssertNil(MPParityRoute(miniProgramPath: "pages/club/payout-receiver/index", query: ["clubId": "+7001"]))
        XCTAssertNil(MPParityRoute(miniProgramPath: "pages/club/settlement/index", query: ["clubId": "007"]))
        XCTAssertNil(MPParityRoute(miniProgramPath: "subpackageA/pages/video-bounty/index", query: ["topicId": "abc"]))
    }

    func testSubscribeLandingPagesOpenTheExistingScreens() {
        let orders = MiniProgramPageLink(path: "subpackageMember/order/order", query: [:])!
        XCTAssertEqual(MPParityRoute(link: orders), .playerOrderList)
        let received = MiniProgramPageLink(path: "pages/coop/list/index", query: [:])!
        XCTAssertEqual(MPParityRoute(link: received), .coopList(.received))
        let sent = MiniProgramPageLink(path: "pages/coop/list/index", query: ["tab": "sent"])!
        XCTAssertEqual(MPParityRoute(link: sent), .coopList(.sent))
        let projects = MiniProgramPageLink(path: "subpackageA/pages/myproject/index", query: [:])!
        XCTAssertEqual(MPParityRoute(link: projects), .myProjects)
        let ledger = MiniProgramPageLink(path: "pages/merchant/ledger/index", query: [:])!
        XCTAssertEqual(MPParityRoute(link: ledger), .merchantLedger)
        let push = PushTapRouter(routeKeys: ["page"])
        guard case .miniProgramPage(let tapped) = push.intent(userInfo: ["page": "pages/coop/list/index?tab=sent"]) else {
            return XCTFail("sent coop page")
        }
        XCTAssertEqual(MPParityRoute(link: tapped), .coopList(.sent))
        XCTAssertNil(push.intent(userInfo: ["page": "pages/roam/index"]))
        XCTAssertNil(push.intent(userInfo: ["type": "ROAM_RECALL", "page": ""]))
    }
}
