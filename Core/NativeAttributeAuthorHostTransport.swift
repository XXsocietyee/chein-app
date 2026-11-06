import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Exact existing routes, not a capability issuer. Read, validate and each mutation remain
/// independently approved by the original composition. No endpoint is enabled by default.
public enum NativeAttributeAuthorHostEndpoint: Hashable {
    case definitions, inspectCurrent, references, validate, save, delete, requestReceipt
    case legacyList, legacyRegister, legacyDelete, publishCheck, modulePreflight

    public init(request: NativeAttributeAuthorRequest) throws {
        try request.validateShape()
        switch (request.method, request.path) {
        case (.get, "api/topic/attribute-author"):
            self = request.isCurrentInspection ? .inspectCurrent : .definitions
        case (.get, "api/topic/attribute-author/references"): self = .references
        case (.get, "api/topic/attribute-author/request"): self = .requestReceipt
        case (.post, "api/topic/attribute-author/validate"): self = .validate
        case (.post, "api/topic/attribute-author"): self = .save
        case (.delete, "api/topic/attribute-author"): self = .delete
        case (.get, "api/topic/state-keys"): self = .legacyList
        case (.post, "api/topic/state-keys"): self = .legacyRegister
        case (.delete, "api/topic/state-keys"): self = .legacyDelete
        case (.get, "api/topic/publish-check"): self = .publishCheck
        case (.get, "api/topic/module-preflight"): self = .modulePreflight
        default: throw NativeAttributeAuthorError.contractMissing("unreviewed author method/path")
        }
    }
}

public struct NativeAttributeAuthorHostCredentials: Equatable {
    public let binding: NativeAttributeAuthorBinding
    fileprivate let token: String
    public init(binding: NativeAttributeAuthorBinding, token: String) throws {
        guard !binding.isLocked, AuthRequestBuilder.isValidToken(token) else {
            throw NativeAttributeAuthorError.staleSource
        }
        self.binding = binding; self.token = token
    }
    public static func == (a: Self, b: Self) -> Bool {
        a.binding == b.binding && a.token.utf8.elementsEqual(b.token.utf8)
    }
}

/// Uses the original final-forward boundary. It creates no URLSession, token, grant or
/// retry queue. The dispatch closure MUST execute its supplied check at the actual wire
/// boundary after any suspension; the separate Composition method supplies that boundary.
@MainActor public final class NativeAttributeAuthorHostTransport: NativeAttributeAuthorTransport {
    public typealias Dispatch = @MainActor (URLRequest, @escaping @MainActor () throws -> Void) async throws -> (Data, Int)
    private let configuration: APIConfiguration
    private let approval: OperationEndpointApproval?
    private let currentApproval: () -> OperationEndpointApproval?
    private let currentCapability: (NativeAttributeAuthorHostEndpoint) -> Bool
    private let credentials: () -> NativeAttributeAuthorHostCredentials?
    private let dispatch: Dispatch
    public init(configuration: APIConfiguration, approval: OperationEndpointApproval? = nil,
                currentApproval: @escaping () -> OperationEndpointApproval? = { nil },
                currentCapability: @escaping (NativeAttributeAuthorHostEndpoint) -> Bool = { _ in false },
                credentials: @escaping () -> NativeAttributeAuthorHostCredentials?,
                dispatch: @escaping Dispatch) {
        self.configuration = configuration; self.approval = approval
        self.currentApproval = currentApproval; self.currentCapability = currentCapability
        self.credentials = credentials; self.dispatch = dispatch
    }
    private func sameIdentity(_ a: NativeAttributeAuthorBinding, _ b: NativeAttributeAuthorBinding) -> Bool {
        a.accountID == b.accountID && a.epoch == b.epoch && a.topicID == b.topicID && !a.isLocked && !b.isLocked &&
        zip([a.server,a.namespace,a.authorizationRevision,a.requestScope],
            [b.server,b.namespace,b.authorizationRevision,b.requestScope]).allSatisfy { $0.0.utf8.elementsEqual($0.1.utf8) }
    }
    private func requireApproval(_ request: NativeAttributeAuthorRequest, endpoint: NativeAttributeAuthorHostEndpoint) throws {
        guard let approval, let liveApproval = currentApproval(), liveApproval == approval,
              liveApproval.namespace.utf8.elementsEqual(approval.namespace.utf8),
              liveApproval.baseURL.absoluteString.utf8.elementsEqual(approval.baseURL.absoluteString.utf8),
              currentCapability(endpoint),
              let account = Int(exactly: request.binding.accountID),
              approval.namespace.utf8.elementsEqual(request.binding.namespace.utf8),
              approval.allows(configuration: configuration, namespace: request.binding.namespace,
                              accountID: account, path: request.path) else {
            throw NativeAttributeAuthorError.unavailable("original exact author method/path approval")
        }
    }
    public func send(_ request: NativeAttributeAuthorRequest,
                     finalCheck: @escaping @MainActor () throws -> Void) async throws -> (Data, Int) {
        let endpoint = try NativeAttributeAuthorHostEndpoint(request: request)
        guard let before = credentials(), sameIdentity(before.binding, request.binding),
              request.isCurrentInspection || request.isOriginalReceiptRead || before.binding == request.binding else { throw NativeAttributeAuthorError.staleSource }
        try requireApproval(request, endpoint: endpoint)
        let wire = try request.urlRequest(configuration: configuration, token: before.token)
        let check: @MainActor () throws -> Void = { [weak self] in
            guard let self else { throw NativeAttributeAuthorError.staleSource }
            try Task.checkCancellation()
            guard self.credentials() == before else { throw NativeAttributeAuthorError.staleSource }
            try self.requireApproval(request, endpoint: endpoint)
            try finalCheck()
        }
        try check()
        let result = try await dispatch(wire, check)
        try Task.checkCancellation()
        guard let after = credentials(), sameIdentity(before.binding, after.binding),
              before.token.utf8.elementsEqual(after.token.utf8) else { throw NativeAttributeAuthorError.staleSource }
        // A successful write may legitimately have advanced S. Do not discard its ACK solely
        // for that advance; the existing receipt consumer verifies exact S+1 and target bytes.
        try requireApproval(request, endpoint: endpoint)
        return result
    }
}
