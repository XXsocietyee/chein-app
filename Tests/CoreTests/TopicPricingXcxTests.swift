import XCTest
@testable import QuestifyCore

/// w2-07: mini-program `pages/topic/pricing` and `pricing/partner` presentation rules.
final class TopicPricingXcxTests: XCTestCase {
    private func preview(_ object: [String: ProjectEditJSON]) throws -> PublisherPricingPreview { try PublisherPricingPreview(.object(object)) }

    func testFloorSliderAndInitialPrice() {
        XCTAssertEqual(TopicPricingXcx.initialPrice(floor: Decimal(string: "58.2")!), 59)
        XCTAssertEqual(TopicPricingXcx.sliderMax(floor: Decimal(string: "58.2")!, reference: nil), 159)
        XCTAssertEqual(TopicPricingXcx.sliderMax(floor: 200, reference: nil), 400)
        XCTAssertEqual(TopicPricingXcx.sliderMax(floor: 10, reference: 200), 300)
    }

    func testDeltaNeedsReferenceAndSamples() {
        XCTAssertEqual(TopicPricingXcx.delta(price: 120, reference: 100, sampleSize: 4), .above(percent: 20))
        XCTAssertEqual(TopicPricingXcx.delta(price: 100, reference: 100, sampleSize: 4), .notAbove)
        XCTAssertNil(TopicPricingXcx.delta(price: 120, reference: 100, sampleSize: 0))
        XCTAssertNil(TopicPricingXcx.delta(price: 120, reference: nil, sampleSize: 3))
    }

    func testPreviewCarriesPhaseAndChapterSupplyTerms() throws {
        let value = try preview(["priceMin": .number(30), "canConfirm": .bool(false), "lineup": .array([
            .object(["toType": .string("merchant"), "toId": .number(9), "shareMode": .number(0), "chapterId": .number(4), "termsMode": .string("REVSHARE"), "fixedFee": .number(3)]),
            .object(["toType": .string("club"), "toId": .number(5), "shareMode": .number(1), "shareRate": .number(15)]),
            .object(["toType": .string("club"), "toId": .number(6), "shareMode": .number(2), "fixedFee": .string("8")]),
            .object(["toType": .string("club"), "toId": .number(7), "shareMode": .number(0)])])])
        XCTAssertEqual(value.canConfirm, false)
        XCTAssertEqual(value.lineup.map { TopicPricingXcx.terms($0) }, [.chapterRevshare(fee: "3.00"), .share(rate: "15"), .fixed(fee: "8"), .traffic])
        XCTAssertTrue(TopicPricingXcx.opensChapterProject(value.lineup[0]))
        XCTAssertFalse(TopicPricingXcx.opensChapterProject(value.lineup[1]))
        XCTAssertNil(try preview(["priceMin": .number(1)]).canConfirm)
    }

    func testConfirmBlockersFollowSourceOrder() {
        XCTAssertEqual(TopicPricingXcx.blocker(guided: true, teamSize: 0, canConfirm: false, price: 10, floor: 20), .teamSize)
        XCTAssertEqual(TopicPricingXcx.blocker(guided: false, teamSize: nil, canConfirm: false, price: 30, floor: 20), .phase)
        XCTAssertEqual(TopicPricingXcx.blocker(guided: false, teamSize: nil, canConfirm: true, price: 10, floor: 20), .belowFloor)
        XCTAssertNil(TopicPricingXcx.blocker(guided: true, teamSize: 4, canConfirm: nil, price: 20, floor: 20))
    }

    func testPartnerMoneyUnknownIsDashAndZeroStaysZero() throws {
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText(nil), "—")
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText(""), "—")
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText("  "), "—")
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText("UNKNOWN"), "—")
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText("unknown"), "—")
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText("nope"), "—")
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText("0"), "0")
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText(" 0.00 "), "0")
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText("15"), "15")
        let missingFee = try XCTUnwrap(PublisherLineup(.object([
            "toType": .string("merchant"), "toId": .number(1), "shareMode": .number(2)
        ])))
        XCTAssertFalse(missingFee.validTerms)
        XCTAssertNil(missingFee.fixedFee)
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText(missingFee.fixedFee), "—")
        let zeroShare = try XCTUnwrap(PublisherLineup(.object([
            "toType": .string("club"), "toId": .number(9), "shareMode": .number(1), "shareRate": .number(0)
        ])))
        XCTAssertTrue(zeroShare.validTerms)
        XCTAssertEqual(TopicPricingXcx.partnerMoneyText(zeroShare.shareRate), "0")
    }

    func testPartnerPreviewPhaseCoversLoadingEmptyErrorAndUnknown() throws {
        XCTAssertEqual(TopicPricingXcx.partnerPreviewPhase(loading: true, inspection: nil, failed: true), .loading)
        XCTAssertEqual(TopicPricingXcx.partnerPreviewPhase(loading: false, inspection: nil, failed: true), .error)
        XCTAssertEqual(TopicPricingXcx.partnerPreviewPhase(loading: false, inspection: nil, failed: false), .unknown)
        let terms = try XCTUnwrap(PublisherLineup(.object([
            "toType": .string("club"), "toId": .number(9), "shareMode": .number(0)
        ])))
        let bare = PublisherPartnerInspection(terms: terms, profile: .object([
            "name": .string("Club"), "memberCount": .null
        ]))
        XCTAssertEqual(TopicPricingXcx.partnerPreviewPhase(loading: false, inspection: bare, failed: false), .empty(bare))
        XCTAssertNil(TopicPricingXcx.factText(nil))
        XCTAssertNil(TopicPricingXcx.factText(.null))
        XCTAssertEqual(TopicPricingXcx.factText(.number(0)), "0")
        let zeroMembers = PublisherPartnerInspection(terms: terms, profile: .object(["memberCount": .number(0)]))
        XCTAssertEqual(TopicPricingXcx.partnerPreviewPhase(loading: false, inspection: zeroMembers, failed: false), .ready(zeroMembers))
        let listed = PublisherPartnerInspection(terms: terms, profile: .object([
            "leaderName": .string("Lin"), "memberCount": .number(0)
        ]))
        XCTAssertEqual(TopicPricingXcx.partnerPreviewPhase(loading: false, inspection: listed, failed: false), .ready(listed))
    }

    func testMerchantPartnerProfileProjectsHomeFactsWithoutChargeOrZeroFill() throws {
        let filled = try JSONDecoder().decode(PublicMerchantHome.self, from: Data(
            #"{"id":31,"memberId":77,"name":"Owner-bound merchant","description":"Tea","address":" 拱墅 ","businessTime":"09:00-18:00","capacity":0,"availableTime":"周末","suitActivityTypes":"茶会","demand":"场地","sysCategoryList":[{"categoryName":"茶馆"},{"categoryName":"  "}],"chargeType":1}"#.utf8))
        let profile = try XCTUnwrap(TopicPricingXcx.merchantPartnerProfile(filled, ownerMemberID: 77).object)
        XCTAssertEqual(profile["id"], .number(31))
        XCTAssertEqual(profile["memberId"], .number(77))
        XCTAssertEqual(profile["name"]?.text, "Owner-bound merchant")
        XCTAssertEqual(profile["description"]?.text, "Tea")
        XCTAssertEqual(profile["address"]?.text, "拱墅")
        XCTAssertEqual(profile["businessTime"]?.text, "09:00-18:00")
        XCTAssertEqual(profile["capacity"], .number(0))
        XCTAssertEqual(profile["availableTime"]?.text, "周末")
        XCTAssertEqual(profile["suitActivityTypes"]?.text, "茶会")
        XCTAssertEqual(profile["demand"]?.text, "场地")
        XCTAssertEqual(profile["sysCategoryList"], .array([.object(["categoryName": .string("茶馆")])]))
        XCTAssertNil(profile["chargeType"])
        let missing = try JSONDecoder().decode(PublicMerchantHome.self, from: Data(
            #"{"id":31,"memberId":77,"name":"Owner","chargeType":0}"#.utf8))
        let bare = try XCTUnwrap(TopicPricingXcx.merchantPartnerProfile(missing, ownerMemberID: 77).object)
        XCTAssertNil(bare["capacity"])
        XCTAssertNil(bare["chargeType"])
    }

    /// R7-PC-B4-3: MP ticketFee (pages/topic/pricing/index.js:489-495).
    func testPlatformFeeAndTakeHome() throws {
        let texts = try XCTUnwrap(TopicPricingXcx.feeTexts(price: 199, rate: Decimal(string: "0.06")))
        XCTAssertEqual(texts.fee, "¥11.94（6%）")
        XCTAssertEqual(texts.takeHome, "¥187.06")
        XCTAssertNil(TopicPricingXcx.fee(price: 0, rate: Decimal(string: "0.06")))
        XCTAssertNil(TopicPricingXcx.fee(price: 100, rate: nil))
        let preview = try PublisherPricingPreview(.object(["priceMin": .number(10), "platformRate": .string("0.055")]))
        XCTAssertEqual(preview.platformRate, Decimal(string: "0.055"))
        let negative = try PublisherPricingPreview(.object(["priceMin": .number(10), "platformRate": .number(-1)]))
        XCTAssertNil(negative.platformRate)
    }
}
