import Foundation

public enum NativeAttributeAuthorError: Error, Equatable {
    case unavailable(String), invalid(String), contractMissing(String), staleSource, storage, uncertain, rejected(String)
    case mixedBatch, unconfirmedResponse(Data), versionConflict(String)
}

/// Source identity comes from the original authorized project read. No login flag grants access.
public struct NativeAttributeAuthorBinding: Codable, Equatable {
    public enum Source: Codable, Equatable {
        case current
        case locked(definitionVersion: Int64, sourceConfigVersion: Int64, sha256: String)
    }
    public let server: String
    public let namespace: String
    public let accountID: Int64
    public let epoch: UInt64
    public let authorizationRevision: String
    public let topicID: Int64
    public let sourceConfigVersion: Int64
    public let requestScope: String
    public let source: Source

    public init(server: String, namespace: String, accountID: Int64, epoch: UInt64,
                authorizationRevision: String, topicID: Int64, sourceConfigVersion: Int64,
                requestScope: String, source: Source = .current) throws {
        guard let url = URL(string: server), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              !namespace.isEmpty, accountID > 0, !authorizationRevision.isEmpty,
              topicID > 0, sourceConfigVersion >= 0, ["", "MERCHANT"].contains(requestScope) else {
            throw NativeAttributeAuthorError.invalid("authorBinding")
        }
        if case .locked(let version, let provenance, let digest) = source {
            guard version > 0, provenance == sourceConfigVersion,
                  digest.range(of: "^[a-f0-9]{64}$(?![\\s\\S])", options: .regularExpression) != nil else {
                throw NativeAttributeAuthorError.invalid("dynamicAttributes.definitionVersion/sourceConfigVersion/sha256")
            }
        }
        self.server = server; self.namespace = namespace; self.accountID = accountID; self.epoch = epoch
        self.authorizationRevision = authorizationRevision; self.topicID = topicID
        self.sourceConfigVersion = sourceConfigVersion; self.requestScope = requestScope; self.source = source
    }
    public var isLocked: Bool { if case .locked = source { return true }; return false }
    func currentVersion(_ version: Int64) throws -> Self {
        guard !isLocked else { throw NativeAttributeAuthorError.staleSource }
        return try .init(server: server, namespace: namespace, accountID: accountID, epoch: epoch,
            authorizationRevision: authorizationRevision, topicID: topicID, sourceConfigVersion: version,
            requestScope: requestScope)
    }
    /// Durable owner key deliberately excludes the ephemeral login epoch. Restores never replay a request.
    public var storageKey: String {
        let components = [server, namespace, String(accountID), String(topicID), requestScope]
        return "native-attribute-author.v1." + Data(components.map { "\($0.utf8.count):\($0)" }.joined().utf8).base64EncodedString()
    }
    public static func == (a: Self, b: Self) -> Bool {
        a.accountID == b.accountID && a.epoch == b.epoch && a.topicID == b.topicID &&
        a.sourceConfigVersion == b.sourceConfigVersion && a.source == b.source &&
        zip([a.server,a.namespace,a.authorizationRevision,a.requestScope],
            [b.server,b.namespace,b.authorizationRevision,b.requestScope]).allSatisfy { pair in pair.0.utf8.elementsEqual(pair.1.utf8) }
    }
}

/// Strict envelope decoding reuses the host's lossless JSON parser. Integer token spelling is
/// checked before Decimal decoding: Jackson rejects 1.0 and 1e0 in integer definition fields.
enum NativeAttributeAuthorWire {
    static func decode(_ data: Data) throws -> ProjectEditJSON {
        guard data.count <= 2 * 1024 * 1024, let text = String(data: data, encoding: .utf8) else {
            throw NativeAttributeAuthorError.invalid("JSON")
        }
        let lossless = try ContentDraftJSON.parse(text)
        let value = try JSONDecoder().decode(ProjectEditJSON.self, from: data)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard try ContentDraftJSON.parse(String(decoding: encoder.encode(value), as: UTF8.self)) == lossless else {
            throw NativeAttributeAuthorError.invalid("JSON exact keys/numbers")
        }
        var tokens = IntegerTokens(bytes: Array(text.utf8)); try tokens.value(path: [])
        return value
    }
    static func encode(_ value: ProjectEditJSON) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    static func same(_ lhs: ProjectEditJSON, _ rhs: ProjectEditJSON) -> Bool {
        guard let a = try? encode(lhs), let b = try? encode(rhs),
              let parsedA = try? ContentDraftJSON.parse(String(decoding: a, as: UTF8.self)),
              let parsedB = try? ContentDraftJSON.parse(String(decoding: b, as: UTF8.self)) else { return false }
        return parsedA == parsedB
    }
    static func sameOptional(_ lhs: ProjectEditJSON?, _ rhs: ProjectEditJSON?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case (.some(let a), .some(let b)): return same(a, b)
        default: return false
        }
    }
    static func fragment(_ data: Data, at path: [String]) throws -> Data {
        guard let text = String(data: data, encoding: .utf8) else { throw NativeAttributeAuthorError.invalid("JSON UTF8") }
        _ = try ContentDraftJSON.parse(text)
        var scanner = IntegerTokens(bytes: Array(data)); try scanner.value(path: [])
        guard let range = scanner.ranges[path] else { throw NativeAttributeAuthorError.invalid("JSON source path") }
        return data.subdata(in: range)
    }
    static func numberSpellings(_ data: Data, beneath path: [String]) throws -> [[String]: String] {
        guard let text = String(data: data, encoding: .utf8) else { throw NativeAttributeAuthorError.invalid("JSON UTF8") }
        _ = try ContentDraftJSON.parse(text)
        var scanner = IntegerTokens(bytes: Array(data)); try scanner.value(path: [])
        return Dictionary(uniqueKeysWithValues: scanner.numbers.compactMap { key, value in
            guard key.starts(with: path) else { return nil }
            return (Array(key.dropFirst(path.count)), value)
        })
    }
    static func replacing(_ data: Data, fragments: [([String], Data)]) throws -> Data {
        guard let text = String(data: data, encoding: .utf8) else { throw NativeAttributeAuthorError.invalid("JSON UTF8") }
        _ = try ContentDraftJSON.parse(text)
        var scanner = IntegerTokens(bytes: Array(data)); try scanner.value(path: [])
        let edits = try fragments.map { path, fragment -> (Range<Int>, Data) in
            _ = try decode(fragment)
            guard let range = scanner.ranges[path] else { throw NativeAttributeAuthorError.invalid("JSON replacement path") }
            return (range, fragment)
        }.sorted { $0.0.lowerBound > $1.0.lowerBound }
        var result = data, previous = data.count
        for (range, fragment) in edits {
            guard range.upperBound <= previous else { throw NativeAttributeAuthorError.invalid("overlapping JSON fragments") }
            result.replaceSubrange(range, with: fragment); previous = range.lowerBound
        }
        _ = try decode(result); return result
    }
    private struct IntegerTokens {
        let bytes: [UInt8]; var index = 0
        var ranges: [[String]: Range<Int>] = [:]
        var numbers: [[String]: String] = [:]
        mutating func space() { while index < bytes.count && [9,10,13,32].contains(bytes[index]) { index += 1 } }
        mutating func string() throws -> String {
            let start = index; index += 1
            while index < bytes.count {
                let c = bytes[index]; index += 1
                if c == 92 { index += 1 }
                else if c == 34 { return try JSONDecoder().decode(String.self, from: Data(bytes[start..<index])) }
            }
            throw NativeAttributeAuthorError.invalid("JSON string")
        }
        mutating func value(path: [String], location: [String] = []) throws {
            space(); guard index < bytes.count else { throw NativeAttributeAuthorError.invalid("JSON token") }
            let start = index
            defer { ranges[location] = start..<index }
            switch bytes[index] {
            case 123:
                index += 1; space(); if bytes[index] == 125 { index += 1; return }
                while true {
                    space(); let key = try string(); space(); index += 1
                    try value(path: path + [key], location: location + [key]); space()
                    if bytes[index] == 125 { index += 1; return }; index += 1
                }
            case 91:
                index += 1; space(); if bytes[index] == 93 { index += 1; return }
                var element = 0
                while true {
                    try value(path: path + ["[]"], location: location + [String(element)]); element += 1; space()
                    if bytes[index] == 93 { index += 1; return }; index += 1
                }
            case 34: _ = try string()
            default:
                let start = index
                while index < bytes.count && ![9,10,13,32,44,93,125].contains(bytes[index]) { index += 1 }
                if bytes[start] == 45 || (48...57).contains(bytes[start]) {
                    numbers[location] = String(decoding: bytes[start..<index], as: UTF8.self)
                }
                if let key = path.last, integerField(path) {
                    let token = String(decoding: bytes[start..<index], as: UTF8.self)
                    if token == "null" && key != "value" { return }
                    guard token.range(of: "^-?[0-9]+$(?![\\s\\S])", options: .regularExpression) != nil else {
                        throw NativeAttributeAuthorError.invalid(path.joined(separator: "."))
                    }
                }
            }
        }
        private func integerField(_ path: [String]) -> Bool {
            guard let field = path.last else { return false }
            if path.count == 1 && ["code","schemaVersion","definitionVersion","sourceConfigVersion","expectedConfigVersion","topicId","configVersion"].contains(field) { return true }
            if path == ["data","topicId"] || path == ["data","configVersion"] ||
                path == ["data","issues","[]","nodeId"] || path == ["issues","[]","nodeId"] { return true }
            if ["initialValue","minValue","maxValue","sortOrder"].contains(field), rowPath(Array(path.dropLast())) { return true }
            return field == "value" && path.suffix(3).elementsEqual(["rules","[]","value"]) && rowPath(Array(path.dropLast(3)))
        }
        private func rowPath(_ path: [String]) -> Bool {
            [["[]"],["data","[]"],["definitions","[]"],["keys","[]"],["data","definitions","[]"]].contains(path)
        }
    }
}

public struct NativeAttributeAuthorRule: Codable, Equatable, Identifiable {
    public let id: UUID
    public var event: String
    public var operation: String
    public var value: String
    public var condition: ProjectEditJSON?
    public let original: [String: ProjectEditJSON]
    let sourceIndex: Int?
    public static let events = ["SESSION_START","NODE_ENTER","NODE_COMPLETE","CHECK_ROLL","CHECK_SUCCESS","CHECK_FAIL",
        "CHECK_STRONG_SUCCESS","CHECK_NEAR_MISS","CHECK_FUMBLE","ITEM_GET","ITEM_LOSE","WEATHER_CHANGE","TIME_TICK","LEVEL_UP","CUSTOM"]
    public static let operations = ["ADD","SET","MIN","MAX","CLAMP","RESET"]
    public var needsValue: Bool { ["ADD","SET","MIN","MAX"].contains(operation) }
    public func duplicate() -> Self {
        Self(copying: self)
    }
    private init(copying other: Self) {
        id = UUID(); event = other.event; operation = other.operation; value = other.value
        condition = other.condition; original = other.original; sourceIndex = other.sourceIndex
    }
    public init(event: String = "CHECK_FAIL", operation: String = "ADD", value: String = "-1") {
        id = UUID(); self.event = event; self.operation = operation; self.value = value; condition = nil; original = [:]; sourceIndex = nil
    }
    init(source: [String: ProjectEditJSON], sourceIndex: Int? = nil) {
        id = UUID(); event = source["on"]?.text ?? ""; operation = source["op"]?.text ?? ""
        value = source["value"]?.integer.map(String.init) ?? ""; condition = source["when"]; original = source; self.sourceIndex = sourceIndex
    }
    public func encoded() throws -> ProjectEditJSON {
        guard Set(original.keys).isSubset(of: ["on","when","op","value"]), Self.events.contains(event),
              Self.operations.contains(operation) else { throw NativeAttributeAuthorError.invalid("rules.on/op/unknown field") }
        var fields: [String: ProjectEditJSON] = ["on": .string(event), "op": .string(operation)]
        if needsValue { fields["value"] = .number(Decimal(try NativeAttributeAuthorRow.integer(value, path: "rules.value"))) }
        if let condition, condition != .null, condition != .array([]) { fields["when"] = condition }
        return .object(fields)
    }
}

public struct NativeAttributeAuthorRow: Identifiable, Codable, Equatable {
    public let id: UUID
    /// Exact original GET row, including legacy and future fields. Never sent as a replacement.
    public let original: [String: ProjectEditJSON]
    public let existingKey: String?
    public var key: String
    public var keyType: String
    public var scope: String
    public var label: String
    public var initial: String
    public var minimum: String
    public var maximum: String
    public var display: String
    public var color: String
    public var icon: String
    public var sortOrder: String
    public var visible: Bool
    public var persistScope: String
    public var rules: [NativeAttributeAuthorRule]
    public let isDefinition: Bool
    public var isCounter: Bool { keyType == "counter" }
    public var sourceIsSupported: Bool {
        guard existingKey != nil else { return true }
        for field in ["display","persistScope","color","icon"] {
            if let value = original[field], value != .null, value.text == nil { return false }
        }
        return (try? Self(source: original).definition()) != nil
    }
    public static let fields: Set<String> = ["stateKey","keyType","scope","label","initialValue","minValue","maxValue",
        "display","color","icon","sortOrder","visible","persistScope","rules"]
    static let extensions: Set<String> = ["minValue","maxValue","display","color","icon","sortOrder","visible","persistScope","rules"]
    public init(registrationOnly: Bool = false) {
        id = UUID(); original = [:]; existingKey = nil; key = "counter."; keyType = "counter"; scope = "run"
        label = ""; initial = "0"; minimum = "0"; maximum = "100"; display = "number"; color = ""; icon = ""
        sortOrder = "0"; visible = true; persistScope = "run"; rules = []; isDefinition = !registrationOnly
    }
    init(source: [String: ProjectEditJSON]) throws {
        guard let key = source["stateKey"]?.text, Self.validKey(key),
              let type = source["keyType"]?.text, let scope = source["scope"]?.text else {
            throw NativeAttributeAuthorError.invalid("state-keys[].stateKey/label/keyType/scope")
        }
        if let label = source["label"], label != .null, label.text == nil { throw NativeAttributeAuthorError.invalid("state-keys[].label") }
        let label = source["label"]?.text ?? ""
        id = UUID(); original = source; existingKey = key; self.key = key; keyType = type; self.scope = scope; self.label = label
        isDefinition = Self.extensions.contains { source[$0] != nil && source[$0] != .null }
        func number(_ name: String, _ fallback: Int) throws -> String {
            guard let raw = source[name], raw != .null else { return String(fallback) }
            guard let value = raw.integer, Int32(exactly: value) != nil else { throw NativeAttributeAuthorError.invalid(name) }
            return String(value)
        }
        initial = try number("initialValue", 0); minimum = try number("minValue", 0)
        maximum = try number("maxValue", ["flag","tag"].contains(type) ? 1 : 100)
        sortOrder = try number("sortOrder", 0)
        display = source["display"]?.text ?? "number"; color = source["color"]?.text ?? ""; icon = source["icon"]?.text ?? ""
        persistScope = source["persistScope"]?.text ?? "run"
        if let raw = source["visible"], raw != .null {
            guard case .bool(let flag) = raw else { throw NativeAttributeAuthorError.invalid("visible") }; visible = flag
        } else { visible = true }
        if let raw = source["rules"], raw != .null {
            guard let rows = raw.array else { throw NativeAttributeAuthorError.invalid("rules") }
            rules = try rows.enumerated().map { index, raw in guard let fields = raw.object else { throw NativeAttributeAuthorError.invalid("rules[]") }; return .init(source: fields, sourceIndex: index) }
        } else { rules = [] }
    }
    public static func validKey(_ key: String) -> Bool {
        key.range(of: "^(clue|counter|relation|tag)\\.[a-z][a-z0-9_]{0,47}$(?![\\s\\S])", options: .regularExpression) != nil
    }
    static func integer(_ text: String, path: String) throws -> Int32 {
        guard text.range(of: "^-?[0-9]+$(?![\\s\\S])", options: .regularExpression) != nil,
              let value = Int32(text) else { throw NativeAttributeAuthorError.invalid(path) }
        return value
    }
    public func definition() throws -> [String: ProjectEditJSON] {
        if !isDefinition { return try registrationPayload() }
        guard Self.validKey(key), existingKey.map({ $0.utf8.elementsEqual(key.utf8) }) ?? true,
              ["run","party","deployment"].contains(scope),
              keyType == (key.hasPrefix("clue.") ? "flag" : String(key.prefix { $0 != "." })),
              !label.isEmpty, label.unicodeScalars.count <= 8,
              label.unicodeScalars.first.map({ $0.value > 0x20 }) == true,
              label.unicodeScalars.last.map({ $0.value > 0x20 }) == true else {
            throw NativeAttributeAuthorError.invalid("stateKey/keyType/scope/label")
        }
        if existingKey != nil {
            guard original["keyType"] == .string(keyType), original["scope"] == .string(scope) else {
                throw NativeAttributeAuthorError.invalid("registered keyType/scope immutable")
            }
        }
        let initialValue = try Self.integer(initial, path: "initialValue")
        var result: [String: ProjectEditJSON] = ["stateKey": .string(key), "keyType": .string(keyType), "scope": .string(scope),
            "label": .string(label), "initialValue": .number(Decimal(Int(initialValue)))]
        guard isDefinition else { return result }
        let lo = try Self.integer(minimum, path: "minValue"), hi = try Self.integer(maximum, path: "maxValue")
        guard lo < hi, (lo...hi).contains(initialValue), ["bar","number","icon","hidden"].contains(display),
              ["run","topic"].contains(persistScope), icon.utf16.count <= 64, rules.count <= 20,
              color.isEmpty || color.range(of: "^#[a-fA-F0-9]{6}$(?![\\s\\S])", options: .regularExpression) != nil else {
            throw NativeAttributeAuthorError.invalid("minValue/maxValue/display/persistScope/color/icon/rules")
        }
        if ["flag","tag"].contains(keyType), !(lo == 0 && hi == 1 && [0,1].contains(initialValue)) {
            throw NativeAttributeAuthorError.invalid("flag/tag 0/1")
        }
        guard isCounter || rules.isEmpty else { throw NativeAttributeAuthorError.invalid("only counter supports numeric rules") }
        result["minValue"] = .number(Decimal(Int(lo))); result["maxValue"] = .number(Decimal(Int(hi)))
        result["display"] = .string(display); result["visible"] = .bool(visible); result["persistScope"] = .string(persistScope)
        result["sortOrder"] = .number(Decimal(Int(try Self.integer(sortOrder, path: "sortOrder"))))
        if !color.isEmpty { result["color"] = .string(color) }
        if !icon.isEmpty { result["icon"] = .string(icon) }
        result["rules"] = .array(try rules.map { try $0.encoded() })
        return result
    }
    /// The committed a829 DTO binds only ThemeStateKey. Never project an extended local
    /// definition into a successful basic registration by silently dropping its extra fields.
    public func registrationPayload() throws -> [String: ProjectEditJSON] {
        guard !isDefinition else {
            throw NativeAttributeAuthorError.contractMissing("ApiTopicStateKeyController.registerStateKeys -> TopicStateKeyRegisterDTO.keys: ThemeStateKey has no minValue/maxValue/display/color/icon/sortOrder/visible/persistScope/rules write consumer")
        }
        guard Self.validKey(key), existingKey.map({ $0.utf8.elementsEqual(key.utf8) }) ?? true,
              ["run","party","deployment"].contains(scope),
              keyType == (key.hasPrefix("clue.") ? "flag" : String(key.prefix { $0 != "." })) else {
            throw NativeAttributeAuthorError.invalid("stateKey/keyType/scope")
        }
        let baseline: Self
        if existingKey == nil { baseline = Self(registrationOnly: true) }
        else { baseline = try Self(source: original) }
        guard minimum == baseline.minimum, maximum == baseline.maximum, display == baseline.display,
              color == baseline.color, icon == baseline.icon, sortOrder == baseline.sortOrder,
              visible == baseline.visible, persistScope == baseline.persistScope, rules == baseline.rules else {
            throw NativeAttributeAuthorError.contractMissing("Registration DTO cannot persist edited min/max/display/color/icon/order/visibility/persistence/rules")
        }
        if existingKey != nil {
            guard original["keyType"] == .string(keyType), original["scope"] == .string(scope) else {
                throw NativeAttributeAuthorError.invalid("registered keyType/scope immutable: existing upsert updates label/initial_value only")
            }
        }
        // ThemeStateKeyService validates no new label length or flag/tag 0/1 range.
        // Its actual content-security check remains on the server. Missing initialValue becomes 0.
        let number: Int32
        if initial.isEmpty { number = 0 } else { number = try Self.integer(initial, path: "initialValue") }
        let unchangedNullableLabel = existingKey != nil && label.isEmpty && original["label"]?.text == nil
        return ["stateKey": .string(key), "keyType": .string(keyType), "scope": .string(scope),
                "label": unchangedNullableLabel ? .null : .string(label), "initialValue": .number(Decimal(Int(number)))]
    }
    /// GET metadata/future fields stay local. These local deltas are not a PUT endpoint.
    public func changes() throws -> [String: ProjectEditJSON] {
        let full = try definition()
        guard existingKey != nil else { return full }
        let baseline = try Self(source: original).definition()
        var patch = full.filter { !NativeAttributeAuthorWire.sameOptional(baseline[$0.key], $0.value) }
        for field in ["color","icon"] where baseline[field] != nil && full[field] == nil { patch[field] = .null }
        return patch
    }
    public var hasChanges: Bool { (try? changes().isEmpty) == false }
    public var unsupportedReason: String? {
        do { _ = try definition(); return nil }
        catch { return String(describing: error) }
    }
}

public struct NativeAttributeAuthorDraft: Codable, Equatable {
    public let binding: NativeAttributeAuthorBinding
    public let rawSource: Data
    public private(set) var rows: [NativeAttributeAuthorRow]
    public init(binding: NativeAttributeAuthorBinding, rawRows: Data) throws {
        guard let source = try NativeAttributeAuthorWire.decode(rawRows).array, source.count <= 4096 else {
            throw NativeAttributeAuthorError.invalid("state-keys list")
        }
        var seen = Set<Data>()
        rows = try source.map {
            guard let fields = $0.object else { throw NativeAttributeAuthorError.invalid("state-keys[]") }
            let row = try NativeAttributeAuthorRow(source: fields)
            guard seen.insert(Data(row.key.utf8)).inserted else { throw NativeAttributeAuthorError.invalid("duplicate stateKey") }
            return row
        }
        self.binding = binding; rawSource = rawRows
    }
    public mutating func add(registrationOnly: Bool = false) throws -> UUID {
        guard !binding.isLocked else { throw NativeAttributeAuthorError.staleSource }
        if !registrationOnly, rows.filter(\.isDefinition).count >= 32 { throw NativeAttributeAuthorError.invalid("definitions: at most 32; server also checks preserved journey attributes") }
        let row = NativeAttributeAuthorRow(registrationOnly: registrationOnly); rows.append(row); return row.id
    }
    public mutating func replace(_ edited: NativeAttributeAuthorRow) throws {
        guard !binding.isLocked, let index = rows.firstIndex(where: { $0.id == edited.id }),
              edited.original == rows[index].original, edited.existingKey == rows[index].existingKey,
              edited.isDefinition == rows[index].isDefinition else { throw NativeAttributeAuthorError.staleSource }
        rows[index] = edited
    }
    /// Reorder only explicit definition rows; untouched legacy registrations gain no sortOrder field.
    public mutating func reorder(_ keys: [String]) throws {
        guard !binding.isLocked, Set(keys.map { Data($0.utf8) }) == Set(rows.filter(\.isDefinition).map { Data($0.key.utf8) }),
              keys.count == rows.filter(\.isDefinition).count else { throw NativeAttributeAuthorError.invalid("sortOrder") }
        for (order, key) in keys.enumerated() {
            guard let index = rows.firstIndex(where: { $0.key.utf8.elementsEqual(key.utf8) }) else { continue }
            rows[index].sortOrder = String(order)
        }
        rows.sort { (Int($0.sortOrder) ?? 0, $0.key) < (Int($1.sortOrder) ?? 0, $1.key) }
    }
    public mutating func removeUnsaved(_ id: UUID) throws {
        guard !binding.isLocked, let row = rows.first(where: { $0.id == id }), row.existingKey == nil else {
            throw NativeAttributeAuthorError.invalid("registered deletion requires server references")
        }
        rows.removeAll { $0.id == id }
    }
    public func changedRows() throws -> [NativeAttributeAuthorRow] {
        var seen = Set<Data>(); var result: [NativeAttributeAuthorRow] = []
        for row in rows {
            guard seen.insert(Data(row.key.utf8)).inserted else { throw NativeAttributeAuthorError.invalid("duplicate stateKey") }
            // Unsupported untouched future rows are retained, not rewritten or repaired.
            let baseline = try? NativeAttributeAuthorRow(source: row.original)
            if let baseline, row.sameEditableValues(as: baseline) { continue }
            _ = try row.definition(); result.append(row)
        }
        return result
    }
    public var hasChanges: Bool { rows.contains { row in
        guard let baseline = try? NativeAttributeAuthorRow(source: row.original) else { return true }
        return !row.sameEditableValues(as: baseline)
    } }
    /// Unsent recovery can cross a login epoch only after a fresh authoritative source matches
    /// every original row. Concurrent/future source changes require the original project's conflict flow.
    public func recoverUnsent(binding next: NativeAttributeAuthorBinding, authoritative: NativeAttributeAuthorDraft) throws -> Self {
        guard !binding.isLocked, !next.isLocked, binding.storageKey == next.storageKey,
              binding.sourceConfigVersion == next.sourceConfigVersion, authoritative.binding == next,
              NativeAttributeAuthorWire.same(try NativeAttributeAuthorWire.decode(rawSource), try NativeAttributeAuthorWire.decode(authoritative.rawSource)) else {
            throw NativeAttributeAuthorError.staleSource
        }
        guard try NativeAttributeAuthorWire.numberSpellings(rawSource, beneath: []) == NativeAttributeAuthorWire.numberSpellings(authoritative.rawSource, beneath: []) else { throw NativeAttributeAuthorError.staleSource }
        return Self(binding: next, rawSource: authoritative.rawSource, rows: rows)
    }
    private init(binding: NativeAttributeAuthorBinding, rawSource: Data, rows: [NativeAttributeAuthorRow]) {
        self.binding = binding; self.rawSource = rawSource; self.rows = rows
    }
}

extension NativeAttributeAuthorRow {
    func sameEditableValues(as other: Self) -> Bool {
        // IDs are local view identities and never take part in change detection.
        return key.utf8.elementsEqual(other.key.utf8) && keyType == other.keyType && scope == other.scope &&
            label.utf8.elementsEqual(other.label.utf8) && initial == other.initial && minimum == other.minimum && maximum == other.maximum &&
            display == other.display && color.utf8.elementsEqual(other.color.utf8) && icon.utf8.elementsEqual(other.icon.utf8) &&
            sortOrder == other.sortOrder && visible == other.visible && persistScope == other.persistScope &&
            rules.count == other.rules.count && zip(rules, other.rules).allSatisfy { pair in
                pair.0.event == pair.1.event && pair.0.operation == pair.1.operation && pair.0.value == pair.1.value &&
                NativeAttributeAuthorWire.sameOptional(pair.0.condition, pair.1.condition) &&
                NativeAttributeAuthorWire.same(.object(pair.0.original), .object(pair.1.original))
            }
    }
}
