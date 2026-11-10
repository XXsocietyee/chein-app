import XCTest
@testable import QuestifyCore

final class SettingsIdentityApplicationsTests: XCTestCase {
    private let dash = SettingsHomePage.unknownDisplay

    func testOnlySignedInPlayerViewIsOfferedApplications() {
        XCTAssertTrue(SettingsIdentityApplications.isOffered(toRole: "player"))
        XCTAssertFalse(SettingsIdentityApplications.isOffered(toRole: "merchant"))
        XCTAssertFalse(SettingsIdentityApplications.isOffered(toRole: "club"))
        XCTAssertFalse(SettingsIdentityApplications.isOffered(toRole: nil))
    }

    func testUnknownCountIsAnEmDashAndALiteralZeroStaysZero() {
        XCTAssertEqual(dash, "—")
        XCTAssertEqual(SettingsHomePage.countText(nil), dash)
        XCTAssertEqual(SettingsHomePage.countText(0), "0")
        XCTAssertEqual(SettingsHomePage.countText(2), "2")
        XCTAssertEqual(SettingsHomePage.countText(numericString: "0"), dash)
        XCTAssertEqual(SettingsHomePage.countText(numericString: ""), dash)
        XCTAssertNotEqual(SettingsHomePage.countText(nil), "0")
        XCTAssertNotEqual(SettingsHomePage.countText(numericString: "0"), "0")
        XCTAssertFalse(SettingsHomePage.routeMarkedLive)
    }

    func testLoadingAndFailureHideAccountActionsWithoutInventingZero() {
        let loading = SettingsHomePage.facts(session: .loading, market: .china)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.marketText, "CN")
        XCTAssertEqual(loading.roleText, dash)
        XCTAssertFalse(loading.offersIdentityApplications)
        XCTAssertFalse(loading.showsSignOut)
        XCTAssertEqual(loading.copyKey, SettingsHomePage.Copy.loading)
        XCTAssertEqual(loading.accessibilityIdentifier, "settings.home.loading")

        let failed = SettingsHomePage.facts(session: .failed, market: nil)
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.marketText, dash)
        XCTAssertNotEqual(failed.marketText, "0")
        XCTAssertFalse(failed.showsSignOut)
        XCTAssertEqual(failed.copyKey, SettingsHomePage.Copy.error)

        XCTAssertEqual(SettingsHomePage.sessionFact(loading: true, failed: true, role: "player"), .loading)
        XCTAssertEqual(SettingsHomePage.sessionFact(loading: false, failed: true, role: "player"), .failed)
    }

    func testSignedOutIsEmptyAndKeepsAKnownMarket() {
        let facts = SettingsHomePage.facts(session: .signedOut, market: .unitedStates)
        XCTAssertEqual(facts.phase, .empty)
        XCTAssertEqual(facts.marketText, "US")
        XCTAssertEqual(facts.roleText, dash)
        XCTAssertFalse(facts.offersIdentityApplications)
        XCTAssertFalse(facts.showsSignOut)
        XCTAssertEqual(facts.copyKey, SettingsHomePage.Copy.signedOut)
        XCTAssertEqual(facts.accessibilityIdentifier, "settingsNative.profileSignedOut")
        XCTAssertEqual(SettingsHomePage.sessionFact(loading: false, failed: false, role: nil), .signedOut)
    }

    func testKnownRolesAreReadyAndUnknownRolesStayAnEmDash() {
        let player = SettingsHomePage.facts(session: .signedIn(role: "player"), market: .china)
        XCTAssertEqual(player.phase, .ready)
        XCTAssertEqual(player.marketText, "CN")
        XCTAssertEqual(player.roleText, "player")
        XCTAssertTrue(player.offersIdentityApplications)
        XCTAssertTrue(player.showsSignOut)
        XCTAssertEqual(player.copyKey, SettingsHomePage.Copy.title)

        let merchant = SettingsHomePage.facts(session: .signedIn(role: " merchant "), market: .unitedStates)
        XCTAssertEqual(merchant.phase, .ready)
        XCTAssertFalse(merchant.offersIdentityApplications)
        XCTAssertTrue(merchant.showsSignOut)
        XCTAssertEqual(merchant.roleText, "merchant")

        let club = SettingsHomePage.facts(session: .signedIn(role: "club"), market: .china)
        XCTAssertEqual(club.phase, .ready)
        XCTAssertFalse(club.offersIdentityApplications)

        for role in ["UNKNOWN", "0", "2", "  ", "Player"] {
            let facts = SettingsHomePage.facts(session: .signedIn(role: role), market: .china)
            XCTAssertEqual(facts.phase, .unknown, role)
            XCTAssertEqual(facts.roleText, dash, role)
            XCTAssertNotEqual(facts.roleText, "0", role)
            XCTAssertFalse(facts.offersIdentityApplications, role)
            XCTAssertTrue(facts.showsSignOut, role)
            XCTAssertEqual(facts.copyKey, SettingsHomePage.Copy.unknown, role)
        }
    }

    func testNilMarketOnAKnownRoleIsUnknownNotZero() {
        let facts = SettingsHomePage.facts(session: .signedIn(role: "player"), market: nil)
        XCTAssertEqual(facts.phase, .unknown)
        XCTAssertEqual(facts.marketText, dash)
        XCTAssertNotEqual(facts.marketText, "0")
        XCTAssertEqual(facts.roleText, "player")
        XCTAssertTrue(facts.offersIdentityApplications)
        XCTAssertTrue(facts.showsSignOut)
        XCTAssertEqual(SettingsHomePage.marketText(nil), dash)
        XCTAssertEqual(SettingsHomePage.marketText(.china), "CN")
    }
}
