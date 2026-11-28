import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// G3 creator topic editor. The calls the mini-program's creator pages make
/// (`pages/publish/fabu`, `pages/play`, `pages/member`, and the host workbench
/// `pages/topic/merchantinfo`), with the same bodies: a POST without a header is
/// form-encoded, play-setup PUT and the state-key writes are JSON, GETs carry a query.
/// No price, payment, refund, or merchant route is built here.
public enum TopicCreatorEditorRoute: String, CaseIterable {
    case authorEditDetail = "api/topic/author-edit-detail"
    case authorSavedDetail = "api/topic/author-saved-detail"
    case attributeBinding = "api/topic/attribute-binding"
    case playSetup = "api/topic/play-setup"
    case publishDraft = "api/topic/publish-draft"
    case shareCode = "api/topic/share-code"
    case stateKeys = "api/topic/state-keys"
    case namedStateKey = "api/topic/state-keys/named"
    case stateKey = "api/topic/state-keys/{}"
    case inviteChapters = "api/topic/invite-chapters"
    case supplyTerms = "api/topic/chapter/supply-terms"
    case hostQRCode = "api/topic/host-qrcode"

    /// Grant entries, without the leading slash, the way the player write lease lists them.
    public static var grantPaths: Set<String> { Set(allCases.map(\.rawValue)) }
}

public enum TopicCreatorEditorIssue: Error, Equatable {
    case invalid, disabled, unauthorized, unavailable, malformed, outcomeUnknown
    /// The server answered and refused. The message is shown as the server wrote it.
    case rejected(String)
}

public struct TopicAuthorDetail: Equatable {
    public let topicID: String
    public let name: String
    public let isDraft: Bool
    public let configVersion: String?
    public let chapterCount: Int
    public let journeyRules: String?
}

public struct TopicAttributeDefinition: Equatable {
    public let stateKey: String
    public let label: String
    public let keyType: String
    public let scope: String
    public let persistScope: String
    public let initialValue: Int
    public let minValue: Int
    public let maxValue: Int
    public let visible: Bool
    /// MP `attribute-binding.js` `fields`: every compared field (registry name → value), so the
    /// 定义差异 list can show 显示方式 / 颜色 / 图标 / 排序 / 显示规则 too.
    public var fields: [String: TopicAttributeFieldValue] = [:]
}

/// One registry field as the MP compares it (`stable(value)`) and shows it (`String(value)`, `null` → 未设置).
public struct TopicAttributeFieldValue: Equatable, Sendable {
    public let canonical: String
    public let display: String?
    public init(canonical: String, display: String?) { self.canonical = canonical; self.display = display }
}

public struct TopicAttributeRegistry: Equatable {
    public let topicID: String
    public let configVersion: String
    public let registryVersion: String
    public let definitions: [TopicAttributeDefinition]
}

/// `theme-d20-page.js` play window. A custom end of `次日 02:00` is sent as `02:00`, as the page does.
public struct TopicPlayWindow: Equatable {
    public enum Mode: String, CaseIterable { case any, day, night, custom }
    public static let starts = ["06:00", "08:00", "10:00", "14:00", "18:00", "19:00"]
    public static let ends = ["20:00", "21:00", "22:00", "23:00", "次日 02:00"]
    public var mode: Mode
    public var start: String?
    public var end: String?
    public init(mode: Mode, start: String? = nil, end: String? = nil) {
        self.mode = mode; self.start = mode == .custom ? start : nil; self.end = mode == .custom ? end : nil
    }
    var wire: PlayWireValue {
        guard mode == .custom else { return .object(["mode": .string(mode.rawValue)]) }
        let trimmedEnd = (end ?? "").replacingOccurrences(of: "^次日\\s*", with: "", options: .regularExpression)
        return .object(["mode": .string("custom"), "start": .string(start ?? ""), "end": .string(trimmedEnd)])
    }
    init(wire: PlayWireValue) {
        let mode = wire["mode"].text.flatMap(Mode.init(rawValue:)) ?? .any
        guard mode == .custom else { self.init(mode: mode); return }
        let raw = wire["end"].text
        let end = Self.ends.first { $0.replacingOccurrences(of: "^次日\\s*", with: "", options: .regularExpression) == raw } ?? raw
        self.init(mode: .custom, start: wire["start"].text, end: end)
    }
}

public struct TopicPlaySetup: Equatable {
    public static let maximumPrepItems = 6
    public var window: TopicPlayWindow
    public var prepItems: [String]
    public init(window: TopicPlayWindow, prepItems: [String]) {
        self.window = window
        self.prepItems = Array(prepItems.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.prefix(Self.maximumPrepItems))
    }
}

public struct TopicPublishReceipt: Equatable {
    public let reviewState: String?
    /// Shown only when the server returned it; an old response without it shows nothing.
    public let contentRevisionNo: String?
}

public struct TopicStateKeyRow: Equatable {
    public let id: String
    public let label: String
    /// The row exactly as read; a rename sends it back with only `label` replaced.
    public let raw: [String: PlayWireValue]
    /// MP `normalizeKey`: the places a key is used in, when the list read carries them.
    public var usedIn: [String] { (PlayWireValue.object(raw)["usedIn"].array ?? []).compactMap(\.text).filter { !$0.isEmpty } }
    /// `clue` / `tag` / `counter` / `relation`, from the key name prefix.
    public var kind: String { id.split(separator: ".", maxSplits: 1).first.map(String.init) ?? "" }
}

public struct TopicInviteChapter: Equatable {
    public let id: String
    public let name: String
}

/// Host workbench station terms (`host-layers.js` saveTier). The REVSHARE tier sets a per-head fee
/// a club would pay, so it is a price term and stays out of this player grant.
public struct TopicChapterSupplyTerms: Equatable {
    public enum Mode: String, CaseIterable { case perk = "PERK", traffic = "TRAFFIC" }
    public let chapterID: Int64
    public let mode: Mode
    public let maxMerchant: Int
    public let perkMinValue: String?
    public init(chapterID: Int64, mode: Mode, maxMerchant: Int, perkMinValue: String? = nil) throws {
        guard chapterID > 0, (0...99).contains(maxMerchant) else { throw TopicCreatorEditorIssue.invalid }
        if let perkMinValue, perkMinValue.range(of: "^\\d{1,8}(\\.\\d{1,2})?$", options: .regularExpression) == nil {
            throw TopicCreatorEditorIssue.invalid
        }
        self.chapterID = chapterID; self.mode = mode; self.maxMerchant = maxMerchant
        self.perkMinValue = mode == .perk ? perkMinValue : nil
    }
}

@MainActor public final class TopicCreatorEditorService {
    public static let stateKeyPattern = "^(clue|relation|tag|counter)\\.[a-z][a-z0-9_]{0,47}$"
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let token: () -> String?
    private let enabled: () -> Bool
    private let unauthorized: () -> Void
    /// `operationScope` of the mini-program page. The personal creator entry sends none.
    public let scope: String?

    public init(baseURL: URL, transport: any HTTPTransport, token: @escaping () -> String?, scope: String? = nil,
                enabled: @escaping () -> Bool, unauthorized: @escaping () -> Void = {}) {
        self.baseURL = baseURL; self.transport = transport; self.token = token
        self.scope = scope; self.enabled = enabled; self.unauthorized = unauthorized
    }

    // MARK: reads

    /// `fabu loadEditingTopic`: POST {id, scope}; the payload needs a `topic` record and record lists.
    public func authorEditDetail(topicID: Int64) async throws -> TopicAuthorDetail {
        try Self.detail(try await read(.authorEditDetail, form: idFields(topicID)), topicID: topicID)
    }

    /// `fabu` server-draft readback after a save: POST {id, scope}.
    public func authorSavedDetail(topicID: Int64) async throws -> TopicAuthorDetail {
        try Self.detail(try await read(.authorSavedDetail, form: idFields(topicID)), topicID: topicID)
    }

    /// `_readAttributeRegistrySnapshot`: GET ?topicId&scope. A different configVersion is a stale topic.
    public func attributeBinding(topicID: Int64, configVersion: String) async throws -> TopicAttributeRegistry {
        let data = try await read(.attributeBinding, query: topicQuery(topicID))
        guard data["configVersion"].editorText == configVersion else {
            throw TopicCreatorEditorIssue.rejected("主题配置版本已变化，请重新读取主题后确认")
        }
        return try Self.registry(data, topicID: topicID, configVersion: configVersion)
    }

    /// `_loadPlaySetup`: GET ?topicId&scope.
    public func playSetup(topicID: Int64) async throws -> TopicPlaySetup {
        let data = try await read(.playSetup, query: topicQuery(topicID))
        guard data.object != nil else { throw TopicCreatorEditorIssue.malformed }
        return TopicPlaySetup(window: TopicPlayWindow(wire: data["playWindow"]),
                              prepItems: (data["prepItems"].array ?? []).compactMap(\.text))
    }

    /// The state-key component's list read: GET ?topicId&scope.
    public func stateKeys(topicID: Int64) async throws -> [TopicStateKeyRow] {
        guard let rows = try await read(.stateKeys, query: topicQuery(topicID)).array else { throw TopicCreatorEditorIssue.malformed }
        return try rows.map { row in
            guard let object = row.object, let id = (row["stateKey"].text ?? row["id"].text), !id.isEmpty else {
                throw TopicCreatorEditorIssue.malformed
            }
            return TopicStateKeyRow(id: id, label: row["label"].text ?? "", raw: object)
        }
    }

    /// `share-card` / `pages/play` route card: POST {id}. Returns the mini-program code image path.
    public func shareCode(topicID: Int64) async throws -> String {
        guard let url = try await read(.shareCode, form: ["id": String(topicID)])["qrcodeUrl"].text, !url.isEmpty else {
            throw TopicCreatorEditorIssue.malformed
        }
        return url
    }

    /// Host workbench `issueHostQr`: POST {id, scope}.
    public func hostQRCode(topicID: Int64) async throws -> String {
        var fields = idFields(topicID); fields["scope"] = scope ?? ""
        guard let url = try await read(.hostQRCode, form: fields)["qrcodeUrl"].text, !url.isEmpty else {
            throw TopicCreatorEditorIssue.malformed
        }
        return url
    }

    /// `coop-invite-sheet loadChapters` / `coop-publisher-access`: POST {id, scope}. Read only.
    public func inviteChapters(topicID: Int64) async throws -> [TopicInviteChapter] {
        guard let rows = try await read(.inviteChapters, form: idFields(topicID))["chapters"].array else {
            throw TopicCreatorEditorIssue.malformed
        }
        return rows.compactMap { row in
            guard let id = row["id"].editorText, Self.decimalID(id) else { return nil }
            return TopicInviteChapter(id: id, name: row["name"].text ?? "")
        }
    }

    // MARK: writes

    /// `_savePlaySetup`: PUT JSON {topicId, scope, playWindow, prepItems}, a whole overwrite.
    public func savePlaySetup(topicID: Int64, setup: TopicPlaySetup) async throws {
        let body: [String: PlayWireValue] = ["topicId": .integer(topicID), "scope": scope.map(PlayWireValue.string) ?? .null,
            "playWindow": setup.window.wire, "prepItems": .array(setup.prepItems.map(PlayWireValue.string))]
        _ = try await write(.playSetup, method: "PUT", path: TopicCreatorEditorRoute.playSetup.rawValue, json: body)
    }

    /// `onRouteRuleCreate`: POST JSON {topicId, scope, kind, label}. The server names the key.
    public func createNamedStateKey(topicID: Int64, kind: String, label: String) async throws -> (key: String, label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ["clue", "tag"].contains(kind), !trimmed.isEmpty else { throw TopicCreatorEditorIssue.invalid }
        let row = try await write(.namedStateKey, method: "POST", path: TopicCreatorEditorRoute.namedStateKey.rawValue,
            json: ["topicId": .integer(topicID), "scope": scope.map(PlayWireValue.string) ?? .null,
                   "kind": .string(kind), "label": .string(trimmed)])
        guard let key = row["key"].text, !key.isEmpty else { throw TopicCreatorEditorIssue.outcomeUnknown }
        return (key, row["label"].text ?? trimmed)
    }

    /// `topic-state-keys onRename`: PUT JSON {topicId, scope, key: row with the new label}.
    public func renameStateKey(topicID: Int64, row: TopicStateKeyRow, label: String) async throws {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != row.label,
              let encoded = row.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "._-"))) else {
            throw TopicCreatorEditorIssue.invalid
        }
        var key = row.raw; key["label"] = .string(name)
        _ = try await write(.stateKey, method: "PUT", path: "api/topic/state-keys/" + encoded,
            json: ["topicId": .integer(topicID), "scope": scope.map(PlayWireValue.string) ?? .null, "key": .object(key)])
    }

    /// `topic-state-keys onConfirmDelete`: DELETE ?topicId&scope&key (the server reads query parameters only).
    /// A key used elsewhere is refused with `…引用位置：A、B` (see `ProjectEditTopicKeys.usedIn(fromRefusal:)`).
    public func deleteStateKey(topicID: Int64, key: String) async throws {
        guard ChinaReviewedRouteCapability.isTopicStateKey(key) else { throw TopicCreatorEditorIssue.invalid }
        var request = try request(TopicCreatorEditorRoute.stateKeys.rawValue, method: "DELETE")
        var parts = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        parts?.queryItems = topicQuery(topicID) + [URLQueryItem(name: "key", value: key)]
        guard let url = parts?.url else { throw TopicCreatorEditorIssue.invalid }
        request.url = url
        _ = try await send(.stateKeys, request: request, write: true)
    }

    /// Server-draft publish: POST {id, scope, configVersion?, registryVersion?, publishRequestId?}.
    /// A retry after an unknown outcome reuses the same request id; the server replays the original.
    public func publishDraft(topicID: Int64, configVersion: String?, registryVersion: String?,
                             publishRequestID: String) async throws -> TopicPublishReceipt {
        guard publishRequestID.range(of: "^[A-Za-z0-9_-]{16,64}$", options: .regularExpression) != nil else {
            throw TopicCreatorEditorIssue.invalid
        }
        var fields = idFields(topicID); fields["publishRequestId"] = publishRequestID
        if let configVersion { fields["configVersion"] = configVersion }
        if let registryVersion { fields["registryVersion"] = registryVersion }
        let data = try await write(.publishDraft, form: fields)
        let revision = data["contentRevisionNo"].editorText.flatMap { $0.range(of: "^[1-9][0-9]{0,17}$", options: .regularExpression) != nil ? $0 : nil }
        return TopicPublishReceipt(reviewState: data["reviewState"].text, contentRevisionNo: revision)
    }

    /// Host workbench `saveTier`: POST {chapterId, termsMode, maxMerchant, perkMinValue?, scope?}.
    public func saveSupplyTerms(_ terms: TopicChapterSupplyTerms) async throws {
        var fields = ["chapterId": String(terms.chapterID), "termsMode": terms.mode.rawValue, "maxMerchant": String(terms.maxMerchant)]
        if let value = terms.perkMinValue { fields["perkMinValue"] = value }
        if let scope { fields["scope"] = scope }
        _ = try await write(.supplyTerms, form: fields)
    }

    // MARK: wire

    private func idFields(_ topicID: Int64) -> [String: String] {
        var fields = ["id": String(topicID)]
        if let scope { fields["scope"] = scope }
        return fields
    }
    private func topicQuery(_ topicID: Int64) -> [URLQueryItem] {
        [URLQueryItem(name: "topicId", value: String(topicID))] + (scope.map { [URLQueryItem(name: "scope", value: $0)] } ?? [])
    }

    private func read(_ route: TopicCreatorEditorRoute, form: [String: String]) async throws -> PlayWireValue {
        try await send(route, request: try request(route.rawValue, method: "POST", form: form), write: false)
    }
    private func read(_ route: TopicCreatorEditorRoute, query: [URLQueryItem]) async throws -> PlayWireValue {
        var request = try request(route.rawValue, method: "GET")
        var parts = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        parts?.queryItems = query
        guard let url = parts?.url else { throw TopicCreatorEditorIssue.invalid }
        request.url = url
        return try await send(route, request: request, write: false)
    }
    private func write(_ route: TopicCreatorEditorRoute, form: [String: String]) async throws -> PlayWireValue {
        try await send(route, request: try request(route.rawValue, method: "POST", form: form), write: true)
    }
    private func write(_ route: TopicCreatorEditorRoute, method: String, path: String,
                       json: [String: PlayWireValue]) async throws -> PlayWireValue {
        var request = try request(path, method: method)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        request.httpBody = try encoder.encode(PlayWireValue.object(json))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(route, request: request, write: true)
    }

    private func request(_ path: String, method: String, form: [String: String]? = nil) throws -> URLRequest {
        guard enabled() else { throw TopicCreatorEditorIssue.disabled }
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else { throw TopicCreatorEditorIssue.unauthorized }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        if let form {
            request.httpBody = Data(Self.formEncoded(form).utf8)
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func send(_ route: TopicCreatorEditorRoute, request: URLRequest, write: Bool) async throws -> PlayWireValue {
        try Task.checkCancellation()
        guard enabled() else { throw TopicCreatorEditorIssue.disabled }
        let data: Data, status: Int
        do { (data, status) = try await transport.send(request) }
        catch { throw write ? TopicCreatorEditorIssue.outcomeUnknown : TopicCreatorEditorIssue.unavailable }
        if status == 401 { unauthorized(); throw TopicCreatorEditorIssue.unauthorized }
        guard status == 200, data.count <= 2_097_152,
              let envelope = try? JSONDecoder().decode(PlayWireValue.self, from: data), envelope.object != nil else {
            throw write ? TopicCreatorEditorIssue.outcomeUnknown : TopicCreatorEditorIssue.unavailable
        }
        let code = envelope["code"].tolerantInteger
        if code == 401 { unauthorized(); throw TopicCreatorEditorIssue.unauthorized }
        guard code == 200 else {
            if let message = envelope["msg"].text, !message.isEmpty { throw TopicCreatorEditorIssue.rejected(message) }
            throw TopicCreatorEditorIssue.unavailable
        }
        return envelope["data"]
    }

    static func formEncoded(_ fields: [String: String]) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._*"))
        return fields.keys.sorted().map { key in
            let value = fields[key] ?? ""
            let encode: (String) -> String = { ($0.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") }
            return encode(key) + "=" + encode(value)
        }.joined(separator: "&")
    }

    static func decimalID(_ value: String) -> Bool {
        value.range(of: "^[1-9][0-9]{0,18}$", options: .regularExpression) != nil
            && (value.count < 19 || value <= "9223372036854775807")
    }

    /// `isEditingTopicPayload`: `topic` is a record; chapters/tickets are record lists when present.
    static func detail(_ data: PlayWireValue, topicID: Int64) throws -> TopicAuthorDetail {
        guard let topic = data["topic"].object else { throw TopicCreatorEditorIssue.malformed }
        for key in ["chapters", "tickets"] where data[key] != .null {
            guard let rows = data[key].array, rows.allSatisfy({ $0.object != nil }) else { throw TopicCreatorEditorIssue.malformed }
        }
        for chapter in data["chapters"].array ?? [] where chapter["cmsTopicNodeList"] != .null {
            guard let nodes = chapter["cmsTopicNodeList"].array, nodes.allSatisfy({ $0.object != nil }) else {
                throw TopicCreatorEditorIssue.malformed
            }
        }
        if let id = PlayWireValue.object(topic)["id"].editorText, id != String(topicID) { throw TopicCreatorEditorIssue.malformed }
        let rules = data["journeyRules"].text ?? topic["journeyRulesJson"]?.text
        return TopicAuthorDetail(topicID: String(topicID), name: topic["name"]?.text ?? "",
            isDraft: data["isDraft"].bool == true, configVersion: topic["configVersion"]?.editorText,
            chapterCount: data["chapters"].array?.count ?? 0, journeyRules: rules)
    }

    /// `attribute-binding.js snapshot`: same topic, unique valid keys, matching type, known scopes, sane ranges.
    static func registry(_ data: PlayWireValue, topicID: Int64, configVersion: String) throws -> TopicAttributeRegistry {
        guard data["topicId"].editorText == String(topicID), let rows = data["definitions"].array,
              let registryVersion = data["registryVersion"].editorText,
              registryVersion.range(of: "^[1-9][0-9]*$", options: .regularExpression) != nil else {
            throw TopicCreatorEditorIssue.malformed
        }
        var seen = Set<String>()
        let types = ["clue": "flag", "tag": "tag", "counter": "counter", "relation": "relation"]
        let definitions = try rows.map { row -> TopicAttributeDefinition in
            guard let key = row["stateKey"].text, key.range(of: stateKeyPattern, options: .regularExpression) != nil,
                  seen.insert(key).inserted, let prefix = key.split(separator: ".").first,
                  row["keyType"].text == types[String(prefix)],
                  let persist = row["persistScope"].text, ["run", "topic"].contains(persist),
                  let scope = row["scope"].text, ["run", "party", "deployment"].contains(scope),
                  let initial = row["initialValue"].integer, let minimum = row["minValue"].integer,
                  let maximum = row["maxValue"].integer, minimum <= initial, initial <= maximum,
                  let visible = row["visible"].bool else { throw TopicCreatorEditorIssue.malformed }
            return TopicAttributeDefinition(stateKey: key, label: row["label"].text ?? "", keyType: row["keyType"].text ?? "",
                scope: scope, persistScope: persist, initialValue: initial, minValue: minimum, maxValue: maximum, visible: visible,
                fields: ProjectAttributeBinding.registryFields(row))
        }
        return TopicAttributeRegistry(topicID: String(topicID), configVersion: configVersion,
                                      registryVersion: registryVersion, definitions: definitions)
    }
}

fileprivate extension PlayWireValue {
    /// A decimal id or version sent either as a JSON string or a safe JSON integer.
    var editorText: String? {
        switch self {
        case .string(let value): return value
        case .integer(let value): return String(value)
        default: return nil
        }
    }
}
