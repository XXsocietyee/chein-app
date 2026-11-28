import Foundation
import XCTest
@testable import QuestifyCore

/// Lane G player release gate. Pins every merchant-center, merchant-onboarding and coop page that the Release build
/// hides (`PlayerLaunch.merchantCenterEnabled == false`), and that a hidden link falls back to the player home page.
/// The test target builds under DEBUG, where the flag is on, so each check passes `enabled: false` explicitly.
final class PlayerReleaseGateTests: XCTestCase {
    /// Every page in the generated route table (`Core/MiniProgramPages.swift`) that Release hides. A new merchant or
    /// coop page in the table fails `testHiddenSetMatchesTheRouteTableExactly` until it is added here.
    static let hiddenPages: Set<String> = [
        "pages/coop/finance/index",
        "pages/coop/invite-detail/index",
        "pages/coop/invite/index",
        "pages/coop/list/index",
        "pages/coop/nearby/index",
        "pages/coop/settlement-detail/index",
        "pages/coop/withdraw/index",
        "pages/coop/withdraw/records/index",
        "pages/cooperation/detail",
        "pages/cooperation/finance",
        "pages/cooperation/index",
        "pages/merchant/aftercare",
        "pages/merchant/aftercare/detail/index",
        "pages/merchant/aftercare/index",
        "pages/merchant/aiInsight",
        "pages/merchant/apply",
        "pages/merchant/apply/index",
        "pages/merchant/brand",
        "pages/merchant/cityNode",
        "pages/merchant/citynode/create/index",
        "pages/merchant/citynode/index",
        "pages/merchant/coop-center/index",
        "pages/merchant/coupons",
        "pages/merchant/crm-campaigns/index",
        "pages/merchant/customer/detail/index",
        "pages/merchant/customer/index",
        "pages/merchant/customers",
        "pages/merchant/decor/ai-npc/index",
        "pages/merchant/decor/coop-setting/index",
        "pages/merchant/decor/gallery/index",
        "pages/merchant/decor/index",
        "pages/merchant/decor/perks/index",
        "pages/merchant/game-node/index",
        "pages/merchant/index",
        "pages/merchant/index/index",
        "pages/merchant/ledger",
        "pages/merchant/ledger/batch-detail/index",
        "pages/merchant/ledger/index",
        "pages/merchant/ledger/order-detail/index",
        "pages/merchant/marketing",
        "pages/merchant/marketing/ai-insight/index",
        "pages/merchant/marketing/index",
        "pages/merchant/operations",
        "pages/merchant/operators",
        "pages/merchant/payout-account/index",
        "pages/merchant/predict/index",
        "pages/merchant/profile",
        "pages/merchant/relation",
        "pages/merchant/relation/index",
        "pages/merchant/reviews",
        "pages/merchant/reviews/index",
        "pages/merchant/settlement",
        "pages/merchant/store/index",
        "pages/merchant/team/index",
        "pages/merchant/todo",
        "pages/merchant/verify",
        "pages/merchant/verify-records/index",
        "pages/merchant/workbench",
        "pages/topic/merchantapply/index",
        "pages/topic/merchantinfo/merchantinfo",
        "pages/topic/settlement/index",
    ]

    /// Player-facing pages that must stay open, including the public merchant home and player money pages.
    static let playerPages: [String] = [
        "pages/index/index",
        "pages/merchant/profile/index",
        "pages/play/merchant/index",
        "pages/topic/index/index",
        "pages/activity/detail/index",
        "pages/club/detail/index",
        "pages/club/settlement/index",
        "pages/topic/pricing/partner/index",
        "subpackageMember/order/order",
        "subpackageMember/market/passes/index",
        "subpackageJourney/pages/settle/index",
        "subpackageA/pages/myproject/index",
    ]

    func testReleaseFlagIsOnInDebugAndTestBuilds() {
        // DEBUG/TEST keep the merchant console for fixtures and UI tests; Release compiles the flag to false.
        XCTAssertTrue(PlayerLaunch.merchantCenterEnabled)
        XCTAssertEqual(PlayerLaunch.playerHomePage, "pages/index/index")
    }

    func testHiddenSetMatchesTheRouteTableExactly() {
        let fromTable = Set(MiniProgramPage.allCases.map(\.rawValue).filter { PlayerLaunch.isHidden(page: $0, enabled: false) })
        XCTAssertEqual(fromTable, Self.hiddenPages)
        for page in MiniProgramPage.allCases {
            XCTAssertEqual(page.isMerchantCenterPage, Self.hiddenPages.contains(page.rawValue), page.rawValue)
        }
    }

    func testEveryHiddenPageIsHiddenOnlyWhenTheFlagIsOff() {
        for page in Self.hiddenPages {
            XCTAssertTrue(PlayerLaunch.isHidden(page: page, enabled: false), page)
            XCTAssertTrue(PlayerLaunch.isHidden(page: "/" + page + "?id=7", enabled: false), page)
            XCTAssertFalse(PlayerLaunch.isHidden(page: page, enabled: true), page)
        }
    }

    func testPlayerPagesStayVisible() {
        for page in Self.playerPages {
            XCTAssertFalse(PlayerLaunch.isHidden(page: page, enabled: false), page)
            XCTAssertFalse(PlayerLaunch.isMerchantCenterPage(page), page)
        }
    }

    func testHiddenDeepLinkFallsBackToPlayerHome() throws {
        let home = try XCTUnwrap(MiniProgramPageLink(path: "pages/index/index", query: [:]))
        XCTAssertEqual(PlayerLaunch.homeIntent, .miniProgramPage(home))
        let samples = ["/pages/coop/list/index?tab=sent", "/pages/merchant/coop-center/index", "/pages/merchant/ledger/index",
                       "/pages/coop/invite-detail/index?inviteId=3", "/pages/merchant/team/index?invite=abc"]
        var parsed = 0
        for path in samples {
            guard let intent = NativeNavigationContract.parseInternal(path) else { continue }
            parsed += 1
            XCTAssertTrue(PlayerLaunch.isMerchantCenterIntent(intent), path)
            XCTAssertEqual(PlayerLaunch.gate(intent, enabled: false), .miniProgramPage(home), path)
            XCTAssertEqual(PlayerLaunch.gate(intent, enabled: true), intent, path)
        }
        XCTAssertGreaterThan(parsed, 0)
    }

    func testPlayerIntentsPassThroughTheGate() throws {
        let topic = try XCTUnwrap(NativeNavigationContract.parseInternal("/pages/topic/index/index?id=5"))
        XCTAssertEqual(PlayerLaunch.gate(topic, enabled: false), topic)
        let store = try XCTUnwrap(MiniProgramPageLink(path: "pages/merchant/profile/index", query: ["id": "7"]))
        XCTAssertEqual(PlayerLaunch.gate(.miniProgramPage(store), enabled: false), .miniProgramPage(store))
        XCTAssertEqual(PlayerLaunch.gate(.routeError(.unsupported), enabled: false), .routeError(.unsupported))
    }

    func testMerchantOnboardingBannerIsDroppedFromThePlayerHome() {
        let all = HomeIndexParityPresentation.fixedActionBanners.map(\.id)
        XCTAssertTrue(all.contains("merchant_apply"))
        let release = HomeIndexParityPresentation.fixedActionBanners.filter { !PlayerLaunch.isHidden(page: $0.routePath, enabled: false) }
        XCTAssertEqual(release.map(\.id), ["activity_list", "club_apply"])
        // DEBUG keeps every banner.
        XCTAssertEqual(HomeIndexParityPresentation.playerActionBanners.map(\.id), all)
    }
}
