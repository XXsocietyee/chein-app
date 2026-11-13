import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// G5 template routes. Ports:
/// - `pages/publish/utils/publish/template-adoption.js` (`resume`): adoption-source → adopt-draft → adoption-receipt →
///   adoption-detail / author-myinfo, journaled so no retry mints a new request ID
/// - `pages/publish/temp/index.js` detail read: `author-myinfo` (my scope) or `author-info`
/// - `pages/publish/components/location-todos` + `utils/publish/location-todos.js`: binding-status / binding
/// - `subpackageA/pages/myproject` save-as (BL-120) and `{id}/market-submit`
public struct TemplateAdoptionService {
    public static let sourcePath = "api/template/adoption-source"
    public static let adoptPath = "api/template/adopt-draft"
    public static let receiptPath = "api/template/adoption-receipt"
    public static let detailPath = "api/template/adoption-detail"
    public static let authorMyInfoPath = "api/template/author-myinfo"
    public static let authorInfoPath = "api/template/author-info"
    public static let bindingStatusPath = "api/template/topic-template/binding-status"
    public static let bindingPath = "api/template/topic-template/binding"
    public static let saveAsPath = "api/template/topic-template/save-as"
    public static func marketSubmitPath(_ id: Int) -> String { "api/template/\(id)/market-submit" }

    let client: PlayerCapabilityClient
    public init(client: PlayerCapabilityClient) { self.client = client }

    // MARK: Adoption journal

    /// `author:template-adoption:v1:<owner>:<scope>:<sourceId>` record. Only requestId-bearing records use receipts.
    public struct Record: Codable, Equatable {
        public let schemaVersion: Int
        public let owner: String
        public let scope: String
        public let requestId: String
        public let sourceVersion: String
        public let originalTemplateId: String
        public var draftId: String?
    }

    public enum Outcome: Equatable {
        /// The adopted draft detail (`advancedConfigJson` present); the journal is cleared.
        case ready(SquareGovernanceJSON)
        /// 「原采用被拒绝…」 / 「当前身份还没解锁…」 / 「原采用未通过…」; the journal is cleared.
        case rejected(String)
        /// Unconfirmed; the journal stays so the next attempt reuses the same request ID.
        case unconfirmed(String)
    }

    static func exactID(_ value: SquareGovernanceJSON) -> String? {
        if let text = value.string, text.first != "0", (1...19).contains(text.count), text.allSatisfy({ $0.isASCII && $0.isNumber }),
           text.count < 19 || text <= "9223372036854775807" { return text }
        if let number = value.int, number > 0 { return String(number) }
        return nil
    }

    static func isSourceVersion(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) }
    }

    public static func newRequestID(now: Date = Date()) -> String {
        "adopt_\(Int64(now.timeIntervalSince1970 * 1000))_" + String(UInt64.random(in: 1...UInt64(UInt32.max)) << 20, radix: 36)
    }

    func sourceRequest(sourceID: String, scope: String) throws -> URLRequest {
        try client.getRequest(Self.sourcePath, query: [("originalTemplateId", sourceID), ("scope", scope)])
    }
    func adoptRequest(_ record: Record) throws -> URLRequest {
        try client.jsonRequest(Self.adoptPath, body: [
            "requestId": .string(record.requestId), "originalTemplateId": .string(record.originalTemplateId),
            "sourceVersion": .string(record.sourceVersion), "scope": .string(record.scope)
        ])
    }

    /// `resume`. `load`/`save`/`clear` are the caller's per-owner journal (the mini-program's storage).
    public func adopt(sourceID rawSource: Int, owner: Int, scope: String,
                      load: () throws -> Record?, save: (Record) throws -> Void, clear: () -> Void) async -> Outcome {
        guard rawSource > 0, owner > 0 else { return .unconfirmed("采用身份或来源编号无效") }
        let sourceID = String(rawSource)
        var record: Record
        do {
            if let saved = try load() {
                guard saved.schemaVersion == 1, saved.owner == String(owner), saved.scope == scope,
                      saved.originalTemplateId == sourceID else { return .unconfirmed("采用恢复记录无法读取，请保留记录核查") }
                record = saved
                if let draft = saved.draftId { return await loadDraft(record, draftID: draft, clear: clear) }
                // Receipt first: PENDING/UNKNOWN resubmits the SAME command, anything else is accepted as-is.
                guard let receipt = try? await client.read(try client.getRequest(Self.receiptPath,
                        query: [("requestId", record.requestId), ("scope", scope)])) else {
                    return .unconfirmed("原采用请求查询失败，恢复记录保留")
                }
                if receipt["requestId"].string == record.requestId, ["PENDING", "UNKNOWN"].contains(receipt["status"].string ?? "") {
                    return await submit(&record, save: save, clear: clear)
                }
                return await accept(.success(receipt), &record, save: save, clear: clear)
            }
        } catch { return .unconfirmed("采用恢复记录无法读取，请保留记录核查") }
        guard let source = try? await client.read(try sourceRequest(sourceID: sourceID, scope: scope)),
              Self.exactID(source["originalTemplateId"]) == sourceID,
              let version = source["sourceVersion"].string, Self.isSourceVersion(version) else {
            return .unconfirmed("来源版本未确认，尚未发起采用")
        }
        record = Record(schemaVersion: 1, owner: String(owner), scope: scope, requestId: Self.newRequestID(),
                        sourceVersion: version, originalTemplateId: sourceID, draftId: nil)
        do { try save(record) } catch { return .unconfirmed("采用恢复记录保存失败，原稿保留") }
        return await submit(&record, save: save, clear: clear)
    }

    private func submit(_ record: inout Record, save: (Record) throws -> Void, clear: () -> Void) async -> Outcome {
        let result: Result<SquareGovernanceJSON, PlayerCapabilityFailure>
        do { result = .success(try await client.write(try adoptRequest(record))) }
        catch let failure as PlayerCapabilityFailure {
            if case .rejected(let code, _) = failure, [404, 405].contains(code) {
                return .unconfirmed("当前服务尚未支持采用请求，请更新服务后重查原请求")
            }
            result = .failure(failure)
        } catch { result = .failure(.outcomeUnknown) }
        return await accept(result, &record, save: save, clear: clear)
    }

    private func accept(_ result: Result<SquareGovernanceJSON, PlayerCapabilityFailure>, _ record: inout Record,
                        save: (Record) throws -> Void, clear: () -> Void) async -> Outcome {
        let facts: SquareGovernanceJSON
        switch result {
        case .success(let value): facts = value
        case .failure(.rejected(_, let message)):
            // P-39: an explicit refusal means the adoption did not happen; the journal is cleared.
            clear(); return .rejected(message ?? "原采用未通过内容、玩法能力或资产资格校验")
        case .failure: return .unconfirmed("采用结果未确认；重试会查询原请求")
        }
        guard facts["requestId"].string == record.requestId, facts["sourceVersion"].string == record.sourceVersion,
              Self.exactID(facts["originalTemplateId"]) == record.originalTemplateId else {
            return .unconfirmed("原采用结果未确认，请按原请求重试")
        }
        if facts["status"].string == "REJECTED" {
            clear()
            switch facts["reason"].string {
            case "SOURCE_VERSION_CONFLICT": return .rejected("原采用被拒绝：来源已改变或下架，请重新选择")
            case "ADOPTION_CAPABILITY_LOCKED": return .rejected("当前身份还没解锁这款玩法用到的分支或计时能力")
            default: return .rejected("原采用未通过内容、玩法能力或资产资格校验")
            }
        }
        guard facts["status"].string == "COMPLETED", let draft = Self.exactID(facts["draftId"]) else {
            return .unconfirmed("原采用尚未确认完成")
        }
        record.draftId = draft
        do { try save(record) } catch { return .unconfirmed("采用恢复记录保存失败，原稿保留") }
        return await loadDraft(record, draftID: draft, clear: clear)
    }

    private func loadDraft(_ record: Record, draftID: String, clear: () -> Void) async -> Outcome {
        guard let detail = try? await client.read(try client.getRequest(Self.detailPath,
                query: [("requestId", record.requestId), ("scope", record.scope)])) else {
            return .unconfirmed("原采用详情读取失败，请按原请求重试")
        }
        guard Self.exactID(detail["id"]) == draftID, case .object(let fields) = detail, fields["advancedConfigJson"] != nil else {
            return .unconfirmed("原采用草稿详情或版本未确认，原稿保留")
        }
        clear()
        return .ready(detail)
    }

    // MARK: Author detail (`temp/index.js`)

    /// `author-myinfo` for my scope (owner edit), `author-info` with an empty scope otherwise.
    public func authorDetail(templateID: Int, myScope: String?) async throws -> SquareGovernanceJSON {
        guard templateID > 0 else { throw PlayerCapabilityFailure.invalid }
        let path = myScope == nil ? Self.authorInfoPath : Self.authorMyInfoPath
        let raw = try await client.read(try client.formRequest(path, fields: [("id", String(templateID)), ("scope", myScope ?? "")]))
        guard Self.exactID(raw["id"]) == String(templateID) else { throw PlayerCapabilityFailure.malformed }
        return raw
    }

    // MARK: Location todos (U02-03 / U02-04)

    public struct LocationRow: Equatable, Identifiable {
        public let slotKey: String
        public let title: String
        public let what: String
        public let how: String
        public let fallback: String
        public let statusText: String
        public let bound: Bool
        public let blocking: Bool
        public let warn: Bool
        public let issueText: String
        public let nodeID: String
        public let revision: Int?
        public var id: String { slotKey }
    }
    public struct LocationTodos: Equatable {
        public let rows: [LocationRow]
        public let sourceTopicText: String?
        public let sourceRevisionText: String?
        public let intentText: String?
        public var blockingCount: Int { rows.filter(\.blocking).count }
        public var warnCount: Int { rows.filter(\.warn).count }
        /// `summaryText`
        public var summary: String {
            if blockingCount > 0 { return "\(blockingCount) 项挡住发布" }
            if warnCount > 0 { return "\(warnCount) 项待复核" }
            return rows.allSatisfy(\.bound) ? "已全部绑定" : ""
        }
    }

    static let statusText = ["UNBOUND": "未绑定", "REBIND_REQUIRED": "待在新城市重绑",
                             "BOUND_UNVERIFIED": "已绑定 · 未现场核验", "LEGACY_UNVERIFIED": "沿用 · 未复核"]
    static let policyText = ["NONE": "不能替代", "ALTERNATE_EVIDENCE": "可换其他证据", "ALTERNATE_NODE": "可换备用地点", "SKIP_ALLOWED": "可跳过"]
    static let intentText = ["NEW_CITY": "换城采用", "SAME_CITY": "同城沿用", "LEGACY": "旧版采用"]

    /// `view`: no location contract → nil (the block is not drawn).
    public static func locationTodos(_ data: SquareGovernanceJSON) -> LocationTodos? {
        let contract = data["contract"]
        let slots = contract["locationSlots"].array ?? []
        guard !slots.isEmpty else { return nil }
        var bindings: [String: SquareGovernanceJSON] = [:]
        for binding in contract["locationBindings"].array ?? [] { if let key = binding["slotKey"].string { bindings[key] = binding } }
        var issues: [String: SquareGovernanceJSON] = [:]
        for issue in data["bindingIssues"].array ?? [] { if let key = issue["slotKey"].string { issues[key] = issue } }
        let rows = slots.compactMap { slot -> LocationRow? in
            guard let key = slot["slotKey"].string else { return nil }
            let binding = bindings[key] ?? .null
            let issue = issues[key]
            let status = PlayerCapabilityClient.text(binding["verificationStatus"]).isEmpty ? "UNBOUND" : PlayerCapabilityClient.text(binding["verificationStatus"])
            let policy = PlayerCapabilityClient.text(slot["alternativePolicy"])
            let node = binding["nodeId"].int.map(String.init) ?? binding["nodeId"].string ?? ""
            let title = PlayerCapabilityClient.text(slot["title"])
            return LocationRow(slotKey: key, title: title.isEmpty ? "地点" : title,
                what: PlayerCapabilityClient.text(slot["observationTarget"]), how: PlayerCapabilityClient.text(slot["observationAction"]),
                fallback: policyText[policy.isEmpty ? "NONE" : policy] ?? "", statusText: statusText[status] ?? "状态待确认",
                bound: status == "BOUND_UNVERIFIED", blocking: issue?["level"].string == "error", warn: issue?["level"].string == "warn",
                issueText: issue.map { PlayerCapabilityClient.text($0["message"]) } ?? "", nodeID: node,
                revision: PlayerCapabilityClient.number(binding["bindingRevision"]).map { Int($0) })
        }
        let source = PlayerCapabilityClient.text(data["sourceTemplateTopicId"]).isEmpty
            ? (data["sourceTemplateTopicId"].int.map(String.init) ?? "") : PlayerCapabilityClient.text(data["sourceTemplateTopicId"])
        let revision = data["sourceContentRevisionId"].int.map(String.init) ?? PlayerCapabilityClient.text(data["sourceContentRevisionId"])
        let adoption = data["adoption"]
        return LocationTodos(rows: rows,
            sourceTopicText: source.isEmpty ? nil : "来源模板 #" + source,
            sourceRevisionText: source.isEmpty ? nil : (revision.isEmpty ? "未锁定来源修订" : "来源修订 #" + revision),
            intentText: source.isEmpty ? nil : adoption["bindingIntent"].string.flatMap { intentText[$0] })
    }

    /// Read failures keep the previous view (nil here); the caller does not draw 「没有待办」.
    public func bindingStatus(topicID: Int, scope: String) async throws -> LocationTodos? {
        guard topicID > 0 else { throw PlayerCapabilityFailure.invalid }
        let raw = try await client.read(try client.formRequest(Self.bindingStatusPath,
            fields: [("topicId", String(topicID)), ("scope", scope)]))
        return Self.locationTodos(raw)
    }

    /// `_bind`. A 409 or a transport failure means: re-read the status, never resend automatically.
    public func bind(topicID: Int, scope: String, slotKey: String, nodeID: Int, expectedRevision: Int?) async throws {
        guard topicID > 0, nodeID > 0, !slotKey.isEmpty else { throw PlayerCapabilityFailure.invalid }
        var fields = [("topicId", String(topicID)), ("scope", scope), ("slotKey", slotKey), ("nodeId", String(nodeID))]
        if let expectedRevision { fields.append(("expectedRevision", String(expectedRevision))) }
        _ = try await client.write(try client.formRequest(Self.bindingPath, fields: fields))
    }

    // MARK: My project actions

    /// BL-120 另存为模板: `{id, scope}`; the original topic stays. Returns the server `msg` when present.
    public func saveAsTemplate(topicID: Int, scope: String) async throws {
        guard topicID > 0 else { throw PlayerCapabilityFailure.invalid }
        _ = try await client.write(try client.formRequest(Self.saveAsPath, fields: [("id", String(topicID)), ("scope", scope)]))
    }

    /// 提交广场审核: `POST {id}/market-submit {scope}`.
    public func submitToMarket(templateID: Int, scope: String) async throws {
        guard templateID > 0 else { throw PlayerCapabilityFailure.invalid }
        _ = try await client.write(try client.formRequest(Self.marketSubmitPath(templateID), fields: [("scope", scope)]))
    }
}
