import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Existing CN session reads/revocation are independent of the password-entry channel.
/// This is not a US fallback: US requires its separately gated protected-proof contract.
public struct CNAccountSessionService {
    public let storageScope: RegionalSessionStorageScope
    private let auth: AuthService

    public init(configuration: RegionalConfiguration, storageScope: RegionalSessionStorageScope,
                transport: any HTTPTransport) throws {
        guard configuration.market == .china, storageScope.matches(configuration: configuration),
              let api = configuration.apiConfiguration,
              configuration.availability(of: .domesticChinaPhone) == .available else {
            throw APIError.notConfigured
        }
        self.storageScope = storageScope
        auth = AuthService(configuration: api, transport: transport)
    }

    /// Bodyless POST, raw Authorization, authoritative public appUser projection.
    /// A legacy cached projection without an explicit server role cannot restore a session.
    public func currentAccount(token: String) async throws -> Account {
        try await currentAccount(token: token, storedRole: nil)
    }

    /// `storedRole` is the role this device committed for the same account at sign-in. It fills
    /// only an omitted server role for that exact account id; a server role always wins, and an
    /// unknown or mismatched account still cannot restore.
    public func currentAccount(token: String, storedRole: StoredSessionRole?) async throws -> Account {
        try Task.checkCancellation()
        var account = try await auth.currentAccount(token: token)
        if account.role.isEmpty, let storedRole, storedRole.accountID == account.id, account.id > 0 {
            account = account.withFallbackRole(storedRole.role)
        }
        guard ["player", "club", "merchant"].contains(account.role) else { throw APIError.malformedResponse }
        try Task.checkCancellation()
        return account
    }

    /// Best-effort remote revocation after the caller has already closed the local session.
    public func logout(token: String) async throws {
        try Task.checkCancellation()
        try await auth.logout(token: token)
        try Task.checkCancellation()
    }
}


/// Non-secret record of the role committed with a signed-in account, kept per storage scope so
/// a cold restore survives a `/api/userInfo` projection that omits `role`.
public struct StoredSessionRole: Equatable {
    public let accountID: Int
    public let role: String
    public init?(accountID: Int, role: String) {
        guard accountID > 0, ["player", "club", "merchant"].contains(role) else { return nil }
        self.accountID = accountID; self.role = role
    }
    public init?(encoded: String?) {
        guard let parts = encoded?.split(separator: "|", omittingEmptySubsequences: false), parts.count == 2,
              let id = Int(parts[0]) else { return nil }
        self.init(accountID: id, role: String(parts[1]))
    }
    public var encoded: String { "\(accountID)|\(role)" }
    public static func key(for scope: RegionalSessionStorageScope) -> String { scope.service + ".restoreRole" }
}

/// Defaults-backed `StoredSessionRole` for one storage scope. Written on every committed session, cleared on logout/expiry.
public struct StoredSessionRoleStore {
    private let defaults: UserDefaults
    private let key: String
    public init(defaults: UserDefaults, scope: RegionalSessionStorageScope) {
        self.defaults = defaults; key = StoredSessionRole.key(for: scope)
    }
    public func read() -> StoredSessionRole? { StoredSessionRole(encoded: defaults.string(forKey: key)) }
    public func record(_ account: Account) {
        if let stored = StoredSessionRole(accountID: account.id, role: account.role) { defaults.set(stored.encoded, forKey: key) }
        else { clear() }
    }
    public func clear() { defaults.removeObject(forKey: key) }
}

extension CNAccountSessionService {
    /// Exact bounded wire shapes from the native SMS/session adapter. This is a transport
    /// allowlist, not provider readiness, authentication, a role grant, or attestation.
    public static func accepts(_ request: URLRequest, configuration: APIConfiguration) -> Bool {
        guard request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Accept") == "application/json",
              let url = request.url, url.query == nil, url.fragment == nil else { return false }
        let token = request.value(forHTTPHeaderField: "Authorization")
        if url == configuration.url(for: .userInfo) {
            return token.map(AuthRequestBuilder.isValidToken) == true && request.httpBody == nil
                && request.value(forHTTPHeaderField: "Content-Type") == nil
        }
        if url == configuration.url(for: .smsSend), token == nil,
           request.value(forHTTPHeaderField: "Content-Type") == AccountPublishMPContract.formContentType,
           let body = request.httpBody, let text = String(data: body, encoding: .utf8), text.hasPrefix("phone=") {
            let encoded = String(text.dropFirst("phone=".count))
            let phone = encoded.removingPercentEncoding ?? encoded
            if let contract = try? AccountPublishMPContract.smsSendRequest(baseURL: configuration.baseURL, phone: phone),
               contract.httpBody == body {
                return true
            }
        }
        let keys: Set<String>
        if url == configuration.url(for: .smsSend) { keys = ["phone"]; guard token == nil else { return false } }
        else if url == configuration.url(for: .phone) { keys = ["phone", "code"]; guard token == nil else { return false } }
        else if url == configuration.url(for: .logout) { keys = []; guard token.map(AuthRequestBuilder.isValidToken) == true else { return false } }
        else { return false }
        let prefix = "multipart/form-data; boundary="
        guard let type = request.value(forHTTPHeaderField: "Content-Type"), type.hasPrefix(prefix),
              let body = request.httpBody, body.count <= 1024,
              let text = String(data: body, encoding: .utf8) else { return false }
        let boundary = String(type.dropFirst(prefix.count))
        var fields: [String: String] = [:]
        for key in keys {
            let marker = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n"
            guard let range = text.range(of: marker),
                  let end = text[range.upperBound...].range(of: "\r\n") else { return false }
            fields[key] = String(text[range.upperBound..<end.lowerBound])
        }
        if let phone = fields["phone"], (try? AuthChannelInput.phone(phone)) != phone { return false }
        if let code = fields["code"], (try? AuthChannelInput.code(code)) != code { return false }
        guard let canonical = try? AuthRequestBuilder.makeFormRequest(url: url, fields: fields,
            token: token, boundary: boundary) else { return false }
        // Byte equality rejects extra/duplicate fields, role/identity injection, alternate
        // framing, malformed boundaries, unbounded payloads and noncanonical encodings.
        return canonical.httpBody == body
    }
}
