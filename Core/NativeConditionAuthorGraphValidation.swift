import Foundation

/// Mirrors only the original author topology checks. Never traverses a live session,
/// chooses an outcome, evaluates facts or applies effects.
enum NativeConditionAuthorGraphValidation {
    static func issues(_ value: ProjectEditJSON, catalog: NativeConditionAuthorCatalog) -> [NativeConditionAuthorIssue] {
        guard let root = value.nativeConditionObject else { return [] }
        let ordinary = (root["edges"]?.nativeConditionArray ?? []).compactMap(\.nativeConditionObject)
        let fallbacks = (root["fallbacks"]?.nativeConditionArray ?? []).compactMap(\.nativeConditionObject)
        let terminals = Set((root["terminalNodeIds"]?.nativeConditionArray ?? []).compactMap(\.nativeConditionInteger))
        let sourceNodes = Set(catalog.nodes.compactMap { Int64($0.id) })
        let gated = Set((root["nodeRequirements"]?.nativeConditionArray ?? []).compactMap { $0.nativeConditionObject?["nodeId"]?.nativeConditionInteger })
        var adjacency: [Int64: Set<Int64>] = [:], outgoing: [Int64: Int] = [:]
        let fallbackSources = Set(fallbacks.compactMap { $0["fromNodeId"]?.nativeConditionInteger })
        var issues: [NativeConditionAuthorIssue] = []
        func fail(_ path: String, _ code: String) { issues.append(.init(path: path, code: code, detail: "")) }
        for row in ordinary + fallbacks {
            if let from = row["fromNodeId"]?.nativeConditionInteger, let to = row["toNodeId"]?.nativeConditionInteger {
                adjacency[from, default: []].insert(to)
            }
        }
        func reachable(_ start: Int64, in graph: [Int64: Set<Int64>]) -> Set<Int64> {
            var seen = Set<Int64>(), pending = [start]
            while let node = pending.popLast() { if seen.insert(node).inserted { pending.append(contentsOf: graph[node] ?? Set<Int64>()) } }
            return seen
        }
        for (i, row) in ordinary.enumerated() {
            guard let from = row["fromNodeId"]?.nativeConditionInteger, let to = row["toNodeId"]?.nativeConditionInteger else { continue }
            let path = "$.edges[\(i)]"
            outgoing[from, default: 0] += 1
            if terminals.contains(from) { fail(path, "terminalOutgoing") }
            if gated.contains(to) && !fallbackSources.contains(from) { fail(path, "requiredFallback") }
            if reachable(to, in: adjacency).contains(from) && (row["allowLoop"] != .bool(true) || (row["maxVisits"]?.nativeConditionInteger ?? 0) <= 0) { fail(path, "loop") }
        }
        for (from, count) in outgoing where count > 1 && !fallbackSources.contains(from) { fail("$.edges", "requiredFallback") }
        for (i, row) in fallbacks.enumerated() {
            guard let from = row["fromNodeId"]?.nativeConditionInteger, let to = row["toNodeId"]?.nativeConditionInteger else { continue }
            let path = "$.fallbacks[\(i)]"
            if terminals.contains(from) { fail(path, "terminalOutgoing") }
            if gated.contains(to) { fail(path, "gatedFallback") }
            if reachable(to, in: adjacency).contains(from) { fail(path, "fallbackLoop") }
        }
        if let start = root["startNodeId"]?.nativeConditionInteger {
            let reached = reachable(start, in: adjacency)
            if !terminals.isSubset(of: reached) || !sourceNodes.isSubset(of: reached) { fail("$", "unreachable") }
            var reverse: [Int64: Set<Int64>] = [:]
            for (from, destinations) in adjacency { for to in destinations { reverse[to, default: []].insert(from) } }
            let reachesEnd = terminals.reduce(into: Set<Int64>()) { $0.formUnion(reachable($1, in: reverse)) }
            if !reached.subtracting(terminals).isSubset(of: reachesEnd) { fail("$", "noTerminalPath") }
        }
        return issues
    }
}
