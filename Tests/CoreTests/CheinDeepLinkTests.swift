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
                    "chein://user@roam/go", "chein://roam:80/go", "https://roam/go", "questify://roam/go", "chein:///roam/go"] {
            XCTAssertNil(parse(bad), bad)
        }
    }
}
