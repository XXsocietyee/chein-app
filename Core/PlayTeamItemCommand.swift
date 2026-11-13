import Foundation

/// TEAM backpack commands from `pages/play/utils/theme-backpack.js` (`ITEM_USE`, `ITEM_DISCARD`, `ITEM_RECEIVE` only).
public enum PlayTeamItemCommandBody {
    public static let actions = ["ITEM_USE", "ITEM_DISCARD", "ITEM_RECEIVE"]

    public static func accepts(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        let keys = Set(object.keys)
        guard keys.isSubset(of: ["activityId", "nodeId", "requestId", "expectedRevision", "action", "payload", "authorityEpoch"]),
              keys.isSuperset(of: ["activityId", "nodeId", "requestId", "expectedRevision", "action", "payload"]) else { return false }
        guard object["nodeId"] is NSNull else { return false }
        guard let activity = exactInt(object["activityId"]), activity > 0 else { return false }
        guard let revision = exactInt(object["expectedRevision"]), revision >= 0 else { return false }
        guard let requestID = object["requestId"] as? String, validRequestID(requestID) else { return false }
        guard let action = object["action"] as? String, actions.contains(action) else { return false }
        if keys.contains("authorityEpoch") {
            guard let epoch = exactInt(object["authorityEpoch"]), (1...2_147_483_647).contains(epoch) else { return false }
        }
        guard let payload = object["payload"] as? [String: Any] else { return false }
        return payloadAccepts(payload)
    }

    public static func validRequestID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_-]{8,64}$", options: .regularExpression) != nil
    }

    private static func payloadAccepts(_ payload: [String: Any]) -> Bool {
        let keys = Set(payload.keys)
        guard keys.isSubset(of: ["contentId", "discardOwned"]), keys.contains("contentId") else { return false }
        guard let contentID = payload["contentId"] as? String, !contentID.isEmpty, contentID.count <= 128,
              contentID.unicodeScalars.allSatisfy({ !$0.properties.isDefaultIgnorableCodePoint && $0.value >= 32 }) else { return false }
        guard !keys.contains("discardOwned") || discardOwned(payload["discardOwned"]) else { return false }
        return true
    }

    private static func discardOwned(_ value: Any?) -> Bool {
        guard let rows = value as? [Any], !rows.isEmpty, rows.count <= 20 else { return false }
        for row in rows {
            guard let object = row as? [String: Any], Set(object.keys) == ["itemId", "quantity"],
                  let item = object["itemId"] as? String, !item.isEmpty, item.count <= 128,
                  let quantity = exactInt(object["quantity"]), quantity > 0, quantity <= 99 else { return false }
        }
        return true
    }

    private static func exactInt(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite, double.rounded() == double, double >= Double(Int.min), double <= Double(Int.max) else { return nil }
        return Int(double)
    }
}

public enum PlayTeamCommandAnswer: Equatable {
    case applied(PlayTeamCommandReceipt)
    case failed(PlayTeamCommandReceipt, reason: String)
    case businessError(requestID: String, message: String)
    case unknown(requestID: String)
    case refused
}

public struct PlayTeamCommandReceipt: Equatable {
    public let activityID: Int
    public let requestID: String
    public let action: String
    public let outcome: String
    public let receiptID: Int
    public let revision: Int
    public let reason: String?
}

/// `submitAction` in `utils/game-session-client.js`: only APPLIED plus a matching terminal receipt is success.
/// A mismatch, PENDING, or a transport failure is unknown. Unknown is never success.
public enum PlayTeamCommandInterpretation {
    public static let dash = "\u{2014}"

    public static func interpret(payload: PlayWireValue, activityID: Int, requestID: String, action: String) -> PlayTeamCommandAnswer {
        guard let receipt = terminal(payload, activityID: activityID, requestID: requestID, action: action) else {
            return .unknown(requestID: requestID)
        }
        if receipt.outcome == "APPLIED" { return .applied(receipt) }
        if receipt.outcome == "FAILED" {
            return .failed(receipt, reason: safeMessage(receipt.reason) ?? "")
        }
        return .unknown(requestID: requestID)
    }

    public static func businessMessage(_ text: String?) -> String {
        safeMessage(text) ?? ""
    }

    private static func terminal(_ payload: PlayWireValue, activityID: Int, requestID: String, action: String) -> PlayTeamCommandReceipt? {
        guard payload["activityId"].tolerantInteger == activityID,
              payload["requestId"].text == requestID,
              payload["action"].text == action,
              let receiptID = payload["receiptId"].integer, receiptID > 0,
              let revision = payload["revision"].integer, revision >= 0,
              let outcome = payload["outcome"].text, outcome == "APPLIED" || outcome == "FAILED" else { return nil }
        let reason = payload["reason"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return PlayTeamCommandReceipt(activityID: activityID, requestID: requestID, action: action, outcome: outcome,
                                       receiptID: receiptID, revision: revision, reason: reason.flatMap { $0.isEmpty ? nil : $0 })
    }

    /// Source `safeMessage`: long or technical server text is not shown.
    private static func safeMessage(_ text: String?) -> String? {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw.count <= 80 else { return nil }
        let lowered = raw.lowercased()
        if lowered.contains("/api/") || lowered.contains("exception") || lowered.contains(".java") || lowered.contains("select ") {
            return nil
        }
        return raw
    }
}

public struct PlayTeamItemCommandClient {
    let service: PlayExperienceService
    public init(service: PlayExperienceService) { self.service = service }

    public func submit(activityID: Int, action: String, contentID: String, revision: Int, authorityEpoch: Int?,
                       requestID: String, token: String) async -> PlayTeamCommandAnswer {
        guard PlayTeamItemCommandBody.actions.contains(action), activityID > 0, revision >= 0,
              PlayTeamItemCommandBody.validRequestID(requestID), !contentID.isEmpty,
              service.enabled.contains(.playerCommands), AuthRequestBuilder.isValidToken(token) else { return .refused }
        var body: [String: PlayWireValue] = [
            "activityId": .int(activityID),
            "nodeId": .null,
            "requestId": .string(requestID),
            "expectedRevision": .int(revision),
            "action": .string(action),
            "payload": .object(["contentId": .string(contentID)])
        ]
        if let authorityEpoch, (1...2_147_483_647).contains(authorityEpoch) {
            body["authorityEpoch"] = .int(authorityEpoch)
        }
        do {
            let payload = try await service.request("api/game/session/command", json: body, capability: .playerCommands, token: token)
            return PlayTeamCommandInterpretation.interpret(payload: payload, activityID: activityID, requestID: requestID, action: action)
        } catch PlayExperienceError.disabled {
            return .refused
        } catch APIError.notConfigured {
            return .refused
        } catch let PlayExperienceError.rejected(_, message) {
            return .businessError(requestID: requestID, message: PlayTeamCommandInterpretation.businessMessage(message))
        } catch {
            return .unknown(requestID: requestID)
        }
    }
}
