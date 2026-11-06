import Foundation

public struct NativeConditionAuthorField: Identifiable {
    public enum Input {
        case number, integer, string, strings, node, item, medal, edge, roles, comparator, check, checkResults, condition, equipment
        case variable(string: Bool, writable: Bool)
    }
    public let key: String
    public let input: Input
    public var id: String { key }
    public init(_ key: String, _ input: Input) { self.key = key; self.input = input }
}

public enum NativeConditionAuthorFields {
    public static func fields(operation: String, effect: Bool) -> [NativeConditionAuthorField] {
        if NativeConditionAuthorValidation.comparisons.contains(operation) || ["SET", "INC", "FLOOR"].contains(operation) {
            return [.init("var", .variable(string: false, writable: effect)), .init("value", .number)]
        }
        if ["ADD", "MIN", "MAX"].contains(operation) {
            return [.init("var", .variable(string: false, writable: true)), .init("value", .integer)]
        }
        if ["RESET", "CLAMP"].contains(operation) { return [.init("var", .variable(string: false, writable: true))] }
        switch operation {
        case "EQ_STR", "SET_STR": return [.init("var", .variable(string: true, writable: effect)), .init("value", .string)]
        case "IN": return [.init("var", .variable(string: true, writable: false)), .init("values", .strings)]
        case "HAS_TAG", "ADD_TAG": return [.init("value", .string)]
        case "ITEM_HELD", "ITEM_ACQUIRED", "CONSUME_ITEM", "ADD_ITEM", "REMOVE_ITEM": return [.init("itemId", .item), .init("quantity", .integer)]
        case "GRANT_BADGE": return [.init("badgeId", .medal)]
        case "NODE_COMPLETED", "UNLOCK_NODE": return [.init("nodeId", .node)]
        case "VISIT_COUNT": return [.init("nodeId", .node), .init("comparator", .comparator), .init("value", .integer)]
        case "EDGE_VISITS": return [.init("edgeId", .edge), .init("comparator", .comparator), .init("value", .integer)]
        case "ROLE_IN": return [.init("values", .roles)]
        case "TIME_BETWEEN": return [.init("start", .integer), .init("end", .integer)]
        case "CHECK_RESULT": return [.init("checkId", .check), .init("in", .checkResults)]
        case "HAS_CONDITION": return [.init("value", .condition)]
        case "ITEM_EQUIPPED": return [.init("value", .equipment)]
        default: return []
        }
    }
    /// User explicitly changes operation; unknown extensions survive. Known old fields are
    /// removed only by this explicit action, never on load/preview/save.
    public static func changingOperation(_ original: ProjectEditJSON, to operation: String, effect: Bool) -> ProjectEditJSON {
        let known: Set<String> = ["op", "var", "value", "values", "itemId", "quantity", "badgeId", "scope", "nodeId", "edgeId", "comparator", "start", "end", "children", "child", "choices", "checkId", "in", "type", "payload"]
        var row = (original.nativeConditionObject ?? [:]).filter { !known.contains($0.key) }
        row["op"] = .string(operation)
        switch operation {
        case "ALL_OF", "ANY_OF": row["children"] = .array([])
        case "NOT": row["child"] = .array([])
        case "RANDOM_CHOICE": row["choices"] = .array([])
        case "GRANT_BADGE": row["scope"] = .string("TOPIC_MEDAL")
        case "EMIT_EVENT": row["type"] = .string("CUSTOM"); row["payload"] = .object([:])
        default: break
        }
        return .object(row)
    }
    public static func blank(operation: String, effect: Bool) -> ProjectEditJSON {
        changingOperation(.object([:]), to: operation, effect: effect)
    }
}
