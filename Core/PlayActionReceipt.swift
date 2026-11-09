import Foundation

/// Outcome of the original play write. Pending is not a rejection and not a new success.
public enum PlayActionReceiptOutcome: Equatable {
    case pending
    case confirmed(PlayWireValue)
}

/// A retry may reuse only the id stored with the original write.
public enum PlayActionReceiptIdentity {
    public static func retained(original: String, proposed: String) -> String? {
        let original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let proposed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty, original.utf8.count <= 96, original == proposed,
              original.utf8.allSatisfy({ $0 >= 0x21 && $0 <= 0x7e }) else { return nil }
        return original
    }
}

/// Production read: GET api/play/action-receipt. Code 520 means the original result is still unknown.
public enum PlayActionReceipt {
    public static func decode(_ data: Data, status: Int, routeActionID: String) throws -> PlayActionReceiptOutcome {
        guard PlayActionReceiptIdentity.retained(original: routeActionID, proposed: routeActionID) != nil else {
            throw APIError.invalidRequest
        }
        guard (200..<300).contains(status), data.count <= 512 * 1024,
              let envelope = try? JSONDecoder().decode(PlayWireValue.self, from: data),
              let code = envelope["code"].tolerantInteger else {
            throw PlayExperienceError.unknownResult
        }
        if code == 401 { throw PlayExperienceError.unauthorized }
        if code == 520 { return .pending }
        guard code == 200 else { throw PlayExperienceError.unknownResult }
        let payload = envelope["data"]
        if let echoed = payload["routeActionId"].text ?? payload["actionId"].text,
           PlayActionReceiptIdentity.retained(original: routeActionID, proposed: echoed) == nil {
            throw PlayExperienceError.malformed
        }
        return .confirmed(payload)
    }
}
