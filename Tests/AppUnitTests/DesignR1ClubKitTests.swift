import XCTest
@testable import Questify

/// Design hand-off r1 · member & club kit rules (review/full-member-club.md MC-10, MC-20, MC-30).
final class DesignR1ClubKitTests: XCTestCase {
    func testMemberMenuPutsTheDestructiveActionLast() {
        let actions = ClubMemberAction.menu(canGovern: true, targetIsOwner: false, targetIsAdmin: false)
        XCTAssertEqual(actions, [.report, .makeAdmin, .tempBan, .remove])
        XCTAssertEqual(actions.last?.isDestructive, true)
        XCTAssertEqual(actions.filter(\.isDestructive).count, 1)
    }

    func testMemberMenuForVisitorsOnlyReports() {
        XCTAssertEqual(ClubMemberAction.menu(canGovern: false, targetIsOwner: false, targetIsAdmin: false), [.report])
        XCTAssertEqual(ClubMemberAction.menu(canGovern: true, targetIsOwner: true, targetIsAdmin: false), [.report])
    }

    func testMemberMenuDoesNotOfferAdminTwice() {
        XCTAssertEqual(ClubMemberAction.menu(canGovern: true, targetIsOwner: false, targetIsAdmin: true), [.report, .tempBan, .remove])
    }

    func testHeavyActionsNeedTheConsequenceSheet() {
        XCTAssertTrue(ClubMemberAction.remove.needsConsequenceSheet)
        XCTAssertTrue(ClubMemberAction.tempBan.needsConsequenceSheet)
        XCTAssertFalse(ClubMemberAction.report.needsConsequenceSheet)
    }

    func testCityPickerPutsTheCurrentCityFirstAndFilters() {
        let all = ClubCreateCityCatalog.filtered(current: "上海", query: "")
        XCTAssertEqual(all.current, "上海")
        XCTAssertFalse(all.others.contains("上海"))
        let search = ClubCreateCityCatalog.filtered(current: "上海", query: "杭")
        XCTAssertNil(search.current)
        XCTAssertEqual(search.others, ["杭州"])
    }

    func testCityPickerOffersATypedCityOutsideTheHotList() {
        let typed = ClubCreateCityCatalog.filtered(current: nil, query: "苏州")
        XCTAssertNil(typed.current)
        XCTAssertEqual(typed.others, ["苏州"])
    }

    func testBadgeCategoryPicksTheShapeFamily() {
        XCTAssertEqual(ClubBadgeCategory.resolve("俱乐部勋章"), .club)
        XCTAssertEqual(ClubBadgeCategory.resolve("城市探索"), .explore)
        XCTAssertEqual(ClubBadgeCategory.resolve(nil), .achievement)
    }

    func testBadgeEmblemsDifferByBadge() {
        XCTAssertEqual(ClubBadgeEmblem.symbol(for: "初次启程", seed: "a"), "flag.fill")
        XCTAssertEqual(ClubBadgeEmblem.symbol(for: "连续打卡 7 天", seed: "b"), "flame.fill")
        XCTAssertNotEqual(ClubBadgeEmblem.symbol(for: "通关老城三章", seed: "c"), ClubBadgeEmblem.symbol(for: "城市夜游", seed: "d"))
        XCTAssertEqual(ClubBadgeEmblem.symbol(for: "", seed: "x"), ClubBadgeEmblem.symbol(for: "", seed: "x"))
    }

    func testProgressRingFractionIsClamped() {
        XCTAssertEqual(ClubBadgeTile.fraction(3, 7), 3.0 / 7.0, accuracy: 0.0001)
        XCTAssertEqual(ClubBadgeTile.fraction(9, 7), 1)
        XCTAssertEqual(ClubBadgeTile.fraction(1, 0), 0)
    }

    func testUnknownValuesReadAsDash() {
        XCTAssertEqual(clubR1Value(nil), "—")
        XCTAssertEqual(clubR1Value("  "), "—")
        XCTAssertEqual(clubR1Value("上海"), "上海")
    }
}

/// MC-25 roster card numbers.
final class DesignR1ClubRosterCardTests: XCTestCase {
    private func model(_ registered: Int?, _ capacity: Int?) -> ClubRosterCardModel {
        ClubRosterCardModel(title: "老城三章", dateText: nil, registered: registered, capacity: capacity,
                            received: nil, refunded: nil, net: nil, attendees: [])
    }

    func testCapacityTextAndFill() {
        XCTAssertEqual(model(5, 50).countText, "5 / 50")
        XCTAssertEqual(model(5, 50).fill ?? -1, 0.1, accuracy: 0.0001)
        XCTAssertEqual(model(60, 50).fill, 1)
    }

    func testUnknownCapacityIsADashAndNoBar() {
        XCTAssertEqual(model(nil, 50).countText, "— / 50")
        XCTAssertNil(model(5, nil).fill)
        XCTAssertNil(model(5, 0).fill)
    }
}
