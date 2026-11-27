import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Platform pass and market client.
/// Source: hengyin `chengyinhub-xcx` `1c80c5aea8f721ca8575e6108048495b100f5576`
/// (`subpackageMember/utils/platform-pass.js`, `pass-library.js`, `market-view.js`,
/// `market/pass`, `market/gift`, `market/membership`, `market/library`, `market/passes`).
/// Quote, marketing order, product pay, pass pay, and gift claim send only while the payment
/// host switch is on. A missing host leaves that switch off, and those methods still throw.
/// Purchase stays refused: that call would pick a payment channel. Virtual goods stay off.
/// Cancel, confirm, and refund-apply keep their own switch.
public struct PlatformPass: @unchecked Sendable {
    public static let miniProgramCommit = "1c80c5aea8f721ca8575e6108048495b100f5576"
    public static var moneyEnabled: Bool { ReleaseMoneyWriteSwitch.paymentEnabled }

    /// TEST-only switch for cancel, confirm, and refund-apply. Nil (the default) sends nothing.
    /// Pay, gift claim, payout, and withdrawal do not read this switch.
    public enum OrderWriteKind: String, Sendable {
        case cancel, confirm, refundApply
    }
#if DEBUG || TEST
    nonisolated(unsafe) public static var orderWriteTestDerivation: (@Sendable (OrderWriteKind) -> Bool)?
#endif
    public static func orderWriteEnabled(_ kind: OrderWriteKind) -> Bool {
#if DEBUG || TEST
        orderWriteTestDerivation?(kind) == true
#else
        false
#endif
    }
    /// China production admits cancel, confirm, and refund-apply only while the matching
    /// TEST derivation is on. Release is always false, so those POSTs stay refused.
    public static func admitsTestOrderWrite(_ path: String) -> Bool {
        guard let kind = orderWriteKind(path) else { return false }
        return orderWriteEnabled(kind)
    }
    public static func orderWriteKind(_ path: String) -> OrderWriteKind? {
        let key = ChinaReviewedRouteCapability.normalized(path)
        guard key.hasPrefix("/api/platform-pass/orders/") else { return nil }
        if key.hasSuffix("/cancel") { return .cancel }
        if key.hasSuffix("/confirm") { return .confirm }
        if key.hasSuffix("/refund-apply") { return .refundApply }
        return nil
    }

    public static let overviewPath = "api/platform-pass"
    public static let libraryPath = "api/platform-pass/library"
    public static let productListPath = "api/marketing/product/list"
    public static let ordersPath = "api/marketing/product/orders"
    public static let giftsBoughtPath = "api/marketing/product/gifts/bought"
    public static let giftsReceivedPath = "api/marketing/product/gifts/received"
    public static let pointsPath = "api/user/info"
    /// Owner 2026-11-24: players may read platform-pass orders. This is a read, not a money write.
    public static let orderReadsEnabled = true

    public static let purchasePath = "api/platform-pass/orders"
    /// GET on the purchase URL lists the viewer's own pass orders (`market/passes` 我的订单). POST stays refused.
    public static let passOrdersPath = "api/platform-pass/orders"
    /// POST `api/platform-pass/orders/{orderNo}/cancel` with no body. Compiled, never sent.
    public static let cancelOrderPath = "api/platform-pass/orders/{}/cancel"
    /// POST `api/platform-pass/orders/{orderNo}/confirm` with no body. Compiled, never sent.
    public static let confirmOrderPath = "api/platform-pass/orders/{}/confirm"
    /// POST `api/platform-pass/orders/{orderNo}/refund-apply` JSON `{reason}`. Compiled, never sent.
    public static let refundApplyPath = "api/platform-pass/orders/{}/refund-apply"
    public static let refundApplyField = "reason"
    /// GET `api/marketing/product/{id}` (`market/pass` detail).
    public static let productDetailPrefix = "api/marketing/product/"
    /// POST `api/public-catalog/list`: the theme library (`market/library`) reads the public catalog, not the pass
    /// switch, so guests, merchants and everyone while the pass is off still see the catalog.
    public static let publicCatalogListPath = "api/public-catalog/list"
    public static let quotePath = "api/marketing/product/quote"
    public static let orderPath = "api/marketing/product/order"
    public static let claimPath = "api/marketing/product/gifts/claim"
    /// GET `api/marketing/product/orders/{orderNo}` (`market/pass` `_verify`). Read only.
    public static let productOrderDetailPath = "api/marketing/product/orders/{}"
    /// POST `api/marketing/product/orders/{orderNo}/pay`. The page sends no `data` key.
    public static let productOrderPayPath = "api/marketing/product/orders/{}/pay"
    /// POST `api/platform-pass/orders/{orderNo}/pay` (`platform-pass-pay.js`). Field `jsCode`, or `{}` when absent.
    public static let passOrderPayPath = "api/platform-pass/orders/{}/pay"

    public static var writesReachable: Bool {
        moneyEnabled && ReleaseMoneyWriteSwitch.paymentEnabled
    }

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    /// GET `/api/platform-pass`. A merchant viewer returns before the request (membership page).
    public func overview(token: String, viewerIsMerchant: Bool) async throws -> PlatformPassOverview {
        if viewerIsMerchant { return .merchantBlocked }
        let data = try await get(Self.overviewPath, query: [], token: token)
        return try PlatformPassOverview.decode(data)
    }

    /// GET `/api/platform-pass/library`. `kind` is `all`, `city`, or `free`. Merchants do not read it.
    public func library(kind: String, token: String, viewerIsMerchant: Bool) async throws -> PlatformPassLibrary {
        if viewerIsMerchant { return .merchantBlocked }
        let query = try Self.libraryQuery(kind)
        let data = try await get(Self.libraryPath, query: query, token: token)
        return try PlatformPassLibrary.decode(data)
    }

    /// GET `/api/marketing/product/list?limit=20`.
    /// The on-sale list is public in the mini-program: a guest (nil token) reads it without a session.
    public func productList(token: String?) async throws -> [PlatformPassProduct] {
        let data = try await get(Self.productListPath, query: [URLQueryItem(name: "limit", value: "20")], token: token)
        return try PlatformPassProduct.decodeList(data)
    }

    /// GET `/api/marketing/product/orders?limit=20`.
    public func orders(token: String) async throws -> [PlatformPassOrder] {
        let data = try await get(Self.ordersPath, query: [URLQueryItem(name: "limit", value: "20")], token: token)
        return try PlatformPassOrder.decodeList(data)
    }

    /// GET bought and received gift lists. Either failure fails the read; nothing is claimed.
    public func gifts(token: String) async throws -> PlatformPassGifts {
        let bought = try await get(Self.giftsBoughtPath, query: [URLQueryItem(name: "limit", value: "20")], token: token)
        let received = try await get(Self.giftsReceivedPath, query: [URLQueryItem(name: "limit", value: "20")], token: token)
        return try PlatformPassGifts.decode(bought: bought, received: received)
    }

    /// GET `/api/marketing/product/{id}`, the detail read `market/pass` uses. Ids the route table would not
    /// normalise to `/api/marketing/product/{}` (for example `order`, `quote`, `list`) are refused before sending.
    public func product(id: String, token: String?) async throws -> PlatformPassProduct {
        guard G6CapabilitySource.productIDAllowed(id) else { throw APIError.invalidRequest }
        let data = try await get(Self.productDetailPrefix + id, query: [], token: token)
        guard let row = PlatformPassJSON.dictionary(data), let product = PlatformPassProduct.decode(row) else {
            throw APIError.malformedResponse
        }
        return product
    }

    /// POST `/api/public-catalog/list` `{locale, sort, product_type?, pageNum: 1, pageSize: 100}` (`pass-library.js`).
    /// The token is optional: the catalog is public. "¥0 可玩" only when a row says `passCovered === true`.
    public func publicLibrary(kind: String, token: String?) async throws -> [PlatformPassLibraryCard] {
        var body: [String: Any] = ["locale": "zh-CN", "sort": "NEWEST", "pageNum": 1, "pageSize": 100]
        switch kind {
        case "all": break
        case "city": body["product_type"] = "1"
        case "free": body["product_type"] = "2"
        default: throw APIError.invalidRequest
        }
        if let token, !AuthRequestBuilder.isValidToken(token) { throw APIError.invalidRequest }
        var request = URLRequest(url: try url(Self.publicCatalogListPath, query: []))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        if let token { request.setValue(token, forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let (bytes, status) = try await transport.send(request)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let object = try PlatformPassJSON.object(bytes)
        guard PlatformPassJSON.isBizOK(object) else { throw APIError.businessCode(PlatformPassJSON.code(object["code"]) ?? -1) }
        guard let page = PlatformPassJSON.dictionary(PlatformPassJSON.dataValue(object)),
              let rows = PlatformPassJSON.rows(page["rows"]) else { throw APIError.malformedResponse }
        return rows.compactMap { PlatformPassJSON.dictionary($0).flatMap(PlatformPassLibraryCard.catalog) }
    }

    /// GET `/api/platform-pass/orders?limit=20`: the viewer's own city-pass subscription orders.
    /// Merchants do not read it. The read gate stays on; purchase never sends.
    public func passOrders(token: String, viewerIsMerchant: Bool = false) async throws -> [PlatformPassSubscriptionOrder] {
        guard Self.orderReadsEnabled, !viewerIsMerchant else { return [] }
        let data = try await get(Self.passOrdersPath, query: [URLQueryItem(name: "limit", value: "20")], token: token)
        guard let rows = PlatformPassJSON.rows(data) else { throw APIError.malformedResponse }
        return rows.compactMap { PlatformPassJSON.dictionary($0).flatMap(PlatformPassSubscriptionOrder.decode) }
    }

    /// GET `/api/platform-pass/orders/{orderNo}` (`market/pass-order`). Read only: pay, cancel and refund stay off.
    public func passOrderDetail(orderNo: String, token: String, viewerIsMerchant: Bool = false) async throws -> PlatformPassSubscriptionOrder {
        guard Self.orderReadsEnabled, !viewerIsMerchant else { throw APIError.notConfigured }
        guard PlatformPassSubscriptionOrder.orderNoAllowed(orderNo) else { throw APIError.invalidRequest }
        let data = try await get(Self.passOrdersPath + "/" + orderNo, query: [], token: token)
        guard let row = PlatformPassJSON.dictionary(data), let order = PlatformPassSubscriptionOrder.decode(row) else {
            throw APIError.malformedResponse
        }
        return order
    }

    /// POST `/api/user/info` and read `point`. Missing or non-numeric stays nil, never 0.
    public func points(token: String) async throws -> Double? {
        let object = try await send(Self.pointsPath, method: "POST", query: [], token: token)
        guard let data = PlatformPassJSON.dictionary(PlatformPassJSON.dataValue(object)) else { return nil }
        return PlatformPassJSON.number(data["point"])
    }

    /// Pass-market point read. Posts `userInfoRequest` (`member_id`) and reads `point`. No pass write.
    public func points(token: String, memberID: Int) async throws -> Double? {
        guard memberID > 0, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var request = try AccountPublishMPContract.userInfoRequest(
            baseURL: configuration.baseURL, memberID: String(memberID), token: token)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, status) = try await transport.send(request)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let object = try PlatformPassJSON.object(bytes)
        guard PlatformPassJSON.isBizOK(object) else { throw APIError.businessCode(PlatformPassJSON.code(object["code"]) ?? -1) }
        guard let data = PlatformPassJSON.dictionary(PlatformPassJSON.dataValue(object)) else { return nil }
        return PlatformPassJSON.number(data["point"])
    }

    /// Platform-pass purchase. Stays refused: the page only continues for channel `XPAY`, and this client does not pick a provider.
    public func purchase(planCode: String, channel: String, token: String) throws -> Never {
        _ = (planCode, channel, token, Self.moneyEnabled, Self.writesReachable, Self.purchasePath)
        throw PlatformPassWriteRefusal.unreachable
    }

    /// POST `api/marketing/product/quote` `{productId, quantity: 1, fulfillmentKind}`.
    /// `fulfillmentKind` is the page's 自己用 (1) or 送给好友 (2). Sends only while payment is on.
    public func quote(productID: String, token: String, fulfillmentKind: Int = 1) async throws -> PlatformPassQuote {
        try refuseUnlessPayment(Self.quotePath)
        let productId = try Self.productID(productID)
        try Self.requireFulfillment(fulfillmentKind)
        let object = try await postJSON(Self.quotePath, token: token, body: [
            "productId": productId, "quantity": 1, "fulfillmentKind": fulfillmentKind
        ])
        guard let row = PlatformPassJSON.dictionary(PlatformPassJSON.dataValue(object)) else { throw APIError.malformedResponse }
        return PlatformPassQuote.decode(row, productID: String(productId), fulfillmentKind: fulfillmentKind)
    }

    /// POST `api/marketing/product/order`. The body is the server quote echoed back (`market-view.js` `orderRequest`).
    /// `payMode` is the mode the caller already chose from `availablePayModes` (cash 1, points 2). This method does not pick one.
    public func order(productID: String, token: String, payMode: Int, quoteSign: String, quoteExpiresAt: Int,
                      requestID: String, fulfillmentKind: Int = 1) async throws -> PlatformPassOrder {
        try refuseUnlessPayment(Self.orderPath)
        let productId = try Self.productID(productID)
        guard payMode == 1 || payMode == 2, quoteExpiresAt > 0, !quoteSign.isEmpty, !requestID.isEmpty else {
            throw APIError.invalidRequest
        }
        try Self.requireFulfillment(fulfillmentKind)
        let object = try await postJSON(Self.orderPath, token: token, body: [
            "productId": productId, "payMode": payMode, "quantity": 1, "fulfillmentKind": fulfillmentKind,
            "quoteSign": quoteSign, "quoteExpiresAt": quoteExpiresAt, "requestId": requestID
        ])
        guard let row = PlatformPassJSON.dictionary(PlatformPassJSON.dataValue(object)),
              let order = PlatformPassOrder.decode(row) else { throw APIError.malformedResponse }
        return order
    }

    /// POST `api/marketing/product/gifts/claim` `{token, requestId}`. Sends only while payment is on.
    public func claim(giftToken: String, requestID: String, token: String) async throws -> PlatformPassClaimReceipt {
        try refuseUnlessPayment(Self.claimPath)
        let gift = giftToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gift.isEmpty, !requestID.isEmpty else { throw APIError.invalidRequest }
        let object = try await postJSON(Self.claimPath, token: token, body: ["token": gift, "requestId": requestID])
        guard let row = PlatformPassJSON.dictionary(PlatformPassJSON.dataValue(object)) else { throw APIError.malformedResponse }
        return PlatformPassClaimReceipt(registrationID: PlatformPassJSON.text(row["registrationId"]))
    }

    /// POST `api/marketing/product/orders/{orderNo}/pay` (`market/pass` `_payCash`).
    /// The page sends no `data` key; the JSON body is `{}`. No provider field is added.
    public func payProductOrder(orderNo: String, token: String) async throws -> PlatformPassPayReceipt {
        try refuseUnlessPayment(Self.productOrderPayPath)
        guard PlatformPassSubscriptionOrder.orderNoAllowed(orderNo) else { throw APIError.invalidRequest }
        let object = try await postJSON("api/marketing/product/orders/\(orderNo)/pay", token: token, body: [:])
        guard PlatformPassJSON.dictionary(PlatformPassJSON.dataValue(object)) != nil else { throw APIError.malformedResponse }
        return PlatformPassPayReceipt(orderNo: orderNo)
    }

    /// POST `api/platform-pass/orders/{orderNo}/pay`. Body is `{jsCode}` or `{}` when `jsCode` is empty.
    /// The code is the one the caller already holds. This method does not choose a provider.
    public func payPassOrder(orderNo: String, jsCode: String, token: String) async throws -> PlatformPassPayReceipt {
        try refuseUnlessPayment(Self.passOrderPayPath)
        guard PlatformPassSubscriptionOrder.orderNoAllowed(orderNo) else { throw APIError.invalidRequest }
        let body: [String: Any] = jsCode.isEmpty ? [:] : ["jsCode": jsCode]
        let object = try await postJSON("api/platform-pass/orders/\(orderNo)/pay", token: token, body: body)
        guard PlatformPassJSON.dictionary(PlatformPassJSON.dataValue(object)) != nil else { throw APIError.malformedResponse }
        return PlatformPassPayReceipt(orderNo: orderNo)
    }

    /// `POST api/platform-pass/orders/{orderNo}/cancel` (`market/pass-order` `onCancelOrder`).
    /// The page sends no `data` key. Its `request()` sets `content-type: application/json`, and the
    /// request client substitutes `{}`. Compiled, never sends. `moneyEnabled` stays false.
    public static func passOrderCancelPath(orderNo: String) -> String {
        "api/platform-pass/orders/\(orderNo)/cancel"
    }

    /// `POST api/platform-pass/orders/{orderNo}/confirm` (`platform-pass-pay.js` `proceed`).
    /// No `data` key, same JSON `{}` body. Compiled, never sends.
    public static func passOrderConfirmPath(orderNo: String) -> String {
        "api/platform-pass/orders/\(orderNo)/confirm"
    }

    /// `POST api/platform-pass/orders/{orderNo}/refund-apply` with `{reason}` (`onRefundSubmit`).
    /// Compiled, never sends.
    public static func passOrderRefundApplyPath(orderNo: String) -> String {
        "api/platform-pass/orders/\(orderNo)/refund-apply"
    }

    public static func passOrderCancelRequest(baseURL: URL, orderNo: String, token: String) throws -> URLRequest {
        try passOrderJSON(baseURL: baseURL, path: passOrderCancelPath(orderNo: orderNo), orderNo: orderNo, token: token, body: [:])
    }

    public static func passOrderConfirmRequest(baseURL: URL, orderNo: String, token: String) throws -> URLRequest {
        try passOrderJSON(baseURL: baseURL, path: passOrderConfirmPath(orderNo: orderNo), orderNo: orderNo, token: token, body: [:])
    }

    public static func passOrderRefundApplyRequest(baseURL: URL, orderNo: String, reason: String, token: String) throws -> URLRequest {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIError.invalidRequest }
        return try passOrderJSON(baseURL: baseURL, path: passOrderRefundApplyPath(orderNo: orderNo), orderNo: orderNo, token: token, body: ["reason": trimmed])
    }

    /// Cancel, confirm, and refund-apply success body: `code` 200 or `"200"`, then one order.
    /// The page reads `data.status` and `data.refund.reviewStatus`.
    public static func decodeOrderEnvelope(_ data: Data) throws -> PlatformPassSubscriptionOrder {
        let object = try PlatformPassJSON.object(data)
        guard PlatformPassJSON.isBizOK(object),
              let row = PlatformPassJSON.dictionary(PlatformPassJSON.dataValue(object)),
              let order = PlatformPassSubscriptionOrder.decode(row) else { throw APIError.malformedResponse }
        return order
    }

    /// Cancel. Compiled, never sends.
    public func cancelPassOrder(orderNo: String, token: String) throws -> Never {
        _ = (orderNo, token, Self.moneyEnabled, Self.writesReachable, Self.passOrderCancelPath(orderNo: orderNo))
        throw PlatformPassWriteRefusal.unreachable
    }

    /// Confirm. Compiled, never sends.
    public func confirmPassOrder(orderNo: String, token: String) throws -> Never {
        _ = (orderNo, token, Self.moneyEnabled, Self.writesReachable, Self.passOrderConfirmPath(orderNo: orderNo))
        throw PlatformPassWriteRefusal.unreachable
    }

    /// Refund apply. The synchronous entry stays unreachable. `moneyEnabled` stays false.
    public func refundApplyPassOrder(orderNo: String, reason: String, token: String) throws -> Never {
        _ = (orderNo, reason, token, Self.moneyEnabled, Self.writesReachable, Self.passOrderRefundApplyPath(orderNo: orderNo))
        throw PlatformPassWriteRefusal.unreachable
    }

    /// Sends cancel only when `orderWriteEnabled(.cancel)` is true. Otherwise throws and sends nothing.
    public func sendCancelPassOrder(orderNo: String, token: String) async throws -> PlatformPassSubscriptionOrder {
        try await sendOrderWrite(.cancel) {
            try Self.passOrderCancelRequest(baseURL: configuration.baseURL, orderNo: orderNo, token: token)
        }
    }

    /// Sends confirm only when `orderWriteEnabled(.confirm)` is true. Otherwise throws and sends nothing.
    public func sendConfirmPassOrder(orderNo: String, token: String) async throws -> PlatformPassSubscriptionOrder {
        try await sendOrderWrite(.confirm) {
            try Self.passOrderConfirmRequest(baseURL: configuration.baseURL, orderNo: orderNo, token: token)
        }
    }

    /// Sends refund-apply only when `orderWriteEnabled(.refundApply)` is true. Otherwise throws and sends nothing.
    public func sendRefundApplyPassOrder(orderNo: String, reason: String, token: String) async throws -> PlatformPassSubscriptionOrder {
        try await sendOrderWrite(.refundApply) {
            try Self.passOrderRefundApplyRequest(baseURL: configuration.baseURL, orderNo: orderNo, reason: reason, token: token)
        }
    }

    /// A missing host leaves `paymentEnabled` false. Virtual-goods paths stay refused even if payment is on.
    private func refuseUnlessPayment(_ path: String) throws {
        guard let host = configuration.baseURL.host, !host.isEmpty else { throw PlatformPassWriteRefusal.unreachable }
        guard ReleaseMoneyWriteSwitch.paymentEnabled else { throw PlatformPassWriteRefusal.unreachable }
        if ReleaseMoneyWriteSwitch.kind(for: path) == .virtualGoods { throw PlatformPassWriteRefusal.unreachable }
    }

    private static func productID(_ raw: String) throws -> Int {
        guard let id = Int(raw), id > 0, String(id) == raw else { throw APIError.invalidRequest }
        return id
    }

    private static func requireFulfillment(_ kind: Int) throws {
        guard kind == 1 || kind == 2 else { throw APIError.invalidRequest }
    }

    private func postJSON(_ path: String, token: String, body: [String: Any]) async throws -> [String: Any] {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var request = URLRequest(url: try url(path, query: []))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let (bytes, status) = try await transport.send(request)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let object = try PlatformPassJSON.object(bytes)
        guard PlatformPassJSON.isBizOK(object) else { throw APIError.businessCode(PlatformPassJSON.code(object["code"]) ?? -1) }
        return object
    }

    private func sendOrderWrite(_ kind: OrderWriteKind, request: () throws -> URLRequest) async throws -> PlatformPassSubscriptionOrder {
        guard Self.orderWriteEnabled(kind) else { throw PlatformPassWriteRefusal.unreachable }
        let built = try request()
        try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(built)
        let (data, status) = try await transport.send(built)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        return try Self.decodeOrderEnvelope(data)
    }

    private static func passOrderJSON(baseURL: URL, path: String, orderNo: String, token: String, body: [String: String]) throws -> URLRequest {
        guard PlatformPassSubscriptionOrder.orderNoAllowed(orderNo), AuthRequestBuilder.isValidToken(token) else {
            throw APIError.invalidRequest
        }
        let built = path.split(separator: "/").reduce(baseURL) { partial, part in
            partial.appendingPathComponent(String(part))
        }
        var request = URLRequest(url: built)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return request
    }

    private static func libraryQuery(_ kind: String) throws -> [URLQueryItem] {
        var query = [URLQueryItem(name: "limit", value: "100")]
        switch kind {
        case "all": break
        case "city": query.append(URLQueryItem(name: "productType", value: "1"))
        case "free": query.append(URLQueryItem(name: "productType", value: "2"))
        default: throw APIError.invalidRequest
        }
        return query
    }

    private func get(_ path: String, query: [URLQueryItem], token: String?) async throws -> Any {
        let object = try await send(path, method: "GET", query: query, token: token)
        guard let data = PlatformPassJSON.dataValue(object) else { throw APIError.malformedResponse }
        return data
    }

    private func send(_ path: String, method: String, query: [URLQueryItem], token: String?) async throws -> [String: Any] {
        if let token, !AuthRequestBuilder.isValidToken(token) { throw APIError.invalidRequest }
        var request = URLRequest(url: try url(path, query: query))
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        if let token { request.setValue(token, forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, status) = try await transport.send(request)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let object = try PlatformPassJSON.object(bytes)
        guard PlatformPassJSON.isBizOK(object) else { throw APIError.businessCode(PlatformPassJSON.code(object["code"]) ?? -1) }
        return object
    }

    private func url(_ path: String, query: [URLQueryItem]) throws -> URL {
        let built = path.split(separator: "/").reduce(configuration.baseURL) { partial, part in
            partial.appendingPathComponent(String(part))
        }
        guard !query.isEmpty else { return built }
        var parts = URLComponents(url: built, resolvingAgainstBaseURL: false)
        parts?.queryItems = query
        guard let url = parts?.url else { throw APIError.invalidRequest }
        return url
    }
}

public enum PlatformPassWriteRefusal: Error, Equatable, Sendable {
    case unreachable
}

/// Marketing quote (`market/pass` `quote`). Amounts stay on the server; the caller does not invent a pay mode.
public struct PlatformPassQuote: Equatable, Sendable {
    public let productID: String
    public let quantity: Int
    public let fulfillmentKind: Int
    public let quoteSign: String?
    public let quoteExpiresAt: Int?
    public let availablePayModes: [Int]

    public init(productID: String, quantity: Int, fulfillmentKind: Int, quoteSign: String?, quoteExpiresAt: Int?, availablePayModes: [Int]) {
        self.productID = productID
        self.quantity = quantity
        self.fulfillmentKind = fulfillmentKind
        self.quoteSign = quoteSign
        self.quoteExpiresAt = quoteExpiresAt
        self.availablePayModes = availablePayModes
    }

    static func decode(_ row: [String: Any], productID: String, fulfillmentKind: Int) -> PlatformPassQuote {
        let modes = PlatformPassJSON.rows(row["availablePayModes"])?.compactMap(PlatformPassJSON.int) ?? []
        return PlatformPassQuote(
            productID: PlatformPassJSON.text(row["productId"]) ?? productID,
            quantity: PlatformPassJSON.int(row["quantity"]) ?? 1,
            fulfillmentKind: PlatformPassJSON.int(row["fulfillmentKind"]) ?? fulfillmentKind,
            quoteSign: PlatformPassJSON.text(row["quoteSign"]),
            quoteExpiresAt: PlatformPassJSON.int(row["quoteExpiresAt"]),
            availablePayModes: modes)
    }
}

/// Pay reply. The server `data` object is accepted and not read for a provider.
public struct PlatformPassPayReceipt: Equatable, Sendable {
    public let orderNo: String

    public init(orderNo: String) { self.orderNo = orderNo }
}

/// Gift claim reply. `registrationId` opens the order page when the server sends one.
public struct PlatformPassClaimReceipt: Equatable, Sendable {
    public let registrationID: String?

    public init(registrationID: String?) { self.registrationID = registrationID }
}

public struct PlatformPassPlan: Equatable, Sendable {
    public let code: String
    public let title: String
    public let priceFen: Int
    public let validDays: Int?

    public init(code: String, title: String, priceFen: Int, validDays: Int?) {
        self.code = code
        self.title = title
        self.priceFen = priceFen
        self.validDays = validDays
    }
}

public struct PlatformPassHolding: Equatable, Sendable {
    public let active: Bool
    public let validTo: String?
    public let coverageEnd: String?
    /// MKT-4-4 card facts (backend PlatformPassService.putCardFacts; MP utils/platform-pass.js:119-127).
    /// Each is nil / false when absent, and the card then leaves that fact out.
    public let planLabel: String?
    public let daysTotal: Int?
    public let daysRemaining: Int?
    public let teammateBenefit: Bool
    public let expiring: Bool

    public init(active: Bool, validTo: String?, coverageEnd: String?, planLabel: String? = nil,
                daysTotal: Int? = nil, daysRemaining: Int? = nil, teammateBenefit: Bool = false, expiring: Bool = false) {
        self.active = active
        self.validTo = validTo
        self.coverageEnd = coverageEnd
        // Only the two labels the MP renders; anything else is not drawn.
        self.planLabel = planLabel == "年卡" || planLabel == "月卡" ? planLabel : nil
        let resolvedTotal = daysTotal.flatMap { $0 > 0 ? $0 : nil }
        self.daysTotal = resolvedTotal
        self.daysRemaining = resolvedTotal.flatMap { total in daysRemaining.map { min(total, max(0, $0)) } }
        self.teammateBenefit = teammateBenefit
        self.expiring = expiring
    }
}

/// `utils/platform-pass.js` `passTerms`: a string list, or the older object shape.
/// First matching line wins. `有效期：` is stored without that prefix.
public struct PlatformPassTermFacts: Equatable, Sendable {
    public var period: String?
    public var renewal: String?
    public var refund: String?
    public var seat: String?
    public var coverage: String?
    public static let empty = PlatformPassTermFacts()
    public init(period: String? = nil, renewal: String? = nil, refund: String? = nil, seat: String? = nil, coverage: String? = nil) {
        self.period = period; self.renewal = renewal; self.refund = refund; self.seat = seat; self.coverage = coverage
    }

    static func parse(_ value: Any?) -> PlatformPassTermFacts {
        if let lines = PlatformPassJSON.rows(value) {
            var facts = PlatformPassTermFacts()
            for line in lines {
                guard let raw = line as? String else { continue }
                let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty { continue }
                let key: WritableKeyPath<PlatformPassTermFacts, String?>
                var stored = text
                if text.range(of: #"^有效期[：:]"#, options: .regularExpression) != nil {
                    key = \.period
                    stored = text.replacingOccurrences(of: #"^有效期[：:]\s*"#, with: "", options: .regularExpression)
                } else if text.contains("续费") { key = \.renewal }
                else if text.contains("退款") { key = \.refund }
                else if text.contains("本人") || text.contains("同行") { key = \.seat }
                else { key = \.coverage }
                if facts[keyPath: key] == nil { facts[keyPath: key] = stored }
            }
            return facts
        }
        if let object = PlatformPassJSON.dictionary(value) {
            return PlatformPassTermFacts(
                period: PlatformPassJSON.text(object["period"]),
                renewal: PlatformPassJSON.text(object["renewal"]),
                refund: PlatformPassJSON.text(object["refund"]),
                seat: PlatformPassJSON.text(object["seat"]),
                coverage: PlatformPassJSON.text(object["coverage"]))
        }
        return .empty
    }
}

public struct PlatformPassOverview: Equatable, Sendable {
    public let enabled: Bool
    public let merchantBlocked: Bool
    public let libraryCount: Int?
    public let plans: [PlatformPassPlan]
    public let holding: PlatformPassHolding
    public let jsapiAvailable: Bool
    public let xpayAvailable: Bool
    /// Server `overview.terms`, normalized the way `passTerms` does.
    public let terms: PlatformPassTermFacts

    public static let merchantBlocked = PlatformPassOverview(
        enabled: false, merchantBlocked: true, libraryCount: nil, plans: [],
        holding: PlatformPassHolding(active: false, validTo: nil, coverageEnd: nil),
        jsapiAvailable: false, xpayAvailable: false)

    public init(enabled: Bool, merchantBlocked: Bool, libraryCount: Int?, plans: [PlatformPassPlan],
                holding: PlatformPassHolding, jsapiAvailable: Bool, xpayAvailable: Bool,
                terms: PlatformPassTermFacts = .empty) {
        self.enabled = enabled
        self.merchantBlocked = merchantBlocked
        self.libraryCount = libraryCount
        self.plans = plans
        self.holding = holding
        self.jsapiAvailable = jsapiAvailable
        self.xpayAvailable = xpayAvailable
        self.terms = terms
    }

    static func decode(_ data: Any) throws -> PlatformPassOverview {
        guard let object = PlatformPassJSON.dictionary(data) else { throw APIError.malformedResponse }
        let plans = PlatformPassJSON.array(object["plans"]).compactMap { row -> PlatformPassPlan? in
            guard let code = PlatformPassJSON.text(row["planCode"]), let price = PlatformPassJSON.int(row["priceFen"]) else { return nil }
            return PlatformPassPlan(code: code, title: PlatformPassJSON.text(row["title"]) ?? "", priceFen: price,
                                    validDays: PlatformPassJSON.int(row["validDays"]))
        }
        let holding = PlatformPassJSON.dictionary(object["holding"]) ?? [:]
        let channels = PlatformPassJSON.dictionary(object["channels"]) ?? [:]
        return PlatformPassOverview(
            enabled: PlatformPassJSON.flag(object["enabled"]),
            merchantBlocked: false,
            libraryCount: PlatformPassJSON.int(object["libraryCount"]),
            plans: plans,
            holding: PlatformPassHolding(active: PlatformPassJSON.flag(holding["active"]),
                                         validTo: PlatformPassJSON.text(holding["validTo"]),
                                         coverageEnd: PlatformPassJSON.text(holding["coverageEnd"]),
                                         planLabel: PlatformPassJSON.text(holding["planLabel"]),
                                         daysTotal: PlatformPassJSON.int(holding["daysTotal"]),
                                         daysRemaining: PlatformPassJSON.int(holding["daysRemaining"]),
                                         teammateBenefit: PlatformPassJSON.flag(holding["teammateBenefit"]),
                                         expiring: PlatformPassJSON.text(holding["badge"]) == "EXPIRING"),
            jsapiAvailable: PlatformPassJSON.flag(PlatformPassJSON.dictionary(channels["jsapi"])?["available"]),
            xpayAvailable: PlatformPassJSON.flag(PlatformPassJSON.dictionary(channels["xpay"])?["available"]),
            terms: PlatformPassTermFacts.parse(object["terms"]))
    }
}

public struct PlatformPassLibraryCard: Equatable, Sendable {
    public let id: String
    public let title: String
    public let cover: String
    public let city: String
    public let kind: String
    public let data: String
    public let free: Bool
    public let tags: [String]
    /// Server `productType`: 1 city orienteering, 2 free explore. Nil when the row omitted it.
    public let productType: Int?
    /// Whole minutes from `totalTime` seconds. Nil when the duration is missing; never a stand-in 0.
    public let minuteCount: Int?
}

public struct PlatformPassLibrary: Equatable, Sendable {
    public let enabled: Bool
    public let covered: Bool
    public let merchantBlocked: Bool
    public let cards: [PlatformPassLibraryCard]

    public static let merchantBlocked = PlatformPassLibrary(enabled: false, covered: false, merchantBlocked: true, cards: [])

    static func decode(_ data: Any) throws -> PlatformPassLibrary {
        guard let object = PlatformPassJSON.dictionary(data) else { throw APIError.malformedResponse }
        let enabled = PlatformPassJSON.flag(object["enabled"])
        let covered = PlatformPassJSON.flag(object["covered"])
        guard enabled else { return PlatformPassLibrary(enabled: false, covered: false, merchantBlocked: false, cards: []) }
        let cards = PlatformPassJSON.array(object["rows"]).compactMap { PlatformPassLibraryCard.make($0, covered: covered) }
        return PlatformPassLibrary(enabled: true, covered: covered, merchantBlocked: false, cards: cards)
    }
}

extension PlatformPassLibraryCard {
    static func make(_ row: [String: Any], covered: Bool) -> PlatformPassLibraryCard? {
        guard let id = PlatformPassJSON.text(row["topicId"]), let name = PlatformPassJSON.text(row["name"]) else { return nil }
        let productType = PlatformPassJSON.int(row["productType"])
        let kind = Self.kind(productType)
        let city = PlatformPassJSON.text(row["addressName"]) ?? ""
        let minuteCount = Self.minuteCount(PlatformPassJSON.number(row["totalTime"]))
        let minutes = minuteCount.map { "约 \($0) 分钟" } ?? ""
        return PlatformPassLibraryCard(
            id: id, title: name, cover: PlatformPassJSON.text(row["imgUrl"]) ?? "", city: city, kind: kind,
            data: [kind, minutes].filter { !$0.isEmpty }.joined(separator: " · "),
            free: covered, tags: [kind, city].filter { !$0.isEmpty },
            productType: productType, minuteCount: minuteCount)
    }

    /// `pass-library.js` `passLibraryCard`: a public-catalog row (`id`, `name`, `imgUrl`, `productType`, `cityName`,
    /// `totalTime`). Free only on a real JSON `passCovered: true`.
    static func catalog(_ row: [String: Any]) -> PlatformPassLibraryCard? {
        guard let id = PlatformPassJSON.text(row["id"]), let name = PlatformPassJSON.text(row["name"]) else { return nil }
        let productType = PlatformPassJSON.int(row["productType"])
        let kind = Self.kind(productType)
        let city = PlatformPassJSON.text(row["cityName"]) ?? ""
        let minuteCount = Self.minuteCount(PlatformPassJSON.number(row["totalTime"]))
        let minutes = minuteCount.map { "约 \($0) 分钟" } ?? ""
        return PlatformPassLibraryCard(
            id: id, title: name, cover: PlatformPassJSON.text(row["imgUrl"]) ?? "", city: city, kind: kind,
            data: [kind, minutes].filter { !$0.isEmpty }.joined(separator: " · "),
            free: PlatformPassJSON.flag(row["passCovered"]), tags: [kind, city].filter { !$0.isEmpty },
            productType: productType, minuteCount: minuteCount)
    }

    private static func kind(_ productType: Int?) -> String {
        switch productType {
        case 1: return "城市定向"
        case 2: return "自由探索"
        default: return ""
        }
    }

    private static func minuteCount(_ seconds: Double?) -> Int? {
        guard let seconds, seconds > 0 else { return nil }
        return max(1, Int((seconds / 60).rounded()))
    }
}

public struct PlatformPassProduct: Equatable, Sendable {
    public let id: String
    public let name: String
    public let kind: String
    public let city: String
    public let validity: String
    public let seats: String
    public let price: String
    public let coverCount: Int
    public let topics: [String]
    public let topicIDs: [String]
    public let giftOnly: Bool
    public let isExtraSeat: Bool
    public let cashPrice: Double?
    public let pointsPrice: Double?
    public let productKind: Int
    public let validityKind: Int?
    public let validDays: Int?

    public init(id: String, name: String, kind: String, city: String, validity: String, seats: String, price: String,
                coverCount: Int, topics: [String], topicIDs: [String], giftOnly: Bool, isExtraSeat: Bool,
                cashPrice: Double?, pointsPrice: Double?, productKind: Int, validityKind: Int?, validDays: Int?) {
        self.id = id
        self.name = name
        self.kind = kind
        self.city = city
        self.validity = validity
        self.seats = seats
        self.price = price
        self.coverCount = coverCount
        self.topics = topics
        self.topicIDs = topicIDs
        self.giftOnly = giftOnly
        self.isExtraSeat = isExtraSeat
        self.cashPrice = cashPrice
        self.pointsPrice = pointsPrice
        self.productKind = productKind
        self.validityKind = validityKind
        self.validDays = validDays
    }

    static func decodeList(_ data: Any) throws -> [PlatformPassProduct] {
        guard let rows = PlatformPassJSON.rows(data) else { throw APIError.malformedResponse }
        return rows.compactMap { PlatformPassJSON.dictionary($0).flatMap(decode) }
    }

    static func decode(_ row: [String: Any]) -> PlatformPassProduct? {
        guard let id = PlatformPassJSON.text(row["productId"]) else { return nil }
        let items = PlatformPassJSON.array(row["items"])
        let kind = PlatformPassJSON.int(row["productKind"]) ?? 0
        let route = PlatformPassJSON.int(row["purchaseRoute"]) ?? 0
        let seats = PlatformPassJSON.int(row["seatCount"])
        return PlatformPassProduct(
            id: id,
            name: PlatformPassJSON.text(row["productName"]) ?? "",
            kind: Self.kindText(kind),
            city: PlatformPassJSON.text(row["saleCity"]) ?? "",
            validity: Self.validity(row),
            seats: (seats ?? 0) > 1 ? "\(seats ?? 0) 人" : "",
            price: Self.price(cash: PlatformPassJSON.number(row["cashPrice"]), points: PlatformPassJSON.number(row["pointsPrice"])),
            coverCount: items.count,
            topics: items.compactMap { PlatformPassJSON.text($0["topicTitle"]) },
            topicIDs: items.compactMap { PlatformPassJSON.text($0["topicId"]) },
            giftOnly: kind == 7,
            isExtraSeat: kind == 8 || route == 3,
            cashPrice: PlatformPassJSON.number(row["cashPrice"]),
            pointsPrice: PlatformPassJSON.number(row["pointsPrice"]),
            productKind: kind,
            validityKind: PlatformPassJSON.int(row["validityKind"]),
            validDays: PlatformPassJSON.int(row["validDays"]))
    }

    private static func kindText(_ kind: Int) -> String {
        switch kind {
        case 1: return "单关票"
        case 2: return "城市包"
        case 3: return "时限通票"
        case 4: return "固定期年卡"
        case 5: return "团体票"
        case 6: return "学校团体票"
        case 7: return "礼品通行证"
        case 8: return "加座"
        default: return ""
        }
    }

    private static func validity(_ row: [String: Any]) -> String {
        switch PlatformPassJSON.int(row["validityKind"]) {
        case 1:
            guard let days = PlatformPassJSON.int(row["validDays"]) else { return "" }
            return "购买后 \(days) 天内有效"
        case 2:
            let from = MPParityChinaClock.dotDay(PlatformPassJSON.text(row["fixedValidFrom"]))
            let to = MPParityChinaClock.dotDay(PlatformPassJSON.text(row["fixedValidTo"]))
            if !from.isEmpty, !to.isEmpty { return "\(from) – \(to)" }
            return to.isEmpty ? "" : "有效至 \(to)"
        case 3:
            guard let days = PlatformPassJSON.int(row["validDays"]) else { return "" }
            return "首次游玩起 \(days) 天内有效"
        default:
            return ""
        }
    }

    private static func price(cash: Double?, points: Double?) -> String {
        var parts: [String] = []
        if let cash { parts.append("¥" + Self.fixed(cash)) }
        if let points { parts.append(Self.plain(points) + " 积分") }
        return parts.joined(separator: " / ")
    }

    private static func fixed(_ value: Double) -> String { PlatformPassNumber.fixed(value) }
    private static func plain(_ value: Double) -> String { PlatformPassNumber.plain(value) }
}

public struct PlatformPassOrder: Equatable, Sendable {
    public let orderNo: String
    public let productID: String
    public let state: String
    public let amount: String
    public let time: String

    public func row(nameByID: [String: String]) -> PlatformPassOrderRow {
        PlatformPassOrderRow(key: orderNo, name: nameByID[productID] ?? "通行证订单", state: state, amount: amount, time: time)
    }

    static func decodeList(_ data: Any) throws -> [PlatformPassOrder] {
        guard let rows = PlatformPassJSON.rows(data) else { throw APIError.malformedResponse }
        return rows.compactMap { PlatformPassJSON.dictionary($0).flatMap(decode) }
    }

    static func decode(_ row: [String: Any]) -> PlatformPassOrder? {
        guard let orderNo = PlatformPassJSON.text(row["orderNo"]) else { return nil }
        let payMode = PlatformPassJSON.int(row["payMode"]) ?? 0
        let amount: String
        if payMode == 2 {
            amount = PlatformPassJSON.number(row["pointsAmount"]).map { Self.plain($0) + " 积分" } ?? ""
        } else {
            amount = PlatformPassJSON.number(row["cashAmount"]).map { "¥" + Self.fixed($0) } ?? ""
        }
        let when = PlatformPassJSON.text(row["paidAt"]) ?? PlatformPassJSON.text(row["createdAt"])
        return PlatformPassOrder(orderNo: orderNo, productID: PlatformPassJSON.text(row["productId"]) ?? "",
                                 state: Self.state(row), amount: amount, time: MPParityChinaClock.dotDay(when))
    }

    private static func state(_ row: [String: Any]) -> String {
        switch PlatformPassJSON.text(row["statusLabel"]) {
        case "PAID":
            if PlatformPassJSON.int(row["fulfillmentState"]) == 2 { return "已购买 · 首次游玩时开始计算有效期" }
            if PlatformPassJSON.int(row["fulfillmentKind"]) == 2 { return "已购买 · 礼品" }
            return "已购买"
        case "PENDING_CASH":
            return "待支付"
        case "CANCELLED":
            return "已取消"
        case "REFUNDED":
            return "已退款"
        default:
            return "状态待确认"
        }
    }

    private static func fixed(_ value: Double) -> String { PlatformPassNumber.fixed(value) }
    private static func plain(_ value: Double) -> String { PlatformPassNumber.plain(value) }
}

enum PlatformPassNumber {
    static func fixed(_ value: Double) -> String {
        let cents = Int((value * 100).rounded())
        let whole = abs(cents) / 100
        let frac = abs(cents) % 100
        return "\(cents < 0 ? "-" : "")\(whole).\(frac < 10 ? "0" : "")\(frac)"
    }

    static func plain(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value.rounded())) }
        return fixed(value)
    }
}

/// One city-pass subscription order (`PlatformPassService.orderView`), shaped like `platform-pass.js` `orderRow`.
/// Every word comes from the server status; an unknown status reads 状态确认中, never a guess.
public struct PlatformPassSubscriptionOrder: Equatable, Sendable {
    public enum Status: String, Sendable { case pending = "PENDING", paid = "PAID", cancelled = "CANCELLED",
                                                refunding = "REFUNDING", refunded = "REFUNDED", unknown = "" }
    public enum RefundDetail: Equatable, Sendable {
        case refunded(amount: String, time: String)
        case rejected(reason: String, time: String)
    }

    public let orderNo: String
    /// `城瘾30天通行证` for MONTH, else `城瘾通行证 · N 天`.
    public let name: String
    /// `30天 · 2026.11.02`.
    public let sub: String
    public let status: Status
    /// Order status word (待付款 / 已开通 / 已取消 / 退款处理中 / 已退款 / 状态确认中).
    public let stateText: String
    /// Refund progress word, empty when there is no application.
    public let refundText: String
    public let refundDetail: RefundDetail?
    /// `¥19.9`, empty when the price is unknown.
    public let amount: String
    /// Paid day `yyyy.MM.dd`, empty when unknown.
    public let time: String
    /// Valid-to day, only for a paid order.
    public let validTo: String
    public let canResume: Bool
    public let canCancel: Bool
    public let canRefund: Bool

    public static func orderNoAllowed(_ orderNo: String) -> Bool {
        !orderNo.isEmpty && orderNo.utf8.count <= 64
            && orderNo.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95 }
    }

    static func decode(_ row: [String: Any]) -> PlatformPassSubscriptionOrder? {
        guard let orderNo = PlatformPassJSON.text(row["orderNo"]), orderNoAllowed(orderNo) else { return nil }
        let status = Status(rawValue: PlatformPassJSON.text(row["status"]) ?? "") ?? .unknown
        let validDays = PlatformPassJSON.int(row["validDays"])
        let name: String
        if PlatformPassJSON.text(row["planCode"]) == "MONTH" { name = "城瘾30天通行证" }
        else { name = "城瘾通行证" + (validDays.map { " · \($0) 天" } ?? "") }
        let paid = day(row["paidTime"])
        let time = paid.isEmpty ? day(row["createdTime"]) : paid
        let sub = [validDays.map { "\($0)天" } ?? "", time].filter { !$0.isEmpty }.joined(separator: " · ")
        let refund = PlatformPassJSON.dictionary(row["refund"]) ?? [:]
        let review = PlatformPassJSON.text(refund["reviewStatus"]) ?? "NONE"
        let stateText: String
        switch status {
        case .pending: stateText = "待付款"
        case .paid: stateText = "已开通"
        case .cancelled: stateText = "已取消"
        case .refunding: stateText = "退款处理中"
        case .refunded: stateText = "已退款"
        case .unknown: stateText = "状态确认中"
        }
        let refundText: String
        if review == "NONE" || status == .refunded { refundText = "" }
        else {
            switch review {
            case "PENDING": refundText = "退款审核中"
            case "APPROVED": refundText = "退款处理中"
            case "REJECTED": refundText = "退款申请未通过"
            default: refundText = "状态确认中"
            }
        }
        var detail: RefundDetail?
        if let fen = PlatformPassJSON.int(refund["refundedFen"]), status == .refunded || review == "APPROVED" {
            detail = .refunded(amount: yuanFen(fen), time: day(refund["decidedTime"]))
        } else if review == "REJECTED" {
            let reason = (refund["decision"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            detail = .rejected(reason: reason, time: day(refund["decidedTime"]))
        }
        return PlatformPassSubscriptionOrder(
            orderNo: orderNo, name: name, sub: sub, status: status, stateText: stateText, refundText: refundText,
            refundDetail: detail, amount: PlatformPassJSON.int(row["priceFen"]).map(yuanFen) ?? "", time: time,
            validTo: status == .paid ? day(row["validTo"]) : "",
            canResume: status == .pending, canCancel: status == .pending,
            canRefund: status == .paid && (review == "NONE" || review == "REJECTED"))
    }

    /// Shared two-decimal yuan (`MoneyDisplay`). Owner 2026-11-24: ¥12.50, never one decimal.
    static func yuanFen(_ fen: Int) -> String {
        MoneyDisplay.yuan(fen: fen)
    }

    /// Server dates arrive as `yyyy-MM-dd HH:mm:ss` (China time), ISO text or epoch numbers.
    private static func day(_ value: Any?) -> String {
        if let text = value as? String { return MPParityChinaClock.dotDay(text) }
        if let ms = PlatformPassJSON.number(value) { return MPParityChinaClock.dotDay(String(Int64(ms))) }
        return ""
    }
}

extension PlatformPassSubscriptionOrder: Identifiable {
    public var id: String { orderNo }
}

public struct PlatformPassOrderRow: Equatable, Sendable {
    public let key: String
    public let name: String
    public let state: String
    public let amount: String
    public let time: String
}

public struct PlatformPassGift: Equatable, Sendable {
    public let key: String
    public let state: String
    public let expires: String
    public let time: String
    public let claimReachable: Bool
    /// Claim deadline as `yyyy.MM.dd`, or empty when this gift has no deadline. The sentence stays in `expires`.
    public let claimDay: String
    /// `productId` on the gift row; MP market-view giftRow names the gift from the on-sale catalog by this id. Empty when absent.
    public let productID: String

    /// MP giftRow `name`: the catalog product name, or empty (the row then leads with its state).
    public func name(nameByID: [String: String]) -> String { nameByID[productID] ?? "" }

    static func decodeList(_ data: Any, side: String) throws -> [PlatformPassGift] {
        guard let rows = PlatformPassJSON.rows(data) else { throw APIError.malformedResponse }
        return rows.compactMap { PlatformPassJSON.dictionary($0).flatMap { decode($0, side: side) } }
    }

    static func decode(_ row: [String: Any], side: String) -> PlatformPassGift? {
        guard let id = PlatformPassJSON.text(row["giftId"]) else { return nil }
        let status = PlatformPassJSON.int(row["status"])
        var state: String
        switch status {
        case 0: state = "待领取"
        case 1: state = "已领取"
        case 2: state = "已过期"
        case 3: state = "已撤销"
        default: state = "状态待确认"
        }
        if side == "bought", status == 0 { state = "待领取 · 领取前你和对方都不能游玩" }
        if side == "bought", status == 3 { state = "已撤销 · 退回给你" }
        let claimDay = status == 0 ? MPParityChinaClock.dotDay(PlatformPassJSON.text(row["claimExpiresAt"])) : ""
        let when = PlatformPassJSON.text(row["claimedAt"]) ?? PlatformPassJSON.text(row["createdAt"])
        return PlatformPassGift(key: side + "-" + id, state: state,
                                expires: claimDay.isEmpty ? "" : "领取截止 \(claimDay)",
                                time: MPParityChinaClock.dotDay(when), claimReachable: false, claimDay: claimDay,
                                productID: PlatformPassJSON.text(row["productId"]) ?? "")
    }
}

public struct PlatformPassGifts: Equatable, Sendable {
    public let bought: [PlatformPassGift]
    public let received: [PlatformPassGift]
    public let claimReachable: Bool

    /// A guest has no gifts to read.
    public static let empty = PlatformPassGifts(bought: [], received: [], claimReachable: false)

    static func decode(bought: Any, received: Any) throws -> PlatformPassGifts {
        PlatformPassGifts(bought: try PlatformPassGift.decodeList(bought, side: "bought"),
                          received: try PlatformPassGift.decodeList(received, side: "received"),
                          claimReachable: false)
    }
}

enum PlatformPassJSON {
    static func object(_ data: Data) throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(with: data)
        guard let object = value as? [String: Any] else { throw APIError.malformedResponse }
        return object
    }

    static func isBizOK(_ object: [String: Any]) -> Bool { code(object["code"]) == 200 }

    static func code(_ value: Any?) -> Int? {
        // No `value is Bool`: on Darwin a JSON NSNumber 0 or 1 bridges to Bool, which turned a real 0 or 1 into nil.
        if value == nil || value is NSNull { return nil }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            let int = number.intValue
            guard number.doubleValue == Double(int) else { return nil }
            return int
        }
        if let text = value as? String { return Int(text) }
        return nil
    }

    static func dataValue(_ object: [String: Any]) -> Any? {
        let value = object["data"]
        if value == nil || value is NSNull { return nil }
        return value
    }

    static func flag(_ value: Any?) -> Bool {
        // Only a real JSON boolean; `as? Bool` would also accept the numbers 0 and 1 on Darwin.
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue }
        return false
    }

    static func number(_ value: Any?) -> Double? {
        // Booleans are rejected by their CFBoolean type below, not `is Bool` (which matches NSNumber 0 and 1 on Darwin).
        if value == nil || value is NSNull { return nil }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            let double = number.doubleValue
            return double.isFinite ? double : nil
        }
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let double = Double(trimmed), double.isFinite else { return nil }
            return double
        }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        guard let double = number(value), double.rounded() == double, double <= Double(Int.max), double >= Double(Int.min) else { return nil }
        return Int(double)
    }

    static func text(_ value: Any?) -> String? {
        if let text = value as? String { return text.isEmpty ? nil : text }
        if let int = int(value) { return String(int) }
        return nil
    }

    static func rows(_ value: Any?) -> [Any]? {
        if let list = value as? [Any] { return list }
        if let list = value as? NSArray { return list.map { $0 } }
        return nil
    }

    static func array(_ value: Any?) -> [[String: Any]] {
        (rows(value) ?? []).compactMap { $0 as? [String: Any] }
    }

    static func dictionary(_ value: Any?) -> [String: Any]? {
        if let object = value as? [String: Any] { return object }
        guard let object = value as? NSDictionary else { return nil }
        var result: [String: Any] = [:]
        for (key, item) in object {
            guard let key = key as? String else { return nil }
            result[key] = item
        }
        return result
    }
}

/// China civil clock for pass dates. Midnight rolls back one millisecond for the "playable through" day,
/// matching `order-status.js` `passUntilText`. Unknown input is empty, never today.
enum MPParityChinaClock {
    static func dotDay(_ raw: String?) -> String {
        guard let ms = MoneyParityTime.timestamp(raw) else { return "" }
        let parts = clock(ms)
        return String(format: "%04d.%02d.%02d", parts.year, parts.month, parts.day)
    }

    /// Mini-program sentence. The App shows the same day through a localized string.
    static func passUntil(_ raw: String?) -> String {
        guard let shown = shown(raw) else { return "" }
        return "可玩至 \(shown.month) 月 \(shown.day) 日"
    }

    static func shownMonthDay(_ raw: String?) -> (month: Int, day: Int)? {
        guard let shown = shown(raw) else { return nil }
        return (shown.month, shown.day)
    }

    private static func shown(_ raw: String?) -> (year: Int, month: Int, day: Int, hour: Int, minute: Int)? {
        guard let ms = MoneyParityTime.timestamp(raw) else { return nil }
        let parts = clock(ms)
        if parts.hour == 0, parts.minute == 0, ms % 60_000 == 0 { return clock(ms - 1) }
        return parts
    }

    private static func clock(_ ms: Int64) -> (year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let date = Date(timeIntervalSince1970: TimeInterval(ms + MoneyParityTime.chinaOffsetMs) / 1000)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return (parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0)
    }
}
