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
            ("/pages/merchant/profile/index?id=7", "pages/merchant/profile/index", ["id": "7"]),
            // fix-parity r1 (account-publish X1): the MP query keys these pages read.
            ("/pages/userinfo/userinfo?userId=12&tab=about", "pages/userinfo/userinfo", ["userId": "12", "tab": "about"]),
            ("/pages/talent/list/index?tab=feed", "pages/talent/list/index", ["tab": "feed"]),
            ("/pages/gerenziliao/gerenziliao?field=introduction", "pages/gerenziliao/gerenziliao", ["field": "introduction"]),
            ("/pages/addressinfo/addressinfo?id=3", "pages/addressinfo/addressinfo", ["id": "3"]),
            ("/pages/agreement/index?type=cancellation_notice", "pages/agreement/index", ["type": "cancellation_notice"]),
            ("/pages/shezhi/shezhi?scene=settings-deregister", "pages/shezhi/shezhi", ["scene": "settings-deregister"]),
            ("/pages/publish/fabu/index?id=5&mode=2&scope=MERCHANT&clubId=8", "pages/publish/fabu/index", ["id": "5", "mode": "2", "scope": "MERCHANT", "clubId": "8"]),
            ("/pages/publish/temp/index?id=6&from=fabu", "pages/publish/temp/index", ["id": "6", "from": "fabu"]),
            ("/pages/publish/activity/index?id=9", "pages/publish/activity/index", ["id": "9"]),
            ("/pages/publish/template-intro/index?scope=MERCHANT", "pages/publish/template-intro/index", ["scope": "MERCHANT"]),
            ("/pages/team/detail/index?teamId=41", "pages/team/detail/index", ["teamId": "41"]),
            ("/pages/team/join/index?entry=code", "pages/team/join/index", ["entry": "code"]),
        ]
        let covered = Set(explicit.map(\.1))
        var rows = explicit
        for page in MiniProgramPageLink.reviewedPages.keys.sorted() where !covered.contains(page) {
            let rule = MiniProgramPageLink.reviewedPages[page]!
            // Every required key gets a value (ids `7`, other keys `x`); a content page (club detail, roam session…)
            // is addressed by `id=7`, which parity r1 made optional on several pages.
            var query = [String: String]()
            for key in rule.required { query[key] = rule.ids.contains(key) ? "7" : "x" }
            if contentPages.contains(page), rule.allowed.contains("id") { query["id"] = "7" }
            let suffix = query.isEmpty ? "" : "?" + query.keys.sorted().map { $0 + "=" + query[$0]! }.joined(separator: "&")
            rows.append(("/" + page + suffix, page, query))
        }
        return rows
    }

    private var contentPages: Set<String> {
        Set(NativeContentTarget.Kind.allCases.map { kind in
            kind.sourcePath.hasPrefix("/") ? String(kind.sourcePath.dropFirst()) : kind.sourcePath
        })
    }

    /// Parity r1 player-content (X1): the MP `onLoad` query reaches the native screen instead of rejecting the link.
    func testParityPlayerContentPagesKeepTheirQuery() {
        let accepted: [(String, [String: String])] = [
            ("pages/templatedetail/topic-preview/index", ["id": "12", "scope": "MERCHANT"]),
            ("pages/templatedetail/topic-detail/index", ["id": "12", "tab": "details"]),
            ("pages/search2/index", ["keyword": "城"]),
            ("pages/search2/result/index", ["keyword": "城", "categoryId": "3", "minPrice": "0", "maxPrice": "100"]),
            ("pages/searchmap/index", ["params": "{\"keyword\":\"城\"}"]),
            ("pages/activity/baoming/baoming", ["activityId": "8", "ticketId": "2"]),
            ("pages/activity/official-organizer/index", ["id": "88"]),
            ("subpackageB/pages/im/chat/index", ["conversationId": "41", "type": "1", "name": "小城"]),
            ("pages/topic/merchantinfo/merchantinfo", ["topicId": "5", "id": "9"]),
            ("pages/topic/merchantapply/index", ["topicId": "5", "nodeId": "2"]),
            ("pages/topic/pricing/index", ["topicId": "5", "club": "1"]),
            ("pages/topic/pricing/partner/index", ["topicId": "5", "toId": "6", "toType": "CLUB"]),
        ]
        for (page, query) in accepted { XCTAssertEqual(MiniProgramPageLink(path: page, query: query)?.query, query, page) }
        XCTAssertNil(MiniProgramPageLink(path: "subpackageB/pages/im/chat/index", query: ["conversationId": "x"]))
        XCTAssertNil(MiniProgramPageLink(path: "pages/topic/pricing/index", query: ["topicId": "05"]))
    }

    func testInvoiceHistoryAcceptsAnOptionalApplicationId() {
        let bare = MiniProgramPageLink(path: "subpackageMember/invoice/index", query: [:])
        XCTAssertEqual(bare?.page, "subpackageMember/invoice/index")
        XCTAssertEqual(bare?.query, [:])
        XCTAssertEqual(MiniProgramPageLink(path: "/subpackageMember/invoice/index", query: ["id": "15"])?.query, ["id": "15"])
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/invoice/index", query: ["id": "0"]))
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/invoice/index", query: ["other": "1"]))
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

    func testMemberLinksOpenWithoutARequiredIdAndKeepOptionalKeys() {
        XCTAssertEqual(MiniProgramPageLink(path: "subpackageMember/market/pass/index", query: [:])?.page,
                       "subpackageMember/market/pass/index")
        XCTAssertEqual(MiniProgramPageLink(path: "subpackageMember/market/pass-order/index", query: [:])?.page,
                       "subpackageMember/market/pass-order/index")
        XCTAssertEqual(MiniProgramPageLink(path: "subpackageMember/invoice-detail/index", query: [:])?.page,
                       "subpackageMember/invoice-detail/index")
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/invoice-detail/index", query: ["id": "0"]))
        XCTAssertEqual(MiniProgramPageLink(path: "subpackageMember/market/gift/index", query: ["mode": "code"])?.query,
                       ["mode": "code"])
        XCTAssertEqual(MiniProgramPageLink(path: "subpackageMember/coupon/coupon", query: ["scope": "MERCHANT"])?.query,
                       ["scope": "MERCHANT"])
        XCTAssertEqual(MiniProgramPageLink(path: "subpackageMember/coupon/coupon", query: [:])?.page,
                       "subpackageMember/coupon/coupon")
    }

    func testRejectsUnknownPagesKeysAndValues() {
        let rejected = [
            "/subpackageMember/market/checkout/index?id=1",                 // no native screen
            "/pages/index/index?id=1",                                      // open pages take no query
            "/pages/club/governance/index",                                  // clubId required (MP governance onLoad)
            "/pages/club/roles/index?clubId=abc",                            // non-canonical id
            "/pages/club/customer-detail/index?clubId=7",                    // memberId required
            "/pages/club/topic-detail/index?topicId=1&foo=2",                // unknown key
            "/pages/club/settlement/index",
            "/pages/merchant/customer/detail/index",
            "/pages/team/join/index",                                        // team invitation keeps this path
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
            "/pages/merchant/ledger/index?view=unknown",                    // 链接已失效
            "/pages/merchant/ledger/index?tab=4",
            "/pages/merchant/ledger/index?view=redemptions&ownerType=3&ownerId=8",
            "/pages/merchant/profile/index",                                // id XOR poiId
            "/pages/merchant/profile/index?id=7&poiId=8",
            "/pages/merchant/team/index?invite=short",
            "/pages/merchant/ledger/order-detail/index?recordType=other&recordId=7",
            "/pages/coop/invite-detail/index?box=other",
            "/pages/coop/invite/index?type=2",
            "/pages/coop/list/index?scope=club",
            "/pages/userinfo/userinfo?userId=abc",                          // ids stay canonical
            "/pages/userinfo/userinfo?tab=wallet",                          // not an MP profile tab
            "/pages/publish/fabu/index?mode=3",                             // MP modes are 1 and 2
            "/pages/team/detail/index?teamId=007",
            "/pages/team/join/index?entry=other",
            "/pages/shezhi/shezhi?scene=unknown",
        ]
        for path in rejected {
            if case .miniProgramPage = NativeNavigationContract.parseInternal(path) { XCTFail(path) }
        }
        // cur-deeplinks-2 opens these page-map paths as links; a push tap still cannot reach them (no configured template).
        for page in ["pages/roam/index", "pages/index/index", "pages/merchant/index/index", "pages/club/workbench/index"] {
            XCTAssertNil(PushTapRouter().intent(userInfo: ["page": page]), page)
        }
        XCTAssertNil(PushTapRouter().intent(userInfo: ["page": "pages/activity/official-detail/index?id=1"]))
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/market/pass/index", query: ["id": String(repeating: "a", count: 513)]))
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/market/pass/index", query: ["id": "a\u{7}"]))
        XCTAssertNil(PushTapRouter().intent(userInfo: ["page": "subpackageJourney/pages/promo/index"]))
    }

    func testEveryClubPageOpensWithItsMiniProgramKeys() {
        // CLB-*-01 / CLB-workbench-01 (parity r1): the keys each pages/club page reads in onLoad.
        let accepted: [(String, [String: String])] = [
            ("pages/club/detail/index", ["id": "7", "tab": "manage", "postId": "9", "scan": "1"]),
            ("pages/club/detail/index", ["owner": "1"]),
            ("pages/club/workbench/index", ["id": "7"]), ("pages/club/workbench/index", ["clubId": "7"]), ("pages/club/workbench/index", [:]),
            ("pages/club/apply/index", [:]), ("pages/club/create/index", [:]),
            ("pages/club/edit/index", ["clubId": "7"]), ("pages/club/badges/index", ["id": "7"]),
            ("pages/club/customers/index", ["clubId": "7"]), ("pages/club/customer-detail/index", ["clubId": "7", "memberId": "8"]),
            ("pages/club/checkin-detail/index", ["clubId": "7", "registrationId": "8"]),
            ("pages/club/enroll/index", ["clubId": "7", "topicId": "3", "clubName": "夜跑团"]),
            ("pages/club/event-ops/index", ["clubId": "7", "activityId": "4", "topicId": "3", "recurrence": "1"]),
            ("pages/club/group-code/index", ["activityId": "4", "activityName": "夜跑", "topicId": "3", "topicName": "城市"]),
            ("pages/club/join-requests/index", ["clubId": "7"]),
            ("pages/club/notify/index", ["clubId": "7", "activityId": "4", "silent": "1"]),
            ("pages/club/topic-detail/index", ["topicId": "3", "clubId": "7", "activityId": "4"]),
            ("pages/club/topic-story/index", ["topicId": "3", "clubId": "7", "scope": "club"]),
            ("pages/club/governance/index", ["clubId": "7", "mode": "report", "targetType": "MEMBER", "targetId": "8", "targetName": "A"]),
            ("pages/club/roles/index", ["clubId": "7", "activityId": "4", "activityLabel": "夜跑"]),
        ]
        for (page, query) in accepted {
            XCTAssertEqual(MiniProgramPageLink(path: page, query: query)?.query, query, page)
        }
    }

    func testCatalogOptionalIDAndSessionVia() {
        let session = MiniProgramPageLink(path: "pages/topic/index/index", query: ["id": "7", "via": "session"])
        XCTAssertEqual(session?.opensSessionPickerFirst, true)
        XCTAssertNil(MiniProgramPageLink(path: "pages/topic/index/index", query: ["id": "7", "via": "other"]))
        XCTAssertEqual(MiniProgramPageLink(path: "pages/topic/catalog/index", query: ["id": "9"])?.catalogDestination, .topic(9))
        XCTAssertEqual(MiniProgramPageLink(path: "pages/topic/catalog/index", query: [:])?.catalogDestination, .home)
        XCTAssertNil(MiniProgramPageLink(path: "pages/topic/catalog/index", query: ["id": "09"]))
    }

    func testEmptyValuesAreAbsent() {
        let link = MiniProgramPageLink(path: "/subpackageA/pages/video-bounty/index", query: ["campaignKey": "", "topicId": ""])
        XCTAssertEqual(link?.query, [:])
    }

    /// The retired rewrite opened 我发布的 and dropped the query. The link now stays on the template author's 我的 page.
    func testRetiredMyTemplateOpensMyPublished() {
        let link = MiniProgramPageLink(path: "subpackageMember/mytemplate/mytemplate", query: ["id": "3"])
        XCTAssertEqual(link?.page, "subpackageMember/mytemplate/mytemplate")
        XCTAssertEqual(link?.query, ["id": "3"])
        XCTAssertNotEqual(link?.page, "pages/activity/official-mine/index")
        XCTAssertNotEqual(link?.query, [:])
        XCTAssertTrue(MiniProgramPageLink.reviewedPages.keys.contains("subpackageMember/mytemplate/mytemplate"))
        XCTAssertEqual(MiniProgramPageLink(path: "subpackageMember/mytemplate/mytemplate", query: ["id": "3", "scope": "MERCHANT"])?.query,
                       ["id": "3", "scope": "MERCHANT"])
        XCTAssertEqual(MiniProgramPageLink(path: "subpackageMember/mytemplate/mytemplate", query: [:])?.query, [:])
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/mytemplate/mytemplate", query: ["scope": "PLAYER"]))
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/mytemplate/mytemplate", query: ["id": "03"]))
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/mytemplate/mytemplate", query: ["keyword": "x"]))
        XCTAssertEqual(MiniProgramPageLink(path: "pages/activity/official-mine/index", query: [:])?.page,
                       "pages/activity/official-mine/index")
        XCTAssertNil(MiniProgramPageLink(path: "pages/activity/official-mine/index", query: ["id": "3"]))
    }
}
