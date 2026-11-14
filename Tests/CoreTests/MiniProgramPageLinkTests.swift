import Foundation
import XCTest
@testable import QuestifyCore

/// P-A deep-link router: every mini-program page with a native parity screen, through each entry
/// (internal path / push tap, verified universal link, chein://mp), and the rejection rules.
final class MiniProgramPageLinkTests: XCTestCase {
    /// One explicit row per page that already had its own query. Every other reviewed page is one more row:
    /// a required `id` uses `7`, and a page with no keys is the bare path.
    private var table: [(String, String, [String: String])] {
        let explicit: [(String, String, [String: String])] = [
            ("/subpackageA/pages/video-bounty/index?campaignKey=spring&topicId=12", "subpackageA/pages/video-bounty/index", ["campaignKey": "spring", "topicId": "12"]),
            ("/subpackageMember/market/passes/index?tab=orders", "subpackageMember/market/passes/index", ["tab": "orders"]),
            ("/subpackageMember/market/pass/index?id=p-7", "subpackageMember/market/pass/index", ["id": "p-7"]),
            ("/subpackageMember/market/gift/index?token=gift-token-1", "subpackageMember/market/gift/index", ["token": "gift-token-1"]),
            ("/subpackageMember/market/membership/index", "subpackageMember/market/membership/index", [:]),
            ("/subpackageMember/market/library/index?kind=all", "subpackageMember/market/library/index", ["kind": "all"]),
            ("/subpackagePass/reveal/index", "subpackagePass/reveal/index", [:]),
            ("/subpackageJourney/pages/landing/index?k=g&t=tok&aid=5&tid=", "subpackageJourney/pages/landing/index", ["k": "g", "t": "tok", "aid": "5"]),
            ("/subpackageJourney/pages/seats/index?registrationId=88", "subpackageJourney/pages/seats/index", ["registrationId": "88"]),
            ("/subpackageJourney/pages/promo/index", "subpackageJourney/pages/promo/index", [:]),
            ("/subpackageJourney/pages/report/index?activityId=3&runId=9&topicName=%E5%9F%8E", "subpackageJourney/pages/report/index", ["activityId": "3", "runId": "9", "topicName": "城"]),
            ("/subpackageJourney/pages/settle/index?topicId=4&registrationId=10", "subpackageJourney/pages/settle/index", ["topicId": "4", "registrationId": "10"]),
            ("/subpackageMember/order/order", "subpackageMember/order/order", [:]),
            ("/pages/coop/list/index", "pages/coop/list/index", [:]),
            ("/pages/coop/list/index?tab=sent", "pages/coop/list/index", ["tab": "sent"]),
            ("/subpackageA/pages/myproject/index", "subpackageA/pages/myproject/index", [:]),
            ("/pages/merchant/ledger/index", "pages/merchant/ledger/index", [:]),
        ]
        let covered = Set(explicit.map(\.1))
        var rows = explicit
        for page in MiniProgramPageLink.reviewedPages.keys.sorted() where !covered.contains(page) {
            let rule = MiniProgramPageLink.reviewedPages[page]!
            let query = rule.required.contains("id") ? ["id": "7"] : [String: String]()
            let suffix = query.isEmpty ? "" : "?id=7"
            rows.append(("/" + page + suffix, page, query))
        }
        return rows
    }

    private var contentPages: Set<String> {
        Set(NativeContentTarget.Kind.allCases.map { kind in
            kind.sourcePath.hasPrefix("/") ? String(kind.sourcePath.dropFirst()) : kind.sourcePath
        })
    }

    func testTableCoversEveryReviewedPage() {
        XCTAssertEqual(Set(table.map(\.1)), Set(MiniProgramPageLink.reviewedPages.keys))
    }

    func testInternalPathAndPushTapOpenEveryPage() {
        let push = PushTapRouter(routeKeys: ["page"])
        for (path, page, query) in table {
            let parsed = MiniProgramPageLink(path: page, query: query)
            XCTAssertEqual(parsed?.page, page, path)
            XCTAssertEqual(parsed?.query, query, path)
            // Content paths keep the earlier typed intent. The link parser still accepts them for chein://mp.
            if contentPages.contains(page) {
                guard case .content(let target) = NativeNavigationContract.parseInternal(path) else { XCTFail(path); continue }
                XCTAssertEqual(target.id, 7, path)
                guard case .content(let tapped) = push.intent(userInfo: ["page": String(path.dropFirst())]) else { XCTFail(path); continue }
                XCTAssertEqual(tapped.id, 7, path)
                continue
            }
            guard case .miniProgramPage(let link) = NativeNavigationContract.parseInternal(path) else { XCTFail(path); continue }
            XCTAssertEqual(link.page, page, path)
            XCTAssertEqual(link.query, query, path)
            // A push payload may omit the leading slash; PushTapRouter adds it.
            guard case .miniProgramPage(let tapped) = push.intent(userInfo: ["page": String(path.dropFirst())]) else { XCTFail(path); continue }
            XCTAssertEqual(tapped, link, path)
        }
    }

    func testVerifiedUniversalLinkOpensEveryPage() {
        let policy = NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://example.test"])
        for (path, page, query) in table {
            if contentPages.contains(page) {
                guard case .content(let target) = policy.parse(URL(string: "https://example.test" + path)!) else { XCTFail(path); continue }
                XCTAssertEqual(target.id, 7, path)
                continue
            }
            guard case .miniProgramPage(let link) = policy.parse(URL(string: "https://example.test" + path)!) else { XCTFail(path); continue }
            XCTAssertEqual(link.page, page, path)
            XCTAssertEqual(link.query, query, path)
        }
        XCTAssertNil(NativeEntryLinkPolicy().parse(URL(string: "https://example.test/subpackageMember/market/gift/index?token=x")!))
    }

    func testCheinMiniProgramURLOpensEveryPage() {
        for (path, page, query) in table {
            let link = MiniProgramPageLink(cheinURL: URL(string: "chein://mp" + path)!)
            XCTAssertEqual(link?.page, page, path)
            XCTAssertEqual(link?.query, query, path)
        }
        XCTAssertNil(MiniProgramPageLink(cheinURL: URL(string: "chein://landing?k=g&t=x")!))
        XCTAssertNil(MiniProgramPageLink(cheinURL: URL(string: "https://mp/subpackageJourney/pages/promo/index")!))
        XCTAssertNil(MiniProgramPageLink(cheinURL: URL(string: "chein://mp/subpackageJourney/pages/promo/index#x")!))
    }

    func testJourneyIntakeOpensTheLandingPage() {
        let intake = JourneyLinkIntake(kind: .seat, token: "seat-token", activityID: 7, topicID: nil)
        let link = MiniProgramPageLink(journey: intake)
        XCTAssertEqual(link.page, "subpackageJourney/pages/landing/index")
        XCTAssertEqual(link.query, ["k": "s", "t": "seat-token", "aid": "7"])
        XCTAssertEqual(MiniProgramPageLink(path: link.page, query: link.query), link)
    }

    func testRejectsUnknownPagesKeysAndValues() {
        let rejected = [
            "/subpackageMember/market/checkout/index?id=1",                 // no native screen
            "/pages/index/index?id=1",                                      // open pages take no query
            "/pages/club/governance/index",                                  // sections only, no page view
            "/pages/club/roles/index",
            "/pages/club/settlement/index",
            "/pages/merchant/customer/detail/index",
            "/pages/team/join/index",                                        // team invitation keeps this path
            "/subpackageMember/market/gift/index",                          // token required
            "/subpackageMember/market/gift/index?token=a&amount=1",         // unknown key
            "/subpackageMember/market/gift/index?token=a&token=b",          // repeated key
            "/subpackagePass/reveal/index?mode=paid&count=3",               // paid facts from a link stay off
            "/subpackageJourney/pages/seats/index?registrationId=08",       // non-canonical id
            "/subpackageJourney/pages/seats/index?registrationId=-1",
            "/subpackageJourney/pages/landing/index?k=x&t=tok",             // unknown landing kind
            "/subpackageJourney/pages/landing/index?k=g",                   // token required
            "/subpackageJourney/pages/report/index?activityId=abc",
            "https://evil.test/subpackageMember/market/membership/index",   // internal paths carry no host
            "/pages/coop/list/index?tab=other",                             // not a sent or received list
            "/pages/roam/index",                                            // roam recall template is empty
            "/pages/index/index",                                           // fallback page, not a configured type
            "/pages/merchant/index/index",
            "/pages/club/workbench/index",
            "/pages/activity/official-detail/index?id=1",                   // official template id is not configured
        ]
        for path in rejected {
            if case .miniProgramPage = NativeNavigationContract.parseInternal(path) { XCTFail(path) }
        }
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/market/pass/index", query: ["id": String(repeating: "a", count: 513)]))
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/market/pass/index", query: ["id": "a\u{7}"]))
        XCTAssertNil(PushTapRouter().intent(userInfo: ["page": "subpackageJourney/pages/promo/index"]))
    }

    func testEmptyValuesAreAbsent() {
        let link = MiniProgramPageLink(path: "/subpackageA/pages/video-bounty/index", query: ["campaignKey": "", "topicId": ""])
        XCTAssertEqual(link?.query, [:])
    }
}
