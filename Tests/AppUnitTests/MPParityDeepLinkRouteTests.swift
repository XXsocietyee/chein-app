import XCTest
@testable import Questify

/// Every page the Core link parser accepts maps to a parity route, so a deep link never lands on a page the
/// native router cannot open.
@MainActor final class MPParityDeepLinkRouteTests: XCTestCase {
    func testEveryReviewedPageMapsToARoute() {
        let samples: [String: [String: String]] = [
            "subpackageMember/market/pass/index": ["id": "p-1"],
            "subpackageMember/market/gift/index": ["token": "gift-token"],
            "subpackageJourney/pages/landing/index": ["k": "g", "t": "tok"],
            "subpackageJourney/pages/seats/index": ["registrationId": "9"],
        ]
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

    func testRevealFromALinkCarriesNoPaidFacts() {
        let reveal = MiniProgramPageLink(path: "subpackagePass/reveal/index", query: [:])!
        XCTAssertEqual(MPParityRoute(link: reveal), .reveal(paid: nil))
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
