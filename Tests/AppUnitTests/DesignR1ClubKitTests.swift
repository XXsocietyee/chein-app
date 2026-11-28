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

    /// CLB-r7-A-07: an administrator without member governance is not offered 临时封禁.
    func testMemberMenuHidesTempBanWithoutMemberGovernance() {
        XCTAssertEqual(ClubMemberAction.menu(canGovern: true, targetIsOwner: false, targetIsAdmin: false, canTempBan: false),
                       [.report, .makeAdmin, .remove])
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

    /// polish-d-r1: with no capacity read the card shows only the count, and it expands only for money or attendees.
    func testCountWithoutCapacityAndExpandability() {
        XCTAssertEqual(model(5, nil).countText, "5")
        XCTAssertTrue(model(5, 50).isExpandable)
        let members = ClubRosterCardModel(title: "梧桐摄影漫步社", dateText: nil, registered: 4, capacity: nil,
                                          received: nil, refunded: nil, net: nil, attendees: [], showsMoney: false)
        XCTAssertFalse(members.isExpandable)
        XCTAssertEqual(members.countText, "4")
    }

    func testMembersScreenRosterCountsRoles() throws {
        let club = try JSONDecoder().decode(ClubRecord.self, from: Data(#"{"id":7003,"name":"梧桐摄影漫步社","isOwner":true,"isJoined":true,"memberCount":4}"#.utf8))
        let rows = #"[{"memberId":9003,"role":2,"isOwner":true},{"memberId":9004,"role":1},{"memberId":9005,"role":0},{"memberId":9009,"role":0}]"#
        let members = try JSONDecoder().decode([ClubMember].self, from: Data(rows.utf8))
        let card = ClubRosterCardModel.members(ClubMemberDirectory(club: club, members: members), locale: Locale(identifier: "zh-Hans"))
        XCTAssertEqual(card.title, "梧桐摄影漫步社")
        XCTAssertEqual(card.registered, 4)
        XCTAssertNil(card.capacity)
        XCTAssertFalse(card.showsMoney)
        // The hosted app may override the language; both catalogs carry the same counts.
        XCTAssertTrue(["主理人 1 · 管理员 1 · 成员 2", "Owner: 1 · Admins: 1 · Members: 2"].contains(card.dateText ?? ""), card.dateText ?? "nil")
    }
}
