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
/// the MP body. A journal row with no usable request id is the MP pending that shows 请人工核对:
/// `POST /api/orient/scoring/session/{id}/recovery` with form `{kind}` only (`requestManualReview`).
/// That post is not a payment, refund, payout, or withdrawal.
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
        /// The pending row could not be saved, so nothing was sent. MP 待办未能保存，本次未提交.
        case notStored
    }

    private let service: OrientSessionService
    private let token: () -> String?
    private let owner: OrientSessionRecoveryOwner
    private let journal: (any OrientScoreSettlementJournal)?
    private var score: OrientSessionScore
    public private(set) var pending: OrientSessionPending?
    /// Set when the saved row has a kind but no usable request id. The page shows 请人工核对 and does not replay.
    public private(set) var unkeyedKind: Kind?
    /// The journal could not be read. MP shows 原操作 and does not offer 请人工核对.
    public private(set) var journalUnreadable = false

    public var pendingKind: Kind? {
        if let pending { return Self.kind(pending) }
        return unkeyedKind
    }

    public var needsManualReview: Bool { unkeyedKind != nil && pending == nil && !journalUnreadable }

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: @escaping () -> String?,
                ownerNamespace: String, accountID: Int, role: String, score: OrientSessionScore,
                journal: (any OrientScoreSettlementJournal)? = nil) throws {
        self.service = OrientSessionService(configuration: configuration, transport: transport, contract: .currentC6)
        self.token = token
        self.owner = try OrientSessionRecoveryOwner(namespace: ownerNamespace, accountID: accountID, role: role)
        self.score = score
        self.journal = journal
        if let journal {
            do {
                if let slot = try journal.load() { adopt(slot) }
            } catch {
                journalUnreadable = true
            }
        }
    }

    public func note(_ score: OrientSessionScore) {
        guard score.sessionID == self.score.sessionID, score.scope == self.score.scope else { return }
        self.score = score
    }

    /// MP `allowed(kind)`: no new write while one is pending.
    public func write(_ kind: Kind) async -> Outcome {
        // MP `allowed`: a pending row, including one with no request id, blocks a new write.
        // An unreadable journal also blocks, so a damaged key is never replaced and replayed.
        guard pending == nil, unkeyedKind == nil, !journalUnreadable else { return .unknown }
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

    /// MP `requestManualReview`: only a pending row with no request id. Body is `{kind}`.
    /// A matching row stays pending, the same as the mini program, which does not drop that local record.
    public func requestManualReview() async -> Outcome {
        guard let unkeyedKind, pending == nil, !journalUnreadable else { return .unknown }
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else { return .unknown }
        do {
            let value = try await service.scoreRecovery(sessionID: score.sessionID, kind: unkeyedKind.rawValue, token: token)
            guard Self.acceptedRecovery(value, sessionID: score.sessionID, memberID: owner.accountID, kind: unkeyedKind.rawValue) else {
                return .unknown
            }
            return .confirmed(unkeyedKind)
        } catch {
            return .unknown
        }
    }

    /// MP `recover()`: read the receipt for the saved key.
    public func recover() async -> Outcome {
        guard let pending, let kind = pendingKind else { return .unknown }
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else { return .unknown }
        do {
            let receipt = try await service.receipt(pending, token: token)
            guard Self.matches(receipt, pending) else { return .unknown }
            self.pending = nil
            forget()
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
        if pending == nil, !remember(made) { return .notStored }
        pending = made
        do {
            let receipt = try await service.write(made, token: token)
            guard Self.matches(receipt, made) else { return .unknown }
            pending = nil
            forget()
            return .confirmed(kind)
        } catch let failure as OrientSessionFailure where Self.confirmedClientError(failure) {
            pending = nil
            forget()
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

    /// MP `index.js` success check for `requestManualReview`: id, session, member, kind, and status 0 or 1.
    private static func acceptedRecovery(_ value: OrientSessionJSON, sessionID: Int, memberID: Int, kind: String) -> Bool {
        guard case .object(let row) = value,
              let id = row["id"]?.exactInteger, id > 0,
              row["sessionId"]?.exactInteger == sessionID,
              row["memberId"]?.exactInteger == memberID,
              row["kind"] == .string(kind),
              let status = row["status"]?.exactInteger, status == 0 || status == 1 else { return false }
        return true
    }

    private func adopt(_ slot: OrientScoreSettlementSlot) {
        guard let kind = Kind(rawValue: slot.kind) else {
            journalUnreadable = true
            return
        }
        let operation: OrientSessionOperation = kind == .sync ? .sync(sessionID: score.sessionID) : .settle(sessionID: score.sessionID)
        if let requestID = slot.requestID,
           let restored = try? OrientSessionPending(owner: owner, scope: score.scope, key: requestID, operation: operation) {
            pending = restored
            return
        }
        unkeyedKind = kind
    }

    /// Save the key before the first POST. A missing journal is fine. A failed save sends nothing.
    private func remember(_ made: OrientSessionPending) -> Bool {
        guard let journal else { return true }
        guard let kind = Self.kind(made) else { return false }
        do {
            try journal.store(OrientScoreSettlementSlot(kind: kind.rawValue, requestID: made.key))
            return true
        } catch {
            return false
        }
    }

    private func forget() { try? journal?.remove() }
}

/// One saved sync or settle for this round. `requestID` nil means the row lost its id (请人工核对).
public struct OrientScoreSettlementSlot: Equatable, Sendable {
    public let kind: String
    public let requestID: String?
    public init(kind: String, requestID: String?) {
        self.kind = kind
        self.requestID = requestID
    }
}

/// Durable slot for the score page. Logout does not erase it. No token is stored.
@MainActor public protocol OrientScoreSettlementJournal: AnyObject {
    func load() throws -> OrientScoreSettlementSlot?
    func store(_ slot: OrientScoreSettlementSlot) throws
    func remove() throws
}

/// One file per account, namespace, and round under Application Support.
@MainActor public final class OrientScoreSettlementFileJournal: OrientScoreSettlementJournal {
    private let fileURL: URL
    private let accountID: Int
    private let sessionID: Int

    public init(directory: URL, accountID: Int, namespace: String, sessionID: Int) throws {
        guard directory.isFileURL, accountID > 0, sessionID > 0, !namespace.isEmpty, namespace.utf8.count <= 2048 else {
            throw OrientSessionFlowError.storageUnavailable
        }
        let folder = directory.standardizedFileURL.appendingPathComponent("orient-score-settlement", isDirectory: true)
        let name = "\(accountID)-\(sessionID)-\(Self.fnv(namespace)).json"
        fileURL = folder.appendingPathComponent(name).standardizedFileURL
        guard fileURL.isFileURL else { throw OrientSessionFlowError.storageUnavailable }
        self.accountID = accountID
        self.sessionID = sessionID
    }

    public func load() throws -> OrientScoreSettlementSlot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let stored = try read()
        guard stored.version == 1, stored.accountID == accountID, stored.sessionID == sessionID else {
            throw OrientSessionFlowError.storageUnavailable
        }
        return OrientScoreSettlementSlot(kind: stored.kind, requestID: stored.requestID)
    }

    public func store(_ slot: OrientScoreSettlementSlot) throws {
        guard OrientScoreSettlementWriter.Kind(rawValue: slot.kind) != nil else { throw OrientSessionFlowError.storageUnavailable }
        let stored = Stored(version: 1, accountID: accountID, sessionID: sessionID, kind: slot.kind, requestID: slot.requestID)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            let bytes = try JSONEncoder().encode(stored)
            #if os(iOS) || os(tvOS) || os(watchOS)
            try bytes.write(to: fileURL, options: [.atomic, .completeFileProtection])
            var mutableURL = fileURL
            var resources = URLResourceValues()
            resources.isExcludedFromBackup = true
            try mutableURL.setResourceValues(resources)
            #else
            try bytes.write(to: fileURL, options: .atomic)
            #endif
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            guard try load() == slot else { throw OrientSessionFlowError.storageUnavailable }
        } catch {
            throw OrientSessionFlowError.storageUnavailable
        }
    }

    public func remove() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
            guard try load() == nil else { throw OrientSessionFlowError.storageUnavailable }
        } catch {
            throw OrientSessionFlowError.storageUnavailable
        }
    }

    private struct Stored: Codable, Equatable {
        let version: Int
        let accountID: Int
        let sessionID: Int
        let kind: String
        let requestID: String?
    }

    private func read() throws -> Stored {
        do {
            let bytes = try Data(contentsOf: fileURL)
            guard bytes.count <= 4096 else { throw OrientSessionFlowError.storageUnavailable }
            return try JSONDecoder().decode(Stored.self, from: bytes)
        } catch {
            throw OrientSessionFlowError.storageUnavailable
        }
    }

    private static func fnv(_ text: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }
}
