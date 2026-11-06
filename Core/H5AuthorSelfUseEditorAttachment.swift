import Foundation

/// Ephemeral identity verified against the original release, immutable BIND receipt and
/// current authority. It selects a fresh original-author read, never grants editor scope.
public struct H5AuthorSelfUseEditorAuthority: Equatable, Hashable, Sendable {
    public let authorId, topicId, organizationId, sourceTemplateId: Int64
    public let targetKind: H5AuthorSelfUseTargetKind
    public let bindingRequestId, applicationRequestId, moduleId, releaseId, contentHash, authorizationHash: String
    let originalBinding: H5AuthorSelfUseBinding
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.originalBinding.sameAuthority(rhs.originalBinding) }
    public func hash(into hasher: inout Hasher) { hasher.combine(bindingRequestId); hasher.combine(authorizationHash) }
    public init(release: H5AuthorSelfUseRelease, binding: H5AuthorSelfUseBinding, receipt: H5AuthorSelfUseReceipt, actor: Int) throws {
        guard binding.valid, binding.authorId == Int64(actor), binding.state == .active, binding.currentAvailable == true,
              binding.runtimeAuthorization == "REQUIRES_ORIGINAL_PUBLISHED_NODE_AND_PLAYER_RUN",
              release.matches(binding), receipt.receiptStatus == .bound, let command = receipt.command,
              receipt.binding?.sameAuthority(binding) == true else { throw H5AuthorSelfUseIssue.forbidden }
        try receipt.validate(actor: actor, expected: command)
        authorId = binding.authorId; topicId = binding.topicId; organizationId = binding.organizationId; sourceTemplateId = binding.sourceTemplateId
        targetKind = binding.targetKind; bindingRequestId = binding.id; applicationRequestId = binding.releaseApplicationRequestId
        moduleId = binding.moduleId; releaseId = binding.releaseId; contentHash = binding.contentHash; authorizationHash = binding.authorizationHash
        originalBinding = binding
    }
    public func validateOriginalDetail(_ raw: Data, session: ProjectEditSession) throws {
        let root = try JSONDecoder().decode([String: ProjectEditJSON].self, from: raw)
        guard let data = root["data"]?.object, let topic = data["topic"]?.object,
              session.accountID == Int(exactly: authorId), topic["id"]?.integer == Int(exactly: topicId),
              topic["memberId"]?.integer == Int(exactly: authorId), data["editScope"]?.text == "FULL",
              topic["configVersion"]?.integer.map({ $0 >= 0 }) == true else { throw H5AuthorSelfUseIssue.forbidden }
        switch targetKind {
        case .clubTopic: guard topic["clubId"]?.integer == Int(exactly: organizationId) else { throw H5AuthorSelfUseIssue.forbidden }
        case .merchantTopic: guard topic["clubId"] == nil || topic["clubId"] == .null || topic["clubId"]?.integer == 0 else { throw H5AuthorSelfUseIssue.forbidden }
        }
    }
}

@MainActor public protocol H5AuthorSelfUseEditorReading {
    var selfUseEditorAuthority: H5AuthorSelfUseEditorAuthority? { get }
    func readOriginalAuthorDetail(topicID: Int, session: ProjectEditSession) async throws -> ProjectEditAuthorDetailReadback
}
