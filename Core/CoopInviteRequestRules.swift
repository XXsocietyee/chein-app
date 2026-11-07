import Foundation

/// Pure rules of mini-program `utils/coop-invite-request.js` and `parseInviteId` from `utils/coop-invite-view.js`:
/// exact invite ids, the per-target write key, receipt validation, write-result classification and
/// readback pagination. No I/O; the idempotent request/readback loop itself stays with the caller.
public enum CoopInviteRequestRules {
    // MARK: ids

    /// Source `parseInviteId` (number): a positive JS-safe integer.
    public static func parseInviteID(_ value: Int) -> String? {
        value > 0 && value <= 9_007_199_254_740_991 ? String(value) : nil
    }

    /// Source `parseInviteId` (string): ASCII digits only, leading zeros dropped, 1...Int64.max.
    public static func parseInviteID(_ value: String) -> String? {
        guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        let digits = String(value.drop(while: { $0 == "0" }))
        let max = "9223372036854775807"
        guard !digits.isEmpty, digits.count < max.count || (digits.count == max.count && digits <= max) else { return nil }
        return digits
    }

    /// Source `exactId`: the string is already in canonical form.
    public static func isExactID(_ value: String) -> Bool { parseInviteID(value) == value }

    /// Source `validRequestId`: `^[A-Za-z0-9_-]{1,64}$`.
    public static func isValidRequestID(_ value: String) -> Bool {
        (1...64).contains(value.utf8.count) && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }

    // MARK: context and write key

    /// Source `context(payload)`. `supplyStationID == nil` means the key is absent; `""` means present but not an exact id.
    public struct Context: Equatable {
        public let inviteType: Int?
        public let topicID: String
        public let toType: String?
        public let toID: String
        public let scope: String
        public let supplyStationID: String?
    }

    public static func context(inviteType: Int?, topicID: String, toType: String?, toID: String,
                               scope: String?, supplyStationID: String?) -> Context {
        Context(inviteType: inviteType, topicID: parseInviteID(topicID) ?? "", toType: toType, toID: parseInviteID(toID) ?? "",
                scope: inviteType == 0 && scope == "MERCHANT" ? "MERCHANT" : "",
                supplyStationID: supplyStationID.map { parseInviteID($0) ?? "" })
    }

    /// Source `writeKey`: `owner:coop-invite:` + JSON array `[inviteType, scope, topicId, toId(, supplyStationId)]`.
    /// Same target -> same key, so a retry replays the original request instead of creating a second invite.
    public static func writeKey(owner: String, context c: Context) -> String {
        func quoted(_ s: String) -> String {
            // Only canonical digit strings and "MERCHANT"/"" occur; escape defensively anyway.
            var out = "\""
            for scalar in s.unicodeScalars {
                switch scalar {
                case "\"": out += "\\\""
                case "\\": out += "\\\\"
                default: out.unicodeScalars.append(scalar)
                }
            }
            return out + "\""
        }
        var fields = [c.inviteType.map(String.init) ?? "null", quoted(c.scope), quoted(c.topicID), quoted(c.toID)]
        if let station = c.supplyStationID { fields.append(quoted(station)) }
        return owner + ":coop-invite:[" + fields.joined(separator: ",") + "]"
    }

    // MARK: receipt

    public struct Receipt: Equatable {
        public enum State: String, Equatable { case created = "CREATED", notFound = "NOT_FOUND", unavailable = "UNAVAILABLE" }
        public let state: State
        public let requestID: String
        public let inviteID: String?
        public let inviteType: Int?
        public let topicID: String?
        public let toType: String?
        public let toID: String?
        public let scope: String?
        public let supplyStationID: String?
    }

    /// Source `receipt(value)`; `nil` means the receipt cannot be trusted. `raw` is a decoded JSON object.
    public static func receipt(_ raw: [String: Any]?) -> Receipt? {
        guard let raw, let requestID = raw["requestId"] as? String, isValidRequestID(requestID),
              let stateText = raw["state"] as? String, let state = Receipt.State(rawValue: stateText) else { return nil }
        if state != .created {
            guard Set(raw.keys).isSubset(of: ["state", "requestId"]) else { return nil }
            return Receipt(state: state, requestID: requestID, inviteID: nil, inviteType: nil, topicID: nil, toType: nil,
                           toID: nil, scope: nil, supplyStationID: nil)
        }
        guard let inviteID = raw["inviteId"] as? String, isExactID(inviteID),
              let topicID = raw["topicId"] as? String, isExactID(topicID),
              let toID = raw["toId"] as? String, isExactID(toID),
              let type = integer(raw["inviteType"]), type == 0 || type == 1,
              let toType = raw["toType"] as? String, toType == (type == 1 ? "club" : "merchant"),
              let scope = raw["scope"] as? String, scope == "" || scope == "MERCHANT", !(type == 1 && scope != "") else { return nil }
        var station: String?
        if let value = raw["supplyStationId"], !(value is NSNull) {
            guard let text = value as? String, isExactID(text), type == 0 else { return nil }
            station = text
        }
        return Receipt(state: .created, requestID: requestID, inviteID: inviteID, inviteType: type, topicID: topicID,
                       toType: toType, toID: toID, scope: scope, supplyStationID: station)
    }

    /// Source `matches(row, payload)`: a CREATED receipt that agrees with every axis of the context.
    /// A receipt station is only compared when the context carries one (source `Object.keys(c).every`).
    public static func matches(_ receipt: Receipt?, context c: Context) -> Bool {
        guard let r = receipt, r.state == .created, r.inviteType == c.inviteType, r.topicID == c.topicID,
              r.toType == c.toType, r.toID == c.toID, r.scope == c.scope else { return false }
        if let station = c.supplyStationID { return r.supplyStationID == station }
        return true
    }

    // MARK: classification

    /// Source `responseCode`: an integer 100...599 or a three-digit `[1-5]xx` string; anything else is 0.
    public static func responseCode(_ value: Any?) -> Int {
        if let number = integer(value), (100...599).contains(number) { return number }
        if let text = value as? String, text.utf8.count == 3, text.utf8.allSatisfy({ (48...57).contains($0) }),
           let first = text.utf8.first, (49...53).contains(first), let number = Int(text) { return number }
        return 0
    }

    public enum WriteStatus: Equatable { case success, failed, unknown }

    /// Source `classify(res, httpStatus, requestId)`. Only a 200 CREATED receipt for *this* request id with a
    /// boolean `replayed` is success; 4xx (except 408 and 409) is a definite rejection; everything else,
    /// including 409, bad status, session change and lost responses, stays unknown and must be read back.
    public static func classify(response: [String: Any]?, httpStatus: Int?, requestID: String) -> WriteStatus {
        let status = httpStatus.map { responseCode($0) } ?? 0
        let code = responseCode(response?["code"])
        if httpStatus != nil && status == 0 { return .unknown }
        guard let response, (response["reason"] as? String) != "sessionChanged", status != 409, code != 409 else { return .unknown }
        if status != 0 && status != 200 { return status >= 400 && status < 500 && status != 408 ? .failed : .unknown }
        if code == 200, let data = response["data"] as? [String: Any], let created = receipt(data), created.state == .created,
           created.requestID == requestID, isBool(data["replayed"]) { return .success }
        let message = response["msg"] as? String ?? ""
        if (code >= 400 && code < 500 && code != 408) || (code == 500 && message.hasPrefix(writeClosedPrefix)) { return .failed }
        return .unknown
    }

    /// Server message prefix meaning the merchant-recruitment write switch is off (a definite refusal).
    public static let writeClosedPrefix = "招商写入已关闭"

    // MARK: readback paging

    /// Source `createReadback` page checks: `hasMore` must be present, `nextCursor` must be an exact id exactly
    /// when there is more, and while paging back the cursor must strictly decrease (numerically).
    public static func readbackPageIsValid(hasMore: Bool?, nextCursor: String?, previousCursor: String?) -> Bool {
        guard let hasMore else { return false }
        if let next = nextCursor, !isExactID(next) { return false }
        if hasMore && nextCursor == nil { return false }
        if !hasMore && nextCursor != nil { return false }
        if let before = previousCursor, let next = nextCursor,
           next.count > before.count || (next.count == before.count && next >= before) { return false }
        return true
    }

    // MARK: helpers

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let int = number.intValue
        return Double(int) == number.doubleValue ? int : nil
    }
    private static func isBool(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
