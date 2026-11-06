import Foundation

/// Uses the existing Decimal JSON codec. No second JSON saver or runtime evaluator.
public typealias NativeConditionAuthorJSON = ProjectEditJSON

public extension ProjectEditJSON {
    var nativeConditionObject: [String: Self]? { if case .object(let v) = self { return v }; return nil }
    var nativeConditionArray: [Self]? { if case .array(let v) = self { return v }; return nil }
    var nativeConditionText: String? { if case .string(let v) = self { return v }; return nil }
    var nativeConditionNumber: Decimal? { if case .number(let v) = self { return v }; return nil }
    var nativeConditionInteger: Int64? {
        guard case .number(let v) = self, v >= Decimal(Int64.min), v <= Decimal(Int64.max) else { return nil }
        let n = NSDecimalNumber(decimal: v).int64Value
        return Decimal(n) == v ? n : nil
    }
}

public enum NativeConditionAuthorError: Error, Equatable {
    case invalidJSON, incompatibleVersion, invalidPath, staleEditor, invalidEdit, persistenceFailed
    case blocked([NativeConditionAuthorIssue])
}

public struct NativeConditionAuthorPath: Hashable, Identifiable {
    public enum Component: Hashable { case field(String), index(Int) }
    public var components: [Component]
    public init(_ components: [Component] = []) { self.components = components }
    public var id: String { components.reduce("$") { text, part in
        switch part { case .field(let key): return text + "." + key; case .index(let i): return text + "[\(i)]" }
    } }
    public func field(_ key: String) -> Self { .init(components + [.field(key)]) }
    public func index(_ i: Int) -> Self { .init(components + [.index(i)]) }
}

public enum NativeConditionAuthorTree {
    public static func value(_ root: ProjectEditJSON, at path: NativeConditionAuthorPath) -> ProjectEditJSON? {
        path.components.reduce(Optional(root)) { value, part in
            switch part {
            case .field(let key): return value?.nativeConditionObject?[key]
            case .index(let i): guard let array = value?.nativeConditionArray, array.indices.contains(i) else { return nil }; return array[i]
            }
        }
    }

    /// Every mutation checks its exact preimage; arbitrary paths cannot create missing ancestors.
    public static func replacing(_ root: ProjectEditJSON, at path: NativeConditionAuthorPath,
                                 expected: ProjectEditJSON, with replacement: ProjectEditJSON) throws -> ProjectEditJSON {
        guard exact(value(root, at: path), expected) else { throw NativeConditionAuthorError.staleEditor }
        func replace(_ current: ProjectEditJSON, _ parts: ArraySlice<NativeConditionAuthorPath.Component>) throws -> ProjectEditJSON {
            guard let first = parts.first else { return replacement }
            switch first {
            case .field(let key):
                guard var object = current.nativeConditionObject, let child = object[key] else { throw NativeConditionAuthorError.invalidPath }
                object[key] = try replace(child, parts.dropFirst()); return .object(object)
            case .index(let i):
                guard var array = current.nativeConditionArray, array.indices.contains(i) else { throw NativeConditionAuthorError.invalidPath }
                array[i] = try replace(array[i], parts.dropFirst()); return .array(array)
            }
        }
        return try replace(root, path.components[...])
    }

    public static func exact(_ lhs: ProjectEditJSON?, _ rhs: ProjectEditJSON?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let a = try? encoder.encode(lhs), let b = try? encoder.encode(rhs) else { return false }
        return a == b
    }

    public static func inserting(_ value: ProjectEditJSON, at index: Int, into array: ProjectEditJSON) throws -> ProjectEditJSON {
        guard var values = array.nativeConditionArray, (0...values.count).contains(index) else { throw NativeConditionAuthorError.invalidEdit }
        values.insert(value, at: index); return .array(values)
    }
    public static func removing(_ index: Int, from array: ProjectEditJSON) throws -> ProjectEditJSON {
        guard var values = array.nativeConditionArray, values.indices.contains(index) else { throw NativeConditionAuthorError.invalidEdit }
        values.remove(at: index); return .array(values)
    }
    /// Destination is the final index, shared by touch and accessibility reorder controls.
    public static func moving(_ source: Int, to destination: Int, in array: ProjectEditJSON) throws -> ProjectEditJSON {
        guard var values = array.nativeConditionArray, values.indices.contains(source), values.indices.contains(destination) else { throw NativeConditionAuthorError.invalidEdit }
        let value = values.remove(at: source); values.insert(value, at: destination); return .array(values)
    }

    public struct Row: Identifiable {
        public let path: NativeConditionAuthorPath
        public let depth: Int
        public let value: ProjectEditJSON
        public var id: String { path.id }
        public var operation: String { value.nativeConditionArray != nil ? "ALL_OF_ARRAY" : value.nativeConditionObject?["op"]?.nativeConditionText ?? "UNKNOWN" }
    }
    public static func rows(_ root: ProjectEditJSON, at path: NativeConditionAuthorPath = .init()) -> [Row] {
        guard let value = value(root, at: path) else { return [] }
        var result: [Row] = []
        func visit(_ value: ProjectEditJSON, _ path: NativeConditionAuthorPath, _ depth: Int) {
            guard depth <= 40, result.count < 4096 else { return }
            result.append(.init(path: path, depth: depth, value: value))
            if let array = value.nativeConditionArray {
                for (i, child) in array.enumerated() { visit(child, path.index(i), depth + 1) }
            } else if let object = value.nativeConditionObject {
                switch object["op"]?.nativeConditionText {
                case "ALL_OF", "ANY_OF":
                    for (i, child) in (object["children"]?.nativeConditionArray ?? []).enumerated() { visit(child, path.field("children").index(i), depth + 1) }
                case "NOT": if let child = object["child"] { visit(child, path.field("child"), depth + 1) }
                case "RANDOM_CHOICE":
                    for (i, choice) in (object["choices"]?.nativeConditionArray ?? []).enumerated() {
                        if let effects = choice.nativeConditionObject?["effects"] { visit(effects, path.field("choices").index(i).field("effects"), depth + 1) }
                    }
                default: break
                }
            }
        }
        visit(value, path, 0); return result
    }
}

public struct NativeConditionAuthorScope: Equatable, Hashable {
    public let accountID: Int
    public let namespace: Data
    public let epoch: UInt64
    public let authorizationRevision: Data
    public let documentIdentity: Data
    public let sourceRevision: Data
    public let incarnation: UUID
    public init(accountID: Int, namespace: String, epoch: UInt64, authorizationRevision: String,
                documentIdentity: String, sourceRevision: String, incarnation: UUID) {
        self.accountID = accountID; self.namespace = Data(namespace.utf8); self.epoch = epoch
        self.authorizationRevision = Data(authorizationRevision.utf8); self.documentIdentity = Data(documentIdentity.utf8)
        self.sourceRevision = Data(sourceRevision.utf8); self.incarnation = incarnation
    }
}

/// A transient projection of the attribute owner's definitions, never a registry or initializer.
public struct NativeConditionAuthorAttributeReference: Equatable, Identifiable {
    public enum ValueType: String { case number, string }
    public let key: String
    public let label: String
    public let type: ValueType
    public let writable: Bool
    public var id: String { key }
    public init(key: String, label: String, type: ValueType, writable: Bool) {
        self.key = key; self.label = label; self.type = type; self.writable = writable
    }
}
public struct NativeConditionAuthorAttributeProjection: Equatable {
    public enum Origin: Equatable { case currentDefinition, publishedDefinition }
    public let scope: NativeConditionAuthorScope
    public let definitionVersion: String
    public let origin: Origin
    public let references: [NativeConditionAuthorAttributeReference]
    public init(scope: NativeConditionAuthorScope, definitionVersion: String, origin: Origin,
                references: [NativeConditionAuthorAttributeReference]) {
        self.scope = scope; self.definitionVersion = definitionVersion; self.origin = origin; self.references = references
    }
}
@MainActor public protocol NativeConditionAuthorAttributePicking: AnyObject {
    func references(for scope: NativeConditionAuthorScope) -> NativeConditionAuthorAttributeProjection?
}

public struct NativeConditionAuthorOption: Identifiable, Equatable {
    public let id: String
    public let label: String
    public init(id: String, label: String) { self.id = id; self.label = label }
}
public struct NativeConditionAuthorCatalog: Equatable {
    public var nodes: [NativeConditionAuthorOption]
    public var items: [NativeConditionAuthorOption]
    public var medals: [NativeConditionAuthorOption]
    /// Original route edge IDs, supplied by the same author source, not inferred from nodes.
    public var edges: [NativeConditionAuthorOption]
    /// Original author source's trigger/outcome values. No locally invented trigger codes.
    public var triggers: [NativeConditionAuthorOption]
    public var outcomes: [NativeConditionAuthorOption]
    /// Read-only declaration projection from the original RPG author binding, including
    /// sys.party.size/environment/visit-related keys only when that binding declares them.
    public var numericFacts: [NativeConditionAuthorOption]
    public var rpg: NativeConditionAuthorRPGProjection?
    public var component: NativeComponentAuthorBinding? = nil
    public var sourceOutcomes: [String: [NativeConditionAuthorDeclaredOutcome]]
    public init(nodes: [NativeConditionAuthorOption], items: [NativeConditionAuthorOption], medals: [NativeConditionAuthorOption],
                triggers: [NativeConditionAuthorOption], outcomes: [NativeConditionAuthorOption],
                numericFacts: [NativeConditionAuthorOption] = [], rpg: NativeConditionAuthorRPGProjection? = nil,
                sourceOutcomes: [String: [NativeConditionAuthorDeclaredOutcome]] = [:],
                edges: [NativeConditionAuthorOption] = []) {
        self.nodes = nodes; self.items = items; self.medals = medals; self.triggers = triggers; self.outcomes = outcomes
        self.numericFacts = numericFacts; self.rpg = rpg
        self.sourceOutcomes = sourceOutcomes; self.edges = edges
    }
}

public struct NativeConditionAuthorDeclaredOutcome: Equatable {
    public let triggerType: String
    public let code: String
    public let label: String
    public init(triggerType: String, code: String, label: String) { self.triggerType = triggerType; self.code = code; self.label = label }
}

/// Immutable reference projection from the original RouteFactRegistry/RpgDefinitions.
/// No client registration API, evaluator, runtime values or independent persisted registry.
public struct NativeConditionAuthorRPGProjection: Equatable {
    public let scope: NativeConditionAuthorScope
    public let definitionVersion: String
    public let supportedOperations: Set<String>
    public let checks: [NativeConditionAuthorOption]
    public let checkResults: [NativeConditionAuthorOption]
    public let conditions: [NativeConditionAuthorOption]
    public let equipment: [NativeConditionAuthorOption]
    public init(scope: NativeConditionAuthorScope, definitionVersion: String, supportedOperations: Set<String>,
                checks: [NativeConditionAuthorOption], checkResults: [NativeConditionAuthorOption],
                conditions: [NativeConditionAuthorOption], equipment: [NativeConditionAuthorOption]) {
        self.scope = scope; self.definitionVersion = definitionVersion; self.supportedOperations = supportedOperations
        self.checks = checks; self.checkResults = checkResults; self.conditions = conditions; self.equipment = equipment
    }
}

public struct NativeConditionAuthorIssue: Equatable, Identifiable {
    public let path: String
    public let code: String
    public let detail: String
    public var id: String { path + ":" + code }
    public init(path: String, code: String, detail: String) { self.path = path; self.code = code; self.detail = detail }
}

public struct NativeConditionAuthorDocument {
    public enum Surface: Equatable { case routeGraph, attributeCondition, templateCondition, templateEffects, componentCondition, componentEffects, componentCheck }
    public let original: String
    public let originalValue: ProjectEditJSON
    public private(set) var value: ProjectEditJSON
    public let surface: Surface
    public let scope: NativeConditionAuthorScope
    public let canRoundTrip: Bool
    private let sourceVersionCompatible: Bool
    public private(set) var revision: UInt64 = 0
    public init(raw: String, surface: Surface, scope: NativeConditionAuthorScope) throws {
        guard raw.utf8.count <= 2 * 1024 * 1024,
              let value = try? JSONDecoder().decode(ProjectEditJSON.self, from: Data(raw.utf8)) else { throw NativeConditionAuthorError.invalidJSON }
        self.original = raw; self.originalValue = value; self.value = value; self.surface = surface; self.scope = scope
        sourceVersionCompatible = surface != .routeGraph || NativeConditionAuthorVersion.hasExplicitV2(raw)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let roundTrip = String(decoding: try encoder.encode(value), as: UTF8.self)
        // Reuse the host's strict JSON parser, including exact key/number handling.
        // A future payload the shared codec cannot represent remains readable as its original text.
        self.canRoundTrip = (try? ContentDraftJSON.parse(raw)) == (try? ContentDraftJSON.parse(roundTrip)) &&
            (try? ContentDraftJSON.parse(raw)) != nil
    }
    public var isExplicitV2: Bool {
        surface == .routeGraph && sourceVersionCompatible && value.nativeConditionObject?["schemaVersion"]?.nativeConditionInteger == 1 &&
        value.nativeConditionObject?["routeExpressionVersion"]?.nativeConditionInteger == 2
    }
    public var hasChanges: Bool { !NativeConditionAuthorTree.exact(originalValue, value) }
    public mutating func replace(at path: NativeConditionAuthorPath, expected: ProjectEditJSON,
                                 with replacement: ProjectEditJSON, revision: UInt64) throws {
        guard self.revision == revision else { throw NativeConditionAuthorError.staleEditor }
        guard canRoundTrip else { throw NativeConditionAuthorError.invalidJSON }
        if surface == .routeGraph && !isExplicitV2 { throw NativeConditionAuthorError.incompatibleVersion }
        value = try NativeConditionAuthorTree.replacing(value, at: path, expected: expected, with: replacement)
        self.revision &+= 1
    }
    public func serialized() throws -> String {
        if !hasChanges { return original }
        guard canRoundTrip else { throw NativeConditionAuthorError.invalidJSON }
        if surface == .routeGraph && !isExplicitV2 { throw NativeConditionAuthorError.incompatibleVersion }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
