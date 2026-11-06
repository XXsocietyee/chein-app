import Foundation

public enum ModInstallationIssue: Error, Equatable {
    case disabled, staleSession, invalidSelection, malformed, unauthorized, unavailable
    case requestNotFound, prepareRejected, pendingConflict, storageUnavailable, unknownOutcome, readCapacityExceeded
}

public enum ModInstallationKind: String, Codable, CaseIterable {
    case site = "SITE", poi = "POI", sku = "SKU", npc = "NPC", routeEntry = "ROUTE_ENTRY"
}

public struct ModInstallationRequirement: Codable, Equatable, Identifiable {
    public let key: String
    public let kind: ModInstallationKind
    public var id: String { kind.rawValue + ":" + key }
}

public struct ModInstallationResource: Codable, Equatable, Identifiable {
    public let kind: ModInstallationKind
    public let id, merchantId: Int64
    public let label: String
    public let region: String?
    public let fingerprint: String
    public var selectionID: String { kind.rawValue + ":" + String(id) }
}

/// A frozen installation reference, not a second purchase or entitlement source.
/// The server independently resolves the authenticated owner's original commerce license.
public struct ModInstallationIdentity: Codable, Equatable {
    public let licenseId, moduleId, releaseId, contentHash, termsHash: String
    public init(licenseId: String, moduleId: String, releaseId: String, contentHash: String, termsHash: String) {
        self.licenseId = licenseId; self.moduleId = moduleId; self.releaseId = releaseId
        self.contentHash = contentHash; self.termsHash = termsHash
    }
    func validate() throws {
        try ModInstallationValidation.key(licenseId); try ModInstallationValidation.key(moduleId)
        try ModInstallationValidation.key(releaseId); try ModInstallationValidation.hash(contentHash)
        try ModInstallationValidation.hash(termsHash)
    }
}

public struct ModInstallationOptions: Codable, Equatable {
    public let schema, licenseId, moduleId, releaseId, contentHash, termsHash, title: String
    public let requiredBindings: [ModInstallationRequirement]
    public let merchants, resources: [ModInstallationResource]
    public var identity: ModInstallationIdentity {
        .init(licenseId: licenseId, moduleId: moduleId, releaseId: releaseId, contentHash: contentHash, termsHash: termsHash)
    }
    public func validate(licenseId: String, merchantId: Int64? = nil) throws {
        guard schema == "mod-installation-options-v1", self.licenseId == licenseId,
              requiredBindings.count <= 32, merchants.count <= ModInstallationReadBudget.maximumRows, resources.count <= ModInstallationReadBudget.maximumRows else { throw ModInstallationIssue.malformed }
        try identity.validate(); try ModInstallationValidation.text(title, maximum: 2048)
        var requirements = Set<String>()
        for item in requiredBindings {
            try ModInstallationValidation.placeholder(item.key)
            guard requirements.insert(item.id).inserted else { throw ModInstallationIssue.malformed }
        }
        var owners = Set<Int64>()
        for item in merchants {
            try ModInstallationValidation.resource(item)
            guard item.kind == .site, item.merchantId == item.id, owners.insert(item.id).inserted else { throw ModInstallationIssue.malformed }
        }
        var keys = Set<String>()
        for item in resources {
            try ModInstallationValidation.resource(item)
            guard let merchantId, item.merchantId == merchantId,
                  keys.insert(item.selectionID).inserted else { throw ModInstallationIssue.malformed }
        }
        if let merchantId { guard owners.contains(merchantId) else { throw ModInstallationIssue.malformed } }
    }
}

public struct ModInstallationBinding: Codable, Equatable, Identifiable {
    public let key: String
    public let kind: ModInstallationKind
    public let resourceId: Int64
    public let fingerprint: String
    public var id: String { kind.rawValue + ":" + key }
}

public struct ModInstallationBoundResource: Codable, Equatable, Identifiable {
    public let key: String
    public let kind: ModInstallationKind
    public let resourceId: Int64
    public let label, fingerprint: String
    public var id: String { kind.rawValue + ":" + key }
    public var binding: ModInstallationBinding { .init(key: key, kind: kind, resourceId: resourceId, fingerprint: fingerprint) }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key && lhs.kind == rhs.kind && lhs.resourceId == rhs.resourceId &&
        lhs.label.utf8.elementsEqual(rhs.label.utf8) && lhs.fingerprint == rhs.fingerprint
    }
}

public struct ModInstallationRequest: Codable, Equatable {
    public let requestId, licenseId: String
    public let merchantId, anchorPoiId: Int64
    public let bindings: [ModInstallationBinding]
    public let clientVersion, runtimeVersion: Int
    func validate() throws {
        guard UUID(uuidString: requestId)?.uuidString.lowercased() == requestId,
              merchantId > 0, anchorPoiId > 0, (1...7).contains(clientVersion), runtimeVersion == 1,
              bindings.count <= 32 else { throw ModInstallationIssue.malformed }
        try ModInstallationValidation.key(licenseId)
        var keys = Set<String>()
        for binding in bindings {
            try ModInstallationValidation.placeholder(binding.key); try ModInstallationValidation.hash(binding.fingerprint)
            guard binding.resourceId > 0, keys.insert(binding.id).inserted else { throw ModInstallationIssue.malformed }
        }
    }
}

public struct ModInstallationReceipt: Codable, Equatable, Identifiable {
    public enum State: String, Codable {
        case prepared = "PREPARED", installed = "INSTALLED_PRIVATE_DRAFT", failed = "FAILED", cancelled = "CANCELLED"
    }
    public let schema, requestId, licenseId, moduleId, releaseId, contentHash, termsHash: String
    public let state: State
    public let merchantId, anchorPoiId: Int64
    public let region, bindingHash: String
    public let draftId: Int64?
    public let editKind, createdAt: String
    public let errorCode: String?
    public let published, executable: Bool
    public let requiredGates: [String]
    public let bindings: [ModInstallationBoundResource]
    public var composition: ModCompositionInstallationReceipt? = nil
    public var id: String { requestId }
    public var terminal: Bool { state != .prepared }
    public var identity: ModInstallationIdentity {
        .init(licenseId: licenseId, moduleId: moduleId, releaseId: releaseId, contentHash: contentHash, termsHash: termsHash)
    }
    /// Only an exact server receipt for an installed member-template draft can enable the editor.
    public var memberTemplateID: MemberPlayTemplateID? {
        guard state == .installed, editKind == "MEMBER_TEMPLATE", !published, !executable,
              let draftId, let value = Int(exactly: draftId) else { return nil }
        return MemberPlayTemplateID(rawValue: value)
    }
    public var topicID: Int? {
        guard state == .installed, editKind == "TOPIC", !published, !executable,
              let draftId, draftId > 0 else { return nil }
        return Int(exactly: draftId)
    }
    public func validate(identity: ModInstallationIdentity) throws {
        guard schema == "mod-installation-receipt-v1", self.identity == identity,
              UUID(uuidString: requestId)?.uuidString.lowercased() == requestId,
              merchantId > 0, anchorPoiId > 0, ["MEMBER_TEMPLATE", "TOPIC"].contains(editKind), !published, !executable,
              Set(requiredGates) == Set(["MERCHANT_FACT_CONFIRMATION", "THEME_CONTENT_REVIEW", "W02_PUBLISH"]),
              requiredGates.count == 3, bindings.count <= 32 else { throw ModInstallationIssue.malformed }
        try identity.validate(); try ModInstallationValidation.text(region, maximum: 256)
        if let composition { guard editKind == "TOPIC" else { throw ModInstallationIssue.malformed };try composition.validate(parentRequestId: requestId,parentLicenseId: licenseId) }
        try ModInstallationValidation.hash(bindingHash)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        guard formatter.date(from: createdAt) != nil || fallback.date(from: createdAt) != nil else { throw ModInstallationIssue.malformed }
        var keys = Set<String>()
        for binding in bindings {
            try ModInstallationValidation.placeholder(binding.key); try ModInstallationValidation.hash(binding.fingerprint)
            try ModInstallationValidation.text(binding.label, maximum: 512)
            guard binding.resourceId > 0, keys.insert(binding.id).inserted else { throw ModInstallationIssue.malformed }
        }
        switch state {
        case .installed:
            guard memberTemplateID != nil || topicID != nil, errorCode == nil else { throw ModInstallationIssue.malformed }
        case .prepared, .cancelled:
            guard draftId == nil, errorCode == nil else { throw ModInstallationIssue.malformed }
        case .failed:
            guard draftId == nil, let errorCode else { throw ModInstallationIssue.malformed }
            try ModInstallationValidation.key(errorCode)
        }
    }
    func validate(previous: Self) throws {
        try validate(identity: previous.identity)
        guard requestId == previous.requestId, merchantId == previous.merchantId, anchorPoiId == previous.anchorPoiId,
              editKind == previous.editKind, composition == previous.composition, region.utf8.elementsEqual(previous.region.utf8), bindingHash == previous.bindingHash, createdAt == previous.createdAt,
              bindings.sorted(by: { $0.id < $1.id }) == previous.bindings.sorted(by: { $0.id < $1.id }),
              !previous.terminal || self == previous else { throw ModInstallationIssue.malformed }
    }
}

/// Durable command plus immutable server-preview facts; never persists authentication or licensed source text.
public struct ModInstallationAttempt: Codable, Equatable {
    public let request: ModInstallationRequest
    public let identity: ModInstallationIdentity
    public let region: String
    public let merchantLabel, anchorLabel: String
    public let bindings: [ModInstallationBoundResource]
    public enum PendingAction: String, Codable { case prepare, install, cancel }
    public var pendingAction: PendingAction?
    public var pendingFacts: ModInstallationFactConfirmation?
    public var receipt: ModInstallationReceipt?

    public init(options: ModInstallationOptions, merchantId: Int64, anchorPoiId: Int64, selections: [String: Int64]) throws {
        try options.validate(licenseId: options.licenseId, merchantId: merchantId)
        guard let merchant = options.merchants.first(where: { $0.id == merchantId }),
              let anchor = options.resources.first(where: { $0.kind == .poi && $0.id == anchorPoiId }),
              let region = anchor.region, selections.count == options.requiredBindings.count else { throw ModInstallationIssue.invalidSelection }
        try ModInstallationValidation.text(region, maximum: 256)
        var bindings: [ModInstallationBoundResource] = []
        for requirement in options.requiredBindings {
            guard let id = selections[requirement.id], let resource = options.resources.first(where: {
                $0.kind == requirement.kind && $0.id == id && $0.merchantId == merchantId
            }), resource.region == nil || resource.region?.utf8.elementsEqual(region.utf8) == true else { throw ModInstallationIssue.invalidSelection }
            bindings.append(.init(key: requirement.key, kind: requirement.kind, resourceId: resource.id,
                label: resource.label, fingerprint: resource.fingerprint))
        }
        bindings.sort { $0.id < $1.id }
        request = .init(requestId: UUID().uuidString.lowercased(), licenseId: options.licenseId, merchantId: merchantId,
            anchorPoiId: anchorPoiId, bindings: bindings.map(\.binding), clientVersion: 7, runtimeVersion: 1)
        identity = options.identity; self.region = region; merchantLabel = merchant.label; anchorLabel = anchor.label
        self.bindings = bindings; receipt = nil; pendingAction = .prepare; pendingFacts = nil; try validate()
    }
    /// Recovery from server history keeps the original request ID, never prepares another request.
    public init(restoring receipt: ModInstallationReceipt) throws {
        try receipt.validate(identity: receipt.identity)
        request = .init(requestId: receipt.requestId, licenseId: receipt.licenseId, merchantId: receipt.merchantId,
            anchorPoiId: receipt.anchorPoiId, bindings: receipt.bindings.map(\.binding), clientVersion: 4, runtimeVersion: 1)
        identity = receipt.identity; region = receipt.region; merchantLabel = String(receipt.merchantId)
        anchorLabel = String(receipt.anchorPoiId); bindings = receipt.bindings; self.receipt = receipt; pendingAction = nil; pendingFacts = nil; try validate()
    }
    public func validate() throws {
        try request.validate(); try identity.validate(); try ModInstallationValidation.text(region, maximum: 256)
        guard receipt != nil || pendingAction == .prepare,
              pendingAction == nil || receipt?.terminal != true,
              pendingAction != .prepare || receipt == nil else { throw ModInstallationIssue.malformed }
        try ModInstallationValidation.text(merchantLabel, maximum: 512); try ModInstallationValidation.text(anchorLabel, maximum: 512)
        guard request.licenseId == identity.licenseId,
              bindings.map(\.binding).sorted(by: { $0.id < $1.id }) == request.bindings.sorted(by: { $0.id < $1.id }) else { throw ModInstallationIssue.malformed }
        if let receipt { try validate(receipt: receipt) }
        if let pendingFacts {
            try pendingFacts.validate()
            guard receipt?.state == .installed, pendingFacts.bindingHash == receipt?.bindingHash, pendingAction == nil else { throw ModInstallationIssue.malformed }
        }
    }
    public func validate(receipt: ModInstallationReceipt) throws {
        try receipt.validate(identity: identity)
        guard receipt.requestId == request.requestId, receipt.merchantId == request.merchantId,
              receipt.anchorPoiId == request.anchorPoiId, receipt.region.utf8.elementsEqual(region.utf8),
              receipt.bindings.sorted(by: { $0.id < $1.id }) == bindings.sorted(by: { $0.id < $1.id }) else { throw ModInstallationIssue.malformed }
        if let previous = self.receipt { try receipt.validate(previous: previous) }
    }
}

/// A separate, explicit reviewed deployment grant. Purchase, login and merchant navigation do not mint it.
public struct ModInstallationApproval {
    public let revision = UUID()
    public let context: RuntimeDependencyContext
    public let expiresAt: Date
    public let readApprovalReference: String
    public let installApprovalReference: String?
    public let templateReviewApprovalReference: String?
    public let compatibilityReadApprovalReference: String?
    public let templateRehearsalReadApprovalReference: String?
    public let installedTextReadApprovalReference: String?
    public init(context: RuntimeDependencyContext, expiresAt: Date, readApprovalReference: String, installApprovalReference: String? = nil, templateReviewApprovalReference: String? = nil, templateRehearsalReadApprovalReference: String? = nil, compatibilityReadApprovalReference: String? = nil, installedTextReadApprovalReference: String? = nil) throws {
        _ = try APIConfiguration(baseURL: context.baseURL)
        guard context.market == .china, context.baseURL.scheme == "https", context.session.accountID > 0,
              expiresAt.timeIntervalSince1970.isFinite else { throw ModInstallationIssue.disabled }
        try ModInstallationValidation.text(readApprovalReference, maximum: 512)
        if let installApprovalReference { try ModInstallationValidation.text(installApprovalReference, maximum: 512) }
        self.context = context; self.expiresAt = expiresAt; self.readApprovalReference = readApprovalReference
        if let templateReviewApprovalReference { try ModInstallationValidation.text(templateReviewApprovalReference, maximum: 512) }
        self.templateReviewApprovalReference = templateReviewApprovalReference
        if let templateRehearsalReadApprovalReference { try ModInstallationValidation.text(templateRehearsalReadApprovalReference, maximum: 512) }
        self.templateRehearsalReadApprovalReference = templateRehearsalReadApprovalReference
        if let compatibilityReadApprovalReference { try ModInstallationValidation.text(compatibilityReadApprovalReference, maximum: 512) }
        self.compatibilityReadApprovalReference = compatibilityReadApprovalReference
        if let installedTextReadApprovalReference { try ModInstallationValidation.text(installedTextReadApprovalReference, maximum: 512) }
        self.installedTextReadApprovalReference = installedTextReadApprovalReference
        self.installApprovalReference = installApprovalReference
    }
    public func matches(_ context: RuntimeDependencyContext) -> Bool {
        ContentDraftContextFence.matches(self.context, context) &&
        self.context.session.role.utf8.elementsEqual(context.session.role.utf8) && Date() < expiresAt
    }
}

enum ModInstallationValidation {
    static func placeholder(_ value: String) throws {
        guard value.range(of: #"\A[A-Za-z][A-Za-z0-9_-]{0,47}\z"#, options: .regularExpression) != nil else { throw ModInstallationIssue.malformed }
    }
    static func key(_ value: String) throws {
        guard value.range(of: #"\A[A-Za-z0-9_-]{1,128}\z"#, options: .regularExpression) != nil else { throw ModInstallationIssue.malformed }
    }
    static func hash(_ value: String) throws {
        guard value.range(of: #"\A[a-f0-9]{64}\z"#, options: .regularExpression) != nil else { throw ModInstallationIssue.malformed }
    }
    static func text(_ value: String, maximum: Int) throws {
        guard !value.isEmpty, value.utf8.count <= maximum,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { throw ModInstallationIssue.malformed }
    }
    static func resource(_ value: ModInstallationResource) throws {
        guard value.id > 0, value.merchantId > 0 else { throw ModInstallationIssue.malformed }
        try text(value.label, maximum: 512); try hash(value.fingerprint)
        if let region = value.region { try text(region, maximum: 256) }
    }
}

/// Current GET projection only. Never persisted as approval or an original installation outcome.
public struct ModInstallationCompatibility: Decodable, Equatable {
    public let schema, licenseId, moduleId, releaseId, contentHash, termsHash: String
    public let clientVersion, runtimeVersion, minimumClientVersion: Int
    public let compatible: Bool
    public let reasonCode, scope: String
    public func validate(_ identity: ModInstallationIdentity) throws {
        guard schema == "mod-installation-compatibility-v1", licenseId == identity.licenseId,
              moduleId == identity.moduleId, releaseId == identity.releaseId, contentHash == identity.contentHash,
              termsHash == identity.termsHash, clientVersion == 7, runtimeVersion == 1,
              (1...7).contains(minimumClientVersion), scope == "TECHNICAL_PROFILE_ONLY_NOT_INSTALL_AUTHORIZATION",
              Set(["CURRENT_TECHNICAL_PROFILE_SUPPORTED", "LICENSE_NOT_ACTIVE", "ARTIFACT_NOT_ACTIVE", "CLIENT_OR_RUNTIME_UNSUPPORTED",
                   "QMOD_HOST_VERSION_CONFIGURATION_REQUIRED", "QMOD_HOST_VERSION_UNSUPPORTED", "QMOD_DEPENDENCY_RESOLVER_UNAVAILABLE",
                   "QMOD_RUNTIME_CAPABILITY_UNSUPPORTED", "ARTIFACT_VALIDATION_UNCONFIRMED"]).contains(reasonCode),
              compatible == (reasonCode == "CURRENT_TECHNICAL_PROFILE_SUPPORTED") else { throw ModInstallationIssue.malformed }
    }
}

/// Technical in-memory limit only. Crossing it is UNKNOWN/incomplete, never an empty successful directory.
/// Existing durable attempts store selected bindings, not this ephemeral multi-page buffer.
enum ModInstallationReadBudget {
    static let maximumRows = 10_000
    static let maximumBytes = 16 * 1024 * 1024
    static func include<T: Encodable>(_ rows: [T], count: inout Int, bytes: inout Int) throws {
        guard rows.count <= maximumRows - count else { throw ModInstallationIssue.readCapacityExceeded }
        for row in rows {
            let size = try JSONEncoder().encode(row).count + 1
            guard size <= maximumBytes - bytes else { throw ModInstallationIssue.readCapacityExceeded }
            bytes += size
        }
        count += rows.count
    }
}

struct ModInstallationOptionPage: Decodable {
    let schema, licenseId, moduleId, releaseId, contentHash, termsHash, title: String
    let requiredBindings: [ModInstallationRequirement]
    let merchantId: Int64?
    let kind: ModInstallationKind
    let afterId, nextAfterId: Int64?
    let items: [ModInstallationResource]
    var identity: ModInstallationIdentity {
        .init(licenseId: licenseId, moduleId: moduleId, releaseId: releaseId, contentHash: contentHash, termsHash: termsHash)
    }
    func validate(identity expected: ModInstallationIdentity, merchantId expectedMerchant: Int64?,
                  kind expectedKind: ModInstallationKind, afterId expectedAfter: Int64?) throws {
        guard schema == "mod-installation-options-page-v1", identity == expected,
              merchantId == expectedMerchant, kind == expectedKind, afterId == expectedAfter,
              items.count <= 50, requiredBindings.count <= 32 else { throw ModInstallationIssue.malformed }
        try identity.validate(); try ModInstallationValidation.text(title, maximum: 2048)
        var declarations = Set<String>()
        for value in requiredBindings {
            try ModInstallationValidation.placeholder(value.key)
            guard declarations.insert(value.id).inserted else { throw ModInstallationIssue.malformed }
        }
        var prior = expectedAfter ?? 0
        for item in items {
            try ModInstallationValidation.resource(item)
            guard item.kind == expectedKind, item.id > prior,
                  expectedMerchant.map({ item.merchantId == $0 }) ?? (item.kind == .site && item.merchantId == item.id) else {
                throw ModInstallationIssue.malformed
            }
            prior = item.id
        }
        if let nextAfterId {
            guard let last = items.last, nextAfterId == last.id, nextAfterId > (expectedAfter ?? 0) else {
                throw ModInstallationIssue.malformed
            }
        }
    }
    func matchesSource(_ other: ModInstallationOptionPage) -> Bool {
        identity == other.identity && title.utf8.elementsEqual(other.title.utf8) && requiredBindings == other.requiredBindings
    }
}

struct ModInstallationHistoryPage: Decodable {
    let schema, licenseId, moduleId, releaseId, contentHash, termsHash: String
    let beforeRequestId, nextBeforeRequestId: String?
    let items: [ModInstallationReceipt]
    func validate(identity expected: ModInstallationIdentity, beforeRequestId expectedBefore: String?) throws {
        let identity = ModInstallationIdentity(licenseId: licenseId, moduleId: moduleId, releaseId: releaseId,
                                               contentHash: contentHash, termsHash: termsHash)
        guard schema == "mod-installation-history-page-v1", identity == expected,
              beforeRequestId == expectedBefore, items.count <= 50 else { throw ModInstallationIssue.malformed }
        try identity.validate()
        var seen = Set<String>()
        for receipt in items {
            try receipt.validate(identity: expected)
            guard seen.insert(receipt.requestId).inserted, receipt.requestId != expectedBefore else { throw ModInstallationIssue.malformed }
        }
        if let nextBeforeRequestId {
            guard items.last?.requestId == nextBeforeRequestId, nextBeforeRequestId != expectedBefore else {
                throw ModInstallationIssue.malformed
            }
        }
    }
}
