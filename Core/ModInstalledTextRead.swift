import Foundation
import Observation

/// This is the canonical native-text artifact projection, not the legacy purchased-component DTO.
/// Original installed text is not the current edited draft, publication or runtime authority.
public struct ModInstalledTextRead: Decodable, CustomStringConvertible, CustomDebugStringConvertible {
    public let schema, scope, requestId, licenseId, moduleId, releaseId, contentHash, termsHash: String
    public let draftId: Int64
    public let editKind, bindingHash, createdAt, checkedAt: String
    private let sourceTextJson, sourceTextHash, installedTextJson, installedTextHash: String
    public let termsVersion, useDuration, updatePolicy, redistribution: String
    public let commercialUse: Bool
    public let allowedRegions: [String]
    public let installationLimit: Int64
    public let published, executable: Bool
    public var description: String { "ModInstalledTextRead[redacted]" }
    public var debugDescription: String { description }
    public static let fieldNames = ["title", "description", "players", "usageLocation", "requiredMaterials", "difficulty",
        "ruleInstructions", "merchantGuide", "questionName", "questionAnswer", "feedbackText", "questionA", "questionB",
        "questionC", "questionD", "correctAnswer", "storyText", "hint1", "hint2", "answerReveal", "photoRequireDesc", "activityCategoryids"]
    private static func fields(_ json: String, hash: String) throws -> [String: String] {
        guard json.utf8.count <= 1_048_576, ContentDraftRecord.hash(json) == hash,
              case .object(let values) = try ContentDraftJSON.parse(json), values.count <= fieldNames.count else { throw ModInstallationIssue.malformed }
        var result: [String: String] = [:]
        for (key, value) in values {
            guard let name = String(data: key, encoding: .utf8), fieldNames.contains(name),
                  case .string(let bytes) = value, bytes.count <= 262_144,
                  let text = String(data: bytes, encoding: .utf8) else { throw ModInstallationIssue.malformed }
            result[name] = text
        }
        guard result["title"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              result["ruleInstructions"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { throw ModInstallationIssue.malformed }
        return result
    }
    public func fields(installed: Bool) throws -> [String: String] {
        try Self.fields(installed ? installedTextJson : sourceTextJson, hash: installed ? installedTextHash : sourceTextHash)
    }
    public func validate(_ receipt: ModInstallationReceipt) throws {
        try receipt.validate(identity: receipt.identity)
        guard schema == "mod-installed-text-read-v1", scope == "OWNER_ORIGINAL_NATIVE_TEXT_PROTECTED_READ_ONLY",
              receipt.memberTemplateID != nil, receipt.composition == nil, requestId == receipt.requestId,
              licenseId == receipt.licenseId, moduleId == receipt.moduleId, releaseId == receipt.releaseId,
              contentHash == receipt.contentHash, termsHash == receipt.termsHash, draftId == receipt.draftId,
              editKind == receipt.editKind, bindingHash == receipt.bindingHash, createdAt == receipt.createdAt,
              !published, !executable, commercialUse, allowedRegions.contains(receipt.region),
              allowedRegions.count <= 32, Set(allowedRegions).count == allowedRegions.count, installationLimit > 0,
              useDuration == "PERPETUAL_PURCHASED_VERSION", updatePolicy == "EXACT_PURCHASED_VERSION",
              redistribution == "PROHIBITED" else { throw ModInstallationIssue.malformed }
        try ModInstallationValidation.text(termsVersion, maximum: 128)
        try ModInstallationValidation.hash(sourceTextHash); try ModInstallationValidation.hash(installedTextHash)
        for region in allowedRegions { try ModInstallationValidation.text(region, maximum: 256) }
        let date = ISO8601DateFormatter(); date.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard date.date(from: checkedAt) != nil || ISO8601DateFormatter().date(from: checkedAt) != nil else { throw ModInstallationIssue.malformed }
        _ = try fields(installed: false); _ = try fields(installed: true)
    }
}

/// One private read visit. It owns no persistence, installation, purchase, publication or runtime writer.
@MainActor @Observable public final class ModInstalledTextReader: Identifiable {
    public let id = UUID()
    public let installation: ModInstallationReceipt
    public private(set) var content: ModInstalledTextRead?
    public private(set) var loading = false
    public private(set) var issue: ModInstallationIssue?
    private let service: any ModInstallationServing
    private var generation = UUID()
    private var retired = false
    private var suspended = false
    init(installation: ModInstallationReceipt, service: any ModInstallationServing) { self.installation = installation; self.service = service }
    public var available: Bool { !retired && !suspended && service.canReadInstalledText }
    public func suspend() { generation = UUID(); suspended = true; content = nil; loading = false; issue = nil }
    public func retire() { suspend(); retired = true }
    @discardableResult public func refreshVisiblePermission() -> Bool {
        guard available else { content = nil; loading = false; return false }; return true
    }
    public func reload() async {
        guard !retired, !loading else { return }
        suspended = false; generation = UUID(); let captured = generation
        content = nil; issue = nil
        guard available else { issue = .disabled; return }
        loading = true
        defer { if generation == captured { loading = false } }
        do {
            let value = try await service.installedText(installation, acceptsResult: { [weak self] in
                guard let self else { return false }; return self.generation == captured && self.available
            })
            try Task.checkCancellation()
            guard generation == captured, available else { return }
            try value.validate(installation); content = value
        } catch {
            guard generation == captured, !retired, !suspended, !Task.isCancelled else { return }
            content = nil; issue = (error as? ModInstallationIssue) ?? .unavailable
        }
    }
}
