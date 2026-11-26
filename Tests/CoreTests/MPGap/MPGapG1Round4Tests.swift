import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class MPGapR4MockTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var responseBody = #"{"code":200,"data":{}}"#
    var statusCode = 200

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(responseBody.utf8), statusCode)
    }
}

final class MPGapG1Round4Tests: XCTestCase {
    func testJourneyFinishOfferResolver() {
        let pass = JourneyFinishOfferPassInput(
            enabled: true,
            holdingActive: false,
            libraryCount: 5,
            monthPlanTitle: "城瘾30天通行证",
            monthPlanPriceFen: 3900
        )
        let product = JourneyFinishOfferProductInput(
            productID: 101,
            productKind: 2,
            productName: "外滩城市包",
            cashPrice: 68,
            pointsPrice: nil,
            coveredTopicIDs: [20, 30]
        )

        // Merchant view never sees offer
        XCTAssertNil(JourneyFinishOfferResolver.resolve(isMerchantView: true, pass: pass, products: [product], currentTopicID: 10))

        // Active pass holder never sees offer
        let activePass = JourneyFinishOfferPassInput(enabled: true, holdingActive: true, libraryCount: 5, monthPlanTitle: "月卡", monthPlanPriceFen: 3900)
        XCTAssertNil(JourneyFinishOfferResolver.resolve(isMerchantView: false, pass: activePass, products: [product], currentTopicID: 10))

        // Pass offer wins when enabled
        let passOffer = JourneyFinishOfferResolver.resolve(isMerchantView: false, pass: pass, products: [product], currentTopicID: 10)
        XCTAssertEqual(passOffer?.kind, .pass)
        XCTAssertEqual(passOffer?.priceText, "¥39.00")
        XCTAssertEqual(passOffer?.analyticsProperties["planCode"], "MONTH")
        let passTrack = passOffer?.trackPayload(topicID: "10")
        XCTAssertEqual(passTrack?.bizType, "platform_pass")
        XCTAssertNil(passTrack?.bizID)
        XCTAssertEqual(passTrack?.properties["offerKind"], .string("pass"))
        XCTAssertEqual(passTrack?.properties["planCode"], .string("MONTH"))
        XCTAssertEqual(passTrack?.properties["topicId"], .integer(10))
        XCTAssertNil(passTrack?.properties["name"])
        XCTAssertTrue(AnalyticsEventClient.allowedEvents.contains(JourneyFinishOfferAnalytics.shown))
        XCTAssertTrue(AnalyticsEventClient.allowedEvents.contains(JourneyFinishOfferAnalytics.click))
        XCTAssertFalse(PlayStageAnalyticsGate.enabled)

        // Falls back to product covering another route
        let prodOffer = JourneyFinishOfferResolver.resolve(isMerchantView: false, pass: nil, products: [product], currentTopicID: 10)
        XCTAssertEqual(prodOffer?.kind, .product)
        XCTAssertEqual(prodOffer?.id, "101")
        XCTAssertEqual(prodOffer?.priceText, "¥68.00")
    }

    func testPlayRoamRound4Models() {
        let strip = RoamCityStripSummary(cityName: "上海", activeEventsCount: 3, liveTeamsCount: 4)
        XCTAssertEqual(strip.cityName, "上海")

        let pin = IdentityPinBadge3DParameters(badgeCode: "PIN_01", categoryTrack: 2)
        XCTAssertEqual(pin.hintKey, "objects.badge3d.hint.pin")
        XCTAssertEqual(pin.rarityTier, 2)

        let pileItem = ObjectCardPileItem(id: "c1", title: "外滩时钟", thumbnailURL: nil)
        XCTAssertEqual(pileItem.title, "外滩时钟")
    }

    @MainActor
    func testPlayerContentRound4ServicePaths() async {
        let transport = MPGapR4MockTransport()
        let service = PlayerContentRound4Service(baseURL: URL(string: "https://example.com")!, token: { "tok-1234" }, transport: transport)

        _ = await service.contactHost(inviteID: 12)
        _ = await service.submitMarketingConsent(merchantRowID: 5, merchantOwnerMemberID: 8, optedIn: true, requestID: "req-4")

        XCTAssertEqual(transport.requests.compactMap { $0.url?.path }, [
            "/api/coop/contact",
            "/api/merchant/crm/marketing-consents"
        ])
    }

    /// R7-PC-B1-12: MP utils/marketing-consent-entry.js pickOffer (:24-41).
    func testMarketingConsentPickOffer() {
        let row: PlayWireValue = .object(["merchantOwnerMemberId": .integer(7), "merchantRowId": .integer(41), "merchantName": .string("咖啡馆")])
        XCTAssertEqual(MarketingConsentOffer.pick([row], ownerMemberID: 7),
                       MarketingConsentOffer(merchantRowID: 41, merchantOwnerMemberID: 7, merchantName: "咖啡馆"))
        XCTAssertNil(MarketingConsentOffer.pick([row, row], ownerMemberID: 7))
        XCTAssertNil(MarketingConsentOffer.pick([row], ownerMemberID: 8))
        let opted: PlayWireValue = .object(["merchantOwnerMemberId": .integer(7), "merchantRowId": .integer(41), "inAppOptedIn": .bool(true)])
        XCTAssertNil(MarketingConsentOffer.pick([opted], ownerMemberID: 7))
    }
}
