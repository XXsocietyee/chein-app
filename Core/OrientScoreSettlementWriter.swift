import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Thin mount hook for fix-r9 member PLY-25-2 (App lane). Cursor Core owns the final contract.
///
/// MP `subpackageMember/orient-score/index.js`:
/// - `sync()` / `settle()` → `confirmWrite` → `write`: `POST /api/orient/scoring/session/{id}/sync|settle`
///   form `{sessionId, idempotencyKey}` (:300-314). Score settle is not money (points and XP only).
/// - `recover()`: `GET /api/orient/scoring/receipt {kind, sessionId, idempotencyKey}` (:155).
/// - `resumeSync()`: the same sync POST with the saved key (:240).
/// The request id stays locked until a confirmed answer, the same rule as `OrientScoreReviewWriter`.
/// Both writes go through `OrientSessionService.write` / `.receipt` (c6 contract), which already send
/// the MP body. `/session/{id}/recovery` (请人工核对) is not sent: the MP offers it only for a pending
/// record that lost its request id (`index.wxml:28`), and this writer never stores one without an id.
@MainActor public final class OrientScoreSettlementWriter {
    public enum Kind: String, Equatable, Sendable {
        case sync = "SYNC"
        case settle = "SETTLE"
    }

    public enum Outcome: Equatable, Sendable {
        /// Matching receipt. MP notice 任务同步已确认 / 已取得本局结算结果 (or 同步结果已确认 / 结算结果已确认 after recovery).
        case confirmed(Kind)
        /// A confirmed 4xx: nothing ran. MP 没有提交成功，刷新后再试.
        case rejected
        /// No matching answer yet. The id stays locked. MP 操作结果待确认，请勿重复提交.
        case unknown
    }

    private let service: OrientSessionService
    private let token: () -> String?
    private let owner: OrientSessionRecoveryOwner
    private var score: OrientSessionScore
    public private(set) var pending: OrientSessionPending?

    public var pendingKind: Kind? {
        switch pending?.operation {
        case .sync?: return .sync
        case .settle?: return .settle
        default: return nil
        }
    }

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: @escaping () -> String?,
                ownerNamespace: String, accountID: Int, role: String, score: OrientSessionScore) throws {
        self.service = OrientSessionService(configuration: configuration, transport: transport, contract: .currentC6)
        self.token = token
        self.owner = try OrientSessionRecoveryOwner(namespace: ownerNamespace, accountID: accountID, role: role)
        self.score = score
    }

    public func note(_ score: OrientSessionScore) {
        guard score.sessionID == self.score.sessionID, score.scope == self.score.scope else { return }
        self.score = score
    }

    /// MP `allowed(kind)`: no new write while one is pending.
    public func write(_ kind: Kind) async -> Outcome {
        guard pending == nil else { return .unknown }
        guard kind == .sync ? score.canSync : score.canSettle else { return .rejected }
        let operation: OrientSessionOperation = kind == .sync ? .sync(sessionID: score.sessionID) : .settle(sessionID: score.sessionID)
        guard let made = try? OrientSessionPending(owner: owner, scope: score.scope, key: Self.makeKey(), operation: operation) else {
            return .rejected
        }
        return await transmit(made)
    }

    /// MP `resumeSync()`: the same sync POST with the saved key.
    public func resumeSync() async -> Outcome {
        guard let pending, case .sync = pending.operation else { return .unknown }
        return await transmit(pending)
    }

    /// MP `recover()`: read the receipt for the saved key.
    public func recover() async -> Outcome {
        guard let pending, let kind = pendingKind else { return .unknown }
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else { return .unknown }
        do {
            let receipt = try await service.receipt(pending, token: token)
            guard Self.matches(receipt, pending) else { return .unknown }
            self.pending = nil
            return .confirmed(kind)
        } catch {
            return .unknown
        }
    }

    private func transmit(_ made: OrientSessionPending) async -> Outcome {
        guard let kind = Self.kind(made) else { return .rejected }
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else {
            return pending == nil ? .rejected : .unknown
        }
        pending = made
        do {
            let receipt = try await service.write(made, token: token)
            guard Self.matches(receipt, made) else { return .unknown }
            pending = nil
            return .confirmed(kind)
        } catch let failure as OrientSessionFailure where Self.confirmedClientError(failure) {
            pending = nil
            return .rejected
        } catch {
            return .unknown
        }
    }

    private static func kind(_ pending: OrientSessionPending) -> Kind? {
        switch pending.operation {
        case .sync: return .sync
        case .settle: return .settle
        default: return nil
        }
    }

    private static func matches(_ receipt: OrientSessionWriteReceipt, _ pending: OrientSessionPending) -> Bool {
        switch (receipt, pending.operation) {
        case (.sync(let value), .sync(let id)):
            return value.sessionID == id && value.idempotencyKey == pending.key
        case (.settlement(let value), .settle(let id)):
            return value.sessionID == id
        default:
            return false
        }
    }

    /// Letters, digits and `-` only, inside `OrientSessionPending`'s 1...96 scored-key rule.
    private static func makeKey() -> String { "os-" + UUID().uuidString.lowercased() }

    /// HTTP 4xx, or an envelope code 4xx on an HTTP 2xx response. 5xx stays unknown.
    private static func confirmedClientError(_ failure: OrientSessionFailure) -> Bool {
        if let status = failure.httpStatus, (400..<500).contains(status) { return true }
        if failure.httpStatus == nil, let code = failure.code, (400..<500).contains(code) { return true }
        return false
    }
}
