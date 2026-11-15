import XCTest
import SwiftUI
import UIKit
@testable import Questify

@MainActor final class NewFeatureViewsAndModelsTests: XCTestCase {
    private final class StubTransport: HTTPTransport {
        var handler: ((URLRequest) throws -> (Data, Int))?
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            if let handler { return try handler(request) }
            return (Data(#"{"code":404}"#.utf8), 404)
        }
    }

    private func pumpRunLoop(seconds: TimeInterval = 0.08) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func assertFits<V: View>(_ view: V, width: CGFloat = 320, colorScheme: ColorScheme = .dark, localeID: String = "zh-Hans", sizeCategory: ContentSizeCategory = .accessibilityExtraExtraExtraLarge) {
        let hosted = view
            .environment(\.colorScheme, colorScheme)
            .environment(\.locale, Locale(identifier: localeID))
            .environment(\.sizeCategory, sizeCategory)
        let controller = UIHostingController(rootView: AnyView(hosted))
        controller.loadViewIfNeeded()
        let size = controller.sizeThatFits(in: CGSize(width: width, height: 3200))
        pumpRunLoop(seconds: 0.04)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertLessThanOrEqual(size.width, width + 1, "Horizontal overflow in \(localeID) \(colorScheme)")
        XCTAssertGreaterThan(size.height, 0)
        XCTAssertLessThan(size.height, 6000)
    }

    // MARK: - RoamTerritoryView

    func testRoamTerritoryViewUnavailableAndPopulatedTabsLayout() throws {
        // Unavailable state (service == nil) renders without overflowing at 320pt accessibility size.
        assertFits(NavigationStack { RoamTerritoryView(service: nil) }, colorScheme: .dark, localeID: "zh-Hans")
        assertFits(NavigationStack { RoamTerritoryView(service: nil) }, colorScheme: .light, localeID: "en")

        let stub = StubTransport()
        stub.handler = { req in
            let path = req.url?.path ?? ""
            if path.hasSuffix("api/roam/territory/nearby") {
                return (Data(#"{"code":200,"data":{"boardId":"b1","seasonId":"s1","revenueMode":"POINTS","items":[{"territoryId":"t1","title":"断桥南口石碑","latitude":30.2591,"longitude":120.1514,"radiusM":120,"claimed":false,"ownerRevenuePoints":20,"checkinTollPoints":5,"checkinCount":0,"revenueTotalPoints":0,"status":"UNCLAIMED","isProtected":false}]}}"#.utf8), 200)
            }
            if path.hasSuffix("api/roam/territory/my") {
                return (Data(#"{"code":200,"data":[{"territoryId":"my-1","title":"柳浪闻莺","ownerRevenuePoints":30,"checkinTollPoints":6,"revenueMode":"POINTS","checkinCount":4,"revenueTotalPoints":120}]}"#.utf8), 200)
            }
            if path.hasSuffix("api/roam/territory/leaderboard") {
                return (Data(#"{"code":200,"data":{"boardId":"b1","revenueMode":"POINTS","leaders":[{"ownerMemberId":11,"ownerNickname":"西湖客","territoryCount":2,"totalRevenuePoints":400,"totalCheckins":10}],"topTerritories":[]}}"#.utf8), 200)
            }
            return (Data(#"{"code":200,"data":{"boardId":"b1","rolls":[]}}"#.utf8), 200)
        }
        let base = URL(string: "https://city.example.test/prod-api/")!
        let lease = try XCTUnwrap(CityGameProductionLease(host: "city.example.test", regionID: "hz"))
        let service = try RoamTerritoryService(configuration: APIConfiguration(baseURL: base), token: "tok-1", lease: lease, transport: stub, isCurrent: { true })
        let cityService = try CityGameHTTPService(configuration: APIConfiguration(baseURL: base), token: "tok-1", lease: lease, transport: stub, isCurrent: { true })

        for tab in RoamTerritoryView.Tab.allCases {
            assertFits(RoamTerritoryView(service: service, cityGameService: cityService, boardId: "b1", initialTab: tab))
        }
    }

    // MARK: - PlayAudioClipStreamView

    func testPlayAudioClipStreamViewLayoutInBothWriteModes() throws {
        let config = try PlayAudioClipConfiguration(minDurationSeconds: 5)
        let writable = NavigationStack {
            PlayAudioClipStreamView(configuration: config, canWrite: true, uploadAudio: { _, _ in "https://cdn.example/a.m4a" }, onSubmit: { _ in })
        }
        let readonly = NavigationStack {
            PlayAudioClipStreamView(configuration: config, canWrite: false, uploadAudio: { _, _ in "https://cdn.example/a.m4a" }, onSubmit: { _ in })
        }
        assertFits(writable, colorScheme: .dark, localeID: "zh-Hans")
        assertFits(readonly, colorScheme: .light, localeID: "en")
    }

    // MARK: - PlayKitNewGameForms & CYScratchCard

    func testPlayKitNewGameFormsAndCYScratchCardLayout() throws {
        let session = try PlayExperienceSession(accountID: 1, epoch: 1, namespace: "unit-test", token: "tok-1")
        let stub = StubTransport()
        let config = try APIConfiguration(baseURL: URL(string: "https://example.com")!)
        let service = PlayExperienceService(configuration: config, transport: stub, enabled: [.reads, .advanced])
        let model = PlayAdvancedCoordinator(activityID: 41, topicID: 71, nodeID: 701, service: service, currentSession: { session })

        for kind: PlayKitScreenKind in [.trueFalse, .imageGuess, .jigsaw, .scratchCard] {
            assertFits(NavigationStack { PlayKitScreen(model: model, kind: kind) }, colorScheme: .dark, localeID: "zh-Hans")
        }

        let coveredCard = CYScratchCard(coverLabel: "轻滑刮开隐藏线索", threshold: 0.45, enabled: true, revealed: false) {
            Text(verbatim: "隐藏线索内容")
        }
        let revealedCard = CYScratchCard(coverLabel: nil, threshold: 0.45, enabled: true, revealed: true) {
            Text(verbatim: "已解锁宝藏坐标")
        }
        assertFits(coveredCard, colorScheme: .dark, localeID: "zh-Hans")
        assertFits(revealedCard, colorScheme: .light, localeID: "en")
    }

    // MARK: - PublishTabRootView

    func testPublishTabRootViewLayoutAtAccessibilitySize() {
        assertFits(NavigationStack { PublishTabRootView().environmentObject(AppSession()) }, colorScheme: .dark, localeID: "zh-Hans")
        assertFits(NavigationStack { PublishTabRootView().environmentObject(AppSession()) }, colorScheme: .light, localeID: "en")
    }

    // MARK: - ExternalGameReviewModel Monetization & Creator Sheet

    func testExternalGameReviewModelMonetizationAndCreatorSheet() async throws {
        let stub = StubTransport()
        stub.handler = { req in
            let path = req.url?.path ?? ""
            if path == ExternalGameReviewPaths.monetization("g-1") && req.httpMethod == "GET" {
                return (Data(#"{"code":200,"data":{"gameId":"g-1","gameName":"西湖寻宝","pricingMode":"PAID","priceFen":500,"currency":"CNY","creatorShareBps":7000,"channelFeeBearer":0,"trafficRewardMode":"POINTS","rewardPerPlayPoints":10,"rewardPerPlayFen":0,"dailyUserCap":3,"dailyGameCap":50,"minDurationMs":10000,"reviewStatus":"APPROVED","entitled":false,"isOwner":false,"moneyGateOpen":false}}"#.utf8), 200)
            }
            if path == ExternalGameReviewPaths.monetization("g-1") && req.httpMethod == "PUT" {
                return (Data(#"{"code":200,"data":{"gameId":"g-1","gameName":"西湖寻宝","pricingMode":"TRAFFIC_ONLY","priceFen":0,"currency":"CNY","creatorShareBps":7000,"channelFeeBearer":1,"trafficRewardMode":"POINTS","rewardPerPlayPoints":15,"rewardPerPlayFen":0,"dailyUserCap":5,"dailyGameCap":100,"minDurationMs":15000,"reviewStatus":"PENDING","entitled":false,"isOwner":true,"moneyGateOpen":false}}"#.utf8), 200)
            }
            if path == ExternalGameReviewPaths.creatorSummary {
                return (Data(#"{"code":200,"data":{"paidOrders":4,"grossSalesFen":2000,"creatorSalesNetFen":1400,"trafficValidPlays":20,"trafficSettledPoints":300,"trafficSettledFen":0,"moneyGateOpen":false,"payoutGateOpen":false,"configs":[]}}"#.utf8), 200)
            }
            if path == ExternalGameReviewPaths.nodeBinding(99) {
                return (Data(#"{"code":200,"data":{"bound":true}}"#.utf8), 200)
            }
            return (Data(#"{"code":404}"#.utf8), 404)
        }

        let review = ExternalGameReviewModel(store: ExternalGameStore())
        // Production host refuses client payment trigger safely.
        let prodSession = ExternalGameSessionBridge(baseURL: URL(string: "https://www.chengyinhub.com")!, token: "tok-1", transport: stub)
        await review.loadMonetization(gameID: "g-1", session: prodSession)
        XCTAssertEqual(review.monetizationByGame["g-1"]?.priceFen, 500)

        let purchased = await review.purchaseGame(gameID: "g-1", session: prodSession)
        XCTAssertFalse(purchased)
        XCTAssertFalse(review.notice.isEmpty)

        await review.loadCreatorSummary(session: prodSession)
        XCTAssertEqual(review.creatorSummary?.paidOrders, 4)

        let saved = await review.saveMonetization(gameID: "g-1", pricingMode: "TRAFFIC_ONLY", priceFen: 0, trafficRewardMode: "POINTS", channelFeeBearer: 1, session: prodSession)
        XCTAssertTrue(saved)
        XCTAssertEqual(review.monetizationByGame["g-1"]?.pricingMode, "TRAFFIC_ONLY")

        let bound = await review.bindNode(nodeID: 99, gameID: "g-1", minScore: 80, session: prodSession)
        XCTAssertTrue(bound)

        assertFits(ExternalGameCreatorMonetizationSheet(model: review, session: prodSession), colorScheme: .dark, localeID: "zh-Hans")
    }
}
