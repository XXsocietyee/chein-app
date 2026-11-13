import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - U02-01..05 template adoption (topic template -> my draft)
// Mirrors mini-program pages/templatedetail/utils/topic-adoption.js and
// pages/publish/utils/publish/location-todos.js (hengyin integration/backend-app-20261112).
// Only translates server facts: no fact -> the row is not drawn; never 0, never "verified", never "both platforms".

// MARK: contentDelivery (§23.3, /api/template/topic-template/info)

/// Optional `contentDelivery` on the public topic-template detail. Every part decodes on its own so a
/// malformed sub-object only drops that part; nothing is defaulted.
public struct TopicTemplateContentDelivery: Decodable, Equatable {
    public struct Revision: Equatable {
        public let contentRevisionId: Int64?
        public let revisionNo: Int64?
    }
    public struct LocationRequirement: Equatable {
        public let physicalPlaceRequired: Bool?
        public let stationWithAddressCount: Int?
        public let cityCode: String?
    }
    public struct OperatingRequirements: Equatable {
        public let needsBooking: Bool?
        public let staffMinutesMax: Int?
        public let maxConcurrent: Int?
        public let materials: [String]
        public let venues: [String]
    }
    public struct License: Equatable {
        public let status: String?
        public let owner: String?
        public let licensedEntity: String?
        public let validTo: String?
    }

    public let revision: Revision?
    public let locationRequirement: LocationRequirement?
    public let operatingRequirementsVisibility: String?
    public let operatingRequirements: OperatingRequirements?
    public let evidenceLevel: String?
    public let platformExecution: String?
    public let license: License?
    public let sourceLocale: String?
    public let translationStatus: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AdoptionWireKey.self)
        let rev = try? c.nestedContainer(keyedBy: AdoptionWireKey.self, forKey: .key("revision"))
        revision = rev.map { Revision(contentRevisionId: AdoptionWire.int64($0, "contentRevisionId"), revisionNo: AdoptionWire.int64($0, "revisionNo")) }
        let loc = try? c.nestedContainer(keyedBy: AdoptionWireKey.self, forKey: .key("locationRequirement"))
        locationRequirement = loc.map {
            LocationRequirement(physicalPlaceRequired: try? $0.decodeIfPresent(Bool.self, forKey: .key("physicalPlaceRequired")),
                                stationWithAddressCount: AdoptionWire.int64($0, "stationWithAddressCount").map { Int(clamping: $0) },
                                cityCode: AdoptionWire.string($0, "cityCode"))
        }
        operatingRequirementsVisibility = AdoptionWire.string(c, "operatingRequirementsVisibility")
        let op = try? c.nestedContainer(keyedBy: AdoptionWireKey.self, forKey: .key("operatingRequirements"))
        operatingRequirements = op.map {
            OperatingRequirements(needsBooking: try? $0.decodeIfPresent(Bool.self, forKey: .key("needsBooking")),
                                  staffMinutesMax: AdoptionWire.int64($0, "staffMinutesMax").map { Int(clamping: $0) },
                                  maxConcurrent: AdoptionWire.int64($0, "maxConcurrent").map { Int(clamping: $0) },
                                  materials: AdoptionWire.strings($0, "materials"), venues: AdoptionWire.strings($0, "venues"))
        }
        let evidence = try? c.nestedContainer(keyedBy: AdoptionWireKey.self, forKey: .key("evidence"))
        evidenceLevel = evidence.flatMap { AdoptionWire.string($0, "evidenceLevel") }
        let runtime = try? c.nestedContainer(keyedBy: AdoptionWireKey.self, forKey: .key("runtimeSupport"))
        platformExecution = runtime.flatMap { AdoptionWire.string($0, "platformExecution") }
        let lic = try? c.nestedContainer(keyedBy: AdoptionWireKey.self, forKey: .key("license"))
        license = lic.map { License(status: AdoptionWire.string($0, "status"), owner: AdoptionWire.string($0, "owner"),
                                    licensedEntity: AdoptionWire.string($0, "licensedEntity"), validTo: AdoptionWire.string($0, "validTo")) }
        sourceLocale = AdoptionWire.string(c, "sourceLocale")
        translationStatus = AdoptionWire.string(c, "translationStatus")
    }

    /// Current published revision id, passed through to `/use` unchanged. Old sources have none.
    public var sourceContentRevisionId: String? {
        guard let id = revision?.contentRevisionId, id > 0 else { return nil }
        return String(id)
    }
    /// Six-digit source city when the server reported one.
    public var sourceCityCode: String? {
        guard let code = locationRequirement?.cityCode, code.count == 6, code.allSatisfy(\.isASCII), code.allSatisfy(\.isNumber) else { return nil }
        return code
    }
}

/// U02-01 "采用条件" rows. Rows without an authoritative fact are not drawn (mini r2-create b4-u02-01).
public enum TopicTemplateAdoptionConditions {
    public struct Row: Equatable, Identifiable {
        public let key: String
        public let label: String
        public let value: String
        public var id: String { key }
    }

    public static func rows(_ delivery: TopicTemplateContentDelivery?, chinese: Bool = W8Text.isChinese) -> [Row] {
        guard let delivery else { return [] }
        func t(_ zh: String, _ en: String) -> String { chinese ? zh : en }
        var out: [Row] = []
        if let value = place(delivery.locationRequirement, t) { out.append(.init(key: "place", label: t("地点", "Places"), value: value)) }
        if let value = operating(delivery, t) { out.append(.init(key: "operating", label: t("投入", "Operating needs"), value: value)) }
        if let value = evidence(delivery.evidenceLevel, t) { out.append(.init(key: "evidence", label: t("验证", "Evidence"), value: value)) }
        if let value = delivery.platformExecution, !value.isEmpty, value != "UNKNOWN" {
            out.append(.init(key: "platform", label: t("端侧", "Platforms"), value: value))
        }
        if let value = locale(delivery, chinese: chinese, t) { out.append(.init(key: "locale", label: t("语言", "Language"), value: value)) }
        if let value = license(delivery.license, t) { out.append(.init(key: "license", label: t("许可", "License"), value: value)) }
        if let value = revision(delivery.revision, t) { out.append(.init(key: "revision", label: t("版本", "Version"), value: value)) }
        return out
    }

    private static func place(_ location: TopicTemplateContentDelivery.LocationRequirement?, _ t: (String, String) -> String) -> String? {
        guard let required = location?.physicalPlaceRequired else { return nil }
        guard required else { return t("不需要到现场", "No on-site visit needed") }
        if let count = location?.stationWithAddressCount, count > 0 {
            return t("需要到现场 · \(count) 个地点", "On-site · \(count) place\(count == 1 ? "" : "s")")
        }
        return t("需要到现场", "On-site visit needed")
    }

    private static func operating(_ delivery: TopicTemplateContentDelivery, _ t: (String, String) -> String) -> String? {
        switch delivery.operatingRequirementsVisibility {
        case "PARTNER_ONLY": return t("仅对合作商家开放", "Shared with partner merchants only")
        case "INCLUDED": break
        default: return nil
        }
        guard let op = delivery.operatingRequirements else { return nil }
        var parts: [String] = []
        if op.needsBooking == true { parts.append(t("需预约", "Booking required")) }
        if let minutes = op.staffMinutesMax, minutes > 0 { parts.append(t("主持约 \(minutes) 分钟", "About \(minutes) min of host time")) }
        if let groups = op.maxConcurrent, groups > 0 { parts.append(t("同时最多 \(groups) 组", "Up to \(groups) groups at once")) }
        parts += op.materials.prefix(2)
        parts += op.venues.prefix(1)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func evidence(_ level: String?, _ t: (String, String) -> String) -> String? {
        switch level {
        case "VERIFIED": return t("已实地验证", "Verified on site")
        case "PILOTED": return t("已试点", "Piloted")
        case "ESTIMATED": return t("预估，未实地验证", "Estimated, not verified on site")
        case "NONE": return t("未实测", "Not tested on site")
        default: return nil
        }
    }

    /// Source language plus a missing-translation note when the viewer reads another language (U02-05).
    private static func locale(_ delivery: TopicTemplateContentDelivery, chinese: Bool, _ t: (String, String) -> String) -> String? {
        guard let source = delivery.sourceLocale, !source.isEmpty else { return nil }
        let name = source == "zh-CN" ? t("简体中文", "Simplified Chinese") : source
        let viewerMatches = source.hasPrefix("zh") == chinese
        if delivery.translationStatus == "SINGLE_LOCALE", !viewerMatches {
            return t("\(name)（暂无译文）", "\(name) only (no translation yet)")
        }
        return name
    }

    private static func license(_ license: TopicTemplateContentDelivery.License?, _ t: (String, String) -> String) -> String? {
        guard let license, license.status == "AUTHORITATIVE" else { return nil }
        let who = [license.licensedEntity, license.owner].compactMap { $0 }.first { !$0.isEmpty }
        let until = license.validTo.map { t("至 \(String($0.prefix(10)))", "until \(String($0.prefix(10)))") }
        return [who ?? t("已登记许可", "License on file"), until].compactMap { $0 }.joined(separator: " · ")
    }

    private static func revision(_ revision: TopicTemplateContentDelivery.Revision?, _ t: (String, String) -> String) -> String? {
        guard let revision, revision.contentRevisionId != nil else { return nil }
        if let number = revision.revisionNo { return t("第 \(number) 版", "Version \(number)") }
        return t("已发布版本", "Published version")
    }
}

// MARK: /use intent + receipt (U02-02 / U02-04)

/// Owner ruling (mini r2-create b4-u02-02/04, "不需要换城市"): the app never sends NEW_CITY. A source with
/// a real place and a city is adopted SAME_CITY; anything else is sent without an intent (server LEGACY).
/// The author replaces addresses one by one in the editor's place to-dos.
public enum TopicTemplateBindingIntent: String, Equatable { case sameCity = "SAME_CITY" }

public struct TopicTemplateAdoptionPlan: Equatable {
    public let bindingIntent: TopicTemplateBindingIntent?
    public let sourceContentRevisionId: String?
    /// True when the template needs real places: the author must reconfirm them after the copy.
    public let keepsPlaces: Bool

    public init(delivery: TopicTemplateContentDelivery?) {
        let placed = delivery?.locationRequirement?.physicalPlaceRequired == true && delivery?.sourceCityCode != nil
        bindingIntent = placed ? .sameCity : nil
        keepsPlaces = delivery?.locationRequirement?.physicalPlaceRequired == true
        sourceContentRevisionId = delivery?.sourceContentRevisionId
    }
}

public struct TopicTemplateBindingIssue: Decodable, Equatable {
    public let slotKey: String?
    public let code: String?
    public let level: String?
    public let message: String?
    /// Only `error` blocks publishing. `warn` is a hint and never blocks on the device (§三 U02-02).
    public var blocksPublish: Bool { level == "error" }
    public var isWarning: Bool { level == "warn" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AdoptionWireKey.self)
        slotKey = AdoptionWire.string(c, "slotKey"); code = AdoptionWire.string(c, "code")
        level = AdoptionWire.string(c, "level"); message = AdoptionWire.string(c, "message")
    }
    public init(slotKey: String?, code: String?, level: String?, message: String?) {
        self.slotKey = slotKey; self.code = code; self.level = level; self.message = message
    }
}

/// `/use` 200 payload. `data.topicId` stays the primary key; the rest is the B2 increment, all optional.
public struct TopicTemplateUseReceipt: Decodable, Equatable {
    public let topicId: Int
    public let sourceTemplateTopicId: String?
    public let sourceContentRevisionId: String?
    public let bindingIntent: String?
    public let pendingRebindSlotKeys: [String]
    public let bindingIssues: [TopicTemplateBindingIssue]

    public var blockingCount: Int { bindingIssues.filter(\.blocksPublish).count }
    public var warningCount: Int { bindingIssues.filter(\.isWarning).count }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AdoptionWireKey.self)
        guard let id = AdoptionWire.int64(c, "topicId"), id > 0, id <= Int64(Int.max) else { throw APIError.malformedResponse }
        topicId = Int(id)
        sourceTemplateTopicId = AdoptionWire.string(c, "sourceTemplateTopicId")
        sourceContentRevisionId = AdoptionWire.string(c, "sourceContentRevisionId")
        bindingIntent = AdoptionWire.string(c, "bindingIntent")
        pendingRebindSlotKeys = AdoptionWire.strings(c, "pendingRebindSlotKeys")
        bindingIssues = (try? c.decodeIfPresent([TopicTemplateBindingIssue].self, forKey: .key("bindingIssues"))) ?? []
    }
    public init(topicId: Int, sourceTemplateTopicId: String? = nil, sourceContentRevisionId: String? = nil, bindingIntent: String? = nil,
                pendingRebindSlotKeys: [String] = [], bindingIssues: [TopicTemplateBindingIssue] = []) {
        self.topicId = topicId; self.sourceTemplateTopicId = sourceTemplateTopicId; self.sourceContentRevisionId = sourceContentRevisionId
        self.bindingIntent = bindingIntent; self.pendingRebindSlotKeys = pendingRebindSlotKeys; self.bindingIssues = bindingIssues
    }
}

/// Author write receipt id: 8-64 of `[A-Za-z0-9._:-]` (§21.2). Same id on retry -> the server replays the original result.
public enum AuthorWriteRequestID {
    public static func make(prefix: String) -> String { "\(prefix)-\(UUID().uuidString.lowercased())" }
    public static func isValid(_ value: String) -> Bool {
        (8...64).contains(value.count) && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "._:-".contains($0)) }
    }
}

// MARK: Location to-dos (U02-03, /binding-status + /binding)

public struct TopicLocationBindingStatus: Decodable, Equatable {
    public struct Slot: Equatable {
        public let slotKey: String
        public let title: String?
        public let observationTarget: String?
        public let observationAction: String?
        public let alternativePolicy: String?
    }
    public struct Binding: Equatable {
        public let slotKey: String
        public let nodeId: String?
        public let bindingRevision: Int?
        public let verificationStatus: String?
    }
    public let slots: [Slot]
    public let bindings: [Binding]
    public let bindingIssues: [TopicTemplateBindingIssue]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AdoptionWireKey.self)
        bindingIssues = (try? c.decodeIfPresent([TopicTemplateBindingIssue].self, forKey: .key("bindingIssues"))) ?? []
        guard let contract = try? c.nestedContainer(keyedBy: AdoptionWireKey.self, forKey: .key("contract")) else {
            slots = []; bindings = []; return
        }
        var slots: [Slot] = []
        if var list = try? contract.nestedUnkeyedContainer(forKey: .key("locationSlots")) {
            while !list.isAtEnd {
                guard let row = try? list.nestedContainer(keyedBy: AdoptionWireKey.self) else { _ = try? list.decode(AdoptionSkip.self); continue }
                guard let key = AdoptionWire.string(row, "slotKey") else { continue }
                slots.append(Slot(slotKey: key, title: AdoptionWire.string(row, "title"),
                                  observationTarget: AdoptionWire.string(row, "observationTarget"),
                                  observationAction: AdoptionWire.string(row, "observationAction"),
                                  alternativePolicy: AdoptionWire.string(row, "alternativePolicy")))
            }
        }
        var bindings: [Binding] = []
        if var list = try? contract.nestedUnkeyedContainer(forKey: .key("locationBindings")) {
            while !list.isAtEnd {
                guard let row = try? list.nestedContainer(keyedBy: AdoptionWireKey.self) else { _ = try? list.decode(AdoptionSkip.self); continue }
                guard let key = AdoptionWire.string(row, "slotKey") else { continue }
                bindings.append(Binding(slotKey: key, nodeId: AdoptionWire.string(row, "nodeId"),
                                        bindingRevision: AdoptionWire.int64(row, "bindingRevision").map { Int(clamping: $0) },
                                        verificationStatus: AdoptionWire.string(row, "verificationStatus")))
            }
        }
        self.slots = slots; self.bindings = bindings
    }
}

/// A node in the author's own draft that already has a place (address or coordinates) and a server id.
public struct TopicLocationEditorNode: Equatable {
    public let id: String
    public let name: String
    public let place: String
    public init?(id: String, name: String, address: String, hasCoordinates: Bool) {
        guard let number = Int64(id), number > 0, String(number) == id else { return nil }
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty || hasCoordinates else { return nil }
        let place = address.isEmpty ? name : address
        guard !place.isEmpty else { return nil }
        self.id = id; self.name = name; self.place = place
    }
}

public struct TopicLocationTodoRow: Equatable, Identifiable {
    public enum Status: Equatable { case unbound, rebindRequired, boundUnverified, legacyUnverified, unknown }
    public let slotKey: String
    public let title: String
    public let observationTarget: String?
    public let observationAction: String?
    public let alternativePolicy: String?
    public let status: Status
    public let blocking: Bool
    public let warning: Bool
    public let issueMessage: String?
    public let nodeId: String?
    public let revision: Int?
    public var id: String { slotKey }
}

public struct TopicLocationTodos: Equatable {
    public let rows: [TopicLocationTodoRow]
    public var blockingCount: Int { rows.filter(\.blocking).count }
    public var warningCount: Int { rows.filter(\.warning).count }

    /// Nil when the topic has no place contract: the whole block is not drawn.
    public init?(_ status: TopicLocationBindingStatus) {
        guard !status.slots.isEmpty else { return nil }
        var bindings: [String: TopicLocationBindingStatus.Binding] = [:]
        for binding in status.bindings where bindings[binding.slotKey] == nil { bindings[binding.slotKey] = binding }
        var issues: [String: TopicTemplateBindingIssue] = [:]
        for issue in status.bindingIssues { if let key = issue.slotKey, issues[key] == nil { issues[key] = issue } }
        rows = status.slots.map { slot in
            let binding = bindings[slot.slotKey]
            let issue = issues[slot.slotKey]
            let status: TopicLocationTodoRow.Status
            switch binding?.verificationStatus ?? "UNBOUND" {
            case "UNBOUND": status = .unbound
            case "REBIND_REQUIRED": status = .rebindRequired
            case "BOUND_UNVERIFIED": status = .boundUnverified
            case "LEGACY_UNVERIFIED": status = .legacyUnverified
            default: status = .unknown
            }
            let title = slot.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            return TopicLocationTodoRow(slotKey: slot.slotKey, title: (title?.isEmpty ?? true) ? W8Text.t("地点", "Place") : title!,
                                        observationTarget: slot.observationTarget, observationAction: slot.observationAction,
                                        alternativePolicy: slot.alternativePolicy, status: status,
                                        blocking: issue?.blocksPublish ?? false, warning: issue?.isWarning ?? false,
                                        issueMessage: issue?.message, nodeId: binding?.nodeId, revision: binding?.bindingRevision)
        }
    }

    /// Mini `slotNodes`: a bound slot maps to its node; an unbound one claims a uniquely same-named node.
    public func editorNode(for row: TopicLocationTodoRow, in nodes: [TopicLocationEditorNode]) -> (node: TopicLocationEditorNode, claimed: Bool)? {
        if let id = row.nodeId, let node = nodes.first(where: { $0.id == id }) { return (node, false) }
        let named = nodes.filter { $0.name == row.title }
        return named.count == 1 ? (named[0], true) : nil
    }

    public static func statusText(_ status: TopicLocationTodoRow.Status) -> String {
        switch status {
        case .unbound: return W8Text.t("未绑定", "Not set")
        case .rebindRequired: return W8Text.t("待重新确认地点", "Place needs reconfirming")
        case .boundUnverified: return W8Text.t("已绑定 · 未现场核验", "Set · not checked on site")
        case .legacyUnverified: return W8Text.t("沿用 · 未复核", "Kept from template · not reviewed")
        case .unknown: return W8Text.t("状态待确认", "Status not confirmed")
        }
    }

    public static func fallbackText(_ policy: String?) -> String? {
        switch policy {
        case "ALTERNATE_EVIDENCE": return W8Text.t("看不到时可换其他证据", "If unavailable: other evidence allowed")
        case "ALTERNATE_NODE": return W8Text.t("看不到时可换备用地点", "If unavailable: a backup place allowed")
        case "SKIP_ALLOWED": return W8Text.t("看不到时可跳过", "If unavailable: may be skipped")
        default: return nil
        }
    }

    public var summaryText: String? {
        if blockingCount > 0 { return W8Text.t("\(blockingCount) 项挡住发布", "\(blockingCount) blocking publish") }
        if warningCount > 0 { return W8Text.t("\(warningCount) 项待复核", "\(warningCount) to review") }
        return rows.allSatisfy({ $0.status == .boundUnverified }) ? W8Text.t("已全部绑定", "All places set") : nil
    }
}

public enum TopicLocationBindOutcome: Equatable {
    case bound
    /// Server refusal, shown verbatim under the row. 409 = someone else updated it: reload.
    case rejected(code: Int, message: String)
    /// No answer: never resend automatically; re-read the authoritative status.
    case unknown
}

@MainActor public protocol TopicLocationBindingClient {
    func status(topicId: Int, scope: String?) async throws -> TopicLocationBindingStatus
    func bind(topicId: Int, scope: String?, slotKey: String, nodeId: String, expectedRevision: Int?) async -> TopicLocationBindOutcome
}

/// Gated default: the to-do block stays hidden.
public struct GatedTopicLocationBindingClient: TopicLocationBindingClient {
    public init() {}
    public func status(topicId: Int, scope: String?) async throws -> TopicLocationBindingStatus { throw APIError.notConfigured }
    public func bind(topicId: Int, scope: String?, slotKey: String, nodeId: String, expectedRevision: Int?) async -> TopicLocationBindOutcome {
        .rejected(code: 0, message: W8Text.t("暂未开放", "Not available yet"))
    }
}

@MainActor public final class TopicLocationTodosModel: ObservableObject {
    @Published public private(set) var todos: TopicLocationTodos?
    @Published public private(set) var busySlot: String?
    @Published public private(set) var rowErrors: [String: String] = [:]
    @Published public private(set) var isLoading = false
    private let client: TopicLocationBindingClient
    public let topicId: Int
    public let scope: String?
    private var generation: UInt64 = 0

    public init(client: TopicLocationBindingClient, topicId: Int, scope: String?) {
        self.client = client; self.topicId = topicId; self.scope = scope
    }

    /// A failed read keeps the last confirmed view: never draw "no to-dos" from an error.
    public func load() async {
        guard topicId > 0 else { return }
        generation &+= 1
        let captured = generation
        isLoading = true
        defer { if captured == generation { isLoading = false } }
        guard let status = try? await client.status(topicId: topicId, scope: scope), captured == generation else { return }
        todos = TopicLocationTodos(status)
    }

    public func bind(_ row: TopicLocationTodoRow, nodeId: String) async {
        guard busySlot == nil, !nodeId.isEmpty else { return }
        busySlot = row.slotKey
        rowErrors[row.slotKey] = nil
        let outcome = await client.bind(topicId: topicId, scope: scope, slotKey: row.slotKey, nodeId: nodeId, expectedRevision: row.revision)
        busySlot = nil
        switch outcome {
        case .bound:
            await load()
        case .rejected(let code, let message):
            rowErrors[row.slotKey] = message.isEmpty ? W8Text.t("绑定失败", "Could not set this place") : message
            if code == 409 { await load() }
        case .unknown:
            rowErrors[row.slotKey] = W8Text.t("绑定结果未确认，已重新读取", "Result not confirmed. Re-reading the latest state.")
            await load()
        }
    }

    public func pickError(_ row: TopicLocationTodoRow) {
        rowErrors[row.slotKey] = W8Text.t("先在章节里给节点设置这座城市的地点并保存", "First give a stop a place in this city in your chapters, then save.")
    }
}

// MARK: Media attribution (U02-05, GET /api/media/asset/attribution)

/// Player-facing credit: attribution only (mini r2-create b4-u02-05 drops the AI / pending-source marks).
public enum MediaAttributionCredit {
    public static func text(attribution: String?) -> String? {
        guard let value = attribution?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return String(value.prefix(40))
    }
}

@MainActor public protocol MediaAttributionReading {
    /// Nil = no credit to show (unreviewed, 422, or nothing on file). Errors are also shown as nothing.
    func credit(reference: String) async -> String?
}

public struct GatedMediaAttributionReader: MediaAttributionReading {
    public init() {}
    public func credit(reference: String) async -> String? { nil }
}

// MARK: Live HTTP client (form POSTs + one GET, same envelope as DiscoveryService)

public struct TopicTemplateAdoptionService: TopicTemplateUsing, TopicLocationBindingClient, MediaAttributionReading {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let token: @MainActor () -> String?

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: @escaping @MainActor () -> String?) {
        self.configuration = configuration; self.transport = transport; self.token = token
    }

    public func use(_ request: TopicTemplateUseRequest) async -> TopicTemplateUseOutcome {
        let response: (code: Int, msg: String?, data: Data)
        do { response = try await send(request.path, fields: request.formFields) }
        catch let error as APIError where error == .invalidRequest || error == .notConfigured {
            return .failed(message: W8Text.t("使用模板失败", "Could not use this template"))
        } catch { return .unknown }
        guard response.code == 200 else {
            if response.code >= 500 { return .unknown }
            return .failed(message: response.msg ?? "")
        }
        guard let receipt = try? JSONDecoder().decode(AdoptionDataEnvelope<TopicTemplateUseReceipt>.self, from: response.data).data else {
            // 200 without a usable topicId: the copy may exist. Treat as unknown so the same requestId re-reads it.
            return .unknown
        }
        return .copied(receipt)
    }

    public func status(topicId: Int, scope: String?) async throws -> TopicLocationBindingStatus {
        var fields = ["topicId": String(topicId)]
        if let scope, !scope.isEmpty { fields["scope"] = scope }
        let response = try await send("/api/template/topic-template/binding-status", fields: fields)
        if response.code == 401 { throw APIError.unauthorized }
        guard response.code == 200 else { throw APIError.businessCode(response.code) }
        do { return try JSONDecoder().decode(AdoptionDataEnvelope<TopicLocationBindingStatus>.self, from: response.data).data }
        catch { throw APIError.malformedResponse }
    }

    public func bind(topicId: Int, scope: String?, slotKey: String, nodeId: String, expectedRevision: Int?) async -> TopicLocationBindOutcome {
        var fields = ["topicId": String(topicId), "slotKey": slotKey, "nodeId": nodeId]
        if let scope, !scope.isEmpty { fields["scope"] = scope }
        if let expectedRevision { fields["expectedRevision"] = String(expectedRevision) }
        guard let response = try? await send("/api/template/topic-template/binding", fields: fields) else { return .unknown }
        if response.code == 200 { return .bound }
        if response.code >= 500 { return .unknown }
        return .rejected(code: response.code, message: response.msg ?? "")
    }

    public func credit(reference: String) async -> String? {
        guard !reference.isEmpty,
              var components = URLComponents(url: configuration.baseURL.appendingPathComponent("api/media/asset/attribution"), resolvingAgainstBaseURL: false)
        else { return nil }
        components.queryItems = [URLQueryItem(name: "reference", value: reference)]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = token(), AuthRequestBuilder.isValidToken(token) { request.setValue(token, forHTTPHeaderField: "Authorization") }
        guard let (data, status) = try? await transport.send(request), (200..<300).contains(status),
              let envelope = try? JSONDecoder().decode(AdoptionAttributionEnvelope.self, from: data), envelope.code == 200
        else { return nil }
        return MediaAttributionCredit.text(attribution: envelope.data?.attribution)
    }

    private func send(_ path: String, fields: [String: String]) async throws -> (code: Int, msg: String?, data: Data) {
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let request = try AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent(relative), fields: fields, token: token())
        let (data, status) = try await transport.send(request)
        if status == 401 { return (401, nil, data) }
        guard (200..<300).contains(status) else { return (status, nil, data) }
        guard let envelope = try? JSONDecoder().decode(AdoptionStatusEnvelope.self, from: data) else { throw APIError.malformedResponse }
        return (envelope.code, envelope.msg, data)
    }
}

// MARK: Wire helpers

struct AdoptionWireKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
    static func key(_ name: String) -> Self { .init(stringValue: name) }
}
private struct AdoptionSkip: Decodable {}

enum AdoptionWire {
    /// Numbers or numeric strings (the server mixes `Long` and `String.valueOf`).
    static func int64(_ c: KeyedDecodingContainer<AdoptionWireKey>, _ key: String) -> Int64? {
        if let value = try? c.decodeIfPresent(Int64.self, forKey: .key(key)) { return value }
        if let text = try? c.decodeIfPresent(String.self, forKey: .key(key)) { return Int64(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
    static func string(_ c: KeyedDecodingContainer<AdoptionWireKey>, _ key: String) -> String? {
        if let text = try? c.decodeIfPresent(String.self, forKey: .key(key)) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = try? c.decodeIfPresent(Int64.self, forKey: .key(key)) { return String(number) }
        return nil
    }
    static func strings(_ c: KeyedDecodingContainer<AdoptionWireKey>, _ key: String) -> [String] {
        ((try? c.decodeIfPresent([String?].self, forKey: .key(key))) ?? nil)?
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
    }
}

private struct AdoptionStatusEnvelope: Decodable {
    let code: Int
    let msg: String?
    enum CodingKeys: String, CodingKey { case code, msg }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? c.decode(Int.self, forKey: .code) { code = value }
        else if let text = try? c.decode(String.self, forKey: .code), let value = Int(text) { code = value }
        else { throw APIError.malformedResponse }
        msg = try? c.decode(String.self, forKey: .msg)
    }
}
private struct AdoptionDataEnvelope<T: Decodable>: Decodable { let data: T }
private struct AdoptionAttributionEnvelope: Decodable {
    struct Payload: Decodable { let attribution: String? }
    let code: Int
    let data: Payload?
}
