import Foundation

/// Author-only preview of the R2 qa.PICK text carrier. Never used as a player result or answer judge.
public struct ModInstallationQaPick: Equatable {
    public struct Option: Decodable, Equatable, Identifiable {
        public let id, label: String
        public let correct: Bool
        public let fb: String?
    }
    private struct Configuration: Decodable { let schemaVersion: Int; let qa: Question }
    private struct Question: Decodable {
        let enabled: Bool; let mode, title: String; let options: [Option]
        let xp, maxTries: Int?; let lead: String?; let multi: Bool?
    }
    public let title, lead: String
    public let maxTries: Int
    public let multi: Bool
    public let options: [Option]
    public init(json: String) throws {
        guard json.utf8.count <= 65536 else { throw ModInstallationIssue.malformed }
        _ = try ContentDraftJSON.parse(json)
        guard let root = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              Set(root.keys) == ["schemaVersion", "qa"], let qa = root["qa"] as? [String: Any],
              Set(qa.keys).isSuperset(of: ["enabled", "mode", "title", "options"]),
              Set(qa.keys).isSubset(of: ["enabled", "mode", "title", "options", "xp", "lead", "maxTries", "multi"]),
              let rows = qa["options"] as? [[String: Any]], rows.allSatisfy({
                  Set($0.keys).isSuperset(of: ["id", "label", "correct"]) && Set($0.keys).isSubset(of: ["id", "label", "correct", "fb"])
              }) else { throw ModInstallationIssue.malformed }
        let decoded = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8)), question = decoded.qa
        guard decoded.schemaVersion == 1, question.enabled, question.mode == "PICK", (question.xp ?? 0) == 0,
              (0...10).contains(question.maxTries ?? 0), (2...4).contains(question.options.count),
              Set(question.options.map(\.id)).count == question.options.count else { throw ModInstallationIssue.malformed }
        try Self.text(question.title, limit: 120)
        if let lead = question.lead { try Self.text(lead, limit: 60, allowsEmpty: true) }
        for option in question.options {
            guard option.id.range(of: "\\A[A-Za-z0-9_-]{1,32}\\z", options: .regularExpression) != nil else { throw ModInstallationIssue.malformed }
            try Self.text(option.label, limit: 32)
            if let feedback = option.fb { try Self.text(feedback, limit: 120, allowsEmpty: true) }
        }
        let count = question.options.filter(\.correct).count, multi = question.multi ?? false
        guard multi ? count >= 2 && count < question.options.count : count == 1 else { throw ModInstallationIssue.malformed }
        title = question.title; lead = question.lead ?? ""; maxTries = question.maxTries ?? 0
        self.multi = multi; options = question.options
    }
    private static func text(_ value: String, limit: Int, allowsEmpty: Bool = false) throws {
        guard value.utf16.count <= limit, !value.contains("{{") else { throw ModInstallationIssue.malformed }
        if value.isEmpty && allowsEmpty { return }
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !value.unicodeScalars.allSatisfy({ $0.value <= 32 }) else { throw ModInstallationIssue.malformed }
    }
}
