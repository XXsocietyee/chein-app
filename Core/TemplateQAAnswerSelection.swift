import Foundation

/// Local answer configuration over the existing QA wire fields. Reading never normalizes a draft.
public struct TemplateQAAnswerSelection {
    public struct Option: Identifiable, Equatable {
        public let id: String
        public let ordinal: Int
        public let label: String
        public let correct: Bool
    }
    public enum Edit {
        /// Source-compatible ordinal entry, resolved against this captured snapshot.
        case choose(Int)
        case chooseID(String), setMultiple(Bool)
    }

    public let options: [Option]
    public let isMultiple: Bool
    public let isSupported: Bool
    public let canEdit: Bool
    private let fingerprint: Data?

    public init(_ draft: TemplateAdvancedDraft) {
        let fields = draft.value["qa"]?.object
        let rows = fields?["options"]?.array
        func booleanOrMissing(_ value: TemplateAuthoringJSON?) -> Bool {
            guard let value else { return true }
            if case .bool = value { return true }
            return false
        }
        var ids = Set<String>()
        let supported = fields != nil && rows != nil && (rows?.count ?? 0) <= 4 &&
            booleanOrMissing(fields?["multi"]) && (rows ?? []).allSatisfy { row in
                guard let value = row.object, let id = value["id"]?.string,
                      Self.validID(id), ids.insert(id).inserted else { return false }
                return booleanOrMissing(value["correct"]) &&
                    (value["label"] == nil || value["label"]?.string != nil)
            }
        fingerprint = Self.snapshot(draft)
        isSupported = supported && fingerprint != nil
        isMultiple = fields?["multi"]?.bool ?? false
        canEdit = isSupported && fields?["enabled"]?.bool == true && fields?["mode"]?.string == "PICK"
        options = supported ? (rows ?? []).enumerated().map { index, row in
            Option(id: row.object?["id"]?.string ?? "", ordinal: index, label: row.object?["label"]?.string ?? "", correct: row.object?["correct"]?.bool ?? false)
        } : []
    }

    /// A choice from a previous list cannot be applied after a reorder, text change, or mode change.
    public func applying(_ edit: Edit, to draft: TemplateAdvancedDraft) -> TemplateAdvancedDraft? {
        guard canEdit, fingerprint == Self.snapshot(draft),
              var fields = draft.value["qa"]?.object, var rows = fields["options"]?.array else { return nil }
        switch edit {
        case .choose(let index):
            guard options.indices.contains(index) else { return nil }
            return applying(.chooseID(options[index].id), to: draft)
        case .chooseID(let id):
            guard options.contains(where: { $0.id == id }) else { return nil }
            guard rows.allSatisfy({ $0.object != nil }) else { return nil }
            rows = rows.map { raw in
                var row = raw.object!
                if isMultiple {
                    if row["id"]?.string == id { row["correct"] = .bool(!(row["correct"]?.bool ?? false)) }
                } else { row["correct"] = .bool(row["id"]?.string == id) }
                return .object(row)
            }
            fields["options"] = .array(rows)
        case .setMultiple(let enabled):
            fields["multi"] = .bool(enabled)
            if !enabled {
                var kept = false
                guard rows.allSatisfy({ $0.object != nil }) else { return nil }
                fields["options"] = .array(rows.map { raw in
                    var row = raw.object!
                    let correct = (row["correct"]?.bool ?? false) && !kept
                    if correct { kept = true }
                    row["correct"] = .bool(correct)
                    return .object(row)
                })
            }
        }
        var next = draft
        next.value["qa"] = .object(fields)
        return next
    }

    private static func validID(_ id: String) -> Bool {
        (1...64).contains(id.utf8.count) && id.utf8.allSatisfy { byte in
            (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || byte == 95 || byte == 45
        }
    }

    private static func snapshot(_ draft: TemplateAdvancedDraft) -> Data? {
        guard let value = draft.value["qa"] else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try? encoder.encode(value)
    }
}
