import XCTest
@testable import QuestifyCore

final class PublicContentShareLinkTests: XCTestCase {
    private func post(id: String?, audience: String?, status: String?) -> SquareL5ShareCard.Post {
        .init(id: id, audience: audience, status: status, contents: "城墙", pics: nil, picList: nil)
    }

    func testPublicSquarePostUsesTheParsedDetailPathOnTheExistingChinaHost() throws {
        let url = try XCTUnwrap(PublicContentShareLink.squarePost(post(id: "9", audience: "PUBLIC", status: "1")))
        XCTAssertEqual(url.absoluteString, "https://www.chengyinhub.com/pages/square/detail/index?id=9")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.map(\.name), ["id"])
        XCTAssertEqual(items.first?.value, "9")
        XCTAssertNil(url.fragment)
        XCTAssertFalse(url.absoluteString.contains("referral"))
        guard case .content(let target) = UniversalLinkParser(verifiedHTTPSOrigins: [PublicContentShareLink.httpsOrigin]).parse(url) else {
            return XCTFail("parser already types this path")
        }
        XCTAssertEqual(target.kind, .post)
        XCTAssertEqual(target.id, 9)
        XCTAssertNil(UniversalLinkParser().parse(url))
        XCTAssertNil(CheinDeepLink(url: url))
        XCTAssertTrue(UniversalLinkConfiguration.verifiedHTTPSOrigins.isEmpty)
        XCTAssertTrue(UniversalLinkConfiguration.associatedDomainEntitlements.isEmpty)
    }

    func testAbsentAudienceAndStatusStayShareableAndPrivateOrUnpublishedDoNot() {
        XCTAssertEqual(
            PublicContentShareLink.squarePost(post(id: "9", audience: nil, status: nil))?.absoluteString,
            "https://www.chengyinhub.com/pages/square/detail/index?id=9")
        XCTAssertEqual(
            PublicContentShareLink.squarePost(post(id: "9", audience: "public", status: "1"))?.absoluteString,
            "https://www.chengyinhub.com/pages/square/detail/index?id=9")
        for hidden in [
            post(id: "9", audience: "PRIVATE", status: "1"),
            post(id: "9", audience: "FOLLOWERS", status: nil),
            post(id: "9", audience: "PUBLIC", status: "0"),
            post(id: "9", audience: "PUBLIC", status: "DRAFT"),
            post(id: nil, audience: "PUBLIC", status: "1"),
            post(id: "", audience: nil, status: nil),
            post(id: "0", audience: nil, status: nil),
            post(id: "007", audience: "PUBLIC", status: "1"),
            post(id: "9/1", audience: "PUBLIC", status: "1"),
        ] {
            XCTAssertNil(PublicContentShareLink.squarePost(hidden), "\(hidden)")
        }
        XCTAssertNil(PublicContentShareLink.squarePost(nil))
    }

    func testDecodedSquarePostMapsPublishedLifecycleOntoTheShareableCard() throws {
        let shown = try JSONDecoder().decode(SquarePost.self, from: Data(#"{"id":9,"memberId":1,"audience":"PUBLIC","lifecycle":"PUBLISHED","contents":"hello"}"#.utf8))
        XCTAssertEqual(
            PublicContentShareLink.squarePost(PublicContentShareLink.l5Post(from: shown))?.absoluteString,
            "https://www.chengyinhub.com/pages/square/detail/index?id=9")
        let numeric = try JSONDecoder().decode(SquarePost.self, from: Data(#"{"id":4,"memberId":1,"lifecycle":"1"}"#.utf8))
        XCTAssertEqual(
            PublicContentShareLink.squarePost(PublicContentShareLink.l5Post(from: numeric))?.absoluteString,
            "https://www.chengyinhub.com/pages/square/detail/index?id=4")
        let hidden = try JSONDecoder().decode(SquarePost.self, from: Data(#"{"id":9,"memberId":1,"audience":"PRIVATE","lifecycle":"PUBLISHED"}"#.utf8))
        XCTAssertNil(PublicContentShareLink.squarePost(PublicContentShareLink.l5Post(from: hidden)))
        let draft = try JSONDecoder().decode(SquarePost.self, from: Data(#"{"id":9,"memberId":1,"lifecycle":"DRAFT"}"#.utf8))
        XCTAssertNil(PublicContentShareLink.squarePost(PublicContentShareLink.l5Post(from: draft)))
    }

    func testDiscoveryTemplateUsesTheParsedTemplatePath() throws {
        let url = try XCTUnwrap(PublicContentShareLink.discoveryTemplate(id: 42))
        XCTAssertEqual(url.absoluteString, "https://www.chengyinhub.com/pages/templatedetail/templatedetail?id=42")
        guard case .content(let target) = UniversalLinkParser(verifiedHTTPSOrigins: [PublicContentShareLink.httpsOrigin]).parse(url) else {
            return XCTFail("parser already types this path")
        }
        XCTAssertEqual(target.kind, .template)
        XCTAssertEqual(target.id, 42)
        XCTAssertNil(PublicContentShareLink.discoveryTemplate(id: 0))
        XCTAssertNil(PublicContentShareLink.discoveryTemplate(id: -3))
    }

    func testTopicTemplatePathIsNotParsedSoOnlyTheMiniProgramPathIsCopied() throws {
        XCTAssertNil(PublicContentShareLink.topicTemplate(id: 15))
        let raw = "https://www.chengyinhub.com/pages/templatedetail/topic-detail/index?id=15"
        let url = try XCTUnwrap(URL(string: raw))
        XCTAssertNil(CheinDeepLink(url: url))
        // PC-A-8-1 (parity r1): a verified universal link to the MP template detail opens that template.
        XCTAssertEqual(UniversalLinkParser(verifiedHTTPSOrigins: ["https://www.chengyinhub.com"]).parse(url),
                       .miniProgramPage(try XCTUnwrap(MiniProgramPageLink(path: "pages/templatedetail/topic-detail/index", query: ["id": "15"]))))
        XCTAssertNil(UniversalLinkParser().parse(url))
        XCTAssertEqual(PublicContentShareLink.topicTemplateCopyText(id: 15), "/pages/templatedetail/topic-detail/index?id=15")
        let text = try XCTUnwrap(PublicContentShareLink.topicTemplateCopyText(id: 15))
        XCTAssertFalse(text.contains("http"))
        XCTAssertFalse(text.contains("chengyinhub"))
        XCTAssertFalse(text.contains("referral"))
        XCTAssertNil(PublicContentShareLink.topicTemplateCopyText(id: 0))
        XCTAssertNil(PublicContentShareLink.topicTemplate(id: 0))
    }

    func testMemberInviteSharePathUsesTheIndexQueryAndNoInventedHost() throws {
        let link = try XCTUnwrap(MemberInviteShareLink(userID: "42"))
        XCTAssertEqual(link.path, "/pages/index/index?inviter=42")
        XCTAssertNil(link.httpsURL())
        XCTAssertNil(MemberInviteShareLink(userID: "0"))
        XCTAssertNil(MemberInviteShareLink(userID: ""))
        let hosted = link.httpsURL(verifiedOrigins: ["https://example.test"])
        XCTAssertEqual(hosted?.absoluteString, "https://example.test/pages/index/index?inviter=42")
        XCTAssertNil(link.httpsURL(verifiedOrigins: ["https://example.test", "https://other.test"]))
    }
}
