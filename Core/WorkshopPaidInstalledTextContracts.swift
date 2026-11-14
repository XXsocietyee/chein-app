import Foundation

/// NEW protected read contract. Metadata and an installation receipt are references, not body-read
/// approval. This model is deliberately not Encodable or a TemplateAuthoringDraft.
public enum WorkshopPaidInstalledTextIssue: Error, Equatable {
    case disabled, invalid, malformed, unavailable, unauthorized, staleSession, staleAction
}
public struct WorkshopPaidInstalledTextReference: Equatable {
    public let item: WorkshopPurchasedItem
    public let receipt: WorkshopPaidInstallOutcome
    public let command: WorkshopPaidInstallCommand
    public let ownedDraftID: Int64
    public init(item: WorkshopPurchasedItem, receipt: WorkshopPaidInstallOutcome) throws {
        guard receipt.state == .installed, let command = receipt.command, command.belongs(to: item),
              let owned = receipt.ownedDraftId, owned > 0, receipt.installedAt != nil else { throw WorkshopPaidInstalledTextIssue.invalid }
        self.item = item; self.receipt = receipt; self.command = command; ownedDraftID = owned
    }
}
public struct WorkshopPaidInstalledTextFields: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public static let names = ["title", "description", "ruleInstructions", "merchantGuide", "questionName", "questionAnswer", "hint1", "hint2", "answerReveal"]
    private let values: [String: Data]
    public subscript(_ name: String) -> String? { values[name].flatMap { String(data: $0, encoding: .utf8) } }
    public var description: String { "WorkshopPaidInstalledTextFields[redacted]" }
    public var debugDescription: String { description }
    static func decode(_ text: String, component: Bool) throws -> Self {
        guard text.utf8.count <= (component ? 266_240 : 262_144),
              case .object(let fields) = try ContentDraftJSON.parse(text),
              fields[Data("schema".utf8)] == .string(Data("w18-member-text-v1".utf8)),
              fields[Data("bindings".utf8)] == .object([:]) else { throw WorkshopPaidInstalledTextIssue.malformed }
        let expected = Set((names + ["schema", "bindings"] + (component ? ["validationMethod"] : [])).map { Data($0.utf8) })
        guard Set(fields.keys).isSubset(of: expected), fields[Data("title".utf8)] != nil else { throw WorkshopPaidInstalledTextIssue.malformed }
        if component {
            guard fields[Data("validationMethod".utf8)] == .number(negative: false, digits: "1", exponent: 0) else { throw WorkshopPaidInstalledTextIssue.malformed }
        }
        var values: [String: Data] = [:]
        for name in names {
            if let value = fields[Data(name.utf8)] {
                if case .null = value { continue }
                guard case .string(let bytes) = value, String(data: bytes, encoding: .utf8) != nil else { throw WorkshopPaidInstalledTextIssue.malformed }
                values[name] = bytes
            }
        }
        guard let title = values["title"].flatMap({ String(data: $0, encoding: .utf8) }), !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw WorkshopPaidInstalledTextIssue.malformed }
        return Self(values: values)
    }
}
public struct WorkshopPaidInstalledTextRights: Decodable, Equatable {
    public let commercialUse, translation: WorkshopPurchasedItem.Permission
    public let adaptation: WorkshopPurchasedItem.Adaptation
    public let allowedRegions: [String]
    public let themeLimit, merchantLimit, runLimit: WorkshopPurchasedItem.Limit
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case useDuration, commercialUse, adaptation, translation, updates, redistribution, allowedRegions, themeLimit, merchantLimit, runLimit
    }
    public init(from decoder: Decoder) throws {
        try WorkshopPurchasedWire.exactKeys(decoder, Set(CodingKeys.allCases.map(\.rawValue)))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard try c.decode(String.self, forKey: .useDuration) == "PERPETUAL_PURCHASED_VERSION",
              try c.decode(String.self, forKey: .updates) == "EXACT_PURCHASED_VERSION",
              try c.decode(String.self, forKey: .redistribution) == "PROHIBITED" else { throw WorkshopPaidInstalledTextIssue.malformed }
        commercialUse = try c.decode(WorkshopPurchasedItem.Permission.self, forKey: .commercialUse)
        translation = try c.decode(WorkshopPurchasedItem.Permission.self, forKey: .translation)
        adaptation = try c.decode(WorkshopPurchasedItem.Adaptation.self, forKey: .adaptation)
        allowedRegions = try c.decode([String].self, forKey: .allowedRegions)
        themeLimit = try c.decode(WorkshopPurchasedItem.Limit.self, forKey: .themeLimit)
        merchantLimit = try c.decode(WorkshopPurchasedItem.Limit.self, forKey: .merchantLimit)
        runLimit = try c.decode(WorkshopPurchasedItem.Limit.self, forKey: .runLimit)
        guard !allowedRegions.isEmpty, allowedRegions.count <= 32,
              Set(allowedRegions.map { Data($0.utf8) }).count == allowedRegions.count,
              allowedRegions.allSatisfy({ WorkshopPurchasedWire.bounded($0, 128) }) else { throw WorkshopPaidInstalledTextIssue.malformed }
    }
    init(item: WorkshopPurchasedItem) {
        commercialUse = item.commercialUse; translation = item.translation; adaptation = item.adaptation
        allowedRegions = item.allowedRegions; themeLimit = item.themeLimit; merchantLimit = item.merchantLimit; runLimit = item.runLimit
    }
    func matches(_ item: WorkshopPurchasedItem) -> Bool {
        commercialUse == item.commercialUse && translation == item.translation && adaptation == item.adaptation &&
        Set(allowedRegions.map { Data($0.utf8) }) == Set(item.allowedRegions.map { Data($0.utf8) }) &&
        themeLimit == item.themeLimit && merchantLimit == item.merchantLimit && runLimit == item.runLimit
    }
}
/// Transient protected data. No generic save, share, editor export or publication representation.
public struct WorkshopPaidInstalledText: CustomStringConvertible, CustomDebugStringConvertible {
    public let requestID, licenseID, moduleID, purchasedVersionID, version: String
    public let contentHash, componentHash, installedAt, checkedAt: String
    public let ownedDraftID, ownedDraftRevision, originalTargetDraftID, originalTargetRevision: Int64
    public let originalTargetPayloadHash, originalBusinessType: String
    public let sourceJSON, componentJSON: String
    public let sourceFields, installedFields: WorkshopPaidInstalledTextFields
    public let termsVersion, termsHash, termsDocumentHash: String
    public let termsDocument: Data
    public let rights: WorkshopPaidInstalledTextRights
    public var description: String { "WorkshopPaidInstalledText[redacted]" }
    public var debugDescription: String { description }
    /// v2 installed-text is `w18-member-text-v1`, keyed by the reference's license and request.
    /// Fields the payload does not carry stay an em dash.
    init(reference: WorkshopPaidInstalledTextReference, fields: WorkshopPaidInstalledTextFields, sourceJSON: String) {
        let command = reference.command
        requestID = command.requestId
        licenseID = command.licenseId
        moduleID = String(command.moduleId)
        purchasedVersionID = command.purchasedVersionId
        version = "—"
        contentHash = command.contentHash
        componentHash = ContentDraftRecord.hash(sourceJSON)
        installedAt = reference.receipt.installedAt ?? "—"
        checkedAt = "—"
        ownedDraftID = reference.ownedDraftID
        ownedDraftRevision = command.targetRevision
        originalTargetDraftID = command.targetDraftId
        originalTargetRevision = command.targetRevision
        originalTargetPayloadHash = command.targetPayloadHash
        originalBusinessType = command.businessType
        self.sourceJSON = sourceJSON
        componentJSON = sourceJSON
        sourceFields = fields
        installedFields = fields
        termsVersion = reference.item.termsVersion
        termsHash = command.termsHash
        termsDocumentHash = "—"
        termsDocument = Data()
        rights = WorkshopPaidInstalledTextRights(item: reference.item)
    }
    func matches(_ reference: WorkshopPaidInstalledTextReference) -> Bool {
        let command = reference.command
        guard sourceFields == installedFields, rights.matches(reference.item) else { return false }
        return WorkshopPaidInstallWire.same(requestID, command.requestId) && WorkshopPaidInstallWire.same(licenseID, command.licenseId) &&
        WorkshopPaidInstallWire.same(moduleID, String(command.moduleId)) && WorkshopPaidInstallWire.same(purchasedVersionID, command.purchasedVersionId) &&
        ownedDraftID == reference.ownedDraftID
    }
}
