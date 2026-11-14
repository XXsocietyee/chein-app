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
}
