import Foundation
import Observation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Only the original service can mint this single exact dispatch after its independent grant check.
@MainActor public final class ModUpgradeDispatchAuthorization {
    public let context: RuntimeDependencyContext
    private let original: URLRequest
    private let current: () throws -> Void
    private var consumed = false
    fileprivate init(context: RuntimeDependencyContext, request: URLRequest, current: @escaping () throws -> Void) {
        self.context = context; original = request; self.current = current
    }
    public func validate() throws { try Task.checkCancellation(); try current() }
    public func consume(_ request: URLRequest, context: RuntimeDependencyContext) throws {
        try validate()
        guard !consumed, ContentDraftContextFence.matches(self.context, context),
              self.context.role.utf8.elementsEqual(context.role.utf8),
              request.url == original.url, request.httpMethod == original.httpMethod, request.httpBody == original.httpBody,
              request.httpBodyStream == nil, request.allHTTPHeaderFields == original.allHTTPHeaderFields,
              request.value(forHTTPHeaderField: "Authorization").map({ $0.utf8.elementsEqual(context.session.token.utf8) }) == true else { throw ModUpgradeIssue.staleSession }
        consumed = true
    }
}
@MainActor public protocol ModUpgradeDispatchTransport: AnyObject {
    func sendModUpgrade(_ request: URLRequest, authorization: ModUpgradeDispatchAuthorization) async throws -> (Data, Int)
}

@MainActor public protocol ModUpgradeServing: AnyObject {
    var isCurrent: Bool { get }
    var canStage: Bool { get }
    var rejectionReason: String? { get }
    func invalidate()
    func versions(source: ModInstallationIdentity, before: String?) async throws -> ModUpgradeVersionPage
    func stage(_ intent: ModUpgradeIntent, attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt
    func request(_ intent: ModUpgradeIntent) async throws -> ModInstallationReceipt
}

public extension ModUpgradeServing { var rejectionReason: String? { nil } }

/// New reviewed endpoint, deliberately separate from both commerce purchase and installation authority.
@MainActor @Observable public final class ModUpgradeService: ModUpgradeServing {
    private let lease: ContentDraftSessionLease
    private let approval: ModUpgradeApproval
    private let currentApproval: () -> ModUpgradeApproval?
    private let transport: any HTTPTransport
    private let onUnauthorized: (RuntimeDependencyContext) -> Void
    private var revoked = false
    public private(set) var rejectionReason: String?
    public init(lease: ContentDraftSessionLease, approval: ModUpgradeApproval,
                currentApproval: @escaping () -> ModUpgradeApproval?, transport: any HTTPTransport = URLSessionTransport(),
                onUnauthorized: @escaping (RuntimeDependencyContext) -> Void = { _ in }) throws {
        guard approval.matches(lease.context), currentApproval()?.revision == approval.revision else { throw ModUpgradeIssue.disabled }
        self.lease = lease; self.approval = approval; self.currentApproval = currentApproval
        self.transport = transport; self.onUnauthorized = onUnauthorized
    }
    public var isCurrent: Bool { (try? check()) != nil }
    public var canStage: Bool { isCurrent && approval.stageApprovalReference != nil }
    public func invalidate() { revoked = true; lease.revoke() }
    private func check(mutating: Bool = false) throws {
        try Task.checkCancellation()
        guard !revoked, lease.isCurrent else { revoked = true; throw ModUpgradeIssue.staleSession }
        guard let latest = currentApproval(), latest.revision == approval.revision,
              latest.matches(lease.context), approval.matches(lease.context) else { revoked = true; throw ModUpgradeIssue.disabled }
        guard !mutating || approval.stageApprovalReference != nil else { throw ModUpgradeIssue.disabled }
    }
    public func versions(source: ModInstallationIdentity, before: String? = nil) async throws -> ModUpgradeVersionPage {
        try source.validate()
        if let before { try ModInstallationValidation.key(before) }
        let data = try await send("licenses/" + source.licenseId + "/versions", before: before)
        try ModUpgradeWire.versions(data)
        let page = try JSONDecoder().decode(Envelope<ModUpgradeVersionPage>.self, from: data).data
        try page.validate(source: source)
        guard before == nil || page.nextCursor != before else { throw ModUpgradeIssue.malformed }
        try check(); return page
    }
    public func stage(_ intent: ModUpgradeIntent, attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt {
        try intent.validate(); try attempt.validate()
        guard intent.installation == attempt.request, intent.target == attempt.identity else { throw ModUpgradeIssue.pendingConflict }
        rejectionReason = nil
        let data = try await send("requests", body: JSONEncoder().encode(ModUpgradeStageCommand(intent: intent)))
        try ModInstallationWire.validate(data, route: "requests")
        let receipt = try JSONDecoder().decode(Envelope<ModInstallationReceipt>.self, from: data).data
        try attempt.validate(receipt: receipt); try check(mutating: true); return receipt
    }
    public func request(_ intent: ModUpgradeIntent) async throws -> ModInstallationReceipt {
        try intent.validate()
        guard let original = intent.installation, let target = intent.target else { throw ModUpgradeIssue.pendingConflict }
        let data = try await send("requests/" + original.requestId)
        try ModInstallationWire.validate(data, route: "requests/" + original.requestId)
        let receipt = try JSONDecoder().decode(Envelope<ModInstallationReceipt>.self, from: data).data
        try receipt.validate(identity: target)
        guard receipt.requestId == original.requestId, receipt.merchantId == original.merchantId,
              receipt.anchorPoiId == original.anchorPoiId,
              receipt.bindings.map(\.binding).sorted(by: { $0.id < $1.id }) == original.bindings.sorted(by: { $0.id < $1.id }) else { throw ModUpgradeIssue.malformed }
        try check(); return receipt
    }
    private struct Envelope<T: Decodable>: Decodable { let code: Int; let data: T }
    private struct Code: Decodable { let code: Int; let msg: String? }
    private func send(_ route: String, body: Data? = nil, before: String? = nil) async throws -> Data {
        try check(mutating: body != nil)
        guard var parts = URLComponents(url: lease.context.baseURL.appendingPathComponent("api/mod-upgrade/" + route), resolvingAgainstBaseURL: false) else { throw ModUpgradeIssue.disabled }
        if let before { parts.queryItems = [URLQueryItem(name: "before", value: before)] }
        guard let url = parts.url, parts.scheme == "https", parts.user == nil, parts.password == nil, parts.fragment == nil else { throw ModUpgradeIssue.disabled }
        var request = URLRequest(url: url); request.httpMethod = body == nil ? "GET" : "POST"; request.httpBody = body
        request.setValue(lease.context.session.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control"); request.cachePolicy = .reloadIgnoringLocalCacheData
        try check(mutating: body != nil)
        let response: (Data, Int)
        if let scoped = transport as? any ModUpgradeDispatchTransport {
            let mutating = body != nil
            let authorization = ModUpgradeDispatchAuthorization(context: lease.context, request: request) { [weak self] in
                guard let self else { throw ModUpgradeIssue.staleSession }; try self.check(mutating: mutating)
            }
            response = try await scoped.sendModUpgrade(request, authorization: authorization)
        } else {
            // Explicitly injected domain transports retain the same service grant/lease checks.
            response = try await transport.send(request)
        }
        let (data, status) = response
        try check(mutating: body != nil)
        guard data.count <= 1048576, let text = String(data: data, encoding: .utf8),
              (try? ContentDraftJSON.parse(text)) != nil else { throw ModUpgradeIssue.malformed }
        let code = try? JSONDecoder().decode(Code.self, from: data).code
        if status == 401 || code == 401 {
            try check(); onUnauthorized(lease.context); invalidate(); throw ModUpgradeIssue.unauthorized
        }
        if status == 404 || code == 404 { throw ModUpgradeIssue.notFound }
        if body == nil, (status == 413 || code == 413),
           (try? JSONDecoder().decode(Code.self, from: data).msg) == "UPGRADE_COMPARISON_TOO_LARGE" {
            throw ModUpgradeIssue.comparisonTooLarge
        }
        if body != nil, code == 422, let reason = try? JSONDecoder().decode(Code.self, from: data).msg,
           reason.hasPrefix("UPGRADE_PREFLIGHT_REJECTED:"), reason.utf8.count <= 512 {
            rejectionReason = reason; throw ModUpgradeIssue.preflightRejected(reason)
        }
        guard (200..<300).contains(status), code == 200 else { throw ModUpgradeIssue.unavailable }
        return data
    }
}

enum ModUpgradeWire {
    static func versions(_ data: Data) throws {
        let root = try dictionary(JSONSerialization.jsonObject(with: data))
        try object(root, required: ["code", "data"], optional: ["msg"])
        let page = try dictionary(root["data"] as Any)
        try object(page, required: ["schema", "source", "sourceTitle", "candidates"], optional: ["nextCursor"])
        try object(dictionary(page["source"] as Any), required: ["licenseId", "moduleId", "releaseId", "contentHash", "termsHash"])
        for candidate in try array(page["candidates"], maximum: 50) {
            let row = try dictionary(candidate)
            try object(row, required: ["offerId", "title", "targetReleaseId", "targetContentHash", "targetTermsHash", "ordering", "authorization", "comparisonHash", "changedFields", "requiredBindings", "compatibility", "conflicts"], optional: ["packageId", "packageVersion", "targetLicenseId", "termsComparison"])
            _ = try array(row["changedFields"], maximum: 64); _ = try array(row["conflicts"], maximum: 64)
            for binding in try array(row["requiredBindings"], maximum: 32) { try object(dictionary(binding), required: ["key", "kind"]) }
            if let raw = row["termsComparison"], !(raw is NSNull) {
                let comparison = try dictionary(raw)
                try object(comparison, required: ["schema", "creatorId", "source", "target"])
                try terms(comparison["source"] as Any); try terms(comparison["target"] as Any)
            }
        }
    }
    /// Do not silently drop a future rights restriction before the buyer's exact confirmation.
    private static func terms(_ raw: Any) throws {
        let value = try dictionary(raw)
        try object(value, required: ["version", "hash", "contentHash", "commercialUse", "allowedRegions", "installationLimit",
                                     "useDuration", "updatePolicy", "redistribution", "refundPolicyReference"], optional: ["compositionRights"])
        _ = try array(value["allowedRegions"], maximum: 32)
        if let rawRights = value["compositionRights"], !(rawRights is NSNull) {
            let rights = try dictionary(rawRights)
            try object(rights, required: ["profile", "applicationRequestId", "decisionId", "author", "reviewer", "sourceKind",
                                         "sourceId", "auditTaskId", "sourceHash", "draftHash", "packageId", "packageVersion",
                                         "releaseId", "contentHash", "scope", "approvedAt", "grantHash"])
            let scope = try dictionary(rights["scope"] as Any)
            try object(scope, required: ["authors", "installationSubjects", "venues", "regions", "commercialUse", "translation",
                                        "adaptation", "remix", "embeddedRedistribution", "evidenceReferences"],
                       optional: ["venueScopeVersion", "venuePoiIds"])
            for field in ["authors", "installationSubjects", "venues"] { _ = try array(scope[field], maximum: 128) }
            for field in ["regions", "evidenceReferences"] { _ = try array(scope[field], maximum: 32) }
            if let pois = scope["venuePoiIds"], !(pois is NSNull) { _ = try array(pois, maximum: 128) }
        }
    }
    private static func dictionary(_ value: Any) throws -> [String: Any] {
        guard let value = value as? [String: Any] else { throw ModUpgradeIssue.malformed }; return value
    }
    private static func array(_ value: Any?, maximum: Int) throws -> [Any] {
        guard let value = value as? [Any], value.count <= maximum else { throw ModUpgradeIssue.malformed }; return value
    }
    private static func object(_ value: [String: Any], required: Set<String>, optional: Set<String> = []) throws {
        let actual = Set(value.keys)
        guard required.isSubset(of: actual), actual.isSubset(of: required.union(optional)) else { throw ModUpgradeIssue.malformed }
    }
}
