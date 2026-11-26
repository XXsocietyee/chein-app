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

public struct CharacterCardAttribute: Equatable, Identifiable {
    public var id: String { stateKey }
    public let stateKey: String
    public let label: String
    public let value: Int
    public let min: Int
    public let max: Int
    public let displayType: String
    public let persistScope: String
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
    /// Existing `CharacterRpgSheet.read` projection. Nil when the payload has no sheet.
    public let rpgSheet: CharacterRpgSheet?
    /// Server `definitionSource` text. Missing, blank, and `UNKNOWN` stay nil.
    public let definitionSource: String?
    /// Level thresholds per attribute `stateKey` (mini-program `rules.levels`). Display-only.
    public var attributeLevels: [String: [CharacterAttributeLevel]] = [:]
    func updating(breakdown: CharacterCheckBreakdown? = nil, originalRequestID: String? = nil) -> Self {
        .init(topicID: topicID, created: created, running: running, attributes: attributes,
              environment: environment, party: party, equipment: equipment,
              breakdown: breakdown ?? self.breakdown, expiry: expiry,
              originalRequestID: originalRequestID ?? self.originalRequestID,
              rpgSheet: rpgSheet, definitionSource: definitionSource,
              attributeLevels: attributeLevels)
    }
}

/// Read-only phase for `subpackageMember/character/index`.
/// The card stays `GET api/play/character` (and `api/play/rpg/status` when an activity is already in scope).
/// This type does not register a route, mark one live, or open a character-sheet save.
/// Unknown stats are an em dash. A literal integer 0 stays `0`. A numeric string is not 0.
public struct CharacterCardPageModel: Equatable {
    public enum Phase: String, Equatable {
        case loading
        case empty
        case error
        case unknown
        case ready
    }
    public static let unknownStat = "—"
    public let phase: Phase
    public let attributeCountText: String
    public let attributeValueTexts: [String]
    public let attributePercentTexts: [String]
    public let breakdownTotalText: String
    public let breakdownDieText: String
    public let momentumText: String
    public let equipmentQuantityTexts: [String]

    /// Literal JSON integers, including 0. Null, missing, `UNKNOWN`, and a numeric string stay an em dash.
    public static func statText(_ raw: PlayWireValue) -> String {
        PWaveNumberFact.parse(raw).displayText
    }

    public static func statText(_ value: Int?) -> String {
        guard let value else { return unknownStat }
        return String(value)
    }

    /// A point range has no ratio. That is an em dash, not the 0 that `CharacterCardAttribute.percent` returns.
    public static func percentText(value: Int, min: Int, max: Int) -> String {
        guard max > min else { return unknownStat }
        let raw = Double(value - min) / Double(max - min) * 100.0
        let percent = Swift.max(0, Swift.min(100, Int(raw.rounded())))
        return String(percent)
    }

    /// A phase with no card. `.ready` fails closed so a missing card cannot be shown as zero.
    public init(_ phase: Phase) {
        switch phase {
        case .ready: self.init(blank: .unknown)
        case .loading, .empty, .error, .unknown: self.init(blank: phase)
        }
    }

    public init(isCurrent: Bool, availability: WorldFactAvailability, card: CharacterCard?, issue: PlayExperienceError?) {
        // A failed refresh keeps the last ready card. Auth loss and a stale session still blank it.
        // Rebuilding with a nil issue uses the card's own stats, so the failure is not an empty success.
        if let card, isCurrent, availability == .ready, Self.keepsVisibleCard(despite: issue) {
            self.init(isCurrent: true, availability: .ready, card: card, issue: nil)
            return
        }
        switch issue {
        case .malformed:
            self = Self(blank: .unknown)
            return
        case .unknownResult, .rejected, .unauthorized, .staleSession, .unsupported, .persistenceUnavailable, .busy, .invalidAction:
            self = Self(blank: .error)
            return
        case .disabled, nil:
            break
        }
        if availability == .unknown {
            self = Self(blank: .unknown)
            return
        }
        guard isCurrent, availability == .ready, let card else {
            self = Self(blank: .loading)
            return
        }
        let values = card.attributes.map { String($0.value) }
        let percents = card.attributes.map { Self.percentText(value: $0.value, min: $0.min, max: $0.max) }
        let quantities = card.equipment.items.map { Self.statText($0.quantity) }
        self.init(phase: card.attributes.isEmpty ? .empty : .ready,
                  attributeCountText: String(card.attributes.count),
                  attributeValueTexts: values,
                  attributePercentTexts: percents,
                  breakdownTotalText: Self.statText(card.breakdown.total),
                  breakdownDieText: Self.statText(card.breakdown.die),
                  momentumText: Self.statText(card.rpgSheet?.momentum?.value),
                  equipmentQuantityTexts: quantities)
    }

    private init(phase: Phase, attributeCountText: String, attributeValueTexts: [String], attributePercentTexts: [String],
                 breakdownTotalText: String, breakdownDieText: String, momentumText: String, equipmentQuantityTexts: [String]) {
        self.phase = phase
        self.attributeCountText = attributeCountText
        self.attributeValueTexts = attributeValueTexts
        self.attributePercentTexts = attributePercentTexts
        self.breakdownTotalText = breakdownTotalText
        self.breakdownDieText = breakdownDieText
        self.momentumText = momentumText
        self.equipmentQuantityTexts = equipmentQuantityTexts
    }

    /// Ordinary read failures leave a card that was already on screen. Sign-in and session changes do not.
    private static func keepsVisibleCard(despite issue: PlayExperienceError?) -> Bool {
        switch issue {
        case .malformed, .unknownResult, .unsupported, .persistenceUnavailable, .busy, .invalidAction, .rejected, .disabled:
            return true
        case .unauthorized, .staleSession, nil:
            return false
        }
    }

    private init(blank phase: Phase) {
        self.phase = phase
        attributeCountText = Self.unknownStat
        attributeValueTexts = []
        attributePercentTexts = []
        breakdownTotalText = Self.unknownStat
        breakdownDieText = Self.unknownStat
        momentumText = Self.unknownStat
        equipmentQuantityTexts = []
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
    public var pageModel: CharacterCardPageModel {
        CharacterCardPageModel(isCurrent: isCurrent, availability: availability, card: card, issue: issue)
    }
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
    /// The page calls this without reloading. A different account clears the old card.
    /// No session is the signed-out reader: the card leaves the screen and 登录 can read again.
    /// `dismiss()` stays retired so a late read cannot refill it.
    public func cardIfCurrent() -> CharacterCard? {
        guard isCurrent else {
            if card != nil { card = nil }
            if currentSession() == nil {
                if issue != .unauthorized { issue = .unauthorized }
                if owner != nil { owner = nil }
            } else if owner != nil {
                retired = true
            }
            if availability != .waitingSource { availability = .waitingSource }
            return nil
        }
        return availability == .ready ? card : nil
    }
    public func load() async {
        guard !retired else { card = nil; availability = .waitingSource; return }
        guard let session = currentSession() else {
            // PLY-24-3: signed out is a sign-in failure, not a permanent loading lease.
            card = nil
            owner = nil
            issue = .unauthorized
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
            var attributeLevels: [String: [CharacterAttributeLevel]] = [:]
            var rpgSheet = CharacterRpgSheet.read(raw["rpg"])
            var definitionSource = Self.keptDefinitionSource(raw["definitionSource"])
            for row in rows {
                guard let stateKey = row["stateKey"].text, !stateKey.isEmpty, stateKey.utf16.count <= 64, keys.insert(stateKey).inserted,
                      let label = row["label"].text, !label.isEmpty, label.utf16.count <= 64,
                      let value = row["value"].integer, let min = row["min"].integer, let max = row["max"].integer,
                      min <= max, value >= min, value <= max,
                      let display = row["displayType"].text, !display.isEmpty,
                      let scope = row["persistScope"].text, ["run", "topic"].contains(scope) else { throw PlayExperienceError.malformed }
                attributes.append(.init(stateKey: stateKey, label: label, value: value, min: min, max: max, displayType: display, persistScope: scope))
                let levels = CharacterAttributeLevel.read(rules: row["rules"])
                if !levels.isEmpty { attributeLevels[stateKey] = levels }
            }
            var environment = WorldEnvironmentProjection.read(raw)
            var expiry = EnvironmentExpiryClock.read(raw["rpg"]["environment"] == .null ? raw["environment"] : raw["rpg"]["environment"])
            var party = PartyRosterProjection.read(party: raw["party"] == .null ? raw["rpg"]["party"] : raw["party"])
            var equipment = WorldEquipmentProjection.read(raw)
            if let activityID, service.enabled.contains(.reads) {
                query["activityId"] = String(activityID)
                let status = try await service.request("api/play/rpg/status", query: query, capability: .reads, token: session.token)
                try check(session, stamp)
                if status["topicId"].integer == topicID {
                    let overlay = WorldEnvironmentProjection.read(status)
                    if overlay.availability == .ready { environment = overlay }
                    let clock = EnvironmentExpiryClock.read(status["rpg"]["environment"] == .null ? status["environment"] : status["rpg"]["environment"])
                    if clock.availability != .waitingSource { expiry = clock }
                    let gear = WorldEquipmentProjection.read(status)
                    if gear.availability == .ready { equipment = gear }
                    let roster = PartyRosterProjection.read(party: status["party"] == .null ? status["rpg"]["party"] : status["party"])
                    if roster.availability == .ready { party = roster }
                    if let sheet = CharacterRpgSheet.read(status["rpg"]) { rpgSheet = sheet }
                    if definitionSource == nil, let source = Self.keptDefinitionSource(status["definitionSource"]) {
                        definitionSource = source
                    }
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
                                 rpgSheet: rpgSheet, definitionSource: definitionSource,
                                 attributeLevels: attributeLevels)
            availability = .ready
        } catch is CancellationError {
            return
        } catch PlayExperienceError.unauthorized {
            guard generation == stamp, let session = owner, currentSession() == session else { return }
            // Drop the owner so this lease is no longer current, without dismiss()'s retired latch,
            // so the existing sign-in sheet can call load() again.
            card = nil
            owner = nil
            issue = .unauthorized
            availability = .waitingSource
            onUnauthorized(session)
        } catch {
            guard generation == stamp else { return }
            if Task.isCancelled { return }
            let failed = error as? PlayExperienceError ?? .unknownResult
            // PLY-24-6: a failed refresh keeps the last card and records the failure.
            // It does not swap in an empty ready card. Sign-out and account changes still clear it.
            if failed != .staleSession, isCurrent, availability == .ready, card != nil {
                issue = failed
                return
            }
            card = nil
            issue = failed
            availability = failed == .disabled ? .waitingSource : .unknown
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
    /// A missing key, blank text, and the token UNKNOWN are not a definition source.
    private static func keptDefinitionSource(_ raw: PlayWireValue) -> String? {
        guard case .string(let value) = raw else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "UNKNOWN" else { return nil }
        return trimmed
    }
    private func check(_ session: PlayExperienceSession, _ generation: UInt64) throws {
        guard self.generation == generation, !retired, currentSession() == session, !Task.isCancelled else { throw PlayExperienceError.staleSession }
    }
}
