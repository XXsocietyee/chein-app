import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class SignInWithAppleFixtureTransport: HTTPTransport {
    var responses: [(String, Int)]
    var requests: [URLRequest] = []
    init(_ responses: [(String, Int)] = []) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        let next = responses.removeFirst()
        return (Data(next.0.utf8), next.1)
    }
}

final class SignInWithAppleFlowTests: XCTestCase {
    private let example = "https://cn.example.com/api-root"
    private let login = #"{"code":200,"token":"synthetic-token","data":{"id":7,"nickname":"Fixture","role":"player"}}"#
    private let account = #"{"code":200,"appUser":{"userId":7,"nickName":"Fixture","role":"player","userType":1}}"#
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ relative: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let url = repoRoot.appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("cannot read \(relative)", file: file, line: line)
            throw CocoaError(.fileReadNoSuchFile)
        }
        return text
    }

    private func flow(baseURL: String? = nil, market: RegionalMarket = .china,
                      capabilities: Set<RegionalCapability> = [.signInWithApple],
                      entitlement: [String] = SignInWithAppleEntitlement.requiredValues,
                      approved: [RegionalMarket: Set<String>]? = nil) -> SignInWithAppleFlow {
        let url = baseURL ?? example
        return SignInWithAppleFlow(
            market: market,
            baseURL: baseURL,
            approvedBaseURLs: approved ?? [.china: [url]],
            verifiedCapabilities: capabilities,
            entitlementValues: entitlement
        )
    }

    func testEntitlementAcceptsOnlyTheDefaultValue() {
        XCTAssertTrue(SignInWithAppleEntitlement(values: ["Default"]).isSatisfied)
        for values in [[], ["default"], ["DEFAULT"], ["Default", "Other"], ["Other"]] {
            XCTAssertFalse(SignInWithAppleEntitlement(values: values).isSatisfied, "\(values)")
        }
    }

    func testRepositoryEntitlementIsTheOnlySignInValue() throws {
        let url = repoRoot.appendingPathComponent("Config/Questify.entitlements")
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.xml
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
        let dict = try XCTUnwrap(plist as? [String: Any])
        let values = try XCTUnwrap(dict[SignInWithAppleEntitlement.key] as? [String])
        // The entitlements file also carries the app group and Apple Pay merchant keys;
        // only the Sign in with Apple value is pinned here.
        XCTAssertEqual(values, SignInWithAppleEntitlement.requiredValues)
        XCTAssertEqual(values.count, 1)
        XCTAssertTrue(SignInWithAppleEntitlement(values: values).isSatisfied)
    }

    func testEmptyURLStaysHiddenAndDoesNotCallTheReviewedHost() async {
        let transport = SignInWithAppleFixtureTransport([(login, 200), (account, 200)])
        let hidden = SignInWithAppleFlow(
            market: .china,
            baseURL: "  ",
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs,
            verifiedCapabilities: [.signInWithApple],
            entitlementValues: SignInWithAppleEntitlement.requiredValues
        )
        XCTAssertFalse(hidden.isShown)
        do {
            _ = try await hidden.exchange(identityToken: "synthetic.apple.token", transport: transport)
            XCTFail("empty URL must not exchange")
        } catch {
            XCTAssertEqual(error as? SignInWithAppleFlowError, .hidden)
        }
        XCTAssertTrue(transport.requests.isEmpty)
        let shipped = SignInWithAppleFlow(
            market: .china,
            baseURL: "",
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs,
            verifiedCapabilities: ReviewedMarketLaunch.chinaVerifiedCapabilities,
            entitlementValues: SignInWithAppleEntitlement.requiredValues
        )
        XCTAssertFalse(shipped.isShown)
        do {
            _ = try await shipped.exchange(identityToken: "synthetic.apple.token", transport: transport)
            XCTFail("shipped empty URL must not exchange")
        } catch {
            XCTAssertEqual(error as? SignInWithAppleFlowError, .hidden)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testReviewedChinaHostStaysHiddenUntilTheCapabilityIsNamed() async {
        let transport = SignInWithAppleFixtureTransport([(login, 200), (account, 200)])
        let withheld = SignInWithAppleFlow(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs,
            verifiedCapabilities: ReviewedMarketLaunch.chinaVerifiedCapabilities,
            entitlementValues: SignInWithAppleEntitlement.requiredValues
        )
        XCTAssertFalse(withheld.isShown)
        XCTAssertFalse(ReviewedMarketLaunch.chinaVerifiedCapabilities.contains(.signInWithApple))
        do {
            _ = try await withheld.exchange(identityToken: "synthetic.apple.token", transport: transport)
            XCTFail("phone capability must not send Apple")
        } catch {
            XCTAssertEqual(error as? SignInWithAppleFlowError, .hidden)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testMissingEntitlementOrAnotherMarketNeverSends() async {
        let transport = SignInWithAppleFixtureTransport([(login, 200)])
        let missingEntitlement = flow(baseURL: example, entitlement: [])
        let unitedStates = flow(baseURL: example, market: .unitedStates)
        let denied = SignInWithAppleFlow(
            market: .china,
            baseURL: "https://47.103.124.64/prod-api/",
            approvedBaseURLs: [.china: ["https://47.103.124.64/prod-api/"]],
            verifiedCapabilities: [.signInWithApple],
            entitlementValues: SignInWithAppleEntitlement.requiredValues
        )
        for candidate in [missingEntitlement, unitedStates, denied] {
            XCTAssertFalse(candidate.isShown)
            do {
                _ = try await candidate.exchange(identityToken: "synthetic.apple.token", transport: transport)
                XCTFail("hidden flow must not exchange")
            } catch {
                XCTAssertEqual(error as? SignInWithAppleFlowError, .hidden)
            }
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testUnapprovedHostAndOtherCapabilitiesStayHidden() async throws {
        let transport = SignInWithAppleFixtureTransport([(login, 200)])
        let unapproved = flow(baseURL: example, approved: [.china: ["https://other.example.com/api-root"]])
        let phoneOnly = flow(baseURL: example, capabilities: [.domesticChinaPhone])
        let payments = flow(baseURL: example, capabilities: [
            .usernamePassword, .physicalEventPayment, .digitalContentPayment, .merchantPayout
        ])
        for candidate in [unapproved, phoneOnly, payments] {
            XCTAssertFalse(candidate.isShown)
            do { _ = try await candidate.exchange(identityToken: "synthetic.apple.token", transport: transport) }
            catch { XCTAssertEqual(error as? SignInWithAppleFlowError, .hidden) }
        }
        XCTAssertTrue(transport.requests.isEmpty)
        let regional = try RegionalConfiguration(
            market: .china, baseURL: example, approvedBaseURLs: [.china: [example]],
            verifiedCapabilities: Set(RegionalCapability.allCases)
        )
        XCTAssertEqual(regional.availability(of: .signInWithApple), .implementationPending)
        XCTAssertFalse(regional.isFeatureShown(.usernamePassword))
        XCTAssertFalse(regional.isFeatureShown(.digitalContentPayment))
        XCTAssertFalse(regional.isFeatureShown(.merchantPayout))
    }

    func testReviewedCapabilityExchangesOnlyTheAppleRouteThenReadsTheSameAccount() async throws {
        let transport = SignInWithAppleFixtureTransport([(login, 200), (account, 200)])
        let ready = flow(baseURL: example, capabilities: [
            .signInWithApple, .usernamePassword, .merchantPayout, .digitalContentPayment
        ])
        XCTAssertTrue(ready.isShown)
        let result = try await ready.exchange(identityToken: "synthetic.apple.token", transport: transport)
        XCTAssertEqual(result.token, "synthetic-token")
        XCTAssertEqual(result.account.id, 7)
        XCTAssertEqual(result.account.role, "player")
        XCTAssertEqual(transport.requests.map { $0.url?.path }, ["/api-root/api/login/apple", "/api-root/api/userInfo"])
        XCTAssertEqual(transport.requests.map { $0.url?.host }, ["cn.example.com", "cn.example.com"])
        XCTAssertNotEqual(transport.requests.first?.url?.host, "www.chengyinhub.com")
        let body = String(data: transport.requests[0].httpBody!, encoding: .utf8)!
        XCTAssertTrue(body.contains("name=\"identityToken\"\r\n\r\nsynthetic.apple.token\r\n"))
        XCTAssertFalse(body.contains("name=\"email\""))
        XCTAssertFalse(body.contains("name=\"password\""))
        XCTAssertFalse(body.contains("name=\"username\""))
        XCTAssertNil(transport.requests[0].value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(transport.requests[1].value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        XCTAssertNil(transport.requests[1].httpBody)
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testExplicitReviewedChinaHostIsUsedOnlyWhenTheCapabilityIsPresent() async throws {
        let transport = SignInWithAppleFixtureTransport([(login, 200), (account, 200)])
        let ready = SignInWithAppleFlow(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs,
            verifiedCapabilities: [.signInWithApple],
            entitlementValues: SignInWithAppleEntitlement.requiredValues
        )
        XCTAssertTrue(ready.isShown)
        _ = try await ready.exchange(identityToken: "synthetic.apple.token", transport: transport)
        XCTAssertEqual(transport.requests.map { $0.url?.host }, ["www.chengyinhub.com", "www.chengyinhub.com"])
        XCTAssertEqual(transport.requests.map { $0.url?.path }, [
            "/prod-api/api/login/apple", "/prod-api/api/userInfo"
        ])
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testInvalidCredentialAndRoleMismatchDoNotRetryOrAccept() async {
        let transport = SignInWithAppleFixtureTransport([
            (login, 200),
            (#"{"code":200,"appUser":{"userId":8,"nickName":"Other","role":"player"}}"#, 200)
        ])
        let ready = flow(baseURL: example)
        for token in ["", " ", "bad\ntoken", "非ASCII"] {
            do { _ = try await ready.exchange(identityToken: token, transport: transport); XCTFail(token) }
            catch { XCTAssertEqual(error as? SignInWithAppleFlowError, .invalidCredential) }
        }
        XCTAssertTrue(transport.requests.isEmpty)
        do { _ = try await ready.exchange(identityToken: "synthetic.apple.token", transport: transport); XCTFail("id") }
        catch { XCTAssertEqual(error as? SignInWithAppleFlowError, .malformedResponse) }
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testLoginFailureDoesNotReadTheAccountOrRetry() async {
        let cases: [((String, Int), SignInWithAppleFlowError)] = [
            ((#"{"code":401,"msg":"secret"}"#, 200), .unauthorized),
            ((#"{"code":429,"msg":"secret"}"#, 200), .rateLimited),
            ((#"{"code":500,"msg":"secret"}"#, 200), .rejected(500)),
            (("{}", 503), .httpStatus(503)),
            (("not-json", 200), .malformedResponse),
            ((#"{"code":200,"token":"synthetic-token","data":{"id":0}}"#, 200), .malformedResponse)
        ]
        for (response, expected) in cases {
            let transport = SignInWithAppleFixtureTransport([response, (account, 200)])
            do { _ = try await flow(baseURL: example).exchange(identityToken: "synthetic.apple.token", transport: transport) }
            catch { XCTAssertEqual(error as? SignInWithAppleFlowError, expected) }
            XCTAssertEqual(transport.requests.count, 1)
            XCTAssertFalse(String(describing: expected).contains("secret"))
        }
    }

    func testAlreadyCancelledExchangeDoesNotSend() async {
        let transport = SignInWithAppleFixtureTransport([(login, 200), (account, 200)])
        let ready = flow(baseURL: example)
        let task = Task { () -> Bool in
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                _ = try await ready.exchange(identityToken: "synthetic.apple.token", transport: transport)
                return false
            } catch {
                return error is CancellationError
            }
        }
        let cancelled = await task.value
        XCTAssertTrue(cancelled)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testBuildFilesDoNotEnableTheFlowOrChangeIdentity() throws {
        let base = try source("Config/Base.xcconfig")
        XCTAssertTrue(base.contains("QUESTIFY_API_BASE_URL =\n"))
        XCTAssertTrue(base.contains("QUESTIFY_SESSION_REALM =\n"))
        XCTAssertTrue(base.contains("MARKETING_VERSION = 1.0.0\n"))
        XCTAssertTrue(base.contains("CURRENT_PROJECT_VERSION = 2\n"))
        XCTAssertTrue(base.contains("PRODUCT_BUNDLE_IDENTIFIER = invalid.example.questify.ios\n"))
        XCTAssertFalse(base.contains("chengyinhub.com"))
        XCTAssertFalse(base.contains("DEVELOPMENT_TEAM"))
        XCTAssertFalse(base.contains("9VHY8N755R"))
        XCTAssertFalse(base.contains("com.chengyinhub.chengyinApp"))
        XCTAssertFalse(base.contains("SIGN_IN_WITH_APPLE"))
        let china = try source("Config/China.Production.xcconfig")
        XCTAssertTrue(china.contains("QUESTIFY_API_BASE_URL = https:/$()/www.chengyinhub.com/prod-api/"))
        XCTAssertTrue(china.contains("QUESTIFY_SESSION_REALM = cn-prod"))
        XCTAssertFalse(china.contains("signInWithApple"))
        let flowSource = try source("Core/SignInWithAppleFlow.swift")
        XCTAssertFalse(flowSource.contains("https://"))
        XCTAssertFalse(flowSource.contains("URLSession("))
        XCTAssertFalse(flowSource.contains("appleConfigurationVerified: true"))
        XCTAssertFalse(flowSource.contains(".password"))
        XCTAssertFalse(flowSource.contains("withdrawal"))
        XCTAssertFalse(flowSource.contains("api/login\""))
        let session = try source("App/AppSession.swift")
        XCTAssertFalse(session.contains("SignInWithAppleFlow("))
    }
}
