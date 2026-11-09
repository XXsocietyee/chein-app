import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor public protocol ModInstallationServing: AnyObject {
    var isCurrent: Bool { get }
    var canMutate: Bool { get }
    var allowsAdditionalDrafts: Bool { get }
    var canReadCompatibility: Bool { get }
    func compatibility(identity: ModInstallationIdentity) async throws -> ModInstallationCompatibility
    func invalidate()
    /// Return a complete original directory only; partial pages/capacity failures must throw.
    func options(identity: ModInstallationIdentity, merchantId: Int64?) async throws -> ModInstallationOptions
    func prepare(_ attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt
    func request(_ requestId: String, identity: ModInstallationIdentity) async throws -> ModInstallationReceipt
    func install(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt
    func cancel(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt
    func preview(_ receipt: ModInstallationReceipt) async throws -> ModInstallationPreview
    func facts(_ receipt: ModInstallationReceipt) async throws -> ModInstallationFacts
    func confirmFacts(_ facts: ModInstallationFacts, receipt: ModInstallationReceipt) async throws -> ModInstallationFacts
    var canReviewInstalledTemplate: Bool { get }
    var canReadInstalledTemplateRehearsal: Bool { get }
    var canReadInstalledText: Bool { get }
    func installedText(_ installation: ModInstallationReceipt, acceptsResult: @escaping @MainActor () -> Bool) async throws -> ModInstalledTextRead
    func templateEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationTemplateEditorState
    func saveTemplateEdit(_ pending: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt
    func templateEditReceipt(_ pending: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt
    func qaEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationQaEditorState
    func saveQaEdit(_ pending: ModInstallationQaEditPending) async throws -> ModInstallationQaEditReceipt
    func qaEditReceipt(_ pending: ModInstallationQaEditPending) async throws -> ModInstallationQaEditReceipt
    /// Return only after the applicable original cursor tail (or exact selected upgrade intent).
    /// An incomplete ordinary history read cannot certify no PREPARED request.
    func history(identity: ModInstallationIdentity) async throws -> [ModInstallationReceipt]
    func venueWorkspace(_ installation: ModInstallationReceipt) async throws -> ModVenueWorkspace
    func venueCommand(_ pending: ModVenueOperationPending) async throws -> ModVenueOperationReceipt
    func venueReceipt(_ pending: ModVenueOperationPending) async throws -> ModVenueOperationReceipt
    func venueCode(_ installation: ModInstallationReceipt, node: Int64) async throws -> ModVenueIssuedCode
}

public extension ModInstallationServing {
    func venueWorkspace(_ installation: ModInstallationReceipt) async throws -> ModVenueWorkspace { throw ModInstallationIssue.unavailable }
    func venueCommand(_ pending: ModVenueOperationPending) async throws -> ModVenueOperationReceipt { throw ModInstallationIssue.unavailable }
    func venueReceipt(_ pending: ModVenueOperationPending) async throws -> ModVenueOperationReceipt { throw ModInstallationIssue.unavailable }
    func venueCode(_ installation: ModInstallationReceipt, node: Int64) async throws -> ModVenueIssuedCode { throw ModInstallationIssue.unavailable }
    var allowsAdditionalDrafts: Bool { true }
    var canReadCompatibility: Bool { false }
    func compatibility(identity: ModInstallationIdentity) async throws -> ModInstallationCompatibility { throw ModInstallationIssue.unavailable }
    var canReviewInstalledTemplate: Bool { false }
    var canReadInstalledTemplateRehearsal: Bool { false }
    var canReadInstalledText: Bool { false }
    func installedText(_ installation: ModInstallationReceipt, acceptsResult: @escaping @MainActor () -> Bool) async throws -> ModInstalledTextRead { throw ModInstallationIssue.disabled }
    func templateEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationTemplateEditorState { throw ModInstallationIssue.unavailable }
    func saveTemplateEdit(_ pending: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt { throw ModInstallationIssue.unavailable }
    func templateEditReceipt(_ pending: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt { throw ModInstallationIssue.unavailable }
    func qaEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationQaEditorState { throw ModInstallationIssue.unavailable }
    func saveQaEdit(_ pending: ModInstallationQaEditPending) async throws -> ModInstallationQaEditReceipt { throw ModInstallationIssue.unavailable }
    func qaEditReceipt(_ pending: ModInstallationQaEditPending) async throws -> ModInstallationQaEditReceipt { throw ModInstallationIssue.unavailable }
}

/// Exact installation-domain routes only. Explicit installed-template REVIEW requires a separate reviewed deployment grant; never approves or publishes.
/// No redirects, cookies or shared caches; identity, login epoch and approval checked around every await.
@MainActor public final class ModInstallationService: ModInstallationServing {
    private let lease: ContentDraftSessionLease
    private let approval: ModInstallationApproval
    private let currentApproval: () -> ModInstallationApproval?
    private let session: URLSession
    private let onUnauthorized: (RuntimeDependencyContext) -> Void
    private var revoked = false
    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    }
    public init(lease: ContentDraftSessionLease, approval: ModInstallationApproval,
                currentApproval: @escaping () -> ModInstallationApproval?,
                onUnauthorized: @escaping (RuntimeDependencyContext) -> Void = { _ in }) throws {
        guard approval.matches(lease.context), currentApproval()?.revision == approval.revision else { throw ModInstallationIssue.disabled }
        self.lease = lease; self.approval = approval; self.currentApproval = currentApproval; self.onUnauthorized = onUnauthorized
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30; configuration.timeoutIntervalForResource = 45
        session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }
    public var isCurrent: Bool { (try? check()) != nil }
    public var canReadCompatibility: Bool { isCurrent && approval.compatibilityReadApprovalReference != nil }
    public func compatibility(identity: ModInstallationIdentity) async throws -> ModInstallationCompatibility {
        guard canReadCompatibility else { throw ModInstallationIssue.disabled }
        try identity.validate()
        let result: ModInstallationCompatibility = try await send("licenses/" + key(identity.licenseId) + "/compatibility",
            query: [URLQueryItem(name: "clientVersion", value: "7"), URLQueryItem(name: "runtimeVersion", value: "1")])
        try result.validate(identity); return result
    }
    public var canMutate: Bool { isCurrent && approval.installApprovalReference != nil }
    public var canReviewInstalledTemplate: Bool { canMutate && approval.templateReviewApprovalReference != nil }
    public var canReadInstalledTemplateRehearsal: Bool { isCurrent && approval.templateRehearsalReadApprovalReference != nil }
    /// A receipt/read/install grant cannot enable protected source text.
    public var canReadInstalledText: Bool { isCurrent && approval.installedTextReadApprovalReference != nil }
    public func installedText(_ installation: ModInstallationReceipt, acceptsResult: @escaping @MainActor () -> Bool) async throws -> ModInstalledTextRead {
        try installation.validate(identity: installation.identity)
        guard canReadInstalledText, acceptsResult(), installation.memberTemplateID != nil, installation.composition == nil else { throw ModInstallationIssue.disabled }
        let result: ModInstalledTextRead = try await send("requests/" + key(installation.requestId) + "/installed-text",
            acceptsResult: { [weak self] in acceptsResult() && self?.canReadInstalledText == true })
        guard canReadInstalledText, acceptsResult() else { throw ModInstallationIssue.disabled }
        try result.validate(installation); return result
    }
    public func invalidate() { revoked = true; lease.revoke(); session.invalidateAndCancel() }
    private func check(mutating: Bool = false) throws {
        try Task.checkCancellation()
        guard !revoked, lease.isCurrent else { revoked = true; throw ModInstallationIssue.staleSession }
        guard let latest = currentApproval(), latest.revision == approval.revision,
              latest.matches(lease.context), approval.matches(lease.context) else { revoked = true; throw ModInstallationIssue.disabled }
        guard !mutating || approval.installApprovalReference != nil else { throw ModInstallationIssue.disabled }
    }
    private func key(_ value: String) throws -> String { try ModInstallationValidation.key(value); return value }
    public func options(identity: ModInstallationIdentity, merchantId: Int64? = nil) async throws -> ModInstallationOptions {
        try identity.validate()
        if let merchantId { guard merchantId > 0 else { throw ModInstallationIssue.invalidSelection } }
        // No legacy first-page fallback: an old server without paging cannot prove a complete directory.
        var source: ModInstallationOptionPage?
        var count = 0, bytes = 0
        var merchants: [ModInstallationResource] = [], resources: [ModInstallationResource] = []
        let scopes: [(Int64?, ModInstallationKind)] = [(nil, .site)] +
            (merchantId.map { owner in ModInstallationKind.allCases.map { (Optional(owner), $0) } } ?? [])
        for (owner, kind) in scopes {
            var cursor: Int64?
            repeat {
                try check()
                var query = [URLQueryItem(name: "kind", value: kind.rawValue)]
                if let owner { query.append(URLQueryItem(name: "merchantId", value: String(owner))) }
                if let cursor { query.append(URLQueryItem(name: "afterId", value: String(cursor))) }
                let page: ModInstallationOptionPage = try await send("licenses/" + key(identity.licenseId) + "/options-page", query: query)
                try page.validate(identity: identity, merchantId: owner, kind: kind, afterId: cursor)
                if let source { guard page.matchesSource(source) else { throw ModInstallationIssue.malformed } }
                else { source = page }
                try ModInstallationReadBudget.include(page.items, count: &count, bytes: &bytes)
                if owner == nil { merchants.append(contentsOf: page.items) } else { resources.append(contentsOf: page.items) }
                cursor = page.nextAfterId
            } while cursor != nil
        }
        try check()
        guard let source else { throw ModInstallationIssue.malformed }
        let result = ModInstallationOptions(schema: "mod-installation-options-v1", licenseId: identity.licenseId,
            moduleId: identity.moduleId, releaseId: identity.releaseId, contentHash: identity.contentHash,
            termsHash: identity.termsHash, title: source.title, requiredBindings: source.requiredBindings,
            merchants: merchants, resources: resources)
        try result.validate(licenseId: identity.licenseId, merchantId: merchantId)
        return result
    }
    public func prepare(_ attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt {
        try attempt.validate()
        guard attempt.receipt == nil else { throw ModInstallationIssue.pendingConflict }
        let result: ModInstallationReceipt = try await send("requests", method: "POST", body: JSONEncoder().encode(attempt.request))
        try attempt.validate(receipt: result); return result
    }
    public func request(_ requestId: String, identity: ModInstallationIdentity) async throws -> ModInstallationReceipt {
        let result: ModInstallationReceipt = try await send("requests/" + key(requestId))
        try result.validate(identity: identity)
        guard result.requestId == requestId else { throw ModInstallationIssue.malformed }
        return result
    }
    public func install(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt {
        try prepared.validate(identity: prepared.identity)
        guard prepared.state == .prepared else { throw ModInstallationIssue.pendingConflict }
        let result: ModInstallationReceipt = try await send("requests/" + key(prepared.requestId) + "/install", method: "POST")
        try result.validate(previous: prepared); return result
    }
    public func cancel(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt {
        try prepared.validate(identity: prepared.identity)
        guard prepared.state == .prepared else { throw ModInstallationIssue.pendingConflict }
        let result: ModInstallationReceipt = try await send("requests/" + key(prepared.requestId) + "/cancel", method: "POST")
        try result.validate(previous: prepared); return result
    }
    public func preview(_ receipt: ModInstallationReceipt) async throws -> ModInstallationPreview {
        try receipt.validate(identity: receipt.identity)
        guard receipt.state == .prepared else { throw ModInstallationIssue.pendingConflict }
        let result: ModInstallationPreview = try await send("requests/" + key(receipt.requestId) + "/preview")
        try result.validate(receipt: receipt); return result
    }
    public func facts(_ receipt: ModInstallationReceipt) async throws -> ModInstallationFacts {
        try receipt.validate(identity: receipt.identity)
        guard receipt.state == .installed else { throw ModInstallationIssue.pendingConflict }
        let result: ModInstallationFacts = try await send("requests/" + key(receipt.requestId) + "/facts")
        try result.validate(receipt: receipt); return result
    }
    public func confirmFacts(_ facts: ModInstallationFacts, receipt: ModInstallationReceipt) async throws -> ModInstallationFacts {
        try facts.validate(receipt: receipt)
        guard !facts.confirmed else { throw ModInstallationIssue.pendingConflict }
        let command = ModInstallationFactConfirmation(facts: facts)
        let result: ModInstallationFacts = try await send("requests/" + key(receipt.requestId) + "/facts",
            method: "POST", body: JSONEncoder().encode(command))
        try result.validate(receipt: receipt); try result.validateConfirmation(of: facts); return result
    }
    public func venueWorkspace(_ installation: ModInstallationReceipt) async throws -> ModVenueWorkspace {
        try installation.validate(identity: installation.identity)
        let result: ModVenueWorkspace = try await send("requests/" + key(installation.requestId) + "/venue")
        try result.validate(installation); return result
    }
    public func venueCommand(_ pending: ModVenueOperationPending) async throws -> ModVenueOperationReceipt {
        try pending.validate(); guard pending.receipt == nil else { throw ModInstallationIssue.pendingConflict }
        let result: ModVenueOperationReceipt = try await send("requests/" + key(pending.installation.requestId) + "/venue/commands", method: "POST", body: JSONEncoder().encode(pending.command))
        try result.validate(pending); return result
    }
    public func venueReceipt(_ pending: ModVenueOperationPending) async throws -> ModVenueOperationReceipt {
        try pending.validate()
        let result: ModVenueOperationReceipt = try await send("requests/" + key(pending.installation.requestId) + "/venue/receipts/" + key(pending.command.requestId))
        try result.validate(pending); return result
    }
    public func venueCode(_ installation: ModInstallationReceipt, node: Int64) async throws -> ModVenueIssuedCode {
        try installation.validate(identity: installation.identity); guard node > 0 else { throw ModInstallationIssue.invalidSelection }
        let result: ModVenueIssuedCode = try await send("requests/" + key(installation.requestId) + "/venue/nodes/" + String(node) + "/code", method: "POST")
        try result.validate(node: node); return result
    }
    public func templateEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationTemplateEditorState {
        try installation.validate(identity: installation.identity); guard installation.memberTemplateID != nil else { throw ModInstallationIssue.pendingConflict }
        let result: ModInstallationTemplateEditorState = try await send("requests/" + key(installation.requestId) + "/template-editor")
        try result.validate(installation); return result
    }
    public func saveTemplateEdit(_ pending: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt {
        try pending.validate(); guard pending.receipt == nil, pending.command.action != "REVIEW" || canReviewInstalledTemplate else { throw ModInstallationIssue.disabled }
        let result: ModInstallationTemplateEditReceipt = try await send("requests/" + key(pending.installation.requestId) + "/template-editor", method: "POST", body: JSONEncoder().encode(pending.command))
        try result.validate(pending); return result
    }
    public func templateEditReceipt(_ pending: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt {
        try pending.validate()
        let result: ModInstallationTemplateEditReceipt = try await send("requests/" + key(pending.installation.requestId) + "/template-editor/" + key(pending.command.editRequestId))
        try result.validate(pending); return result
    }
    public func qaEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationQaEditorState {
        try installation.validate(identity: installation.identity); guard installation.topicID != nil else { throw ModInstallationIssue.pendingConflict }
        let result: ModInstallationQaEditorState = try await send("requests/" + key(installation.requestId) + "/qa-editor")
        try result.validate(installation); return result
    }
    public func saveQaEdit(_ pending: ModInstallationQaEditPending) async throws -> ModInstallationQaEditReceipt {
        try pending.validate(); guard pending.receipt == nil else { throw ModInstallationIssue.pendingConflict }
        let result: ModInstallationQaEditReceipt = try await send("requests/" + key(pending.installation.requestId) + "/qa-editor", method: "POST", body: JSONEncoder().encode(pending.command))
        try result.validate(pending); return result
    }
    public func qaEditReceipt(_ pending: ModInstallationQaEditPending) async throws -> ModInstallationQaEditReceipt {
        try pending.validate()
        let result: ModInstallationQaEditReceipt = try await send("requests/" + key(pending.installation.requestId) + "/qa-editor/" + key(pending.command.editRequestId))
        try result.validate(pending); return result
    }
    public func history(identity: ModInstallationIdentity) async throws -> [ModInstallationReceipt] {
        try identity.validate()
        var result: [ModInstallationReceipt] = [], seen = Set<String>(), seenCursors = Set<String>()
        var cursor: String?
        var count = 0, bytes = 0
        repeat {
            try check()
            let query = cursor.map { [URLQueryItem(name: "beforeRequestId", value: $0)] } ?? []
            let page: ModInstallationHistoryPage = try await send("licenses/" + key(identity.licenseId) + "/history-page", query: query)
            try page.validate(identity: identity, beforeRequestId: cursor)
            for receipt in page.items {
                guard seen.insert(receipt.requestId).inserted else { throw ModInstallationIssue.malformed }
            }
            if let next = page.nextBeforeRequestId {
                guard seenCursors.insert(next).inserted else { throw ModInstallationIssue.malformed }
            }
            try ModInstallationReadBudget.include(page.items, count: &count, bytes: &bytes)
            result.append(contentsOf: page.items); cursor = page.nextBeforeRequestId
        } while cursor != nil
        try check(); return result // Only the proven tail permits absence-of-PREPARED decisions.

    }
    private struct Envelope<T: Decodable>: Decodable { let code: Int; let data: T? }
    private struct Code: Decodable { let code: Int }
    private func send<T: Decodable>(_ route: String, method: String = "GET", body: Data? = nil,
                                    query: [URLQueryItem] = [], acceptsResult: @escaping @MainActor () -> Bool = { true }) async throws -> T {
        try check(mutating: method == "POST"); guard acceptsResult() else { throw ModInstallationIssue.disabled }
        guard var components = URLComponents(url: lease.context.baseURL.appendingPathComponent("api/mod-installation/" + route), resolvingAgainstBaseURL: false) else { throw ModInstallationIssue.disabled }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url, components.scheme == "https", components.user == nil,
              components.password == nil, components.fragment == nil else { throw ModInstallationIssue.disabled }
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body
        request.setValue(lease.context.session.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control"); request.cachePolicy = .reloadIgnoringLocalCacheData
        try check(mutating: method == "POST"); guard acceptsResult() else { throw ModInstallationIssue.disabled }
        try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request)
        let (data, response) = try await session.data(for: request)
        try check(mutating: method == "POST"); guard acceptsResult() else { throw ModInstallationIssue.disabled }
        guard let http = response as? HTTPURLResponse, data.count <= 2_097_152,
              let text = String(data: data, encoding: .utf8), (try? ContentDraftJSON.parse(text)) != nil else { throw ModInstallationIssue.malformed }
        let code = try? JSONDecoder().decode(Code.self, from: data).code
        if http.statusCode == 401 || code == 401 {
            try check(mutating: method == "POST"); guard acceptsResult() else { throw ModInstallationIssue.disabled }; onUnauthorized(lease.context); invalidate(); throw ModInstallationIssue.unauthorized
        }
        if http.statusCode == 413 || code == 413 { throw ModInstallationIssue.readCapacityExceeded }
        if http.statusCode == 404 || code == 404 { throw ModInstallationIssue.requestNotFound }
        if (route == "requests" || route.hasSuffix("/qa-editor") || route.hasSuffix("/template-editor")), method == "POST", code == 422 { throw ModInstallationIssue.prepareRejected }
        guard (200..<300).contains(http.statusCode), code == 200 else { throw ModInstallationIssue.unavailable }
        try ModInstallationWire.validate(data, route: route)
        guard let result = try JSONDecoder().decode(Envelope<T>.self, from: data).data else { throw ModInstallationIssue.malformed }
        try check(mutating: method == "POST"); guard acceptsResult() else { throw ModInstallationIssue.disabled }; return result
    }
}
