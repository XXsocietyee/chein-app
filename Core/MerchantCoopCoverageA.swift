import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Lane A of the merchant/coop mini-program contract pass (hengyin `chengyinhub-xcx` `25eb6a0c`).
/// Paths the coverage checker had not recorded: coop-center `loadMoreRoutes`, and the merchant
/// branch of `pages/merchant/components/cy/fe-reference-range` (`kind` defaults to `merchant`).
/// The payer export literal already lives on `ClubFEReferenceExportClient`. Building a request
/// does not send it. Payout, refund, withdrawal, and both IM mark-read switches are not opened here.
public enum MerchantCoopCoverageA {
    public static let recruitRoutesPath = "api/merchant/recruit-routes"
    /// `kind !== 'payer'` export. GET, optional `from` / `to` query, same day rule as `rangeQuery`.
    public static let referenceSettlementMerchantExportPath = "api/fe/reference-settlement/merchant/export"

    public enum Refusal: Error, Equatable {
        case invalidPage
        case invalidBase
    }

    public static func recruitRoutes(baseURL: URL, pageNum: Int, pageSize: Int) throws -> URLRequest {
        guard pageNum > 0, pageSize > 0, pageNum <= 10_000, pageSize <= 100 else { throw Refusal.invalidPage }
        guard var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              parts.scheme == "https" || parts.scheme == "http" else { throw Refusal.invalidBase }
        parts.path = "/" + recruitRoutesPath
        parts.query = nil
        parts.fragment = nil
        guard let url = parts.url else { throw Refusal.invalidBase }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("pageNum=\(pageNum)&pageSize=\(pageSize)".utf8)
        return request
    }

    /// GET `api/fe/reference-settlement/merchant/export`. `from` and `to` are included only when
    /// they are `YYYY-MM-DD`, and swapped when reversed. Does not send.
    public static func referenceSettlementMerchantExport(baseURL: URL, from: String, to: String) throws -> URLRequest {
        guard var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              parts.scheme == "https" || parts.scheme == "http" else { throw Refusal.invalidBase }
        parts.path = "/" + referenceSettlementMerchantExportPath
        parts.fragment = nil
        let query = referenceRangeQuery(from: from, to: to)
        parts.queryItems = query.isEmpty ? nil : query
        guard let url = parts.url else { throw Refusal.invalidBase }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.httpBody = nil
        return request
    }

    private static func referenceRangeQuery(from: String, to: String) -> [URLQueryItem] {
        var start = referenceDay(from)
        var end = referenceDay(to)
        if let left = start, let right = end, left > right {
            start = right
            end = left
        }
        var items: [URLQueryItem] = []
        if let start { items.append(URLQueryItem(name: "from", value: start)) }
        if let end { items.append(URLQueryItem(name: "to", value: end)) }
        return items
    }

    private static func referenceDay(_ value: String) -> String? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2 else { return nil }
        guard parts.allSatisfy({ part in part.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
        return value
    }
}
