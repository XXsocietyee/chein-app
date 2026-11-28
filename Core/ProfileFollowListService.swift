import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A separate read lease. Adding a list never grants the existing follow or chat writer permission.
public struct ProfileFollowListApproval: Equatable {
    public static let path = "api/user/follow-list"
    public static let paths: Set<String> = [path, ProfilePublicInfoReadRoute.path]
    public let endpoint: OperationEndpointApproval
    public let issuanceID: UUID
    public let expiresAt: Date
    public init(endpoint: OperationEndpointApproval, expiresAt: Date, issuanceID: UUID = UUID()) throws {
        guard endpoint.paths == Self.paths, expiresAt.timeIntervalSince1970.isFinite else { throw APIError.invalidConfiguration }
        self.endpoint = endpoint; self.expiresAt = expiresAt; self.issuanceID = issuanceID
    }
    public func matches(_ context: RuntimeDependencyContext, now: Date = Date()) -> Bool {
        context.market == .china && ["player", "club", "merchant"].contains(context.role) &&
        endpoint.baseURL == context.baseURL && endpoint.accountID == context.session.accountID &&
        endpoint.namespace == context.session.namespace && now < expiresAt
    }
}
public enum ProfileFollowListTransportPolicy {
    public static func accepts(_ request: URLRequest, context: RuntimeDependencyContext, approval: ProfileFollowListApproval) -> Bool {
        guard approval.matches(context), request.value(forHTTPHeaderField: "Authorization") == context.session.token,
              !request.httpShouldHandleCookies, request.httpBodyStream == nil,
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil else { return false }
        if ProfilePublicInfoReadRoute(request: request, baseURL: context.baseURL) != nil { return true }
        guard request.httpMethod == "GET", request.httpBody == nil,
              request.value(forHTTPHeaderField: "Accept") == "application/json",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let fields = components.queryItems, fields.count == 3,
              Set(fields.map(\.name)) == ["kind", "cursor", "limit"] else { return false }
        let values = Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.value ?? "") })
        guard ProfileFollowListKind(rawValue: values["kind"] ?? "") != nil,
              let raw = values["cursor"], let cursor = Int(raw), cursor >= 0, raw == String(cursor),
              values["limit"] == "50" else { return false }
        components.query = nil
        return components.url == context.baseURL.appendingPathComponent(ProfileFollowListApproval.path)
    }
}
@MainActor public final class ProfileFollowListDispatchTransport: HTTPTransport {
    private let dispatch: (URLRequest) async throws -> (Data, Int)
    public init(_ dispatch: @escaping (URLRequest) async throws -> (Data, Int)) { self.dispatch = dispatch }
    public func send(_ request: URLRequest) async throws -> (Data, Int) { try await dispatch(request) }
}

@MainActor public final class ProfileFollowListService: ProfileFollowListReading {
    public let scope = UUID()
    private let context: RuntimeDependencyContext
    private let approval: ProfileFollowListApproval
    private let transport: any HTTPTransport
    private let current: () -> RuntimeDependencyContext?
    private let currentApproval: () -> ProfileFollowListApproval?
    private let onUnauthorized: (RuntimeDependencyContext) -> Void
    private var retired = false
    public var identity: SocialAccountIdentity { .init(accountID: context.session.accountID, epoch: context.session.epoch, role: context.role) }
    public var isOfflineExample: Bool { false }
    public var isConfigured: Bool { isCurrent }
    public var isCurrent: Bool {
        guard !retired else { return false }
        guard current() == context, currentApproval() == approval, approval.matches(context) else { retired = true; return false }
        return true
    }
    public init(context: RuntimeDependencyContext, approval: ProfileFollowListApproval, transport: any HTTPTransport,
                current: @escaping () -> RuntimeDependencyContext?, currentApproval: @escaping () -> ProfileFollowListApproval?,
                onUnauthorized: @escaping (RuntimeDependencyContext) -> Void = { _ in }) throws {
        guard approval.matches(context), AuthRequestBuilder.isValidToken(context.session.token) else { throw APIError.invalidConfiguration }
        self.context = context; self.approval = approval; self.transport = transport
        self.current = current; self.currentApproval = currentApproval; self.onUnauthorized = onUnauthorized
    }
    private func fence() throws {
        try Task.checkCancellation()
        guard isCurrent else { throw CancellationError() }
    }
    private func send(_ request: URLRequest) async throws -> (Data, Int) {
        try fence()
        guard ProfileFollowListTransportPolicy.accepts(request, context: context, approval: approval) else { throw APIError.notConfigured }
        do {
            let result = try await transport.send(request)
            try fence(); return result
        } catch { try fence(); throw error }
    }
    private func read<T>(_ operation: () async throws -> T) async throws -> T {
        try fence()
        do { let value = try await operation(); try fence(); return value }
        catch {
            try fence()
            if error as? APIError == .unauthorized { onUnauthorized(context) }
            throw error
        }
    }
    public func page(kind: ProfileFollowListKind, cursor: Int) async throws -> ProfileFollowListPage {
        guard cursor >= 0 else { throw APIError.invalidRequest }
        return try await read {
            guard var parts = URLComponents(url: context.baseURL.appendingPathComponent(ProfileFollowListApproval.path), resolvingAgainstBaseURL: false) else { throw APIError.invalidConfiguration }
            parts.queryItems = [URLQueryItem(name: "cursor", value: String(cursor)), URLQueryItem(name: "kind", value: kind.rawValue), URLQueryItem(name: "limit", value: "50")]
            guard let url = parts.url else { throw APIError.invalidRequest }
            var request = URLRequest(url: url); request.httpMethod = "GET"; request.httpShouldHandleCookies = false
            request.setValue(context.session.token, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, status) = try await send(request)
            let envelope = try? JSONDecoder().decode(SocialValue.self, from: data)
            if status == 401 || envelope?["code"].integer == 401 { throw APIError.unauthorized }
            guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
            guard let code = envelope?["code"].integer else { throw APIError.malformedResponse }
            guard code == 200 else { throw APIError.businessCode(code) }
            let page: ProfileFollowListPage
            do { page = try JSONDecoder().decode(Payload.self, from: data).data }
            catch { throw APIError.malformedResponse }
            try page.validate(owner: context.session.accountID, kind: kind, cursor: cursor)
            return page
        }
    }
    private struct Payload: Decodable { let data: ProfileFollowListPage }
    /// Narrow an already supplied two-read grant to the existing public-profile lifecycle.
    /// This does not issue permission: withdrawal/expiry of the original lease remains authoritative.
    public func makePublicProfileReader(memberID: Int, isCurrent selectedCurrent: @escaping () -> Bool) -> ProfilePublicInfoReader? {
        guard isCurrent, selectedCurrent(),
              let target = try? ProfilePublicInfoTarget(memberID: memberID, context: context, viewerRevision: 0,
                current: { [weak self] in self?.isCurrent == true && selectedCurrent() }),
              let endpoint = try? OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                accountID: context.session.accountID, paths: [ProfilePublicInfoReadRoute.path]),
              let access = try? ProfilePublicInfoReadAccess(context: context, approval: endpoint),
              let configuration = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        let guarded = ProfileFollowListDispatchTransport { [weak self] request in
            guard let self, target.isCurrent else { throw CancellationError() }
            return try await self.send(request)
        }
        return ProfilePublicInfoReader(target: target, configuration: configuration, transport: guarded,
            access: { [weak self] captured in
                guard let self, self.isCurrent, target.isCurrent, captured == self.context else { return nil }
                return access
            }, onUnauthorized: { [weak self] captured in
                guard let self, self.isCurrent, target.isCurrent, captured == self.context else { return }
                self.onUnauthorized(captured)
            })
    }
    public func publicProfile(memberID: Int) async throws -> SocialPublicProfile {
        try await read {
            let guarded = ProfileFollowListDispatchTransport { [weak self] request in
                guard let self else { throw CancellationError() }; return try await self.send(request)
            }
            return try await SocialAccountService(configuration: APIConfiguration(baseURL: context.baseURL), transport: guarded)
                .profile(memberID: memberID, token: context.session.token)
        }
    }
    public func informationList() async throws -> [SocialInformation] { throw APIError.notConfigured }
    public func information(id: Int) async throws -> SocialInformation { throw APIError.notConfigured }
    public func invitationHistory(page: Int) async throws -> SocialInviteHistory { throw APIError.notConfigured }
}
