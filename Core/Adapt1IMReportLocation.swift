import Foundation

/// The backend answers `success("举报已提交")` only. There is no report ledger or receipt lookup, so this is never
/// an "applied" proof; the caller keeps its pending/unknown state until product signs off.
public enum Adapt1ReportOutcome: Equatable {
    case submittedUnreceipted(message: String?)
}

/// Static location carried as the card form the backend accepts (type 3, `cardType:"location"`).
/// The backend rejects type 13 (`ImServiceImpl.java:992`) and drops `datum`/`source`/rounding fields.
public enum Adapt1StaticLocationCard {
    public static let contentPrefix = "[位置] "
    /// Datum is not transmitted by the card form; an App-side assumption that needs product acceptance.
    public static let assumedDatum = "WGS84"

    public static func wireFields(for place: IMStaticLocation) throws -> [String: String] {
        let place = try place.validated()
        let card: [String: Any] = ["cardType": "location", "name": place.name, "address": place.address,
                                   "lat": place.lat, "lng": place.lng]
        let data = try JSONSerialization.data(withJSONObject: card, options: [.sortedKeys])
        guard let raw = String(data: data, encoding: .utf8) else { throw APIError.invalidRequest }
        return ["msg_type": "3", "content": "[位置]", "extra_json": raw]
    }

    /// Accepts only the server-rebuilt card: type 3, `cardType == "location"`, content `"[位置] " + name`.
    public static func read(_ message: MessagingMessage) -> IMStaticLocation? {
        guard message.isPayloadVisible, message.type == 3,
              let bytes = message.extraJSON?.data(using: .utf8), bytes.count <= 4096,
              let object = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
              object["cardType"] as? String == "location",
              let name = object["name"] as? String,
              let lat = (object["lat"] as? NSNumber)?.doubleValue,
              let lng = (object["lng"] as? NSNumber)?.doubleValue,
              message.content == contentPrefix + name else { return nil }
        let address = object["address"] as? String ?? ""
        return try? IMStaticLocation(name: name, address: address, latitude: lat, longitude: lng, datum: assumedDatum)
    }
}

extension Adapt1IMBackendAdapter {
    /// A5: `POST api/im/report` form `message_id`, `reason` (label plus optional note). Replaces the JSON body
    /// `{target_type,target_id,reason_code,submit_request_id}` that binds nothing on the backend.
    public func reportMessage(messageID: Int, reasonLabel: String, note: String?, token: String) async throws -> Adapt1ReportOutcome {
        guard messageID > 0, let reason = Self.reasonText(label: reasonLabel, note: note) else { throw APIError.invalidRequest }
        try allow(Adapt1IMPath.report, write: true)
        let data = try await post(Adapt1IMPath.report, fields: ["message_id": String(messageID), "reason": reason], token: token)
        struct Header: Decodable { let msg: String? }
        return .submittedUnreceipted(message: (try? JSONDecoder().decode(Header.self, from: data))?.msg)
    }

    /// Label, then `：note`. Capped at 64 UTF-16 units (the backend's other report path caps there; the column
    /// limit for this path is UNVERIFIED), truncating only the note. Nil when the label is empty or alone too long.
    static func reasonText(label: String, note: String?) -> String? {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, label.utf16.count <= 64, !label.unicodeScalars.contains(where: { $0.value < 32 }) else { return nil }
        let note = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !note.isEmpty else { return label }
        var result = label + "："
        for character in note {
            guard result.utf16.count + String(character).utf16.count <= 64 else { break }
            if character.unicodeScalars.contains(where: { $0.value < 32 }) { continue }
            result.append(character)
        }
        return result == label + "：" ? label : result
    }

    /// A6: send the static place as a type-3 location card to `POST api/im/send`.
    /// A 200 whose body does not prove the same card is an unknown outcome (never a retry grant).
    public func sendStaticLocation(_ intent: IMOutgoingIntent, token: String) async throws -> MessagingMessage {
        guard case .staticLocation(let place) = intent.payload else { throw APIError.invalidRequest }
        try allow(Adapt1IMPath.send, write: true)
        var fields = try Adapt1StaticLocationCard.wireFields(for: place)
        fields["conversation_id"] = String(intent.scope.conversationID)
        fields["client_message_id"] = intent.clientMessageID
        let data = try await post(Adapt1IMPath.send, fields: fields, token: token)
        struct Envelope: Decodable { let data: MessagingMessage }
        struct Identity: Decodable { struct Body: Decodable { let clientMessageId: String? }; let data: Body }
        guard let message = try? JSONDecoder().decode(Envelope.self, from: data).data,
              let key = (try? JSONDecoder().decode(Identity.self, from: data))?.data.clientMessageId,
              key == intent.clientMessageID,
              message.conversationID == intent.scope.conversationID,
              message.senderID == intent.scope.identity.accountID,
              Adapt1StaticLocationCard.read(message) == place else { throw IMCapabilityGap.unknownOutcome }
        return message
    }
}
