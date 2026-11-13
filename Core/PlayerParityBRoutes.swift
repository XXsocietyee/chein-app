import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Parity package P-B: the remaining mini-program player paths on top of `PlayerGapService`.
/// Each method is one request with no retry, shaped like the mini-program helper named beside it.
/// Organiser control, the lead ticket scan, the editor alternatives and the circle configure are non-money.
extension PlayerGapService {
    /// Every P-B route this service may build, relative to the API base.
    public static let parityBPaths: Set<String> = [
        "api/game/session/shared/control", "api/game/session/shared/export", "api/game/session/shared/export/anchor",
        "api/registration/scan_group_member_ticket", "api/verify/seat/receipt",
        "api/orient/task/alternative", "api/topic/author-saved-detail",
        "api/circle-theme/instance/configure", "api/project/home",
        "api/analytics/events/batch"
    ]

    /// The raw envelope and HTTP status, for the helpers whose mini-program classification is not `PlayerGapReply`.
    func sendRaw(_ request: URLRequest) async -> (envelope: PlayWireValue?, status: Int)? {
        guard let (data, status) = try? await transport.send(request) else { return nil }
        return (try? JSONDecoder().decode(PlayWireValue.self, from: data), status)
    }

    // MARK: shared session (organiser)

    /// `game-session-client.js loadSharedStaffView(activityId, false)`: GET `{activityId}`.
    public func sharedControl(activityID: Int) async -> SharedRunStaffRead {
        await sharedStaffView(activityID: activityID, exported: false)
    }

    /// `loadSharedStaffView(activityId, true)`.
    public func sharedExport(activityID: Int) async -> SharedRunStaffRead {
        await sharedStaffView(activityID: activityID, exported: true)
    }

    private func sharedStaffView(activityID: Int, exported: Bool) async -> SharedRunStaffRead {
        guard activityID > 0 else { return .businessError(message: nil, reasonCode: nil) }
        let path = exported ? "api/game/session/shared/export" : "api/game/session/shared/control"
        guard let request = try? makeRequest(path, method: "GET", query: ["activityId": String(activityID)]),
              let (envelope, status) = await sendRaw(request), (200..<300).contains(status), let envelope else { return .networkError }
        guard envelope["code"].tolerantInteger == 200 else {
            return .businessError(message: SharedRunStaffRead.safeMessage(envelope["msg"].text), reasonCode: envelope["data"]["reasonCode"].text)
        }
        let data = envelope["data"]
        return SharedRunStaffRead.validated(data, activityID: activityID, exported: exported) ? .ready(data) : .invalid
    }

    /// `anchorSharedRun`: POST JSON `{activityId}`. Only a 4xx-style business refusal (`GAME_*` reason on 500)
    /// proves nothing started; every other non-200 or malformed reply is an unknown write that the caller rereads.
    public func anchorSharedRun(activityID: Int) async -> SharedRunAnchorResult {
        guard activityID > 0 else { return .refused(message: nil) }
        guard let request = try? makeRequest("api/game/session/shared/export/anchor", method: "POST", json: ["activityId": .int(activityID)]),
              let (envelope, status) = await sendRaw(request), (200..<300).contains(status), let envelope else { return .unknown }
        let code = envelope["code"].tolerantInteger
        let data = envelope["data"]
        if code != 200 {
            if code == 500, data.object != nil, let reason = data["reasonCode"].text, reason.range(of: "^GAME_[A-Z0-9_]+$", options: .regularExpression) != nil {
                return .refused(message: SharedRunStaffRead.safeMessage(envelope["msg"].text))
            }
            return .unknown
        }
        return SharedRunAnchorResult.validAnchor(data, activityID: activityID) ? .anchored(data) : .unknown
    }

    // MARK: lead member ticket (registration-seat.js + merchant-verification.js)

    /// `leadVerifyMemberTicket`: form `{code, activityId}`.
    public func scanGroupMemberTicket(code: String, activityID: Int) async -> (envelope: PlayWireValue?, status: Int)? {
        guard activityID > 0, !code.isEmpty,
              let request = try? makeRequest("api/registration/scan_group_member_ticket", method: "POST",
                                             form: ["code": code, "activityId": String(activityID)]) else { return nil }
        return await sendRaw(request)
    }

    /// `seatRecovery.readReceipt`: form `{registrationId, seatNo, activityId}` of the original seat.
    public func seatReceipt(_ target: RegistrationSeatTarget) async -> (envelope: PlayWireValue?, status: Int)? {
        var form = ["registrationId": target.registrationID, "seatNo": String(target.seatNo)]
        if let activity = target.activityID { form["activityId"] = activity }
        guard let request = try? makeRequest("api/verify/seat/receipt", method: "POST", form: form) else { return nil }
        return await sendRaw(request)
    }

    // MARK: editor: orienteering alternatives (theme-runtime-structure.js)

    /// `_saveStructureAlts` one row: JSON `{topicId, taskId, alternativeTaskType, promptText, enabled[, answer]}`.
    public func saveOrientAlternative(topicID: Int, taskID: Int, row: OrientAlternativeRow) async -> PlayerGapReply {
        guard topicID > 0, taskID > 0 else { return .unknown }
        var body: [String: PlayWireValue] = ["topicId": .int(topicID), "taskId": .int(taskID),
            "alternativeTaskType": .string(row.type.rawValue), "promptText": .string(row.prompt), "enabled": .bool(row.on)]
        if row.type == .quiz, !row.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { body["answer"] = .string(row.answer) }
        guard let request = try? makeRequest("api/orient/task/alternative", method: "POST", json: body) else { return .unknown }
        return await send(request)
    }

    /// `author-saved-detail` (personal scope): form `{id}`. Returns the node's rows, or nil when the readback
    /// cannot prove the configs were loaded for this topic and node.
    public func orientAlternatives(topicID: Int, taskID: Int) async -> [OrientAlternativeType: OrientAlternativeRow]? {
        guard topicID > 0, taskID > 0,
              let request = try? makeRequest("api/topic/author-saved-detail", method: "POST", form: ["id": String(topicID)]),
              case .ok(let detail, _) = await send(request) else { return nil }
        return OrientAlternativeRow.drafts(detail, topicID: topicID, taskID: taskID)
    }

    // MARK: circle theme host (project-host + merchantinfo)

    /// `loadProjectHome` personal scope: POST JSON `{topicId, scope: ""}`. Only the circle facts are kept.
    public func circleHostTopic(topicID: Int) async -> CircleThemeHostTopic? {
        guard topicID > 0,
              let request = try? makeRequest("api/project/home", method: "POST", json: ["topicId": .int(topicID), "scope": .string("")]),
              case .ok(let data, _) = await send(request) else { return nil }
        return CircleThemeHostTopic(data)
    }

    /// `submitCircleConfig`: JSON `{topicId, candidateCodes, scope: ""}`. The caller validates first.
    public func configureCircleInstance(topicID: Int, candidateCodes: [String]) async -> PlayerGapReply {
        guard topicID > 0, !candidateCodes.isEmpty,
              let request = try? makeRequest("api/circle-theme/instance/configure", method: "POST", json: [
                "topicId": .int(topicID), "candidateCodes": .array(candidateCodes.map { .string($0) }), "scope": .string("")]) else { return .unknown }
        return await send(request)
    }

    // MARK: analytics

    /// `analytics.js postBatch`: JSON `{events}`. True only when `data.accepted` equals the batch size.
    public func postAnalyticsBatch(_ events: [AnalyticsQueuedEvent]) async -> Bool {
        guard !events.isEmpty, events.count <= AnalyticsEventClient.maxBatch,
              let request = try? makeRequest("api/analytics/events/batch", method: "POST", json: ["events": .array(events.map(\.wire))]),
              case .ok(let data, _) = await send(request) else { return false }
        return data["accepted"].integer == events.count
    }
}

// MARK: - Shared session

public enum SharedRunStaffRead: Equatable {
    case ready(PlayWireValue)
    case businessError(message: String?, reasonCode: String?)
    case invalid
    case networkError

    /// `safeMessage`: drop empty, long, or engineering text.
    static func safeMessage(_ raw: String?) -> String? {
        let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 80,
              text.range(of: #"(?:/api/|exception|\.java\b|\bselect\b)"#, options: [.regularExpression, .caseInsensitive]) == nil else { return nil }
        return text
    }

    static func revision(_ value: PlayWireValue) -> Int? { value.integer.flatMap { $0 >= 0 ? $0 : nil } }
    static func hash(_ value: PlayWireValue) -> Bool { value.text?.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil }

    static func validated(_ data: PlayWireValue, activityID: Int, exported: Bool) -> Bool {
        guard data.object != nil, revision(data["revision"]) != nil else { return false }
        let epoch = exported ? data["authorityEpoch"] : data["run"]["authorityEpoch"]
        guard let epochValue = revision(epoch), epochValue >= 1 else { return false }
        if exported {
            return data["activityId"].tolerantInteger == activityID && (data["sessionId"].tolerantInteger ?? 0) > 0
                && hash(data["configHash"]) && hash(data["highWaterHash"])
        }
        guard data["teams"].array != nil, data["stations"].array != nil else { return false }
        if data["availableActions"] != .null {
            guard let actions = data["availableActions"].array, actions.allSatisfy({ $0.text != nil }) else { return false }
        }
        return true
    }
}

public enum SharedRunAnchorResult: Equatable {
    case anchored(PlayWireValue)
    case refused(message: String?)
    case unknown

    static func validAnchor(_ data: PlayWireValue, activityID: Int) -> Bool {
        let anchor = data["anchor"]
        guard data.object != nil, data["activityId"].tolerantInteger == activityID, (data["sessionId"].tolerantInteger ?? 0) > 0,
              anchor.object != nil, let epoch = SharedRunStaffRead.revision(data["authorityEpoch"]), epoch >= 1,
              anchor["epoch"].integer == epoch, let at = anchor["at"].integer, at >= 1,
              anchor["configHash"] == data["configHash"], anchor["highWaterHash"] == data["highWaterHash"],
              SharedRunStaffRead.hash(anchor["highWaterHash"]), SharedRunStaffRead.hash(anchor["configHash"]) else { return false }
        return true
    }
}

/// The organiser panel facts the director shows (`genericOpsStatusText`, teams and stations counts).
public struct SharedRunControlSummary: Equatable {
    public let revision: Int
    public let authorityEpoch: Int
    public let operationStatus: String?
    public let authorityMode: String?
    public let teamCount: Int
    public let stationCount: Int
    public let offlineAnchorAvailable: Bool
    /// An anchor the server already holds for this epoch (`_reconcileOfflineAnchor` reads it from control).
    public let anchoredAt: Int?

    public init?(_ data: PlayWireValue) {
        guard let revision = SharedRunStaffRead.revision(data["revision"]),
              let epoch = SharedRunStaffRead.revision(data["run"]["authorityEpoch"]), epoch >= 1,
              let teams = data["teams"].array, let stations = data["stations"].array else { return nil }
        self.revision = revision; authorityEpoch = epoch
        operationStatus = data["run"]["operationStatus"].text; authorityMode = data["run"]["authorityMode"].text
        teamCount = teams.count; stationCount = stations.count
        offlineAnchorAvailable = data["offlineAnchorAvailable"].bool == true
        let anchor = data["offlineAnchor"]
        if anchor["epoch"].integer == epoch, let at = anchor["at"].integer, at >= 1,
           SharedRunStaffRead.hash(anchor["highWaterHash"]), SharedRunStaffRead.hash(anchor["configHash"]) { anchoredAt = at } else { anchoredAt = nil }
    }
}

public struct SharedRunExportSummary: Equatable {
    public let revision: Int
    public let authorityEpoch: Int
    public let sessionID: Int
    public let configHash: String
    public let highWaterHash: String
    public let manualNeedsReview: Bool
    public let manualNextSequence: Int?

    public init?(_ data: PlayWireValue) {
        guard let revision = SharedRunStaffRead.revision(data["revision"]),
              let epoch = SharedRunStaffRead.revision(data["authorityEpoch"]), epoch >= 1,
              let session = data["sessionId"].tolerantInteger, session > 0,
              let config = data["configHash"].text, let high = data["highWaterHash"].text else { return nil }
        self.revision = revision; authorityEpoch = epoch; sessionID = session; configHash = config; highWaterHash = high
        manualNeedsReview = data["manual"]["needsReview"].bool == true
        manualNextSequence = data["manual"]["nextSequence"].integer
    }
}

// MARK: - Lead member ticket

/// `pages/play/utils/lead-ticket-scan.js`: legacy JSON codes are unwrapped; dynamic codes go to the server as-is.
public enum LeadMemberTicket: Equatable {
    case code(String)
    case malformed
    case notTopic

    public static func resolve(_ raw: String) -> LeadMemberTicket {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .malformed }
        guard value.first == "{" else { return .code(value) }
        guard let data = value.data(using: .utf8), let ticket = try? JSONDecoder().decode(PlayWireValue.self, from: data),
              ticket.object != nil else { return .malformed }
        let code: String
        if let text = ticket["code"].text { code = text } else if let number = ticket["code"].integer { code = String(number) } else { return .malformed }
        guard !code.isEmpty else { return .malformed }
        if let type = ticket["type"].text, !type.isEmpty, type != "topic" { return .notTopic }
        return .code(code.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// `registration-seat.js seatTarget` for `scan_group_member_ticket`: `v1.<registrationId>.(activity|topic)_seat_<n>.…` (6 parts).
public struct RegistrationSeatTarget: Codable, Equatable, Hashable {
    public let registrationID: String
    public let seatNo: Int
    public let activityID: String?

    static func positiveID(_ value: String) -> Bool { value.range(of: "^[1-9][0-9]*$", options: .regularExpression) != nil && Int(value) != nil }

    public init?(code: String, activityID: Int) {
        let parts = code.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 6, parts[0] == "v1", Self.positiveID(parts[1]), activityID > 0,
              let match = parts[2].range(of: "^(activity|topic)_seat_[1-9][0-9]*$", options: .regularExpression), match == parts[2].startIndex..<parts[2].endIndex,
              let seat = parts[2].split(separator: "_").last.flatMap({ Int($0) }), seat <= 2_147_483_647 else { return nil }
        registrationID = parts[1]; seatNo = seat; self.activityID = String(activityID)
    }

    /// `validSeatReceipt`.
    public func matchesReceipt(_ data: PlayWireValue) -> Bool {
        func id(_ v: PlayWireValue) -> Bool { (v.integer.map { $0 > 0 } ?? false) || (v.text.map(Self.positiveID) ?? false) }
        func idText(_ v: PlayWireValue) -> String? { v.integer.map(String.init) ?? v.text }
        guard data.object != nil, ["seatId", "registrationId", "activityId", "verifierMemberId"].allSatisfy({ id(data[$0]) }),
              idText(data["registrationId"]) == registrationID, data["seatNo"].tolerantInteger == seatNo,
              activityID == nil || idText(data["activityId"]) == activityID,
              data["topicId"] == .null || id(data["topicId"]), data["replayed"].bool != nil,
              data["registrationFirstTime"] == .null || data["registrationFirstTime"].bool != nil,
              let verifiedAt = data["verifiedAt"].text, !verifiedAt.isEmpty else { return false }
        return true
    }
}

/// The one UNKNOWN seat write per account and seat (`createVerificationWorkflow` storage). A held seat is only reread.
public struct LeadTicketPendingStore {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public static func key(accountID: Int, target: RegistrationSeatTarget) -> String {
        "verification_unknown_v1:\(accountID):seat:\(target.registrationID):\(target.seatNo)"
    }
    public func isHeld(_ key: String) -> Bool { defaults.object(forKey: key) != nil }
    public func hold(_ key: String, target: RegistrationSeatTarget) -> Bool {
        guard let data = try? JSONEncoder().encode(target) else { return false }
        defaults.set(data, forKey: key)
        return defaults.data(forKey: key) == data
    }
    public func clear(_ key: String) { defaults.removeObject(forKey: key) }
}

public enum LeadTicketScanOutcome: Equatable {
    case verified(message: String?)
    case failed(message: String?)
    /// 409: the ticket changed elsewhere; review the redemption record first.
    case review(message: String?)
    /// The seat result is not known; rescanning the same seat only rereads it.
    case unknown
    case blocked

    /// `classifyVerificationOutcome` for `scan_group_member_ticket`.
    public static func classify(_ reply: (envelope: PlayWireValue?, status: Int)?, seat: RegistrationSeatTarget?) -> LeadTicketScanOutcome {
        guard let seat else {
            // The non-seat branch is a plain request: 200 verified, anything else (or no reply) did not verify.
            guard let envelope = reply?.envelope, reply?.status == 200 else { return .failed(message: nil) }
            return envelope["code"].tolerantInteger == 200 ? .verified(message: envelope["msg"].text) : .failed(message: envelope["msg"].text)
        }
        guard let reply else { return .unknown }
        let envelope = reply.envelope, code = envelope?["code"].tolerantInteger, message = envelope?["msg"].text
        if reply.status == 409 || code == 409 {
            let chinese = message.map { $0.range(of: "\\p{Han}", options: .regularExpression) != nil } ?? false
            return .review(message: chinese ? message : nil)
        }
        if [400, 401, 403, 404, 405, 413, 415, 426, 429].contains(reply.status) { return .failed(message: nil) }
        guard reply.status == 200, let envelope, envelope.object != nil else { return .unknown }
        let data = envelope["data"]
        if code == 200 { return seat.matchesReceipt(data) ? .verified(message: message) : .unknown }
        if code == 500, data["alreadyVerified"].bool == true, message == "该订单已核销" { return .failed(message: message) }
        return .unknown
    }

    /// `seatRecovery` terminal check: a 200 receipt for the original seat with `replayed: true`.
    public static func recovered(_ reply: (envelope: PlayWireValue?, status: Int)?, seat: RegistrationSeatTarget) -> Bool {
        guard let envelope = reply?.envelope, envelope["code"].tolerantInteger == 200 else { return false }
        return seat.matchesReceipt(envelope["data"]) && envelope["data"]["replayed"].bool == true
    }
}

// MARK: - Orienteering alternatives

public enum OrientAlternativeType: String, CaseIterable, Codable, Hashable {
    case scan = "SCAN", quiz = "QUIZ", photo = "PHOTO"
}

public struct OrientAlternativeRow: Equatable, Hashable {
    public let type: OrientAlternativeType
    public var on: Bool
    public var prompt: String
    /// Always starts empty: the author detail only says whether an answer is set.
    public var answer: String
    public var answerConfigured: Bool

    public init(type: OrientAlternativeType, on: Bool = false, prompt: String = "", answer: String = "", answerConfigured: Bool = false) {
        self.type = type; self.on = on; self.prompt = prompt; self.answer = answer; self.answerConfigured = answerConfigured
    }

    /// `alternativeDrafts` for one node. Nil when the configs were not loaded or the node's rows are malformed.
    static func drafts(_ detail: PlayWireValue, topicID: Int, taskID: Int) -> [OrientAlternativeType: OrientAlternativeRow]? {
        guard detail["topic"]["id"].tolerantInteger == topicID, detail["nodeAlternativeConfigsLoaded"].bool == true,
              let configs = detail["nodeAlternativeConfigs"].object else { return nil }
        let nodeIDs = (detail["chapters"].array ?? []).flatMap { $0["cmsTopicNodeList"].array ?? [] }.compactMap { $0["id"].tolerantInteger }
        guard nodeIDs.contains(taskID) else { return nil }
        guard let rows = configs[String(taskID)]?.array else { return [:] }
        var result: [OrientAlternativeType: OrientAlternativeRow] = [:]
        for row in rows {
            guard let type = row["type"].text.flatMap(OrientAlternativeType.init(rawValue:)), result[type] == nil,
                  row["promptText"] == .null || row["promptText"].text != nil,
                  let enabled = row["enabled"].bool, let configured = row["answerConfigured"].bool else { return nil }
            result[type] = .init(type: type, on: enabled, prompt: row["promptText"].text ?? "", answerConfigured: type != .photo && configured)
        }
        return result
    }

    public static func rows(_ drafts: [OrientAlternativeType: OrientAlternativeRow]) -> [OrientAlternativeRow] {
        OrientAlternativeType.allCases.map { drafts[$0] ?? .init(type: $0) }
    }

    public enum Issue: Equatable { case quizNeedsPromptAndAnswer, photoNeedsPrompt, scanNotConfigured }

    /// `_saveStructureAlts` checks, in the same order.
    public static func issue(_ dirty: [OrientAlternativeRow]) -> Issue? {
        let blank: (String) -> Bool = { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if let missing = dirty.first(where: { $0.on && ($0.type == .quiz ? blank($0.prompt) || (blank($0.answer) && !$0.answerConfigured) : $0.type == .photo && blank($0.prompt)) }) {
            return missing.type == .quiz ? .quizNeedsPromptAndAnswer : .photoNeedsPrompt
        }
        if dirty.contains(where: { $0.on && $0.type == .scan && !$0.answerConfigured }) { return .scanNotConfigured }
        return nil
    }

    /// The readback must match every row this save wrote.
    public static func confirms(_ saved: [OrientAlternativeType: OrientAlternativeRow], dirty: [OrientAlternativeRow]) -> Bool {
        dirty.allSatisfy { row in
            guard let back = saved[row.type], back.on == row.on,
                  back.prompt == row.prompt.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            let wroteAnswer = row.answerConfigured || !row.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return row.type == .photo || !wroteAnswer || back.answerConfigured
        }
    }
}

// MARK: - Circle theme

/// `pages/topic/utils/circle-theme.js` (BL-183): the candidate table and `validateSelection`.
public enum CircleThemeRole: String, CaseIterable { case experience = "EXPERIENCE", rest = "REST", expression = "EXPRESSION" }

public struct CircleThemeCandidate: Equatable, Identifiable {
    public let code: String
    public let name: String
    public let merchant: String
    public let role: CircleThemeRole
    public var id: String { code }
}

public enum CircleThemeCatalog {
    private static func c(_ code: String, _ name: String, _ merchant: String, _ role: CircleThemeRole) -> CircleThemeCandidate {
        .init(code: code, name: name, merchant: merchant, role: role)
    }
    /// Candidate copy is theme content, kept verbatim from the mini-program table.
    public static let candidates: [String: [CircleThemeCandidate]] = [
        "FITNESS": [c("F1", "身体起点", "健身房、私教工作室", .experience), c("F2", "出拳解压", "拳击、搏击、泰拳馆", .experience),
                    c("F3", "柔韧恢复", "瑜伽、普拉提、拉伸馆", .rest), c("F4", "一起攀或一起打", "攀岩馆、球类俱乐部", .experience),
                    c("F5", "城市开跑", "跑团、骑行俱乐部", .expression), c("F6", "运动补给", "轻食店、健康餐、果昔店", .rest),
                    c("F7", "装备试一试", "运动服装、跑鞋、户外店", .expression), c("F8", "放松一下", "运动恢复、拉伸、按摩店", .rest)],
        "MIDLIFE": [c("M1", "安静喝一杯", "咖啡馆、茶馆", .rest), c("M2", "今天穿给自己", "女装、鞋包、买手店", .expression),
                    c("M3", "身体舒展开", "瑜伽、普拉提、舞蹈工作室", .experience), c("M4", "状态焕新", "美发、美甲、护肤、造型店", .expression),
                    c("M5", "重新读点自己的", "书店、文化空间", .experience), c("M6", "做一件小作品", "花店、陶艺、手作工作室", .experience),
                    c("M7", "留一张现在的照片", "摄影馆、写真馆、自拍馆", .expression), c("M8", "晚一点回家", "餐厅、小酒馆、酒吧", .rest)],
        "DATE": [c("C1", "先坐下来聊", "咖啡馆、茶馆", .rest), c("C2", "替对方选一件", "服装、饰品、眼镜、买手店", .expression),
                 c("C3", "选一种彼此的味道", "香氛、护肤、生活方式店", .expression), c("C4", "带一束回家", "花店、植物店", .expression),
                 c("C5", "一起做一件东西", "陶艺、银饰、烘焙、绘画工作室", .experience), c("C6", "吃一个甜点", "甜品店、烘焙店", .rest),
                 c("C7", "留下今天", "自拍馆、照相馆、拍贴店", .experience), c("C8", "最后一杯", "酒吧、小酒馆、无酒精酒吧", .rest)],
        "FRIENDS": [c("P1", "集合第一杯", "咖啡馆、茶饮店", .rest), c("P2", "一起吃点好的", "餐厅、轻食、地方小吃", .rest),
                    c("P3", "朋友互相挑", "服装、古着、饰品店", .expression), c("P4", "玩一局", "桌游店、棋牌空间", .experience),
                    c("P5", "唱一会儿", "KTV、音乐空间", .experience), c("P6", "一起做一件", "陶艺、画室、烘焙、手作店", .experience),
                    c("P7", "拍一张新的", "自拍馆、拍贴店、摄影馆", .expression), c("P8", "最后一轮", "酒吧、小酒馆、无酒精酒吧", .rest)],
        "SHANGHAI": [c("S1", "上海早点", "早餐店、小吃店、烘焙店", .rest), c("S2", "城市咖啡时间", "咖啡馆、烘焙咖啡店", .rest),
                     c("S3", "穿一点上海", "本地服装、古着、旗袍或设计店", .expression), c("S4", "翻几页城市", "书店、杂志店、文化空间", .experience),
                     c("S5", "带走一件本地设计", "文创、设计零售、手作店", .expression), c("S6", "吃一口本地味道", "本帮菜、小吃、甜品店", .rest),
                     c("S7", "留下一张街头感", "自拍馆、拍贴店、摄影服务", .experience), c("S8", "上海夜里见", "酒吧、小酒馆、现场音乐空间", .experience)]
    ]

    public static func theme(_ code: String?) -> [CircleThemeCandidate]? { candidates[(code ?? "").uppercased()] }

    public enum Issue: Equatable { case unknownTheme, count, foreign, missing([CircleThemeRole]) }

    /// `validateSelection`: 3–4 distinct candidates of this theme covering all three roles.
    public static func validate(themeCode: String?, codes: [String]) -> Issue? {
        guard let theme = theme(themeCode) else { return .unknownTheme }
        var seen = Set<String>(); let selected = codes.filter { seen.insert($0).inserted }
        guard (3...4).contains(selected.count) else { return .count }
        let byCode = Dictionary(uniqueKeysWithValues: theme.map { ($0.code, $0) })
        guard selected.allSatisfy({ byCode[$0] != nil }) else { return .foreign }
        let roles = Set(selected.compactMap { byCode[$0]?.role })
        let missing = CircleThemeRole.allCases.filter { !roles.contains($0) }
        return missing.isEmpty ? nil : .missing(missing)
    }
}

/// `project/home` host facts for a circle topic. Nil unless the caller is the host of a circle-theme topic.
public struct CircleThemeHostTopic: Equatable {
    public let themeCode: String
    /// `circleReviewedAt` date part; nil renders "not reviewed yet".
    public let reviewedOn: String?

    init?(_ data: PlayWireValue) {
        guard data["host"].object != nil,
              let code = data["topic"]["circleThemeCode"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else { return nil }
        themeCode = code
        reviewedOn = data["topic"]["circleReviewedAt"].text.flatMap { $0.isEmpty ? nil : String($0.prefix(10)) }
    }
}
