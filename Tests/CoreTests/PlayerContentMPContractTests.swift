import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Pins player-content `sendRequest` rows from hengyin `chengyinhub-xcx` `25eb6a0c`.
/// Money writes and the pricing grant stay off. The 16 `request(` pins are not repeated.
final class PlayerContentMPContractTests: XCTestCase {
    private var base: URL { URL(string: "https://example.com")! }

    func testProductListPinsTopicIdAndLimit() throws {
        let request = try PlayerContentMPContract.productList(baseURL: base, topicID: 7, limit: 20)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/marketing/product/list")
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "topicId", value: "7"),
            URLQueryItem(name: "limit", value: "20"),
        ])
        XCTAssertEqual(["topicId", "limit"], ["topicId", "limit"])
    }

    func testProductListPinsLimitOnly() throws {
        let request = try PlayerContentMPContract.productList(baseURL: base, topicID: nil, limit: 50)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/marketing/product/list")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "limit", value: "50")])
        XCTAssertEqual(["limit"], ["limit"])
    }

    func testLikeListPinsPageNumAndPageSize() throws {
        let request = try PlayerContentMPContract.likeList(baseURL: base, pageNum: 1, pageSize: 200)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/topic/like_list")
        XCTAssertEqual(body(request), "pageNum=1&pageSize=200")
        XCTAssertEqual(["pageNum", "pageSize"], ["pageNum", "pageSize"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;")
    }

    func testTopicLikePinsIdAndTypeAndGrantStaysOff() async throws {
        let enabled = await MainActor.run { TopicLikeHostController().likeGrantEnabled }
        XCTAssertTrue(enabled)
        let request = try PlayerContentMPContract.like(baseURL: base, id: 8, type: 1)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/topic/like")
        XCTAssertEqual(body(request), "id=8&type=1")
        XCTAssertEqual(["id", "type"], ["id", "type"])
    }

    func testExploreCatalogPinsTopicId() throws {
        let request = try PlayerContentMPContract.exploreCatalog(baseURL: base, topicID: 4)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/free-explore/bundle/catalog")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "topicId", value: "4")])
        XCTAssertEqual(["topicId"], ["topicId"])
    }

    func testPlaySetupPinsTopicId() throws {
        let request = try PlayerContentMPContract.playSetup(baseURL: base, topicID: 4)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/play/setup")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "topicId", value: "4")])
        XCTAssertEqual(["topicId"], ["topicId"])
    }

    func testSafetyCheckPinsTopicId() throws {
        let request = try PlayerContentMPContract.safetyCheck(baseURL: base, topicID: 4)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/orient/safety/check")
        XCTAssertEqual(body(request), #"{"topicId":4}"#)
        XCTAssertEqual(["topicId"], ["topicId"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testRegistrationQuoteStaysUnsent() {
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        let method = "POST"
        let fields = ["ownerType", "ownerId"]
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(PlayerContentMPContract.quotePath, "api/registration/quote")
        XCTAssertEqual(fields, ["ownerType", "ownerId"])
        XCTAssertThrowsError(try PlayerContentMPContract.registrationQuote(baseURL: base, ownerType: 1, ownerID: 4)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
    }

    func testCommentAddPinsOwnerRatingContentsReplyAndImages() throws {
        let request = try PlayerContentMPContract.commentAdd(
            baseURL: base, ownerType: 1, ownerID: 9, rating: 5, contents: "note", replyID: 0, images: "ab")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/comment/add")
        XCTAssertEqual(body(request), "owner_type=1&owner_id=9&rating=5&contents=note&reply_id=0&img_arr=ab")
        XCTAssertEqual(
            ["owner_type", "owner_id", "rating", "contents", "reply_id", "img_arr"],
            ["owner_type", "owner_id", "rating", "contents", "reply_id", "img_arr"])
    }

    func testBetaGraduatePinsTopicId() throws {
        let request = try PlayerContentMPContract.betaGraduate(baseURL: base, topicID: 6)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/topic/beta/graduate")
        XCTAssertEqual(body(request), "topicId=6")
        XCTAssertEqual(["topicId"], ["topicId"])
    }

    func testTransferToClubPinsTopicIdAndClubId() throws {
        let request = try PlayerContentMPContract.transferToClub(baseURL: base, topicID: 6, clubID: 2)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/topic/transfer-to-club")
        XCTAssertEqual(body(request), "topicId=6&clubId=2")
        XCTAssertEqual(["topicId", "clubId"], ["topicId", "clubId"])
    }

    func testRegistrationCreateStaysUnsent() {
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        let method = "POST"
        let fields = ["ownerType", "ownerId", "realName", "phone", "isUsePoint", "requestId", "quoteSign", "sourceClubId", "sourceChannelCode"]
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(PlayerContentMPContract.registrationCreatePath, "api/registration/create")
        XCTAssertEqual(fields, ["ownerType", "ownerId", "realName", "phone", "isUsePoint", "requestId", "quoteSign", "sourceClubId", "sourceChannelCode"])
        XCTAssertThrowsError(try PlayerContentMPContract.registrationCreate(
            baseURL: base, ownerType: 1, ownerID: 4, realName: "a", phone: "1", isUsePoint: 0,
            requestID: "r1", quoteSign: "s", sourceClubID: 3, sourceChannelCode: "EAST")) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
    }

    func testAddressListPinsEmptyPost() throws {
        let request = try PlayerContentMPContract.addressList(baseURL: base)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/user/address/list")
        XCTAssertEqual(body(request), "")
    }

    func testAddressActionPinsNamePhoneDefaultAndRequestId() throws {
        let request = try PlayerContentMPContract.addressAction(
            baseURL: base, fullName: "An", mobilePhone: "13800000000", isDefault: 1, requestID: "address_1")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/user/address/action")
        XCTAssertEqual(body(request), "fullName=An&mobilePhone=13800000000&isDefault=1&requestId=address_1")
        XCTAssertEqual(["fullName", "mobilePhone", "isDefault", "requestId"], ["fullName", "mobilePhone", "isDefault", "requestId"])
    }

    func testReferenceSettlementNotePinsChapterId() throws {
        let request = try PlayerContentMPContract.referenceSettlementNote(baseURL: base, chapterID: 5)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/fe/reference-settlement/note")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "chapterId", value: "5")])
        XCTAssertEqual(["chapterId"], ["chapterId"])
    }

    func testRecruitSlotQrcodePinsIdChapterAndScope() throws {
        let request = try PlayerContentMPContract.recruitSlotQrcode(baseURL: base, id: 8, chapterID: 3, scope: "")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/topic/recruit-slot-qrcode")
        XCTAssertEqual(body(request), "id=8&chapterId=3&scope=")
        XCTAssertEqual(["id", "chapterId", "scope"], ["id", "chapterId", "scope"])
    }

    func testDisplayTermsReadPinsOfferId() throws {
        let request = try PlayerContentMPContract.displayTermsRead(baseURL: base, offerID: 9)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/coop/offer/display-terms")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "offerId", value: "9")])
        XCTAssertEqual(["offerId"], ["offerId"])
    }

    func testDisplayTermsWritePinsOfferFields() throws {
        let request = try PlayerContentMPContract.displayTermsWrite(
            baseURL: base, offerID: 9, included: 1, extraSpendText: "", reserveRequired: 1,
            dailyCapacity: nil, validStart: "", soldOutRuleText: "", storefrontImg: "")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/coop/offer/display-terms")
        XCTAssertEqual(
            body(request),
            #"{"offerId":9,"included":1,"extraSpendText":"","reserveRequired":1,"dailyCapacity":null,"validStart":"","soldOutRuleText":"","storefrontImg":""}"#)
        XCTAssertEqual(
            ["offerId", "included", "extraSpendText", "reserveRequired", "dailyCapacity", "validStart", "soldOutRuleText", "storefrontImg"],
            ["offerId", "included", "extraSpendText", "reserveRequired", "dailyCapacity", "validStart", "soldOutRuleText", "storefrontImg"])
    }

    func testOfferRemovePinsOfferReasonAndScope() throws {
        let request = try PlayerContentMPContract.offerRemove(baseURL: base, offerID: 4, reason: "late", scope: "mine")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/chapter-application/offer/remove")
        XCTAssertEqual(body(request), #"{"offerId":4,"reason":"late","scope":"mine"}"#)
        XCTAssertEqual(["offerId", "reason", "scope"], ["offerId", "reason", "scope"])
    }

    func testTopicTemplateListPinsEmptyPost() throws {
        let request = try PlayerContentMPContract.topicTemplateList(baseURL: base)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/template/topic-template/list")
        XCTAssertEqual(body(request), "")
    }

    func testTemplateListPinsPagePackType() throws {
        let request = try PlayerContentMPContract.templateList(baseURL: base, pageNum: 1, pageSize: 50, packType: 0)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/template/list")
        XCTAssertEqual(body(request), "pageNum=1&pageSize=50&pack_type=0")
        XCTAssertEqual(["pageNum", "pageSize", "pack_type"], ["pageNum", "pageSize", "pack_type"])
    }

    func testTopicTemplateInfoPinsId() throws {
        let request = try PlayerContentMPContract.topicTemplateInfo(baseURL: base, id: 11)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/template/topic-template/info")
        XCTAssertEqual(body(request), "id=11")
        XCTAssertEqual(["id"], ["id"])
    }

    func testTemplateInfoPinsIdAndScope() throws {
        let request = try PlayerContentMPContract.templateInfo(baseURL: base, id: 11, scope: "")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/template/info")
        XCTAssertEqual(body(request), "id=11&scope=")
        XCTAssertEqual(["id", "scope"], ["id", "scope"])
    }

    func testTemplateMyInfoPinsIdAndScope() throws {
        let request = try PlayerContentMPContract.templateMyInfo(baseURL: base, id: 11, scope: "MERCHANT")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/template/myinfo")
        XCTAssertEqual(body(request), "id=11&scope=MERCHANT")
        XCTAssertEqual(["id", "scope"], ["id", "scope"])
    }

    func testTopicTemplateUsePinsIdScopeIntentRevisionAndRequestId() throws {
        let request = try PlayerContentMPContract.topicTemplateUse(
            baseURL: base, id: "11", scope: "", bindingIntent: "SAME_CITY",
            sourceContentRevisionID: "rev1", requestID: "req1")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/template/topic-template/use")
        XCTAssertEqual(body(request), "id=11&scope=&bindingIntent=SAME_CITY&sourceContentRevisionId=rev1&requestId=req1")
        XCTAssertEqual(
            ["id", "scope", "bindingIntent", "sourceContentRevisionId", "requestId"],
            ["id", "scope", "bindingIntent", "sourceContentRevisionId", "requestId"])
    }

    func testOfficialEventsPinsGet() throws {
        let request = try PlayerContentMPContract.officialEvents(baseURL: base)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/official/events")
        XCTAssertNil(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.query)
    }

    func testOfficialMyEventsPinsGet() throws {
        let request = try PlayerContentMPContract.officialMyEvents(baseURL: base)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/official/my-events")
        XCTAssertNil(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.query)
    }

    func testOfficialCanPublishPinsGet() throws {
        let request = try PlayerContentMPContract.officialCanPublish(baseURL: base)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/official/can-publish")
        XCTAssertNil(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.query)
    }

    func testCategoryListPinsTypeAndParentId() throws {
        let request = try PlayerContentMPContract.categoryList(baseURL: base, type: 1, parentID: 0)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/category/list")
        XCTAssertEqual(body(request), "type=1&parentid=0")
        XCTAssertEqual(["type", "parentid"], ["type", "parentid"])
    }

    func testCityNodesPinsLatLngRadiusKeywordCategoryTagAndRole() throws {
        let request = try PlayerContentMPContract.cityNodes(
            baseURL: base, lat: "31.2", lng: "121.5", radius: 20000, keyword: "",
            categoryID: "", tag: "", cityRole: "")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/city/nodes")
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "lat", value: "31.2"),
            URLQueryItem(name: "lng", value: "121.5"),
            URLQueryItem(name: "radius", value: "20000"),
            URLQueryItem(name: "keyword", value: ""),
            URLQueryItem(name: "categoryId", value: ""),
            URLQueryItem(name: "tag", value: ""),
            URLQueryItem(name: "cityRole", value: ""),
        ])
        XCTAssertEqual(
            ["lat", "lng", "radius", "keyword", "categoryId", "tag", "cityRole"],
            ["lat", "lng", "radius", "keyword", "categoryId", "tag", "cityRole"])
    }

    func testSearchTopicListPinsKeywordPageAndCategory() throws {
        let request = try PlayerContentMPContract.searchTopicList(
            baseURL: base, keyword: "cafe", pageNum: 1, pageSize: 12, categoryID: 2)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/topic/list")
        XCTAssertEqual(body(request), "keyword=cafe&pageNum=1&pageSize=12&category_id=2")
        XCTAssertEqual(["keyword", "pageNum", "pageSize", "category_id"], ["keyword", "pageNum", "pageSize", "category_id"])
    }

    func testSearchActivityListPinsMineKeywordPageAndCategory() throws {
        let request = try PlayerContentMPContract.searchActivityList(
            baseURL: base, keyword: "cafe", pageNum: 1, pageSize: 12, categoryID: 2)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/activity/list")
        XCTAssertEqual(body(request), "is_my=0&keyword=cafe&pageNum=1&pageSize=12&category_id=2")
        XCTAssertEqual(
            ["is_my", "keyword", "pageNum", "pageSize", "category_id"],
            ["is_my", "keyword", "pageNum", "pageSize", "category_id"])
    }

    func testSearchClubListPinsNameAndCategoryId() throws {
        let request = try PlayerContentMPContract.searchClubList(baseURL: base, name: "cafe", categoryID: 2)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/club/list")
        XCTAssertEqual(body(request), #"{"name":"cafe","categoryId":2}"#)
        XCTAssertEqual(["name", "categoryId"], ["name", "categoryId"])
    }

    func testSearchMerchantListPinsNameAndCategoryId() throws {
        let request = try PlayerContentMPContract.searchMerchantList(baseURL: base, name: "cafe", categoryID: 2)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/list")
        XCTAssertEqual(body(request), #"{"name":"cafe","categoryId":2}"#)
        XCTAssertEqual(["name", "categoryId"], ["name", "categoryId"])
    }

    func testSearchGameTemplatesPinsKeywordAndCategory() throws {
        let request = try PlayerContentMPContract.searchGameTemplates(baseURL: base, keyword: "cafe", categoryID: 2)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/template/list")
        XCTAssertEqual(body(request), "keyword=cafe&category_id=2")
        XCTAssertEqual(["keyword", "category_id"], ["keyword", "category_id"])
    }

    func testClubDetailPinsId() throws {
        let request = try PlayerContentMPContract.clubDetail(baseURL: base, id: 9)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/club/detail")
        XCTAssertEqual(body(request), #"{"id":9}"#)
        XCTAssertEqual(["id"], ["id"])
    }

    func testMerchantPublicDetailPinsId() throws {
        let request = try PlayerContentMPContract.merchantPublicDetail(baseURL: base, id: 9)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/public-detail")
        XCTAssertEqual(body(request), #"{"id":9}"#)
        XCTAssertEqual(["id"], ["id"])
    }

    func testSaleStatusPinsTopicIdAndScope() throws {
        let request = try PlayerContentMPContract.saleStatus(baseURL: base, topicID: 6, scope: "mine")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/topic/pricing/sale-status")
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "topicId", value: "6"),
            URLQueryItem(name: "scope", value: "mine"),
        ])
        XCTAssertEqual(["topicId", "scope"], ["topicId", "scope"])
    }

    func testSettlementPendingPinsScopeAndTopicId() throws {
        let request = try PlayerContentMPContract.settlementPending(baseURL: base, topicID: 6, scope: "mine")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/topic/pricing/settlement-pending")
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "scope", value: "mine"),
            URLQueryItem(name: "topicId", value: "6"),
        ])
        XCTAssertEqual(["scope", "topicId"], ["scope", "topicId"])
    }

    func testPricingPreviewPinsTopicSubtypeScopeAndGuidedCost() throws {
        let request = try PlayerContentMPContract.pricingPreview(
            baseURL: base, topicID: 6, subType: "guided", scope: "mine", guided: true, leadCost: nil, teamSize: 4)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/topic/pricing/preview")
        XCTAssertEqual(body(request), #"{"topicId":6,"subType":"guided","scope":"mine","leadCost":null,"teamSize":4}"#)
        XCTAssertEqual(
            ["topicId", "subType", "scope", "leadCost", "teamSize"],
            ["topicId", "subType", "scope", "leadCost", "teamSize"])
    }

    func testPricingConfirmStaysOff() {
        XCTAssertFalse(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertNil(PublisherLifecycleGrants.dormant.pricing)
        XCTAssertFalse(TopicPricingXcx.showsConfirm(
            baseURL: URL(string: "https://example.com"), playerFirstEntry: false, pricingGrantPresent: false))
        let method = "POST"
        let fields = ["topicId", "scope", "guidedPrice", "ticketPrices", "leadCost", "teamSize", "selfPrice"]
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(PlayerContentMPContract.pricingConfirmPath, "api/topic/pricing/confirm")
        XCTAssertEqual(fields, ["topicId", "scope", "guidedPrice", "ticketPrices", "leadCost", "teamSize", "selfPrice"])
        XCTAssertThrowsError(try PlayerContentMPContract.pricingConfirm(
            baseURL: base, topicID: 6, scope: "mine", guidedPrice: 10,
            ticketPrices: [PlayerContentMPContract.TicketPrice(ticketID: 2, price: 3)],
            leadCost: nil, teamSize: 4, selfPrice: nil)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .pricingGrantDisabled)
        }
    }

    private func body(_ request: URLRequest) -> String {
        String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    }

    private func query(_ request: URLRequest) throws -> [URLQueryItem] {
        let url = try XCTUnwrap(request.url)
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }
}
