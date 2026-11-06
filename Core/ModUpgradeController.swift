import Foundation
import Observation

@MainActor @Observable public final class ModUpgradeController {
    public let source: ModInstallationIdentity
    public private(set) var sourceTitle: String?
    public private(set) var candidates: [ModUpgradeCandidate] = []
    public private(set) var nextCursor: String?
    public private(set) var selected: ModUpgradeCandidate?
    public private(set) var intent: ModUpgradeIntent?
    public private(set) var busy = false
    public private(set) var messageKey: String?
    private let service: any ModUpgradeServing
    private let store: ModUpgradeIntentStore
    private var seenCursors = Set<String>()
    private let makeInstallation: (ModUpgradeIntent) -> ModInstallationController?
    private let clearRejectedJournal: (ModUpgradeIntent) throws -> Void
    private let verifyUnstagedJournalEmpty: (ModUpgradeIntent) throws -> Void
    private let finishUninstalledJournal: (ModUpgradeIntent, ModInstallationReceipt) throws -> Void
    private let recoverInstallationAttempt: ((ModUpgradeIntent) throws -> ModInstallationAttempt?)?
    private let readOriginalPreview: ((ModUpgradeIntent, ModInstallationReceipt) async throws -> ModInstallationPreview)?
    private let readOriginalFacts: ((ModUpgradeIntent, ModInstallationReceipt) async throws -> ModInstallationFacts)?
    public init(source: ModInstallationIdentity, service: any ModUpgradeServing, store: ModUpgradeIntentStore,
                makeInstallation: @escaping (ModUpgradeIntent) -> ModInstallationController? = { _ in nil },
                clearRejectedJournal: @escaping (ModUpgradeIntent) throws -> Void = { _ in throw ModUpgradeIssue.pendingConflict },
                verifyUnstagedJournalEmpty: @escaping (ModUpgradeIntent) throws -> Void = { _ in throw ModUpgradeIssue.pendingConflict },
                finishUninstalledJournal: @escaping (ModUpgradeIntent, ModInstallationReceipt) throws -> Void = { _, _ in throw ModUpgradeIssue.pendingConflict },
                recoverInstallationAttempt: ((ModUpgradeIntent) throws -> ModInstallationAttempt?)? = nil,
                readOriginalPreview: ((ModUpgradeIntent, ModInstallationReceipt) async throws -> ModInstallationPreview)? = nil,
                readOriginalFacts: ((ModUpgradeIntent, ModInstallationReceipt) async throws -> ModInstallationFacts)? = nil) {
        self.source = source; self.service = service; self.store = store; self.makeInstallation = makeInstallation; self.clearRejectedJournal = clearRejectedJournal; self.verifyUnstagedJournalEmpty = verifyUnstagedJournalEmpty; self.finishUninstalledJournal = finishUninstalledJournal
        self.recoverInstallationAttempt = recoverInstallationAttempt
        self.readOriginalPreview = readOriginalPreview; self.readOriginalFacts = readOriginalFacts
    }
    public private(set) var originalRecoveryIntent: ModUpgradeIntent?
    public private(set) var originalRecoveryReceipt: ModInstallationReceipt?
    public private(set) var originalRecoveryRead = false
    public private(set) var originalRecoveryUnknown = false
    public private(set) var originalRecoveryStorageUnavailable = false
    public private(set) var originalRecoveryPreview: ModInstallationPreview?
    public private(set) var originalRecoveryFacts: ModInstallationFacts?
    public private(set) var originalRecoveryContentUnknown = false
    private func clearOriginalContent() {
        originalRecoveryPreview = nil; originalRecoveryFacts = nil; originalRecoveryContentUnknown = false
    }
    private func clearOriginalRecovery() {
        clearOriginalContent()
        originalRecoveryIntent = nil; originalRecoveryReceipt = nil; originalRecoveryRead = false
        originalRecoveryUnknown = false; originalRecoveryStorageUnavailable = false
    }
    /// Original source→target journal and original upgrade request reader only. No versions/options/stage.
    /// Revoked license/artifact cannot authorize new work, but does not erase the buyer's original receipt.
    public func recoverOriginalReceipt() async {
        guard !busy, isCurrent else { return }
        busy = true; defer { busy = false }
        clearOriginalRecovery()
        do {
            try check()
            guard var saved = try store.load() else { originalRecoveryRead = true; return }
            originalRecoveryIntent = saved
            guard saved.rejectionReason == nil else { originalRecoveryRead = true; return }
            // The local command already exists before provenance binding. Reading it must not depend on
            // a currently active installation grant; only the independent upgrade receipt reader is used.
            var recoveredAttempt: ModInstallationAttempt?
            if saved.installation == nil, let recoverInstallationAttempt {
                recoveredAttempt = try recoverInstallationAttempt(saved)
                try check(); guard try store.load() == saved else { throw ModUpgradeIssue.pendingConflict }
                if let recoveredAttempt {
                    try recoveredAttempt.validate()
                    guard recoveredAttempt.identity == saved.target else { throw ModUpgradeIssue.pendingConflict }
                    saved = try store.bind(recoveredAttempt); originalRecoveryIntent = saved
                }
            }
            let receipt: ModInstallationReceipt
            if saved.installation == nil {
                if recoverInstallationAttempt != nil { originalRecoveryRead = true; return }
                // Crash between original installation-journal write and provenance binding: use the SAME
                // original adapter's intent(for:) recovery. It binds only already-persisted exact bytes; no stage.
                guard let recovery = makeInstallation(saved) else { throw ModUpgradeIssue.unavailable }
                await recovery.recoverOriginalReceipts(includeHistory: false); try check()
                guard let bound = try store.load(), bound.source == saved.source, bound.candidate == saved.candidate,
                      bound.rejectionReason == saved.rejectionReason else { throw ModUpgradeIssue.pendingConflict }
                saved = bound; originalRecoveryIntent = bound
                guard !recovery.originalRecoveryStorageUnavailable else { throw ModUpgradeIssue.storageUnavailable }
                guard !recovery.originalRecoveryRequestUnknown else { throw ModUpgradeIssue.unavailable }
                guard bound.installation != nil else {
                    guard recovery.originalRecoveryRequestID == nil else { throw ModUpgradeIssue.pendingConflict }
                    originalRecoveryRead = true; return
                }
                guard let recovered = recovery.originalRecoveryReceipt else { throw ModUpgradeIssue.unavailable }
                receipt = recovered
            } else {
                receipt = try await service.request(saved); try check()
            }
            guard let command = saved.installation else { throw ModUpgradeIssue.pendingConflict }
            guard try store.load() == saved, let target = saved.target,
                  receipt.requestId == command.requestId, receipt.merchantId == command.merchantId,
                  receipt.anchorPoiId == command.anchorPoiId,
                  receipt.bindings.map(\.binding).sorted(by: { $0.id < $1.id }) == command.bindings.sorted(by: { $0.id < $1.id }) else { throw ModUpgradeIssue.pendingConflict }
            try receipt.validate(identity: target)
            try recoveredAttempt?.validate(receipt: receipt)
            originalRecoveryReceipt = receipt; originalRecoveryRead = true
        } catch {
            guard isCurrent, !Task.isCancelled else { clearOriginalRecovery(); return }
            originalRecoveryUnknown = true
            originalRecoveryStorageUnavailable = error as? ModUpgradeIssue == .storageUnavailable
        }
    }

    /// Explicit original GET only. A content permission failure cannot erase a verified historical receipt.
    /// PREPARED preview is the original bound plan; INSTALLED facts are the current draft, not frozen source.
    public func readOriginalContent() async {
        guard !busy, isCurrent, let saved = originalRecoveryIntent, let receipt = originalRecoveryReceipt,
              saved.installation?.requestId == receipt.requestId,
              receipt.state == .prepared || receipt.state == .installed else { return }
        busy = true; defer { busy = false }
        clearOriginalContent()
        do {
            try check(); guard try store.load() == saved else { throw ModUpgradeIssue.pendingConflict }
            if receipt.state == .prepared {
                guard let readOriginalPreview else { throw ModUpgradeIssue.unavailable }
                let value = try await readOriginalPreview(saved, receipt); try check()
                try value.validate(receipt: receipt)
                guard try store.load() == saved, originalRecoveryReceipt == receipt else { throw ModUpgradeIssue.pendingConflict }
                originalRecoveryPreview = value
            } else {
                guard let readOriginalFacts else { throw ModUpgradeIssue.unavailable }
                let value = try await readOriginalFacts(saved, receipt); try check()
                try value.validate(receipt: receipt)
                guard try store.load() == saved, originalRecoveryReceipt == receipt else { throw ModUpgradeIssue.pendingConflict }
                originalRecoveryFacts = value
            }
        } catch {
            guard isCurrent, !Task.isCancelled else { clearOriginalRecovery(); return }
            clearOriginalContent(); originalRecoveryContentUnknown = true
        }
    }

    public var isCurrent: Bool { service.isCurrent }
    public var rejectionReason: String? {
        _ = service.rejectionReason // Observe stage completion; the durable record owns the scoped reason.
        guard isCurrent, let intent, let saved = try? store.load(), saved.candidate == intent.candidate else { return nil }
        return saved.rejectionReason
    }
    public func makeInstallationController() -> ModInstallationController? {
        guard isCurrent, let intent, (try? store.load()) == intent else { return nil }
        return makeInstallation(intent)
    }
    public var canConfirm: Bool {
        isCurrent && service.canStage && !busy && intent == nil && selected?.authorization == .authorized &&
            selected?.compatibility == .compatible && selected?.termsComparison != nil
    }
    /// Only a fresh original server CANCELLED/FAILED receipt permits another selection. No new request is sent.
    public func finishUninstalledOriginal() async {
        guard isCurrent, !busy, let saved = intent, saved.installation != nil, saved.rejectionReason == nil else { return }
        busy = true; defer { busy = false }
        do {
            try check(); guard try store.load() == saved else { throw ModUpgradeIssue.pendingConflict }
            let verified = try await service.request(saved); try check()
            guard verified.state == .cancelled || verified.state == .failed else { throw ModUpgradeIssue.originalNotFinished }
            try finishUninstalledJournal(saved, verified); try check(); try store.finishUninstalled(saved, verified: verified)
            intent = nil; selected = nil; messageKey = nil
        } catch { handle(error) }
    }
    /// Cancels a local choice only before either journal contains an installation request.
    public func discardUnstaged() {
        guard isCurrent, !busy, let saved = intent, saved.installation == nil else { return }
        do {
            try check(); try verifyUnstagedJournalEmpty(saved); try check(); try store.abandonUnstaged(saved)
            intent = nil; selected = nil; messageKey = nil
        } catch { handle(error) }
    }
    /// A buyer may change a conclusively rejected selection, but never abandon an unknown original command.
    public func discardRejected() {
        guard isCurrent, !busy, let saved = intent, saved.rejectionReason != nil else { return }
        do {
            try check(); try clearRejectedJournal(saved); try check(); try store.abandonRejected(saved)
            intent = nil; selected = nil; messageKey = nil
        } catch { handle(error) }
    }
    public func invalidate() {
        clearOriginalRecovery()
        service.invalidate(); selected = nil; candidates = []; nextCursor = nil; sourceTitle = nil; intent = nil
    }
    /// Entry/foreground/restart is read-only. A persisted choice is recovered, never restaged automatically.
    public func recover(more: Bool = false) async {
        guard !busy, !more || nextCursor != nil else { return }
        busy = true; defer { busy = false }
        do {
            try check()
            intent = try store.load()
            let cursor = more ? nextCursor : nil
            if !more { selected = nil; candidates = []; nextCursor = nil; seenCursors = [] }
            let page = try await service.versions(source: source, before: cursor); try check()
            try page.validate(source: source)
            guard Set(candidates.map(\.offerId)).isDisjoint(with: page.candidates.map(\.offerId)) else { throw ModUpgradeIssue.malformed }
            if let next = page.nextCursor {
                guard !seenCursors.contains(next), next != cursor else { throw ModUpgradeIssue.malformed }
                seenCursors.insert(next)
            }
            candidates += page.candidates; sourceTitle = page.sourceTitle; nextCursor = page.nextCursor; messageKey = nil
        } catch { handle(error) }
    }
    public func select(_ candidate: ModUpgradeCandidate) {
        guard isCurrent, !busy, intent == nil, candidates.contains(candidate) else { return }
        selected = candidate; messageKey = nil
    }
    /// Exact rendered selection must be confirmed, not whatever a late response now happens to contain.
    public func confirm(_ reviewed: ModUpgradeCandidate, confirmedByBuyer: Bool) {
        guard canConfirm, selected == reviewed, confirmedByBuyer else { return }
        do {
            try check()
            let original = try ModUpgradeIntent(source: source, candidate: reviewed, confirmedByBuyer: confirmedByBuyer)
            try store.begin(original); try check(); intent = try store.load(); messageKey = nil
        } catch { handle(error) }
    }
    private func check() throws { guard isCurrent else { throw ModUpgradeIssue.staleSession }; try Task.checkCancellation() }
    private func handle(_ error: Error) {
        if !isCurrent || error as? ModUpgradeIssue == .unauthorized || error as? ModUpgradeIssue == .staleSession {
            invalidate(); messageKey = "error.session"
        } else if error as? ModUpgradeIssue == .originalNotFinished {
            messageKey = "error.originalNotFinished"
        } else if error as? ModUpgradeIssue == .comparisonTooLarge {
            messageKey = "error.comparisonTooLarge"
        } else if error as? ModUpgradeIssue == .storageUnavailable {
            intent = nil; selected = nil; messageKey = "error.storage"
        } else { messageKey = "error.unavailable" }
    }
}
