import Foundation

/// The backend returns `{code:200,msg}` for `read`: it never proves the requested cursor position.
public enum Adapt1ReadAckOutcome: Equatable {
    /// The server accepted the request; `unreadAfter` is the `unread` of the `conversations` row afterwards.
    /// This is NOT an `APPLIED` receipt (no such receipt exists server side).
    case acceptedUnverified(unreadAfter: Int)
}

extension Adapt1IMBackendAdapter {
    /// A3: `POST api/im/read` with form `read_to` (NOT `last_message_id`, which the backend ignores and then
    /// marks the whole conversation read, `ApiImController.java:142`). `request_id` is sent but ignored by the backend.
    public func readCursor(conversationID: Int, readTo: Int, requestID: String, token: String) async throws -> Adapt1ReadAckOutcome {
        guard conversationID > 0, readTo >= 0, NativeChannelNotificationCommand.validKey(requestID) else { throw APIError.invalidRequest }
        try allow(Adapt1IMPath.read, write: true)
        try allow(Adapt1IMPath.conversations, write: false)
        _ = try await post(Adapt1IMPath.read, fields: [
            "conversation_id": String(conversationID), "read_to": String(readTo), "request_id": requestID], token: token)
        guard let row = try await readbackRow(conversationID: conversationID, token: token),
              let unread = row.unread, unread >= 0 else { throw IMCapabilityGap.unknownOutcome }
        return .acceptedUnverified(unreadAfter: unread)
    }

    /// A4: the notification `.ack` command carries a JSON body the backend cannot bind. Re-send its values as form
    /// fields (`last_message_id` becomes `read_to`). Other operations (mute minutes, preferences) are not adapted.
    public func ack(_ command: NativeChannelNotificationCommand, token: String) async throws -> Adapt1ReadAckOutcome {
        try command.validate()
        guard command.operation == .ack,
              let object = try JSONSerialization.jsonObject(with: command.body) as? [String: Any],
              let channel = object["conversation_id"] as? String, let channelID = Int(channel), String(channelID) == channel,
              let last = object["last_message_id"] as? String, let readTo = Int(last), String(readTo) == last,
              object["request_id"] as? String == command.requestID else { throw APIError.invalidRequest }
        return try await readCursor(conversationID: channelID, readTo: readTo, requestID: command.requestID, token: token)
    }
}
