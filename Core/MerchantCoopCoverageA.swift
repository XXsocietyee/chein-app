import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Lane A of the merchant/coop mini-program contract pass (hengyin `chengyinhub-xcx` `25eb6a0c`).
/// One path the coverage checker had not recorded: coop-center `loadMoreRoutes`.
/// POST with no header, so the mini-program client uses `application/x-www-form-urlencoded;`
/// and the object `{pageNum, pageSize}`. Building a request does not send it.
/// Payout, refund, withdrawal, and both IM mark-read switches are not opened here.
public enum MerchantCoopCoverageA {
    public static let recruitRoutesPath = "api/merchant/recruit-routes"

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
}
