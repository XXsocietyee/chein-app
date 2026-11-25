import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Coverage lane `cursor/cov3-a` on hengyin `chengyinhub-xcx` `25eb6a0c`.
/// The only owned missing-endpoint call with one path literal that Core did not
/// already record is `app.js:374`: `siteBaseUrl + '/api/login/code'`.
/// Building the request does not send it. Pay, refund, payout, withdrawal,
/// paid orders, quote, registration create, and pricing confirm are not opened here.
public enum Cov3AMPContract {
    /// `app.js:374`. POST form field `code`.
    public static let loginCodePath = "api/login/code"

    public enum Refusal: Error, Equatable {
        case invalidBase
    }

    /// `app.js:374`. `wx.request` posts `{ code }` as `application/x-www-form-urlencoded;`.
    /// Returns the request. Does not send it.
    public static func loginCode(baseURL: URL, code: String) throws -> URLRequest {
        guard var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              parts.scheme == "https" || parts.scheme == "http" else { throw Refusal.invalidBase }
        parts.path = "/" + loginCodePath
        parts.query = nil
        parts.fragment = nil
        guard let url = parts.url else { throw Refusal.invalidBase }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;", forHTTPHeaderField: "Content-Type")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let escaped = code.addingPercentEncoding(withAllowedCharacters: allowed) ?? code
        request.httpBody = Data("code=\(escaped)".utf8)
        return request
    }
}
