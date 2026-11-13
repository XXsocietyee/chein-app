import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Stub-ledger row 11. The participation detail now carries the topic id, activity id,
/// and product type that were already on `/api/registration/info`. This asks the existing
/// `AppSession` orient-score provider for `current` then `score`. It does not call
/// sync, settle, appeal, or dispute.
@MainActor enum OrientScoreEntryProduction {
    static func loader(detail: ParticipationDetail, session: AppSession) -> (() async throws -> OrientSessionScore?)? {
        guard let request = ParticipationOrientScoreEntry.request(detail, accountID: session.account?.id) else { return nil }
        return session.orientScoreLoader(topicID: request.topicID, activityID: request.activityID)
    }
}
