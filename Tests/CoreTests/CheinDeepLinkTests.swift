import XCTest
@testable import QuestifyCore

final class CheinDeepLinkTests: XCTestCase {
    private func parse(_ text: String) -> CheinDeepLink? { URL(string: text).flatMap(CheinDeepLink.init(url:)) }

    func testThreeSupportedLinksResolveToTheirOwningTab() {
        XCTAssertEqual(parse("chein://roam/go"), .roamGo)
        XCTAssertEqual(parse("chein://ticket/42"), .ticket(id: 42))
        XCTAssertEqual(parse("chein://club/7/join"), .clubJoin(id: 7))
        XCTAssertEqual(parse("CHEIN://Roam/go"), .roamGo)
        XCTAssertEqual(CheinDeepLink.roamGo.rootTab, .roam)
        XCTAssertEqual(CheinDeepLink.ticket(id: 1).rootTab, .mine)
        XCTAssertEqual(CheinDeepLink.clubJoin(id: 1).rootTab, .club)
        XCTAssertTrue(RootTab.playerTabs.contains(CheinDeepLink.ticket(id: 1).rootTab))
    }

    func testRejectsEverythingElse() {
        for bad in ["chein://roam", "chein://roam/go/", "chein://roam/go/extra", "chein://roam/start",
                    "chein://ticket", "chein://ticket/0", "chein://ticket/-3", "chein://ticket/007", "chein://ticket/1.5",
                    "chein://ticket/99999999999999999999", "chein://ticket/abc", "chein://club/9", "chein://club/9/leave",
                    "chein://club//join", "chein://club/0/join", "chein://roam/go?x=1", "chein://roam/go#f",
                    "chein://user@roam/go", "chein://roam:80/go", "https://roam/go", "questify://roam/go", "chein:///roam/go",
                    "chein://referral", "chein://referral/tok/extra", "chein://referral/tok?x=1", "chein://gift",
                    "chein://seat", "chein://seat/tok/aid/0", "chein://seat/tok/aid/007", "chein://landing",
                    "chein://landing?k=x&t=abc", "chein://landing?k=r", "chein://landing?k=r&t=abc&evil=1",
                    "chein://landing?k=s&t=abc&aid=0"] {
            XCTAssertNil(parse(bad), bad)
        }
        XCTAssertNil(parse("chein://referral/" + String(repeating: "a", count: 513)))
    }

    func testReferralGiftAndSeatLandingsCarryTheTokenAndDoNotClaim() {
        let referral = parse("chein://referral/invite-token")
        XCTAssertEqual(referral, .referral(token: "invite-token", activityID: nil, topicID: nil))
        XCTAssertEqual(referral?.rootTab, .home)
        XCTAssertEqual(referral?.journeyIntake?.kind, .referral)
        XCTAssertNil(referral?.journeyIntake?.activityID)
        XCTAssertEqual(parse("CHEIN://Gift/AbC"), .gift(token: "AbC", activityID: nil, topicID: nil))
        XCTAssertEqual(parse("chein://seat/seat-token/aid/9/tid/3"), .seat(token: "seat-token", activityID: 9, topicID: 3))
        XCTAssertEqual(parse("chein://seat/seat-token/tid/4"), .seat(token: "seat-token", activityID: nil, topicID: 4))
        XCTAssertEqual(parse("chein://referral/a%2Fb"), .referral(token: "a/b", activityID: nil, topicID: nil))
        let landing = parse("chein://landing?k=s&t=seat-token&aid=9&tid=")
        XCTAssertEqual(landing, .seat(token: "seat-token", activityID: 9, topicID: nil))
        XCTAssertEqual(landing?.rootTab, .home)
        let page = "/subpackageJourney/pages/landing/index?k=r&t=invite-token&tid=8"
        XCTAssertEqual(JourneyLoopSource.journeyLink(miniProgramPath: page), .referral(token: "invite-token", activityID: nil, topicID: 8))
        XCTAssertEqual(JourneyLoopSource.journeyLink(miniProgramPath: "chein://gift/present"), .gift(token: "present", activityID: nil, topicID: nil))
        XCTAssertNil(JourneyLoopSource.journeyLink(miniProgramPath: "/pages/index/index?k=r&t=abc"))
        let long = String(repeating: "b", count: 512)
        XCTAssertEqual(parse("chein://gift/" + long)?.journeyIntake?.token, long)
    }
}
