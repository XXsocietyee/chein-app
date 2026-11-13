import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Read-only points history, weekly statistics, and earn-rule list.
/// The mini-program posts all three (`subpackageMember/points-history/index.js`,
/// `components/cy/profile/index.js`). No redeem, withdraw, or payout is forwarded.
public enum PassMarketPointsReads {
    public static let listPath = "api/points/list"
    public static let statisticsPath = "api/user/points/statistics"
    public static let rulesPath = "api/points/result_list"
    public static let method = "POST"
    /// Missing amount. A known zero is the string "0", never this mark.
    public static let unknownAmount = "\u{2014}"

    public static func display(_ points: Int?) -> String {
        guard let points else { return unknownAmount }
        return String(points)
    }

    /// Last path segments must equal the relative path. `/api/user/points/list` is not `/api/points/list`.
    public static func matches(path: String, relative: String) -> Bool {
        let parts = path.split(separator: "/").map(String.init)
        let want = relative.split(separator: "/").map(String.init)
        guard !want.isEmpty, parts.count >= want.count else { return false }
        return Array(parts.suffix(want.count)) == want
    }

    public static func isAllowedRead(_ request: URLRequest) -> Bool {
        guard request.httpMethod?.uppercased() == method,
              request.httpBodyStream == nil,
              let url = request.url, url.query == nil, url.fragment == nil else { return false }
        return [listPath, statisticsPath, rulesPath].contains { matches(path: url.path, relative: $0) }
    }
}

/// Forwards only the three posts. Every other method and path, including cart redeem and withdrawal, stops here.
public struct PassMarketPointsReadTransport: HTTPTransport {
    public let underlying: any HTTPTransport
    public init(underlying: any HTTPTransport) { self.underlying = underlying }

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request)
        guard PassMarketPointsReads.isAllowedRead(request) else { throw APIError.notConfigured }
        return try await underlying.send(request)
    }
}
