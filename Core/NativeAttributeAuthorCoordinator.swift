import Foundation
import Observation

@MainActor @Observable public final class NativeAttributeAuthorCoordinator {
    public enum Phase: String { case idle, loading, ready, editing, validating, review, sending, unknown, blocked, confirmed, retired }
    public private(set) var phase: Phase = .idle
    public private(set) var draft: NativeAttributeAuthorDraft?
    public private(set) var issue: String?
    public private(set) var warnings: [String] = []
    public private(set) var referenceReadback: NativeAttributeAuthorReferences?
    public private(set) var pending: NativeAttributeAuthorPending?
    public private(set) var projectResult: NativeAttributeAuthorProjectAction?
    public private(set) var latestForInspection: NativeAttributeAuthorDraft?
    public private(set) var publishCheckResult: NativeAttributeAuthorPublishCheck?
    public private(set) var modulePreflightResult: NativeAttributeAuthorModulePreflight?
    public private(set) var contractGap: String?
    public private(set) var sourceRetirementReceipt: NativeAttributeAuthorMutationReceipt?
    public let binding: NativeAttributeAuthorBinding
    /// Only resumes an exact existing local record. Never interprets it as a fresh server read.
    public let localDraftOnly: Bool
    private let service: NativeAttributeAuthorService
    private let store: NativeAttributeAuthorLocalStore?
    private let projectFlow: (any NativeAttributeAuthorProjectFlow)?
    private var generation = UUID()
    private var reviewRequest: NativeAttributeAuthorRequest?
    private var deletionReview: NativeAttributeAuthorReferences?
    private var deletingKeyReview: String?
    private var projectPending = false
    private var projectSourceRetired = false
    private var storedRecovery: NativeAttributeAuthorRecovery?
    private var validationTarget: NativeAttributeAuthorValidatedTarget?
    public init(binding: NativeAttributeAuthorBinding, service: NativeAttributeAuthorService,
                store: NativeAttributeAuthorLocalStore? = nil, projectFlow: (any NativeAttributeAuthorProjectFlow)? = nil,
                localDraftOnly: Bool = false) {
        self.localDraftOnly = localDraftOnly
        self.binding = binding; self.service = service; self.store = store; self.projectFlow = projectFlow
    }
    public var busy: Bool { [.loading,.validating,.sending].contains(phase) }
    public var canEdit: Bool { !busy && phase != .retired && !binding.isLocked && pending == nil && !projectPending && !projectSourceRetired && draft?.binding == binding && store != nil }
    public var canSave: Bool { service.permitsSave && !localDraftOnly && canEdit && draft?.hasChanges == true && store != nil }
    public var canUseProjectFlow: Bool { !localDraftOnly && canEdit && draft?.hasChanges == false && projectFlow != nil && store != nil }
    public var canReadChecks: Bool { !localDraftOnly && !busy && phase != .retired && !binding.isLocked && !projectSourceRetired && (!service.usesVersionedDefinitions || pending == nil) && draft?.binding == binding }
    public var canReadPublishCheck: Bool { canReadChecks && service.permits(.publishCheck) }
    public var canReadModulePreflight: Bool { canReadChecks && service.permits(.modulePreflight) }
    public var canDelete: Bool {
        !localDraftOnly && canEdit && draft?.hasChanges == false &&
        (usesVersionedDefinitions ? service.permits(.delete) && service.permits(.references) && service.permits(.requestReceipt) : service.permits(.legacyDelete))
    }
    public var canRecoverUnsentDraft: Bool { !localDraftOnly && !busy && phase != .retired && !binding.isLocked && !projectSourceRetired && pending == nil && draft != nil && store != nil }
    public var reviewDeletesKey: String? { phase == .review ? deletingKeyReview : nil }
    public var usesVersionedDefinitions: Bool { service.usesVersionedDefinitions }
    public var retiredSourceBinding: NativeAttributeAuthorBinding? {
        guard projectSourceRetired, pending == nil else { return nil }
        return latestForInspection?.binding ?? draft?.binding
    }
    private func check(_ ticket: UUID) throws {
        guard generation == ticket, phase != .retired else { throw NativeAttributeAuthorError.staleSource }
        try service.check(binding)
    }
    private func checkIdentity(_ ticket: UUID, expected: NativeAttributeAuthorBinding) throws {
        guard generation == ticket, phase != .retired else { throw NativeAttributeAuthorError.staleSource }
        try service.checkIdentity(expected)
    }
    public func retire() {
        generation = UUID(); phase = .retired; draft = nil; latestForInspection = nil
        pending = nil; referenceReadback = nil; deletionReview = nil; reviewRequest = nil; issue = nil; warnings = []
        deletingKeyReview = nil; publishCheckResult = nil; modulePreflightResult = nil; contractGap = nil
        validationTarget = nil; sourceRetirementReceipt = nil
        // Durable local drafts and unknown requests remain in the original owner namespace.
    }
    private func message(_ error: Error) -> String {
        switch error {
        case NativeAttributeAuthorError.rejected(let text): return text
        case NativeAttributeAuthorError.versionConflict(let text): return text
        case NativeAttributeAuthorError.invalid: return "nativeAttribute.invalid"
        case NativeAttributeAuthorError.unavailable: return "nativeAttribute.unavailable"
        case NativeAttributeAuthorError.contractMissing: return "nativeAttribute.extensionWriteMissing"
        case NativeAttributeAuthorError.staleSource: return "nativeAttribute.stale"
        case NativeAttributeAuthorError.storage: return "nativeAttribute.storage"
        case NativeAttributeAuthorError.mixedBatch: return "nativeAttribute.mixedBatch"
        default: return "nativeAttribute.unknown"
        }
    }
    private func report(_ error: Error, phase next: Phase = .blocked) {
        if case NativeAttributeAuthorError.contractMissing(let detail) = error { contractGap = detail }
        if case NativeAttributeAuthorError.versionConflict = error { projectSourceRetired = true }
        issue = message(error); phase = next
    }
    private func persist(_ value: NativeAttributeAuthorRecovery) throws {
        guard let store else { throw NativeAttributeAuthorError.storage }
        try store.save(value, replacing: storedRecovery); storedRecovery = value
    }
    public func load() async {
        guard phase == .idle || (phase == .blocked && draft == nil), !busy else { return }
        let ticket = generation; phase = .loading
        do {
            try check(ticket)
            if localDraftOnly {
                guard !binding.isLocked, let restored = try store?.load(binding: binding),
                      restored.pending == nil, restored.draft.binding == binding else {
                    throw NativeAttributeAuthorError.unavailable("exact unsent local attribute draft")
                }
                // No registry GET, rebase, receipt reconciliation, or pending replay. The
                // same original store/compare-and-swap remains the only local saver.
                storedRecovery = restored; draft = restored.draft; phase = .editing
                return
            }
            // Frozen readback never loads a mutable current draft from local recovery.
            if !binding.isLocked, let restored = try store?.load(binding: binding) {
                storedRecovery = restored
                draft = restored.draft; pending = restored.pending
                if let pending = restored.pending {
                    phase = .unknown; issue = pending.requiresOriginalContractRecovery ? "nativeAttribute.historicalRecovery" : pending.acknowledged ? "nativeAttribute.readbackNeeded" : "nativeAttribute.unknown"
                    return // A cold-start prepared record is inspected, never automatically sent.
                }
                if restored.draft.binding != binding {
                    issue = "nativeAttribute.restoredSourceChanged"; phase = .blocked; return
                }
                let current = try await service.load(binding); try check(ticket)
                let recovered = try restored.draft.recoverUnsent(binding: binding, authoritative: current)
                try persist(.init(draft: recovered)); draft = recovered; phase = .editing; return
            }
            let value = try await service.load(binding); try check(ticket)
            draft = value; phase = .ready
        } catch {
            guard generation == ticket, phase != .retired else { return }; report(error)
        }
    }
    @discardableResult public func replace(_ row: NativeAttributeAuthorRow) -> Bool {
        guard canEdit, var value = draft else { return false }
        do {
            try service.check(binding); try value.replace(row)
            try persist(.init(draft: value))
            draft = value; phase = .editing; issue = nil; reviewRequest = nil; deletionReview = nil; referenceReadback = nil; validationTarget = nil
            return true
        } catch { report(error); return false }
    }
    public func recoverUnsentDraft() async {
        guard canRecoverUnsentDraft, let draft else { return }
        let ticket = generation; phase = .loading
        do {
            let latest = try await service.load(binding); try check(ticket)
            let recovered = try draft.recoverUnsent(binding: binding, authoritative: latest)
            try persist(.init(draft: recovered)); self.draft = recovered; issue = nil; phase = .editing
        } catch {
            guard generation == ticket, phase != .retired else { return }; report(error)
        }
    }
    @discardableResult public func add(registrationOnly: Bool? = nil) -> UUID? {
        guard canEdit, var value = draft else { return nil }
        do {
            try service.check(binding); let id = try value.add(registrationOnly: registrationOnly ?? !service.usesVersionedDefinitions)
            try persist(.init(draft: value))
            draft = value; phase = .editing; issue = nil; validationTarget = nil; reviewRequest = nil; return id
        } catch { report(error); return nil }
    }
    public func reorder(_ keys: [String]) {
        guard canEdit, var value = draft else { return }
        do {
            try service.check(binding); try value.reorder(keys)
            try persist(.init(draft: value))
            draft = value; phase = .editing; issue = nil; reviewRequest = nil; deletionReview = nil; referenceReadback = nil; validationTarget = nil
        } catch { report(error) }
    }
    public func removeUnsaved(_ id: UUID) {
        guard canEdit, var value = draft else { return }
        do {
            try service.check(binding); try value.removeUnsaved(id)
            try persist(.init(draft: value))
            draft = value; phase = .editing; issue = nil; reviewRequest = nil; validationTarget = nil
        } catch { report(error) }
    }
    public func prepareSave() async {
        guard canSave, let draft else { return }
        let ticket = generation; phase = .validating; warnings = []; reviewRequest = nil; deletionReview = nil; referenceReadback = nil; deletingKeyReview = nil; contractGap = nil
        validationTarget = nil
        do {
            try check(ticket)
            let rows = try draft.changedRows(); guard !rows.isEmpty else { phase = .ready; return }
            let prepared = try await service.prepareSave(draft, key: UUID()); try check(ticket)
            warnings = prepared.2; reviewRequest = prepared.0; validationTarget = prepared.1; phase = .review; issue = nil
        } catch {
            guard generation == ticket, phase != .retired else { return }; report(error)
        }
    }
    public func cancelReview() {
        guard phase == .review else { return }; reviewRequest = nil; deletionReview = nil; deletingKeyReview = nil; validationTarget = nil; phase = .editing
    }
    public func readPublishCheck() async {
        guard canReadPublishCheck else { return }
        let ticket = generation, previous = phase, key = UUID(); phase = .loading
        do {
            let result = try await service.publishCheck(binding, key: key); try check(ticket)
            guard result.binding == binding, result.requestKey == key else { throw NativeAttributeAuthorError.staleSource }
            publishCheckResult = result; phase = previous; issue = nil
        } catch {
            guard generation == ticket, phase != .retired else { return }; report(error, phase: previous)
        }
    }
    public func readModulePreflight() async {
        guard canReadModulePreflight else { return }
        let ticket = generation, previous = phase, key = UUID(); phase = .loading
        // A failed refresh must not leave an earlier ready report looking like the current result.
        modulePreflightResult = nil
        do {
            let result = try await service.modulePreflight(binding, key: key); try check(ticket)
            guard result.binding == binding, result.requestKey == key else { throw NativeAttributeAuthorError.staleSource }
            modulePreflightResult = result; phase = previous; issue = nil
        } catch {
            guard generation == ticket, phase != .retired else { return }; report(error, phase: previous)
        }
    }
    public func prepareDelete(_ key: String) async {
        guard canDelete,
              draft?.rows.contains(where: { $0.existingKey?.utf8.elementsEqual(key.utf8) == true }) == true else { return }
        let ticket = generation; phase = .loading; referenceReadback = nil; deletionReview = nil; reviewRequest = nil; deletingKeyReview = nil; validationTarget = nil
        do {
            try check(ticket)
            let requestKey = UUID()
            if !service.hasReferenceReadContract {
                // The committed DELETE itself reads referencesOf before delete. No fabricated
                // empty-reference result is created from GET/publish-check/module-preflight.
                deletingKeyReview = key; reviewRequest = try service.deleteRequest(key, binding: binding, requestKey: requestKey)
                warnings = ["nativeAttribute.serverReferenceCheck"]; issue = nil; phase = .review; return
            }
            let read = try await service.readReferences(binding: binding, key: key, requestKey: requestKey); try check(ticket)
            referenceReadback = read
            guard read.permitsDelete else {
                issue = read.incompleteReason ?? "nativeAttribute.referenced"; phase = .blocked; return
            }
            deletionReview = read; deletingKeyReview = key
            reviewRequest = try service.deleteRequest(key, binding: binding, requestKey: read.requestKey)
            phase = .review; issue = nil
        } catch {
            guard generation == ticket, phase != .retired else { return }; report(error)
        }
    }
    public func confirm() async {
        guard !localDraftOnly, phase == .review, pending == nil, let request = reviewRequest, let draft, store != nil else { return }
        let ticket = generation
        var attempt = NativeAttributeAuthorPending(request: request, draft: draft, deletingKey: deletingKeyReview)
        attempt.validatedTarget = validationTarget
        phase = .sending
        if request.method == .delete, service.hasReferenceReadContract {
            do {
                guard let reviewed = deletionReview else { throw NativeAttributeAuthorError.staleSource }
                let latest = try await service.readReferences(binding: binding, key: reviewed.stateKey, requestKey: reviewed.requestKey)
                try check(ticket)
                guard latest == reviewed, latest.permitsDelete else { throw NativeAttributeAuthorError.rejected("nativeAttribute.referencesChanged") }
            } catch {
                guard generation == ticket, phase != .retired else { return }; report(error); return
            }
        }
        do {
            try check(ticket)
            try persist(.init(draft: draft, pending: attempt)); try check(ticket)
            attempt.dispatchStarted = true
            // Mark and verify before the potentially suspending final-forward transport.
            try persist(.init(draft: draft, pending: attempt)); pending = attempt; reviewRequest = nil
            try check(ticket)
        } catch {
            guard generation == ticket, phase != .retired else { return }
            pending = attempt; report(error, phase: .unknown); return
        }
        do {
            let reply = try await service.submitWithReceipt(attempt)
            try checkIdentity(ticket, expected: request.binding)
            switch reply {
            case .legacyAcknowledged:
                attempt.acknowledged = true
                try persist(.init(draft: draft, pending: attempt)); pending = attempt
                await reconcileAcknowledged(ticket: ticket)
            case .confirmed(let receipt):
                attempt.receipt = receipt; attempt.lastResponse = receipt.response; attempt.acknowledged = true
                try persist(.init(draft: draft, pending: attempt)); pending = attempt
                try acceptReceipt(receipt, ticket: ticket)
            case .unconfirmed(let response):
                attempt.lastResponse = response
                try persist(.init(draft: draft, pending: attempt)); pending = attempt
                issue = "nativeAttribute.unknown"; phase = .unknown
            case .notDeleted:
                try persist(.init(draft: draft)); pending = nil; projectSourceRetired = true
                issue = "nativeAttribute.notDeleted"; phase = .blocked
            }
        } catch {
            guard generation == ticket, phase != .retired else { return }
            if case NativeAttributeAuthorError.unconfirmedResponse(let bytes) = error {
                attempt.lastResponse = bytes
                do { try persist(.init(draft: draft, pending: attempt)); pending = attempt } catch { /* Original pending remains durable. */ }
                report(error, phase: .unknown)
            } else if case NativeAttributeAuthorError.versionConflict = error {
                do { try persist(.init(draft: draft)); pending = nil; deletionReview = nil; report(error) }
                catch { report(error, phase: .unknown) }
            } else if case NativeAttributeAuthorError.rejected = error {
                do {
                    try persist(.init(draft: draft)); pending = nil; deletionReview = nil; report(error)
                } catch { report(error, phase: .unknown) }
            } else { report(error, phase: .unknown) }
        }
    }
    /// New explicitly recorded protocol requests recover the same original server receipt.
    /// Historical local-only UUIDs still inspect only; latest definitions are never a receipt.
    public func readback() async {
        guard !localDraftOnly, !busy, pending != nil, phase != .retired else { return }
        let ticket = generation
        if let receipt = pending?.receipt, pending?.acknowledged == true {
            phase = .loading
            do { try acceptReceipt(receipt, ticket: ticket) }
            catch { guard generation == ticket, phase != .retired else { return }; report(error, phase: .unknown) }
            return
        }
        if service.usesVersionedDefinitions {
            phase = .loading
            do {
                guard let pending else { return }
                try checkIdentity(ticket, expected: pending.request.binding)
                if pending.acknowledged && !pending.request.isVersionedMutation && !pending.requiresOriginalContractRecovery {
                    await reconcileAcknowledged(ticket: ticket); return
                }
                if pending.request.isVersionedMutation && pending.originalRequestProtocol == NativeAttributeAuthorRequest.originalRequestProtocol && pending.dispatchStarted {
                    let reply = try await service.recoverOriginal(pending)
                    try checkIdentity(ticket, expected: pending.request.binding)
                    guard let draft else { throw NativeAttributeAuthorError.storage }
                    var recovered = pending
                    switch reply {
                    case .confirmed(let receipt):
                        recovered.receipt = receipt; recovered.lastResponse = receipt.response; recovered.acknowledged = true
                        try persist(.init(draft: draft, pending: recovered)); self.pending = recovered
                        try acceptReceipt(receipt, ticket: ticket)
                    case .unconfirmed(let response):
                        recovered.lastResponse = response
                        try persist(.init(draft: draft, pending: recovered)); self.pending = recovered
                        phase = .unknown; issue = "nativeAttribute.unknown"
                    case .notDeleted:
                        try persist(.init(draft: draft)); self.pending = nil; projectSourceRetired = true
                        phase = .blocked; issue = "nativeAttribute.notDeleted"
                    case .legacyAcknowledged: throw NativeAttributeAuthorError.invalid("original request GET cannot be a legacy ACK")
                    }
                    return
                }
                let latest = try await service.inspectCurrent(pending.request.binding)
                try checkIdentity(ticket, expected: pending.request.binding)
                latestForInspection = latest; phase = .unknown; issue = "nativeAttribute.inspectionOnly"
            } catch {
                guard generation == ticket, phase != .retired else { return }; report(error, phase: .unknown)
            }
            return
        }
        if pending?.acknowledged == true && pending?.request.binding == binding && pending?.requiresOriginalContractRecovery == false { phase = .loading; await reconcileAcknowledged(ticket: ticket); return }
        phase = .loading
        do {
            let latest = try await service.load(binding); try check(ticket)
            latestForInspection = latest; phase = .unknown; issue = "nativeAttribute.inspectionOnly"
        } catch {
            guard generation == ticket, phase != .retired else { return }; report(error, phase: .unknown)
        }
    }
    private func reconcileAcknowledged(ticket: UUID) async {
        guard let pending, pending.acknowledged, !pending.requiresOriginalContractRecovery, store != nil else { return }
        do {
            let latest: NativeAttributeAuthorDraft
            if service.usesVersionedDefinitions {
                try checkIdentity(ticket, expected: pending.request.binding)
                latest = try await service.inspectCurrent(pending.request.binding)
                try checkIdentity(ticket, expected: pending.request.binding)
                guard latest.binding.sourceConfigVersion > pending.request.binding.sourceConfigVersion else { throw NativeAttributeAuthorError.uncertain }
            } else { latest = try await service.load(binding); try check(ticket) }
            latestForInspection = latest
            if let key = pending.deletingKey {
                guard !latest.rows.contains(where: { $0.key.utf8.elementsEqual(key.utf8) }) else { throw NativeAttributeAuthorError.uncertain }
            } else {
                for expected in try pending.draft.changedRows() {
                    guard let actual = latest.rows.first(where: { $0.key.utf8.elementsEqual(expected.key.utf8) }) else { throw NativeAttributeAuthorError.uncertain }
                    let actualFields = try actual.definition(), expectedFields = try expected.definition()
                    // Compare the complete intended definition; a concurrent edit cannot become our success.
                    guard NativeAttributeAuthorWire.same(.object(actualFields), .object(expectedFields)) else { throw NativeAttributeAuthorError.uncertain }
                }
            }
            try persist(.init(draft: latest))
            if service.usesVersionedDefinitions { try checkIdentity(ticket, expected: pending.request.binding) } else { try check(ticket) }
            self.pending = nil; self.draft = latest; deletionReview = nil; referenceReadback = nil
            reviewRequest = nil; issue = service.usesVersionedDefinitions ? "nativeAttribute.reloadProject" : nil; phase = .confirmed
            if service.usesVersionedDefinitions { projectSourceRetired = true }
        } catch {
            guard generation == ticket, phase != .retired else { return }; report(error, phase: .unknown)
        }
    }
    private func acceptReceipt(_ receipt: NativeAttributeAuthorMutationReceipt, ticket: UUID) throws {
        try checkIdentity(ticket, expected: receipt.originalBinding)
        guard let pending, pending.receipt == receipt, pending.request.requestKey == receipt.requestKey,
              pending.acknowledged else { throw NativeAttributeAuthorError.storage }
        let latest = try receipt.readback()
        try persist(.init(draft: latest))
        try checkIdentity(ticket, expected: receipt.originalBinding)
        self.pending = nil; draft = latest; latestForInspection = latest; validationTarget = nil
        reviewRequest = nil; deletionReview = nil; deletingKeyReview = nil; referenceReadback = nil
        projectSourceRetired = true; sourceRetirementReceipt = receipt
        phase = .confirmed; issue = "nativeAttribute.reloadProject"
    }
    public func performProjectAction(_ action: NativeAttributeAuthorProjectAction) async {
        guard canUseProjectFlow, let flow = projectFlow, let draft, store != nil else { return }
        let ticket = generation, key = UUID(); phase = .sending; projectResult = nil
        do {
            try check(ticket); try persist(.init(draft: draft))
            projectPending = true
            let result = try await flow.perform(action, binding: binding, requestKey: key)
            try service.checkIdentity(binding)
            guard generation == ticket, phase != .retired, result.requestKey == key,
                  result.action == action, result.originalBinding == binding,
                  result.binding.storageKey == binding.storageKey,
                  result.binding.epoch == binding.epoch,
                  result.binding.authorizationRevision.utf8.elementsEqual(binding.authorizationRevision.utf8) else { throw NativeAttributeAuthorError.staleSource }
            let latest: NativeAttributeAuthorDraft
            if action == .publish {
                guard result.binding.isLocked else { throw NativeAttributeAuthorError.invalid("published locked definition missing") }
                latest = try NativeAttributeAuthorService.frozenDraft(binding: result.binding, source: result.source)
                // A published snapshot must originate from the exact draft version passed to the original flow.
                guard latest.binding.sourceConfigVersion == binding.sourceConfigVersion else { throw NativeAttributeAuthorError.staleSource }
            } else {
                guard !result.binding.isLocked else { throw NativeAttributeAuthorError.staleSource }
                latest = try .init(binding: result.binding, rawRows: result.source)
            }
            for row in draft.rows where row.isDefinition {
                guard let found = latest.rows.first(where: { $0.key.utf8.elementsEqual(row.key.utf8) }),
                      NativeAttributeAuthorWire.same(.object(try found.definition()), .object(try row.definition())) else { throw NativeAttributeAuthorError.invalid("project definition readback mismatch") }
            }
            // The original project flow owns its journal and may advance configVersion. Do not
            // reuse this old source binding for new requests; the host remounts a fresh consumer.
            projectResult = action; projectPending = false; projectSourceRetired = true
            latestForInspection = latest; phase = .confirmed; issue = "nativeAttribute.reloadProject"
        } catch {
            guard generation == ticket, phase != .retired else { return }
            report(error, phase: .unknown) // Original project recovery stays with its original owner.
        }
    }
}
