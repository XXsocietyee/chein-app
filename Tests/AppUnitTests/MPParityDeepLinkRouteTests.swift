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
            "pages/team/join/index": ["entry": "code"],
            // Pages whose MP query needs one of several keys (no single `required` key):
            // 537bfd65a group-code takes activityId or topicId; c9cbcd24b the public merchant home takes id or poiId.
            "pages/club/group-code/index": ["activityId": "7"],
            "pages/merchant/profile/index": ["id": "7"],
            // mp-nav r3: poi-detail accepts exactly one of poiId or id, so an empty query is not a link.
            "subpackageRoam/poi-detail/index": ["poiId": "5"],
        ]
        // Every other required key gets a value too (parity r1: clubId, memberId, orderNo, topicId, reportId…).
        for (page, rule) in MiniProgramPageLink.reviewedPages where samples[page] == nil && !rule.required.isEmpty {
            var query = [String: String]()
            for key in rule.required { query[key] = rule.ids.contains(key) ? "7" : "x" }
            samples[page] = query
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
        // CLB-r8-governance-01 (MP governance js:204-207): a bare link opens the screen, which shows 链接已失效 + 返回.
        XCTAssertEqual(MPParityRoute(miniProgramPath: "pages/club/governance/index", query: [:]),
                       .screen(page: "pages/club/governance/index", query: [:]))
        // CLB-topic-detail-01 / CLB-workbench-01: club pages reach their screens with their MP keys.
        let topic = MiniProgramPageLink(path: "pages/club/topic-detail/index", query: ["topicId": "3", "clubId": "7"])!
        XCTAssertEqual(MPParityRoute(link: topic), .screen(page: "pages/club/topic-detail/index", query: ["topicId": "3", "clubId": "7"]))
        XCTAssertEqual(MPParityRoute(miniProgramPath: "pages/club/workbench/index", query: ["clubId": "7"]),
                       .screen(page: "pages/club/workbench/index", query: ["clubId": "7"]))
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
        // MKT-3-2: a gift link without a token opens the shared 链接已失效 state instead of nothing.
        XCTAssertEqual(MPParityRoute(miniProgramPath: "subpackageMember/market/gift/index", query: [:]), .gift(token: ""))
        XCTAssertEqual(MPParityRoute(miniProgramPath: "subpackageMember/market/gift/index", query: ["token": ""]), .gift(token: ""))
        XCTAssertNil(MPParityRoute(miniProgramPath: "subpackageMember/market/gift/index", query: ["token": "../x"]))
        XCTAssertEqual(MPParityRoute(miniProgramPath: "subpackageMember/market/pass-order/index", query: ["orderNo": "PP20261101A"]),
                       .passOrder(orderNo: "PP20261101A"))
        XCTAssertNil(MPParityRoute(miniProgramPath: "subpackageMember/market/pass-order/index", query: ["orderNo": "../x"]))
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
        // 71ca5fbef wired the page map's existing native pages into mini-program links, so the roam tab now opens.
        guard case .miniProgramPage(let roam) = push.intent(userInfo: ["page": "pages/roam/index"]) else { return XCTFail("roam page") }
        XCTAssertEqual(roam.page, "pages/roam/index"); XCTAssertTrue(roam.query.isEmpty)
        XCTAssertNil(push.intent(userInfo: ["type": "ROAM_RECALL", "page": ""]))
    }
}
