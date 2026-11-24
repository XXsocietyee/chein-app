import Foundation

public enum PlaySessionAvailability: Equatable {
    case registrationRequired, empty, completed, unavailable, unknown, active
}
public enum PlayAnswerAvailability: Equatable {
    case text, choice, completed, locked, sessionUnavailable, arrivalRequired, unsupported, advancedRequired, branchReadOnly, missingQuestion, mediaUnavailable
    public var canAnswer: Bool { self == .text || self == .choice }
}

/// One account/epoch/scope-specific read, including the authoritative route-state read
/// for branch routes. The server determines visible nodes, completion and progression.
public struct PlaySnapshot: Equatable {
    public let scope: PlaySessionScope
    public let result: PlayNodesResult
    public let authority: PlayRouteState?
    public init(scope: PlaySessionScope, result: PlayNodesResult, authority: PlayRouteState? = nil) throws {
        guard scope.isValid else { throw APIError.invalidRequest }
        if case .topic(let id) = scope, let returnedID = result.topicID, returnedID != id { throw APIError.malformedResponse }
        if result.routeState?.isBranch == true {
            guard let authority, authority.isBranch,
                  authority.sessionID == result.routeState?.sessionID,
                  let readVersion = authority.version, let firstVersion = result.routeState?.version,
                  readVersion >= firstVersion else { throw APIError.malformedResponse }
        }
        self.scope = scope; self.result = result; self.authority = authority
    }
    public var route: PlayRouteState? { authority ?? result.routeState }
    public var visibleNodes: [PlayNode] {
        guard route?.isBranch == true else { return result.nodes.filter { $0.routeNodeState != "HIDDEN" } }
        // Missing/future branch state cannot reveal an undiscovered task.
        let visible: Set<String> = ["DISCOVERED_LOCKED", "PLAYABLE", "COMPLETED"]
        return result.nodes.filter { visible.contains(route?.nodeStates[$0.id] ?? "") }
    }
    public var availability: PlaySessionAvailability {
        if result.registered == false { return .registrationRequired }
        if result.nodes.isEmpty { return .empty }
        if (route?.isBranch != true && result.allDone) || route?.status == "COMPLETED" { return .completed }
        if result.playable == false || (route?.isBranch == true && route?.status != "ACTIVE") { return .unavailable }
        if let status = route?.status, status != "ACTIVE", status != "COMPLETED" { return .unavailable }
        if result.playable == nil || (route?.mode != nil && route?.mode != "LINEAR" && route?.mode != "BRANCH_GRAPH") { return .unknown }
        return .active
    }
    public var displayedDoneCount: Int? { route?.isBranch == true ? visibleNodes.filter(isDone).count : result.doneCount }
    public func isDone(_ node: PlayNode) -> Bool { node.done == true || route?.nodeStates[node.id] == "COMPLETED" || node.routeNodeState == "COMPLETED" }
    /// Free-exploration story lock. City mode is never story-locked. A missing `storyLocked`
    /// counts as locked only while `PlayRuntimePortRouteGate` says so (default off).
    public func isStoryLocked(_ node: PlayNode) -> Bool {
        guard result.mode == PlayGameplayMode.freeExploration.rawValue else { return false }
        if let storyLocked = node.storyLocked { return storyLocked }
        return PlayRuntimePortRouteGate.storyLockMissingIsLocked
    }
    /// Visited places stay visited. A missing `storyLocked` is not treated as visited.
    public func isVisited(_ node: PlayNode) -> Bool {
        result.mode == PlayGameplayMode.freeExploration.rawValue
            && (node.visited == true || node.storyLocked == false || isDone(node))
    }
    public func isLocked(_ node: PlayNode) -> Bool {
        if node.locked == true { return true }
        if route?.isBranch == true { return !isDone(node) && route?.nodeStates[node.id] != "PLAYABLE" }
        return node.routeNodeState != nil && node.routeNodeState != "PLAYABLE" && node.routeNodeState != "COMPLETED"
    }
    public func lockReason(_ node: PlayNode) -> String? { route?.lockReasons[node.id] ?? node.lockReason }
    public func answerAvailability(for node: PlayNode) -> PlayAnswerAvailability {
        guard visibleNodes.contains(where: { $0.id == node.id }) else { return .locked }
        if isDone(node) { return .completed }
        if isLocked(node) { return .locked }
        guard availability == .active, node.done == false else { return .sessionUnavailable }
        // Shop-day mode has a separate arrival/photo/merchant-redemption contract.
        guard result.mode == 1 else { return .unsupported }
        if node.hasAdvancedPrerequisite { return .advancedRequired }
        // No branch write until uncertain-outcome and route-token reconciliation is migrated.
        if route?.isBranch == true { return .branchReadOnly }
        if (node.needScan == true || node.needGPS == true) && node.arrived != true { return .arrivalRequired }
        guard node.validationMethod == 1 || node.validationMethod == 3 || (node.validationMethod == nil && node.needAnswer == true) else { return .unsupported }
        guard let question = node.question, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .missingQuestion }
        if node.questionImage?.isEmpty == false || node.questionAudio?.isEmpty == false { return .mediaUnavailable }
        if node.validationMethod == 3 {
            guard let options = node.options, !options.isEmpty,
                  options.allSatisfy({ !$0.key.isEmpty && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return .missingQuestion }
            return .choice
        }
        return .text
    }
    public func validateAnswer(nodeID: Int, answer: String) throws {
        guard let node = visibleNodes.first(where: { $0.id == nodeID }),
              !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.invalidRequest }
        let availability = answerAvailability(for: node)
        guard availability.canAnswer else { throw APIError.invalidRequest }
        if availability == .choice, node.options?[answer] == nil { throw APIError.invalidRequest }
    }
}

/// Story counts, the all-visited ending, and perk-only progress live beside the snapshot.
/// `FreeExplorationPresentation` is not owned by this package, so these facts are not stored on it.
public struct FreeExplorationStoryFacts: Equatable {
    public let storyUnlocked: Int?
    public let storyTotal: Int?
    public let isFullyVisited: Bool
    public let isPerkOnly: Bool
    public init(snapshot: PlaySnapshot) {
        storyUnlocked = snapshot.result.storyUnlocked
        storyTotal = snapshot.result.storyTotal
        let stores = snapshot.availability == .registrationRequired ? [] : snapshot.visibleNodes
        isFullyVisited = snapshot.result.mode == PlayGameplayMode.freeExploration.rawValue
            && snapshot.availability != .registrationRequired
            && !stores.isEmpty
            && stores.allSatisfy(snapshot.isVisited)
        isPerkOnly = snapshot.result.perkOnly == true
    }
}
