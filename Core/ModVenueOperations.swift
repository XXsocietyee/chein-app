import Foundation
import Observation

public struct ModVenueOperationDocument: Codable, Equatable {
    public struct Window: Codable, Equatable { public let from, until: Int64 }
    public struct Place: Codable, Equatable {
        public let slotId: String
        public let poiId: Int64
        public let fingerprint, consentEvidenceRef, safetyReviewRef: String
        public let operatingWindows: [Window]
    }
    public let schema, installationRequestId, bindingHash, purpose, ruleVersion: String
    public let proofValidityMillis: Int64
    public let places: [Place]
    func validate(_ installation: ModInstallationReceipt) throws {
        guard schema == "mod-venue-operation-v1", installationRequestId == installation.requestId, bindingHash == installation.bindingHash,
              purpose == "VENUE_CHECK", QmodSourceSubmissionWire.hashValid(ruleVersion), (1...Int64(Int32.max)).contains(proofValidityMillis),
              !places.isEmpty, places.count == installation.bindings.count, Set(places.map(\.slotId)).count == places.count else { throw ModInstallationIssue.invalidSelection }
        for p in places {
            guard let b = installation.bindings.first(where: { $0.key == p.slotId }), b.kind.rawValue == "POI", b.resourceId == p.poiId, b.fingerprint == p.fingerprint,
                  p.consentEvidenceRef.range(of: #"\A[A-Za-z0-9][A-Za-z0-9_:/.-]{1,999}\z"#, options: .regularExpression) != nil,
                  p.safetyReviewRef.range(of: #"\A[A-Za-z0-9][A-Za-z0-9_:/.-]{1,999}\z"#, options: .regularExpression) != nil,
                  (1...366).contains(p.operatingWindows.count) else { throw ModInstallationIssue.invalidSelection }
            var end: Int64 = -1
            for w in p.operatingWindows { guard w.from >= 0, w.from >= end, w.until > w.from, w.until <= 253402300799000 else { throw ModInstallationIssue.invalidSelection }; end = w.until }
        }
    }
}
public struct ModVenueWorkspace: Decodable, Equatable {
    public struct Node: Decodable, Equatable, Identifiable { public let nodeId: Int64; public let title, slotId: String; public var id: Int64 { nodeId } }
    public let schema, installationRequestId, bindingHash, policyRef, ruleVersion, purpose: String
    public let installationId, topicId: Int64
    public let bindings: [ModInstallationBoundResource]
    public let legalPermissionIssued: Bool
    public let nodes: [Node]
    public let consentId: Int64?
    public let event, version: String?
    public let document: ModVenueOperationDocument?
    func validate(_ i: ModInstallationReceipt) throws {
        guard schema == "mod-venue-operation-workspace-v1", installationRequestId == i.requestId, installationId > 0,
              let installationTopicID = i.topicID, topicId == Int64(installationTopicID),
              bindingHash == i.bindingHash, bindings == i.bindings, !bindings.isEmpty, bindings.allSatisfy({ $0.kind.rawValue == "POI" }),
              !legalPermissionIssued, policyRef == "original-live-code-venue-v1", purpose == "VENUE_CHECK", QmodSourceSubmissionWire.hashValid(ruleVersion),
              !nodes.isEmpty, Set(nodes.map(\.nodeId)).count == nodes.count, nodes.allSatisfy({ $0.nodeId > 0 }) else { throw ModInstallationIssue.malformed }
        for node in nodes { guard bindings.contains(where: { $0.key == node.slotId }) else { throw ModInstallationIssue.malformed } }
        if let consentId { guard consentId > 0, ["AGREE", "REVOKE"].contains(event ?? ""), version.map(QmodSourceSubmissionWire.hashValid) == true else { throw ModInstallationIssue.malformed } }
        else { guard event == nil, version == nil, document == nil else { throw ModInstallationIssue.malformed } }
        if event == "AGREE" { guard let document, document.ruleVersion == ruleVersion else { throw ModInstallationIssue.malformed }; try document.validate(i) }
        else { guard document == nil else { throw ModInstallationIssue.malformed } }
    }
}
public struct ModVenueOperationCommand: Codable, Equatable {
    public let requestId, installationRequestId: String
    public let expectedConsentId: Int64?
    public let event: String
    public let document: ModVenueOperationDocument?
}
public struct ModVenueOperationReceipt: Codable, Equatable {
    public let requestId, event, status: String
    public let version, reason: String?
    public let consentId: Int64?
    public let installationId: Int64
    public let executionPermit: Bool
    func validate(_ pending: ModVenueOperationPending) throws {
        guard requestId == pending.command.requestId, event == pending.command.event, installationId == pending.installationId, !executionPermit else { throw ModInstallationIssue.malformed }
        if status == "COMMITTED" { guard consentId.map({ $0 > 0 }) == true, version.map(QmodSourceSubmissionWire.hashValid) == true, reason == nil else { throw ModInstallationIssue.malformed } }
        else { guard status == "REJECTED_BEFORE_WRITE", consentId == nil, version == nil, reason?.hasPrefix("QMOD_") == true else { throw ModInstallationIssue.malformed } }
    }
}
public struct ModVenueOperationPending: Codable, Equatable {
    public let installation: ModInstallationReceipt
    public let installationId: Int64
    public let command: ModVenueOperationCommand
    public var receipt: ModVenueOperationReceipt?
    func validate() throws {
        try installation.validate(identity: installation.identity)
        guard installation.state == .installed, installation.topicID != nil, installationId > 0,
              command.installationRequestId == installation.requestId, UUID(uuidString: command.requestId)?.uuidString.lowercased() == command.requestId,
              command.expectedConsentId.map({ $0 > 0 }) ?? true else { throw ModInstallationIssue.invalidSelection }
        if command.event == "AGREE" { guard let document = command.document else { throw ModInstallationIssue.invalidSelection }; try document.validate(installation) }
        else { guard command.event == "REVOKE", command.expectedConsentId != nil, command.document == nil else { throw ModInstallationIssue.invalidSelection } }
        if let receipt { try receipt.validate(self) }
    }
}
public struct ModVenueIssuedCode: Decodable, Equatable {
    public let nodeId: Int64
    public let code: String
    public let nodeName, qrcodeUrl: String?
    public let ttlMs: Int64
    func validate(node: Int64) throws { guard nodeId == node, !code.isEmpty, code.utf8.count <= 2048, ttlMs > 0, ttlMs <= 60000 else { throw ModInstallationIssue.malformed } }
}
/// One private visit over the existing installation lease and original scoped journal.
/// Closing invalidates presentation claims, never the shared installation service or a server command.
@MainActor @Observable public final class ModVenueOperations: Identifiable {
    public struct Confirmation: Identifiable {
        public let id = UUID()
        fileprivate let visit: UUID, workspace: ModVenueWorkspace, previous: ModVenueOperationPending?
        fileprivate let event: String, document: ModVenueOperationDocument?
    }
    public struct CodeClaim {
        fileprivate let visit: UUID, visibility: UUID, workspace: ModVenueWorkspace, node: Int64
    }
    public let id = UUID()
    public let installation: ModInstallationReceipt
    public private(set) var workspace: ModVenueWorkspace?
    public private(set) var pending: ModVenueOperationPending?
    public private(set) var issued: ModVenueIssuedCode?
    public private(set) var issue: String?
    public private(set) var busy = false
    public private(set) var originalUnknown = false
    public private(set) var workspaceFresh = false
    private var originalConfirmed = false
    private var storageBlocked = false
    private var suspended = true
    private var visit = UUID()
    private var codeVisibility = UUID()
    private let service: any ModInstallationServing
    private let store: ModInstallationPendingStore
    public var isCurrent: Bool { service.isCurrent }
    private var ready: Bool { !suspended && isCurrent && !busy && !storageBlocked }
    public var canWrite: Bool { ready && service.canMutate && workspaceFresh && (pending == nil || (pending?.receipt != nil && originalConfirmed)) }
    public var canRetryExact: Bool { ready && service.canMutate && pending != nil && pending?.receipt == nil }
    init(installation: ModInstallationReceipt, service: any ModInstallationServing, store: ModInstallationPendingStore) {
        self.installation = installation; self.service = service; self.store = store
    }
    public func suspend() {
        suspended = true; visit = UUID(); hideCode(); busy = false
        workspace = nil; workspaceFresh = false; pending = nil; originalUnknown = false; originalConfirmed = false; issue = nil
    }
    private func check(_ ticket: UUID) throws {
        guard !suspended, visit == ticket else { throw CancellationError() }
        guard isCurrent else { suspend(); throw ModInstallationIssue.staleSession }
        try Task.checkCancellation()
    }
    private func visible(_ ticket: UUID, error: Error) -> Bool {
        guard !suspended, visit == ticket else { return false }
        if !isCurrent || error as? ModInstallationIssue == .unauthorized || error as? ModInstallationIssue == .staleSession {
            suspend(); return false
        }
        guard !Task.isCancelled, !(error is CancellationError) else { suspend(); return false }
        return true
    }
    private func finish(_ ticket: UUID) { if visit == ticket { busy = false } }
    private func accept(_ receipt: ModVenueOperationReceipt, original: ModVenueOperationPending, ticket: UUID) throws {
        try check(ticket); try receipt.validate(original)
        guard pending == original, try store.loadVenue(installation: installation) == original,
              original.receipt == nil || original.receipt == receipt else { throw ModInstallationIssue.pendingConflict }
        var next = original; next.receipt = receipt; try store.acceptVenue(next); pending = next
        originalConfirmed = true; originalUnknown = false
    }
    private func readWorkspace(_ ticket: UUID) async throws {
        try check(ticket); workspaceFresh = false
        let value = try await service.venueWorkspace(installation); try check(ticket); try value.validate(installation)
        workspace = value; workspaceFresh = true
    }
    /// Restart/foreground only reads the persisted original UUID, then independent current.
    public func load() async {
        guard !Task.isCancelled, !busy else { return }
        guard isCurrent else { suspend(); return }
        suspended = false; visit = UUID(); let ticket = visit
        busy = true; issue = nil; hideCode(); workspace = nil; workspaceFresh = false
        pending = nil; originalUnknown = false; originalConfirmed = false; storageBlocked = false
        defer { finish(ticket) }
        do {
            try check(ticket)
            do { pending = try store.loadVenue(installation: installation) }
            catch { storageBlocked = true; throw error }
            if let original = pending {
                do {
                    let receipt = try await service.venueReceipt(original); try check(ticket)
                    try accept(receipt, original: original, ticket: ticket)
                } catch {
                    guard visible(ticket, error: error) else { return }
                    originalUnknown = true
                    issue = "原请求回读未确认；已知回执仅保留为历史，不能由当前同意替代。 / Original receipt reread unconfirmed; current consent is not its result."
                }
            }
            try await readWorkspace(ticket)
        } catch {
            guard visible(ticket, error: error) else { return }
            workspaceFresh = false
            issue = "当前读取不可用；原同意与原请求未更改。 / Current read unavailable; original consent and request are unchanged."
        }
    }
    /// Capture the displayed consent version synchronously, before the confirmation Task.
    public func review(event: String, document: ModVenueOperationDocument?) throws -> Confirmation {
        guard canWrite, let workspace else { throw ModInstallationIssue.disabled }
        if event == "AGREE" {
            guard let document, document.ruleVersion == workspace.ruleVersion else { throw ModInstallationIssue.invalidSelection }
            try document.validate(installation)
        } else {
            guard event == "REVOKE", document == nil, workspace.event == "AGREE", workspace.consentId != nil else { throw ModInstallationIssue.invalidSelection }
        }
        return .init(visit: visit, workspace: workspace, previous: pending, event: event, document: document)
    }
    public func canConfirm(_ review: Confirmation) -> Bool {
        canWrite && review.visit == visit && review.workspace == workspace && review.previous == pending
    }
    public func confirm(_ review: Confirmation) async {
        guard canConfirm(review) else { return }
        let ticket = visit; busy = true; issue = nil; hideCode(); workspaceFresh = false
        defer { finish(ticket) }
        do {
            try await readWorkspace(ticket)
            guard service.canMutate, workspace == review.workspace,
                  try store.loadVenue(installation: installation) == review.previous else { throw ModInstallationIssue.pendingConflict }
            let value = ModVenueOperationPending(installation: installation, installationId: review.workspace.installationId,
                command: .init(requestId: UUID().uuidString.lowercased(), installationRequestId: installation.requestId,
                    expectedConsentId: review.workspace.consentId, event: review.event, document: review.document), receipt: nil)
            try value.validate(); try store.beginVenue(value); pending = value; originalConfirmed = false
            try await dispatch(value, ticket: ticket)
        } catch {
            guard visible(ticket, error: error) else { return }
            workspaceFresh = false
            if pending?.receipt == nil, pending != nil { originalUnknown = true }
            issue = "审阅版本已变化或提交未确认；没有替换原请求。请回读后重新明确审阅。 / Review changed or submission unconfirmed; no replacement request was made. Reread before reviewing again."
        }
    }
    public func retryExact() async {
        guard canRetryExact, let original = pending else { return }
        let ticket = visit; busy = true; issue = nil; hideCode(); defer { finish(ticket) }
        do {
            try check(ticket)
            guard try store.loadVenue(installation: installation) == original else { throw ModInstallationIssue.pendingConflict }
            do {
                let receipt = try await service.venueReceipt(original); try check(ticket)
                try accept(receipt, original: original, ticket: ticket)
            } catch ModInstallationIssue.requestNotFound {
                try check(ticket); guard service.canMutate else { throw ModInstallationIssue.disabled }
                try await dispatch(original, ticket: ticket); return
            }
            try await readWorkspace(ticket)
        } catch {
            guard visible(ticket, error: error) else { return }
            if pending?.receipt == nil { originalUnknown = true }
            issue = "原请求未确认；仅保留原 UUID，不自动重发。 / Original request unconfirmed; retain its UUID without automatic retry."
        }
    }
    private func dispatch(_ original: ModVenueOperationPending, ticket: UUID) async throws {
        try check(ticket)
        guard service.canMutate, try store.loadVenue(installation: installation) == original else { throw ModInstallationIssue.pendingConflict }
        workspaceFresh = false
        let receipt = try await service.venueCommand(original); try check(ticket)
        try accept(receipt, original: original, ticket: ticket)
        // Failure here cannot replace or downgrade the known original receipt.
        try await readWorkspace(ticket)
    }
    public func claimCode(node: Int64) -> CodeClaim? {
        guard canWrite, let workspace, workspace.event == "AGREE", workspace.nodes.contains(where: { $0.nodeId == node }) else { return nil }
        hideCode()
        return .init(visit: visit, visibility: codeVisibility, workspace: workspace, node: node)
    }
    public func issueCode(_ claim: CodeClaim) async {
        guard canWrite, claim.visit == visit, claim.visibility == codeVisibility, workspace == claim.workspace else { return }
        let ticket = visit; codeVisibility = UUID(); let visibility = codeVisibility
        busy = true; issued = nil; issue = nil; defer { finish(ticket) }
        do {
            try check(ticket)
            let code = try await service.venueCode(installation, node: claim.node); try check(ticket)
            guard visibility == codeVisibility, service.canMutate else { return }
            try code.validate(node: claim.node); issued = code
        } catch {
            guard visible(ticket, error: error) else { return }
            issue = "签发未确认；不自动重试，需要原审核及当前营业窗口。 / Issuance unconfirmed; no automatic retry. Original review and current operating window are required."
        }
    }
    /// Also retires any already in-flight code response without claiming server cancellation.
    public func hideCode() { codeVisibility = UUID(); issued = nil }
}
