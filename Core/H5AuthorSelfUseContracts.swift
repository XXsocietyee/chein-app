import Foundation
import CryptoKit

public enum H5AuthorSelfUseIssue: String, Error, Equatable {
    case disabled, stale, malformed, storage, unknown, unauthorized, forbidden, conflict, notFound, capacity
}
public enum H5AuthorSelfUseTargetKind: String, Codable, CaseIterable, Hashable, Sendable {
    case merchantTopic = "MERCHANT_TOPIC", clubTopic = "CLUB_TOPIC"
}
public enum H5AuthorSelfUseWire {
    public static func uuid(_ value: String) -> Bool { UUID(uuidString: value)?.uuidString.lowercased() == value }
    public static func hash(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    static func key(_ value: String) -> Bool { ModReleaseApplicationWire.key(value) }
    static func text(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf16.count <= 1024 }
    static func actor(_ value: String) -> Int64? {
        guard let id = Int64(value), id > 0, String(id) == value else { return nil }; return id
    }
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    static func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
    /// Heterogeneous ordered arrays retain Int64 values; Foundation NSNumber/Double is never used.
    static func authorizationHash(_ binding: H5AuthorSelfUseBinding) throws -> String {
        try digest(encode([
            CanonicalScalar.string("AUTHOR_SELF_USE"), .string(binding.selfUseRequestId), .integer(binding.authorId),
            .string(binding.releaseApplicationRequestId), .string(binding.moduleId), .string(binding.releaseId), .string(binding.contentHash),
            .integer(binding.sourceTemplateId), .string(binding.targetKind.rawValue), .integer(binding.organizationId), .integer(binding.topicId)
        ]))
    }
    private enum CanonicalScalar: Encodable {
        case string(String), integer(Int64)
        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self { case .string(let value): try c.encode(value); case .integer(let value): try c.encode(value) }
        }
    }
    static func exactKeys(_ decoder: Decoder, _ keys: Set<String>) throws {
        struct Key: CodingKey {
            let stringValue: String
            var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { return nil }
        }
        guard Set(try decoder.container(keyedBy: Key.self).allKeys.map(\.stringValue)) == keys else { throw H5AuthorSelfUseIssue.malformed }
    }
}

public struct H5AuthorSelfUseOrganization: Codable, Equatable, Identifiable, Sendable {
    public let organizationId: Int64
    public let name: String
    public var id: Int64 { organizationId }
    var valid: Bool { organizationId > 0 && H5AuthorSelfUseWire.text(name) }
}
public struct H5AuthorSelfUseTarget: Codable, Equatable, Identifiable, Sendable {
    public let topicId: Int64, organizationId: Int64, expectedTopicConfigVersion: Int64
    public let name: String
    public let targetKind: H5AuthorSelfUseTargetKind
    public var id: Int64 { topicId }
    public var valid: Bool { topicId > 0 && organizationId > 0 && expectedTopicConfigVersion >= 0 && H5AuthorSelfUseWire.text(name) }
}
public struct H5AuthorSelfUseOrganizationPage: Decodable, Sendable {
    public let source: String, targetKind: H5AuthorSelfUseTargetKind, organizationId: Int64?
    public let items: [H5AuthorSelfUseOrganization], nextAfterId: Int64?
    public let grantsPlayerAccess: Bool
    func validate(kind: H5AuthorSelfUseTargetKind, after: Int64?) throws {
        guard source == "h5-author-self-use-organizations-v1", targetKind == kind, organizationId == nil, !grantsPlayerAccess,
              items.count <= 25, items.allSatisfy(\.valid), Self.ascending(items.map(\.id), after: after),
              nextAfterId == nil || nextAfterId == items.last?.id else { throw H5AuthorSelfUseIssue.malformed }
    }
    static func ascending(_ ids: [Int64], after: Int64?) -> Bool {
        var previous = after ?? 0
        for id in ids { guard id > previous else { return false }; previous = id }; return true
    }
}
public struct H5AuthorSelfUseTargetPage: Decodable, Sendable {
    public let source: String, targetKind: H5AuthorSelfUseTargetKind, organizationId: Int64
    public let items: [H5AuthorSelfUseTarget], nextAfterId: Int64?
    public let grantsPlayerAccess: Bool
    func validate(kind: H5AuthorSelfUseTargetKind, organization: Int64, after: Int64?) throws {
        guard source == "h5-author-self-use-targets-v1", targetKind == kind, organizationId == organization, !grantsPlayerAccess,
              items.count <= 25, items.allSatisfy({ $0.valid && $0.targetKind == kind && $0.organizationId == organization }),
              H5AuthorSelfUseOrganizationPage.ascending(items.map(\.id), after: after),
              nextAfterId == nil || nextAfterId == items.last?.id else { throw H5AuthorSelfUseIssue.malformed }
    }
}

public struct H5AuthorSelfUseBindCommand: Codable, Equatable, Sendable {
    public let requestId, releaseApplicationRequestId, releaseId, contentHash: String
    public let targetKind: H5AuthorSelfUseTargetKind
    public let organizationId, topicId, expectedTopicConfigVersion: Int64
    public let previousRequestId: String?
    public init(application: ModReleaseApplicationView, target: H5AuthorSelfUseTarget, previousRequestId: String? = nil,
                requestId: String = UUID().uuidString.lowercased()) throws {
        guard application.state == .approved,
              let owner = Int(exactly: application.owner), application.valid(owner: owner), target.valid,
              let release = application.releaseId, let hash = application.contentHash else { throw H5AuthorSelfUseIssue.malformed }
        self.requestId = requestId; releaseApplicationRequestId = application.requestId; releaseId = release; contentHash = hash
        targetKind = target.targetKind; organizationId = target.organizationId; topicId = target.topicId
        expectedTopicConfigVersion = target.expectedTopicConfigVersion; self.previousRequestId = previousRequestId
        guard valid else { throw H5AuthorSelfUseIssue.malformed }
    }
    public var valid: Bool {
        H5AuthorSelfUseWire.uuid(requestId) && H5AuthorSelfUseWire.uuid(releaseApplicationRequestId) && H5AuthorSelfUseWire.key(releaseId) &&
            H5AuthorSelfUseWire.hash(contentHash) && organizationId > 0 && topicId > 0 && expectedTopicConfigVersion >= 0 &&
            (previousRequestId.map { H5AuthorSelfUseWire.uuid($0) && $0 != requestId } ?? true)
    }
    private enum CodingKeys: String, CodingKey, CaseIterable { case requestId, releaseApplicationRequestId, releaseId, contentHash, targetKind, organizationId, topicId, expectedTopicConfigVersion, previousRequestId }
    public init(from decoder: Decoder) throws {
        try H5AuthorSelfUseWire.exactKeys(decoder, Set(CodingKeys.allCases.map(\.rawValue)))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try c.decode(String.self, forKey: .requestId); releaseApplicationRequestId = try c.decode(String.self, forKey: .releaseApplicationRequestId)
        releaseId = try c.decode(String.self, forKey: .releaseId); contentHash = try c.decode(String.self, forKey: .contentHash)
        targetKind = try c.decode(H5AuthorSelfUseTargetKind.self, forKey: .targetKind)
        organizationId = try c.decode(Int64.self, forKey: .organizationId); topicId = try c.decode(Int64.self, forKey: .topicId)
        expectedTopicConfigVersion = try c.decode(Int64.self, forKey: .expectedTopicConfigVersion); previousRequestId = try c.decodeIfPresent(String.self, forKey: .previousRequestId)
        guard valid else { throw H5AuthorSelfUseIssue.malformed }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(requestId, forKey: .requestId); try c.encode(releaseApplicationRequestId, forKey: .releaseApplicationRequestId)
        try c.encode(releaseId, forKey: .releaseId); try c.encode(contentHash, forKey: .contentHash); try c.encode(targetKind, forKey: .targetKind)
        try c.encode(organizationId, forKey: .organizationId); try c.encode(topicId, forKey: .topicId); try c.encode(expectedTopicConfigVersion, forKey: .expectedTopicConfigVersion)
        if let previousRequestId { try c.encode(previousRequestId, forKey: .previousRequestId) } else { try c.encodeNil(forKey: .previousRequestId) }
    }
}

/// v1.3 exact original release projection. IDs remain Int64 JSON integers.
public struct H5AuthorSelfUseRelease: Decodable, Equatable, Sendable {
    public let source, releaseApplicationRequestId, moduleId, releaseId, contentHash, authorizationSource: String
    public let authorId, sourceTemplateId: Int64
    public let grantsPlayerAccess: Bool
    public var valid: Bool {
        source == "h5-author-self-use-release-v1" && authorizationSource == "AUTHOR_SELF_USE" && !grantsPlayerAccess &&
        authorId > 0 && sourceTemplateId > 0 && H5AuthorSelfUseWire.uuid(releaseApplicationRequestId) &&
        [moduleId, releaseId].allSatisfy(H5AuthorSelfUseWire.key) && H5AuthorSelfUseWire.hash(contentHash)
    }
    public func matches(_ binding: H5AuthorSelfUseBinding) -> Bool {
        valid && binding.valid && authorId == binding.authorId && releaseApplicationRequestId == binding.releaseApplicationRequestId &&
        moduleId == binding.moduleId && releaseId == binding.releaseId && contentHash == binding.contentHash && sourceTemplateId == binding.sourceTemplateId
    }
    public func matches(_ application: ModReleaseApplicationView, actor: Int) -> Bool {
        valid && application.valid(owner: actor) && application.state == .approved && authorId == Int64(actor) &&
        releaseApplicationRequestId == application.requestId && moduleId == application.moduleId && releaseId == application.releaseId && contentHash == application.contentHash
    }
}

/// Current authority is a separate wrapper; immutable BOUND evidence does not contain this permission.
public struct H5AuthorSelfUseCurrentBinding: Decodable {
    public let binding: H5AuthorSelfUseBinding
    public let grantsPlayerAccess: Bool
    public let runtimeAuthorization: String
    public let currentAvailable: Bool
    public let reasonCode: String?
    public func projection(matching original: H5AuthorSelfUseBinding) throws -> H5AuthorSelfUseBinding {
        guard binding.sameAuthority(original), !grantsPlayerAccess,
              runtimeAuthorization == "REQUIRES_ORIGINAL_PUBLISHED_NODE_AND_PLAYER_RUN",
              original.state != .revoked || binding.state == .revoked,
              reasonCode.map({ !$0.isEmpty && $0.utf8.count <= 192 }) ?? true else { throw H5AuthorSelfUseIssue.malformed }
        var value = binding; value.currentAvailable = currentAvailable; value.runtimeAuthorization = runtimeAuthorization; value.reasonCode = reasonCode
        return value
    }
}

public struct H5AuthorSelfUseRevokeCommand: Codable, Equatable, Sendable {
    public let requestId, expectedAuthorizationHash: String
    public init(binding: H5AuthorSelfUseBinding, requestId: String = UUID().uuidString.lowercased()) throws {
        self.requestId = requestId; expectedAuthorizationHash = binding.authorizationHash
        guard binding.valid, binding.state == .active, valid else { throw H5AuthorSelfUseIssue.malformed }
    }
    var valid: Bool { H5AuthorSelfUseWire.uuid(requestId) && H5AuthorSelfUseWire.hash(expectedAuthorizationHash) }
    private enum CodingKeys: String, CodingKey { case requestId, expectedAuthorizationHash }
    public init(from decoder: Decoder) throws {
        try H5AuthorSelfUseWire.exactKeys(decoder, ["requestId", "expectedAuthorizationHash"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try c.decode(String.self, forKey: .requestId); expectedAuthorizationHash = try c.decode(String.self, forKey: .expectedAuthorizationHash)
        guard valid else { throw H5AuthorSelfUseIssue.malformed }
    }
}
public enum H5AuthorSelfUseCommand: Codable, Equatable, Sendable {
    public enum Operation: String, Codable, Sendable { case bind = "BIND", revoke = "REVOKE" }
    case bind(H5AuthorSelfUseBindCommand)
    case revoke(bindingRequestId: String, command: H5AuthorSelfUseRevokeCommand)
    public var operation: Operation { switch self { case .bind: return .bind; case .revoke: return .revoke } }
    public var requestId: String { switch self { case .bind(let c): return c.requestId; case .revoke(_, let c): return c.requestId } }
    public var valid: Bool { switch self { case .bind(let c): return c.valid; case .revoke(let id, let c): return H5AuthorSelfUseWire.uuid(id) && c.valid && id != c.requestId } }
    /// The array has one ASCII operation string followed by the exact normalized command.
    /// Command strings are canonical UUIDs/keys/hashes/enums, with Int64 JSON integers and explicit nulls.
    public var inputHash: String { get throws {
        guard valid else { throw H5AuthorSelfUseIssue.malformed }
        var bytes = Data(("[\"" + operation.rawValue + "\",").utf8)
        bytes.append(try H5AuthorSelfUseWire.encode(self)); bytes.append(contentsOf: "]".utf8)
        return H5AuthorSelfUseWire.digest(bytes)
    } }
    public var body: Data { get throws {
        switch self { case .bind(let c): return try H5AuthorSelfUseWire.encode(c); case .revoke(_, let c): return try H5AuthorSelfUseWire.encode(c) }
    } }
    private enum CodingKeys: String, CodingKey { case bindingRequestId, command }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.bindingRequestId) {
            try H5AuthorSelfUseWire.exactKeys(decoder, ["bindingRequestId", "command"])
            self = .revoke(bindingRequestId: try c.decode(String.self, forKey: .bindingRequestId), command: try c.decode(H5AuthorSelfUseRevokeCommand.self, forKey: .command))
        } else { self = .bind(try H5AuthorSelfUseBindCommand(from: decoder)) }
        guard valid else { throw H5AuthorSelfUseIssue.malformed }
    }
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .bind(let c): try c.encode(to: encoder)
        case .revoke(let id, let command):
            var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(id, forKey: .bindingRequestId); try c.encode(command, forKey: .command)
        }
    }
}

public struct H5AuthorSelfUseBinding: Codable, Equatable, Sendable, Identifiable {
    public enum State: String, Codable, Sendable { case active = "ACTIVE", revoked = "REVOKED" }
    public let authorizationSource, selfUseRequestId, releaseApplicationRequestId, moduleId, releaseId, contentHash, authorizationHash: String
    public let authorId, sourceTemplateId, organizationId, topicId: Int64
    public let targetKind: H5AuthorSelfUseTargetKind
    public let state: State
    public var currentAvailable: Bool? = nil
    public var reasonCode: String? = nil
    public var runtimeAuthorization: String? = nil
    public var id: String { selfUseRequestId }
    public var valid: Bool {
        authorizationSource == "AUTHOR_SELF_USE" && [selfUseRequestId,releaseApplicationRequestId].allSatisfy(H5AuthorSelfUseWire.uuid) &&
            [moduleId,releaseId].allSatisfy(H5AuthorSelfUseWire.key) && [contentHash,authorizationHash].allSatisfy(H5AuthorSelfUseWire.hash) &&
            authorId > 0 && sourceTemplateId > 0 && organizationId > 0 && topicId > 0 &&
            (reasonCode.map { !$0.isEmpty && $0.utf8.count <= 192 } ?? true) &&
            (runtimeAuthorization == nil || runtimeAuthorization == "REQUIRES_ORIGINAL_PUBLISHED_NODE_AND_PLAYER_RUN") &&
            (try? H5AuthorSelfUseWire.authorizationHash(self)) == authorizationHash
    }
    public func matches(_ command: H5AuthorSelfUseBindCommand) -> Bool {
        valid && selfUseRequestId == command.requestId && releaseApplicationRequestId == command.releaseApplicationRequestId &&
            releaseId == command.releaseId && contentHash == command.contentHash && targetKind == command.targetKind && organizationId == command.organizationId && topicId == command.topicId
    }
    public func sameAuthority(_ other: Self) -> Bool {
        valid && other.valid && selfUseRequestId == other.selfUseRequestId && authorId == other.authorId &&
            releaseApplicationRequestId == other.releaseApplicationRequestId && moduleId == other.moduleId && releaseId == other.releaseId &&
            contentHash == other.contentHash && sourceTemplateId == other.sourceTemplateId && targetKind == other.targetKind &&
            organizationId == other.organizationId && topicId == other.topicId && authorizationHash == other.authorizationHash
    }
}
public struct H5AuthorSelfUseReceipt: Codable, Equatable, Sendable, Identifiable {
    public enum Status: String, Codable, Sendable { case bound = "BOUND", revoked = "REVOKED", rejected = "PREFLIGHT_REJECTED", pending = "PENDING", notFound = "NOT_FOUND" }
    public let source, actorId, requestId: String
    public let inputHash: String?
    public let receiptStatus: Status
    public let operation: H5AuthorSelfUseCommand.Operation?
    public let command: H5AuthorSelfUseCommand?
    public let binding: H5AuthorSelfUseBinding?
    public let reasonCode: String?
    public var grantsPlayerAccess: Bool? = nil
    public var publishesTopic: Bool? = nil
    public var materializesTemplate: Bool? = nil
    public var id: String { requestId }
    public var finished: Bool { receiptStatus == .bound || receiptStatus == .revoked || receiptStatus == .rejected }
    public func validate(actor: Int, expected: H5AuthorSelfUseCommand) throws {
        let expectedHash = try expected.inputHash
        guard source == "h5-author-self-use-request-v1", actorId == String(actor), actor > 0, requestId == expected.requestId, expected.valid,
              inputHash == nil || inputHash == expectedHash, operation == nil || operation == expected.operation,
              command == nil || command == expected, reasonCode.map({ !$0.isEmpty && $0.utf8.count <= 192 }) ?? true else { throw H5AuthorSelfUseIssue.malformed }
        if finished {
            guard operation == expected.operation, command == expected, inputHash == expectedHash else { throw H5AuthorSelfUseIssue.malformed }
        }
        switch receiptStatus {
        case .bound:
            guard case .bind(let c) = expected, let binding, binding.matches(c), binding.authorId == Int64(actor), binding.state == .active, reasonCode == nil else { throw H5AuthorSelfUseIssue.malformed }
        case .revoked:
            guard case .revoke(let original, let c) = expected, let binding, binding.valid, binding.authorId == Int64(actor),
                  binding.selfUseRequestId == original, binding.authorizationHash == c.expectedAuthorizationHash, binding.state == .revoked, reasonCode == nil else { throw H5AuthorSelfUseIssue.malformed }
        case .rejected: guard binding == nil, reasonCode != nil else { throw H5AuthorSelfUseIssue.malformed }
        case .pending, .notFound: guard binding == nil else { throw H5AuthorSelfUseIssue.malformed }
        }
        if receiptStatus == .bound || receiptStatus == .revoked {
            guard grantsPlayerAccess == false, publishesTopic == false, materializesTemplate == false else { throw H5AuthorSelfUseIssue.malformed }
        }
    }
}

/// Projection of the existing authenticated original-topic runtime resolver, never an author license.
public struct H5AuthorSelfUseRuntimeAuthority: Equatable, Sendable {
    public let selfUseRequestId, authorizationHash, moduleId, releaseId, contentHash, run, objective, version: String
    public let sourceTemplateId, organizationId: Int64
    public let topicId, nodeId, activityId: Int
    public let targetKind: H5AuthorSelfUseTargetKind
    public let sourceRunScope, verifierVersion, classification: String
    public var valid: Bool {
        H5AuthorSelfUseWire.uuid(selfUseRequestId) && version == contentHash && [authorizationHash,contentHash,version].allSatisfy(H5AuthorSelfUseWire.hash) &&
            [moduleId,releaseId].allSatisfy(H5AuthorSelfUseWire.key) && [run,objective,sourceRunScope,verifierVersion,classification].allSatisfy(H5AuthorSelfUseWire.text) &&
            sourceTemplateId > 0 && organizationId > 0 && topicId > 0 && nodeId > 0 && activityId >= 0
    }
}
