import Foundation
import Combine
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// OWN-21.1 / OWN-21.2. Gameplay preset list, info and draft.
/// `POST /api/preset/gameplay/draft` returns a personal template id. It is not a shelf id and it is not a money write.
public enum GameplayPresetPath {
    public static let list = "/api/preset/gameplay/list"
    public static let info = "/api/preset/gameplay/info"
    public static let draft = "/api/preset/gameplay/draft"
    public static let relative = ["api/preset/gameplay/list", "api/preset/gameplay/info", "api/preset/gameplay/draft"]
}

public enum GameplayPresetRefusal: Error, Equatable {
    case invalidRequest
    case notSent
}

/// A preset draft body. Money keys are refused and are not sent. Other keys are kept so the server can reject an undeclared parameter in its own words.
public enum GameplayPresetDraftBody {
    public static let moneyKeys: Set<String> = ["payChannel", "payAmount", "price", "amount", "payableAmount", "refundAmount"]
    public static let requestIDPattern = #"^[A-Za-z0-9._:-]{8,64}$"#

    public static func allows(_ object: [String: Any]) -> Bool {
        guard let requestID = object["requestId"] as? String,
              requestID.range(of: requestIDPattern, options: .regularExpression) != nil,
              let presetKey = object["presetKey"] as? String, !presetKey.isEmpty, presetKey.utf16.count <= 128,
              moneyKeys.isDisjoint(with: Set(object.keys)) else { return false }
        if let inputs = object["inputs"] {
            guard let map = inputs as? [String: Any], moneyKeys.isDisjoint(with: Set(map.keys)) else { return false }
        }
        return true
    }
}

public struct GameplayPresetField: Equatable, Identifiable, Sendable {
    public let key: String
    public let kind: String
    public let label: String
    public let maxLength: Int?
    public let min: Decimal?
    public let max: Decimal?
    public let options: [String]
    public let items: [String]
    public let bins: [String]
    public var id: String { key }

    public init(key: String, kind: String, label: String, maxLength: Int?, min: Decimal?, max: Decimal?, options: [String], items: [String], bins: [String]) {
        self.key = key; self.kind = kind; self.label = label; self.maxLength = maxLength
        self.min = min; self.max = max; self.options = options; self.items = items; self.bins = bins
    }
}

public struct GameplayPresetSummary: Equatable, Identifiable, Sendable {
    public let presetKey: String
    public let version: String?
    public let sourceMark: String?
    public let title: String
    public let purpose: String?
    public let category: String?
    public let authorTodos: [String]
    public let requiredFields: [GameplayPresetField]
    public let templateSource: String?
    public var id: String { presetKey }

    /// Display label for the three author-list marks. The raw server value is kept when it is not one of those marks. It is not a permission.
    public func templateSourceLabel(chinese: Bool) -> String {
        switch templateSource?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case nil, "": return WP09Copy.unknown
        case "PRESET", "预设起头": return WP09Copy.text("预设起头", "Started from a preset", chinese: chinese)
        case "OWN", "自主创建": return WP09Copy.text("自主创建", "Created on its own", chinese: chinese)
        case "REFERENCE", "引用模板": return WP09Copy.text("引用模板", "References a template", chinese: chinese)
        case "REFERENCE_UNLISTED", "引用已下架": return WP09Copy.text("引用已下架", "References an unlisted template", chinese: chinese)
        case let other?: return other
        }
    }
}

public struct GameplayPresetCatalog: Equatable, Sendable {
    public let catalogVersion: String?
    public let presets: [GameplayPresetSummary]
}

public enum GameplayPresetReceiptState: Equatable, Sendable {
    case applied, replayed, rejected, pending, unknown
    public init(raw: String?) {
        switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "APPLIED": self = .applied
        case "REPLAYED": self = .replayed
        case "REJECTED": self = .rejected
        case "PENDING": self = .pending
        default: self = .unknown
        }
    }
    /// An applied or replayed receipt opens the same draft. Pending and unknown do not, and they are not "created".
    public var opensDraft: Bool { self == .applied || self == .replayed }
}

public struct GameplayPresetDraftReceipt: Equatable, Sendable {
    public let draftID: Int?
    public let state: GameplayPresetReceiptState
    public let serverMessage: String?
    public let authorTodos: [String]
    public var opensEditor: Bool { state.opensDraft && (draftID ?? 0) > 0 }
    /// Replay keeps the original draft. The copy must not say a new draft was created.
    public func outcome(chinese: Bool) -> String {
        switch state {
        case .applied: return WP09Copy.text("草稿已打开", "Draft is open", chinese: chinese)
        case .replayed: return WP09Copy.text("仍是原来的草稿", "Still the original draft", chinese: chinese)
        case .rejected: return serverMessage?.isEmpty == false ? serverMessage! : WP09Copy.text("未能建成草稿", "The draft was not created", chinese: chinese)
        case .pending, .unknown: return WP09Copy.unknown
        }
    }
}

public enum GameplayPresetRead<T: Equatable>: Equatable {
    case value(T)
    case empty
    case failed(String)
    case notSent
}

public struct GameplayPresetClient {
    public let configuration: APIConfiguration
    private let transport: any HTTPTransport
    public let token: String

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: String) {
        self.configuration = configuration
        self.transport = transport
        self.token = token
    }

    public func list() async -> GameplayPresetRead<GameplayPresetCatalog> {
        await send(method: "GET", path: GameplayPresetPath.list, query: [], body: nil) { data in
            guard let object = Self.object(data) else { return nil }
            let presets = Self.presets(object["presets"])
            return GameplayPresetCatalog(catalogVersion: Self.text(object["catalogVersion"]), presets: presets)
        }
    }

    public func info(presetKey: String) async -> GameplayPresetRead<GameplayPresetSummary> {
        guard !presetKey.isEmpty else { return .notSent }
        return await send(method: "GET", path: GameplayPresetPath.info, query: [("presetKey", presetKey)], body: nil) { data in
            guard let object = Self.object(data) else { return nil }
            let row = (object["preset"] as? [String: Any]) ?? object
            return Self.preset(row)
        }
    }

    /// OWN-21.1. Same `requestId` retries the original receipt. A money key is not sent.
    public func draft(requestID: String, presetKey: String, inputs: [String: Any]) async -> GameplayPresetRead<GameplayPresetDraftReceipt> {
        let body: [String: Any] = ["requestId": requestID, "presetKey": presetKey, "inputs": inputs]
        guard GameplayPresetDraftBody.allows(body),
              let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else { return .notSent }
        return await send(method: "POST", path: GameplayPresetPath.draft, query: [], body: data) { payload in
            guard let object = Self.object(payload) else { return nil }
            let receipt = object["writeReceipt"] as? [String: Any]
            let id = Self.integer(object["draftId"])
            return GameplayPresetDraftReceipt(draftID: id, state: GameplayPresetReceiptState(raw: Self.text(receipt?["state"])),
                                               serverMessage: Self.text(object["message"]) ?? Self.text(object["msg"]),
                                               authorTodos: Self.strings(object["authorTodos"]))
        }
    }

    private func send<T: Equatable>(method: String, path: String, query: [(String, String)], body: Data?,
                                    decode: (Any) -> T?) async -> GameplayPresetRead<T> {
        guard AuthRequestBuilder.isValidToken(token), let request = make(method: method, path: path, query: query, body: body) else { return .notSent }
        do { try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request) } catch { return .notSent }
        let data: Data
        let status: Int
        do { (data, status) = try await transport.send(request) }
        catch is CancellationError { return .failed(WP09Copy.unknown) }
        catch { return .failed(WP09Copy.unknown) }
        guard (200...299).contains(status), let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failed(WP09Copy.unknown)
        }
        let code = Self.integer(root["code"]) ?? Int(Self.text(root["code"]) ?? "")
        guard code == 200 else {
            return .failed(Self.text(root["msg"]) ?? Self.text(root["message"]) ?? WP09Copy.unknown)
        }
        if root["data"] is NSNull || root["data"] == nil { return .empty }
        guard let value = decode(root["data"] as Any) else { return .failed(WP09Copy.unknown) }
        if let catalog = value as? GameplayPresetCatalog, catalog.presets.isEmpty { return .empty }
        return .value(value)
    }

    private func make(method: String, path: String, query: [(String, String)], body: Data?) -> URLRequest? {
        let url = path.split(separator: "/").reduce(configuration.baseURL) { partial, part in
            partial.appendingPathComponent(String(part))
        }
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if !query.isEmpty { parts.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        guard let final = parts.url else { return nil }
        var request = URLRequest(url: final)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    static func object(_ value: Any) -> [String: Any]? { value as? [String: Any] }
    static func text(_ value: Any?) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let whole = integer(value) { return String(whole) }
        return nil
    }
    static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() { return nil }
            let double = number.doubleValue
            guard double.isFinite, double.rounded() == double, abs(double) <= 9_007_199_254_740_991 else { return nil }
            return Int(double)
        }
        if let text = value as? String { return Int(text) }
        return nil
    }
    static func decimal(_ value: Any?) -> Decimal? {
        if let number = value as? NSNumber {
            if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() { return nil }
            return number.decimalValue
        }
        if let text = value as? String { return Decimal(string: text) }
        return nil
    }
    static func strings(_ value: Any?) -> [String] {
        guard let rows = value as? [Any] else { return [] }
        return rows.prefix(32).compactMap { text($0) }
    }
    static func presets(_ value: Any?) -> [GameplayPresetSummary] {
        guard let rows = value as? [Any] else { return [] }
        return rows.prefix(100).compactMap { ($0 as? [String: Any]).flatMap(preset) }
    }
    static func preset(_ row: [String: Any]) -> GameplayPresetSummary? {
        guard let key = text(row["presetKey"]), !key.isEmpty else { return nil }
        let fields = (row["requiredFields"] as? [Any] ?? []).prefix(40).compactMap { item -> GameplayPresetField? in
            guard let field = item as? [String: Any], let name = text(field["key"]) ?? text(field["name"]) else { return nil }
            return GameplayPresetField(key: name, kind: text(field["kind"]) ?? "text", label: text(field["label"]) ?? name,
                                        maxLength: integer(field["maxLength"]), min: decimal(field["min"]), max: decimal(field["max"]),
                                        options: strings(field["options"]), items: strings(field["items"]), bins: strings(field["bins"]))
        }
        return GameplayPresetSummary(presetKey: key, version: text(row["version"]), sourceMark: text(row["sourceMark"]),
                                      title: text(row["title"]) ?? key, purpose: text(row["purpose"]), category: text(row["category"]),
                                      authorTodos: strings(row["authorTodos"]), requiredFields: fields, templateSource: text(row["templateSource"]))
    }
}

/// OWN-21.1. List, then info, then draft. A successful receipt opens an editable draft. The same request id is reused.
@MainActor public final class GameplayPresetModel: ObservableObject {
    public enum Phase: Equatable {
        case idle, loading, empty, failed(String), catalog, form, editing
    }
    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var catalog: GameplayPresetCatalog?
    @Published public private(set) var preset: GameplayPresetSummary?
    @Published public private(set) var receipt: GameplayPresetDraftReceipt?
    @Published public var message: String?
    @Published public var textInputs: [String: String] = [:]
    @Published public var orderItems: [String: [String]] = [:]
    @Published public var binChoices: [String: [String: String]] = [:]
    public private(set) var canDraft: Bool
    public private(set) var requestID: String
    private var client: GameplayPresetClient?
    private let makeRequestID: () -> String

    public init(client: GameplayPresetClient?, canDraft: Bool = true, makeRequestID: @escaping () -> String = { AuthorWriteRequestID.make(prefix: "preset") }) {
        self.client = client
        self.canDraft = canDraft
        self.makeRequestID = makeRequestID
        self.requestID = makeRequestID()
    }

    public func adopt(client: GameplayPresetClient?, canDraft: Bool) {
        self.client = client
        self.canDraft = canDraft
    }

    public var editorOpen: Bool { phase == .editing && receipt?.opensEditor == true }
    public var inputsEditable: Bool { phase == .form || phase == .editing }

    public func load() async {
        guard let client else { phase = .failed(WP09Copy.unknown); return }
        phase = .loading
        switch await client.list() {
        case .value(let value):
            catalog = value
            phase = value.presets.isEmpty ? .empty : .catalog
        case .empty:
            catalog = GameplayPresetCatalog(catalogVersion: nil, presets: [])
            phase = .empty
        case .failed(let message): phase = .failed(message)
        case .notSent: phase = .failed(WP09Copy.unknown)
        }
    }

    public func open(presetKey: String) async {
        guard let client else { phase = .failed(WP09Copy.unknown); return }
        phase = .loading
        switch await client.info(presetKey: presetKey) {
        case .value(let value):
            preset = value
            textInputs = [:]
            orderItems = Dictionary(uniqueKeysWithValues: value.requiredFields.filter { $0.kind == "order" }.map { ($0.key, $0.items) })
            binChoices = [:]
            receipt = nil
            phase = .form
        case .empty: phase = .empty
        case .failed(let message): phase = .failed(message)
        case .notSent: phase = .failed(WP09Copy.unknown)
        }
    }

    /// Builds the draft. Missing required input is listed and not sent. A replay keeps `requestID`.
    public func create() async {
        guard canDraft, let client, let preset else { message = WP09Copy.unknown; return }
        let inputs = collectedInputs(preset)
        if let missing = missingLabels(preset, inputs: inputs) {
            message = missing
            phase = .form
            return
        }
        switch await client.draft(requestID: requestID, presetKey: preset.presetKey, inputs: inputs) {
        case .value(let value):
            receipt = value
            message = value.outcome(chinese: W8Text.isChinese)
            phase = value.opensEditor ? .editing : .form
        case .empty:
            message = WP09Copy.unknown
            phase = .form
        case .failed(let serverMessage):
            receipt = nil
            message = serverMessage
            phase = .form
        case .notSent:
            receipt = nil
            message = WP09Copy.unknown
            phase = .form
        }
    }

    public func move(_ key: String, from index: Int, up: Bool) {
        guard var rows = orderItems[key], rows.indices.contains(index) else { return }
        let next = up ? index - 1 : index + 1
        guard rows.indices.contains(next) else { return }
        rows.swapAt(index, next)
        orderItems[key] = rows
    }

    private func collectedInputs(_ preset: GameplayPresetSummary) -> [String: Any] {
        var inputs: [String: Any] = [:]
        for field in preset.requiredFields {
            switch field.kind {
            case "order": inputs[field.key] = orderItems[field.key] ?? field.items
            case "bin_map": inputs[field.key] = binChoices[field.key] ?? [:]
            default: inputs[field.key] = textInputs[field.key] ?? ""
            }
        }
        return inputs
    }

    private func missingLabels(_ preset: GameplayPresetSummary, inputs: [String: Any]) -> String? {
        var missing: [String] = []
        for field in preset.requiredFields {
            switch field.kind {
            case "number":
                guard let text = inputs[field.key] as? String, let number = Decimal(string: text) else { missing.append(field.label); continue }
                if let min = field.min, number < min { missing.append(field.label) }
                if let max = field.max, number > max { missing.append(field.label) }
            case "order":
                let rows = inputs[field.key] as? [String] ?? []
                if Set(rows) != Set(field.items) || rows.count != field.items.count { missing.append(field.label) }
            case "bin_map":
                let map = inputs[field.key] as? [String: String] ?? [:]
                if field.items.contains(where: { map[$0]?.isEmpty != false }) { missing.append(field.label) }
            case "choice":
                let text = (inputs[field.key] as? String) ?? ""
                if text.isEmpty || (!field.options.isEmpty && !field.options.contains(text)) { missing.append(field.label) }
            default:
                let text = (inputs[field.key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if text.isEmpty { missing.append(field.label) }
                if let max = field.maxLength, text.utf16.count > max { missing.append(field.label) }
            }
        }
        guard !missing.isEmpty else { return nil }
        let list = missing.joined(separator: WP09Copy.text("、", ", ", chinese: W8Text.isChinese))
        return WP09Copy.text("预设还缺这些必填内容，补齐后才能建草稿：\(list)", "This preset is still missing: \(list)", chinese: W8Text.isChinese)
    }
}
