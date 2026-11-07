import XCTest
@testable import QuestifyCore

final class MerchantWriteRouteTests: XCTestCase {
    func testGroupsAreDisjointAndNonEmpty() {
        var seen = Set<String>()
        for group in MerchantWriteGroup.allCases {
            let set = MerchantWriteRoute.routes[group] ?? []
            XCTAssertFalse(set.isEmpty, group.rawValue)
            XCTAssertTrue(seen.isDisjoint(with: set), group.rawValue)
            seen.formUnion(set)
        }
        XCTAssertEqual(seen, MerchantWriteRoute.all)
    }
    func testAdmitsOnlyGrantedPostWithoutQuery() {
        let granted: Set<MerchantWriteGroup> = [.team]
        XCTAssertTrue(MerchantWriteRoute.accepts(method: "POST", relative: "api/merchant/operators/invite", hasQuery: false, granted: granted))
        XCTAssertFalse(MerchantWriteRoute.accepts(method: "GET", relative: "api/merchant/operators/invite", hasQuery: false, granted: granted))
        XCTAssertFalse(MerchantWriteRoute.accepts(method: "POST", relative: "api/merchant/operators/invite", hasQuery: true, granted: granted))
        XCTAssertFalse(MerchantWriteRoute.accepts(method: "POST", relative: "api/merchant/crm/broadcast", hasQuery: false, granted: granted))
        XCTAssertFalse(MerchantWriteRoute.accepts(method: "POST", relative: "api/merchant/operators/invite", hasQuery: false, granted: []))
    }
    func testRejectsReadsLookalikesAndTraversal() {
        let all = Set(MerchantWriteGroup.allCases)
        for path in ["api/merchant/operators/list", "api/merchant/info", "api/merchant/update/", "api/merchant/../admin/x",
                     "api/merchant/crm/campaigns/preview", "API/merchant/update", "api/merchant/decor/save/1", ""] {
            XCTAssertFalse(MerchantWriteRoute.accepts(method: "POST", relative: path, hasQuery: false, granted: all), path)
        }
    }
}
