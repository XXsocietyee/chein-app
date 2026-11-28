import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum AuthChannelError: Error, Equatable {
    case invalidPhone, invalidCode, invalidAppleCredential, rateLimited
    /// Backend `errorCode` SMS_DAILY_LIMIT / SMS_INTL_NOT_CONFIGURED (SmsVerificationService).
    case smsDailyLimit, smsRegionUnavailable
    /// Maps the backend envelope `errorCode` (sent with code 500) to a typed SMS failure; nil keeps the generic path.
    public static func sms(errorCode: String?) -> AuthChannelError? {
        switch errorCode {
        case "SMS_RATE_LIMITED": return .rateLimited
        case "SMS_DAILY_LIMIT": return .smsDailyLimit
        case "SMS_INTL_NOT_CONFIGURED": return .smsRegionUnavailable
        default: return nil
        }
    }
}

/// CN backend accepts an eleven-digit ASCII phone starting with 1. Its SMS service
/// generates six-digit one-time codes. Backend validation remains authoritative.
public enum AuthChannelInput {
    public static func phone(_ value: String) throws -> String {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // i18n r1: a US number arrives in E.164 (`+1` and 10 NANP digits) from `PhoneCountryCode.wireValue`.
        if result.hasPrefix("+1"), PhoneCountryCode.unitedStates.isValid(String(result.dropFirst(2))) { return result }
        guard result.utf8.count == 11, result.first == "1", result.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw AuthChannelError.invalidPhone
        }
        return result
    }
    public static func code(_ value: String) throws -> String {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.utf8.count == 6, result.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw AuthChannelError.invalidCode
        }
        return result
    }
}

@MainActor
public protocol AuthChannelServing {
    func sendSMSCode(phone: String) async throws
    func loginWithPhone(phone: String, code: String) async throws -> LoginResult
    func loginWithApple(identityToken: String) async throws -> LoginResult
    /// P2-5: Apple returns the full name only on the first authorization; the backend names a new account from it.
    func loginWithApple(identityToken: String, givenName: String?, familyName: String?) async throws -> LoginResult
    func currentAccount(token: String) async throws -> Account
    func currentAccount(token: String, loginFallbackRole: String?) async throws -> Account
    /// Deregister posts the phone returned by `/api/user/info`, including a masked number.
    func sendBoundDeregistrationCode(phone: String) async throws
}

public extension AuthChannelServing {
    func loginWithApple(identityToken: String, givenName: String?, familyName: String?) async throws -> LoginResult {
        try await loginWithApple(identityToken: identityToken)
    }
    func currentAccount(token: String, loginFallbackRole: String?) async throws -> Account {
        try await currentAccount(token: token)
    }
    func sendBoundDeregistrationCode(phone: String) async throws {
        try await sendSMSCode(phone: phone)
    }
}

/// No retries, persistence, OAuth launch, production defaults or diagnostic credential
/// logging. Every mutation is called only by an explicit user action in the coordinator.
public struct AuthChannelService: AuthChannelServing {
    private let builder: AuthRequestBuilder
    private let transport: any HTTPTransport
    private let auth: AuthService
    public let allowLoginRoleFallback: Bool
    public init(configuration: APIConfiguration, transport: any HTTPTransport, allowLoginRoleFallback: Bool = false) {
        builder = AuthRequestBuilder(configuration: configuration)
        self.transport = transport
        auth = AuthService(configuration: configuration, transport: transport)
        self.allowLoginRoleFallback = allowLoginRoleFallback
    }
    private struct Envelope: Decodable {
        let code: Int
        let token: String?
        let data: Account?
    }
    private struct StatusEnvelope: Decodable { let code: Int; let errorCode: String? }
    private func execute(_ endpoint: AuthEndpoint, fields: [String: String]) async throws -> Data {
        try Task.checkCancellation()
        let request = try builder.make(endpoint, fields: fields)
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        if status == 401 { throw APIError.unauthorized }
        if status == 429 { throw AuthChannelError.rateLimited }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let body: StatusEnvelope
        do { body = try JSONDecoder().decode(StatusEnvelope.self, from: data) }
        catch { throw APIError.malformedResponse }
        if body.code == 401 { throw APIError.unauthorized }
        if body.code == 429 { throw AuthChannelError.rateLimited }
        if body.code != 200, let typed = AuthChannelError.sms(errorCode: body.errorCode) { throw typed }
        guard body.code == 200 else { throw APIError.businessCode(body.code) }
        return data
    }
    public func sendSMSCode(phone: String) async throws {
        _ = try await execute(.smsSend, fields: ["phone": AuthChannelInput.phone(phone)])
    }
    public func sendBoundDeregistrationCode(phone: String) async throws {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AuthChannelError.invalidPhone }
        try Task.checkCancellation()
        var request = try AccountPublishMPContract.smsSendRequest(baseURL: builder.configuration.baseURL, phone: trimmed)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        if status == 401 { throw APIError.unauthorized }
        if status == 429 { throw AuthChannelError.rateLimited }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let body: StatusEnvelope
        do { body = try JSONDecoder().decode(StatusEnvelope.self, from: data) }
        catch { throw APIError.malformedResponse }
        if body.code == 401 { throw APIError.unauthorized }
        if body.code == 429 { throw AuthChannelError.rateLimited }
        if body.code != 200, let typed = AuthChannelError.sms(errorCode: body.errorCode) { throw typed }
        guard body.code == 200 else { throw APIError.businessCode(body.code) }
    }
    public func loginWithPhone(phone: String, code: String) async throws -> LoginResult {
        try await login(.phone, fields: ["phone": AuthChannelInput.phone(phone), "code": AuthChannelInput.code(code)])
    }
    public func loginWithApple(identityToken: String) async throws -> LoginResult {
        try await loginWithApple(identityToken: identityToken, givenName: nil, familyName: nil)
    }
    public func loginWithApple(identityToken: String, givenName: String?, familyName: String?) async throws -> LoginResult {
        // The opaque Apple credential is exchanged with the existing backend. This is
        // transport validation only, never a claim that the JWT signature was verified.
        guard AuthRequestBuilder.isValidToken(identityToken) else { throw AuthChannelError.invalidAppleCredential }
        var fields = ["identityToken": identityToken]
        // P2-5: `POST /api/login/apple` form fields `givenName` / `familyName` (backend uses them only for a new account).
        if let given = Self.appleNamePart(givenName) { fields["givenName"] = given }
        if let family = Self.appleNamePart(familyName) { fields["familyName"] = family }
        return try await login(.apple, fields: fields)
    }
    /// Trimmed, control characters removed, at most 30 characters (the backend cap); nil when empty.
    static func appleNamePart(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = String(String.UnicodeScalarView(value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(30))
    }
    private func login(_ endpoint: AuthEndpoint, fields: [String: String]) async throws -> LoginResult {
        let data = try await execute(endpoint, fields: fields)
        let body: Envelope
        do { body = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw APIError.malformedResponse }
        guard let token = body.token, AuthRequestBuilder.isValidToken(token),
              let account = body.data, account.id > 0 else { throw APIError.malformedResponse }
        return LoginResult(token: token, account: account)
    }
    public func currentAccount(token: String) async throws -> Account {
        try await currentAccount(token: token, loginFallbackRole: nil)
    }
    public func currentAccount(token: String, loginFallbackRole: String?) async throws -> Account {
        try Task.checkCancellation()
        var result = try await auth.currentAccount(token: token)
        if result.role.isEmpty, allowLoginRoleFallback,
           let fallback = loginFallbackRole, ["player", "club", "merchant"].contains(fallback) {
            result = result.withFallbackRole(fallback)
        }
        guard ["player", "club", "merchant"].contains(result.role) else { throw APIError.malformedResponse }
        try Task.checkCancellation()
        return result
    }
}
