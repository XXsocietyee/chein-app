import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// P0-5 / P1-1 (audit 11-28): owner configuration, release gate, the `api/login/wechat/app` request shape and link routing.
private final class LaunchHTTPFixture: HTTPTransport {
    var requests: [URLRequest] = []
    var replies: [(String, Int)]
    init(_ replies: [(String, Int)]) { self.replies = replies }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let reply = replies.removeFirst()
        return (Data(reply.0.utf8), reply.1)
    }
}

final class WeChatAppLaunchTests: XCTestCase {
    private let link = "https://www.chengyinhub.com/app/"

    func testOwnerValuesBuildSchemeAndUniversalLinkCallbacks() throws {
        let configuration = try XCTUnwrap(WeChatAppLaunch.configuration(appID: "wxa1b2c3d4e5", universalLink: link))
        XCTAssertEqual(configuration.appID, "wxa1b2c3d4e5")
        XCTAssertEqual(configuration.universalLink.absoluteString, link)
        XCTAssertTrue(configuration.acceptsURL(URL(string: "wxa1b2c3d4e5://oauth?code=c&state=s")!))
        XCTAssertTrue(configuration.acceptsUniversalLink(URL(string: "https://www.chengyinhub.com/app/wxa1b2c3d4e5/oauth?code=c&state=s")!))
        XCTAssertFalse(configuration.acceptsURL(URL(string: "wxother://oauth?code=c")!))
        XCTAssertFalse(configuration.acceptsUniversalLink(URL(string: "https://www.chengyinhub.com/app/club/3/join")!))
        XCTAssertFalse(configuration.acceptsUniversalLink(URL(string: "https://evil.example.com/app/wxa1b2c3d4e5/oauth?code=c")!))
    }

    func testPlaceholderEmptyAndMalformedValuesGiveNoConfiguration() {
        XCTAssertNil(WeChatAppLaunch.configuration(appID: "chein-wechat-unset", universalLink: link))
        XCTAssertNil(WeChatAppLaunch.configuration(appID: "", universalLink: link))
        XCTAssertNil(WeChatAppLaunch.configuration(appID: nil, universalLink: nil))
        XCTAssertNil(WeChatAppLaunch.configuration(appID: "wx_bad", universalLink: link))
        XCTAssertNil(WeChatAppLaunch.configuration(appID: "wxa1b2c3", universalLink: "https://www.chengyinhub.com/app"))
        XCTAssertNil(WeChatAppLaunch.configuration(appID: "wxa1b2c3", universalLink: "http://www.chengyinhub.com/app/"))
        XCTAssertNil(WeChatAppLaunch.configuration(appID: "wxa1b2c3", universalLink: ""))
    }

    func testGateOpensOnlyWhenEveryFactHolds() {
        XCTAssertTrue(WeChatAppLaunch.gate(sdkLinked: true, configured: true, legalCatalog: true,
                                           appleAlternative: true, exchangeWired: true).permitsAuthorization)
        let cases: [(Bool, Bool, Bool, Bool, Bool)] = [
            (false, true, true, true, true), (true, false, true, true, true), (true, true, false, true, true),
            (true, true, true, false, true), (true, true, true, true, false),
        ]
        for value in cases {
            XCTAssertFalse(WeChatAppLaunch.gate(sdkLinked: value.0, configured: value.1, legalCatalog: value.2,
                                                appleAlternative: value.3, exchangeWired: value.4).permitsAuthorization)
        }
        XCTAssertFalse(WeChatAppAuthGate().permitsAuthorization)
    }

    /// ApiLoginController.loginWechatApp: `@PostMapping("/login/wechat/app") loginWechatApp(String code)`, answers
    /// `{code, msg, token, data: LoginResponseVO, linkedMiniProgram}`. The account match (app_open_id → union_id →
    /// wx_open_id) is server-side from the code; the app sends only `code`.
    @MainActor func testExchangeRequestMatchesBackendFieldsAndDecodesLinkedAccount() async throws {
        let reply = #"{"code":200,"msg":"操作成功","token":"t-1","data":{"id":41,"nickname":"城瘾用户","role":"player"},"linkedMiniProgram":true}"#
        let http = LaunchHTTPFixture([(reply, 200)])
        let service = WeChatAppAuthService(configuration: try APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com/prod-api/")!),
                                           transport: http)
        let result = try await service.exchange(code: "061AbcCode")
        XCTAssertEqual(result.token, "t-1")
        XCTAssertEqual(result.account.id, 41)
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://www.chengyinhub.com/prod-api/api/login/wechat/app")
        XCTAssertNil(request.url?.query)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
        XCTAssertTrue(body.contains("Content-Disposition: form-data; name=\"code\"\r\n\r\n061AbcCode\r\n"))
        XCTAssertEqual(body.components(separatedBy: "Content-Disposition:").count, 2)
    }

    @MainActor func testBackendRefusalsAreNotSignIns() async throws {
        for reply in [#"{"code":500,"msg":"原生微信未配置"}"#, #"{"code":500,"msg":"账号已被冻结"}"#] {
            let http = LaunchHTTPFixture([(reply, 200)])
            let service = WeChatAppAuthService(configuration: try APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com/prod-api/")!),
                                               transport: http)
            do { _ = try await service.exchange(code: "061AbcCode"); XCTFail("refusal signed in") }
            catch { XCTAssertEqual(error as? WeChatAppAuthError, .rejected) }
        }
    }
}

final class AppUniversalLinkRouterTests: XCTestCase {
    private let router = AppUniversalLinkRouter(verifiedHTTPSOrigins: ["https://www.chengyinhub.com"])
    private func route(_ text: String) -> AppLinkDestination? { router.route(URL(string: text)!) }

    func testOriginComesFromThePlainDomainSetting() {
        XCTAssertEqual(AppUniversalLinkRouter.origin(domain: "www.chengyinhub.com"), "https://www.chengyinhub.com")
        XCTAssertEqual(AppUniversalLinkRouter.origin(domain: " WWW.ChengyinHub.com "), "https://www.chengyinhub.com")
        for bad in [nil, "", "localhost", "https://www.chengyinhub.com", "www.chengyinhub.com/app", ".example.com", "a..b.com"] {
            XCTAssertNil(AppUniversalLinkRouter.origin(domain: bad), String(describing: bad))
        }
    }

    func testAppPathsRouteToContentAndChainDeepLinks() {
        XCTAssertEqual(route("https://www.chengyinhub.com/app/activity/12"), .entry(.content(NativeContentTarget(kind: .activity, id: 12)!)))
        XCTAssertEqual(route("https://www.chengyinhub.com/app/topic/7"), .entry(.content(NativeContentTarget(kind: .topic, id: 7)!)))
        XCTAssertEqual(route("https://www.chengyinhub.com/app/club/3"), .entry(.content(NativeContentTarget(kind: .club, id: 3)!)))
        XCTAssertEqual(route("https://www.chengyinhub.com/app/club/3/join"), .deepLink(.clubJoin(id: 3)))
        XCTAssertEqual(route("https://www.chengyinhub.com/app/ticket/88"), .deepLink(.ticket(id: 88)))
        XCTAssertEqual(route("https://www.chengyinhub.com/app/roam/go"), .deepLink(.roamGo))
        XCTAssertEqual(route("https://www.chengyinhub.com/app/landing?k=r&t=abc&aid=5"),
                       .deepLink(.referral(token: "abc", activityID: 5, topicID: nil)))
    }

    func testAppPathsReachTheMiniProgramRouterAndHome() {
        XCTAssertEqual(route("https://www.chengyinhub.com/app/pages/topic/index/index?id=9"),
                       .entry(.content(NativeContentTarget(kind: .topic, id: 9)!)))
        XCTAssertEqual(route("https://www.chengyinhub.com/app/pages/activity/detail/index?id=4"),
                       .entry(.content(NativeContentTarget(kind: .activity, id: 4)!)))
        let home = MiniProgramPageLink(path: "pages/index/index", query: [:])!
        XCTAssertEqual(route("https://www.chengyinhub.com/app/"), .entry(.miniProgramPage(home)))
        XCTAssertEqual(route("https://www.chengyinhub.com/app"), .entry(.miniProgramPage(home)))
    }

    func testTodaysSharePathsStillRoute() {
        XCTAssertEqual(route("https://www.chengyinhub.com/pages/topic/index/index?id=21"),
                       .entry(.content(NativeContentTarget(kind: .topic, id: 21)!)))
    }

    func testRejectsForeignHostsCallbacksAndMalformedIDs() {
        XCTAssertNil(route("https://evil.example.com/app/activity/12"))
        XCTAssertNil(route("http://www.chengyinhub.com/app/activity/12"))
        XCTAssertNil(route("https://www.chengyinhub.com:8443/app/activity/12"))
        XCTAssertNil(route("https://www.chengyinhub.com/app/wxa1b2c3d4e5/oauth?code=c&state=s"))
        XCTAssertNil(route("https://www.chengyinhub.com/app/activity/012"))
        XCTAssertNil(route("https://www.chengyinhub.com/app/activity/-1"))
        XCTAssertNil(route("https://www.chengyinhub.com/app/activity/0"))
        XCTAssertNil(route("https://www.chengyinhub.com/app/club/3/join/extra"))
        XCTAssertNil(route("https://www.chengyinhub.com/app//activity/12"))
        XCTAssertNil(route("https://www.chengyinhub.com/app/../merchant/team"))
        XCTAssertNil(route("https://www.chengyinhub.com/app/activity/12#x"))
        XCTAssertNil(AppUniversalLinkRouter(verifiedHTTPSOrigins: []).route(URL(string: "https://www.chengyinhub.com/app/activity/12")!))
    }

    func testCheinShortContentForms() {
        XCTAssertEqual(AppUniversalLinkRouter.cheinContent(URL(string: "chein://activity/12")!),
                       .entry(.content(NativeContentTarget(kind: .activity, id: 12)!)))
        XCTAssertEqual(AppUniversalLinkRouter.cheinContent(URL(string: "chein://topic/7")!),
                       .entry(.content(NativeContentTarget(kind: .topic, id: 7)!)))
        XCTAssertNil(AppUniversalLinkRouter.cheinContent(URL(string: "chein://activity/abc")!))
        XCTAssertNil(AppUniversalLinkRouter.cheinContent(URL(string: "chein://activity/12?x=1")!))
        XCTAssertNil(AppUniversalLinkRouter.cheinContent(URL(string: "https://www.chengyinhub.com/activity/12")!))
        // The existing chein grammar keeps owning club join and tickets.
        XCTAssertEqual(CheinDeepLink(url: URL(string: "chein://club/3/join")!), .clubJoin(id: 3))
        XCTAssertEqual(CheinDeepLink(url: URL(string: "chein://ticket/88")!), .ticket(id: 88))
    }
}
