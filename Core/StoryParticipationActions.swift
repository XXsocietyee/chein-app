import Foundation

// MARK: - Story join / node answer actions (injected writer, gated by default)
// The writer is the ONLY place a join or answer could leave the device. The default writer reports
// `.unavailable`, so the UI shows "Not available yet" and never a success state. A real transport can be
// injected later without touching the view or this model.

public enum StoryParticipationWriteOutcome: Equatable {
    case accepted(message: String)
    case rejected(message: String)
    case unavailable
}

public struct StoryJoinRequest: Equatable {
    public let topicId: Int
    public let stationId: Int?
    public let role: StoryParticipantRole

    public init(topicId: Int, stationId: Int?, role: StoryParticipantRole) {
        self.topicId = topicId
        self.stationId = stationId
        self.role = role
    }
}

public struct StoryAnswerRequest: Equatable {
    public let endpoint: String
    public let payload: [String: PlayWireValue]

    public init(endpoint: String, payload: [String: PlayWireValue]) {
        self.endpoint = endpoint
        self.payload = payload
    }
}

@MainActor public protocol StoryParticipationWriting {
    func join(_ request: StoryJoinRequest) async -> StoryParticipationWriteOutcome
    func submitAnswer(_ request: StoryAnswerRequest) async -> StoryParticipationWriteOutcome
}

/// Production default: no approved write route/grant, so nothing is ever sent.
public struct GatedStoryParticipationWriter: StoryParticipationWriting {
    public init() {}
    public func join(_ request: StoryJoinRequest) async -> StoryParticipationWriteOutcome { .unavailable }
    public func submitAnswer(_ request: StoryAnswerRequest) async -> StoryParticipationWriteOutcome { .unavailable }
}

public enum StoryActionState: Equatable {
    case idle
    case submitting
    case accepted(String)
    case rejected(String)
    case unavailable
    case invalid(String)
}

@available(macOS 14.0, *)
@MainActor public final class StoryParticipationActionModel: ObservableObject {
    @Published public private(set) var joinState: StoryActionState = .idle
    @Published public private(set) var answerStates: [Int: StoryActionState] = [:]
    private let writer: StoryParticipationWriting

    public init(writer: StoryParticipationWriting) { self.writer = writer }

    public func join(coordinator: StoryParticipationCoordinator) async {
        guard joinState != .submitting else { return }
        let state = coordinator.joinState
        guard state.canSubmitJoin else {
            joinState = .invalid(W8Text.t("当前状态无需再次申请", "No further application is needed right now"))
            return
        }
        joinState = .submitting
        let request = StoryJoinRequest(topicId: state.topicId, stationId: state.currentStation?.stationId, role: state.role)
        let outcome = await writer.join(request)
        switch outcome {
        case .accepted(let message):
            // Only a server-accepted join changes local state.
            coordinator.joinState = StoryProjectJoinState(
                topicId: state.topicId, role: state.role,
                myJoined: state.isMerchant ? state.myJoined : true,
                myApplyState: state.isMerchant ? 1 : state.myApplyState,
                stations: state.stations, selectedStationIndex: state.selectedStationIndex)
            joinState = .accepted(message)
        case .rejected(let message): joinState = .rejected(message)
        case .unavailable: joinState = .unavailable
        }
    }

    public func submitAnswer(nodeId: Int, coordinator: StoryParticipationCoordinator) async {
        if answerStates[nodeId] == .submitting { return }
        let built: (endpoint: String, payload: [String: PlayWireValue])
        do { built = try coordinator.buildAnswerRequest(nodeId: nodeId) }
        catch {
            answerStates[nodeId] = .invalid(error.localizedDescription)
            return
        }
        answerStates[nodeId] = .submitting
        let outcome = await writer.submitAnswer(StoryAnswerRequest(endpoint: built.endpoint, payload: built.payload))
        switch outcome {
        case .accepted(let message):
            coordinator.markNodeAnswered(nodeId: nodeId, answer: coordinator.draftAnswers[nodeId] ?? "")
            answerStates[nodeId] = .accepted(message)
        case .rejected(let message): answerStates[nodeId] = .rejected(message)
        case .unavailable: answerStates[nodeId] = .unavailable
        }
    }
}
