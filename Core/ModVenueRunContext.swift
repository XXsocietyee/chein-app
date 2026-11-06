import Foundation

/// Read-only original Run context. It is not evidence, a GPS claim, or permission to complete.
public struct ModVenueRunContext: Codable, Equatable {
    public let schema, runtimeDomain, run, consentVersion, ruleVersion, purpose: String
    public let sessionId, topicId, nodeId, expectedVersion, expectedEpoch, consentId: Int
    init?(raw: PlayWireValue) {
        guard raw["schema"].text == "original-mod-venue-context-v1", let domain = raw["runtimeDomain"].text,
              ["TOPIC_ROUTE", "GAME_SESSION"].contains(domain), let run = raw["run"].text, !run.isEmpty, run.utf8.count <= 160,
              let session = raw["sessionId"].integer, session > 0, let topic = raw["topicId"].integer, topic > 0,
              let node = raw["nodeId"].integer, node > 0, let version = raw["expectedVersion"].integer, version >= 0,
              let epoch = raw["expectedEpoch"].integer, epoch > 0, let consent = raw["consentId"].integer, consent > 0,
              let consentVersion = raw["consentVersion"].text, QmodSourceSubmissionWire.hashValid(consentVersion),
              let rule = raw["ruleVersion"].text, QmodSourceSubmissionWire.hashValid(rule), raw["purpose"].text == "VENUE_CHECK" else { return nil }
        schema = "original-mod-venue-context-v1"; runtimeDomain = domain; self.run = run; self.consentVersion = consentVersion; ruleVersion = rule; purpose = "VENUE_CHECK"
        sessionId = session; topicId = topic; nodeId = node; expectedVersion = version; expectedEpoch = epoch; consentId = consent
    }
    func fields(node: Int, advance: PlayRouteAdvance?) throws -> [String: String] {
        guard node == nodeId, let advance, UUID(uuidString: advance.actionID) != nil, advance.expectedVersion == expectedVersion else { throw PlayExperienceError.invalidAction }
        return ["venueDomain": runtimeDomain, "venueSessionId": String(sessionId), "venueRun": run,
                "venueNodeId": String(nodeId), "venueEpoch": String(expectedEpoch)]
    }
    func accepts(_ receipt: PlayWireValue, request: String) -> Bool {
        guard receipt["requestId"].text == request else { return false }
        let status = receipt["status"].text
        if status == "REVOKED_OR_UNAVAILABLE" { return receipt["accepted"].bool == true }
        if status == "REJECTED" { return receipt["accepted"].bool == false && receipt["nodeId"].integer == nodeId }
        let p = receipt["evidence"]
        return status == "COMMITTED" && receipt["accepted"].bool == true && receipt["nodeId"].integer == nodeId
            && p["schema"].text == "original-mod-venue-evidence-v1" && p["runtimeDomain"].text == runtimeDomain
            && p["requestId"].text == request && p["sessionId"].integer == sessionId && p["run"].text == run
            && p["topicId"].integer == topicId && p["nodeId"].integer == nodeId && p["authorityEpoch"].integer == expectedEpoch
            && p["consentId"].integer == consentId && p["consentVersion"].text == consentVersion && p["ruleVersion"].text == ruleVersion && p["purpose"].text == purpose
    }
}
