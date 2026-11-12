import Foundation
import XCTest
@testable import QuestifyCore

final class UniversalLinkParserTests: XCTestCase {
    private let fixture = "https://example.test"
    private let scene = "abcdef0123456789abcdef0123456789"

    func testDefaultConfigurationClaimsNoDomainAndAcceptsNothing() throws {
        XCTAssertTrue(UniversalLinkConfiguration.verifiedHTTPSOrigins.isEmpty)
        XCTAssertTrue(UniversalLinkConfiguration.associatedDomainEntitlements.isEmpty)
        let url = try url("\(fixture)/badge?name=Synthetic")
        XCTAssertNil(UniversalLinkParser().parse(url))
        XCTAssertNil(UniversalLinkParser(verifiedHTTPSOrigins: []).parse(url))
        XCTAssertNil(UniversalLinkParser(verifiedHTTPSOrigins: UniversalLinkConfiguration.verifiedHTTPSOrigins).parse(url))
    }

    func testFixtureHostAgreesWithTypedRouterOnKnownRoutes() throws {
        let origins: Set<String> = [fixture]
        let hardened = UniversalLinkParser(verifiedHTTPSOrigins: origins)
        let typed = NativeEntryLinkPolicy(verifiedHTTPSOrigins: origins)
        let accepted = [
            "\(fixture)/door?scene=\(scene)&inviter=42",
            "\(fixture)/door?scene=\(scene)ab",
            "\(fixture)/merchant/team?invite=synthetic-invite-token",
            "\(fixture)/pages/activity/detail/index?id=42",
            "\(fixture)/pages/club/detail/index?id=42",
            "\(fixture)/pages/topic/index/index?id=42",
            "\(fixture)/pages/templatedetail/templatedetail?id=42",
            "\(fixture)/pages/square/detail/index?id=42",
            "\(fixture)/subpackageRoam/poi-detail/index?id=42",
            "\(fixture)/subpackageRoam/session/index?id=42",
            "\(fixture)/merchant/public-home/42",
            "\(fixture)/merchant/public-home/member/42",
            "\(fixture)/team/join?code=SYNTHETIC",
            "\(fixture)/badge?name=Synthetic",
            "https://EXAMPLE.TEST/pages/activity/detail/index?id=42",
            "\(fixture)/catalog",
            "\(fixture)/catalog/list?city_code=SHA",
            "\(fixture)/catalog/filters?city_code=SHA",
            "\(fixture)/catalog/info?id=9",
        ]
        for raw in accepted {
            let parsed = try url(raw)
            let intent = hardened.parse(parsed)
            XCTAssertEqual(intent, typed.parse(parsed), raw)
            XCTAssertNotNil(intent, raw)
        }
        let rejected = [
            "http://example.test/team/join?code=SYNTHETIC",
            "custom://example.test/team/join?code=SYNTHETIC",
            "https://user@example.test/team/join?code=SYNTHETIC",
            "https://example.test:443/team/join?code=SYNTHETIC",
            "https://example.test/team/join?code=SYNTHETIC#x",
            "https://example.test.evil.test/badge?name=Synthetic",
            "https://notexample.test/badge?name=Synthetic",
            "https://evil.test/badge?name=Synthetic",
            "https://example.test/merchant/%74eam?invite=synthetic-invite-token",
            "https://example.test//merchant/public-home/42",
            "https://example.test/merchant/public-home/42/",
            "https://example.test/merchant/public-home/42?memberId=1",
            "https://example.test/merchant/team?invite=synthetic-token",
            "https://example.test/no-such-route",
            "https://example.test/pages/activity/detail/index?id=0",
            "https://example.test/catalog/map",
            "https://example.test/catalog/ids?ids=9",
            "https://example.test/catalog/city/list",
            "https://example.test/catalog/info",
            "https://example.test/catalog/info?id=9&pay=1",
            "https://example.test/catalog?quote=1",
        ]
        for raw in rejected {
            let parsed = try url(raw)
            XCTAssertNil(hardened.parse(parsed), raw)
            XCTAssertEqual(hardened.parse(parsed), typed.parse(parsed), raw)
        }
    }

    func testTrailingSlashOriginIsNormalizedWithoutOpeningTheTypedRouter() throws {
        let rawOrigin = "https://Example.Test/"
        let parsed = try url("\(fixture)/badge?name=Synthetic")
        XCTAssertNil(NativeEntryLinkPolicy(verifiedHTTPSOrigins: [rawOrigin]).parse(parsed))
        guard case .badge = UniversalLinkParser(verifiedHTTPSOrigins: [rawOrigin]).parse(parsed) else {
            return XCTFail("normalized fixture origin should reach the typed badge route")
        }
    }

    func testMalformedOriginsCannotReviveAHost() throws {
        let parser = UniversalLinkParser(verifiedHTTPSOrigins: [
            "https://example.test/phish",
            "https://user@example.test/",
            "https://example.test:443/",
            "http://example.test/",
            "https://example.test/?q=1",
            "https://example.test/#x",
            "https://127.0.0.1/",
            "https://localhost/",
            "not a url",
            "",
        ])
        XCTAssertNil(parser.parse(try url("\(fixture)/badge?name=Synthetic")))
    }

    func testLiteralLocalAndSingleLabelHostsStayClosedEvenWhenListed() throws {
        let required = ["127.0.0.1", "10.1.2.3", "localhost", "printer.local", "intranet"]
        var checked = 0
        let names = required + [
            "ex_ample.test",
            "not.invalid",
            "a.localhost",
            ["47", "103", "124", "64"].joined(separator: "."),
        ]
        for name in names {
            let raw = "https://\(name)/pages/activity/detail/index?id=42"
            guard let parsed = URL(string: raw),
                  let host = URLComponents(url: parsed, resolvingAgainstBaseURL: false)?.host?.lowercased(),
                  host == name else {
                XCTAssertFalse(required.contains(name), "required host did not survive URL parsing: \(name)")
                continue
            }
            let listed: Set<String> = ["https://\(name)"]
            XCTAssertNotNil(NativeEntryLinkPolicy(verifiedHTTPSOrigins: listed).parse(parsed), name)
            XCTAssertNil(UniversalLinkParser(verifiedHTTPSOrigins: listed).parse(parsed), name)
            if required.contains(name) { checked += 1 }
        }
        XCTAssertEqual(checked, required.count)
    }

    func testOptionalAddressFormsStayClosedWhenTheySurviveParsing() {
        let legacy = ["47", "103", "124", "64"].joined(separator: ".")
        let raws = [
            "https://[::1]/pages/activity/detail/index?id=42",
            "https://example.test./pages/activity/detail/index?id=42",
            "https://\(legacy)/badge?name=Synthetic",
            "https://example.test/pages/activity/detail/index?id=42\\x",
        ]
        for raw in raws {
            guard let parsed = URL(string: raw) else { continue }
            let components = URLComponents(url: parsed, resolvingAgainstBaseURL: false)
            let host = components?.host?.lowercased()
            let stillHostile = parsed.absoluteString.contains("\\")
                || host?.contains(":") == true
                || host?.hasSuffix(".") == true
                || host == legacy
            guard stillHostile, let host else { continue }
            XCTAssertNil(UniversalLinkParser(verifiedHTTPSOrigins: ["https://\(host)", fixture]).parse(parsed), raw)
        }
    }

    func testOverlongAndTraversalNeverReachARoute() throws {
        let parser = UniversalLinkParser(verifiedHTTPSOrigins: [fixture])
        let long = "\(fixture)/pages/activity/detail/index?id=42&pad=" + String(repeating: "a", count: 9000)
        let parsed = try url(long)
        XCTAssertGreaterThan(parsed.absoluteString.utf8.count, 8192)
        XCTAssertNil(parser.parse(parsed))
        for raw in [
            "\(fixture)/merchant/team/../public-home/42",
            "\(fixture)/%2e%2e/merchant/public-home/42",
            "\(fixture)/merchant/public-home/%34%32",
            "\(fixture)/./badge?name=Synthetic",
        ] {
            XCTAssertNil(parser.parse(try url(raw)), raw)
        }
    }

    private func url(_ raw: String, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        try XCTUnwrap(URL(string: raw), raw, file: file, line: line)
    }
}
