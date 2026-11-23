import Foundation

/// A row from /api/project/my selects an edit-detail read. It grants no write authority
/// and supplies no gameplay mode or revision; both must come from that fresh read.
public struct ProjectEditRemoteTarget: Equatable, Hashable, Identifiable {
    public let topicID: Int
    public let owner: ProjectEditOwner
    public let readerScope: UUID
    public var id: String { "\(readerScope):\(owner.rawValue):\(topicID)" }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.topicID == rhs.topicID && lhs.owner.rawValue == rhs.owner.rawValue && lhs.readerScope == rhs.readerScope }
    public func hash(into hasher: inout Hasher) { hasher.combine(topicID); hasher.combine(owner.rawValue); hasher.combine(readerScope) }
    /// A verified installation selects a fresh edit-detail read and grants no edit authority.
    public init?(installationReceipt receipt: ModInstallationReceipt, readerScope: UUID) {
        guard (try? receipt.validate(identity: receipt.identity)) != nil, let id = receipt.topicID else { return nil }
        topicID = id; owner = .merchant; self.readerScope = readerScope
    }
    /// MP `fabu?id=` (fix-parity C-F11): selects the fresh edit-detail read for that topic; the server still decides ownership.
    public init?(topicID: Int, owner: ProjectEditOwner, readerScope: UUID) {
        guard topicID > 0 else { return nil }
        self.topicID = topicID; self.owner = owner; self.readerScope = readerScope
    }
    public init?(project: CreatorContentProject, readerScope: UUID) {
        guard project.bizType == "topic", project.sourceID > 0 else { return nil }
        switch project.ownerType {
        case "member": owner = .personal
        case "merchant": owner = .merchant
        default: return nil // Club ownership has no reviewed professional editor scope.
        }
        topicID = project.sourceID; self.readerScope = readerScope
    }
}

public enum ProjectEditContinuationFailure: Error { case changedPending, baselineSaved }
