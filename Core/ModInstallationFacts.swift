import Foundation

/// The current native draft, not the frozen licensed source. Editing changes draftContentHash and invalidates confirmation.
public struct ModInstallationFacts: Codable, Equatable, Identifiable {
    public var id: String { requestId + ":" + draftContentHash }
    public let schema, requestId, licenseId: String
    public let draftId, merchantId: Int64
    public let bindingHash, draftContentHash, title, rules: String
    public let confirmed: Bool
    public let bindings: [ModInstallationBoundResource]
    public let advancedConfigJson: String?
    public init(schema: String, requestId: String, licenseId: String, draftId: Int64, merchantId: Int64,
                bindingHash: String, draftContentHash: String, title: String, rules: String, confirmed: Bool,
                bindings: [ModInstallationBoundResource], advancedConfigJson: String? = nil) {
        self.schema = schema; self.requestId = requestId; self.licenseId = licenseId; self.draftId = draftId
        self.merchantId = merchantId; self.bindingHash = bindingHash; self.draftContentHash = draftContentHash
        self.title = title; self.rules = rules; self.confirmed = confirmed; self.bindings = bindings; self.advancedConfigJson = advancedConfigJson
    }
    public func validate(receipt: ModInstallationReceipt) throws {
        guard schema == "mod-installation-facts-v1", receipt.state == .installed,
              requestId == receipt.requestId, licenseId == receipt.licenseId, draftId == receipt.draftId,
              merchantId == receipt.merchantId, bindingHash == receipt.bindingHash,
              bindings.sorted(by: { $0.id < $1.id }) == receipt.bindings.sorted(by: { $0.id < $1.id }) else { throw ModInstallationIssue.malformed }
        if let advancedConfigJson, !advancedConfigJson.isEmpty {
            guard advancedConfigJson.utf8.count <= (receipt.editKind == "TOPIC" ? 1048576 : 65536) else { throw ModInstallationIssue.malformed }
            _ = try ContentDraftJSON.parse(advancedConfigJson)
        }
        try ModInstallationValidation.hash(draftContentHash)
        try ModInstallationValidation.text(title, maximum: 1024)
        guard (receipt.editKind == "TOPIC" || !rules.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty), rules.utf8.count <= 524288,
              rules.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) || [9, 10, 13].contains(Int($0.value)) }) else { throw ModInstallationIssue.malformed }
    }
    func validateConfirmation(of reviewed: Self) throws {
        guard requestId == reviewed.requestId, licenseId == reviewed.licenseId, draftId == reviewed.draftId,
              merchantId == reviewed.merchantId, bindingHash == reviewed.bindingHash,
              draftContentHash == reviewed.draftContentHash, title.utf8.elementsEqual(reviewed.title.utf8), rules.utf8.elementsEqual(reviewed.rules.utf8),
              bindings.sorted(by: { $0.id < $1.id }) == reviewed.bindings.sorted(by: { $0.id < $1.id }),
              advancedConfigJson == reviewed.advancedConfigJson, confirmed else { throw ModInstallationIssue.malformed }
    }
}
public struct ModInstallationFactConfirmation: Codable, Equatable {
    public let expectedDraftHash, bindingHash: String
    public init(facts: ModInstallationFacts) { expectedDraftHash = facts.draftContentHash; bindingHash = facts.bindingHash }
    func validate() throws {
        try ModInstallationValidation.hash(expectedDraftHash); try ModInstallationValidation.hash(bindingHash)
    }
}

/// Owner-only, already bound native content. Every value is rendered as text, not HTML or executable code.
public struct ModInstallationPreview: Codable, Equatable {
    public let schema, requestId, licenseId, bindingHash: String
    public let fields: [String: String]
    public func validate(receipt: ModInstallationReceipt) throws {
        if receipt.editKind == "TOPIC" {
            guard schema == "mod-installation-preview-v1", receipt.state == .prepared, requestId == receipt.requestId,
                  licenseId == receipt.licenseId, bindingHash == receipt.bindingHash, Set(fields.keys) == (receipt.composition == nil ? ["qmodTopicGraphJson"] : ["qmodTopicGraphJson","compositionReceiptJson"]),
                  let graph = fields["qmodTopicGraphJson"] else { throw ModInstallationIssue.malformed }
            let parsed = try ModInstallationTopicGraph(json: graph)
            guard parsed.compositionLockHash == receipt.composition?.lockHash else { throw ModInstallationIssue.malformed }
            let payload = try QmodSourceSubmissionWire.object(Data(graph.utf8), limit: 524288)
            if payload["adapter"] as? String == ModCompositionVenueSelection.adapter, payload[QmodContentLocalesArtifact.field] != nil {
                // No removal of bound metadata to make the default-language artifact compare equal.
                guard let physical = payload["originalVenueBindings"] as? [[String: Any]], physical.count == receipt.bindings.count,
                      payload["originalVenueNodes"] is [[String: Any]],
                      let physicalHash = payload["originalVenueBindingsHash"] as? String, QmodSourceSubmissionWire.hashValid(physicalHash) else { throw ModInstallationIssue.malformed }
                for value in physical {
                    guard let slot = value["slotId"] as? String, let poi = value["poiId"] as? Int64, let fingerprint = value["fingerprint"] as? String,
                          receipt.bindings.contains(where: { $0.key == slot && $0.kind == .poi && $0.resourceId == poi && $0.fingerprint == fingerprint }) else { throw ModInstallationIssue.malformed }
                }
            }
            if let expected = receipt.composition {
                guard let raw = fields["compositionReceiptJson"], raw.utf8.count <= 131072 else { throw ModInstallationIssue.malformed }
                _ = try ContentDraftJSON.parse(raw)
                let actual = try JSONDecoder().decode(ModCompositionInstallationReceipt.self,from: Data(raw.utf8))
                guard actual == expected else { throw ModInstallationIssue.malformed }
            }
            return
        }
        let allowed: Set<String> = ["title", "description", "players", "usageLocation", "requiredMaterials", "difficulty", "ruleInstructions", "merchantGuide", "questionName", "questionAnswer", "feedbackText", "questionA", "questionB", "questionC", "questionD", "correctAnswer", "storyText", "hint1", "hint2", "answerReveal", "photoRequireDesc", "activityCategoryids", "validationMethod", "duration", "categoryId", "advancedConfigJson", QmodContentLocalesArtifact.field]
        guard schema == "mod-installation-preview-v1", receipt.state == .prepared, requestId == receipt.requestId,
              licenseId == receipt.licenseId, bindingHash == receipt.bindingHash,
              Set(fields.keys).isSubset(of: allowed), fields["title"]?.isEmpty == false,
              fields["ruleInstructions"]?.isEmpty == false,
              fields.allSatisfy({ $0.value.utf8.count <= ($0.key == QmodContentLocalesArtifact.field ? 524288 : 128000) && !$0.value.contains("{{") }) else { throw ModInstallationIssue.malformed }
        if let json = fields[QmodContentLocalesArtifact.field] {
            var original: [String: Any] = fields
            guard let method = fields["validationMethod"].flatMap(Int.init) else { throw ModInstallationIssue.malformed }
            original["validationMethod"] = method
            _ = try QmodContentLocalesArtifact(json: json, expectedKind: "MEMBER_TEMPLATE", defaultPayload: original)
        }
        if let graph = fields["advancedConfigJson"] {
            guard fields["validationMethod"] == "0" else { throw ModInstallationIssue.malformed }
            _ = try ModInstallationNativeGraph(json: graph)
        }
    }
}

extension ModInstallationFacts {
    /// An entry hint only. Server rechecks installation origin, original node IDs, ownership and private state.
    public var hasQaEditorCandidate: Bool {
        guard let advancedConfigJson, let data = advancedConfigJson.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              root["bizType"] as? String == "TOPIC", let children = root["bundledTemplates"] as? [[String: Any]] else { return false }
        return children.contains { row in
            guard let raw = row["advancedConfigJson"] as? String else { return false }
            return (try? ModInstallationQaPick(json: raw)) != nil
        }
    }
}
