import Foundation

public struct NativeAttributeAuthorPublishIssue: Identifiable, Equatable {
    public let id: Int
    public let level: String
    public let code: String
    public let nodeID: Int?
    public let message: String
    public let field: String?
    public let original: ProjectEditJSON
    init(index: Int, source: ProjectEditJSON, requiresField: Bool = false) throws {
        guard let fields = source.object, let level = fields["level"]?.text,
              ["error","warn"].contains(level), let code = fields["code"]?.text, !code.isEmpty,
              let message = fields["message"]?.text else { throw NativeAttributeAuthorError.invalid("publish-check issue level/code/message") }
        if let node = fields["nodeId"], node != .null {
            guard let id = node.integer, id > 0 else { throw NativeAttributeAuthorError.invalid("publish-check nodeId") }
            nodeID = id
        } else { nodeID = nil }
        if requiresField {
            guard let field = fields["field"]?.text else { throw NativeAttributeAuthorError.invalid("module-preflight issue.field") }
            self.field = field
        } else { field = fields["field"]?.text }
        id = index; self.level = level; self.code = code; self.message = message; original = source
    }
}
public struct NativeAttributeAuthorPublishCheck: Equatable {
    public let binding: NativeAttributeAuthorBinding
    public let requestKey: UUID
    public let issues: [NativeAttributeAuthorPublishIssue]
    // Empty issues are diagnostic output, never an empty-reference proof or a write grant.
}
public struct NativeAttributeAuthorModulePreflight: Equatable {
    public let binding: NativeAttributeAuthorBinding
    public let requestKey: UUID
    public let topicID: Int64
    public let configVersion: Int64
    /// Original diagnostic ready flag. Never a save/publication result or operation permission.
    public let ready: Bool
    public let issues: [NativeAttributeAuthorPublishIssue]
    /// Full original object, including unknown fields, retained for the original host renderer.
    public let report: ProjectEditJSON
    init(binding: NativeAttributeAuthorBinding, requestKey: UUID, report: ProjectEditJSON) throws {
        guard let fields = report.object, let topicID = fields["topicId"]?.integer, topicID > 0,
              let version = fields["configVersion"]?.integer, version >= 0,
              case .bool(let ready)? = fields["ready"], let rows = fields["issues"]?.array,
              rows.count <= 4096 else { throw NativeAttributeAuthorError.invalid("module-preflight topicId/configVersion/ready/issues") }
        guard Int64(topicID) == binding.topicID, Int64(version) == binding.sourceConfigVersion else {
            throw NativeAttributeAuthorError.staleSource
        }
        let issues = try rows.enumerated().map { index, raw in
            try NativeAttributeAuthorPublishIssue(index: index, source: raw, requiresField: true)
        }
        // Check response consistency only. No project validator, field mapper or preflight
        // engine is reproduced; the server produced every issue and the original ready flag.
        guard ready == !issues.contains(where: { $0.level == "error" }) else {
            throw NativeAttributeAuthorError.invalid("module-preflight ready/issues inconsistent")
        }
        self.binding = binding; self.requestKey = requestKey; self.topicID = Int64(topicID)
        configVersion = Int64(version); self.ready = ready; self.issues = issues; self.report = report
    }
}
