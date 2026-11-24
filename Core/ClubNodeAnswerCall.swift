import Foundation

/// Which answer read a story node uses.
/// Club entry: `POST api/club/topic-node-answer` `{clubId, topicId, nodeId}`.
/// Merchant entry with no club id: `POST api/topic/host-node-answer` `{topicId, nodeId, scope}`.
public struct ClubNodeAnswerCall: Equatable, Sendable {
    public let path: String
    public let topicID: Int
    public let nodeID: Int
    public let clubID: Int?
    public let scope: String?

    public var fields: [String: ClubGovernanceValue] {
        var body: [String: ClubGovernanceValue] = ["topicId": .integer(topicID), "nodeId": .integer(nodeID)]
        if let clubID { body["clubId"] = .integer(clubID) }
        if let scope { body["scope"] = .string(scope) }
        return body
    }

    public init?(clubID: Int?, topicID: Int, nodeID: Int, scope: String?) {
        guard topicID > 0, nodeID > 0 else { return nil }
        let trimmed = scope?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hostScope = (trimmed?.isEmpty == false) ? trimmed : nil
        if let clubID {
            guard clubID > 0 else { return nil }
            self.path = "api/club/topic-node-answer"
            self.clubID = clubID
            self.scope = nil
        } else if let hostScope {
            self.path = "api/topic/host-node-answer"
            self.clubID = nil
            self.scope = hostScope
        } else { return nil }
        self.topicID = topicID
        self.nodeID = nodeID
    }
}
