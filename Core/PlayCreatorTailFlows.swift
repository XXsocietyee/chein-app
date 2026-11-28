import Foundation
import Observation

/// WP-02 local intent store. Every write is read back; a mismatch is a storage failure, never a silent drop.
public final class PlayCreatorTailDefaultsStore {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Value.self, from: $0) }
    }
    func save<Value: Codable & Equatable>(_ value: Value, key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        defaults.set(data, forKey: key)
        return load(Value.self, key: key) == value
    }
    func has(key: String) -> Bool { defaults.object(forKey: key) != nil }
}

// MARK: - author content appeal (myproject audit sheet)

/// Port of the myproject audit sheet: `loadAudit`, `saveAuditDraft`, `appealAudit`, `recoverAuditAppeal`.
/// A submitted command is frozen with its request id. Only its own receipt settles it; "not found" is not "not sent".
@MainActor @Observable public final class CreatorAuditAppealFlow {
    public struct Draft: Codable, Equatable {
        public var reason: String
        public var attachments: [String]
        public var pending: Bool
        public var confirmed: Bool
        public var command: CreatorAuditAppealCommand?
    }
    public enum Note: Equatable {
        case pendingOnOpen, legacyUnbound, recordIncomplete, unconfirmed, readFailed, submitted
        case confirmed(appealID: String), networkPending, server(String), storageFailed
    }
    public enum Load: Equatable { case loading, ready(CreatorAuditTimeline), failed(String?) }

    public let target: CreatorAuditTarget
    public private(set) var load: Load = .loading
    public private(set) var draft: Draft
    public private(set) var note: Note?
    public private(set) var canAppeal = false
    /// Raw appeal state from the timeline or, once confirmed, the receipt.
    public private(set) var appealState: String?
    public private(set) var busy = false
    /// Set when a pick was uploaded and failed. Submit stays closed until the author dismisses it.
    public private(set) var imageProblem: CreatorAppealImageProblem?
    public private(set) var uploadingImages = false
    /// `addAuditAttachment`: at most 6 refs. `upload-client` refuses a known file over 10MB.
    public static let maximumImages = 6
    public static let maximumImageBytes = 10 * 1024 * 1024
    @ObservationIgnored private let service: PlayerGapService
    @ObservationIgnored private let store: PlayCreatorTailDefaultsStore
    @ObservationIgnored private let owner: Int
    @ObservationIgnored private let key: String
    @ObservationIgnored private var readSequence = 0
    @ObservationIgnored private var appealSequence = 0

    public init?(service: PlayerGapService, store: PlayCreatorTailDefaultsStore, target: CreatorAuditTarget) {
        guard let owner = service.accountID, owner > 0 else { return nil }
        self.service = service; self.store = store; self.target = target; self.owner = owner
        key = "audit-appeal:\(owner):\(target.bizType):\(target.bizID)"
        let stored = store.load(Draft.self, key: key)
        if store.has(key: key), stored == nil { draft = .init(reason: "", attachments: [], pending: false, confirmed: false, command: nil); note = .storageFailed; return }
        draft = stored ?? .init(reason: "", attachments: [], pending: false, confirmed: false, command: nil)
        if draft.pending { note = .pendingOnOpen }
    }

    /// The appeal entry: offered only when the timeline says `canAppeal` and nothing is pending or confirmed.
    /// A failed image upload keeps this closed so the appeal is not reported sent with an empty new list.
    public var offersAppeal: Bool {
        canAppeal && !draft.pending && !draft.confirmed && !busy && !uploadingImages && imageProblem == nil && note != .storageFailed
    }
    /// Room left under the mini-program cap of 6. Zero hides "添加申诉图片".
    public var imageSlots: Int { max(0, Self.maximumImages - draft.attachments.count) }
    /// A failed upload still allows another pick. It does not reopen submit (`offersAppeal`).
    public var canAddImages: Bool {
        canAppeal && !draft.pending && !draft.confirmed && !busy && !uploadingImages && note != .storageFailed && imageSlots > 0
    }
    public var offersRecovery: Bool { draft.pending && !busy }

    public func loadTimeline() async {
        readSequence += 1; let sequence = readSequence
        load = .loading
        let reply = await service.auditTimeline(target)
        guard sequence == readSequence else { return }
        switch reply {
        case .ok(let data, _) where data.object != nil:
            let timeline = CreatorAuditTimeline(data)
            load = .ready(timeline)
            canAppeal = timeline.canAppeal && !draft.confirmed
            if !draft.confirmed { appealState = timeline.appealState }
        case .refused(_, let message), .ok(_, let message): load = .failed(message); canAppeal = false
        case .retryable(let message): load = .failed(message); canAppeal = false
        case .unauthorized, .unknown: load = .failed(nil); canAppeal = false
        }
    }

    /// `addAuditAttachment`. Uploads in pick order. Any failure stores none of this batch and sets `imageProblem`.
    /// The source launches at most 3 uploads at once and writes `results[index]`; one-at-a-time keeps that order
    /// and still attaches nothing when one file fails (`onDone` only calls back when `failures` is empty).
    public func uploadImages(_ jpegs: [Data], now: @escaping () -> Date = { Date() }) async {
        guard canAddImages, !jpegs.isEmpty else { return }
        guard jpegs.count <= imageSlots else { imageProblem = .unknown; return }
        if jpegs.contains(where: { $0.count > Self.maximumImageBytes }) { imageProblem = .oversize; return }
        if jpegs.contains(where: \.isEmpty) { imageProblem = .unknown; return }
        uploadingImages = true
        let started = now()
        var refs: [String] = []
        for jpeg in jpegs {
            if now().timeIntervalSince(started) > 60 {
                uploadingImages = false
                imageProblem = .unknown
                return
            }
            switch await service.uploadAppealImage(jpeg) {
            case .uploaded(let reference): refs.append(reference)
            case .failed(let problem):
                uploadingImages = false
                imageProblem = problem
                return
            }
        }
        var next = draft.attachments
        next.append(contentsOf: refs)
        if next.count > Self.maximumImages { next = Array(next.prefix(Self.maximumImages)) }
        guard saveAttachments(next) else { uploadingImages = false; return }
        imageProblem = nil
        uploadingImages = false
    }

    /// `removeAuditAttachment`.
    public func removeImage(at index: Int) {
        guard offersAppeal, draft.attachments.indices.contains(index) else { return }
        var refs = draft.attachments
        refs.remove(at: index)
        _ = saveAttachments(refs)
    }

    /// The author has seen the upload error and may appeal with the attachments that did save.
    public func dismissImageProblem() { imageProblem = nil }

    /// A picker failure (not a cancel) is an upload error: do not submit as if the images were attached.
    public func failImagePick() {
        guard canAddImages else { return }
        imageProblem = .unknown
    }

    /// `appealAudit`: freeze the command first, then send it once. A pending command only re-reads its receipt.
    public func submit(reason raw: String) async {
        if draft.pending { await recover(); return }
        guard imageProblem == nil, !uploadingImages else { return }
        guard offersAppeal, CreatorAuditTimeline.reasonValid(raw) else { return }
        let reason = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard save(pending: true, reason: reason), let command = draft.command else { return }
        busy = true
        let reply = await service.submitAuditAppeal(command)
        busy = false
        switch reply {
        case .ok: note = .submitted; await recover()
        case .refused(let code, let message):
            note = message.map(Note.server) ?? .unconfirmed
            // First-response validation is definite; any other code keeps the frozen input.
            if code == 400 { _ = save(pending: false, reason: reason) }
            else if code == 409 { await recover() }
        case .retryable(let message):
            note = .server(message)
        case .unauthorized, .unknown: note = .networkPending
        }
    }

    /// `recoverAuditAppeal`: GET the original receipt with the frozen request id.
    public func recover() async {
        guard let command = draft.command else { note = .legacyUnbound; await loadTimeline(); return }
        guard command.bizType == target.bizType, command.bizID == target.bizID, command.reason == draft.reason, command.valid,
              command.attachments == CreatorAuditAppealCommand(requestID: command.requestID, target: target, reason: draft.reason, attachments: draft.attachments).attachments
        else { note = .recordIncomplete; return }
        appealSequence += 1; let sequence = appealSequence
        busy = true
        let reply = await service.auditAppealReceipt(command)
        busy = false
        guard sequence == appealSequence else { return }
        guard case .ok(let data, _) = reply else { note = reply == .unknown ? .readFailed : .unconfirmed; return }
        guard let found = command.confirmedAppealID(in: data, owner: owner) else { note = .unconfirmed; return }
        draft.pending = false; draft.confirmed = true; canAppeal = false
        note = .confirmed(appealID: found.appealID); appealState = found.appealState
        _ = save(pending: false, reason: draft.reason)
        await loadTimeline()
    }

    /// `saveAuditDraft`: the command survives while pending or confirmed; it is created once and then frozen.
    @discardableResult private func save(pending: Bool, reason: String) -> Bool {
        var next = draft
        next.reason = reason; next.pending = pending
        next.command = pending || next.confirmed
            ? (draft.command ?? CreatorAuditAppealCommand(requestID: CreatorAuditAppealCommand.newRequestID(), target: target, reason: reason, attachments: draft.attachments))
            : nil
        guard store.save(next, key: key) else { note = .storageFailed; return false }
        draft = next
        return true
    }

    @discardableResult private func saveAttachments(_ refs: [String]) -> Bool {
        var next = draft
        next.attachments = refs
        guard store.save(next, key: key) else { note = .storageFailed; return false }
        draft = next
        return true
    }
}

// MARK: - original-run guard appeal (play)

/// Port of `pages/play/utils/guard-appeal.js`. One entry per owner and play session, persisted before any send.
/// After a submit the outcome is read only by the frozen request id; a transport failure never resubmits.
@MainActor @Observable public final class PlayGuardAppealFlow {
    public enum State: String, Codable { case draft = "DRAFT", unknown = "UNKNOWN", found = "FOUND" }
    public struct Eligibility: Codable, Equatable { public let canSubmit: Bool; public let originalRunActive: Bool }
    public struct Result: Codable, Equatable {
        public let appealState: String?
        public let canReverify: Bool
        public let decisionReason: String?
    }
    public enum Note: String, Codable { case canSubmit, readOnly, submitted, unconfirmed, readFailed, originMismatch }
    public struct Entry: Codable, Equatable {
        public let owner: Int
        public let session: String
        public let reference: PlayGuardAppealReference
        public var state: State
        public var reason: String
        public var command: PlayGuardAppealCommand?
        public var eligibility: Eligibility?
        public var result: Result?
        public var note: Note?
        public var serverMessage: String?
    }
    public private(set) var entry: Entry?
    public private(set) var busy = false
    public private(set) var storageFailed = false
    @ObservationIgnored private let service: PlayerGapService
    @ObservationIgnored private let store: PlayCreatorTailDefaultsStore
    @ObservationIgnored private let owner: Int
    @ObservationIgnored private let session: String
    @ObservationIgnored private let key: String
    @ObservationIgnored private let keyFactory: () -> String

    public init?(service: PlayerGapService, store: PlayCreatorTailDefaultsStore, session: String,
                 keyFactory: @escaping () -> String = { UUID().uuidString.lowercased() }) {
        guard let owner = service.accountID, owner > 0, !session.isEmpty else { return nil }
        self.service = service; self.store = store; self.owner = owner; self.session = session; self.keyFactory = keyFactory
        key = "play-guard-appeal:\(owner):\(session)"
        let stored = store.load(Entry.self, key: key)
        if store.has(key: key), stored == nil || stored?.owner != owner || stored?.session != session { storageFailed = true; return }
        entry = stored
    }

    /// A new refusal with an appealable guard reference. An unresolved submitted intent is never discarded.
    public func reference(_ value: PlayGuardAppealReference) {
        guard !storageFailed else { return }
        if let entry, entry.command != nil, entry.state != .found { return }
        save(.init(owner: owner, session: session, reference: value, state: .draft, reason: "", command: nil))
    }

    public var canSubmit: Bool { entry.map { $0.command == nil && $0.eligibility?.canSubmit == true } == true && !busy && !storageFailed }

    public func read() async {
        guard var current = entry, !busy, !storageFailed else { return }
        busy = true; defer { busy = false }
        if let command = current.command {
            let reply = await service.guardAppealReceipt(command)
            guard case .ok(let fact, _) = reply, fact.object != nil else {
                current.state = .unknown; current.note = reply == .unknown ? .readFailed : .unconfirmed
                current.serverMessage = reply.message; save(current); return
            }
            let intent = fact["intent"]
            guard fact["state"].text == "FOUND", intent["requestId"].text == command.requestID, intent["memberId"].text == String(owner),
                  intent["bizId"].text == command.guardLogID, intent["reason"].text == command.reason,
                  intent["evidence"] == .null, intent.object?["evidence"] != nil, intent["attachments"].array?.isEmpty == true,
                  intent["guardReference"]["guardLogId"].text == command.guardLogID,
                  intent["guardReference"]["arrivalRequestId"].text == command.arrivalRequestID else {
                current.state = .unknown; current.note = .unconfirmed; current.serverMessage = nil; save(current); return
            }
            current.state = .found
            current.result = .init(appealState: fact["appealState"].text, canReverify: fact["canReverify"].bool == true,
                                   decisionReason: fact["decisionReason"].text)
            current.note = .submitted; current.serverMessage = fact["decisionReason"].text
        } else {
            let reply = await service.guardAppealReference(current.reference)
            guard case .ok(let fact, _) = reply, fact.object != nil else {
                current.note = .readFailed; current.serverMessage = reply.message; save(current); return
            }
            let origin = fact["guardOrigin"]
            guard ClubEditionEmptyReason.idText(origin["guardLogId"]) == current.reference.guardLogID,
                  ClubEditionEmptyReason.idText(origin["routeSessionId"]) == current.reference.routeSessionID else {
                current.note = .originMismatch; current.serverMessage = nil; save(current); return
            }
            let eligibility = Eligibility(canSubmit: fact["canSubmit"].bool == true, originalRunActive: fact["originalRunActive"].bool == true)
            current.eligibility = eligibility; current.note = eligibility.canSubmit ? .canSubmit : .readOnly; current.serverMessage = nil
        }
        save(current)
    }

    /// Freeze the command (with a new request id), persist it, send once, then read only by that id.
    public func submit(reason raw: String) async {
        guard canSubmit, var current = entry else { return }
        let reason = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty, reason.count <= 500 else { return }
        let command = PlayGuardAppealCommand(guardLogID: current.reference.guardLogID, arrivalRequestID: current.reference.arrivalRequestID,
                                             requestID: keyFactory(), reason: reason)
        current.command = command; current.reason = reason; current.state = .unknown
        guard save(current) else { return }
        busy = true
        _ = await service.submitGuardAppeal(command) // A transport failure does not prove no write.
        busy = false
        await read()
    }

    @discardableResult private func save(_ next: Entry) -> Bool {
        guard store.save(next, key: key) else { storageFailed = true; return false }
        entry = next
        return true
    }
}
