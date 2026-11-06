import Foundation

/// Explicit original POI selections in the same source command and pending journal. No consent or evidence verdict.
enum ModCompositionVenueSelection {
    static let adapter = "first-party-venue-standard-topic-4"
    static func slots(_ source: QmodSourceSubmissionSource) throws -> [String] {
        let entries = try source.exactBytes()
        guard let bytes = entries["content.json"], let raw = try QmodSourceSubmissionWire.object(bytes)["venueSlots"] as? [[String: Any]], raw.count <= 32 else { throw QmodSourceSubmissionIssue.invalidPackage }
        var result = [String]()
        for slot in raw {
            try QmodSourceSubmissionWire.keys(slot, ["id"])
            guard let id = slot["id"] as? String, id.range(of: #"\A[a-z][a-z0-9_-]{0,47}\z"#, options: .regularExpression) != nil else { throw QmodSourceSubmissionIssue.invalidPackage }
            result.append(id)
        }
        guard Set(result).count == result.count else { throw QmodSourceSubmissionIssue.invalidPackage }
        return result.sorted()
    }
    static func bindings(_ choices: [String: ModInstallationResource]) -> [ModInstallationBinding] {
        choices.keys.sorted().compactMap { key in choices[key].map { .init(key: key, kind: .poi, resourceId: $0.id, fingerprint: $0.fingerprint) } }
    }
    /// Read the retained original values only. Reopening after resource/revocation changes must not reconstruct a new body.
    static func validate(_ values: [ModInstallationBinding]?, slots: [String]) throws {
        guard let values else { guard slots.isEmpty else { throw QmodSourceSubmissionIssue.storage }; return }
        guard values.count <= 32, values.map(\.key) == slots, Set(values.map(\.key)).count == values.count,
              values.allSatisfy({ $0.kind == .poi && $0.resourceId > 0 && QmodSourceSubmissionWire.hashValid($0.fingerprint) }) else { throw QmodSourceSubmissionIssue.storage }
    }
}
