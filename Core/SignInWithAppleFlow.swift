import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The entitlement file must contain only this value. A missing or wider set stays hidden.
public struct SignInWithAppleEntitlement: Equatable {
    public static let key = "com.apple.developer.applesignin"
    public static let requiredValues = ["Default"]
    public let values: [String]
    public init(values: [String]) { self.values = values }
    public var isSatisfied: Bool { values == Self.requiredValues }
}

public enum SignInWithAppleVisibility: Equatable {
    case hidden
    case ready
}

/// `ready` is the only state a later screen may present. This type does not present it.
public struct SignInWithApplePresentation: Equatable {
    public let visibility: SignInWithAppleVisibility
    public var isShown: Bool { visibility == .ready }
}

public enum SignInWithAppleFlowError: Error, Equatable {
    case hidden
    case invalidCredential
    case unauthorized
    case malformedResponse
    case rejected(Int)
    case rateLimited
    case httpStatus(Int)
}

/// China Sign in with Apple exchange. Hidden unless the reviewed deployment names
/// `.signInWithApple`, the entitlement is exactly `Default`, and the caller supplies
/// that deployment's own approved HTTPS URL. An empty URL never selects another host.
public struct SignInWithAppleFlow {
    public let presentation: SignInWithApplePresentation
    public var isShown: Bool { presentation.isShown }
    private let configuration: APIConfiguration?
    private static let deniedHost = "47.103.124.64"

    public init(market: RegionalMarket, baseURL: String?,
                approvedBaseURLs: [RegionalMarket: Set<String>] = [:],
                verifiedCapabilities: Set<RegionalCapability> = [],
                entitlementValues: [String] = []) {
        let resolved = Self.resolve(
            market: market, baseURL: baseURL, approvedBaseURLs: approvedBaseURLs,
            verifiedCapabilities: verifiedCapabilities, entitlementValues: entitlementValues
        )
        configuration = resolved
        presentation = SignInWithApplePresentation(visibility: resolved == nil ? .hidden : .ready)
    }

    private static func resolve(market: RegionalMarket, baseURL: String?,
                                approvedBaseURLs: [RegionalMarket: Set<String>],
                                verifiedCapabilities: Set<RegionalCapability>,
                                entitlementValues: [String]) -> APIConfiguration? {
        let trimmed = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let entitlement = SignInWithAppleEntitlement(values: entitlementValues)
        guard market == .china, entitlement.isSatisfied, verifiedCapabilities.contains(.signInWithApple),
              !trimmed.isEmpty, !trimmed.contains(deniedHost) else { return nil }
        guard let regional = try? RegionalConfiguration(
            market: market, baseURL: trimmed, approvedBaseURLs: approvedBaseURLs,
            verifiedCapabilities: verifiedCapabilities
        ), let api = regional.apiConfiguration, admits(api.baseURL) else { return nil }
        return api
    }

    /// One login exchange, then one current-account read. No retry, persistence, or provider launch.
    public func exchange(identityToken: String, transport: any HTTPTransport) async throws -> LoginResult {
        guard let configuration else { throw SignInWithAppleFlowError.hidden }
        guard AuthRequestBuilder.isValidToken(identityToken) else { throw SignInWithAppleFlowError.invalidCredential }
        try Task.checkCancellation()
        let builder = AuthRequestBuilder(configuration: configuration)
        let loginRequest = try builder.make(.apple, fields: ["identityToken": identityToken])
        guard Self.admits(loginRequest.url) else { throw SignInWithAppleFlowError.hidden }
        let (loginData, loginStatus) = try await transport.send(loginRequest)
        try Task.checkCancellation()
        let login = try Self.loginResult(data: loginData, status: loginStatus)
        let accountRequest = try builder.make(.userInfo, token: login.token)
        guard Self.admits(accountRequest.url) else { throw SignInWithAppleFlowError.hidden }
        let (accountData, accountStatus) = try await transport.send(accountRequest)
        try Task.checkCancellation()
        let account = try Self.currentAccount(data: accountData, status: accountStatus)
        guard account.id == login.account.id, account.id > 0,
              ["player", "club", "merchant"].contains(account.role) else {
            throw SignInWithAppleFlowError.malformedResponse
        }
        return LoginResult(token: login.token, account: account)
    }

    private static func admits(_ url: URL?) -> Bool {
        guard let host = url?.host, !host.isEmpty, host.caseInsensitiveCompare(deniedHost) != .orderedSame else {
            return false
        }
        return url?.scheme == "https"
    }

    private struct Envelope: Decodable {
        let code: Int
        let token: String?
        let data: Account?
        let appUser: Account?
    }

    private static func loginResult(data: Data, status: Int) throws -> LoginResult {
        let body = try envelope(data: data, status: status)
        guard let token = body.token, AuthRequestBuilder.isValidToken(token),
              let account = body.data, account.id > 0 else {
            throw SignInWithAppleFlowError.malformedResponse
        }
        return LoginResult(token: token, account: account)
    }

    private static func currentAccount(data: Data, status: Int) throws -> Account {
        let body = try envelope(data: data, status: status)
        guard let account = body.appUser, account.id > 0 else { throw SignInWithAppleFlowError.malformedResponse }
        return account
    }

    private static func envelope(data: Data, status: Int) throws -> Envelope {
        if status == 401 { throw SignInWithAppleFlowError.unauthorized }
        if status == 429 { throw SignInWithAppleFlowError.rateLimited }
        guard (200..<300).contains(status) else { throw SignInWithAppleFlowError.httpStatus(status) }
        let body: Envelope
        do { body = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw SignInWithAppleFlowError.malformedResponse }
        if body.code == 401 { throw SignInWithAppleFlowError.unauthorized }
        if body.code == 429 { throw SignInWithAppleFlowError.rateLimited }
        guard body.code == 200 else { throw SignInWithAppleFlowError.rejected(body.code) }
        return body
    }
}
