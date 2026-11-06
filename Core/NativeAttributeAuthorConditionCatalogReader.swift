import Foundation

/// Exact private-source identity captured by the same original Project editor.
/// Used only for42 attribute rules.when, not41's full route trigger/outcome catalog.
public struct NativeAttributeAuthorConditionCatalogSource: Equatable {
    public let binding: NativeAttributeAuthorBinding
    public let scope: NativeConditionAuthorScope
    public let baseRevision: String
    public init(binding: NativeAttributeAuthorBinding, scope: NativeConditionAuthorScope, baseRevision: String) {
        self.binding = binding; self.scope = scope; self.baseRevision = baseRevision
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.binding == rhs.binding && lhs.scope == rhs.scope && lhs.baseRevision.utf8.elementsEqual(rhs.baseRevision.utf8)
    }
}

/// Read-only projection over the original approved POST api/topic/edit-detail. No alternate
/// API, registry, permission, request journal, or write receipt is created here.
@MainActor public final class NativeAttributeAuthorConditionCatalogReader {
    private let service: ProjectEditHTTPService
    private let currentSession: () -> ProjectEditSession?
    private let currentSource: () -> NativeAttributeAuthorConditionCatalogSource?
    private var generation = UUID()
    private var cached: (NativeAttributeAuthorConditionCatalogSource, NativeConditionAuthorCatalog)?
    public init(service: ProjectEditHTTPService, currentSession: @escaping () -> ProjectEditSession?,
                currentSource: @escaping () -> NativeAttributeAuthorConditionCatalogSource?) {
        self.service = service; self.currentSession = currentSession; self.currentSource = currentSource
    }
    public func refresh() async throws {
        generation = UUID(); let ticket = generation; cached = nil
        guard let source = currentSource(), !source.binding.isLocked, !source.baseRevision.isEmpty,
              let session = currentSession(), Self.matches(source, session: session),
              let topicID = Int(exactly: source.binding.topicID) else { throw NativeAttributeAuthorError.staleSource }
        try Task.checkCancellation()
        let readback = try await service.readOriginalAuthorDetail(topicID: topicID, session: session)
        guard !Task.isCancelled, generation == ticket, currentSource() == source, currentSession() == session,
              readback.session == session, readback.snapshot.topicID == topicID,
              readback.snapshot.draft.baseRevision.utf8.elementsEqual(source.baseRevision.utf8),
              readback.server.absoluteString.utf8.elementsEqual(source.binding.server.utf8),
              readback.owner.rawValue.utf8.elementsEqual(source.binding.requestScope.utf8) else {
            throw NativeAttributeAuthorError.staleSource
        }
        let projection = try Self.project(readback.raw, binding: source.binding)
        guard !Task.isCancelled, generation == ticket, currentSource() == source, currentSession() == session else {
            throw NativeAttributeAuthorError.staleSource
        }
        cached = (source, projection)
    }
    public func attributeRuleCatalog(for scope: NativeConditionAuthorScope) -> NativeConditionAuthorCatalog? {
        guard let value = cached else { return nil }
        guard currentSource() == value.0, let session = currentSession(), Self.matches(value.0, session: session) else {
            cached = nil; return nil
        }
        guard value.0.scope == scope else { return nil }
        return value.1
    }
    public func retire() { generation = UUID(); cached = nil }
    private static func matches(_ source: NativeAttributeAuthorConditionCatalogSource, session: ProjectEditSession) -> Bool {
        let binding = source.binding, scope = source.scope
        guard let topicID = Int(exactly: binding.topicID), let identity = try? ProjectEditDraftIdentity(topicID: topicID) else { return false }
        return Int64(session.accountID) == binding.accountID && session.epoch == binding.epoch &&
            session.storageNamespace.utf8.elementsEqual(binding.namespace.utf8) &&
            "\(session.viewerRevision):\(session.configurationRevision)".utf8.elementsEqual(binding.authorizationRevision.utf8) &&
            scope.accountID == session.accountID && scope.epoch == session.epoch &&
            scope.namespace == Data(session.storageNamespace.utf8) &&
            scope.authorizationRevision == Data(binding.authorizationRevision.utf8) &&
            scope.documentIdentity == Data(identity.bucket.utf8)
    }
    static func project(_ data: Data, binding: NativeAttributeAuthorBinding) throws -> NativeConditionAuthorCatalog {
        let root = try NativeAttributeAuthorWire.decode(data)
        guard root.object?["code"]?.integer == 200, let body = root.object?["data"]?.object,
              let topic = body["topic"]?.object, let topicID = topic["id"]?.integer, Int64(topicID) == binding.topicID,
              let version = topic["configVersion"]?.integer, Int64(version) == binding.sourceConfigVersion,
              let chapters = body["chapters"]?.array,
              let rawTheme = body["themeRuntimeConfig"], let rawGraph = topic["routeGraphJson"] else {
            throw NativeAttributeAuthorError.contractMissing("original complete attribute condition catalog")
        }
        let numbers = try NativeAttributeAuthorWire.numberSpellings(data, beneath: [])
        guard numbers[["data","topic","id"]] == String(topicID),
              numbers[["data","topic","configVersion"]] == String(version) else {
            throw NativeAttributeAuthorError.invalid("original catalog integer identity")
        }
        var seenNodes = Set<Int>(), nodes: [NativeConditionAuthorOption] = []
        for (ci, chapter) in chapters.enumerated() {
            guard let fields = chapter.object, let rows = fields["cmsTopicNodeList"]?.array else {
                throw NativeAttributeAuthorError.invalid("original chapter node source")
            }
            for (ni, row) in rows.enumerated() {
                guard let node = row.object, let id = node["id"]?.integer, id > 0, seenNodes.insert(id).inserted,
                      numbers[["data","chapters",String(ci),"cmsTopicNodeList",String(ni),"id"]] == String(id) else {
                    throw NativeAttributeAuthorError.invalid("original node identity")
                }
                if let owner = node["topicId"], owner != .null {
                    guard owner.integer == topicID,
                          numbers[["data","chapters",String(ci),"cmsTopicNodeList",String(ni),"topicId"]] == String(topicID) else {
                        throw NativeAttributeAuthorError.invalid("foreign node source")
                    }
                }
                let label = try optionalLabel(node, "name", fallback: String(id))
                nodes.append(.init(id: String(id), label: label))
            }
        }
        let theme = try originalObject(rawTheme)
        if let theme {
            guard theme["schemaVersion"]?.integer == 1 else { throw NativeAttributeAuthorError.invalid("theme catalog schema") }
            guard let text = rawTheme.text,
                  try NativeAttributeAuthorWire.numberSpellings(Data(text.utf8), beneath: [])[["schemaVersion"]] == "1" else {
                throw NativeAttributeAuthorError.invalid("theme catalog version token")
            }
        }
        var items: [NativeConditionAuthorOption] = [], medals: [NativeConditionAuthorOption] = [], seenItems = Set<Data>()
        // Original ThemeRuntimeConfig.rows explicitly treats missing/null items as empty.
        let itemRows = try optionalRows(theme?["items"])
        guard itemRows.count <= 200 else { throw NativeAttributeAuthorError.invalid("original item catalog limit") }
        for row in itemRows {
            guard let item = row.object, let id = item["id"]?.text,
                  id.range(of: "^[a-z][a-z0-9_]{0,31}$(?![\\s\\S])", options: .regularExpression) != nil,
                  !id.hasPrefix("legacy_"), seenItems.insert(Data(id.utf8)).inserted,
                  let kind = item["kind"]?.text, ["ITEM","MEDAL"].contains(kind) else {
                throw NativeAttributeAuthorError.invalid("original theme item identity")
            }
            let option = NativeConditionAuthorOption(id: id, label: try optionalLabel(item, "name", fallback: id))
            if kind == "ITEM" { items.append(option) } else { medals.append(option) }
        }
        let graph = try originalObject(rawGraph)
        var edges: [NativeConditionAuthorOption] = [], seenEdges = Set<Data>()
        let graphNumbers: [[String]: String]
        if graph != nil, let text = rawGraph.text {
            graphNumbers = try NativeAttributeAuthorWire.numberSpellings(Data(text.utf8), beneath: [])
        } else { graphNumbers = [:] }
        for field in ["edges","fallbacks"] {
            for (index, row) in try optionalRows(graph?[field]).enumerated() {
                guard let fields = row.object else { throw NativeAttributeAuthorError.invalid("original edge source") }
                let id: String
                if let explicit = fields["id"] {
                    guard let text = explicit.text, !text.isEmpty else { throw NativeAttributeAuthorError.invalid("original edge id") }
                    id = text
                } else if field == "fallbacks", let from = fields["fromNodeId"]?.integer, from > 0,
                          graphNumbers[[field,String(index),"fromNodeId"]] == String(from) {
                    // Exact original RouteConditionSchema.fromConfig fallback identity.
                    id = "fallback-\(from)"
                } else { throw NativeAttributeAuthorError.invalid("original edge id") }
                guard seenEdges.insert(Data(id.utf8)).inserted else { throw NativeAttributeAuthorError.invalid("duplicate edge id") }
                edges.append(.init(id: id, label: id))
            }
        }
        // These are intentionally not a full41 route-author catalog. The current original
        // attribute-author context has no RPG registry, trigger/outcome producer, or runtime facts.
        return .init(nodes: nodes, items: items, medals: medals, triggers: [], outcomes: [], edges: edges)
    }
    private static func originalObject(_ value: ProjectEditJSON) throws -> [String: ProjectEditJSON]? {
        if value == .null { return nil }
        guard let text = value.text else { throw NativeAttributeAuthorError.invalid("original catalog JSON text") }
        if text.unicodeScalars.allSatisfy({ $0.value <= 32 }) { return nil }
        guard let object = try NativeAttributeAuthorWire.decode(Data(text.utf8)).object else {
            throw NativeAttributeAuthorError.invalid("original catalog JSON object")
        }
        return object
    }
    private static func optionalRows(_ value: ProjectEditJSON?) throws -> [ProjectEditJSON] {
        guard let value, value != .null else { return [] }
        guard let rows = value.array else { throw NativeAttributeAuthorError.invalid("original catalog array") }
        return rows
    }
    private static func optionalLabel(_ fields: [String: ProjectEditJSON], _ key: String, fallback: String) throws -> String {
        guard let value = fields[key] else { return fallback }
        guard let text = value.text else { throw NativeAttributeAuthorError.invalid("original catalog label") }
        return text.isEmpty ? fallback : text
    }
}
