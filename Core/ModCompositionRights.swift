import Foundation

/// Author evidence attached to the ORIGINAL release application. No field here is an approval.
public struct ModCompositionRightsProposal: Codable, Equatable {
    public let authors, installationSubjects, venues: [Int64]
    public let regions: [String]
    public let commercialUse, translation, adaptation, remix, embeddedRedistribution: Bool
    public let evidenceReferences: [String]
    public var venueScopeVersion: String? = nil
    public var venuePoiIds: [Int64]? = nil
    public var valid: Bool {
        func ids(_ value: [Int64]) -> Bool { !value.isEmpty && value.count <= 128 && Set(value).count == value.count && value.allSatisfy { $0 > 0 } }
        func texts(_ value: [String]) -> Bool { !value.isEmpty && value.count <= 32 && Set(value).count == value.count && value.allSatisfy(ModReleaseApplicationWire.text) }
        let physical = venueScopeVersion == nil && venuePoiIds == nil || venueScopeVersion == "original-owned-poi-v1" && venuePoiIds.map(ids) == true
        return physical && ids(authors) && ids(installationSubjects) && ids(venues) && texts(regions) && texts(evidenceReferences) && remix && embeddedRedistribution
    }
}
/// Display of an original reviewer-issued frozen grant. An authenticated DTO does not authorize any local action.
public struct ModCompositionRightsGrant: Codable, Equatable {
    public let profile, applicationRequestId, decisionId: String
    public let author, reviewer: Int64
    public let sourceKind: String
    public let sourceId, auditTaskId: Int64
    public let sourceHash, draftHash, packageId, packageVersion, releaseId, contentHash: String
    public let scope: ModCompositionRightsProposal
    public let approvedAt, grantHash: String
    public var valid: Bool {
        profile == "first-party-h5-composition-rights-v1" && author > 0 && reviewer > 0 && author != reviewer &&
            sourceId > 0 && auditTaskId > 0 && ["TEMPLATE", "TOPIC"].contains(sourceKind) && scope.valid &&
            [applicationRequestId, decisionId].allSatisfy(ModReleaseApplicationWire.uuid) &&
            [sourceHash, draftHash, contentHash, grantHash].allSatisfy(ModReleaseApplicationWire.hash) &&
            ModReleaseApplicationWire.key(releaseId) && packageVersion.range(of: #"\A(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\z"#, options: .regularExpression) != nil &&
            packageId.range(of: #"\A[a-z][a-z0-9._-]{0,63}\z"#, options: .regularExpression) != nil && ModReleaseApplicationView.date(approvedAt) != nil
    }
}
/// Original Terms projection for the release receipt, with an optional explicit composition exception.
/// Absent legacy fields remain unapproved; raw asset redistribution remains PROHIBITED.
public struct ModCompositionApprovedTerms: Codable, Equatable {
    public let version, hash, contentHash: String
    public let commercialUse: Bool
    public let allowedRegions: [String]
    public let installationLimit: Int64
    public let useDuration, updatePolicy, redistribution, refundPolicyReference: String
    public let compositionRights: ModCompositionRightsGrant?
}
public struct ModCompositionRightsDraft {
    public var requested = false
    public var physicalVenuesRequested = false, venuePoiIds = ""
    public var authors = "", installationSubjects = "", venues = "", regions = "", evidenceReferences = ""
    public var commercialUse = false, translation = false, adaptation = false, remix = false, embeddedRedistribution = false
    public init() { }
    public func proposal() throws -> ModCompositionRightsProposal? {
        guard requested else { return nil }
        func lines(_ raw: String) -> [String] { raw.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        func ids(_ raw: String) throws -> [Int64] {
            try lines(raw).map { value in
                guard value.range(of: #"\A[1-9][0-9]{0,18}\z"#, options: .regularExpression) != nil, let id = Int64(value), id > 0 else { throw ModReleaseApplicationIssue.invalidProposal }; return id
            }
        }
        var result = try ModCompositionRightsProposal(authors: ids(authors), installationSubjects: ids(installationSubjects), venues: ids(venues), regions: lines(regions),
            commercialUse: commercialUse, translation: translation, adaptation: adaptation, remix: remix, embeddedRedistribution: embeddedRedistribution, evidenceReferences: lines(evidenceReferences))
        if physicalVenuesRequested { result.venueScopeVersion = "original-owned-poi-v1"; result.venuePoiIds = try ids(venuePoiIds) }
        guard result.valid else { throw ModReleaseApplicationIssue.invalidProposal }; return result
    }
}
