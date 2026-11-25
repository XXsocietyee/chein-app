import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Stub-ledger row 27. Builds the orient score appeal / dispute submitter from the
/// reports grant. Nil when that grant is absent, so the form stays hidden.
/// Sync, settle, purchase, and payout are not called.
@MainActor enum OrientScoreReviewProduction {
    private static var writers: [String: OrientScoreReviewWriter] = [:]

    static func make(_ context: OrientScoreReviewContext) -> (submitter: OrientScoreReviewModel.Submitter, makeKey: () -> String)? {
        guard let runtime = context.session.currentRuntimeDependencyContext,
              runtime.market == .china,
              runtime.role == "player" || runtime.role == "club",
              let grant = context.session.composition.playerWriteGrant(runtime),
              grant.reports.paths.contains(OrientScoreReviewLease.appeal),
              grant.reports.paths.contains(OrientScoreReviewLease.dispute),
              let api = context.session.regionalConfiguration?.apiConfiguration,
              let writer = open(session: context.session, score: context.score, runtime: runtime, api: api, paths: grant.reports.paths)
        else { return nil }
        let entryID = context.entryID
        let nodeID = context.nodeID
        let submitter: OrientScoreReviewModel.Submitter = { kind, reason, key in
            try await writer.submit(kind: kind, reason: reason, key: key, entryID: entryID(), nodeID: nodeID())
        }
        return (submitter, { writer.lockedKey ?? UUID().uuidString })
    }

    private static func open(session: AppSession, score: OrientSessionScore, runtime: RuntimeDependencyContext,
                             api: APIConfiguration, paths: Set<String>) -> OrientScoreReviewWriter? {
        let key = "\(runtime.session.accountID)|\(runtime.session.epoch)|\(runtime.session.namespace)|\(score.sessionID)|\(score.scope.topicID)|\(score.scope.activityID)"
        if let existing = writers[key] {
            existing.note(score)
            return existing
        }
        guard let created = try? OrientScoreReviewWriter(
            configuration: api, transport: session.runtimeHTTPTransport,
            token: { [weak session] in session?.token },
            ownerNamespace: runtime.session.namespace, accountID: runtime.session.accountID,
            role: runtime.role, score: score, grantedPaths: paths) else { return nil }
        writers[key] = created
        return created
    }
}

/// Passed into `OrientScoreReviewFactory.makeSubmitter`. The entry id is read at send time.
@MainActor struct OrientScoreReviewContext {
    let session: AppSession
    let score: OrientSessionScore
    let entryID: () -> Int?
    /// PLY-25-5: MP 申诉漏记任务 node id, read at send time. Used only when no ledger row is chosen.
    var nodeID: () -> Int? = { nil }
}
