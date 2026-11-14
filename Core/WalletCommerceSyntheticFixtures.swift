import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if DEBUG
/// Offline earnings-overview bytes for the reads this build already sends.
/// Unknown money is an em dash. A known zero stays 0. This type does not send a withdrawal.
public enum WalletEarningsOverviewFixtureData {
    public static let unknownMoney = "—"
    public static let stagesUnknown = #"{"pendingSettlement":"12.30","disputed":2,"withdrawable":0,"complaintPeriod":[{"availableDate":"2026-10-08","amount":"4.50"}],"amountsKnown":false}"#
    public static let stagesEmpty = #"{"pendingSettlement":0,"disputed":0,"withdrawable":0,"complaintPeriod":[],"amountsKnown":true,"currency":"CNY"}"#
    public static let stagesReady = #"{"pendingSettlement":"1.00","disputed":0,"withdrawable":"3.00","complaintPeriod":[],"amountsKnown":true,"currency":"CNY"}"#
    public static let userInfoReady = #"{"balance":"128.50","currency":"CNY"}"#
    public static let userInfoEmpty = #"{"balance":"0","currency":"CNY"}"#
    public static let errorEnvelope = #"{"code":503}"#
    public enum Outcome: Equatable { case loading, empty, ready, unknown, failed, balanceEmpty, balanceReady }
    public static func envelope(_ body: String) -> (Data, Int) {
        (Data(("{\"code\":200,\"data\":" + body + "}").utf8), 200)
    }
    public static func response(_ outcome: Outcome) -> (Data, Int)? {
        switch outcome {
        case .loading: return nil
        case .empty: return envelope(stagesEmpty)
        case .ready: return envelope(stagesReady)
        case .unknown: return envelope(stagesUnknown)
        case .failed: return (Data(errorEnvelope.utf8), 503)
        case .balanceEmpty: return envelope(userInfoEmpty)
        case .balanceReady: return envelope(userInfoReady)
        }
    }
    /// Unknown, missing, or not-yet-loaded money is an em dash. A known zero stays the digit 0.
    public static func moneyText(known: Bool, amount: Decimal?) -> String {
        guard known, let amount else { return unknownMoney }
        return NSDecimalNumber(decimal: amount).stringValue
    }
}

/// Offline only; all IDs and financial values are invented test data. Never a live factory.
public enum WalletIncomeDetailFixtureData {
    public static let incomeList = #"{"rows":[{"id":4,"changeBalance":"8.50","changeType":1,"eventType":4,"changeReason":"Synthetic withdrawal rejection return"}],"total":1}"#
    public static let emptyList = #"{"rows":[],"total":0}"#
    public static let unknownAmount = #"{"rows":[{"id":1,"changeType":1,"eventType":1,"changeReason":"Synthetic missing amount"}],"total":1}"#
    public static let knownZero = #"{"rows":[{"id":2,"changeBalance":"0","changeType":1,"currency":"CNY","eventType":1,"changeReason":"Synthetic known zero"}],"total":1}"#
    public static let errorEnvelope = #"{"code":503}"#
}

public struct WalletCommerceSyntheticTransport: HTTPTransport {
    public let fail: Bool
    public init(fail: Bool = false) { self.fail = fail }
    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        if fail { return (Data(WalletIncomeDetailFixtureData.errorEnvelope.utf8), 503) }
        let payload: String
        switch request.url?.path {
        case "/api/wallet/stages": payload = WalletEarningsOverviewFixtureData.stagesUnknown
        case "/api/balance/list": payload = #"[{"id":1,"changeBalance":"5.00","changeType":2,"changeReason":"Synthetic debit"},{"id":2,"changeType":1,"changeReason":"Synthetic missing amount"}]"#
        case "/api/points/list": payload = #"[{"id":3,"changePoints":-7,"afterPoints":40,"changeReason":"Synthetic points"}]"#
        case "/api/user/points/list": payload = #"{"rows":[{"id":3,"changePoints":-7,"afterPoints":40,"changeReason":"Synthetic points"}],"total":1}"#
        case "/api/user/balance/list": payload = WalletIncomeDetailFixtureData.incomeList
        case "/api/product/list": payload = #"{"rows":[{"id":10,"productName":"Synthetic postcard","price":8,"stock":null}],"total":1}"#
        case "/api/product/info": payload = #"{"id":10,"productName":"Synthetic postcard","price":8,"stock":null,"skuList":[{"id":11,"skuName":"Synthetic variant","price":8,"stock":null}]}"#
        case "/api/cart/list": payload = #"{"rows":[{"id":20,"productId":10,"skuId":11,"quantity":1,"productName":"Synthetic postcard","price":8}],"total":1}"#
        case "/api/cart/settlement": payload = #"{"productAmount":8,"deliveryFee":0,"taxFee":0,"totalAmount":"8.1","pointBalance":40,"productList":[{"id":20,"productId":10,"skuId":11,"quantity":1,"price":8}],"address":{"id":30,"mobilePhone":"TEST-0000"}}"#
        case "/api/withdrawal/list": payload = #"{"rows":[{"id":40,"amount":5,"status":1,"bankAccount":"SYNTHETIC-1234"},{"id":41,"amount":6,"status":2}],"total":2}"#
        case "/api/points/result_list": payload = #"[{"id":50,"status":1,"eventType":1,"title":"Synthetic rule","description":"Offline fixture only","value":5,"pointsNum":2},{"id":51,"status":1,"eventType":14,"title":"Synthetic spend rule"},{"id":52,"status":1,"eventType":1,"title":"Deleted rule","delFlag":1}]"#
        default: throw APIError.invalidRequest // No mutation success is fabricated by UI fixtures.
        }
        return (Data(("{\"code\":200,\"data\":" + payload + "}").utf8), 200)
    }
}

/// Synthetic pages for the existing income list. Not a host, a route, or a payout.
public enum AssetCenterAnalysisFixtureData {
    public static let incomeListPath = AssetCenterAnalysisPageModel.incomeListPath
    public static let loading = AssetCenterAnalysisPageModel(.loading)
    public static let failed = AssetCenterAnalysisPageModel(.error)
    public static let emptyPage = page(rows: [], total: 0)
    public static let unknownAmountPage = page(rows: [row(id: 4, amount: nil, currency: "CNY")], total: 1)
    public static let knownZeroPage = page(rows: [row(id: 5, amount: "0", currency: "CNY")], total: 1)
    public static let readyPage = page(rows: [row(id: 6, amount: "8.50", currency: "CNY")], total: 1)
    public static let mixedCurrencyPage = page(rows: [
        row(id: 7, amount: "1.00", currency: "CNY"),
        row(id: 8, amount: "2.00", currency: "USD")
    ], total: 2)
    public static let malformedAmountPage = page(rows: [row(id: 9, amount: "UNKNOWN", currency: "CNY")], total: 1)
    public static let errorBody = Data("{\"code\":503}".utf8)

    public static func row(id: Int, amount: String?, currency: String?, direction: Int = 1, event: Int = 1) -> String {
        var fields = ["\"id\":\(id)", "\"changeType\":\(direction)", "\"eventType\":\(event)", "\"createTime\":\"2026-11-01 00:00:00\""]
        if let amount { fields.append("\"changeBalance\":\"\(amount)\"") }
        if let currency { fields.append("\"currency\":\"\(currency)\"") }
        return "{" + fields.joined(separator: ",") + "}"
    }

    public static func page(rows: [String], total: Int?) -> Data {
        let totalJSON = total.map(String.init) ?? "null"
        let body = "{\"code\":200,\"data\":{\"rows\":[" + rows.joined(separator: ",") + "],\"total\":" + totalJSON + "}}"
        return Data(body.utf8)
    }

    public static func decodeRows(_ data: Data) throws -> [WalletLedgerRow] {
        struct Envelope: Decodable {
            struct Body: Decodable { let rows: [WalletLedgerRow] }
            let data: Body
        }
        return try JSONDecoder().decode(Envelope.self, from: data).data.rows
    }

    public static func model(page: Data) throws -> AssetCenterAnalysisPageModel {
        AssetCenterAnalysisPageModel(rows: try decodeRows(page))
    }
}
#endif
