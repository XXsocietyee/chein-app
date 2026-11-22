import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Stub-ledger row 11. The participation detail now carries the topic id, activity id,
/// and product type that were already on `/api/registration/info`. This asks the existing
/// `AppSession` orient-score provider for `current` then `score`. It does not call
/// sync, settle, appeal, or dispute.
@MainActor enum OrientScoreEntryProduction {
    /// Several current rounds come back as a choice, never as an empty page (PLY-25-1).
    static func loader(detail: ParticipationDetail, session: AppSession) -> ((Int?) async throws -> OrientScoreLoad)? {
        guard let request = ParticipationOrientScoreEntry.request(detail, accountID: session.account?.id) else { return nil }
        return session.orientScoreRoundsLoader(topicID: request.topicID, activityID: request.activityID)
    }
}
