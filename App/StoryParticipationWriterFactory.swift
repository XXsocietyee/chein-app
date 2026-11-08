import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Single seam for the story join / answer writer. Production returns the gated writer (nothing is sent,
/// UI says "Not available yet"). Composition can later replace `makeWriter` with a transport-backed
/// writer once a write route and grant are approved; no view code changes.
@MainActor enum StoryParticipationWriterFactory {
    static var makeWriter: () -> StoryParticipationWriting = { GatedStoryParticipationWriter() }
}

enum StoryParticipationFeedbackMapping {
    /// Maps action-model state to the per-node feedback the view renders. Accepted/idle/submitting show
    /// no banner (an accepted node displays its own "answered" mark).
    static func answerFeedback(_ states: [Int: StoryActionState]) -> [Int: StoryAnswerFeedback] {
        var result: [Int: StoryAnswerFeedback] = [:]
        for (nodeID, state) in states {
            switch state {
            case .unavailable: result[nodeID] = .blocked
            case .invalid(let message), .rejected(let message): result[nodeID] = .invalid(message)
            case .idle, .submitting, .accepted: break
            }
        }
        return result
    }

    static func joinMessage(_ state: StoryActionState) -> String? {
        switch state {
        case .invalid(let message), .rejected(let message): return message
        default: return nil
        }
    }
}
