import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

#if DEBUG
/// DEBUG-only end-to-end override. `--e2e-test-host <url>` admits exactly one TEST host and
/// nothing else; Release builds compile none of this. The shipped reviewed composition is
/// reused unchanged, and only the outgoing production host is rewritten to the TEST host,
/// after every reviewed route guard has run. The session realm is separate from production.
enum E2ETestHostOverride {
    static let testHost = "https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech"
    static let realm = "cn-e2e-test"

    /// True when this DEBUG process was launched against the TEST host. Requests still name the production base URL
    /// and are rewritten in `E2ETestHostTransport`, so host-based switches use this to judge the real target.
    static var active: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let i = arguments.firstIndex(of: "--e2e-test-host"), arguments.indices.contains(i + 1) else { return false }
        return arguments[i + 1] == testHost
    }

    @MainActor static func selected(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppCompositionRoot? {
        guard let i = arguments.firstIndex(of: "--e2e-test-host"), arguments.indices.contains(i + 1),
              arguments[i + 1] == testHost else { return nil }
        let build = RegionalLaunchConfiguration.BuildMetadata(
            market: RegionalMarket.china.rawValue,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            realm: realm
        )
        let transport: () -> any HTTPTransport = { E2ETestHostTransport(underlying: URLSessionTransport()) }
        return RegionalLaunchConfiguration.shippedComposition(build: build, makeTransport: transport)
    }
}

struct E2ETestHostTransport: HTTPTransport {
    let underlying: any HTTPTransport

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        var outgoing = request
        if let url = request.url?.absoluteString, url.hasPrefix(ReviewedMarketLaunch.chinaProductionBaseURL) {
            let rest = url.dropFirst(ReviewedMarketLaunch.chinaProductionBaseURL.count)
            outgoing.url = URL(string: E2ETestHostOverride.testHost + "/" + rest)
        } else if request.url?.host?.lowercased() == "www.chengyinhub.com" {
            throw APIError.notConfigured
        }
        let started = Date()
        do {
            let (data, status) = try await underlying.send(outgoing)
            NSLog("[E2E] %@ %@ -> %d %.0fms", outgoing.httpMethod ?? "GET", outgoing.url?.path ?? "",
                  status, Date().timeIntervalSince(started) * 1000)
            return (data, status)
        } catch {
            NSLog("[E2E] %@ %@ -> error %@", outgoing.httpMethod ?? "GET", outgoing.url?.path ?? "",
                  LogFieldRedaction.redacted("\(error)"))
            throw error
        }
    }
}
#endif
