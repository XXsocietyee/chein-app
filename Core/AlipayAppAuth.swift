import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Owner 11-28 04:30: Alipay sign-in (CN). Mirrors the WeChat app login: the backend signs an `authInfo` string,
/// the Alipay SDK returns an `auth_code`, the backend exchanges it for the session token. No SDK binary is linked
/// by this module; a platform driver plugs in behind `AlipaySDKAuthDriving`. Every default is gated off, so the
/// login screen renders nothing for Alipay until the SDK, provider and exchange are verified (P27).
public enum AlipayAppAuthError: Error, Equatable {
    case notConfigured, unavailable, launchFailed, timedOut
    case invalidCode, invalidResponse, staleSession, rateLimited
    case unauthorized, rejected, network, storage, upgradeRequired
    public var localizationKey: String {
        self == .upgradeRequired ? "auth.channels.upgradeRequired" : "auth.alipay.\(String(describing: self))"
    }
}

/// Independent release evidence. Defaults never permit SDK authorization or HTTP.
public struct AlipayAppAuthGate: Equatable {
    public var sdkVerified = false
    public var providerVerified = false
    public var legalVerified = false
    public var liveExchangeApproved = false
    public init() {}
    public var permitsAuthorization: Bool {
        sdkVerified && providerVerified && legalVerified && liveExchangeApproved
    }
}

/// The app's own URL scheme registered for the Alipay SDK callback (`<scheme>://safepay/...`).
public struct AlipaySDKConfiguration: Equatable {
    public static let callbackHost = "safepay"
    public let appScheme: String
    public init(appScheme: String) throws {
        let bytes = Array(appScheme.utf8)
        guard bytes.count >= 3, bytes.count <= 64, let first = bytes.first, (97...122).contains(first),
              bytes.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 43 || $0 == 45 || $0 == 46 })
        else { throw AlipayAppAuthError.notConfigured }
        self.appScheme = appScheme
    }
    public func acceptsURL(_ url: URL) -> Bool {
        guard url.absoluteString.utf8.count <= 16_384,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.port == nil else { return false }
        return parts.scheme?.lowercased() == appScheme && parts.host?.lowercased() == Self.callbackHost
    }
}

/// Primitives from the SDK's auth result dictionary (`resultStatus`, `result`); no SDK object escapes the driver.
public struct AlipaySDKAuthResponse: Equatable {
    public let resultStatus: String
    public let result: String?
    public init(resultStatus: String, result: String?) { self.resultStatus = resultStatus; self.result = result }

    /// `result` is `success=true&auth_code=…&result_code=200&…`; a code is accepted only with `result_code=200`.
    public var authCode: String? {
        guard resultStatus == "9000", let result else { return nil }
        var values: [String: String] = [:]
        for pair in result.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            values[parts[0]] = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        guard values["result_code"] == "200", let code = values["auth_code"], !code.isEmpty, code.utf8.count <= 4096,
              code.utf8.allSatisfy({ $0 > 0x20 && $0 < 0x7f }) else { return nil }
        return code
    }
}

public enum AlipayAppAuthorizationOutcome: Equatable {
    case authCode(String), cancelled, unavailable, launchFailed
}

@MainActor
public protocol AlipaySDKAuthDriving: AnyObject {
    var isLinked: Bool { get }
    var isInstalled: Bool { get }
    func authorize(_ authInfo: String, scheme: String, response: @escaping (AlipaySDKAuthResponse) -> Void)
    /// Hands an accepted `safepay` callback URL to the SDK, which then calls the pending `response`.
    func handle(_ url: URL)
    func detach()
}

@MainActor
public protocol AlipayAppAuthorizing: AnyObject {
    func start(authInfo: String, attemptID: UUID, callback: @escaping (AlipayAppAuthorizationOutcome) -> Void)
    func cancel(attemptID: UUID)
}

/// Stateful, injected SDK adapter (same shape as `WeChatSDKAuthAdapter`). The coordinator owns timeout, exchange,
/// verified account lookup and the guarded session commit.
@MainActor
public final class AlipayAuthAdapter: AlipayAppAuthorizing {
    private let driver: (any AlipaySDKAuthDriving)?
    private let configuration: AlipaySDKConfiguration?
    private var pendingID: UUID?
    private var pendingCallback: ((AlipayAppAuthorizationOutcome) -> Void)?

    public init(driver: (any AlipaySDKAuthDriving)? = nil, configuration: AlipaySDKConfiguration? = nil) {
        self.driver = driver; self.configuration = configuration
    }
    public var isConfigured: Bool { configuration != nil && driver?.isLinked == true }

    public func start(authInfo: String, attemptID: UUID, callback: @escaping (AlipayAppAuthorizationOutcome) -> Void) {
        guard pendingID == nil else { callback(.launchFailed); return }
        guard let configuration, let driver, driver.isLinked,
              !authInfo.isEmpty, authInfo.utf8.count <= 8192,
              authInfo.utf8.allSatisfy({ $0 > 0x20 && $0 < 0x7f }) else { callback(.unavailable); return }
        guard driver.isInstalled else { callback(.unavailable); return }
        pendingID = attemptID; pendingCallback = callback
        driver.authorize(authInfo, scheme: configuration.appScheme) { [weak self] response in
            self?.receive(response, attemptID: attemptID)
        }
    }
    public func cancel(attemptID: UUID) {
        guard pendingID == attemptID else { return }
        pendingID = nil; pendingCallback = nil; driver?.detach()
    }
    /// URL-scheme callback from `onOpenURL`; only while an attempt is pending.
    public func acceptsURL(_ url: URL) -> Bool {
        guard pendingID != nil, configuration?.acceptsURL(url) == true, let driver else { return false }
        driver.handle(url)
        return true
    }
    private func receive(_ response: AlipaySDKAuthResponse, attemptID: UUID) {
        guard pendingID == attemptID else { return }
        let outcome: AlipayAppAuthorizationOutcome
        switch response.resultStatus {
        case "9000":
            if let code = response.authCode { outcome = .authCode(code) } else { outcome = .launchFailed }
        case "6001": outcome = .cancelled
        default: outcome = .launchFailed
        }
        let callback = pendingCallback
        pendingID = nil; pendingCallback = nil; driver?.detach()
        callback?(outcome)
    }
}

@MainActor
public protocol AlipayAppExchanging {
    func authInfo() async throws -> String
    func exchange(authCode: String) async throws -> LoginResult
    func currentAccount(token: String) async throws -> Account
}

/// `GET api/login/alipay/auth-info` → signed authInfo; `POST api/login/alipay` (`auth_code`) → token + account.
public struct AlipayAppAuthService: AlipayAppExchanging {
    public static let authInfoPath = "api/login/alipay/auth-info"
    public static let loginPath = "api/login/alipay"
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let auth: AuthService
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
        auth = AuthService(configuration: configuration, transport: transport)
    }
    private struct StatusEnvelope: Decodable { let code: Int }
    private struct InfoObject: Decodable {
        let authInfo: String?
        let auth_info: String?
    }
    private struct InfoEnvelope: Decodable {
        let code: Int
        let text: String?
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            code = try container.decode(Int.self, forKey: .code)
            if let value = try? container.decode(String.self, forKey: .data) {
                text = value
            } else if let object = try? container.decode(InfoObject.self, forKey: .data) {
                text = object.authInfo ?? object.auth_info
            } else {
                text = nil
            }
        }
        enum Keys: String, CodingKey { case code, data }
    }
    private struct LoginEnvelope: Decodable { let code: Int; let token: String?; let data: Account? }

    private func send(_ request: URLRequest) async throws -> Data {
        try Task.checkCancellation()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        if status == 401 { throw AlipayAppAuthError.unauthorized }
        if status == 429 { throw AlipayAppAuthError.rateLimited }
        if status == 426 { throw AlipayAppAuthError.upgradeRequired }
        guard (200..<300).contains(status) else { throw AlipayAppAuthError.network }
        guard let body = try? JSONDecoder().decode(StatusEnvelope.self, from: data) else { throw AlipayAppAuthError.invalidResponse }
        if body.code == 401 { throw AlipayAppAuthError.unauthorized }
        if body.code == 429 { throw AlipayAppAuthError.rateLimited }
        guard body.code == 200 else { throw AlipayAppAuthError.rejected }
        return data
    }
    public func authInfo() async throws -> String {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(Self.authInfoPath))
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await send(request)
        guard let body = try? JSONDecoder().decode(InfoEnvelope.self, from: data),
              let text = body.text, !text.isEmpty, text.utf8.count <= 8192 else { throw AlipayAppAuthError.invalidResponse }
        return text
    }
    public func exchange(authCode: String) async throws -> LoginResult {
        guard !authCode.isEmpty, authCode.utf8.count <= 4096,
              authCode.utf8.allSatisfy({ $0 > 0x20 && $0 < 0x7f }) else { throw AlipayAppAuthError.invalidCode }
        let url = configuration.baseURL.appendingPathComponent(Self.loginPath)
        let request = try AuthRequestBuilder.makeFormRequest(url: url, fields: ["auth_code": authCode], token: nil)
        let data = try await send(request)
        guard let body = try? JSONDecoder().decode(LoginEnvelope.self, from: data),
              let token = body.token, AuthRequestBuilder.isValidToken(token),
              let account = body.data, account.id > 0 else { throw AlipayAppAuthError.invalidResponse }
        return LoginResult(token: token, account: account)
    }
    public func currentAccount(token: String) async throws -> Account {
        try Task.checkCancellation()
        let result = try await auth.currentAccount(token: token)
        try Task.checkCancellation()
        return result
    }
}

@MainActor
public final class AlipayAppAuthCoordinator {
    public enum Phase: Equatable { case idle, preparing, authorizing, exchanging, signedIn }
    public private(set) var phase: Phase = .idle
    public private(set) var issue: AlipayAppAuthError?
    public var onChange: (() -> Void)?
    public var isWorking: Bool { phase == .preparing || phase == .authorizing || phase == .exchanging }
    /// The channel exists in this build. When false the login screen renders nothing for Alipay (P27).
    public var isOffered: Bool { gate().permitsAuthorization && adapter != nil && service != nil }
    public var canStart: Bool { !isWorking && phase != .signedIn && isOffered && context().permitsLogin }
    private let adapter: (any AlipayAppAuthorizing)?
    private let service: (any AlipayAppExchanging)?
    private let gate: () -> AlipayAppAuthGate
    private let context: () -> WeChatAppAuthContext
    private let commit: (LoginResult, WeChatAppAuthContext) throws -> Bool
    private var attemptID: UUID?
    private var captured: WeChatAppAuthContext?
    private var work: Task<Void, Never>?

    public init(adapter: (any AlipayAppAuthorizing)? = nil, service: (any AlipayAppExchanging)? = nil,
                gate: @escaping () -> AlipayAppAuthGate = { AlipayAppAuthGate() },
                context: @escaping () -> WeChatAppAuthContext,
                commit: @escaping (LoginResult, WeChatAppAuthContext) throws -> Bool) {
        self.adapter = adapter; self.service = service; self.gate = gate
        self.context = context; self.commit = commit
    }

    public func start() {
        guard !isWorking else { return }
        guard canStart, let service else { issue = .notConfigured; onChange?(); return }
        let id = UUID()
        attemptID = id; captured = context(); phase = .preparing; issue = nil; onChange?()
        work = Task { [weak self] in
            do {
                let info = try await service.authInfo()
                guard let self, self.current(id) else { return }
                self.authorize(info, attemptID: id)
            } catch {
                self?.fail(error, attemptID: id)
            }
        }
    }
    private func current(_ id: UUID) -> Bool {
        attemptID == id && captured == context() && context().permitsLogin && gate().permitsAuthorization
    }
    private func authorize(_ info: String, attemptID id: UUID) {
        phase = .authorizing; onChange?()
        adapter?.start(authInfo: info, attemptID: id) { [weak self] outcome in
            self?.receive(outcome, attemptID: id)
        }
    }
    private func receive(_ outcome: AlipayAppAuthorizationOutcome, attemptID id: UUID) {
        guard attemptID == id, phase == .authorizing else { return }
        guard current(id) else { stop(issue: .staleSession); return }
        switch outcome {
        case .cancelled: stop(issue: nil)
        case .unavailable: stop(issue: .unavailable)
        case .launchFailed: stop(issue: .launchFailed)
        case .authCode(let code):
            // Transition before async work: a duplicate callback cannot exchange twice.
            phase = .exchanging; onChange?()
            work = Task { [weak self] in
                await self?.exchange(code, attemptID: id)
            }
        }
    }
    private func exchange(_ code: String, attemptID id: UUID) async {
        guard current(id), let service, let captured else { stop(issue: .staleSession); return }
        do {
            let result = try await service.exchange(authCode: code)
            guard current(id) else { stop(issue: .staleSession); return }
            let account = try await service.currentAccount(token: result.token)
            guard current(id) else { stop(issue: .staleSession); return }
            guard account.id == result.account.id else { throw AlipayAppAuthError.invalidResponse }
            let committed: Bool
            do { committed = try commit(LoginResult(token: result.token, account: account), captured) }
            catch { throw AlipayAppAuthError.storage }
            stop(issue: committed ? nil : .staleSession)
            if committed { phase = .signedIn; onChange?() }
        } catch {
            fail(error, attemptID: id)
        }
    }
    private func fail(_ error: Error, attemptID id: UUID) {
        guard attemptID == id else { return }
        if error is CancellationError { stop(issue: nil); return }
        if let error = error as? AlipayAppAuthError { stop(issue: error); return }
        if let error = error as? APIError {
            switch error {
            case .unauthorized: stop(issue: .unauthorized)
            case .malformedResponse: stop(issue: .invalidResponse)
            case .notConfigured, .invalidConfiguration: stop(issue: .notConfigured)
            case .businessCode: stop(issue: .rejected)
            case .httpStatus(426): stop(issue: .upgradeRequired)
            default: stop(issue: .network)
            }
            return
        }
        stop(issue: .network)
    }
    /// Dismissal, logout, session change and navigation all invalidate callbacks before cancelling SDK work.
    public func cancel() { stop(issue: nil) }
    private func stop(issue: AlipayAppAuthError?) {
        let id = attemptID
        attemptID = nil; captured = nil; phase = .idle; self.issue = issue
        work?.cancel(); work = nil
        if let id { adapter?.cancel(attemptID: id) }
        onChange?()
    }
}
