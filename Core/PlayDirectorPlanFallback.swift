import Foundation

/// Port of `pages/club/topic-detail/plan-fallback.js` (`PLAN_FALLBACK`).
/// Checks `/api/game/session/shared/control` and submits `POST /api/game/session/command`
/// with action `PLAN_FALLBACK` and a 1–500 character reason without mutating `PlayDirectorAction`.
public struct PlayPlanFallbackStatus: Equatable {
    public let known: Bool
    public let available: Bool
    public let reason: String
    public let controlRevision: Int?

    public init(known: Bool, available: Bool, reason: String, controlRevision: Int?) {
        self.known = known
        self.available = available
        self.reason = reason
        self.controlRevision = controlRevision
    }

    private static let disabledReasons: [String: String] = [
        "FALLBACK_NOT_CONFIGURED": "本场不能用默认结局收尾",
        "NO_EFFECTIVE_TEAMS": "没有可参与的队伍",
        "PLAN_AVAILABLE": "仍有通过或待共识的方案",
        "BALLOT_NOT_FINISHED": "尚未完成表决或全队拒绝确认",
        "BALLOT_CHANGED": "库存已变化，需重新表决",
        "SESSION_ENDED": "本局已结束",
        "SESSION_PAUSED": "本局已暂停",
        "RULE_BLOCKED": "当前服务时段不可收尾",
        "NOT_STAFF": "仅本场工作人员可操作"
    ]

    public static func present(control: PlayWireValue?, expectedRevision: Int) -> Self {
        let world = control?["world"]
        guard let world, case .bool(let available) = world["fallbackAvailable"] else {
            return .init(known: false, available: false, reason: "", controlRevision: nil)
        }
        let revision = control?["revision"].integer
        let synchronized = revision == expectedRevision
        let actions = Set(control?["availableActions"].array?.compactMap(\.text) ?? [])
        let canFallback = synchronized && available && actions.contains("PLAN_FALLBACK")
        let disabledCode = world["fallbackDisabledReason"].text ?? ""
        let reason: String
        if !synchronized {
            reason = "场次状态已更新，请重新加载后确认"
        } else {
            reason = Self.disabledReasons[disabledCode] ?? disabledCode
        }
        return .init(known: true, available: canFallback, reason: reason, controlRevision: revision)
    }

    public static func validatedReason(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 500 else {
            throw PlayExperienceError.invalidAction
        }
        return trimmed
    }
}

public struct PlayPlanFallbackResult: Equatable {
    public let title: String
    public let endingKey: String?
    public let reason: String
}

extension PlayExperienceService {
    /// Fetches shared-control eligibility for `PLAN_FALLBACK` (`GET /api/game/session/shared/control`).
    public func planFallbackStatus(activityID: Int, expectedRevision: Int, token: String) async throws -> PlayPlanFallbackStatus {
        guard activityID > 0, expectedRevision >= 0 else { throw PlayExperienceError.invalidAction }
        let raw = try await request("api/game/session/shared/control", query: ["activityId": String(activityID)],
                                    capability: .reads, token: token)
        return PlayPlanFallbackStatus.present(control: raw, expectedRevision: expectedRevision)
    }

    /// Submits `PLAN_FALLBACK` with a 1–500 char reason (`POST /api/game/session/command`).
    public func submitPlanFallback(activityID: Int, expectedRevision: Int, reason: String,
                                       requestID: String = UUID().uuidString, token: String) async throws -> PlayPlanFallbackResult {
        guard activityID > 0, expectedRevision >= 0,
              requestID.range(of: "^[A-Za-z0-9_-]{8,64}$", options: .regularExpression) != nil else {
            throw PlayExperienceError.invalidAction
        }
        let cleanReason = try PlayPlanFallbackStatus.validatedReason(reason)
        let body: [String: PlayWireValue] = [
            "activityId": .int(activityID),
            "nodeId": .null,
            "expectedRevision": .int(expectedRevision),
            "requestId": .string(requestID),
            "action": .string("PLAN_FALLBACK"),
            "payload": .object(["reason": .string(cleanReason)])
        ]
        let raw = try await request("api/game/session/command", json: body, capability: .directorCommands, token: token)
        let outcome = raw["outcome"].text ?? ""
        guard ["APPLIED", "PENDING"].contains(outcome) else { throw PlayExperienceError.rejected(409, raw["reason"].text ?? raw["msg"].text) }
        let result = raw["result"]["result"]
        let title = result["title"].text ?? "已按默认结局收尾"
        return PlayPlanFallbackResult(title: title, endingKey: result["endingKey"].text, reason: result["reason"].text ?? cleanReason)
    }
}
