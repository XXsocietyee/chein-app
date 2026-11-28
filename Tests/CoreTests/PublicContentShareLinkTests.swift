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

    /// Function audit 11-28 row "分享主题模板": the parser already reads this MP page back (PC-A-8-1), so the share is
    /// the https link (MP topic-detail index.js:317), not the bare path text.
    func testTopicTemplateSharesTheParsedUniversalLink() throws {
        let url = try XCTUnwrap(PublicContentShareLink.topicTemplate(id: 15))
        XCTAssertEqual(url.absoluteString, "https://www.chengyinhub.com/pages/templatedetail/topic-detail/index?id=15")
        XCTAssertNil(CheinDeepLink(url: url))
        XCTAssertEqual(UniversalLinkParser(verifiedHTTPSOrigins: ["https://www.chengyinhub.com"]).parse(url),
                       .miniProgramPage(try XCTUnwrap(MiniProgramPageLink(path: "pages/templatedetail/topic-detail/index", query: ["id": "15"]))))
        XCTAssertNil(UniversalLinkParser().parse(url))
        XCTAssertNil(PublicContentShareLink.topicTemplateCopyText(id: 15))
        XCTAssertNil(PublicContentShareLink.topicTemplateCopyText(id: 0))
        XCTAssertNil(PublicContentShareLink.topicTemplate(id: 0))
        XCTAssertNil(PublicContentShareLink.topicTemplate(id: -2))
    }

    /// MP infomationdetail.js:161 share path: the guide article shares its https link once the parser reads it back.
    func testInformationSharesTheParsedUniversalLink() throws {
        let url = try XCTUnwrap(PublicContentShareLink.information(id: 21))
        XCTAssertEqual(url.absoluteString, "https://www.chengyinhub.com/subpackageA/pages/infomationdetail/infomationdetail?id=21")
        XCTAssertEqual(UniversalLinkParser(verifiedHTTPSOrigins: ["https://www.chengyinhub.com"]).parse(url),
                       .miniProgramPage(try XCTUnwrap(MiniProgramPageLink(path: "subpackageA/pages/infomationdetail/infomationdetail", query: ["id": "21"]))))
        XCTAssertNil(PublicContentShareLink.informationCopyText(id: 21))
        XCTAssertNil(PublicContentShareLink.information(id: 0))
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

    /// CLB-detail-30 / CLB-r10-detail-03 (MP club/detail js:3509-3545): club invite and 带票分享 are https universal links
    /// that the existing parser reads back to the same page.
    func testClubInviteAndTicketShareAreUniversalLinksThatParseBack() throws {
        let parser = UniversalLinkParser(verifiedHTTPSOrigins: [PublicContentShareLink.httpsOrigin])
        let club = try XCTUnwrap(PublicContentShareLink.club(ClubShareLink(clubID: 42, postID: nil)))
        XCTAssertEqual(club.absoluteString, "https://www.chengyinhub.com/pages/club/detail/index?id=42")
        XCTAssertEqual(parser.parse(club), .content(try XCTUnwrap(NativeContentTarget(kind: .club, id: 42))))

        let post = try XCTUnwrap(PublicContentShareLink.club(ClubShareLink(clubID: 42, postID: 7)))
        XCTAssertEqual(post.absoluteString, "https://www.chengyinhub.com/pages/club/detail/index?id=42&postId=7")
        XCTAssertEqual(parser.parse(post), .miniProgramPage(try XCTUnwrap(MiniProgramPageLink(path: ClubShareLink.page, query: ["id": "42", "postId": "7"]))))

        let ticket = try XCTUnwrap(PublicContentShareLink.clubTicket(TopicClubShareLink(topicID: 8, sourceClubId: 42, clubCode: "club-42-t8")))
        XCTAssertEqual(ticket.absoluteString, "https://www.chengyinhub.com/pages/topic/index/index?id=8&sourceClubId=42&clubCode=club-42-t8")
        guard case .miniProgramPage(let page)? = parser.parse(ticket) else { return XCTFail("ticket share is a reviewed page") }
        XCTAssertEqual(page.query, ["id": "8", "sourceClubId": "42", "clubCode": "club-42-t8"])
        XCTAssertNil(PublicContentShareLink.clubTicket(TopicClubShareLink(topicID: 8, sourceClubId: 0, clubCode: nil)))
    }
}
