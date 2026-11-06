import Foundation

public enum ModReleaseApplicationIssue: String, Error, Equatable {
    case disabled, stale, invalidProposal, malformed, storage, unknown, notFound, unauthorized, conflict
}
/// Omission is the shipped WORKSHOP contract. New intents always make an explicit choice.
public enum ModReleaseDistributionChoice: String, Codable, CaseIterable, Sendable {
    case selfUse = "SELF_USE", workshop = "WORKSHOP"
}
public enum ModReleaseApplicationWire {
    static func uuid(_ value: String) -> Bool { QmodSourceSubmissionWire.uuid(value) }
    static func hash(_ value: String) -> Bool { QmodSourceSubmissionWire.hashValid(value) }
    static func key(_ value: String) -> Bool { value.range(of: "\\A[a-zA-Z0-9_-]{1,128}\\z", options: .regularExpression) != nil }
    static func profile(_ kind: String?) -> String { kind ?? "TEMPLATE" }
    static func review(kind: String?, attempt: String?) -> Bool {
        switch profile(kind) { case "TEMPLATE": return attempt.map(uuid) == true; case "TOPIC": return attempt == nil; default: return false }
    }
    static func text(_ value: String) -> Bool {
        !value.isEmpty && value == value.trimmingCharacters(in: .whitespacesAndNewlines) && value.utf16.count <= 256 &&
            !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
}
public struct ModReleaseApplicationSource: Codable, Equatable, Hashable {
    public let sourceRequestId, sourceHash, draftHash: String
    public let reviewAttemptId: String?
    public var sourceKind: String? = nil
    public let auditTaskId: Int64
    public init(review: QmodSourceSubmissionReview) throws {
        guard review.schema == "qmod-source-review-v1", review.phase == "SUBMITTED", review.auditStatus == "APPROVED",
              review.draftMatchesReviewed, let attempt = review.reviewAttemptId, let task = review.auditTaskId,
              task > 0, ModReleaseApplicationWire.uuid(review.requestId), ModReleaseApplicationWire.uuid(attempt),
              ModReleaseApplicationWire.hash(review.sourceHash), ModReleaseApplicationWire.hash(review.draftHash) else { throw ModReleaseApplicationIssue.malformed }
        sourceRequestId = review.requestId; reviewAttemptId = attempt; sourceHash = review.sourceHash; draftHash = review.draftHash; auditTaskId = task
    }
    public init(topicEligibility e: ModReleaseApplicationEligibility) throws {
        sourceRequestId = e.sourceRequestId; reviewAttemptId = e.reviewAttemptId; sourceHash = e.sourceHash; draftHash = e.draftHash; auditTaskId = e.auditTaskId; sourceKind = e.sourceKind
        guard sourceKind == "TOPIC", valid, e.matches(self) else { throw ModReleaseApplicationIssue.malformed }
    }
    var valid: Bool { ModReleaseApplicationWire.uuid(sourceRequestId) && ModReleaseApplicationWire.review(kind: sourceKind, attempt: reviewAttemptId) && ModReleaseApplicationWire.hash(sourceHash) && ModReleaseApplicationWire.hash(draftHash) && auditTaskId > 0 }
}
public struct ModReleaseApplicationProposal: Codable, Equatable {
    public let title: String
    public let priceMinor: Int64?, currency: String?, commercialUse: Bool?, allowedRegions: [String]?, installationLimit: Int64?
    public var compositionRights: ModCompositionRightsProposal? = nil
    public init(title: String, priceMinor: Int64? = nil, currency: String? = nil, commercialUse: Bool? = nil,
                allowedRegions: [String]? = nil, installationLimit: Int64? = nil, compositionRights: ModCompositionRightsProposal? = nil) throws {
        self.title = title; self.priceMinor = priceMinor; self.currency = currency; self.commercialUse = commercialUse
        self.allowedRegions = allowedRegions; self.installationLimit = installationLimit; self.compositionRights = compositionRights
        guard valid else { throw ModReleaseApplicationIssue.invalidProposal }
    }
    var valid: Bool {
        ModReleaseApplicationWire.text(title) && ((priceMinor == nil && currency == nil) ||
            (priceMinor.map { $0 >= 0 && $0 <= Int64(Int32.max) } == true && currency.map { ["CNY", "USD"].contains($0) } == true)) &&
            (compositionRights.map(\.valid) ?? true) && (installationLimit.map { $0 > 0 } ?? true) &&
            (allowedRegions.map { !$0.isEmpty && $0.count <= 32 && Set($0).count == $0.count && $0.allSatisfy(ModReleaseApplicationWire.text) } ?? true)
    }
    var validForSelfUse: Bool {
        ModReleaseApplicationWire.text(title) && priceMinor == nil && currency == nil && commercialUse == nil &&
            allowedRegions == nil && installationLimit == nil && compositionRights == nil
    }
}
public struct ModReleaseApplicationEligibility: Codable, Equatable {
    public let sourceRequestId: String
    public let reviewAttemptId: String?
    public var sourceKind: String? = nil
    public let sourceId, draftId: Int64
    public let sourceHash, draftHash: String
    public let auditTaskId: Int64
    public let packageId: String, moduleIds: [String], registeredReleaseId: String?
    public func matches(_ source: ModReleaseApplicationSource) -> Bool {
        source.valid && ModReleaseApplicationWire.profile(sourceKind) == ModReleaseApplicationWire.profile(source.sourceKind) && sourceRequestId == source.sourceRequestId && reviewAttemptId == source.reviewAttemptId &&
            sourceHash == source.sourceHash && draftHash == source.draftHash && auditTaskId == source.auditTaskId && sourceId > 0 && draftId > 0 &&
            ModReleaseApplicationWire.text(packageId) && moduleIds.count <= 501 && Set(moduleIds).count == moduleIds.count && moduleIds.allSatisfy(ModReleaseApplicationWire.key) &&
            (registeredReleaseId.map(ModReleaseApplicationWire.key) ?? true)
    }
    func selectedModule(_ selection: String?) throws -> String? {
        if moduleIds.isEmpty { guard selection == nil else { throw ModReleaseApplicationIssue.invalidProposal }; return nil }
        if moduleIds.count == 1 { guard selection == nil || selection == moduleIds[0] else { throw ModReleaseApplicationIssue.invalidProposal }; return moduleIds[0] }
        guard let selection, moduleIds.contains(selection) else { throw ModReleaseApplicationIssue.invalidProposal }; return selection
    }
}
public struct ModReleaseApplicationCommand: Codable, Equatable {
    public let requestId, sourceRequestId, sourceHash, draftHash: String
    public let reviewAttemptId: String?
    public var sourceKind: String? = nil
    public let auditTaskId: Int64
    public let proposal: ModReleaseApplicationProposal
    public let confirmedByAuthor: Bool
    public let previousRequestId, existingModuleId: String?
    public var distributionChoice: ModReleaseDistributionChoice? = nil
    public var distribution: ModReleaseDistributionChoice { distributionChoice ?? .workshop }
    init(source: ModReleaseApplicationSource, eligibility: ModReleaseApplicationEligibility, proposal: ModReleaseApplicationProposal,
         existingModuleId: String?, previousRequestId: String? = nil, distributionChoice: ModReleaseDistributionChoice? = nil) throws {
        guard eligibility.matches(source), proposal.valid, previousRequestId.map(ModReleaseApplicationWire.uuid) ?? true else { throw ModReleaseApplicationIssue.invalidProposal }
        requestId = UUID().uuidString.lowercased(); sourceRequestId = source.sourceRequestId; reviewAttemptId = source.reviewAttemptId; sourceKind = source.sourceKind
        sourceHash = source.sourceHash; draftHash = source.draftHash; auditTaskId = source.auditTaskId
        self.proposal = proposal; confirmedByAuthor = true; self.previousRequestId = previousRequestId
        self.existingModuleId = try eligibility.selectedModule(existingModuleId)
        self.distributionChoice = distributionChoice
        guard valid else { throw ModReleaseApplicationIssue.invalidProposal }
    }
    var valid: Bool {
        ModReleaseApplicationWire.uuid(requestId) && ModReleaseApplicationWire.uuid(sourceRequestId) && ModReleaseApplicationWire.review(kind: sourceKind, attempt: reviewAttemptId) &&
            ModReleaseApplicationWire.hash(sourceHash) && ModReleaseApplicationWire.hash(draftHash) && auditTaskId > 0 && proposal.valid && confirmedByAuthor &&
            (previousRequestId.map { ModReleaseApplicationWire.uuid($0) && $0 != requestId } ?? true) && (existingModuleId.map(ModReleaseApplicationWire.key) ?? true) &&
            (distribution != .selfUse || (ModReleaseApplicationWire.profile(sourceKind) == "TEMPLATE" && proposal.validForSelfUse))
    }
}
/// Exact ModCommerceContracts.Offer wire, including review evidence absent from the buyer's projection.
/// Frozen license terms reuse the existing commerce model; nothing here authorizes purchase or installation.
public struct ModReleaseApplicationApprovedOffer: Codable, Equatable {
    public let offerId, moduleId, releaseId: String
    public let creatorId: Int64
    public let title, currency: String
    public let priceMinor, platformFeeMinor, taxMinor, creatorMinor: Int64
    public let economicsApprovalReference, contentApprovalReference: String
    public let digitalChannelApprovalReference, platform, market, productType, channel, merchantId, appId: String?
    public let terms: ModCompositionApprovedTerms
    var valid: Bool {
        guard [offerId, moduleId, releaseId].allSatisfy(ModReleaseApplicationWire.key), creatorId > 0,
              ModReleaseApplicationWire.text(title), ["CNY", "USD"].contains(currency), priceMinor >= 0, priceMinor <= Int64(Int32.max),
              [platformFeeMinor, taxMinor, creatorMinor].allSatisfy({ $0 >= 0 && $0 <= priceMinor }),
              platformFeeMinor + taxMinor + creatorMinor == priceMinor,
              [economicsApprovalReference, contentApprovalReference, terms.version, terms.refundPolicyReference].allSatisfy(ModReleaseApplicationWire.text),
              ModReleaseApplicationWire.hash(terms.hash), ModReleaseApplicationWire.hash(terms.contentHash),
              !terms.allowedRegions.isEmpty, terms.allowedRegions.count <= 32, Set(terms.allowedRegions).count == terms.allowedRegions.count,
              terms.allowedRegions.allSatisfy(ModReleaseApplicationWire.text), terms.installationLimit > 0,
              terms.useDuration == "PERPETUAL_PURCHASED_VERSION", terms.updatePolicy == "EXACT_PURCHASED_VERSION", terms.redistribution == "PROHIBITED" else { return false }
        if priceMinor > 0 {
            guard [digitalChannelApprovalReference, merchantId, appId].allSatisfy({ $0.map(ModReleaseApplicationWire.text) == true }),
                  platform.map({ ["IOS", "ANDROID"].contains($0) }) == true, market.map({ ["CN", "US"].contains($0) }) == true,
                  productType == "DIGITAL_MOD", channel.map({ ["APPLE_STOREKIT", "WECHAT_APP"].contains($0) }) == true else { return false }
            if channel == "APPLE_STOREKIT" && platform != "IOS" { return false }
            if channel == "WECHAT_APP" && (market != "CN" || currency != "CNY") { return false }
        }
        if let grant = terms.compositionRights {
            guard grant.valid, grant.author == creatorId, grant.releaseId == releaseId, grant.contentHash == terms.contentHash else { return false }
        }
        return true
    }
    func preserves(_ p: ModReleaseApplicationProposal) -> Bool {
        p.title == title && (p.priceMinor.map { $0 == priceMinor } ?? true) && (p.currency.map { $0 == currency } ?? true) &&
            (p.commercialUse.map { $0 == terms.commercialUse } ?? true) && (p.allowedRegions.map { $0 == terms.allowedRegions } ?? true) &&
            (p.installationLimit.map { $0 == terms.installationLimit } ?? true) && p.compositionRights == terms.compositionRights?.scope
    }
}
public struct ModReleaseApplicationView: Codable, Equatable, Identifiable {
    public enum State: String, Codable { case validating = "VALIDATING", pending = "PENDING", preflightRejected = "PREFLIGHT_REJECTED", rejected = "REJECTED", cancelled = "CANCELLED", approved = "APPROVED" }
    public let schema: String, owner: Int64, requestId: String, sourceRequestId: String
    public let reviewAttemptId: String?
    public var sourceKind: String? = nil
    public let sourceId, draftId: Int64?
    public let sourceHash, draftHash: String
    public let auditTaskId: Int64
    public let moduleId, releaseId, offerId: String?
    public let proposal: ModReleaseApplicationProposal, state: State, reason: String?, reviewedBy: Int64?, reviewedAt: String?, contentHash: String?
    public let approvedOffer: ModReleaseApplicationApprovedOffer?
    public var decisionId: String? = nil
    public var distributionChoice: ModReleaseDistributionChoice? = nil
    public var distribution: ModReleaseDistributionChoice { distributionChoice ?? .workshop }
    public var id: String { requestId }
    public var permitsNewIntent: Bool { [.preflightRejected, .rejected, .cancelled].contains(state) && approvedOffer == nil }
    public var terminal: Bool { permitsNewIntent || state == .approved }
    func valid(owner: Int) -> Bool {
        guard schema == "mod-release-application-v1", self.owner == Int64(owner), owner > 0,
              [requestId, sourceRequestId].allSatisfy(ModReleaseApplicationWire.uuid), ModReleaseApplicationWire.review(kind: sourceKind, attempt: reviewAttemptId),
              [sourceHash, draftHash].allSatisfy(ModReleaseApplicationWire.hash), auditTaskId > 0, proposal.valid,
              [sourceId, draftId, reviewedBy].allSatisfy({ $0.map { $0 > 0 } ?? true }),
              [moduleId, releaseId, offerId].allSatisfy({ $0.map(ModReleaseApplicationWire.key) ?? true }),
              (contentHash.map(ModReleaseApplicationWire.hash) ?? true),
              (distribution != .selfUse || (ModReleaseApplicationWire.profile(sourceKind) == "TEMPLATE" && proposal.validForSelfUse && offerId == nil && approvedOffer == nil)),
              (decisionId.map(ModReleaseApplicationWire.uuid) ?? true), (reason.map { $0.utf16.count <= 1000 } ?? true),
              (reviewedAt.map { $0.utf8.count <= 64 && Self.date($0) != nil } ?? true) else { return false }
        if state != .validating && state != .preflightRejected {
            guard sourceId != nil, draftId != nil, moduleId != nil, releaseId != nil,
                  distribution == .selfUse || offerId != nil else { return false }
        }
        if state == .approved {
            if distribution == .selfUse {
                guard contentHash != nil, reviewedBy != nil, let reviewedAt, Self.date(reviewedAt) != nil else { return false }
            } else {
                guard let approvedOffer, approvedOffer.valid, approvedOffer.preserves(proposal), approvedOffer.creatorId == self.owner,
                  approvedOffer.offerId == offerId, approvedOffer.moduleId == moduleId, approvedOffer.releaseId == releaseId,
                  approvedOffer.terms.contentHash == contentHash, reviewedBy != nil, let reviewedAt,
                  ModReleaseApplicationView.date(reviewedAt) != nil else { return false }
            }
        } else if approvedOffer != nil { return false }
        return true
    }
    static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
    func matches(_ command: ModReleaseApplicationCommand, owner: Int) -> Bool {
        valid(owner: owner) && command.valid && distribution == command.distribution && ModReleaseApplicationWire.profile(sourceKind) == ModReleaseApplicationWire.profile(command.sourceKind) && requestId == command.requestId && sourceRequestId == command.sourceRequestId &&
            reviewAttemptId == command.reviewAttemptId && sourceHash == command.sourceHash && draftHash == command.draftHash && auditTaskId == command.auditTaskId && proposal == command.proposal &&
            (command.existingModuleId.map { moduleId == nil || moduleId == $0 } ?? true)
    }
    func canFollow(_ old: Self) -> Bool {
        guard distribution == old.distribution, ModReleaseApplicationWire.profile(sourceKind) == ModReleaseApplicationWire.profile(old.sourceKind), requestId == old.requestId, owner == old.owner, sourceRequestId == old.sourceRequestId, reviewAttemptId == old.reviewAttemptId,
              sourceHash == old.sourceHash, draftHash == old.draftHash, auditTaskId == old.auditTaskId, proposal == old.proposal else { return false }
        if old.terminal { return sameRecordedFact(as: old) }
        if old.state == .pending && state == .validating { return false }
        return (old.sourceId.map { sourceId == $0 } ?? true) && (old.draftId.map { draftId == $0 } ?? true) &&
            (old.moduleId.map { moduleId == $0 } ?? true) && (old.releaseId.map { releaseId == $0 } ?? true) && (old.offerId.map { offerId == $0 } ?? true)
    }
    /// The backend now emits WORKSHOP for old records. Only omission of that legacy
    /// discriminator is normalized; all original reviewed facts must still be identical.
    func sameRecordedFact(as other: Self) -> Bool {
        guard distribution == other.distribution else { return false }
        var lhs = self, rhs = other; lhs.distributionChoice = nil; rhs.distributionChoice = nil
        return lhs == rhs
    }
}
