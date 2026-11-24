import Foundation
import Observation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// G1 play runtime. Mini-program `pages/play` reads and non-money writes that had no native caller:
/// check roll/reroll/settle + receipt (`utils/journey-check-recovery.js`), advanced receipt
/// (`components/advanced-game`), shared help (`utils/coop-help*.js`), history (`utils/play-history.js`),
/// setup (`pages/topic/index` `_loadPrep`), theme gameplay preview/action and the shared preview
/// (`utils/theme-backpack.js`, `utils/theme-trade.js`), and contact (`utils/play-hud-overlays.js`).
/// The server rolls and settles. Nothing here rolls, scores or decides a result locally.
public struct PlayRuntimeEnvelope: Equatable {
    public let status: Int
    public let code: Int?
    public let msg: String?
    public let errorCode: String?
    public let data: PlayWireValue
    public var ok: Bool { (200..<300).contains(status) && code == 200 }
}

public enum PlayRuntimeError: Error, Equatable {
    case invalidRequest
    case unauthorized
    /// Transport loss, a non-2xx status, or an unreadable body. The write may have landed.
    case unknown
}

/// One request per call. No retry, no URLSession fallback. The composition transport decides admission.
public struct PlayRuntimeClient {
    public let baseURL: URL
    public let token: String
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: String) throws {
        guard AuthRequestBuilder.isValidToken(token) else { throw PlayRuntimeError.invalidRequest }
        baseURL = configuration.baseURL; self.transport = transport; self.token = token
    }

    public func get(_ path: String, query: [String: String]) async throws -> PlayRuntimeEnvelope {
        var request = try base(path)
        if !query.isEmpty {
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.url = components.url
        }
        request.httpMethod = "GET"
        return try await send(request)
    }

    /// Mini-program `req` without a header: `application/x-www-form-urlencoded`.
    public func postForm(_ path: String, fields: [String: String]) async throws -> PlayRuntimeEnvelope {
        guard !fields.isEmpty else { throw PlayRuntimeError.invalidRequest }
        var request = try base(path)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics; allowed.insert(charactersIn: "-._*")
        request.httpBody = Data(fields.sorted { $0.key < $1.key }.map { key, value in
            (key.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") + "=" + (value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
        }.joined(separator: "&").utf8)
        return try await send(request)
    }

    /// `{ 'content-type': 'application/json' }`. Keys are sorted so a kept retry re-encodes identically.
    public func postJSON(_ path: String, body: [String: PlayWireValue]) async throws -> PlayRuntimeEnvelope {
        var request = try base(path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        request.httpBody = try encoder.encode(body)
        return try await send(request)
    }

    private func base(_ path: String) throws -> URLRequest {
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.first == "api", segments.count > 1, segments.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        } }) else { throw PlayRuntimeError.invalidRequest }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.timeoutInterval = 20; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send(_ request: URLRequest) async throws -> PlayRuntimeEnvelope {
        let data: Data, status: Int
        do { (data, status) = try await transport.send(request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw PlayRuntimeError.unknown }
        let raw = try? JSONDecoder().decode(PlayWireValue.self, from: data)
        let code = raw?["code"].tolerantInteger
        if status == 401 || code == 401 { throw PlayRuntimeError.unauthorized }
        guard let raw, raw.object != nil else { throw PlayRuntimeError.unknown }
        return PlayRuntimeEnvelope(status: status, code: code, msg: raw["msg"].text, errorCode: raw["errorCode"].text, data: raw["data"])
    }
}

extension PlayWireValue {
    /// `orient-score-view.js` `id()`: a positive safe integer, as number or decimal text.
    public var playPositiveID: Int? {
        guard let value = tolerantInteger, value > 0 else { return nil }
        if let text, text.trimmingCharacters(in: .whitespaces) != String(value) { return nil }
        return value
    }
}

// MARK: - Journey check (D20): roll / reroll / settle / receipt

/// `_journeyOriginal()`: owner, route session, node, check, topic and activity (`"0"` when topic-only).
public struct PlayCheckOriginal: Codable, Equatable, Sendable {
    public let owner: Int; public let sessionID: Int; public let nodeID: Int; public let checkID: String
    public let topicID: Int; public let activityID: Int
    public init?(owner: Int, sessionID: Int?, nodeID: Int, checkID: String, topicID: Int, activityID: Int?) {
        guard owner > 0, let sessionID, sessionID > 0, nodeID > 0, topicID > 0,
              checkID.range(of: "^[A-Za-z0-9_-]{1,64}$", options: .regularExpression) != nil else { return nil }
        self.owner = owner; self.sessionID = sessionID; self.nodeID = nodeID; self.checkID = checkID
        self.topicID = topicID; self.activityID = max(0, activityID ?? 0)
    }
    /// `'journey-original:' + [owner, sessionId, nodeId, checkId].join(':')`
    public var storageKey: String { "journey-original:\(owner):\(sessionID):\(nodeID):\(checkID)" }
}

/// The one write that may be in flight. Its `actionId` is the server's idempotent receipt id.
public struct PlayCheckPending: Codable, Equatable, Sendable {
    public let scope: PlayCheckOriginal
    public let action: String
    public let actionID: String
    public init(scope: PlayCheckOriginal, action: JourneyCheckAction) {
        self.scope = scope; self.action = action.rawValue
        actionID = "check:\(scope.nodeID):\(scope.checkID):\(action.rawValue)"
    }
}

@MainActor public protocol PlayCheckPendingStore: AnyObject {
    func read(_ key: String) throws -> PlayCheckPending?
    func write(_ pending: PlayCheckPending?, key: String) throws
}

@MainActor public final class PlayCheckMemoryPendingStore: PlayCheckPendingStore {
    public private(set) var values: [String: PlayCheckPending] = [:]
    public var failing = false
    public init() {}
    public func read(_ key: String) throws -> PlayCheckPending? {
        if failing { throw PlayRuntimeError.unknown }
        return values[key]
    }
    public func write(_ pending: PlayCheckPending?, key: String) throws {
        if failing { throw PlayRuntimeError.unknown }
        values[key] = pending
    }
}

/// `pages/play/utils/journey-check-recovery.js` `_legacyCheckAction`, line for line.
/// A sent write keeps its pending record until a matching receipt (same session, node, check and
/// `actionId`) or an explicit `CHECK_REJECTED` / `CHECK_BAD_REQUEST`. Anything else is unknown, and
/// the only way out of unknown is `recover`: `GET api/play/check/receipt` for the original action.
@available(macOS 14.0, *)
@MainActor @Observable public final class PlayCheckRuntime {
    public enum Action: String { case roll, reroll, settle, recover }
    public let original: PlayCheckOriginal
    public let problem: JourneyCheckProblem
    public private(set) var receipt: JourneyCheckReceipt?
    /// `detailsHidden`: a redacted receipt shows the verdict and settle text only.
    public private(set) var detailsHidden = false
    public private(set) var unknown = false
    public private(set) var loading = false
    public private(set) var disabledReason = ""
    private let client: @MainActor () -> PlayRuntimeClient?
    private let store: any PlayCheckPendingStore
    private var acting = false

    public init(original: PlayCheckOriginal, problem: JourneyCheckProblem, store: any PlayCheckPendingStore,
                client: @escaping @MainActor () -> PlayRuntimeClient?) {
        self.original = original; self.problem = problem; self.store = store; self.client = client
        restore()
    }

    public var canRoll: Bool { !unknown && !loading && receipt == nil && !acting }
    public var canReroll: Bool { !unknown && !loading && receipt?.canReroll == true }
    public var canSettle: Bool { !unknown && !loading && receipt != nil && receipt?.settled == false }

    /// `_restoreJourneyCheck()`
    public func restore() {
        do {
            if try store.read(original.storageKey) != nil {
                unknown = true; disabledReason = "原检定结果待确认，请再次查询"
            }
        } catch { unknown = true; disabledReason = "原检定记录无法读取，暂不提交新动作" }
    }

    public func perform(_ action: Action) async {
        guard !acting else { return }
        let key = original.storageKey
        var pending: PlayCheckPending?
        do {
            pending = try store.read(key)
            if let found = pending, JourneyCheckAction(rawValue: found.action) == nil || found.scope != original { throw PlayRuntimeError.invalidRequest }
            if action == .recover && pending == nil { return }
            if pending != nil && action != .recover { restore(); return }
            if pending == nil {
                guard let write = JourneyCheckAction(rawValue: action.rawValue) else { return }
                let created = PlayCheckPending(scope: original, action: write)
                try store.write(created, key: key); pending = created
            }
        } catch {
            unknown = true; disabledReason = "原检定记录无法保存或读取，暂不提交新动作"; return
        }
        guard let pending, let client = client() else { markUnknown(); return }
        acting = true; loading = true; unknown = true
        let read = action == .recover
        let response: PlayRuntimeEnvelope
        do {
            if read {
                response = try await client.get("api/play/check/receipt", query: [
                    "sessionId": String(original.sessionID), "nodeId": String(original.nodeID),
                    "checkId": original.checkID, "action": pending.action])
            } else {
                response = try await client.postForm("api/play/check/" + action.rawValue, fields: [
                    "topicId": String(original.topicID), "activityId": String(original.activityID),
                    "sessionId": String(original.sessionID), "nodeId": String(original.nodeID), "checkId": original.checkID])
            }
        } catch { markUnknown(); return }
        if !read, let code = response.errorCode, ["CHECK_REJECTED", "CHECK_BAD_REQUEST"].contains(code) {
            try? store.write(nil, key: key)
            acting = false; loading = false; unknown = false
            disabledReason = response.msg ?? "本次检定未被接受，请确认后重新操作"
            return
        }
        let data = response.data
        guard response.code == 200, data.object != nil, data["sessionId"].playPositiveID == original.sessionID,
              data["nodeId"].playPositiveID == original.nodeID, data["checkId"].text == original.checkID,
              data["actionId"].text == pending.actionID, let parsed = try? JourneyCheckReceipt(data) else { markUnknown(); return }
        try? store.write(nil, key: key)
        acting = false; loading = false; unknown = false; disabledReason = ""
        receipt = parsed; detailsHidden = Self.hidden(data)
    }

    private func markUnknown() {
        acting = false; loading = false; unknown = true
        disabledReason = "原检定结果待确认，请再次查询；未查到不代表未写入"
    }

    /// `checkReceiptView` hidden test: a redacted receipt never leaks totals, modifiers or dice.
    static func hidden(_ r: PlayWireValue) -> Bool {
        let b = r["breakdown"]
        return r["detailsHidden"].bool == true || r["hidden"].bool == true || r["redacted"].bool == true
            || b["hidden"].bool == true || b["redacted"].bool == true
            || b["skill"]["hidden"].bool == true || b["skill"]["redacted"].bool == true
            || b["situational"]["hidden"].bool == true || b["situational"]["redacted"].bool == true
    }

    /// `marginText`: 过线 N 点 / 正好过线 / 差 N 点. Empty when hidden or a number is missing.
    public static func marginText(_ receipt: JourneyCheckReceipt?, hidden: Bool = false) -> String {
        guard let receipt, !hidden, let total = receipt.total, let dc = receipt.dc else { return "" }
        let diff = total - dc
        return diff > 0 ? "过线 \(diff) 点" : diff == 0 ? "正好过线" : "差 \(-diff) 点"
    }

    /// `natTag`
    public static func natTag(_ receipt: JourneyCheckReceipt?) -> String {
        receipt?.nat == "CRIT" ? "天然 20" : receipt?.nat == "FUMBLE" ? "天然 1 · 手滑了" : ""
    }
}

// MARK: - Advanced receipt

public enum PlayAdvancedReceipt {
    /// `resolveUnknown()`: `GET api/play/advanced/receipt {sessionId, idempotencyKey}`. Only a receipt for the
    /// same session and key proves the original request; it returns the `view` to hydrate.
    public static func read(client: PlayRuntimeClient, sessionID: Int, idempotencyKey: String) async throws -> PlayWireValue {
        guard sessionID > 0, !idempotencyKey.isEmpty else { throw PlayRuntimeError.invalidRequest }
        let response = try await client.get("api/play/advanced/receipt",
            query: ["sessionId": String(sessionID), "idempotencyKey": idempotencyKey])
        let receipt = response.data
        guard response.ok, receipt["sessionId"].playPositiveID == sessionID,
              receipt["idempotencyKey"].text == idempotencyKey, receipt["view"].object != nil else { throw PlayRuntimeError.unknown }
        return receipt["view"]
    }
}

// MARK: - Shared (team) help: VIEW / USE / SKIP

/// `utils/coop-help.js`. Free uses are pooled per team; a USE may charge points the server reports.
public enum PlayCoopHelp {
    public static let capability = "game.teamCooperation@1"
    public enum Operation: String { case view = "VIEW", use = "USE", skip = "SKIP" }
    public struct Row: Equatable, Identifiable {
        public enum State: String { case unlocked, off, free, cost }
        public let level: Int; public let title: String; public let state: State; public let actionText: String
        public var id: Int { level }
    }
    public struct Skip: Equatable { public let level: Int; public let usable: Bool; public let reason: String }
    public enum Outcome: Equatable { case ok(PlayWireValue), rejected(String), unknown }

    static var typeText: [String: String] {
        ["TEXT": W8Text.t("文字提示", "Text hint"), "IMAGE": W8Text.t("图片提示", "Picture hint"), "LETTER": W8Text.t("揭示字母", "Reveal a letter"),
         "DIGIT": W8Text.t("揭示数字", "Reveal a digit"), "ANSWER": W8Text.t("查看答案", "Show the answer")]
    }
    static var reasonText: [String: String] {
        ["REAL_OPERATION_REQUIRED": W8Text.t("需要现场完成，不能跳过", "Must be done on site; it can’t be skipped"),
         "HELP_TYPE_UNSUPPORTED": W8Text.t("暂不支持这种提示", "This hint type isn’t supported yet"),
         "INSUFFICIENT_POINTS": W8Text.t("积分不足", "Not enough points")]
    }

    /// The open instance for `questKey`, else the last one.
    public static func question(_ cooperation: PlayWireValue, questKey: String) -> PlayWireValue? {
        let mine = (cooperation["questions"].array ?? []).filter { $0["questKey"].text == questKey && $0["runtimeInstance"] != .null }
        return mine.first { $0["completedAt"] == .null && $0["cancelledAt"] == .null } ?? mine.last
    }

    public static func canHelp(_ cooperation: PlayWireValue, questKey: String) -> Bool {
        guard let q = question(cooperation, questKey: questKey) else { return false }
        return q["nodeId"].integer != nil && cooperation["gameSessionId"].integer != nil
            && cooperation["authorityEpoch"].integer != nil && q["completedAt"] == .null && q["cancelledAt"] == .null
    }

    public static func body(activityID: Int, cooperation: PlayWireValue, questKey: String, operation: Operation,
                            level: Int?, requestID: String?) -> [String: PlayWireValue]? {
        guard let q = question(cooperation, questKey: questKey) else { return nil }
        let instance = q["runtimeInstance"].text ?? q["runtimeInstance"].integer.map(String.init) ?? ""
        var body: [String: PlayWireValue] = [
            "activityId": .integer(Int64(activityID)), "gameSessionId": cooperation["gameSessionId"], "nodeId": q["nodeId"],
            "runtimeInstance": .string(instance), "authorityEpoch": cooperation["authorityEpoch"],
            "capabilities": .string(capability), "operation": .string(operation.rawValue)]
        if operation != .view {
            guard let requestID, !requestID.isEmpty else { return nil }
            body["requestId"] = .string(requestID)
        }
        if operation == .use {
            guard let level else { return nil }
            body["level"] = .integer(Int64(level))
        }
        return body
    }

    public static func rows(_ levels: PlayWireValue) -> (rows: [Row], skip: Skip?) {
        var rows: [Row] = []; var skip: Skip?
        for l in levels.array ?? [] {
            guard let level = l["level"].integer else { continue }
            let reason = l["reason"].text.flatMap { reasonText[$0] }
            if l["type"].text == "SKIP" {
                let usable = l["usable"].bool == true
                skip = Skip(level: level, usable: usable, reason: reason ?? (usable ? "" : W8Text.t("暂不可跳过", "Can’t be skipped now"))); continue
            }
            if l["type"].text == "LOCATION" { continue }
            let state: Row.State, text: String
            if l["unlocked"].bool == true { state = .unlocked; text = W8Text.t("重看", "View again") }
            else if l["usable"].bool != true { state = .off; text = reason ?? W8Text.t("不可用", "Unavailable") }
            else if l["free"].bool == true || !((l["costPoints"].integer ?? 0) > 0) { state = .free; text = W8Text.t("免费", "Free") }
            else { state = .cost; text = W8Text.t("消耗 \(l["costPoints"].integer ?? 0) 积分", "Costs \(l["costPoints"].integer ?? 0) points") }
            rows.append(Row(level: level, title: l["type"].text.flatMap { typeText[$0] } ?? W8Text.t("提示", "Hint"), state: state, actionText: text))
        }
        return (rows, skip)
    }

    public static func freeText(_ remaining: PlayWireValue) -> String {
        remaining.integer.map { W8Text.t("本局剩余免费 \($0) 次", "\($0) free left this run") } ?? ""
    }

    public static func newRequestID() -> String { "coop-" + UUID().uuidString.lowercased() }

    /// `POST api/play/help/shared`. A lost response is unknown; retry with the same request id only.
    public static func send(client: PlayRuntimeClient, body: [String: PlayWireValue]) async -> Outcome {
        do {
            let response = try await client.postJSON("api/play/help/shared", body: body)
            // `res.httpFail`: an HTTP status outside 2xx proves nothing about the write.
            guard (200..<300).contains(response.status) else { return .unknown }
            if response.code == 200, response.data.object != nil { return .ok(response.data) }
            return .rejected(response.msg ?? "操作失败")
        } catch { return .unknown }
    }
}

// MARK: - History (completed run, read-only)

public struct PlayHistoryScope: Equatable, Sendable {
    public let owner: Int; public let activityID: Int; public let topicID: Int; public let routeSessionID: Int
    public init?(owner: Int, activityID: Int?, topicID: Int, routeSessionID: Int?) {
        guard owner > 0, topicID > 0, let routeSessionID, routeSessionID > 0, (activityID ?? 0) >= 0 else { return nil }
        self.owner = owner; self.activityID = activityID ?? 0; self.topicID = topicID; self.routeSessionID = routeSessionID
    }
    var query: [String: String] {
        ["activityId": String(activityID), "topicId": String(topicID), "routeSessionId": String(routeSessionID)]
    }
}

public struct PlayHistoryProjection: Equatable {
    public struct Node: Equatable { public let nodeID: Int; public let chapterID: Int?; public let name: String; public let story: String }
    public struct Chapter: Equatable { public let id: Int; public let lines: [String] }
    public let scope: PlayHistoryScope
    public let configVersion: Int
    public let narrativeAvailable: Bool
    public let nodes: [Node]
    public let chapters: [Chapter]

    /// `play-history.js` `project()`: read-only, same scope, config pinned, every node done+history,
    /// node ids unique, chapter blocks reference known nodes only. Any break drops the whole read.
    public static func project(_ data: PlayWireValue, scope: PlayHistoryScope, configVersion expected: Int?) -> PlayHistoryProjection? {
        guard data["readOnly"].bool == true, data["routeSessionId"].playPositiveID == scope.routeSessionID,
              (data["activityId"].tolerantInteger ?? -1) == scope.activityID, data["topicId"].playPositiveID == scope.topicID,
              let config = data["configVersion"].playPositiveID, expected == nil || expected == config,
              let rawNodes = data["nodes"].array, let rawChapters = data["chapters"].array else { return nil }
        var nodes: [Node] = []
        for row in rawNodes {
            guard let id = row["nodeId"].playPositiveID, row["done"].bool == true, row["history"].bool == true,
                  row["results"].array != nil else { return nil }
            var chapter: Int?
            if row["chapterId"] != .null { guard let value = row["chapterId"].playPositiveID else { return nil }; chapter = value }
            nodes.append(Node(nodeID: id, chapterID: chapter, name: row["name"].text ?? "", story: row["storyText"].text ?? ""))
        }
        guard Set(nodes.map(\.nodeID)).count == nodes.count else { return nil }
        var chapters: [Chapter] = []
        if data["narrativeAvailable"].bool == true {
            for row in rawChapters {
                guard let id = row["chapterId"].playPositiveID, row["complete"].bool == true, let blocks = row["blocks"].array else { return nil }
                var lines: [String] = []
                for block in blocks where block["beat"] == .null && block["when"] == .null {
                    switch block["type"].text {
                    case "node":
                        guard let node = block["nodeId"].playPositiveID, let found = nodes.first(where: { $0.nodeID == node }) else { return nil }
                        if !found.story.isEmpty { lines.append(found.story) }
                    case "text", "voice":
                        let content = block["content"].text ?? ""
                        let line = (block["who"].text).map { $0.isEmpty ? content : $0 + "：" + content } ?? content
                        if !line.isEmpty { lines.append(line) }
                    default: break
                    }
                }
                chapters.append(Chapter(id: id, lines: lines))
            }
            guard Set(chapters.map(\.id)).count == chapters.count else { return nil }
        }
        return PlayHistoryProjection(scope: scope, configVersion: config, narrativeAvailable: data["narrativeAvailable"].bool == true,
                                     nodes: nodes, chapters: chapters)
    }

    /// `GET api/play/history {activityId, topicId, routeSessionId}`. A failed or mismatched read is nil, never partial.
    public static func read(client: PlayRuntimeClient, scope: PlayHistoryScope, configVersion: Int?) async -> PlayHistoryProjection? {
        guard let response = try? await client.get("api/play/history", query: scope.query), response.ok else { return nil }
        return project(response.data, scope: scope, configVersion: configVersion)
    }
}

// MARK: - Setup (开局前准备)

public struct PlayTopicSetup: Equatable {
    public struct Item: Equatable, Identifiable { public let index: Int; public let text: String; public var id: Int { index } }
    public let items: [Item]
    /// Empty when the window is unrestricted (`mode` missing or `any`).
    public let windowText: String
    public let closed: Bool

    /// `_buildPrep`: at most six trimmed prep items; a play window only when it is not `any`.
    /// Nil when neither is configured, so the row does not show.
    public init?(_ data: PlayWireValue) {
        items = Array((data["prepItems"].array ?? []).compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.prefix(6)).enumerated().map { Item(index: $0.offset, text: $0.element) }
        let window = data["playWindow"]
        let mode = window["mode"].text ?? ""
        let restricted = !mode.isEmpty && mode != "any"
        guard !items.isEmpty || restricted else { return nil }
        windowText = !restricted ? "" : mode == "night" ? "夜间 20:00–06:00" : mode == "day" ? "白天 06:00–20:00"
            : (window["start"].text ?? "") + "–" + (window["end"].text ?? "")
        closed = restricted && data["openNow"].bool == false
    }

    public func rowText(ticked: Set<Int>) -> String {
        let left = items.filter { !ticked.contains($0.index) }.count
        if closed { return "开局前准备 · " + windowText + " 开放" }
        return left > 0 ? "开局前准备 · 还有 \(left) 项未勾选" : "开局前准备 · 已全部勾选"
    }

    public func ready(ticked: Set<Int>) -> Bool { !closed && items.allSatisfy { ticked.contains($0.index) } }

    public enum Read: Equatable { case hidden, failed, loaded(PlayTopicSetup) }

    /// `GET api/play/setup {topicId}`. A read that fails shows 「开局前准备加载失败 · 轻点重试」.
    public static func read(client: PlayRuntimeClient, topicID: Int) async -> Read {
        guard topicID > 0, let response = try? await client.get("api/play/setup", query: ["topicId": String(topicID)]),
              response.ok, response.data != .null else { return .failed }
        return PlayTopicSetup(response.data).map(Read.loaded) ?? .hidden
    }
}

// MARK: - Contact (联系主办 / 联系商家)

public struct PlayContact: Equatable {
    public let merchant: Bool; public let name: String; public let phone: String
    public var label: String { merchant ? "联系商家" : "联系主办" }

    /// `contact(raw)`: a phone of 3–32 dial characters, else nothing shows.
    public init?(_ raw: PlayWireValue) {
        guard raw.object != nil, let phone = raw["phone"].text?.trimmingCharacters(in: .whitespacesAndNewlines),
              phone.range(of: "^[0-9+\\-\\s()]{3,32}$", options: .regularExpression) != nil else { return nil }
        merchant = (raw["kind"].text ?? "").uppercased() == "MERCHANT"
        name = String((raw["name"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        self.phone = phone
    }

    /// `loadPlayContact`: `{activityId}` for an activity run, else `{topicId, nodeId?}`.
    public static func read(client: PlayRuntimeClient, scope: PlaySessionScope, currentNodeID: Int?) async -> PlayContact? {
        var query: [String: String]
        switch scope {
        case .activity(let id): query = ["activityId": String(id)]
        case .topic(let id):
            query = ["topicId": String(id)]
            if let node = currentNodeID, node > 0 { query["nodeId"] = String(node) }
        }
        guard scope.isValid, let response = try? await client.get("api/play/contact", query: query), response.ok else { return nil }
        return PlayContact(response.data)
    }
}

// MARK: - Theme gameplay (personal) and the shared (team) preview

public enum PlayThemeGameplayExchange {
    public enum Outcome: Equatable { case applied(PlayWireValue), rejected(String), unknown }

    /// SOLO command: `{sessionId, expectedVersion, actionId, operation, contentId, ...selections}`.
    public static func command(view: PlayWireValue, operation: String, contentID: String, actionID: String,
                               selections: [String: PlayWireValue] = [:]) -> [String: PlayWireValue]? {
        guard view["scope"].text != "TEAM", let session = view["sessionId"].playPositiveID, let version = view["version"].integer,
              !operation.isEmpty, !contentID.isEmpty, !actionID.isEmpty else { return nil }
        var body = selections.filter { ["costOption", "choiceKey", "discardRewards", "previewVersion", "discardOwned", "weRun", "participants"].contains($0.key) }
        body["sessionId"] = .integer(Int64(session)); body["expectedVersion"] = .integer(Int64(version))
        body["actionId"] = .string(actionID); body["operation"] = .string(operation); body["contentId"] = .string(contentID)
        return body
    }

    public static func newActionID() -> String { "theme_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "") }

    /// `POST api/play/theme/gameplay-action`. Applied only when the receipt names the same session with an integer version.
    /// A transport loss or a 200 without that proof is unknown; retry resends the kept command.
    public static func action(client: PlayRuntimeClient, command: [String: PlayWireValue]) async -> Outcome {
        guard let response = try? await client.postJSON("api/play/theme/gameplay-action", body: command) else { return .unknown }
        let receipt = response.data
        if response.ok, receipt.object != nil, receipt["sessionId"].playPositiveID == command["sessionId"]?.integer,
           receipt["version"].integer != nil { return .applied(receipt) }
        if response.code == 200 || !(200..<300).contains(response.status) { return .unknown }
        return .rejected(response.msg ?? "操作失败")
    }

    /// `POST api/play/theme/gameplay-preview` (SOLO) with the reward-preview pack check.
    public static func preview(client: PlayRuntimeClient, view: PlayWireValue, operation: String, contentID: String,
                               choices: [String: PlayWireValue] = [:]) async -> (pack: PlayThemeRewardPreview?, version: Int?, error: String) {
        guard let session = view["sessionId"].playPositiveID, let version = view["version"].integer else { return (nil, nil, "奖励预览暂未加载，请重新读取") }
        var body = choices.filter { ["choiceKey", "costOption", "discardRewards", "participants"].contains($0.key) }
        body["sessionId"] = .integer(Int64(session)); body["expectedVersion"] = .integer(Int64(version))
        body["operation"] = .string(operation); body["contentId"] = .string(contentID)
        let response = try? await client.postJSON("api/play/theme/gameplay-preview", body: body)
        guard let response, response.ok, let pack = PlayThemeRewardsRules.preview(response.data, view: view),
              response.data["sessionId"].playPositiveID == session, let next = response.data["version"].integer else {
            return (nil, nil, response?.msg ?? "奖励预览暂未加载，请重新读取")
        }
        return (pack, next, "")
    }

    /// `POST api/game/session/shared/preview {activityId, action, payload}` (player side; never a write).
    /// Valid only with integer `expectedRevision` and `authorityEpoch`.
    public static func sharedPreview(client: PlayRuntimeClient, activityID: Int, action: String,
                                     payload: [String: PlayWireValue]) async -> (data: PlayWireValue?, error: String) {
        guard activityID > 0, !action.isEmpty else { return (nil, "预览暂未加载，请重新读取") }
        let response = try? await client.postJSON("api/game/session/shared/preview", body: [
            "activityId": .integer(Int64(activityID)), "action": .string(action), "payload": .object(payload)])
        guard let response, response.ok, response.data["expectedRevision"].integer != nil,
              response.data["authorityEpoch"].integer != nil else { return (nil, response?.msg ?? "预览暂未加载，请重新读取") }
        return (response.data, "")
    }
}

// MARK: - Run session end tombstone

public enum PlayRunSessionClear {
    /// `clearServerRunSession`: `POST api/play/run-session/clear {savedAt, activityId | topicId}` when a run ends,
    /// so another device does not restore a finished run. Failure is silent; the local state is unaffected.
    /// `pages/play` `req` sends this as `application/x-www-form-urlencoded` (no request header).
    public static func clear(client: PlayRuntimeClient, scope: PlaySessionScope, savedAt: Int64) async -> Bool {
        guard scope.isValid, savedAt > 0 else { return false }
        var fields = ["savedAt": String(savedAt)]
        switch scope {
        case .activity(let id): fields["activityId"] = String(id)
        case .topic(let id): fields["topicId"] = String(id)
        }
        return (try? await client.postForm("api/play/run-session/clear", fields: fields))?.ok == true
    }
}

public enum PlayRunSessionSave {
    /// `saveServerPausedRun`: `POST api/play/run-session/save` urlencoded
    /// `{elapsedSeconds, savedAt, activityId | topicId}`. One scope id, never both.
    /// Failure is silent. This does not replace `PlayExperienceService.savePaused`, which stays multipart.
    public static func save(client: PlayRuntimeClient, scope: PlaySessionScope, elapsedSeconds: Int, savedAt: Int64) async -> Bool {
        guard scope.isValid, (0...PlayPausedRecord.maximumSeconds).contains(elapsedSeconds), savedAt > 0 else { return false }
        var fields = ["elapsedSeconds": String(elapsedSeconds), "savedAt": String(savedAt)]
        switch scope {
        case .activity(let id): fields["activityId"] = String(id)
        case .topic(let id): fields["topicId"] = String(id)
        }
        return (try? await client.postForm("api/play/run-session/save", fields: fields))?.ok == true
    }
}
