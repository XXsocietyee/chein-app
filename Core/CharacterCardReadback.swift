import Foundation
import Observation

/// Authoritative check breakdown from a signed receipt. Totals are never recomputed
/// from die + skill + mods, and success is never inferred from total vs DC.
/// Missing breakdowns stay `WAITING_SOURCE`; malformed payloads stay `UNKNOWN`.
public struct CharacterCheckBreakdown: Equatable {
    public struct Skill: Equatable {
        public let hidden: Bool
        public let statKey: String?
        public let label: String?
        public let value: Int?
    }
    public struct Situational: Equatable {
        public let raw: Int?
        public let applied: Int?
        public let cap: Int?
    }
    public let availability: WorldFactAvailability
    public let die: Int?
    public let skill: Skill?
    public let situational: Situational?
    public let bargain: Int?
    public let momentum: Int?
    public let total: Int?
    public let dc: Int?
    public let natAuto: Bool?
    public static let waitingSource = CharacterCheckBreakdown(
        availability: .waitingSource, die: nil, skill: nil, situational: nil,
        bargain: nil, momentum: nil, total: nil, dc: nil, natAuto: nil)
    public static func read(_ raw: PlayWireValue) -> Self {
        if raw == .null { return .waitingSource }
        guard raw.object != nil else { return .init(availability: .unknown, die: nil, skill: nil, situational: nil, bargain: nil, momentum: nil, total: nil, dc: nil, natAuto: nil) }
        let skill: Skill?
        if raw["skill"] == .null { skill = nil }
        else if raw["skill"]["hidden"].bool == true {
            skill = .init(hidden: true, statKey: nil, label: nil, value: nil)
        } else if raw["skill"].object != nil {
            skill = .init(hidden: false, statKey: raw["skill"]["statKey"].text, label: raw["skill"]["label"].text, value: raw["skill"]["value"].integer)
        } else { return .init(availability: .unknown, die: nil, skill: nil, situational: nil, bargain: nil, momentum: nil, total: nil, dc: nil, natAuto: nil) }
        let situational: Situational?
        if raw["situational"] == .null { situational = nil }
        else if raw["situational"].object != nil {
            situational = .init(raw: raw["situational"]["raw"].integer, applied: raw["situational"]["applied"].integer, cap: raw["situational"]["cap"].integer)
        } else { return .init(availability: .unknown, die: nil, skill: nil, situational: nil, bargain: nil, momentum: nil, total: nil, dc: nil, natAuto: nil) }
        return .init(availability: .ready, die: raw["die"].integer, skill: skill, situational: situational,
                     bargain: raw["bargain"].integer, momentum: raw["momentum"].integer,
                     total: raw["total"].integer, dc: raw["dc"].integer, natAuto: raw["natAuto"].bool)
    }
}

public struct CharacterAttributeLevel: Equatable, Sendable {
    public let at: Int
    public let label: String
    public init(at: Int, label: String) {
        self.at = at
        self.label = label
    }
}

public struct CharacterStarPip: Equatable, Identifiable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let filled: Bool
    public init(index: Int, filled: Bool) {
        self.index = index
        self.filled = filled
    }
}

public struct CharacterCardAttribute: Equatable, Identifiable, Sendable {
    public var id: String { stateKey }
    public let stateKey: String
    public let label: String
    public let value: Int
    public let min: Int
    public let max: Int
    public let displayType: String
    public let persistScope: String
    public let levels: [CharacterAttributeLevel]

    public init(
        stateKey: String,
        label: String,
        value: Int,
        min: Int,
        max: Int,
        displayType: String,
        persistScope: String,
        levels: [CharacterAttributeLevel] = []
    ) {
        self.stateKey = stateKey
        self.label = label
        self.value = value
        self.min = min
        self.max = max
        self.displayType = displayType
        self.persistScope = persistScope
        self.levels = levels
    }

    public var levelLabel: String {
        let sorted = levels.filter { !$0.label.isEmpty }.sorted { $0.at < $1.at }
        var matched = ""
        for level in sorted where value >= level.at {
            matched = level.label
        }
        return matched
    }

    public var scopeText: String {
        switch persistScope {
        case "topic": return "同主题跨局保留"
        case "run": return "每局重置"
        default: return "保留范围未记录"
        }
    }

    public var rangeText: String {
        "范围 \(min)–\(max)"
    }

    public var percent: Int {
        guard max > min else { return 0 }
        let raw = Double(value - min) / Double(max - min) * 100.0
        return Swift.max(0, Swift.min(100, Int(raw.rounded())))
    }

    public var stars: [CharacterStarPip] {
        guard displayType == "stars", min == 0, max > 0, max <= 10 else { return [] }
        return (0..<max).map { idx in
            CharacterStarPip(index: idx, filled: idx < value)
        }
    }
}

public struct CharacterRpgMomentum: Equatable, Sendable {
    public let value: Int
    public let max: Int
    public let percent: Int

    public init(value: Int, max: Int) {
        let clampedMax = Swift.max(1, max)
        let clampedVal = Swift.max(0, Swift.min(clampedMax, value))
        self.value = clampedVal
        self.max = clampedMax
        self.percent = Int((Double(clampedVal) / Double(clampedMax) * 100.0).rounded())
    }
}

public struct CharacterRpgClock: Equatable, Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let label: String
    public let value: Int
    public let segments: Int
    public let percent: Int

    public init(key: String, label: String, value: Int, segments: Int) {
        let seg = Swift.max(1, segments)
        let val = Swift.max(0, Swift.min(seg, value))
        self.key = key
        self.label = label
        self.value = val
        self.segments = seg
        self.percent = Int((Double(val) / Double(seg) * 100.0).rounded())
    }
}

public struct CharacterRpgTrait: Equatable, Identifiable, Sendable {
    public var id: String { "\(tag):\(key)" }
    public let key: String
    public let label: String
    public let desc: String
    public let tag: String

    public init(key: String, label: String, desc: String, tag: String) {
        self.key = key
        self.label = label
        self.desc = desc
        self.tag = tag
    }
}

public struct CharacterRpgSheet: Equatable, Sendable {
    public let momentum: CharacterRpgMomentum?
    public let clocks: [CharacterRpgClock]
    public let facets: [CharacterRpgTrait]
    public let aspects: [CharacterRpgTrait]

    public init(
        momentum: CharacterRpgMomentum?,
        clocks: [CharacterRpgClock],
        facets: [CharacterRpgTrait],
        aspects: [CharacterRpgTrait]
    ) {
        self.momentum = momentum
        self.clocks = clocks
        self.facets = facets
        self.aspects = aspects
    }

    public static func read(_ raw: PlayWireValue) -> CharacterRpgSheet? {
        guard raw.object != nil, raw["enabled"].bool == true else { return nil }
        let momentum: CharacterRpgMomentum?
        if let mVal = raw["momentum"].integer, let mMax = raw["momentumMax"].integer, mMax > 0 {
            momentum = CharacterRpgMomentum(value: mVal, max: mMax)
        } else {
            momentum = nil
        }
        let clocks: [CharacterRpgClock] = (raw["clocks"].array ?? []).enumerated().compactMap { idx, c in
            guard c.object != nil,
                  let val = c["value"].integer,
                  let seg = c["segments"].integer, seg > 0 else { return nil }
            let key = c["var"].text ?? "clock-\(idx)"
            let label = (c["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? key
            return CharacterRpgClock(key: key, label: label, value: val, segments: seg)
        }
        let facets: [CharacterRpgTrait] = (raw["facets"].array ?? []).enumerated().compactMap { idx, f in
            guard f.object != nil,
                  let label = f["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else { return nil }
            let key = f["key"].text ?? "facet-\(idx)"
            let desc = f["desc"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return CharacterRpgTrait(key: key, label: label, desc: desc, tag: "侧面")
        }
        let aspects: [CharacterRpgTrait] = (raw["aspects"].array ?? []).enumerated().compactMap { idx, a in
            guard a.object != nil,
                  let label = a["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else { return nil }
            let key = a["key"].text ?? "aspect-\(idx)"
            let desc = a["desc"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return CharacterRpgTrait(key: key, label: label, desc: desc, tag: "本局特质")
        }
        if momentum == nil && clocks.isEmpty && facets.isEmpty && aspects.isEmpty {
            return nil
        }
        return CharacterRpgSheet(momentum: momentum, clocks: clocks, facets: facets, aspects: aspects)
    }
}

public struct CharacterCard: Equatable {
    public let topicID: Int
    public let created: Bool
    public let running: Bool
    public let attributes: [CharacterCardAttribute]
    public let environment: WorldEnvironmentProjection
    public let party: PartyRosterProjection
    public let equipment: WorldEquipmentProjection
    public let breakdown: CharacterCheckBreakdown
    public let expiry: EnvironmentExpiryClock
    public let originalRequestID: String?
    public let definitionSource: String?
    public let rpgSheet: CharacterRpgSheet?

    public init(
        topicID: Int,
        created: Bool,
        running: Bool,
        attributes: [CharacterCardAttribute],
        environment: WorldEnvironmentProjection,
        party: PartyRosterProjection,
        equipment: WorldEquipmentProjection,
        breakdown: CharacterCheckBreakdown,
        expiry: EnvironmentExpiryClock,
        originalRequestID: String?,
        definitionSource: String? = nil,
        rpgSheet: CharacterRpgSheet? = nil
    ) {
        self.topicID = topicID
        self.created = created
        self.running = running
        self.attributes = attributes
        self.environment = environment
        self.party = party
        self.equipment = equipment
        self.breakdown = breakdown
        self.expiry = expiry
        self.originalRequestID = originalRequestID
        self.definitionSource = definitionSource
        self.rpgSheet = rpgSheet
    }

    public var heading: String {
        created ? "本人角色卡" : "角色模板"
    }

    public var statusText: String {
        if created {
            return running ? "本局进行中" : "已建立"
        }
        return "尚未建卡"
    }

    public var definitionNote: String {
        switch definitionSource {
        case "SESSION_SNAPSHOT_PARTIAL":
            return "部分跨局属性展示当前主题定义，不代表建卡时原始区间。"
        case "SESSION_SNAPSHOT_V1":
            return "展示本局开始时的角色属性定义。"
        case "LEGACY_LIVE":
            return "历史角色未保存建卡快照，当前按主题最新规则展示。"
        default:
            return created
                ? "仅展示服务端已记录的本人角色数值。"
                : "当前尚未建立本人角色，以下为主题属性模板与初始值。"
        }
    }

    func updating(breakdown: CharacterCheckBreakdown? = nil, originalRequestID: String? = nil) -> Self {
        .init(topicID: topicID, created: created, running: running, attributes: attributes,
              environment: environment, party: party, equipment: equipment,
              breakdown: breakdown ?? self.breakdown, expiry: expiry,
              originalRequestID: originalRequestID ?? self.originalRequestID,
              definitionSource: definitionSource, rpgSheet: rpgSheet)
    }
}

/// Ported from `utils/user-character.js` for character sheet & topic relation checks.
public enum CharacterSheetPresenter {
    public struct FailureView: Equatable, Sendable {
        public let state: String
        public let error: String
        public let canRetry: Bool
    }

    public static func exactId(_ value: String?) -> String {
        let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: "^[1-9]\\d*$", options: .regularExpression) != nil else { return "" }
        return text
    }

    public static func exactId(_ value: Int?) -> String {
        guard let value, value > 0 else { return "" }
        return String(value)
    }

    public static func registrationTopic(_ item: PlayWireValue) -> (topicId: String, activityId: String)? {
        guard item.object != nil else { return nil }
        let topicId = exactId(item["topicId"].text ?? item["topicId"].integer.map(String.init))
            .isEmpty ? exactId(item["ownerType"].integer == 1 ? (item["ownerId"].text ?? item["ownerId"].integer.map(String.init)) : nil)
            : exactId(item["topicId"].text ?? item["topicId"].integer.map(String.init))
        guard !topicId.isEmpty else { return nil }
        let actRaw = item["activityId"].text ?? item["activityId"].integer.map(String.init)
        let ownerActRaw = item["ownerType"].integer == 0 ? (item["ownerId"].text ?? item["ownerId"].integer.map(String.init)) : nil
        let activityId = !exactId(actRaw).isEmpty ? exactId(actRaw) : exactId(ownerActRaw)
        return (topicId: topicId, activityId: activityId)
    }

    public static func hasTopicRelation(rows: [PlayWireValue], topicID: String) -> Bool {
        let target = exactId(topicID)
        guard !target.isEmpty else { return false }
        return rows.contains { registrationTopic($0)?.topicId == target }
    }

    public static func failure(code: Int?, message: String?) -> FailureView {
        if code == 401 {
            return FailureView(state: "unauthorized", error: "请先登录后查看角色卡", canRetry: false)
        }
        let msg = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if code == 403 || msg.contains("无权") {
            return FailureView(state: "forbidden", error: msg.isEmpty ? "无权查看该角色卡" : msg, canRetry: false)
        }
        return FailureView(state: "error", error: msg.isEmpty ? "角色卡加载失败，请稍后重试" : msg, canRetry: true)
    }
}

/// Read-only original route action. Caller supplies an already-resolved actionId;
/// this does not invent a hashed action-id prefix. Missing mapper is WAITING_SOURCE.
/// A returned action id that is not the requested id is not a replay.
public enum RouteActionOriginalRecovery {
    public static let rpgRequestReceipts = "rpgv2.RpgRequestReceipts"
    public struct Receipt: Equatable {
        public let actionID: String
        public let replay: Bool
    }
    public struct WaitingSource: Error, Equatable {
        public let capability: String
    }
    public static func recoverFromRouteAction(
        sessionID: Int64?,
        memberID: Int64?,
        actionID: String?,
        selectAction: ((Int64, Int64, String) -> String?)?
    ) throws -> Receipt? {
        let trimmed = actionID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let sessionID, let memberID, !trimmed.isEmpty else { return nil }
        guard let selectAction else {
            throw WaitingSource(capability: rpgRequestReceipts)
        }
        guard let found = selectAction(sessionID, memberID, trimmed), found == trimmed else { return nil }
        return Receipt(actionID: trimmed, replay: true)
    }
}

/// Read IGameSessionRuntimeService.receipt. PENDING is not applied. Does not command.
public enum GameReceiptOriginalRecovery {
    public static let gameReceipt = "gameSession.receipt"
    public struct Read: Equatable {
        public let requestID: String
        public let outcome: String
        public let replayed: Bool
        public let applied: Bool
    }
    public struct WaitingSource: Error, Equatable {
        public let capability: String
    }
    public static func recoverFromGameReceipt(
        memberID: Int64?,
        activityID: Int64?,
        requestID: String?,
        receipt: ((Int64, Int64, String) async throws -> (requestID: String, activityID: Int64, outcome: String, replayed: Bool)?)?
    ) async throws -> Read? {
        let trimmed = requestID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let memberID, memberID > 0, let activityID, activityID > 0, !trimmed.isEmpty else { return nil }
        guard let receipt else {
            throw WaitingSource(capability: gameReceipt)
        }
        guard let found = try await receipt(memberID, activityID, trimmed),
              found.requestID == trimmed, found.activityID == activityID else { return nil }
        return Read(requestID: trimmed, outcome: found.outcome, replayed: found.replayed,
                    applied: found.outcome == "APPLIED")
    }
}

/// Existing Play/RPG surfaces (`PlayExperienceView`, `PlayAdvancedView`,
/// `PlayPlayerTeamStatusView`, `JourneyCheckCoordinator`, `PlayObjectCardRevealView`)
/// stay the host. This lease only projects character / world facts through
/// `PlayExperienceService` and never opens a private transport.
@available(macOS 14.0, *)
@MainActor @Observable public final class CharacterCardReadback {
    public let topicID: Int
    public let activityID: Int?
    public private(set) var card: CharacterCard?
    public private(set) var availability: WorldFactAvailability = .waitingSource
    public private(set) var originalRequestID: String?
    public private(set) var issue: PlayExperienceError?
    private let service: PlayExperienceService
    private let currentSession: () -> PlayExperienceSession?
    private let onUnauthorized: (PlayExperienceSession) -> Void
    private var owner: PlayExperienceSession?
    private var original: PlayPlayerCommand?
    private var generation: UInt64 = 0
    private var retired = false
    public init?(topicID: Int, activityID: Int? = nil, service: PlayExperienceService,
                 currentSession: @escaping () -> PlayExperienceSession?,
                 onUnauthorized: @escaping (PlayExperienceSession) -> Void = { _ in }) {
        guard topicID > 0, activityID.map({ $0 > 0 }) ?? true, service.enabled.contains(.reads) else { return nil }
        self.topicID = topicID; self.activityID = activityID; self.service = service
        self.currentSession = currentSession; self.onUnauthorized = onUnauthorized
    }
    public var isCurrent: Bool { !retired && owner != nil && owner == currentSession() }
    public func dismiss() { retired = true; card = nil; availability = .waitingSource }
    /// Freeze the original command identity. A new UUID is never minted here.
    public func bindOriginal(_ command: PlayPlayerCommand) {
        guard command.requestID.range(of: "^[A-Za-z0-9_-]{8,64}$", options: .regularExpression) != nil else { return }
        if let originalRequestID { guard originalRequestID == command.requestID else { return } }
        original = command; originalRequestID = command.requestID
        if let card { self.card = card.updating(originalRequestID: command.requestID) }
    }
    public func acceptBreakdown(_ raw: PlayWireValue) {
        guard isCurrent, let card else { return }
        self.card = card.updating(breakdown: CharacterCheckBreakdown.read(raw["breakdown"] == .null ? raw : raw["breakdown"]),
                                  originalRequestID: originalRequestID)
    }
    /// The page calls this without reloading. A revoked lease clears the old card.
    public func cardIfCurrent() -> CharacterCard? {
        guard isCurrent else {
            card = nil
            if owner != nil { retired = true }
            availability = .waitingSource
            return nil
        }
        return availability == .ready ? card : nil
    }
    public func load() async {
        guard !retired else { card = nil; availability = .waitingSource; return }
        guard let session = currentSession() else {
            card = nil
            if owner != nil { retired = true }
            availability = .waitingSource
            return
        }
        if owner != nil && owner != session { card = nil; availability = .unknown; issue = .staleSession; return }
        owner = session; generation &+= 1; let stamp = generation; issue = nil
        do {
            var query = ["topicId": String(topicID)]
            let raw = try await service.request("api/play/character", query: query, capability: .reads, token: session.token)
            try check(session, stamp)
            guard let topic = raw["topicId"].integer, topic == topicID,
                  let created = raw["created"].bool, let running = raw["running"].bool,
                  let rows = raw["attributes"].array else { throw PlayExperienceError.malformed }
            var attributes: [CharacterCardAttribute] = []; var keys = Set<String>()
            for row in rows {
                guard let stateKey = row["stateKey"].text, !stateKey.isEmpty, stateKey.utf16.count <= 64, keys.insert(stateKey).inserted,
                      let label = row["label"].text, !label.isEmpty, label.utf16.count <= 64,
                      let value = row["value"].integer, let min = row["min"].integer, let max = row["max"].integer,
                      min <= max, value >= min, value <= max,
                      let display = row["displayType"].text, !display.isEmpty,
                      let scope = row["persistScope"].text, ["run", "topic"].contains(scope) else { throw PlayExperienceError.malformed }
                let rawLevels = (row["rules"]["levels"].array ?? row["levels"].array ?? []).compactMap { lvl -> CharacterAttributeLevel? in
                    guard let at = lvl["at"].integer,
                          let lbl = lvl["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !lbl.isEmpty else { return nil }
                    return CharacterAttributeLevel(at: at, label: lbl)
                }
                attributes.append(.init(stateKey: stateKey, label: label, value: value, min: min, max: max, displayType: display, persistScope: scope, levels: rawLevels))
            }
            let definitionSource = raw["definitionSource"].text
            var rpgSheet = CharacterRpgSheet.read(raw["rpg"])
            var environment = WorldEnvironmentProjection.read(raw)
            var expiry = EnvironmentExpiryClock.read(raw["rpg"]["environment"] == .null ? raw["environment"] : raw["rpg"]["environment"])
            var party = PartyRosterProjection.read(party: raw["party"] == .null ? raw["rpg"]["party"] : raw["party"])
            var equipment = WorldEquipmentProjection.read(raw)
            if let activityID, service.enabled.contains(.reads) {
                query["activityId"] = String(activityID)
                let status = try await service.request("api/play/rpg/status", query: query, capability: .reads, token: session.token)
                try check(session, stamp)
                if status["topicId"].integer == topicID {
                    if let statusRpg = CharacterRpgSheet.read(status["rpg"]) { rpgSheet = statusRpg }
                    let overlay = WorldEnvironmentProjection.read(status)
                    if overlay.availability == .ready { environment = overlay }
                    let clock = EnvironmentExpiryClock.read(status["rpg"]["environment"] == .null ? status["environment"] : status["rpg"]["environment"])
                    if clock.availability != .waitingSource { expiry = clock }
                    let gear = WorldEquipmentProjection.read(status)
                    if gear.availability == .ready { equipment = gear }
                    let roster = PartyRosterProjection.read(party: status["party"] == .null ? status["rpg"]["party"] : status["party"])
                    if roster.availability == .ready { party = roster }
                }
                if party.availability == .waitingSource {
                    do {
                        let projection = try await service.playerProjection(activityID: activityID, token: session.token)
                        try check(session, stamp)
                        party = PartyRosterProjection.read(teamActions: projection.teamActions)
                    } catch {
                        try check(session, stamp)
                        party = .unknown
                    }
                }
            }
            try check(session, stamp)
            card = CharacterCard(topicID: topic, created: created, running: running, attributes: attributes,
                                 environment: environment, party: party, equipment: equipment,
                                 breakdown: .waitingSource, expiry: expiry, originalRequestID: originalRequestID,
                                 definitionSource: definitionSource, rpgSheet: rpgSheet)
            availability = .ready
        } catch is CancellationError {
            return
        } catch PlayExperienceError.unauthorized {
            guard generation == stamp, let session = owner, currentSession() == session else { return }
            card = nil
            retired = true
            issue = .unauthorized
            availability = .waitingSource
            onUnauthorized(session)
        } catch {
            guard generation == stamp else { return }
            card = nil
            issue = error as? PlayExperienceError ?? .unknownResult
            availability = issue == .disabled ? .waitingSource : .unknown
        }
    }
    /// Replay the frozen command/requestId through the existing session writer. No new identity.
    public func retryOriginal() async {
        guard isCurrent, let session = owner, session == currentSession(),
              let command = original, let originalRequestID, command.requestID == originalRequestID else { return }
        guard service.enabled.contains(.playerCommands) else { issue = .disabled; availability = .waitingSource; return }
        generation &+= 1; let stamp = generation; issue = nil
        do {
            _ = try await service.playerCommand(command, token: session.token)
            try check(session, stamp)
            await load()
        } catch PlayExperienceError.unknownResult {
            guard generation == stamp, currentSession() == session else { return }
            do {
                let recovered = try await GameReceiptOriginalRecovery.recoverFromGameReceipt(
                    memberID: Int64(session.accountID),
                    activityID: Int64(command.activityID),
                    requestID: command.requestID,
                    receipt: { _, _, _ in
                        let found = try await self.service.playerReceipt(command, token: session.token)
                        return (found.requestID, Int64(found.activityID), found.outcome, false)
                    })
                guard let recovered else {
                    availability = .unknown
                    return
                }
                if recovered.applied || recovered.outcome == "FAILED" || recovered.outcome == "APPLIED" {
                    try check(session, stamp)
                    await load()
                    return
                }
                availability = .unknown
            } catch {
                guard generation == stamp else { return }
                issue = error as? PlayExperienceError ?? .unknownResult
                availability = .unknown
            }
        } catch {
            guard generation == stamp else { return }
            issue = error as? PlayExperienceError ?? .unknownResult
            availability = .unknown
        }
    }
    private func check(_ session: PlayExperienceSession, _ generation: UInt64) throws {
        guard self.generation == generation, !retired, currentSession() == session, !Task.isCancelled else { throw PlayExperienceError.staleSession }
    }
}
