import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// fix/1128c-ai-weather (inventory A2 / B2). `GET api/play/environment?topicId=` (`ApiPlayEnvironmentController`,
/// signed-in): the topic city's environment snapshot and the `weather_event_rule` events evaluated against it.
/// The node list already carries `weatherLocked` / `lockReason` (B1); this read adds the event list and the weather
/// that the scene and the AI guide show, so neither contradicts the server's gate.
public struct PlayEnvironmentService {
    public static let path = "api/play/environment"

    public enum SourceStatus: String, Sendable { case available = "AVAILABLE", fallbackUnknown = "FALLBACK_UNKNOWN", disabled = "DISABLED" }

    public struct Event: Equatable, Identifiable, Sendable {
        public let id: Int
        public let ruleName: String
        /// weather / daypart / weekpart / season
        public let conditionKey: String
        public let conditionValues: [String]
        public let unlockNodeID: Int?
        /// The easter-egg hint the author wrote (`taskLabel`), shown only while the event is active.
        public let taskLabel: String?
        public let active: Bool
        /// Server wording: why it is (not) active. Shown as-is.
        public let reason: String?
        public let lockReason: String?
        public let windowStart: String?
        public let windowEnd: String?
    }

    public struct Snapshot: Equatable, Sendable {
        public let topicID: Int
        public let city: String?
        public let enabled: Bool
        public let keys: [String]
        /// `environment`: weather / daypart / weekpart / season → server value (`unknown` when the source failed).
        public let environment: [String: String]
        public let sourceStatus: SourceStatus
        public let fallbackReason: String?
        public let events: [Event]

        public var weather: String? { environment["weather"].flatMap { $0 == "unknown" ? nil : $0 } }
        public var daypart: String? { environment["daypart"].flatMap { $0 == "unknown" ? nil : $0 } }
        /// Active events first, then by server order.
        public var orderedEvents: [Event] { events.filter(\.active) + events.filter { !$0.active } }
    }

    let client: PlayerCapabilityClient
    public init(client: PlayerCapabilityClient) { self.client = client }

    /// Nil on any failure (signed out, ENV_* rejection, malformed): the play screen simply shows no weather section.
    public func snapshot(topicID: Int) async -> Snapshot? {
        guard topicID > 0, let request = try? client.getRequest(Self.path, query: [("topicId", String(topicID))]),
              let raw = try? await client.read(request) else { return nil }
        return Self.snapshot(raw, topicID: topicID)
    }

    public static func snapshot(_ raw: SquareGovernanceJSON, topicID: Int) -> Snapshot? {
        guard case .object = raw else { return nil }
        let returned = PlayerCapabilityClient.positiveID(raw["topicId"])
        if let returned, returned != topicID { return nil }
        var environment: [String: String] = [:]
        if case .object(let values) = raw["environment"] {
            for (key, value) in values {
                if let text = value.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { environment[key] = text }
            }
        }
        let events: [Event] = (raw["events"].array ?? []).compactMap { row in
            guard let id = PlayerCapabilityClient.positiveID(row["id"]) else { return nil }
            return Event(id: id,
                         ruleName: row["ruleName"].string ?? "",
                         conditionKey: row["conditionKey"].string ?? "",
                         conditionValues: (row["conditionValues"].array ?? []).compactMap(\.string),
                         unlockNodeID: PlayerCapabilityClient.positiveID(row["unlockNodeId"]),
                         taskLabel: nonEmpty(row["taskLabel"].string),
                         active: row["active"].bool ?? false,
                         reason: nonEmpty(row["reason"].string),
                         lockReason: nonEmpty(row["lockReason"].string),
                         windowStart: nonEmpty(row["windowStart"].string),
                         windowEnd: nonEmpty(row["windowEnd"].string))
        }
        return Snapshot(topicID: topicID,
                        city: nonEmpty(raw["city"].string),
                        enabled: raw["enabled"].bool ?? false,
                        keys: (raw["keys"].array ?? []).compactMap(\.string),
                        environment: environment,
                        sourceStatus: SourceStatus(rawValue: raw["sourceStatus"].string ?? "") ?? .disabled,
                        fallbackReason: nonEmpty(raw["fallbackReason"].string),
                        events: events)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
