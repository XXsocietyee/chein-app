import Foundation
import Observation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum VerificationCodeKind: String, Hashable { case ticket, cityVoucher }
public enum VerificationCodeFailure: Error, Equatable { case disabled, login, invalid, expired, unavailable, failed, stale }
public struct VerificationCodeTarget: Equatable {
    public let kind: VerificationCodeKind
    public let id: Int
    public init(kind: VerificationCodeKind, id: Int) { self.kind = kind; self.id = id }
    public var issuePath: String { kind == .ticket ? "api/verify/dyncode/issue" : "api/verify/citynode/issue" }
}

/// Memory-only server receipt. No encoder, storage, logging or user-entered code path.
/// Shape checks bind the response to the request; only the server verifies its signature.
public struct VerificationCodeReceipt: Decodable {
    private let code: String
    public let expiresAtMilliseconds: Int64
    public let ttlMilliseconds: Int64
    private let type: String?
    private let poiID: Int?
    enum CodingKeys: String, CodingKey { case code, expiresAt, ttlMs, type, poiId }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)
        expiresAtMilliseconds = try c.decode(Int64.self, forKey: .expiresAt)
        ttlMilliseconds = try c.decode(Int64.self, forKey: .ttlMs)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        poiID = try c.decodeIfPresent(Int.self, forKey: .poiId)
        guard !code.isEmpty, code.utf8.count <= 2048, code.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value <= 126 }),
              expiresAtMilliseconds > 0, (1...300_000).contains(ttlMilliseconds) else { throw VerificationCodeFailure.invalid }
    }
    public var expiry: Date { Date(timeIntervalSince1970: Double(expiresAtMilliseconds) / 1000) }
    /// Largest server/device clock offset accepted (acceptance F-03: the TEST server ran ~7 s ahead).
    /// Beyond it the server's absolute expiry cannot be placed on this device's clock and the code is treated as expired.
    public static let maximumClockOffset: TimeInterval = 120
    public var ttl: TimeInterval { Double(ttlMilliseconds) / 1000 }
    /// Issue instant on the SERVER's clock: the signed absolute expiry minus the TTL.
    public var serverIssuedAt: Date { expiry.addingTimeInterval(-ttl) }
    /// Device-clock expiry of a code requested at `requestedAt` and received at `receivedAt`.
    /// The server minted it somewhere in [requestedAt, receivedAt] on this device's clock, so the observed
    /// clock offset is `serverIssuedAt − deviceIssue`. Within ±`maximumClockOffset` the code lives for its TTL
    /// from `requestedAt` (the earliest possible issue instant, so the lifetime is never extended past the
    /// server's). Comparing the server's absolute expiry to the device clock instead made a 7 s fast server
    /// look expired at once. A code minted long before the request (or a wildly wrong clock) is expired.
    public func localExpiry(requestedAt: Date, receivedAt: Date) throws -> Date {
        guard receivedAt >= requestedAt else { throw VerificationCodeFailure.expired }
        let largestOffset = serverIssuedAt.timeIntervalSince(requestedAt)
        let smallestOffset = serverIssuedAt.timeIntervalSince(receivedAt)
        guard smallestOffset <= Self.maximumClockOffset, largestOffset >= -Self.maximumClockOffset else {
            throw VerificationCodeFailure.expired
        }
        return requestedAt.addingTimeInterval(ttl)
    }
    func validatedCode(target: VerificationCodeTarget, accountID: Int, requestedAt: Date, now: Date) throws -> String {
        try validated(target: target, accountID: accountID, requestedAt: requestedAt, now: now).code
    }
    /// The exact server code plus its device-clock expiry (see `localExpiry`).
    func validated(target: VerificationCodeTarget, accountID: Int, requestedAt: Date, now: Date) throws -> (code: String, expiry: Date) {
        let parts = code.split(separator: ".", omittingEmptySubsequences: false)
        guard target.id > 0, accountID > 0, parts.count == 6, parts[0] == "v1", Int(parts[1]) == target.id,
              Int64(parts[3]) == expiresAtMilliseconds, Int64(parts[4]) != nil,
              parts[5].utf8.count == 43, parts[5].utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else { throw VerificationCodeFailure.invalid }
        switch target.kind {
        case .ticket:
            guard let type, ["activity", "topic"].contains(type), parts[2] == Substring(type) else { throw VerificationCodeFailure.invalid }
        case .cityVoucher:
            guard poiID == target.id, parts[2] == Substring("citynode_\(accountID)") else { throw VerificationCodeFailure.invalid }
        }
        // Absolute server milliseconds are mandatory (bound to the signed payload above) and anchor the issue
        // instant. The lifetime is the server TTL measured on this device's clock, never longer.
        guard now >= requestedAt else { throw VerificationCodeFailure.expired }
        let expiry = try localExpiry(requestedAt: requestedAt, receivedAt: now)
        guard expiry > now else { throw VerificationCodeFailure.expired }
        return (code, expiry)
    }
}

/// Separate, composition-only grant. Neither a URL nor a gameplay grant enables issuance.
public struct VerificationCodeApproval {
    public let market: RegionalMarket
    public let endpoints: OperationEndpointApproval
    public let kinds: Set<VerificationCodeKind>
    public init(market: RegionalMarket, endpoints: OperationEndpointApproval, kinds: Set<VerificationCodeKind> = []) {
        self.market = market; self.endpoints = endpoints; self.kinds = kinds
    }
    public func allows(_ kind: VerificationCodeKind, context: RuntimeDependencyContext) -> Bool {
        let required: Set<String> = kind == .ticket ? ["api/verify/dyncode/issue", "api/registration/info"] : ["api/verify/citynode/issue"]
        return market == .china && context.market == market && endpoints.baseURL == context.baseURL &&
            endpoints.namespace == context.session.namespace && endpoints.accountID == context.session.accountID &&
            kinds.contains(kind) && required.isSubset(of: endpoints.paths)
    }
}
@MainActor public protocol VerificationCodeServing {
    var enabled: Bool { get }
    func issue(_ target: VerificationCodeTarget, context: RuntimeDependencyContext) async throws -> VerificationCodeReceipt
    func order(id: Int, context: RuntimeDependencyContext) async throws -> OrderLifecycleDetail
}
@MainActor public struct VerificationCodeHTTPService: VerificationCodeServing {
    private let configuration: APIConfiguration?
    private let approval: VerificationCodeApproval?
    private let captured: RuntimeDependencyContext?
    private let current: () -> RuntimeDependencyContext?
    private let transport: any HTTPTransport
    private let kind: VerificationCodeKind
    public init(configuration: APIConfiguration?, approval: VerificationCodeApproval? = nil, kind: VerificationCodeKind,
                transport: any HTTPTransport, current: @escaping () -> RuntimeDependencyContext?) {
        self.configuration = configuration; self.approval = approval; self.kind = kind
        self.current = current; captured = current()
        let scoped = approval.map { RuntimeDependencyConfiguration(market: $0.market, endpoints: $0.endpoints) }
        self.transport = RuntimeDependencyTransport(configuration: scoped, captured: captured, transport: transport, current: current)
    }
    public var enabled: Bool {
        guard let configuration, let approval, let captured, current() == captured, configuration.baseURL == captured.baseURL else { return false }
        return approval.allows(kind, context: captured)
    }
    private func require(_ context: RuntimeDependencyContext) throws -> APIConfiguration {
        guard enabled, context == captured, let configuration else { throw VerificationCodeFailure.disabled }
        try Task.checkCancellation(); return configuration
    }
    public func issue(_ target: VerificationCodeTarget, context: RuntimeDependencyContext) async throws -> VerificationCodeReceipt {
        let configuration = try require(context)
        guard target.kind == kind, target.id > 0 else { throw VerificationCodeFailure.invalid }
        let request: URLRequest
        switch kind {
        case .ticket:
            request = try OrderLifecycleRequestContract.issueTicket(registrationID: target.id, baseURL: configuration.baseURL, token: context.session.token)
        case .cityVoucher:
            request = try RoamExperienceMutation.issueVoucher(poiID: target.id).request(configuration: configuration, token: context.session.token)
        }
        let (data, status) = try await transport.send(request)
        _ = try require(context)
        if status == 401 { throw VerificationCodeFailure.login }
        if status == 403 || status == 410 { throw VerificationCodeFailure.unavailable }
        guard (200..<300).contains(status) else { throw VerificationCodeFailure.failed }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }
    public func order(id: Int, context: RuntimeDependencyContext) async throws -> OrderLifecycleDetail {
        let configuration = try require(context)
        guard kind == .ticket else { throw VerificationCodeFailure.invalid }
        let result = try await OrderLifecycleService(configuration: configuration, transport: transport).detail(id: id, token: context.session.token)
        _ = try require(context); return result
    }
    private struct Envelope: Decodable {
        let data: VerificationCodeReceipt
        enum CodingKeys: String, CodingKey { case code, data }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let code = try c.decode(Int.self, forKey: .code)
            if code == 401 { throw VerificationCodeFailure.login }
            if code == 403 || code == 410 { throw VerificationCodeFailure.unavailable }
            guard code == 200 else { throw VerificationCodeFailure.failed }
            data = try c.decode(VerificationCodeReceipt.self, forKey: .data)
        }
    }
}

/// MP `subpackageMember/signup/index.js` ticket QR (V-02): renew `leadSeconds` before expiry,
/// and never sooner than `retrySeconds` after the last try. A failure inside that last window stops.
/// Issuing a code moves no money.
public enum TicketEntryCodeRefresh {
    public static let leadSeconds: TimeInterval = 30
    public static let retrySeconds: TimeInterval = 5
    public static func next(expiry: Date, now: Date) -> Date {
        max(expiry.addingTimeInterval(-leadSeconds), now.addingTimeInterval(retrySeconds))
    }
}

@MainActor @Observable public final class VerificationCodeCoordinator {
    public enum Phase: String { case review, loading, ready, expired, paused, disabled, login, invalid, unavailable, failed, stale }
    public let target: VerificationCodeTarget
    public private(set) var phase: Phase = .review
    public private(set) var remainingSeconds = 0
    public private(set) var readback: OrderLifecycleDetail?
    public private(set) var checkingOrder = false
    public private(set) var readbackFailed = false
    /// RCODE-2: the last `.failed` came from the transport (no connection / timeout), not from the server.
    public private(set) var failedOnNetwork = false
    private var code: String?
    private var expiry: Date?
    private var issuedAt: Date?
    private var owner: RuntimeDependencyContext?
    private var generation: UInt64 = 0
    private var active = false
    private var issuing = false
    /// Next silent ticket renew. Nil after the code is dead, so a late tick cannot loop.
    private var nextSilentRenewAt: Date?
    private let service: any VerificationCodeServing
    private let current: () -> RuntimeDependencyContext?
    private let now: () -> Date
    private let onUnauthorized: (RuntimeDependencyContext) -> Void
    public init(target: VerificationCodeTarget, service: any VerificationCodeServing,
                current: @escaping () -> RuntimeDependencyContext?, now: @escaping () -> Date = Date.init,
                onUnauthorized: @escaping (RuntimeDependencyContext) -> Void = { _ in }) {
        self.target = target; self.service = service; self.current = current; self.now = now; self.onUnauthorized = onUnauthorized
    }
    public var displayCode: String? {
        guard active, owner != nil, current() == owner, service.enabled, phase == .ready, expiry.map({ $0 > now() }) == true, issuedAt.map({ now() >= $0 }) == true else { return nil }
        return code
    }
    public func present() async {
        guard !issuing, !checkingOrder else { return }
        failedOnNetwork = false
        guard target.id > 0 else { clear(); phase = .invalid; return }
        guard let context = current() else { clear(); phase = .login; return }
        guard service.enabled else { clear(); phase = .disabled; return }
        generation &+= 1; owner = context; active = true
        await issue()
    }
    private func isCurrent(_ stamp: UInt64) -> Bool {
        active && generation == stamp && owner != nil && current() == owner && !Task.isCancelled
    }
    private func eraseCode() { code = nil; expiry = nil; issuedAt = nil; remainingSeconds = 0; nextSilentRenewAt = nil }
    private func clear() {
        generation &+= 1; active = false; owner = nil; issuing = false; checkingOrder = false
        readback = nil; readbackFailed = false; eraseCode()
    }
    public func pause() { clear(); phase = .paused }
    public func invalidate() { clear(); phase = .review }
    /// View-owned, cancellable one-second task. Ticket codes renew silently before expiry
    /// (`TicketEntryCodeRefresh`); a failed renew keeps the current code until the last few
    /// seconds, then stops. A clock jump past expiry clears and waits for a manual retry.
    /// City vouchers reissue only at expiry, never on a failed or uncertain response.
    public func tick() async {
        guard active else { return }
        guard current() == owner, service.enabled else { clear(); phase = .stale; return }
        guard let expiry else { return }
        if let issuedAt, now() < issuedAt { eraseCode(); phase = .expired; return }
        if target.kind == .ticket {
            await tickTicket(expiry: expiry)
            return
        }
        if now() >= expiry {
            eraseCode(); phase = .expired
            if target.kind == .cityVoucher { await issue() }
        } else {
            remainingSeconds = max(0, Int(expiry.timeIntervalSince(now()).rounded(.up)))
        }
    }
    /// Still inside the lead window: keep showing the current code and renew once it is due.
    /// At or past expiry the code is already dead, so this does not mint another one.
    private func tickTicket(expiry: Date) async {
        if now() >= expiry {
            eraseCode(); phase = .expired
            return
        }
        remainingSeconds = max(0, Int(expiry.timeIntervalSince(now()).rounded(.up)))
        guard let due = nextSilentRenewAt, now() >= due, !issuing else { return }
        await renewTicket(keeping: expiry)
    }
    /// Silent renew (MP `_loadQr(..., true)`). The code on screen stays until a new receipt validates.
    /// An ended registration clears the code and does not mint another. A scanned chapter does not:
    /// the registration can stay active, and this path never reads the verification field.
    private func renewTicket(keeping previousExpiry: Date) async {
        guard active, !issuing, let owner, current() == owner, target.kind == .ticket else { return }
        let stamp = generation
        issuing = true
        defer { if generation == stamp { issuing = false } }
        do {
            let detail = try await service.order(id: target.id, context: owner)
            guard isCurrent(stamp) else { return }
            guard detail.id == target.id else { throw VerificationCodeFailure.invalid }
            readback = detail
            guard detail.registrationStatus == 2 else { throw VerificationCodeFailure.unavailable }
            let requestedAt = now()
            let receipt = try await service.issue(target, context: owner)
            guard isCurrent(stamp) else { return }
            let validated = try receipt.validated(target: target, accountID: owner.session.accountID, requestedAt: requestedAt, now: now())
            code = validated.code; expiry = validated.expiry; issuedAt = requestedAt
            remainingSeconds = max(0, Int(validated.expiry.timeIntervalSince(now()).rounded(.up))); phase = .ready
            nextSilentRenewAt = TicketEntryCodeRefresh.next(expiry: validated.expiry, now: now())
        } catch {
            guard isCurrent(stamp) else { return }
            if error as? APIError == .unauthorized || error as? VerificationCodeFailure == .login {
                fail(error, stamp: stamp); return
            }
            if error as? VerificationCodeFailure == .unavailable {
                eraseCode(); phase = .unavailable; return
            }
            if now() < previousExpiry.addingTimeInterval(-TicketEntryCodeRefresh.retrySeconds), self.expiry != nil, phase == .ready {
                nextSilentRenewAt = now().addingTimeInterval(TicketEntryCodeRefresh.retrySeconds)
                return
            }
            eraseCode(); phase = .failed
        }
    }
    private func issue() async {
        guard active, !issuing, let owner, current() == owner else { return }
        let stamp = generation
        issuing = true; eraseCode(); phase = .loading; readbackFailed = false
        defer { if generation == stamp { issuing = false } }
        do {
            if target.kind == .ticket {
                let detail = try await service.order(id: target.id, context: owner)
                guard isCurrent(stamp) else { return }
                guard detail.id == target.id else { throw VerificationCodeFailure.invalid }
                readback = detail
                // verificationStatus=1 can still have remaining chapters. Issuance is server-authoritative.
                guard detail.registrationStatus == 2 else { throw VerificationCodeFailure.unavailable }
            }
            let requestedAt = now()
            let receipt = try await service.issue(target, context: owner)
            guard isCurrent(stamp) else { return }
            let validated = try receipt.validated(target: target, accountID: owner.session.accountID, requestedAt: requestedAt, now: now())
            code = validated.code; expiry = validated.expiry; issuedAt = requestedAt
            remainingSeconds = max(0, Int(validated.expiry.timeIntervalSince(now()).rounded(.up))); phase = .ready
            if target.kind == .ticket {
                nextSilentRenewAt = TicketEntryCodeRefresh.next(expiry: validated.expiry, now: now())
            }
        } catch { fail(error, stamp: stamp) }
    }
    /// There is no ticket-code status endpoint. Read the authoritative registration record.
    public func checkOrder() async {
        guard target.kind == .ticket, active, !issuing, !checkingOrder, let owner, current() == owner else { return }
        let stamp = generation; checkingOrder = true; readbackFailed = false
        defer { if generation == stamp { checkingOrder = false } }
        do {
            let detail = try await service.order(id: target.id, context: owner)
            guard isCurrent(stamp) else { return }
            guard detail.id == target.id else { throw VerificationCodeFailure.invalid }
            readback = detail
            // A readback never claims a completed scan. Clear on an ended registration.
            if detail.registrationStatus != 2 { eraseCode(); phase = .unavailable }
        } catch {
            guard isCurrent(stamp) else { return }
            if error as? APIError == .unauthorized || error as? VerificationCodeFailure == .login { fail(error, stamp: stamp) }
            else { readbackFailed = true }
        }
    }
    private func fail(_ error: Error, stamp: UInt64) {
        guard isCurrent(stamp) else { return }
        eraseCode()
        if error as? APIError == .unauthorized || error as? VerificationCodeFailure == .login {
            let captured = owner; clear(); phase = .login; if let captured { onUnauthorized(captured) }; return
        }
        let failure = error as? VerificationCodeFailure
        switch failure {
        case .disabled: phase = .disabled
        case .expired: phase = .expired
        case .invalid: phase = .invalid
        case .unavailable: phase = .unavailable
        case .stale: phase = .stale
        default:
            phase = .failed
            failedOnNetwork = error is URLError || (error as NSError).domain == NSURLErrorDomain
        }
    }
}
