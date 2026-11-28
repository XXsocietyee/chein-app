import XCTest
@testable import QuestifyCore

/// One assertion family per universal link and `chein://` / `chengyin://` route.
final class InboundLinkCatalogTests: XCTestCase {
    private let origins = Set([InboundLinkCatalog.verifiedOrigin])
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func receipt() throws -> String {
        let url = repoRoot.appendingPathComponent("docs/release/receipts/cursor-1128-deep-links.md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func decide(_ text: String, enabled: Bool = false, file: StaticString = #filePath, line: UInt = #line) -> InboundLinkCatalog.Decision {
        let url = URL(string: text)
        XCTAssertNotNil(url, text, file: file, line: line)
        return InboundLinkCatalog.decide(url: url!, verifiedHTTPSOrigins: origins, merchantCenterEnabled: enabled)
    }

    func testCheinAndChengyinShortForms() throws {
        try assertFixed(testName: "testCheinAndChengyinShortForms")
    }

    func testUniversalLinkShortForms() throws {
        try assertFixed(testName: "testUniversalLinkShortForms")
    }

    func testContentPagesOpenTheirScreens() throws {
        let receipt = try receipt()
        for row in InboundLinkCatalog.pageRows where InboundLinkCatalog.isContentPage(row.path) {
            try assertPage(row, receipt: receipt, screen: row.screen, gate: "no", testName: "testContentPagesOpenTheirScreens")
        }
    }

    func testMerchantRoutesFallBackToHome() throws {
        let receipt = try receipt()
        var saw = 0
        for row in InboundLinkCatalog.pageRows where PlayerLaunch.isMerchantCenterPage(row.path) {
            saw += 1
            try assertPage(row, receipt: receipt, screen: "Home tab", gate: "yes", testName: "testMerchantRoutesFallBackToHome")
            let opened = decide(InboundLinkCatalog.httpsRoute(path: row.path, query: InboundLinkCatalog.sampleQuery(for: row.path)), enabled: true)
            XCTAssertNotEqual(opened.screenName, "Home tab", row.path)
        }
        XCTAssertGreaterThan(saw, 0)
        let invite = "https://www.chengyinhub.com/merchant/team?invite=abcdefghijklmnop"
        XCTAssertEqual(decide(invite).screenName, "Home tab")
        XCTAssertEqual(decide(invite).gate, "yes")
        XCTAssertTrue(receipt.contains(invite))
    }

    func testMoneyRoutesKeepTheirScreens() throws {
        let receipt = try receipt()
        for row in InboundLinkCatalog.pageRows where InboundLinkCatalog.moneyPages.contains(row.path) {
            try assertPage(row, receipt: receipt, screen: row.screen, gate: "money switch", testName: "testMoneyRoutesKeepTheirScreens")
            XCTAssertFalse(PlayerLaunch.isMerchantCenterPage(row.path), row.path)
        }
        for kind in ["g", "s"] {
            let landing = "https://www.chengyinhub.com/subpackageJourney/pages/landing/index?k=\(kind)&t=tok"
            XCTAssertEqual(decide(landing).screenName, "JourneyLandingHost", landing)
            XCTAssertEqual(decide(landing).gate, "money switch", landing)
            XCTAssertTrue(receipt.contains(landing))
        }
        let referral = "https://www.chengyinhub.com/subpackageJourney/pages/landing/index?k=r&t=tok"
        XCTAssertEqual(decide(referral).gate, "no")
        XCTAssertEqual(decide(referral).screenName, "JourneyLandingHost")
    }

    func testReviewedPagesOpenOrFallBack() throws {
        let receipt = try receipt()
        for row in InboundLinkCatalog.pageRows {
            guard !PlayerLaunch.isMerchantCenterPage(row.path),
                  !InboundLinkCatalog.moneyPages.contains(row.path),
                  !InboundLinkCatalog.isContentPage(row.path) else { continue }
            try assertPage(row, receipt: receipt, screen: row.screen, gate: "no", testName: "testReviewedPagesOpenOrFallBack")
        }
        XCTAssertEqual(decide("https://www.chengyinhub.com/subpackageRoam/session/index?shareToken=tok").screenName, "RoamSharedFootprintView")
        XCTAssertEqual(decide("https://www.chengyinhub.com/subpackageMember/mytemplate/mytemplate").screenName, "OfficialPublishedView")
        XCTAssertEqual(decide("https://www.chengyinhub.com/pages/crop/index").screenName, "pages.crop.empty")
        XCTAssertEqual(decide("https://www.chengyinhub.com/subpackageP3/pages/badge-3d/index").screenName, "profile.badges.empty")
        XCTAssertEqual(decide("https://www.chengyinhub.com/pages/play/merchant/index").screenName, "mp.common.linkExpired")
        XCTAssertFalse(PlayerLaunch.isMerchantCenterPage("pages/play/merchant/index"))
        XCTAssertFalse(PlayerLaunch.isMerchantCenterPage("pages/merchant/profile/index"))
    }

    func testSpecialUniversalLinks() throws {
        try assertFixed(testName: "testSpecialUniversalLinks")
        XCTAssertEqual(decide("https://www.chengyinhub.com/pages/merchant/profile/index?id=7").screenName, "PublicMerchantHomeView")
        XCTAssertEqual(decide("chengyin://topic/7").screenName, "SessionTopicDetailView")
        XCTAssertEqual(CheinDeepLink.canonicalURL(URL(string: "chengyin://topic/7")!).scheme, "chein")
    }

    func testReceiptListsEveryRoute() throws {
        let receipt = try receipt()
        for row in InboundLinkCatalog.pageRows {
            let query = InboundLinkCatalog.sampleQuery(for: row.path)
            let route = InboundLinkCatalog.httpsRoute(path: row.path, query: query)
            XCTAssertTrue(receipt.contains(route), route)
            let decision = decide(route)
            XCTAssertTrue(receipt.contains(decision.screenName), decision.screenName)
            XCTAssertTrue(receipt.contains(decision.testName), route)
        }
        for row in InboundLinkCatalog.fixedRoutes {
            XCTAssertTrue(receipt.contains(row.route), row.route)
            XCTAssertTrue(receipt.contains(row.screen), row.route)
            XCTAssertTrue(receipt.contains(row.test), row.route)
        }
    }

    private func assertFixed(testName: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let receipt = try receipt()
        let rows = InboundLinkCatalog.fixedRoutes.filter { $0.test == testName }
        XCTAssertFalse(rows.isEmpty, testName, file: file, line: line)
        for row in rows {
            let decision = decide(row.route)
            XCTAssertEqual(decision.screenName, row.screen, row.route, file: file, line: line)
            XCTAssertEqual(decision.gate, row.gate, row.route, file: file, line: line)
            XCTAssertEqual(decision.testName, row.test, row.route, file: file, line: line)
            XCTAssertTrue(receipt.contains(row.route), row.route, file: file, line: line)
        }
    }

    private func assertPage(
        _ row: (path: String, query: String, screen: String),
        receipt: String,
        screen: String,
        gate: String,
        testName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let query = InboundLinkCatalog.sampleQuery(for: row.path)
        XCTAssertNotNil(MiniProgramPageLink(path: row.path, query: query), row.path, file: file, line: line)
        var urls = [
            InboundLinkCatalog.httpsRoute(path: row.path, query: query),
            InboundLinkCatalog.mpRoute(scheme: "chein", path: row.path, query: query),
            InboundLinkCatalog.mpRoute(scheme: "chengyin", path: row.path, query: query),
            InboundLinkCatalog.appRoute(path: row.path, query: query),
            InboundLinkCatalog.appMPRoute(path: row.path, query: query),
        ]
        if let kind = NativeContentTarget.Kind.allCases.first(where: { $0.sourcePath == "/" + row.path }),
           let host = shortHost(kind), query["id"] == "7" {
            urls.append("chein://\(host)/7")
            urls.append("chengyin://\(host)/7")
            urls.append(InboundLinkCatalog.origin + "/app/\(host)/7")
        }
        for url in urls {
            let decision = decide(url)
            XCTAssertEqual(decision.screenName, screen, url, file: file, line: line)
            XCTAssertEqual(decision.gate, gate, url, file: file, line: line)
            XCTAssertEqual(decision.testName, testName, url, file: file, line: line)
            XCTAssertTrue(receipt.contains(url), url, file: file, line: line)
        }
    }

    private func shortHost(_ kind: NativeContentTarget.Kind) -> String? {
        switch kind {
        case .activity: return "activity"
        case .club: return "club"
        case .topic: return "topic"
        case .template: return "template"
        case .post: return "post"
        case .poi, .roamSession: return nil
        }
    }
}
