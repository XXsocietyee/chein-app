import Foundation
import Observation

@MainActor @Observable public final class ModInstallationController {
    public let identity: ModInstallationIdentity
    public private(set) var compatibility: ModInstallationCompatibility?
    public private(set) var compatibilityReadFailed = false
    public var canReadCompatibility: Bool { service.canReadCompatibility }
    /// Independent read: a failed diagnostic never discards or replays the installation journal.
    public func readCompatibility() async {
        guard !busy, service.canReadCompatibility else { return }
        busy = true; defer { finishOperation() }
        compatibility = nil; compatibilityReadFailed = false
        do { let value = try await service.compatibility(identity: identity); try check(); try value.validate(identity); compatibility = value }
        catch { compatibilityReadFailed = true; if !service.isCurrent { invalidate() } }
    }
    public private(set) var options: ModInstallationOptions?
    public private(set) var selectedMerchantId: Int64?
    public private(set) var selectedAnchorPoiId: Int64?
    public private(set) var selections: [String: Int64] = [:]
    public private(set) var attempt: ModInstallationAttempt?
    public private(set) var history: [ModInstallationReceipt] = []
    public private(set) var preview: ModInstallationPreview?
    public private(set) var facts: ModInstallationFacts?
    public private(set) var busy = false
    public private(set) var messageKey: String?
    public private(set) var storageBlocked = false
    public private(set) var recoveryReady = false
    public private(set) var originalPrepareNotFound = false
    private var recoveryRequested = false
    private let service: any ModInstallationServing
    private let store: ModInstallationPendingStore
    public init(identity: ModInstallationIdentity, service: any ModInstallationServing, store: ModInstallationPendingStore) {
        self.identity = identity; self.service = service; self.store = store
    }
    /// Independent owner receipt recovery. New-install options and active-license gates are not receipt authority.
    /// Reads the existing journal without accepting/clearing a pending command or re-entering any writer.
    public private(set) var originalRecoveryRequestID: String?
    public private(set) var originalRecoverySavedReceipt: ModInstallationReceipt?
    public private(set) var originalRecoveryReceipt: ModInstallationReceipt?
    public private(set) var originalRecoveryHistory: [ModInstallationReceipt] = []
    public private(set) var originalRecoveryRequestUnknown = false
    public private(set) var originalRecoveryStorageUnavailable = false
    public private(set) var originalRecoveryHistoryRead = false
    public private(set) var originalRecoveryHistoryUnknown = false
    private func clearOriginalRecovery() {
        originalRecoveryRequestID = nil; originalRecoverySavedReceipt = nil; originalRecoveryReceipt = nil
        originalRecoveryHistory = []; originalRecoveryRequestUnknown = false; originalRecoveryStorageUnavailable = false
        originalRecoveryHistoryRead = false; originalRecoveryHistoryUnknown = false
    }
    public func recoverOriginalReceipts(includeHistory: Bool = true) async {
        guard !busy, isCurrent else { return }
        busy = true; defer { busy = false }
        clearOriginalRecovery()
        do {
            try check(); try Task.checkCancellation()
            if let saved = try store.load() {
                originalRecoveryRequestID = saved.request.requestId; originalRecoverySavedReceipt = saved.receipt
                let receipt = try await service.request(saved.request.requestId, identity: identity)
                try check(); try Task.checkCancellation(); try saved.validate(receipt: receipt)
                originalRecoveryReceipt = receipt
            }
        } catch {
            guard isCurrent, !Task.isCancelled else { clearOriginalRecovery(); return }
            originalRecoveryRequestUnknown = true
            originalRecoveryStorageUnavailable = error as? ModInstallationIssue == .storageUnavailable
        }
        guard includeHistory else { return }
        // This original owner history read remains useful even if local storage or a single request is unknown.
        // Its rows never stand in for a failed exact-request read, clear a journal or create another request.
        do {
            let rows = try await service.history(identity: identity)
            try check(); try Task.checkCancellation()
            guard Set(rows.map(\.requestId)).count == rows.count else { throw ModInstallationIssue.malformed }
            for receipt in rows { try receipt.validate(identity: identity) }
            originalRecoveryHistory = rows; originalRecoveryHistoryRead = true
        } catch {
            guard isCurrent, !Task.isCancelled else { clearOriginalRecovery(); return }
            originalRecoveryHistoryUnknown = true
        }
    }
    public func readOriginalHistoryReceipt(_ historical: ModInstallationReceipt) async {
        guard !busy, isCurrent, originalRecoveryHistory.contains(historical) else { return }
        busy = true; defer { busy = false }
        originalRecoveryReceipt = nil
        do {
            let receipt = try await service.request(historical.requestId, identity: identity)
            try check(); try Task.checkCancellation(); try receipt.validate(previous: historical)
            originalRecoveryReceipt = receipt
        } catch {
            guard isCurrent, !Task.isCancelled else { clearOriginalRecovery(); return }
            // Keep the history row explicitly historical; absence/failure never becomes an uninstall result.
            originalRecoveryHistoryUnknown = true
        }
    }

    public var isCurrent: Bool { service.isCurrent }
    /// Capture only an actual installed receipt from this live owner controller. The read endpoint
    /// independently checks the original license, native profile and resource/use scope again.
    public func installedTextReader(_ installation: ModInstallationReceipt) -> ModInstalledTextReader? {
        guard isCurrent, !busy, service.canReadInstalledText, installation.identity == identity,
              installation.memberTemplateID != nil, installation.composition == nil,
              receipt == installation || history.contains(installation) || originalRecoveryReceipt == installation else { return nil }
        return ModInstalledTextReader(installation: installation, service: service)
    }
    public func qaEditor() -> ModInstallationQaEditor? {
        guard isCurrent, let receipt, receipt.topicID != nil, !busy else { return nil }
        return ModInstallationQaEditor(installation: receipt, service: service, store: store)
    }
    public func templateEditor(_ installation: ModInstallationReceipt) -> ModInstallationTemplateEditor? {
        guard isCurrent, installation.identity == identity, installation.memberTemplateID != nil, !busy else { return nil }
        return ModInstallationTemplateEditor(installation: installation, service: service, store: store)
    }
    public func venueOperations(_ installation: ModInstallationReceipt) -> ModVenueOperations? {
        guard isCurrent, installation.identity == identity, installation.state == .installed, installation.topicID != nil, !installation.bindings.isEmpty else { return nil }
        return ModVenueOperations(installation: installation, service: service, store: store)
    }
    public var receipt: ModInstallationReceipt? { attempt?.receipt }
    public var canSelect: Bool { service.isCurrent && recoveryReady && !recoveryRequested && !busy && attempt == nil && !storageBlocked }
    /// Mirror the server's existing same-region rule. This is a choice filter, never map authority.
    public func bindingResources(for requirement: ModInstallationRequirement) -> [ModInstallationResource] {
        guard let options, options.requiredBindings.contains(requirement), let selectedMerchantId,
              let anchor = options.resources.first(where: { $0.kind == .poi && $0.id == selectedAnchorPoiId }),
              let region = anchor.region else { return [] }
        return options.resources.filter {
            $0.kind == requirement.kind && $0.merchantId == selectedMerchantId && ($0.region == nil || $0.region?.utf8.elementsEqual(region.utf8) == true)
        }
    }
    public var canPrepare: Bool {
        guard canSelect, service.canMutate, let options, let selectedMerchantId, let selectedAnchorPoiId else { return false }
        return (try? ModInstallationAttempt(options: options, merchantId: selectedMerchantId, anchorPoiId: selectedAnchorPoiId, selections: selections)) != nil
    }
    public var canRetryOriginalPrepare: Bool {
        service.canMutate && !busy && !storageBlocked && originalPrepareNotFound &&
        attempt?.pendingAction == .prepare && attempt?.receipt == nil
    }
    public var canCancel: Bool {
        service.canMutate && !busy && !storageBlocked && attempt?.pendingAction == nil && receipt?.state == .prepared
    }
    public var canConfirm: Bool {
        service.canMutate && recoveryReady && !recoveryRequested && !busy && !storageBlocked && attempt?.pendingAction == nil && receipt?.state == .prepared && preview?.requestId == receipt?.requestId
    }
    public var canStartAnother: Bool {
        service.allowsAdditionalDrafts && service.canMutate && !busy && !storageBlocked && attempt?.pendingAction == nil && attempt?.pendingFacts == nil && receipt?.terminal == true
    }
    public var canConfirmFacts: Bool {
        service.canMutate && !busy && !storageBlocked && attempt?.pendingFacts == nil && facts?.confirmed == false && receipt?.state == .installed
    }
    /// A 404 permits an explicit retry of the exact persisted command, never a replacement UUID.
    public func retryOriginalPrepare() async {
        guard canRetryOriginalPrepare, let original = attempt else { return }
        busy = true; defer { finishOperation() }
        do {
            try check(); recoveryReady = false; originalPrepareNotFound = false
            do {
                let existing = try await service.request(original.request.requestId, identity: identity)
                try accept(existing); messageKey = nil; await refreshPreviewPreservingReceipt(existing)
            } catch ModInstallationIssue.requestNotFound {
                try check()
                guard try store.load() == original else { throw ModInstallationIssue.pendingConflict }
                let result = try await service.prepare(original); try accept(result); messageKey = nil; await refreshPreviewPreservingReceipt(result)
            }
            // A prior 404 left recovery incomplete. Finish the same read barrier before
            // enabling install confirmation; never allocate a replacement request.
            let initial = try await service.options(identity: identity, merchantId: nil); try check()
            try initial.validate(licenseId: identity.licenseId)
            guard initial.identity == identity else { throw ModInstallationIssue.malformed }
            let rows = try await service.history(identity: identity); try check()
            options = initial; history = rows; recoveryReady = true
        } catch { handle(error, fallback: "error.prepareUnknown") }
    }
    public func invalidate() {
        clearOriginalRecovery()
        compatibility = nil; compatibilityReadFailed = false
        recoveryRequested = false; service.invalidate(); options = nil; history = []; attempt = nil; facts = nil; preview = nil; selections = [:]
        selectedMerchantId = nil; selectedAnchorPoiId = nil; recoveryReady = false; originalPrepareNotFound = false
    }
    /// Entry and foreground recovery are read-only. A missing/unknown request never allocates another UUID or POSTs.
    public func recover() async {
        guard !busy else { recoveryRequested = true; recoveryReady = false; return }
        recoveryRequested = false; busy = true; defer { finishOperation() }
        do {
            try check(); compatibility = nil; compatibilityReadFailed = false; recoveryReady = false; originalPrepareNotFound = false
            let previousOptions = options
            let saved = try store.load(); attempt = saved; storageBlocked = false; messageKey = nil
            if let saved {
                let result = try await service.request(saved.request.requestId, identity: identity)
                try accept(result)
                await refreshPreviewPreservingReceipt(result)
                if result.state == .installed { await readFactsPreservingReceipt(result) }
                try check()
            }
            let initial = try await service.options(identity: identity, merchantId: nil); try check()
            try initial.validate(licenseId: identity.licenseId)
            guard initial.identity == identity else { throw ModInstallationIssue.malformed }
            let rows = try await service.history(identity: identity); try check(); history = rows
            // An earlier app/device may have prepared an original request. Recover it instead of creating another.
            if attempt == nil, let original = rows.first(where: { $0.state == .prepared }) {
                let restored = try ModInstallationAttempt(restoring: original)
                try store.begin(restored); attempt = restored
                await refreshPreviewPreservingReceipt(original)
            }
            try check()
            if attempt == nil, let merchantId = selectedMerchantId {
                if let previous = previousOptions,
                   let merchant = previous.merchants.first(where: { $0.id == merchantId }),
                   initial.merchants.contains(merchant) {
                    // Foreground recovery must not replace merchant options with the empty root list.
                    // Keep the previous snapshot until all reads succeed so a retry can compare it.
                    let fresh = try await service.options(identity: identity, merchantId: merchantId); try check()
                    try fresh.validate(licenseId: identity.licenseId, merchantId: merchantId)
                    guard fresh.identity == identity,
                          initial.requiredBindings.sorted(by: { $0.id < $1.id }) == fresh.requiredBindings.sorted(by: { $0.id < $1.id }),
                          previous.requiredBindings.sorted(by: { $0.id < $1.id }) == fresh.requiredBindings.sorted(by: { $0.id < $1.id }) else { throw ModInstallationIssue.malformed }
                    reconcileSelection(previous: previous, fresh: fresh)
                } else {
                    options = initial; selectedMerchantId = nil; selectedAnchorPoiId = nil; selections = [:]
                    messageKey = "bindingsChanged"
                }
            } else { options = initial }
            recoveryReady = true
        } catch { handle(error, fallback: attempt == nil ? "error.bindingsRecovery" : "error.recoveryUnknown") }
    }
    /// Coalesce foreground refreshes arriving during any in-flight action. Only reads
    /// are queued, never the interrupted write; the original receipt/key remains authoritative.
    private func finishOperation() {
        busy = false
        guard recoveryRequested else { return }
        guard service.isCurrent else { recoveryRequested = false; return }
        Task { [weak self] in
            guard let self, self.recoveryRequested else { return }
            await self.recover()
        }
    }
    /// An ID alone cannot preserve consent to a changed resource. Never replace its fingerprint silently.
    private func reconcileSelection(previous: ModInstallationOptions, fresh: ModInstallationOptions) {
        let oldAnchor = selectedAnchorPoiId, oldSelections = selections
        options = fresh
        guard let merchant = previous.merchants.first(where: { $0.id == selectedMerchantId }),
              fresh.merchants.contains(merchant) else {
            selectedMerchantId = nil; selectedAnchorPoiId = nil; selections = [:]; messageKey = "bindingsChanged"; return
        }
        if let id = selectedAnchorPoiId,
           !previous.resources.contains(where: { $0.kind == .poi && $0.id == id && fresh.resources.contains($0) }) {
            selectedAnchorPoiId = nil
        }
        selections = selections.filter { key, id in
            guard let requirement = fresh.requiredBindings.first(where: { $0.id == key }),
                  let original = previous.resources.first(where: { $0.kind == requirement.kind && $0.id == id }) else { return false }
            return bindingResources(for: requirement).contains(original)
        }
        if oldAnchor != selectedAnchorPoiId || oldSelections != selections { messageKey = "bindingsChanged" }
    }
    public func selectMerchant(_ id: Int64?) async {
        guard canSelect else { return }
        selectedMerchantId = nil; selectedAnchorPoiId = nil; selections = [:]
        guard let id else { return }
        let initial = options
        guard initial?.merchants.contains(where: { $0.id == id }) == true else { messageKey = "error.selection"; return }
        busy = true; defer { finishOperation() }
        do {
            let result = try await service.options(identity: identity, merchantId: id); try check()
            guard initial?.requiredBindings.sorted(by: { $0.id < $1.id }) == result.requiredBindings.sorted(by: { $0.id < $1.id }) else { throw ModInstallationIssue.malformed }
            options = result; selectedMerchantId = id; messageKey = nil
        } catch { handle(error, fallback: "error.options") }
    }
    public func selectAnchor(_ id: Int64?) {
        guard canSelect else { return }
        guard id == nil || options?.resources.contains(where: { $0.id == id && $0.kind == .poi && $0.merchantId == selectedMerchantId && $0.region != nil }) == true else { return }
        selectedAnchorPoiId = id
        let previous = selections
        selections = selections.filter { key, resourceId in
            guard let requirement = options?.requiredBindings.first(where: { $0.id == key }) else { return false }
            return bindingResources(for: requirement).contains(where: { $0.id == resourceId })
        }
        if previous != selections { messageKey = "bindingsChanged" }
    }
    public func select(_ id: Int64?, for requirement: ModInstallationRequirement) {
        guard canSelect, options?.requiredBindings.contains(requirement) == true else { return }
        guard id == nil || bindingResources(for: requirement).contains(where: { $0.id == id }) else { return }
        selections[requirement.id] = id
    }
    public func prepare() async {
        guard canPrepare, let options, let selectedMerchantId, let selectedAnchorPoiId else { return }
        busy = true; defer { finishOperation() }
        do {
            try check(); guard try store.load() == nil else { throw ModInstallationIssue.pendingConflict }
            // Selection can outlive the last foreground read. Before allocating a new UUID,
            // prove the complete original history again; a partial/failed page is not absence.
            recoveryReady = false
            let rows = try await service.history(identity: identity); try check(); history = rows
            guard try store.load() == nil else { throw ModInstallationIssue.pendingConflict }
            if let original = rows.first(where: { $0.state == .prepared }) {
                let restored = try ModInstallationAttempt(restoring: original)
                try store.begin(restored); attempt = restored
                await refreshPreviewPreservingReceipt(original)
                recoveryReady = true; messageKey = "originalRecovered"; return
            }
            recoveryReady = true
            let prepared = try ModInstallationAttempt(options: options, merchantId: selectedMerchantId,
                anchorPoiId: selectedAnchorPoiId, selections: selections)
            try store.begin(prepared); attempt = prepared // Persist + exact readback before the first network write.
            let result = try await service.prepare(prepared); try accept(result); messageKey = nil; await refreshPreviewPreservingReceipt(result)
        } catch { handle(error, fallback: "error.prepareUnknown") }
    }
    /// The view passes the exact receipt that the user reviewed; a stale confirmation never dispatches.
    public func confirmInstall(_ confirmed: ModInstallationReceipt) async {
        guard canConfirm, receipt == confirmed else { return }
        busy = true; defer { finishOperation() }
        do {
            try check(); attempt = try store.markDispatch(.install, confirmed: confirmed)
            let result = try await service.install(confirmed); try accept(result); messageKey = nil; await refreshPreviewPreservingReceipt(result)
            if result.state == .installed { await readFactsPreservingReceipt(result) }
            await refreshHistoryAfterMutation()
        } catch { handle(error, fallback: "error.installUnknown") }
    }
    public func cancel(_ confirmed: ModInstallationReceipt) async {
        guard canCancel, receipt == confirmed else { return }
        busy = true; defer { finishOperation() }
        do {
            try check(); attempt = try store.markDispatch(.cancel, confirmed: confirmed)
            let result = try await service.cancel(confirmed); try accept(result); messageKey = nil; await refreshPreviewPreservingReceipt(result)
            await refreshHistoryAfterMutation()
        } catch { handle(error, fallback: "error.cancelUnknown") }
    }
    public func startAnother() async {
        guard canStartAnother, let receipt else { return }
        busy = true; defer { finishOperation() }
        do {
            let verified = try await service.request(receipt.requestId, identity: identity); try accept(verified)
            guard verified.terminal else { throw ModInstallationIssue.pendingConflict }
            recoveryReady = false
            try store.finish(verified); attempt = nil; facts = nil; selections = [:]; selectedMerchantId = nil; selectedAnchorPoiId = nil
            let nextOptions = try await service.options(identity: identity, merchantId: nil); try check()
            let rows = try await service.history(identity: identity); try check()
            options = nextOptions; history = rows
            if let original = rows.first(where: { $0.state == .prepared }) {
                let restored = try ModInstallationAttempt(restoring: original); try store.begin(restored); attempt = restored
                await refreshPreviewPreservingReceipt(original)
            }
            recoveryReady = true; messageKey = nil
        } catch { handle(error, fallback: "error.recoveryUnknown") }
    }
    /// Review or resume one original server history receipt, with no prepare call and no new key.
    public func restore(_ historical: ModInstallationReceipt) async {
        guard !busy, !storageBlocked, service.isCurrent,
              attempt == nil || attempt?.request.requestId == historical.requestId || (receipt?.terminal == true && attempt?.pendingFacts == nil) else { return }
        busy = true; defer { finishOperation() }
        do {
            if let current = receipt, current.requestId != historical.requestId {
                let verified = try await service.request(current.requestId, identity: identity); try accept(verified)
                try store.finish(verified); attempt = nil; facts = nil
            }
            let fresh = try await service.request(historical.requestId, identity: identity); try check()
            try fresh.validate(previous: historical)
            if attempt == nil {
                let restored = try ModInstallationAttempt(restoring: fresh); try store.begin(restored); attempt = restored
            } else { try accept(fresh) }
            await refreshPreviewPreservingReceipt(fresh)
            messageKey = nil
            if fresh.state == .installed { await readFactsPreservingReceipt(fresh) }
        } catch { handle(error, fallback: "error.recoveryUnknown") }
    }
    public func refreshFacts() async {
        guard !busy, let receipt, receipt.state == .installed else { return }
        busy = true; defer { finishOperation() }
        do { try await readFacts(receipt); messageKey = nil }
        catch { facts = nil; handle(error, fallback: "error.factsUnknown") }
    }
    /// Explicit confirmation of the exact title, full rules, resource bindings and current draft hash reviewed on screen.
    public func confirmFacts(_ reviewed: ModInstallationFacts) async {
        guard canConfirmFacts, facts == reviewed, let receipt else { return }
        busy = true; defer { finishOperation() }
        do {
            try check(); attempt = try store.markFacts(reviewed)
            let result = try await service.confirmFacts(reviewed, receipt: receipt); try check()
            try result.validate(receipt: receipt); try result.validateConfirmation(of: reviewed)
            attempt = try store.acceptFacts(result); facts = result; messageKey = nil
        } catch { facts = nil; handle(error, fallback: "error.factsUnknown") }
    }
    private func refreshPreviewPreservingReceipt(_ receipt: ModInstallationReceipt) async {
        guard receipt.state == .prepared else { preview = nil; return }
        do { let result = try await service.preview(receipt); try check(); try result.validate(receipt: receipt); preview = result }
        catch { preview = nil; handle(error, fallback: "error.preview") }
    }
    private func readFactsPreservingReceipt(_ receipt: ModInstallationReceipt) async {
        do { try await readFacts(receipt) }
        catch { facts = nil; handle(error, fallback: "error.factsUnknown") }
    }
    private func readFacts(_ receipt: ModInstallationReceipt) async throws {
        let result = try await service.facts(receipt); try check()
        try result.validate(receipt: receipt)
        attempt = try store.acceptFacts(result); facts = result
    }
    private func refreshHistoryAfterMutation() async {
        do { let result = try await service.history(identity: identity); try check(); history = result }
        catch { handle(error, fallback: "error.history") }
    }
    private func accept(_ value: ModInstallationReceipt) throws {
        try check(); guard let attempt else { throw ModInstallationIssue.pendingConflict }
        try attempt.validate(receipt: value)
        self.attempt = try store.accept(value); originalPrepareNotFound = false
    }
    private func check() throws { guard service.isCurrent else { throw ModInstallationIssue.staleSession } }
    private func handle(_ error: Error, fallback: String) {
        if !service.isCurrent || error as? ModInstallationIssue == .staleSession || error as? ModInstallationIssue == .unauthorized {
            invalidate(); messageKey = "error.session"; return
        }
        if error as? ModInstallationIssue == .readCapacityExceeded {
            recoveryReady = false; messageKey = "error.readCapacity"; return
        }
        if error as? ModInstallationIssue == .storageUnavailable { storageBlocked = true; messageKey = "error.storage"; return }
        if error as? ModInstallationIssue == .pendingConflict { messageKey = "error.pending"; return }
        if error as? ModInstallationIssue == .prepareRejected, let original = attempt, original.receipt == nil {
            do {
                try store.discardRejectedPreflight(requestId: original.request.requestId)
                attempt = nil; facts = nil; selections = [:]; selectedMerchantId = nil; selectedAnchorPoiId = nil
                originalPrepareNotFound = false; recoveryReady = options != nil; messageKey = "error.preflightRejected"
            } catch { storageBlocked = true; messageKey = "error.storage" }
            return
        }
        // A write may have reached the server. Preserve the original request, even for malformed or 404 readback.
        if error as? ModInstallationIssue == .requestNotFound, attempt != nil {
            originalPrepareNotFound = attempt?.pendingAction == .prepare && attempt?.receipt == nil
            messageKey = "error.requestUnknown"; return
        }
        messageKey = fallback
    }
}
