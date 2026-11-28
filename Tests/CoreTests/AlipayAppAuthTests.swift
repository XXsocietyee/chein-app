import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class AlipayHTTPFixture: HTTPTransport {
    var requests: [URLRequest] = []
    var replies: [(String, Int)]
    init(_ replies: [(String, Int)]) { self.replies = replies }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let reply = replies.removeFirst()
        return (Data(reply.0.utf8), reply.1)
    }
}

@MainActor
private final class AlipayDriverStub: AlipaySDKAuthDriving {
    var isLinked = true
    var isInstalled = true
    var authInfos: [String] = []
    var schemes: [String] = []
    var handled: [URL] = []
    var detached = 0
    var pending: ((AlipaySDKAuthResponse) -> Void)?
    var reply: AlipaySDKAuthResponse?
    func authorize(_ authInfo: String, scheme: String, response: @escaping (AlipaySDKAuthResponse) -> Void) {
        authInfos.append(authInfo); schemes.append(scheme); pending = response
    }
    func handle(_ url: URL) {
        handled.append(url)
        if let reply, let pending { pending(reply) }
    }
    func detach() { detached += 1; pending = nil }
}

@MainActor
final class AlipayAppAuthTests: XCTestCase {
    private let context = WeChatAppAuthContext(session: AuthChannelSessionSnapshot(epoch: 1, accountID: nil, isBusy: false),
                                               market: .china, namespace: "fixture")
    private func open() -> AlipayAppAuthGate {
        var gate = AlipayAppAuthGate()
        gate.sdkVerified = true; gate.providerVerified = true; gate.legalVerified = true; gate.liveExchangeApproved = true
        return gate
    }
    private func service(_ http: AlipayHTTPFixture) throws -> AlipayAppAuthService {
        try AlipayAppAuthService(configuration: APIConfiguration(baseURL: URL(string: "https://api.example.com/prefix")!), transport: http)
    }

    func testDefaultsAreGatedOffSoTheRowIsNotOffered() {
        XCTAssertFalse(AlipayAppAuthGate().permitsAuthorization)
        let ctx = context
        let coordinator = AlipayAppAuthCoordinator(context: { ctx }, commit: { _, _ in true })
        XCTAssertFalse(coordinator.isOffered)
        XCTAssertFalse(coordinator.canStart)
        coordinator.start()
        XCTAssertEqual(coordinator.issue, .notConfigured)
        XCTAssertEqual(coordinator.phase, .idle)
    }

    func testAuthResultParsesOnlySuccessfulCodes() {
        XCTAssertEqual(AlipaySDKAuthResponse(resultStatus: "9000", result: "success=true&auth_code=A1b2&result_code=200&user_id=2088").authCode, "A1b2")
        XCTAssertEqual(AlipaySDKAuthResponse(resultStatus: "9000", result: #"success="true"&auth_code="Q9"&result_code="200""#).authCode, "Q9")
        XCTAssertNil(AlipaySDKAuthResponse(resultStatus: "9000", result: "auth_code=A1b2&result_code=1005").authCode)
        XCTAssertNil(AlipaySDKAuthResponse(resultStatus: "6001", result: "auth_code=A1b2&result_code=200").authCode)
        XCTAssertNil(AlipaySDKAuthResponse(resultStatus: "9000", result: nil).authCode)
    }

    func testConfigurationAcceptsOnlyTheOwnSafepayCallback() throws {
        XCTAssertThrowsError(try AlipaySDKConfiguration(appScheme: "Bad Scheme"))
        let configuration = try AlipaySDKConfiguration(appScheme: "chein-alipay")
        XCTAssertTrue(configuration.acceptsURL(URL(string: "chein-alipay://safepay/?resultStatus=9000")!))
        XCTAssertFalse(configuration.acceptsURL(URL(string: "other://safepay/")!))
        XCTAssertFalse(configuration.acceptsURL(URL(string: "chein-alipay://open/club")!))
    }

    func testAdapterMapsCallbackAndIgnoresURLsWithoutAPendingAttempt() throws {
        let driver = AlipayDriverStub()
        let adapter = AlipayAuthAdapter(driver: driver, configuration: try AlipaySDKConfiguration(appScheme: "chein-alipay"))
        let url = URL(string: "chein-alipay://safepay/?x=1")!
        XCTAssertFalse(adapter.acceptsURL(url))
        var outcomes: [AlipayAppAuthorizationOutcome] = []
        adapter.start(authInfo: "apiname=com.alipay.account.auth&sign=x", attemptID: UUID()) { outcomes.append($0) }
        XCTAssertEqual(driver.schemes, ["chein-alipay"])
        driver.reply = AlipaySDKAuthResponse(resultStatus: "9000", result: "auth_code=CODE7&result_code=200")
        XCTAssertTrue(adapter.acceptsURL(url))
        XCTAssertEqual(outcomes, [.authCode("CODE7")])
        XCTAssertFalse(adapter.acceptsURL(url))
        adapter.start(authInfo: "info", attemptID: UUID()) { outcomes.append($0) }
        driver.pending?(AlipaySDKAuthResponse(resultStatus: "6001", result: nil))
        XCTAssertEqual(outcomes.last, .cancelled)
        driver.isInstalled = false
        adapter.start(authInfo: "info", attemptID: UUID()) { outcomes.append($0) }
        XCTAssertEqual(outcomes.last, .unavailable)
    }

    func testSignInFetchesAuthInfoExchangesCodeAndCommits() async throws {
        let http = AlipayHTTPFixture([
            (#"{"code":200,"data":"apiname=com.alipay.account.auth&sign=s"}"#, 200),
            (#"{"code":200,"token":"fixture-token","data":{"id":7}}"#, 200),
            (#"{"code":200,"appUser":{"id":7}}"#, 200)
        ])
        let driver = AlipayDriverStub()
        let adapter = AlipayAuthAdapter(driver: driver, configuration: try AlipaySDKConfiguration(appScheme: "chein-alipay"))
        var committed: [Int] = []
        let gate = open(), ctx = context
        let coordinator = AlipayAppAuthCoordinator(adapter: adapter, service: try service(http), gate: { gate }, context: { ctx },
                                                   commit: { result, _ in committed.append(result.account.id); return true })
        XCTAssertTrue(coordinator.isOffered)
        coordinator.start()
        XCTAssertEqual(coordinator.phase, .preparing)
        for _ in 0..<50 where driver.pending == nil { await Task.yield() }
        XCTAssertEqual(driver.authInfos, ["apiname=com.alipay.account.auth&sign=s"])
        XCTAssertEqual(coordinator.phase, .authorizing)
        driver.pending?(AlipaySDKAuthResponse(resultStatus: "9000", result: "auth_code=CODE7&result_code=200"))
        for _ in 0..<50 where coordinator.phase != .signedIn { await Task.yield() }
        XCTAssertEqual(coordinator.phase, .signedIn)
        XCTAssertEqual(committed, [7])
        XCTAssertEqual(http.requests.first?.httpMethod, "GET")
        XCTAssertEqual(http.requests.first?.url?.path, "/prefix/api/login/alipay/auth-info")
        XCTAssertEqual(http.requests[1].url?.path, "/prefix/api/login/alipay")
        let body = String(data: http.requests[1].httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("name=\"auth_code\"\r\n\r\nCODE7"))
    }

    func testCancelledAuthorizationLeavesNoIssue() async throws {
        let http = AlipayHTTPFixture([(#"{"code":200,"data":{"authInfo":"info"}}"#, 200)])
        let driver = AlipayDriverStub()
        let adapter = AlipayAuthAdapter(driver: driver, configuration: try AlipaySDKConfiguration(appScheme: "chein-alipay"))
        let gate = open(), ctx = context
        let coordinator = AlipayAppAuthCoordinator(adapter: adapter, service: try service(http), gate: { gate }, context: { ctx },
                                                   commit: { _, _ in XCTFail("no commit"); return false })
        coordinator.start()
        for _ in 0..<50 where driver.pending == nil { await Task.yield() }
        XCTAssertEqual(driver.authInfos, ["info"])
        driver.pending?(AlipaySDKAuthResponse(resultStatus: "6001", result: nil))
        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertNil(coordinator.issue)
    }
}
