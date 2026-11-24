import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
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

    func testClubLeaderIsNotOfferedIdentityApplications() {
        XCTAssertFalse(SettingsIdentityApplications.isOffered(toRole: "player", isClubLeader: true))
        XCTAssertTrue(SettingsIdentityApplications.isOffered(toRole: "player", isClubLeader: false))
    }

    func testDeniedAccountProfileStaysAnErrorTheUserCanRetry() {
        let fact = SettingsHomePage.sessionFact(loading: false, failed: true, role: "player", accessDenied: true)
        XCTAssertEqual(fact, .denied)
        let facts = SettingsHomePage.facts(session: fact, market: .china)
        XCTAssertEqual(facts.phase, .error)
        XCTAssertEqual(facts.copyKey, SettingsHomePage.Copy.denied)
        XCTAssertTrue(facts.retriesProfileOnTap)
        XCTAssertEqual(SettingsAccountProfileClient.deniedCopy, "当前身份不能查看账号信息")
        XCTAssertEqual(SettingsAccountProfileClient.deniedRetry, "点击刷新并确认当前账号权限")
    }

    func testSettingsProfileReadPostsMemberIDAndDecodesRole() async throws {
        final class Transport: HTTPTransport {
            var requests: [URLRequest] = []
            var status = 200
            var body = Data(#"{"code":200,"data":{"role":"player","isClubLeader":true}}"#.utf8)
            func send(_ request: URLRequest) async throws -> (Data, Int) {
                requests.append(request)
                return (body, status)
            }
        }
        let transport = Transport()
        let client = SettingsAccountProfileClient(configuration: try APIConfiguration(baseURL: URL(string: "https://fixture.example")!), transport: transport)
        let ready = await client.refresh(memberID: 7, token: "synthetic-token")
        guard case .ready(let profile) = ready else { return XCTFail("expected a profile") }
        XCTAssertEqual(profile.role, "player")
        XCTAssertTrue(profile.isClubLeader)
        XCTAssertEqual(profile.theme, "player")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.hasSuffix("api/user/info") == true)
        let form = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)
        XCTAssertTrue(form?.contains("name=\"member_id\"\r\n\r\n7") == true)
        transport.status = 403
        transport.body = Data(#"{"code":403,"msg":"denied"}"#.utf8)
        let denied = await client.refresh(memberID: 7, token: "synthetic-token")
        XCTAssertEqual(denied, .denied)
        transport.status = 200
        transport.body = Data(#"{"code":"403","msg":"denied"}"#.utf8)
        XCTAssertEqual(await client.refresh(memberID: 7, token: "synthetic-token"), .denied)
        transport.body = Data(#"{"code":200,"data":{"role":"club"}}"#.utf8)
        guard case .ready(let club) = await client.refresh(memberID: 7, token: "synthetic-token") else { return XCTFail("expected club") }
        XCTAssertTrue(club.isClubLeader)
        XCTAssertEqual(club.theme, "player")
        transport.body = Data(#"{"code":200,"data":{"role":"merchant","isClubLeader":false}}"#.utf8)
        guard case .ready(let merchant) = await client.refresh(memberID: 7, token: "synthetic-token") else { return XCTFail("expected merchant") }
        XCTAssertEqual(merchant.theme, "merchant")
        XCTAssertFalse(merchant.isClubLeader)
    }
}
