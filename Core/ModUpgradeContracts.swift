import Foundation

public enum ModUpgradeIssue: Error, Equatable {
    case disabled, staleSession, malformed, unauthorized, unavailable, notFound, selectionChanged, storageUnavailable, pendingConflict
    case preflightRejected(String)
    case originalNotFinished
    case comparisonTooLarge
}

/// Separately reviewed deployment grant. Neither purchase nor login nor an installation grant creates it.
public struct ModUpgradeApproval {
    public let revision = UUID()
    public let context: RuntimeDependencyContext
    public let expiresAt: Date
    public let readApprovalReference: String
    public let stageApprovalReference: String?
    public init(context: RuntimeDependencyContext, expiresAt: Date, readApprovalReference: String, stageApprovalReference: String? = nil) throws {
        _ = try APIConfiguration(baseURL: context.baseURL)
        guard context.market == .china, context.baseURL.scheme == "https", context.session.accountID > 0,
              expiresAt.timeIntervalSince1970.isFinite else { throw ModUpgradeIssue.disabled }
        try ModInstallationValidation.text(readApprovalReference, maximum: 512)
        if let stageApprovalReference { try ModInstallationValidation.text(stageApprovalReference, maximum: 512) }
        self.context = context; self.expiresAt = expiresAt; self.readApprovalReference = readApprovalReference
        self.stageApprovalReference = stageApprovalReference
    }
    public func matches(_ context: RuntimeDependencyContext) -> Bool {
        ContentDraftContextFence.matches(self.context, context) &&
        self.context.session.role.utf8.elementsEqual(context.session.role.utf8) && Date() < expiresAt
    }
}

/// Original frozen terms only. Missing comparison data is UNKNOWN, never a broad rights grant.
public struct ModUpgradeFrozenTermsComparison: Codable, Equatable {
    public let schema: String
    public let creatorId: Int64
    public let source, target: WorkshopCommerceTerms
    public init(schema: String, creatorId: Int64, source: WorkshopCommerceTerms, target: WorkshopCommerceTerms) {
        self.schema = schema; self.creatorId = creatorId; self.source = source; self.target = target
    }
    public func validate(source expected: ModInstallationIdentity, targetReleaseId: String,
                         targetContentHash: String, targetTermsHash: String) throws {
        guard schema == "mod-upgrade-frozen-terms-v1", creatorId > 0,
              source.contentHash == expected.contentHash, source.hash == expected.termsHash,
              target.contentHash == targetContentHash, target.hash == targetTermsHash else { throw ModUpgradeIssue.malformed }
        try validate(source, releaseId: expected.releaseId)
        try validate(target, releaseId: targetReleaseId)
    }
    private func validate(_ terms: WorkshopCommerceTerms, releaseId: String) throws {
        try ModInstallationValidation.text(terms.version, maximum: 2048)
        try ModInstallationValidation.hash(terms.hash); try ModInstallationValidation.hash(terms.contentHash)
        guard terms.installationLimit > 0, !terms.allowedRegions.isEmpty, terms.allowedRegions.count <= 32,
              Set(terms.allowedRegions).count == terms.allowedRegions.count,
              terms.useDuration == "PERPETUAL_PURCHASED_VERSION", terms.updatePolicy == "EXACT_PURCHASED_VERSION",
              terms.redistribution == "PROHIBITED" else { throw ModUpgradeIssue.malformed }
        for region in terms.allowedRegions { try ModInstallationValidation.text(region, maximum: 2048) }
        try ModInstallationValidation.text(terms.refundPolicyReference, maximum: 2048)
        if let rights = terms.compositionRights {
            guard rights.matches(releaseId: releaseId, contentHash: terms.contentHash, creatorId: creatorId,
                                 allowedRegions: terms.allowedRegions, commercialUse: terms.commercialUse) else { throw ModUpgradeIssue.malformed }
        }
    }
}

/// Metadata and frozen contract scope only: no licensed answers, source payload or executable content.
public struct ModUpgradeCandidate: Codable, Equatable, Identifiable {
    public enum Ordering: String, Codable { case newerPackageVersion = "NEWER_PACKAGE_VERSION", otherReviewedRelease = "OTHER_REVIEWED_RELEASE" }
    public enum Authorization: String, Codable { case authorized = "AUTHORIZED", acquisitionRequired = "ACQUISITION_REQUIRED" }
    public enum Compatibility: String, Codable { case compatible = "COMPATIBLE", blocked = "BLOCKED" }
    public let offerId, title, targetReleaseId, targetContentHash, targetTermsHash: String
    public let packageId, packageVersion: String?
    public let ordering: Ordering
    public let authorization: Authorization
    public let targetLicenseId: String?
    public let comparisonHash: String
    public let changedFields: [String]
    public let requiredBindings: [ModInstallationRequirement]
    public let compatibility: Compatibility
    public let conflicts: [String]
    /// Optional only for old wire/journal compatibility. New confirmation requires an explicit snapshot.
    public let termsComparison: ModUpgradeFrozenTermsComparison?
    public init(offerId: String, title: String, targetReleaseId: String, targetContentHash: String, targetTermsHash: String,
                packageId: String?, packageVersion: String?, ordering: Ordering, authorization: Authorization,
                targetLicenseId: String?, comparisonHash: String, changedFields: [String],
                requiredBindings: [ModInstallationRequirement], compatibility: Compatibility, conflicts: [String],
                termsComparison: ModUpgradeFrozenTermsComparison? = nil) {
        self.offerId = offerId; self.title = title; self.targetReleaseId = targetReleaseId
        self.targetContentHash = targetContentHash; self.targetTermsHash = targetTermsHash
        self.packageId = packageId; self.packageVersion = packageVersion; self.ordering = ordering
        self.authorization = authorization; self.targetLicenseId = targetLicenseId; self.comparisonHash = comparisonHash
        self.changedFields = changedFields; self.requiredBindings = requiredBindings; self.compatibility = compatibility
        self.conflicts = conflicts; self.termsComparison = termsComparison
    }
    public var id: String { offerId }
    public func identity(source: ModInstallationIdentity) -> ModInstallationIdentity? {
        guard authorization == .authorized, let targetLicenseId else { return nil }
        return .init(licenseId: targetLicenseId, moduleId: source.moduleId, releaseId: targetReleaseId,
                     contentHash: targetContentHash, termsHash: targetTermsHash)
    }
    public func validate(source: ModInstallationIdentity) throws {
        try ModInstallationValidation.key(offerId); try ModInstallationValidation.key(targetReleaseId)
        try ModInstallationValidation.text(title, maximum: 2048)
        for hash in [targetContentHash, targetTermsHash, comparisonHash] { try ModInstallationValidation.hash(hash) }
        guard targetReleaseId != source.releaseId, changedFields.count <= 64, requiredBindings.count <= 32,
              conflicts.count <= 64, Set(changedFields).count == changedFields.count,
              Set(requiredBindings.map(\.id)).count == requiredBindings.count,
              (packageId == nil) == (packageVersion == nil),
              ordering != .newerPackageVersion || packageVersion != nil else { throw ModUpgradeIssue.malformed }
        if let packageId { try ModInstallationValidation.text(packageId, maximum: 128) }
        if let packageVersion { try ModInstallationValidation.text(packageVersion, maximum: 128) }
        for field in changedFields { try ModInstallationValidation.text(field, maximum: 128) }
        for conflict in conflicts { try ModInstallationValidation.text(conflict, maximum: 512) }
        for requirement in requiredBindings { try ModInstallationValidation.placeholder(requirement.key) }
        switch authorization {
        case .authorized:
            guard let identity = identity(source: source), identity.licenseId != source.licenseId else { throw ModUpgradeIssue.malformed }
            try identity.validate()
        case .acquisitionRequired:
            guard targetLicenseId == nil else { throw ModUpgradeIssue.malformed }
        }
        guard compatibility != .compatible || conflicts.isEmpty else { throw ModUpgradeIssue.malformed }
        try termsComparison?.validate(source: source, targetReleaseId: targetReleaseId,
                                      targetContentHash: targetContentHash, targetTermsHash: targetTermsHash)
        guard try JSONEncoder().encode(self).count <= 229376 else { throw ModUpgradeIssue.malformed }
    }
}

public struct ModUpgradeVersionPage: Codable, Equatable {
    public let schema: String
    public let source: ModInstallationIdentity
    public let sourceTitle: String
    public let candidates: [ModUpgradeCandidate]
    public let nextCursor: String?
    public func validate(source expected: ModInstallationIdentity) throws {
        guard schema == "mod-upgrade-versions-v1", source == expected, candidates.count <= 50,
              Set(candidates.map(\.offerId)).count == candidates.count else { throw ModUpgradeIssue.malformed }
        try source.validate(); try ModInstallationValidation.text(sourceTitle, maximum: 2048)
        if let nextCursor { try ModInstallationValidation.key(nextCursor) }
        for candidate in candidates { try candidate.validate(source: source) }
    }
}

/// Frozen buyer selection plus the original installation command. No token or licensed payload is persisted.
public struct ModUpgradeIntent: Codable, Equatable {
    public let source: ModInstallationIdentity
    public let candidate: ModUpgradeCandidate
    public let confirmedByBuyer: Bool
    public var installation: ModInstallationRequest?
    public var rejectionReason: String?
    public var target: ModInstallationIdentity? { candidate.identity(source: source) }
    public init(source: ModInstallationIdentity, candidate: ModUpgradeCandidate, confirmedByBuyer: Bool) throws {
        // Decoding old persisted commands still uses validate(), so original recovery remains possible.
        guard candidate.termsComparison != nil else { throw ModUpgradeIssue.selectionChanged }
        self.source = source; self.candidate = candidate; self.confirmedByBuyer = confirmedByBuyer; installation = nil; rejectionReason = nil
        try validate()
    }
    public func validate() throws {
        try source.validate(); try candidate.validate(source: source)
        guard confirmedByBuyer, candidate.compatibility == .compatible, let target else { throw ModUpgradeIssue.selectionChanged }
        try target.validate()
        if let rejectionReason {
            guard installation != nil, rejectionReason.hasPrefix("UPGRADE_PREFLIGHT_REJECTED:"),
                  rejectionReason.utf8.count <= 512 else { throw ModUpgradeIssue.malformed }
        }
        if let installation {
            try installation.validate()
            guard installation.licenseId == target.licenseId else { throw ModUpgradeIssue.pendingConflict }
        }
    }
}

public struct ModUpgradeStageCommand: Encodable {
    public let sourceLicenseId, offerId, comparisonHash: String
    public let confirmedByBuyer: Bool
    public let installation: ModInstallationRequest
    public init(intent: ModUpgradeIntent) throws {
        try intent.validate()
        guard let installation = intent.installation, intent.rejectionReason == nil else { throw ModUpgradeIssue.pendingConflict }
        sourceLicenseId = intent.source.licenseId; offerId = intent.candidate.offerId
        comparisonHash = intent.candidate.comparisonHash; confirmedByBuyer = intent.confirmedByBuyer; self.installation = installation
    }
}
