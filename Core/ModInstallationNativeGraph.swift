import Foundation

/// Owner-only structural preview of the existing native branch contract, never a runtime simulator.
public struct ModInstallationNativeGraph: Equatable {
    public struct Option: Decodable, Equatable, Identifiable { public let id, label, nextStepId: String }
    public struct Step: Decodable, Equatable, Identifiable {
        public let id, title, body: String
        public let terminal: Bool
        public let outcomeCode, outcomeLabel: String?
        public let options: [Option]
    }
    private struct Root: Decodable { let schemaVersion: Int; let branch: Branch }
    private struct Branch: Decodable { let enabled: Bool; let startStepId: String; let steps: [Step] }
    public let startStepId: String
    public let steps: [Step]
    public init(json: String, allowSingleTerminal: Bool = false) throws {
        guard json.utf8.count <= 65536 else { throw ModInstallationIssue.malformed }
        _ = try ContentDraftJSON.parse(json) // Reject duplicate keys before Foundation/Decodable can discard one.
        guard let root = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              Set(root.keys) == ["schemaVersion", "branch"],
              let branch = root["branch"] as? [String: Any], Set(branch.keys) == ["enabled", "startStepId", "steps"],
              let rows = branch["steps"] as? [[String: Any]], ((allowSingleTerminal ? 1 : 2)...50).contains(rows.count) else { throw ModInstallationIssue.malformed }
        for row in rows {
            let required: Set<String> = ["id", "title", "body", "terminal", "options"]
            guard required.isSubset(of: Set(row.keys)), Set(row.keys).isSubset(of: required.union(["outcomeCode", "outcomeLabel"])),
                  let options = row["options"] as? [[String: Any]], options.count <= 12,
                  options.allSatisfy({ Set($0.keys) == ["id", "label", "nextStepId"] }) else { throw ModInstallationIssue.malformed }
        }
        let decoded = try JSONDecoder().decode(Root.self, from: Data(json.utf8))
        guard decoded.schemaVersion == 1, decoded.branch.enabled else { throw ModInstallationIssue.malformed }
        let graph = decoded.branch
        let ids = Set(graph.steps.map(\.id))
        guard ids.count == graph.steps.count, ids.contains(graph.startStepId) else { throw ModInstallationIssue.malformed }
        for step in graph.steps {
            try Self.identifier(step.id)
            guard step.title.utf16.count <= 80, step.body.utf16.count <= 1000,
                  (step.terminal ? step.options.isEmpty : !step.options.isEmpty),
                  Set(step.options.map(\.id)).count == step.options.count else { throw ModInstallationIssue.malformed }
            if step.terminal { guard let code = step.outcomeCode else { throw ModInstallationIssue.malformed }; try Self.identifier(code) }
            for option in step.options {
                try Self.identifier(option.id)
                guard !option.label.isEmpty, option.label.utf16.count <= 80, ids.contains(option.nextStepId) else { throw ModInstallationIssue.malformed }
            }
        }
        let indexed = Dictionary(uniqueKeysWithValues: graph.steps.map { ($0.id, $0) })
        var visiting = Set<String>(), visited = Set<String>()
        func visit(_ id: String) throws {
            guard !visiting.contains(id), let step = indexed[id] else { throw ModInstallationIssue.malformed }
            if visited.contains(id) { return }
            visiting.insert(id)
            for option in step.options { try visit(option.nextStepId) }
            visiting.remove(id); visited.insert(id)
        }
        try visit(graph.startStepId)
        guard visited == ids, graph.steps.contains(where: \.terminal) else { throw ModInstallationIssue.malformed }
        startStepId = graph.startStepId; steps = graph.steps
    }
    private static func identifier(_ value: String) throws {
        guard value.range(of: "\\A[A-Za-z0-9_-]{1,64}\\z", options: .regularExpression) != nil else { throw ModInstallationIssue.malformed }
    }
}
