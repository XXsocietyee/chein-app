import XCTest
@testable import Questify

@MainActor final class RootPresentationCoordinatorTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testLinkWaitsForTabsThenReplaysOnce() {
        let c = RootPresentationCoordinator()
        c.enqueue(.roamGo, now: t0)
        XCTAssertNil(c.takeLink(now: t0, tabsVisible: false, signedIn: false))
        XCTAssertEqual(c.takeLink(now: t0.addingTimeInterval(10), tabsVisible: true, signedIn: false), .roamGo)
        XCTAssertNil(c.takeLink(now: t0.addingTimeInterval(11), tabsVisible: true, signedIn: false))
    }

    func testLastLinkWins() {
        let c = RootPresentationCoordinator()
        c.enqueue(.ticket(id: 1), now: t0)
        c.enqueue(.clubJoin(id: 9), now: t0.addingTimeInterval(1))
        XCTAssertEqual(c.takeLink(now: t0.addingTimeInterval(2), tabsVisible: true, signedIn: true), .clubJoin(id: 9))
    }

    func testTicketWaitsForSignIn() {
        let c = RootPresentationCoordinator()
        c.enqueue(.ticket(id: 5), now: t0)
        XCTAssertNil(c.takeLink(now: t0, tabsVisible: true, signedIn: false))
        XCTAssertEqual(c.takeLink(now: t0.addingTimeInterval(60), tabsVisible: true, signedIn: true), .ticket(id: 5))
    }

    func testOpenPassportSheetHoldsTheLinkUntilItCloses() {
        let c = RootPresentationCoordinator()
        c.setSheet("passport", open: true)
        c.enqueue(.ticket(id: 5), now: t0)
        XCTAssertNil(c.takeLink(now: t0, tabsVisible: true, signedIn: true))
        c.setSheet("passport", open: false)
        XCTAssertEqual(c.takeLink(now: t0, tabsVisible: true, signedIn: true), .ticket(id: 5))
    }

    func testLinkExpiresAfterFiveMinutes() {
        let c = RootPresentationCoordinator()
        c.enqueue(.roamGo, now: t0)
        XCTAssertNil(c.takeLink(now: t0.addingTimeInterval(RootPresentationCoordinator.linkLifetime + 1), tabsVisible: true, signedIn: true))
        XCTAssertNil(c.pendingLink)
    }

    func testConsentGoesFirst() {
        let c = RootPresentationCoordinator()
        c.consentActive = true
        XCTAssertFalse(c.allowsSecondaryRootSheet)
        c.enqueue(.roamGo, now: t0)
        XCTAssertNil(c.takeLink(now: t0, tabsVisible: true, signedIn: true))
        c.consentActive = false
        XCTAssertTrue(c.allowsSecondaryRootSheet)
        XCTAssertEqual(c.takeLink(now: t0, tabsVisible: true, signedIn: true), .roamGo)
    }

    func testSeatLandingDoesNotWaitForSignInAndRecordsIntake() throws {
        let c = RootPresentationCoordinator()
        let link = CheinDeepLink.seat(token: "seat-token", activityID: 4, topicID: nil)
        c.enqueue(link, now: t0)
        XCTAssertEqual(c.takeLink(now: t0, tabsVisible: true, signedIn: false), link)
        c.noteJourney(try XCTUnwrap(link.journeyIntake))
        XCTAssertEqual(c.pendingJourney?.kind, .seat)
        XCTAssertEqual(c.pendingJourney?.token, "seat-token")
        XCTAssertEqual(c.pendingJourney?.activityID, 4)
        XCTAssertNil(c.pendingLink)
        c.clear()
        XCTAssertNil(c.pendingJourney)
    }
}
