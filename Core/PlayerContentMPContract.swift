import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Wire contracts for player-content mini-program `sendRequest` calls at hengyin
/// `chengyinhub-xcx` `25eb6a0c`. Paths, methods, and field names match that source.
/// Money writes and the pricing grant stay off: those builders refuse before a request exists.
/// Nothing here is called from App screens.
public enum PlayerContentMPContract {
    public static let moneyEnabled = false
    public static let pricingGrantEnabled = false

    public enum Refusal: Error, Equatable {
        case moneyDisabled
        case pricingGrantDisabled
        case invalidBase
    }

    public struct TicketPrice: Equatable, Sendable {
        public let ticketID: Int
        public let price: Int
        public init(ticketID: Int, price: Int) {
            self.ticketID = ticketID
            self.price = price
        }
    }

    public static let productListPath = "api/marketing/product/list"
    public static let likeListPath = "api/topic/like_list"
    public static let likePath = "api/topic/like"
    public static let exploreCatalogPath = "api/free-explore/bundle/catalog"
    public static let playSetupPath = "api/play/setup"
    public static let safetyCheckPath = "api/orient/safety/check"
    public static let quotePath = "api/registration/quote"
    public static let commentAddPath = "api/comment/add"
    public static let betaGraduatePath = "api/topic/beta/graduate"
    public static let transferToClubPath = "api/topic/transfer-to-club"
    public static let registrationCreatePath = "api/registration/create"
    public static let addressListPath = "api/user/address/list"
    public static let addressActionPath = "api/user/address/action"
    public static let referenceSettlementNotePath = "api/fe/reference-settlement/note"
    public static let recruitSlotQrcodePath = "api/topic/recruit-slot-qrcode"
    public static let displayTermsPath = "api/coop/offer/display-terms"
    public static let offerRemovePath = "api/merchant/chapter-application/offer/remove"
    public static let topicTemplateListPath = "api/template/topic-template/list"
    public static let templateListPath = "api/template/list"
    public static let topicTemplateInfoPath = "api/template/topic-template/info"
    public static let templateInfoPath = "api/template/info"
    public static let templateMyInfoPath = "api/template/myinfo"
    public static let topicTemplateUsePath = "api/template/topic-template/use"
    public static let officialEventsPath = "api/official/events"
    public static let officialMyEventsPath = "api/official/my-events"
    public static let officialCanPublishPath = "api/official/can-publish"
    public static let categoryListPath = "api/category/list"
    public static let cityNodesPath = "api/city/nodes"
    public static let topicListPath = "api/topic/list"
    public static let activityListPath = "api/activity/list"
    public static let clubListPath = "api/club/list"
    public static let merchantListPath = "api/merchant/list"
    public static let clubDetailPath = "api/club/detail"
    public static let merchantPublicDetailPath = "api/merchant/public-detail"
    public static let saleStatusPath = "api/topic/pricing/sale-status"
    public static let settlementPendingPath = "api/topic/pricing/settlement-pending"
    public static let pricingPreviewPath = "api/topic/pricing/preview"
    public static let pricingConfirmPath = "api/topic/pricing/confirm"

    /// `pages/topic/index/index.js` product list. `topicID` is omitted on the limit-only reads.
    public static func productList(baseURL: URL, topicID: Int?, limit: Int) throws -> URLRequest {
        var query = [(String, String)]()
        if let topicID { query.append(("topicId", String(topicID))) }
        query.append(("limit", String(limit)))
        return try get(baseURL, productListPath, query)
    }

    /// `pages/topic/index/index.js` like list. POST form, no JSON header.
    public static func likeList(baseURL: URL, pageNum: Int, pageSize: Int) throws -> URLRequest {
        try form(baseURL, likeListPath, [("pageNum", String(pageNum)), ("pageSize", String(pageSize))])
    }

    /// `pages/topic/index/index.js` like. `type` is 1 or 0. The host grant stays off; this only builds the wire body.
    public static func like(baseURL: URL, id: Int, type: Int) throws -> URLRequest {
        try form(baseURL, likePath, [("id", String(id)), ("type", String(type))])
    }

    /// `pages/topic/index/index.js` free-explore catalog.
    public static func exploreCatalog(baseURL: URL, topicID: Int) throws -> URLRequest {
        try get(baseURL, exploreCatalogPath, [("topicId", String(topicID))])
    }

    /// `pages/topic/index/index.js` play setup.
    public static func playSetup(baseURL: URL, topicID: Int) throws -> URLRequest {
        try get(baseURL, playSetupPath, [("topicId", String(topicID))])
    }

    /// `pages/topic/index/index.js` safety check. JSON body `{topicId}`.
    public static func safetyCheck(baseURL: URL, topicID: Int) throws -> URLRequest {
        try json(baseURL, safetyCheckPath, [("topicId", .int(topicID))])
    }

    /// `pages/topic/index/index.js` quote. Read of a price. This contract does not send it.
    public static func registrationQuote(baseURL: URL, ownerType: Int, ownerID: Int) throws -> URLRequest {
        if !moneyEnabled { throw Refusal.moneyDisabled }
        return try json(baseURL, quotePath, [("ownerType", .int(ownerType)), ("ownerId", .int(ownerID))])
    }

    /// `pages/topic/index/index.js` comment add. POST form.
    public static func commentAdd(baseURL: URL, ownerType: Int, ownerID: Int, rating: Int, contents: String, replyID: Int, images: String) throws -> URLRequest {
        try form(baseURL, commentAddPath, [
            ("owner_type", String(ownerType)),
            ("owner_id", String(ownerID)),
            ("rating", String(rating)),
            ("contents", contents),
            ("reply_id", String(replyID)),
            ("img_arr", images),
        ])
    }

    /// `pages/topic/index/index.js` beta graduate. POST form.
    public static func betaGraduate(baseURL: URL, topicID: Int) throws -> URLRequest {
        try form(baseURL, betaGraduatePath, [("topicId", String(topicID))])
    }

    /// `pages/topic/index/index.js` transfer. POST form, not JSON.
    public static func transferToClub(baseURL: URL, topicID: Int, clubID: Int) throws -> URLRequest {
        try form(baseURL, transferToClubPath, [("topicId", String(topicID)), ("clubId", String(clubID))])
    }

    /// `pages/topic/index/index.js` registration create. Money write. Refused while `moneyEnabled` is false.
    public static func registrationCreate(
        baseURL: URL, ownerType: Int, ownerID: Int, realName: String, phone: String,
        isUsePoint: Int, requestID: String, quoteSign: String?, sourceClubID: Int?, sourceChannelCode: String?
    ) throws -> URLRequest {
        if !moneyEnabled { throw Refusal.moneyDisabled }
        var fields: [(String, Wire)] = [
            ("ownerType", .int(ownerType)),
            ("ownerId", .int(ownerID)),
            ("realName", .text(realName)),
            ("phone", .text(phone)),
            ("isUsePoint", .int(isUsePoint)),
            ("requestId", .text(requestID)),
        ]
        if let quoteSign { fields.append(("quoteSign", .text(quoteSign))) }
        if let sourceClubID { fields.append(("sourceClubId", .int(sourceClubID))) }
        if let sourceChannelCode { fields.append(("sourceChannelCode", .text(sourceChannelCode))) }
        return try json(baseURL, registrationCreatePath, fields)
    }

    /// `pages/topic/index/index.js` address list. POST form, empty data.
    public static func addressList(baseURL: URL) throws -> URLRequest {
        try form(baseURL, addressListPath, [])
    }

    /// `pages/topic/utils/checkout-profile.js` `participantPayload`, sent from topic index.
    public static func addressAction(baseURL: URL, fullName: String, mobilePhone: String, isDefault: Int, requestID: String) throws -> URLRequest {
        try form(baseURL, addressActionPath, [
            ("fullName", fullName),
            ("mobilePhone", mobilePhone),
            ("isDefault", String(isDefault)),
            ("requestId", requestID),
        ])
    }

    /// `pages/topic/components/cy/chapter-node-form/index.js` settlement note.
    public static func referenceSettlementNote(baseURL: URL, chapterID: Int) throws -> URLRequest {
        try get(baseURL, referenceSettlementNotePath, [("chapterId", String(chapterID))])
    }

    /// `pages/topic/merchantinfo/host-layers.js` recruit-slot qrcode. POST form.
    public static func recruitSlotQrcode(baseURL: URL, id: Int, chapterID: Int, scope: String) throws -> URLRequest {
        try form(baseURL, recruitSlotQrcodePath, [
            ("id", String(id)),
            ("chapterId", String(chapterID)),
            ("scope", scope),
        ])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js` display-terms read.
    public static func displayTermsRead(baseURL: URL, offerID: Int) throws -> URLRequest {
        try get(baseURL, displayTermsPath, [("offerId", String(offerID))])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js` display-terms write. JSON, key order of the page literal.
    public static func displayTermsWrite(
        baseURL: URL, offerID: Int, included: Int, extraSpendText: String, reserveRequired: Int,
        dailyCapacity: Int?, validStart: String, soldOutRuleText: String, storefrontImg: String
    ) throws -> URLRequest {
        try json(baseURL, displayTermsPath, [
            ("offerId", .int(offerID)),
            ("included", .int(included)),
            ("extraSpendText", .text(extraSpendText)),
            ("reserveRequired", .int(reserveRequired)),
            ("dailyCapacity", dailyCapacity.map(Wire.int) ?? .null),
            ("validStart", .text(validStart)),
            ("soldOutRuleText", .text(soldOutRuleText)),
            ("storefrontImg", .text(storefrontImg)),
        ])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js` offer remove. JSON.
    public static func offerRemove(baseURL: URL, offerID: Int, reason: String, scope: String) throws -> URLRequest {
        try json(baseURL, offerRemovePath, [
            ("offerId", .int(offerID)),
            ("reason", .text(reason)),
            ("scope", .text(scope)),
        ])
    }

    /// `pages/templatedetail/shelf/index.js` and search topic-template lane. POST form, empty data.
    public static func topicTemplateList(baseURL: URL) throws -> URLRequest {
        try form(baseURL, topicTemplateListPath, [])
    }

    /// `pages/templatedetail/shelf/index.js` play templates. `pageSize` is 50, `pack_type` is 0.
    public static func templateList(baseURL: URL, pageNum: Int, pageSize: Int, packType: Int) throws -> URLRequest {
        try form(baseURL, templateListPath, [
            ("pageNum", String(pageNum)),
            ("pageSize", String(pageSize)),
            ("pack_type", String(packType)),
        ])
    }

    /// `pages/templatedetail/topic-preview` and `topic-detail`. POST form `{id}`.
    public static func topicTemplateInfo(baseURL: URL, id: Int) throws -> URLRequest {
        try form(baseURL, topicTemplateInfoPath, [("id", String(id))])
    }

    /// `pages/templatedetail/templatedetail.js` public detail. POST form `{id, scope: ""}`.
    public static func templateInfo(baseURL: URL, id: Int, scope: String) throws -> URLRequest {
        try form(baseURL, templateInfoPath, [("id", String(id)), ("scope", scope)])
    }

    /// `pages/templatedetail/templatedetail.js` owned detail. POST form `{id, scope}`.
    public static func templateMyInfo(baseURL: URL, id: Int, scope: String) throws -> URLRequest {
        try form(baseURL, templateMyInfoPath, [("id", String(id)), ("scope", scope)])
    }

    /// `pages/templatedetail/utils/topic-adoption.js` `usePayload`, then `requestId` is appended.
    public static func topicTemplateUse(
        baseURL: URL, id: String, scope: String, bindingIntent: String?, sourceContentRevisionID: String?, requestID: String
    ) throws -> URLRequest {
        var fields = [("id", id), ("scope", scope)]
        if let bindingIntent { fields.append(("bindingIntent", bindingIntent)) }
        if let sourceContentRevisionID { fields.append(("sourceContentRevisionId", sourceContentRevisionID)) }
        fields.append(("requestId", requestID))
        return try form(baseURL, topicTemplateUsePath, fields)
    }

    /// `pages/activity/list/index.js` public browse. GET, empty data.
    public static func officialEvents(baseURL: URL) throws -> URLRequest {
        try get(baseURL, officialEventsPath, [])
    }

    /// `pages/activity/list/index.js` mine tab. GET, no data object.
    public static func officialMyEvents(baseURL: URL) throws -> URLRequest {
        try get(baseURL, officialMyEventsPath, [])
    }

    /// `pages/activity/list/index.js` can-publish. GET, no data object.
    public static func officialCanPublish(baseURL: URL) throws -> URLRequest {
        try get(baseURL, officialCanPublishPath, [])
    }

    /// `pages/search2/index.js` category list. POST form.
    public static func categoryList(baseURL: URL, type: Int, parentID: Int) throws -> URLRequest {
        try form(baseURL, categoryListPath, [("type", String(type)), ("parentid", String(parentID))])
    }

    /// `pages/searchmap/index.js` merchant nodes. GET query, key order of the page literal.
    public static func cityNodes(
        baseURL: URL, lat: String, lng: String, radius: Int, keyword: String,
        categoryID: String, tag: String, cityRole: String
    ) throws -> URLRequest {
        try get(baseURL, cityNodesPath, [
            ("lat", lat),
            ("lng", lng),
            ("radius", String(radius)),
            ("keyword", keyword),
            ("categoryId", categoryID),
            ("tag", tag),
            ("cityRole", cityRole),
        ])
    }

    /// `utils/discover-search.js` topic lane. POST form. No `is_my`.
    public static func searchTopicList(baseURL: URL, keyword: String, pageNum: Int, pageSize: Int, categoryID: Int?) throws -> URLRequest {
        var fields = [("keyword", keyword), ("pageNum", String(pageNum)), ("pageSize", String(pageSize))]
        if let categoryID { fields.append(("category_id", String(categoryID))) }
        return try form(baseURL, topicListPath, fields)
    }

    /// `utils/discover-search.js` activity lane. POST form. `is_my` is first.
    public static func searchActivityList(baseURL: URL, keyword: String, pageNum: Int, pageSize: Int, categoryID: Int?) throws -> URLRequest {
        var fields = [
            ("is_my", "0"),
            ("keyword", keyword),
            ("pageNum", String(pageNum)),
            ("pageSize", String(pageSize)),
        ]
        if let categoryID { fields.append(("category_id", String(categoryID))) }
        return try form(baseURL, activityListPath, fields)
    }

    /// `utils/discover-search.js` club lane. JSON.
    public static func searchClubList(baseURL: URL, name: String, categoryID: Int?) throws -> URLRequest {
        var fields: [(String, Wire)] = [("name", .text(name))]
        if let categoryID { fields.append(("categoryId", .int(categoryID))) }
        return try json(baseURL, clubListPath, fields)
    }

    /// `utils/discover-search.js` merchant lane. JSON.
    public static func searchMerchantList(baseURL: URL, name: String, categoryID: Int?) throws -> URLRequest {
        var fields: [(String, Wire)] = [("name", .text(name))]
        if let categoryID { fields.append(("categoryId", .int(categoryID))) }
        return try json(baseURL, merchantListPath, fields)
    }

    /// `utils/discover-search.js` game-template lane. POST form.
    public static func searchGameTemplates(baseURL: URL, keyword: String, categoryID: Int?) throws -> URLRequest {
        var fields = [("keyword", keyword)]
        if let categoryID { fields.append(("category_id", String(categoryID))) }
        return try form(baseURL, templateListPath, fields)
    }

    /// `pages/topic/pricing/partner/index.js` club profile. JSON `{id}`.
    public static func clubDetail(baseURL: URL, id: Int) throws -> URLRequest {
        try json(baseURL, clubDetailPath, [("id", .int(id))])
    }

    /// `pages/topic/pricing/partner/index.js` merchant profile. JSON `{id}`.
    public static func merchantPublicDetail(baseURL: URL, id: Int) throws -> URLRequest {
        try json(baseURL, merchantPublicDetailPath, [("id", .int(id))])
    }

    /// `pages/topic/pricing/index.js` sale status. GET. Blank scope is omitted (`undefined`).
    public static func saleStatus(baseURL: URL, topicID: Int, scope: String?) throws -> URLRequest {
        var query = [("topicId", String(topicID))]
        if let scope, !scope.isEmpty { query.append(("scope", scope)) }
        return try get(baseURL, saleStatusPath, query)
    }

    /// `pages/topic/pricing/index.js` settlement pending. GET. Key order is scope, then topicId.
    public static func settlementPending(baseURL: URL, topicID: Int, scope: String?) throws -> URLRequest {
        var query = [(String, String)]()
        if let scope, !scope.isEmpty { query.append(("scope", scope)) }
        query.append(("topicId", String(topicID)))
        return try get(baseURL, settlementPendingPath, query)
    }

    /// `pages/topic/pricing/index.js` preview. JSON. Guided cost keys are appended only when the page is guided.
    public static func pricingPreview(
        baseURL: URL, topicID: Int, subType: String, scope: String?, guided: Bool, leadCost: Int?, teamSize: Int?
    ) throws -> URLRequest {
        var fields: [(String, Wire)] = [("topicId", .int(topicID)), ("subType", .text(subType))]
        if let scope, !scope.isEmpty { fields.append(("scope", .text(scope))) }
        if guided {
            fields.append(("leadCost", leadCost.map(Wire.int) ?? .null))
            fields.append(("teamSize", teamSize.map(Wire.int) ?? .null))
        }
        return try json(baseURL, pricingPreviewPath, fields)
    }

    /// `pages/topic/pricing/index.js` confirm. Money write. Refused while `pricingGrantEnabled` is false.
    public static func pricingConfirm(
        baseURL: URL, topicID: Int, scope: String?, guidedPrice: Int?, ticketPrices: [TicketPrice],
        leadCost: Int?, teamSize: Int?, selfPrice: Int?
    ) throws -> URLRequest {
        if !pricingGrantEnabled { throw Refusal.pricingGrantDisabled }
        var fields: [(String, Wire)] = [("topicId", .int(topicID))]
        if let scope, !scope.isEmpty { fields.append(("scope", .text(scope))) }
        if let guidedPrice { fields.append(("guidedPrice", .int(guidedPrice))) }
        if !ticketPrices.isEmpty {
            let rows = ticketPrices.map { [("ticketId", Wire.int($0.ticketID)), ("price", Wire.int($0.price))] }
            fields.append(("ticketPrices", .array(rows)))
        }
        if guidedPrice != nil {
            if leadCost != nil || teamSize != nil {
                fields.append(("leadCost", leadCost.map(Wire.int) ?? .null))
                fields.append(("teamSize", teamSize.map(Wire.int) ?? .null))
            }
        }
        if let selfPrice { fields.append(("selfPrice", .int(selfPrice))) }
        return try json(baseURL, pricingConfirmPath, fields)
    }

    /// `pages/activity/official-mine/index.js` recover. POST, no data. Builds the request and does not send it.
    public static func broadcastRecover(baseURL: URL, id: String) throws -> URLRequest {
        guard !id.isEmpty, id.rangeOfCharacter(from: CharacterSet(charactersIn: "/?#")) == nil else {
            throw Refusal.invalidBase
        }
        guard var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw Refusal.invalidBase }
        parts.path = "/" + broadcastRecoverPath(id)
        guard let url = parts.url else { throw Refusal.invalidBase }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        return request
    }

    public static func broadcastRecoverPath(id: String) -> String {
        "api/official/broadcast/\(id)/recover"
    }

    private enum Wire {
        case int(Int)
        case text(String)
        case null
        case array([[(String, Wire)]])
    }

    private static let formType = "application/x-www-form-urlencoded;"
    private static let jsonType = "application/json"

    private static func get(_ base: URL, _ path: String, _ query: [(String, String)]) throws -> URLRequest {
        try make(base, path, "GET", query, nil, jsonType)
    }

    private static func form(_ base: URL, _ path: String, _ fields: [(String, String)]) throws -> URLRequest {
        try make(base, path, "POST", [], formBody(fields), formType)
    }

    private static func json(_ base: URL, _ path: String, _ fields: [(String, Wire)]) throws -> URLRequest {
        try make(base, path, "POST", [], Data(jsonObject(fields).utf8), jsonType)
    }

    private static func make(_ base: URL, _ path: String, _ method: String, _ query: [(String, String)], _ body: Data?, _ contentType: String) throws -> URLRequest {
        guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { throw Refusal.invalidBase }
        parts.path = "/" + path
        if !query.isEmpty {
            parts.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        guard let url = parts.url else { throw Refusal.invalidBase }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    private static func formBody(_ fields: [(String, String)]) -> Data {
        let text = fields.map { "\(formEscape($0.0))=\(formEscape($0.1))" }.joined(separator: "&")
        return Data(text.utf8)
    }

    private static func formEscape(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func jsonObject(_ fields: [(String, Wire)]) -> String {
        "{" + fields.map { "\"\($0.0)\":\(encode($0.1))" }.joined(separator: ",") + "}"
    }

    private static func encode(_ value: Wire) -> String {
        switch value {
        case .int(let number):
            return String(number)
        case .text(let text):
            return jsonString(text)
        case .null:
            return "null"
        case .array(let rows):
            let items = rows.map { row in "{" + row.map { "\"\($0.0)\":\(encode($0.1))" }.joined(separator: ",") + "}" }
            return "[" + items.joined(separator: ",") + "]"
        }
    }

    private static func jsonString(_ value: String) -> String {
        var out = "\""
        for scalar in value.unicodeScalars {
            if scalar.value == 0x22 {
                out += "\\\""
            } else if scalar.value == 0x5C {
                out += "\\\\"
            } else if scalar.value < 0x20 {
                let hex = String(scalar.value, radix: 16)
                out += "\\u" + String(repeating: "0", count: max(0, 4 - hex.count)) + hex
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        out += "\""
        return out
    }
}
