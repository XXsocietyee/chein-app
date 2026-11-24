import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Owner-approved orient score appeal and dispute.
/// The request id stays locked until a confirmed 2xx or 4xx. An unknown outcome,
/// including a transport failure after the request is built, keeps that id and
/// re-reads `api/orient/scoring/receipt`. This type does not call sync, settle,
/// purchase, or payout, and it does not report success without a matching record.
@MainActor public final class OrientScoreReviewWriter {
    public static let appealPath = "api/orient/scoring/appeal"
    public static let disputePath = "api/orient/scoring/dispute"
    public static let receiptPath = "api/orient/scoring/receipt"

    private let service: OrientSessionService
    private let token: () -> String?
    private let owner: OrientSessionRecoveryOwner
    private struct Saved {
        let pending: OrientSessionPending
        var built = false
    }

    private var score: OrientSessionScore
    private var saved: Saved?

    public var lockedKey: String? { saved?.pending.key }

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: @escaping () -> String?,
                ownerNamespace: String, accountID: Int, role: String, score: OrientSessionScore,
                grantedPaths: Set<String>) throws {
        guard grantedPaths.contains(Self.appealPath), grantedPaths.contains(Self.disputePath),
              grantedPaths.contains(where: { $0.hasSuffix("/sync") || $0.hasSuffix("/settle") || $0.contains("purchase") || $0.contains("payout") }) == false
        else { throw APIError.invalidConfiguration }
        self.service = OrientSessionService(configuration: configuration, transport: transport, contract: .currentC6)
        self.token = token
        self.owner = try OrientSessionRecoveryOwner(namespace: ownerNamespace, accountID: accountID, role: role)
        self.score = score
    }

    /// A later score read can open a dispute after the round ends. It does not replace a locked id.
    public func note(_ score: OrientSessionScore) {
        guard score.sessionID == self.score.sessionID, score.scope == self.score.scope else { return }
        self.score = score
    }

    public func submit(kind: OrientScoreReviewModel.Kind, reason: String, key: String, entryID: Int?, nodeID: Int? = nil) async throws {
        if let saved {
            guard saved.pending.key == key else { throw OrientScoreReviewOutcome.unknown }
            if try await confirmed(saved.pending) {
                self.saved = nil
                return
            }
            try await transmit(saved.pending)
            return
        }
        let pending = try makePending(kind: kind, reason: reason, key: key, entryID: entryID, nodeID: nodeID)
        try await transmit(pending)
    }

    private func makePending(kind: OrientScoreReviewModel.Kind, reason: String, key: String, entryID: Int?, nodeID: Int?) throws -> OrientSessionPending {
        let text = try OrientSessionScoreReason.normalized(reason)
        let operation: OrientSessionOperation
        switch kind {
        case .appeal:
            // MP submitReview: a selected ledger row wins; otherwise the 漏记任务 node id.
            let node = nodeID.flatMap { $0 > 0 ? $0 : nil }
            if let entryID, entryID > 0 {
                guard timelineEntryIDs().contains(entryID) else {
                    throw OrientScoreReviewOutcome.rejected(W8Text.t("请选择一条计分记录", "Choose a ledger entry"))
                }
                operation = .appeal(sessionID: score.sessionID, entryID: entryID, nodeID: nil, reason: text)
            } else if let node {
                operation = .appeal(sessionID: score.sessionID, entryID: nil, nodeID: node, reason: text)
            } else {
                throw OrientScoreReviewOutcome.rejected(W8Text.t("请选择一条计分记录", "Choose a ledger entry"))
            }
        case .dispute:
            guard score.status == 1 || score.status == 2 else {
                throw OrientScoreReviewOutcome.rejected(W8Text.t("对局结束后才能提交争议", "A dispute can be sent after the round ends"))
            }
            operation = .dispute(sessionID: score.sessionID, reason: text)
        }
        return try OrientSessionPending(owner: owner, scope: score.scope, key: key, operation: operation)
    }

    private func transmit(_ pending: OrientSessionPending) async throws {
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else {
            if saved?.built == true { throw OrientScoreReviewOutcome.unknown }
            saved = nil
            throw APIError.unauthorized
        }
        saved = Saved(pending: pending, built: true)
        do {
            let receipt = try await service.write(pending, token: token)
            guard case .review(let review) = receipt, review.record.matches(pending) else {
                try await finishUnknown(pending)
                return
            }
            saved = nil
        } catch let outcome as OrientScoreReviewOutcome {
            throw outcome
        } catch let failure as OrientSessionFailure where Self.confirmedClientError(failure) {
            saved = nil
            throw OrientScoreReviewOutcome.rejected(W8Text.t("服务器没有接受这次提交。", "The server did not accept this."))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try await finishUnknown(pending)
        }
    }

    /// Receipt re-read. A matching record is the only unknown-path success. Anything else stays locked.
    private func finishUnknown(_ pending: OrientSessionPending) async throws {
        if try await confirmed(pending) {
            saved = nil
            return
        }
        throw OrientScoreReviewOutcome.unknown
    }

    private func confirmed(_ pending: OrientSessionPending) async throws -> Bool {
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else { return false }
        do {
            let receipt = try await service.scoringReviewReceipt(pending, token: token)
            guard case .review(let review) = receipt else { return false }
            return review.record.matches(pending)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return false
        }
    }

    private func timelineEntryIDs() -> Set<Int> {
        var ids: Set<Int> = []
        for row in score.timeline {
            guard case .object(let fields) = row, let id = fields["entryId"]?.exactInteger, id > 0 else { continue }
            ids.insert(id)
        }
        return ids
    }

    /// HTTP 4xx, or an envelope code 4xx on an HTTP 2xx response. 5xx stays unknown.
    private static func confirmedClientError(_ failure: OrientSessionFailure) -> Bool {
        if let status = failure.httpStatus, (400..<500).contains(status) { return true }
        if failure.httpStatus == nil, let code = failure.code, (400..<500).contains(code) { return true }
        return false
    }
}
