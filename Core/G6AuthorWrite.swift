import Foundation

/// Port of `utils/author-write-recovery.js`. One saved intent per (owner, bucket). The first try sends the write;
/// only an explicit retry reads `/api/author-write/receipt` first and replays the saved body when the receipt says UNKNOWN.
public enum G6AuthorWrite {
    public static func isOperation(_ value: String) -> Bool {
        guard (1...64).contains(value.utf8.count), let first = value.unicodeScalars.first, (65...90).contains(first.value) else { return false }
        return value.unicodeScalars.allSatisfy { (65...90).contains($0.value) || (48...57).contains($0.value) || $0 == "_" }
    }

    public struct Intent: Codable, Equatable, Sendable {
        public let owner: String
        public let bucket: String
        public let requestId: String
        public let operation: String
        public let endpoint: String
        public let bodyJSON: String
    }

    /// What the receipt read decided for a saved intent.
    public enum ReceiptDecision: Equatable, Sendable {
        /// The original write already landed; settle with the stored response JSON.
        case found(responseJSON: Data?)
        /// The server has no record: replay the saved body with the same request id.
        case replay
        /// Anything else: keep the intent, say the result is not confirmed.
        case unknown
    }

    public static func key(owner: String, bucket: String) -> String {
        "author_write_v1:" + (owner.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? owner) + ":"
            + (bucket.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? bucket)
    }

    public static func pending(_ store: any JourneyRequestStoring, owner: String, bucket: String) -> Intent? {
        guard let text = store.read(key(owner: owner, bucket: bucket)), !text.isEmpty,
              let intent = try? JSONDecoder().decode(Intent.self, from: Data(text.utf8)),
              intent.owner == owner, intent.bucket == bucket, !intent.requestId.isEmpty else { return nil }
        return intent
    }

    /// Saves a new intent with `aw-` request id merged into the body. Returns nil when it could not be saved and read back.
    public static func begin(_ store: any JourneyRequestStoring, owner: String, bucket: String, operation: String, endpoint: String,
                             body: [String: Any], requestID: String) -> Intent? {
        guard !owner.isEmpty, isOperation(operation), requestID.hasPrefix("aw-") else { return nil }
        var fields = body
        fields["requestId"] = requestID
        guard JSONSerialization.isValidJSONObject(fields),
              let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else { return nil }
        let intent = Intent(owner: owner, bucket: bucket, requestId: requestID, operation: operation, endpoint: endpoint,
                            bodyJSON: String(decoding: data, as: UTF8.self))
        guard let encoded = try? JSONEncoder().encode(intent) else { return nil }
        store.write(key(owner: owner, bucket: bucket), String(decoding: encoded, as: UTF8.self))
        return pending(store, owner: owner, bucket: bucket) == intent ? intent : nil
    }

    public static func clear(_ store: any JourneyRequestStoring, intent: Intent) -> Bool {
        guard pending(store, owner: intent.owner, bucket: intent.bucket)?.requestId == intent.requestId else { return false }
        store.remove(key(owner: intent.owner, bucket: intent.bucket))
        return pending(store, owner: intent.owner, bucket: intent.bucket) == nil
    }

    /// The receipt must name the same operation and request id. FOUND settles, UNKNOWN replays, anything else stays unknown.
    public static func decide(_ envelope: G6Envelope, intent: Intent) -> ReceiptDecision {
        guard envelope.ok, let receipt = envelope.data as? [String: Any],
              receipt["operation"] as? String == intent.operation,
              receipt["requestId"] as? String == intent.requestId else { return .unknown }
        switch receipt["state"] as? String {
        case "FOUND": return .found(responseJSON: G6JSON.data(receipt["response"]))
        case "UNKNOWN": return .replay
        default: return .unknown
        }
    }

    /// A write answer for the saved intent: HTTP 400/401/403/404/405/410/422 and a matching REJECTED marker are definite.
    public enum Settlement: Equatable, Sendable { case succeeded, rejected, unknown }

    public static func settle(status: Int?, object: [String: Any]?, intent: Intent, valid: ([String: Any]?) -> Bool) -> Settlement {
        if let status, [400, 401, 403, 404, 405, 410, 422].contains(status) { return .rejected }
        guard let object else { return .unknown }
        if G6JSON.integer(object["code"]) == 200 || (object["code"] as? String) == "200", valid(object["data"] as? [String: Any]) {
            return .succeeded
        }
        if let marker = object["writeReceipt"] as? [String: Any], marker["state"] as? String == "REJECTED",
           marker["requestId"] as? String == intent.requestId, marker["operation"] as? String == intent.operation {
            return .rejected
        }
        return .unknown
    }
}
