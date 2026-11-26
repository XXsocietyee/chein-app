import SwiftUI

struct ProfileEditReloadConfirmation: Identifiable {
    let id = UUID()
    fileprivate let identity: ProfileReadIdentity
    fileprivate let viewerRevision: UInt64?
    fileprivate let generation: Int
    fileprivate let modelRevision: Int
    fileprivate let reloadContextRevision: UInt64
    fileprivate let snapshot: ProfileEditSnapshot
    fileprivate let draft: ProfileEditDraft
}

/// A local navigation decision, never permission to save or retry a write.
struct ProfileEditExitConfirmation: Identifiable {
    let id = UUID()
    fileprivate let identity: ProfileReadIdentity
    fileprivate let viewerRevision: UInt64?
    fileprivate let generation: Int
    fileprivate let modelRevision: Int
    fileprivate let contextRevision: UInt64
    fileprivate let snapshot: ProfileEditSnapshot
    fileprivate let draft: ProfileEditDraft
    fileprivate let writeWasLocked: Bool
}

/// One local category-picker session. This carries no permission to read or save.
struct ProfilePreferencePickerEdit: Identifiable {
    let context: ProfileTextFieldEdit
    let reader: (any DiscoveryReading)?
    let readerIdentity: String?
    let readerConfigured: Bool
    let selected: [Int]
    var id: UUID { context.id }
}

@MainActor
final class ProfileEditModel: ObservableObject {
    let coordinator: ProfileEditCoordinator
    @Published var draft = ProfileEditDraft() { didSet { retirePreferencePicker(); retireSavedReturn(); retireTextEdit(); avatarDraftRevision &+= 1; if draft.avatarReplacement == nil { avatarPreview = nil }; retireReload() } }
    @Published var confirmation: ProfileEditConfirmation?
    @Published private(set) var reloadConfirmation: ProfileEditReloadConfirmation?
    @Published private(set) var exitConfirmation: ProfileEditExitConfirmation?
    @Published private(set) var textEdit: ProfileTextFieldEdit?
    @Published private(set) var preferencePicker: ProfilePreferencePickerEdit?
    private struct ReviewedDraft {
        let reviewID: UUID
        let generation: Int
        let modelRevision: Int
        let draftRevision: UInt64
        let draft: ProfileEditDraft
        let identity: ProfileReadIdentity?
        let viewerRevision: UInt64?
    }
    private var reviewedDraft: ReviewedDraft?
    private var savedReturnRevision: UInt64 = 0
    private struct SavedReturnOwner {
        let receipt: ProfileSavedReturn
        let generation: Int
        let revision: UInt64
        let draft: ProfileEditDraft
    }
    private var savedReturnOwner: SavedReturnOwner?
    func retireSavedReturn() { savedReturnRevision &+= 1; savedReturnOwner = nil }
    /// The view invokes its navigation callback only after this synchronous fence.
    func consumeSavedReturn(_ value: ProfileSavedReturn) -> Bool {
        guard let owner = savedReturnOwner, owner.receipt == value else { return false }
        savedReturnOwner = nil
        guard !Task.isCancelled, !exitCommitted, !busy, !coordinator.isBusy,
              owner.generation == generation, owner.revision == savedReturnRevision,
              Self.sameDraft(draft, owner.draft), coordinator.consumeSavedReturn(value) else { return false }
        return true
    }
    private var exitCommitted = false
    @Published private(set) var busy = false
    @Published private(set) var revision = 0
    @Published private(set) var contractShownName: String?
    @Published private(set) var contractPhoneMask: String?
    @Published private(set) var contractIntroduction: String?
    let avatarEditorID = UUID()
    @Published private(set) var avatarLifetimeID = UUID()
    @Published private(set) var avatarPreview: RetainedSelectedImage?
    /// A3-01: local previews of staged 探索作品 / 联系二维码 uploads, keyed by the staged replacement id.
    @Published private(set) var mediaPreviews: [UUID: RetainedSelectedImage] = [:]
    private(set) var avatarDraftRevision: UInt64 = 0
    var avatarPresentationActive = false
    private var avatarActive = true
    private var avatarRetirement: (() -> Void)?
    private var mediaRetirements: [ProfileMediaKind: () -> Void] = [:]
    private var generation = 0
    private var reloadContextRevision: UInt64 = 0
    private var contextIdentity: ProfileReadIdentity?
    private var contextViewerRevision: UInt64?
    init(coordinator: ProfileEditCoordinator) {
        self.coordinator = coordinator
        contextIdentity = coordinator.identity; contextViewerRevision = coordinator.viewerRevision
    }
    /// Compare the typed bytes, including whitespace and Unicode normalization.
    private static func sameDraft(_ lhs: ProfileEditDraft, _ rhs: ProfileEditDraft) -> Bool {
        lhs.name.utf8.elementsEqual(rhs.name.utf8) && lhs.introduction.utf8.elementsEqual(rhs.introduction.utf8)
        && lhs.routePreferenceIDs == rhs.routePreferenceIDs && lhs.avatarReplacement == rhs.avatarReplacement
        && ProfileCasePortfolio.sameText(lhs.caseIntroduction, rhs.caseIntroduction)
        && lhs.removesContactQR == rhs.removesContactQR
        && lhs.removesCasePictures == rhs.removesCasePictures && lhs.casePictureSubset == rhs.casePictureSubset
        && lhs.addedCasePictures == rhs.addedCasePictures && lhs.contactQRReplacement == rhs.contactQRReplacement
    }
    private static func sameSnapshot(_ lhs: ProfileEditSnapshot, _ rhs: ProfileEditSnapshot) -> Bool {
        lhs.id == rhs.id && ProfileCasePortfolio.sameText(lhs.caseIntroduction, rhs.caseIntroduction) && zip([lhs.nickname, lhs.introduction, lhs.avatar, lhs.wechat, lhs.casePics, lhs.tagIds],
                              [rhs.nickname, rhs.introduction, rhs.avatar, rhs.wechat, rhs.casePics, rhs.tagIds])
            .allSatisfy { $0.0.utf8.elementsEqual($0.1.utf8) }
    }
    /// Row text is the committed profile. An unchanged draft shows the loaded shown name
    /// (non-blank name, otherwise nickname). A local sheet confirm replaces that row.
    var displayedName: String {
        let loaded = coordinator.snapshot?.nickname ?? ""
        if !draft.name.utf8.elementsEqual(loaded.utf8) { return draft.name }
        let shown = contractShownName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return shown.isEmpty ? draft.name : shown
    }
    var displayedIntroduction: String {
        let loaded = coordinator.snapshot?.introduction ?? ""
        if !draft.introduction.utf8.elementsEqual(loaded.utf8) { return draft.introduction }
        return contractIntroduction ?? draft.introduction
    }
    private var hasUnsavedDraft: Bool {
        guard let snapshot = coordinator.snapshot else { return false }
        let sameText = draft.name.utf8.elementsEqual(snapshot.nickname.utf8)
            && draft.introduction.utf8.elementsEqual(snapshot.introduction.utf8)
        let samePreferences = draft.routePreferenceIDs.map { $0.map(String.init).joined(separator: ",").utf8.elementsEqual(snapshot.tagIds.utf8) } ?? true
        return !sameText || !samePreferences || draft.avatarReplacement != nil
            || !draft.addedCasePictures.isEmpty || draft.contactQRReplacement != nil
            || (draft.caseIntroduction.map { !ProfileCasePortfolio.sameText($0, snapshot.caseIntroduction) } ?? false)
            || (draft.removesContactQR && !snapshot.wechat.isEmpty)
            || (draft.removesCasePictures && ProfileCasePortfolio(casePics: snapshot.casePics).imageCount > 0)
            || draft.casePictureSubset?.hasChanges == true
    }
    /// Saved-image access only. Existing draft/save/clear logic remains unchanged.
    var savedAvatarReadSnapshot: ProfileEditSnapshot? {
        guard canBeginTextEdit else { return nil }
        return coordinator.currentAvatarReadSnapshot
    }
    func currentMediaReadSnapshot(for value: ProfileTextFieldEdit) -> ProfileEditSnapshot? {
        guard textEdit?.id == value.id, value.field == .casePictures || value.field == .contactQR,
              avatarActive, !exitCommitted, !busy, !coordinator.isBusy, !coordinator.isLocked,
              confirmation == nil, coordinator.confirmation == nil, reloadConfirmation == nil,
              exitConfirmation == nil, !avatarPresentationActive, preferencePicker == nil,
              coordinator.identity == value.identity, coordinator.viewerRevision == value.viewerRevision,
              generation == value.generation, revision == value.modelRevision,
              avatarDraftRevision == value.draftRevision, Self.sameDraft(draft, value.draft),
              let snapshot = coordinator.currentAvatarReadSnapshot,
              ProfileSavedMediaExact.snapshot(snapshot) == ProfileSavedMediaExact.snapshot(value.snapshot) else { return nil }
        return snapshot
    }
    /// This is local scratch editing, never an independent server save.
    var canBeginTextEdit: Bool {
        avatarActive && !exitCommitted && !busy && !coordinator.isBusy && !coordinator.isLocked
            && coordinator.isConfigured && coordinator.snapshot != nil
            && confirmation == nil && coordinator.confirmation == nil
            && reloadConfirmation == nil && exitConfirmation == nil
            && textEdit == nil && preferencePicker == nil && !avatarPresentationActive
    }
    func beginPreferencePicker(reader: (any DiscoveryReading)?) {
        guard avatarActive, !exitCommitted else { return }
        synchronizeContext()
        guard canBeginTextEdit, let identity = coordinator.identity,
              let snapshot = coordinator.snapshot, snapshot.id == identity.accountID else { return }
        let context = ProfileTextFieldEdit(field: .preferences, identity: identity,
            viewerRevision: coordinator.viewerRevision, generation: generation, modelRevision: revision,
            draftRevision: avatarDraftRevision, snapshot: snapshot, draft: draft)
        guard let selected = ProfilePreferenceRemoval.selection(draft: draft, snapshot: snapshot) else { return }
        preferencePicker = .init(context: context, reader: reader,
            readerIdentity: reader?.discoveryPresentationIdentity, readerConfigured: reader?.isConfigured == true,
            selected: selected)
    }
    func retirePreferencePicker() { preferencePicker = nil }
    func cancelPreferencePicker(_ value: ProfilePreferencePickerEdit) {
        guard preferencePicker?.id == value.id else { return }
        retirePreferencePicker()
    }
    private func ownsPreferencePicker(_ value: ProfilePreferencePickerEdit) -> Bool {
        let context = value.context
        guard preferencePicker?.id == value.id, avatarActive, !exitCommitted, !busy,
              !coordinator.isBusy, !coordinator.isLocked, coordinator.isConfigured,
              textEdit == nil, confirmation == nil, coordinator.confirmation == nil,
              reloadConfirmation == nil, exitConfirmation == nil, !avatarPresentationActive,
              coordinator.identity == context.identity, coordinator.viewerRevision == context.viewerRevision,
              generation == context.generation, revision == context.modelRevision,
              avatarDraftRevision == context.draftRevision, Self.sameDraft(draft, context.draft),
              let snapshot = coordinator.snapshot, Self.sameSnapshot(snapshot, context.snapshot),
              (value.reader?.isConfigured == true) == value.readerConfigured,
              ProfileCasePortfolio.sameText(value.reader?.discoveryPresentationIdentity, value.readerIdentity) else { return false }
        return true
    }
    /// Shared picker reads and Done both consult this live, captured owner gate.
    func preferencePickerIdentity(_ value: ProfilePreferencePickerEdit) -> ProfileReadIdentity? {
        guard ownsPreferencePicker(value) else { cancelPreferencePicker(value); return nil }
        return value.context.identity
    }
    func preferencePickerPresentation(for value: ProfilePreferencePickerEdit?) -> Binding<ProfilePreferencePickerEdit?> {
        Binding(get: {
            guard let value, self.ownsPreferencePicker(value) else { return nil }
            return self.preferencePicker
        }, set: { next in
            if next == nil, let value { self.cancelPreferencePicker(value) }
        })
    }
    @discardableResult func confirmPreferencePicker(_ value: ProfilePreferencePickerEdit, selectedIDs: [Int]) -> Bool {
        guard ownsPreferencePicker(value), value.readerConfigured,
              ProfilePreferenceRemoval.validIDs(selectedIDs) else { cancelPreferencePicker(value); return false }
        // Consume synchronously before handing the existing picker result to the local draft.
        retirePreferencePicker()
        draft.routePreferenceIDs = selectedIDs
        return true
    }
    func beginTextEdit(_ field: ProfileTextField) {
        guard !exitCommitted else { return }
        synchronizeContext()
        guard canBeginTextEdit, let identity = coordinator.identity,
              let snapshot = coordinator.snapshot else { return }
        textEdit = .init(field: field, identity: identity, viewerRevision: coordinator.viewerRevision,
            generation: generation, modelRevision: revision, draftRevision: avatarDraftRevision,
            snapshot: snapshot, draft: draft)
    }
    func cancelTextEdit(_ value: ProfileTextFieldEdit) {
        guard textEdit?.id == value.id else { return }
        retireTextEdit()
    }
    private func retireTextEdit() { textEdit = nil }
    /// A previously retained sheet binding cannot observe or dismiss a later editor.
    func textEditPresentation(for presented: ProfileTextFieldEdit?) -> Binding<ProfileTextFieldEdit?> {
        return .init(get: {
            guard let presented, self.textEdit?.id == presented.id else { return nil }
            return self.textEdit
        }, set: { value in
            if value == nil, let presented { self.cancelTextEdit(presented) }
        })
    }
    @discardableResult func confirmTextEdit(_ value: ProfileTextFieldEdit, text: String) -> Bool {
        guard textEdit?.id == value.id else { return false }
        guard avatarActive, !exitCommitted, !busy, !coordinator.isBusy, !coordinator.isLocked,
              confirmation == nil, coordinator.confirmation == nil,
              reloadConfirmation == nil, exitConfirmation == nil, !avatarPresentationActive,
              coordinator.identity == value.identity, coordinator.viewerRevision == value.viewerRevision,
              generation == value.generation, revision == value.modelRevision,
              avatarDraftRevision == value.draftRevision, Self.sameDraft(draft, value.draft),
              let snapshot = coordinator.snapshot, Self.sameSnapshot(snapshot, value.snapshot) else {
            cancelTextEdit(value); return false
        }
        // Consume before assigning: a repeated or late action cannot touch a newer field.
        retireTextEdit()
        var next = draft
        switch value.field {
        case .name: next.name = text
        case .introduction: next.introduction = text
        case .caseIntroduction:
            guard snapshot.caseIntroduction != nil else { return false }
            next.caseIntroduction = ProfileCasePortfolio.sameText(text, snapshot.caseIntroduction) ? nil : text
        case .contactQR:
            // A QR editor may retain original bytes or clear them, never supply a replacement URL.
            guard text.isEmpty || text.utf8.elementsEqual(snapshot.wechat.utf8) else { return false }
            next.removesContactQR = text.isEmpty && !snapshot.wechat.isEmpty
        case .casePictures:
            guard text.isEmpty || text.utf8.elementsEqual(snapshot.casePics.utf8) else { return false }
            next.removesCasePictures = text.isEmpty && ProfileCasePortfolio(casePics: snapshot.casePics).imageCount > 0
            next.casePictureSubset = nil
        case .preferences:
            guard let original = ProfilePreferenceRemoval.selection(draft: draft, snapshot: snapshot),
                  let selected = ProfilePreferenceRemoval.parse(text),
                  ProfilePreferenceRemoval.isOrderedSubset(selected, of: original) else { return false }
            // No-op confirmation must keep nil/raw preservation and existing staged edits.
            if selected != original { next.routePreferenceIDs = selected }
        }
        draft = next
        return true
    }
    @discardableResult func confirmContactQR(_ value: ProfileTextFieldEdit, remove: Bool) -> Bool {
        guard value.field == .contactQR else { return false }
        return confirmTextEdit(value, text: remove ? "" : value.snapshot.wechat)
    }
    @discardableResult func confirmPreferenceRemoval(_ value: ProfileTextFieldEdit, selectedIDs: [Int]) -> Bool {
        guard value.field == .preferences,
              ProfilePreferenceRemoval.validIDs(selectedIDs) else { return false }
        return confirmTextEdit(value, text: selectedIDs.map(String.init).joined(separator: ","))
    }
    @discardableResult func confirmCasePictureRemoval(_ value: ProfileTextFieldEdit, remove: Bool) -> Bool {
        guard value.field == .casePictures else { return false }
        return confirmTextEdit(value, text: remove ? "" : value.snapshot.casePics)
    }
    @discardableResult func confirmCasePictureSubset(_ value: ProfileTextFieldEdit, retainedIndices: [Int]) -> Bool {
        guard value.field == .casePictures,
              let subset = try? ProfileCasePictureSubset(source: value.snapshot.casePics, retainedIndices: retainedIndices) else { return false }
        if retainedIndices.isEmpty, subset.originalCount > 0 {
            return confirmCasePictureRemoval(value, remove: true)
        }
        // Reuse the entire one-use field/source/draft/session fence before staging.
        guard confirmTextEdit(value, text: value.snapshot.casePics) else { return false }
        var next = draft; next.casePictureSubset = subset.hasChanges ? subset : nil
        draft = next
        return true
    }
    func ownsAvatarScope(_ scope: ProfileAvatarScope) -> Bool {
        avatarActive && scope.editorID == avatarEditorID && scope.lifetimeID == avatarLifetimeID &&
            coordinator.identity == scope.identity && coordinator.viewerRevision == scope.viewerRevision
    }
    func avatarTarget(source: ProfileAvatarUploadClient) -> ProfileAvatarTarget? {
        guard avatarActive, !busy, confirmation == nil, reloadConfirmation == nil, exitConfirmation == nil, textEdit == nil, draft.avatarReplacement == nil,
              let snapshot = coordinator.snapshot,
              let scope = coordinator.avatarScope(source: source, editorID: avatarEditorID, lifetimeID: avatarLifetimeID) else { return nil }
        return try? .init(scope: scope, snapshot: snapshot, draft: draft, draftRevision: avatarDraftRevision)
    }
    func stageAvatar(_ replacement: ProfileAvatarReplacement, preview: RetainedSelectedImage?) {
        // Flow checked this exact owner, snapshot, draft and revision immediately before calling.
        draft = draft.stagingAvatar(replacement); avatarPreview = preview
    }
    func discardAvatar(id: UUID) {
        guard !busy, !coordinator.isLocked, draft.avatarReplacement?.id == id else { return }
        draft = .init(name: draft.name, introduction: draft.introduction, routePreferenceIDs: draft.routePreferenceIDs, caseIntroduction: draft.caseIntroduction, removesContactQR: draft.removesContactQR, removesCasePictures: draft.removesCasePictures, casePictureSubset: draft.casePictureSubset).carryingUploads(of: draft)
    }
    /// A3-01: a 探索作品 / 联系二维码 upload target. Unlike the avatar, a staged avatar does not block it;
    /// 探索作品 stops at the mini-program's 9 pictures, 联系二维码 takes one staged replacement.
    func mediaTarget(source: ProfileAvatarUploadClient, kind: ProfileMediaKind) -> ProfileAvatarTarget? {
        guard kind != .avatar else { return avatarTarget(source: source) }
        guard avatarActive, !busy, confirmation == nil, reloadConfirmation == nil, exitConfirmation == nil, textEdit == nil,
              let snapshot = coordinator.snapshot,
              kind != .casePicture || draft.casePictureCount(keeping: snapshot) < ProfileMediaKind.casePictureLimit,
              kind != .contactQR || draft.contactQRReplacement == nil,
              let scope = coordinator.avatarScope(source: source, editorID: avatarEditorID, lifetimeID: avatarLifetimeID) else { return nil }
        return try? .init(mediaScope: scope, snapshot: snapshot, draft: draft, draftRevision: avatarDraftRevision)
    }
    func stageMedia(_ replacement: ProfileAvatarReplacement, kind: ProfileMediaKind, preview: RetainedSelectedImage?) {
        // Flow checked this exact owner, snapshot, draft and revision immediately before calling.
        switch kind {
        case .avatar: stageAvatar(replacement, preview: preview); return
        case .casePicture: draft = draft.stagingCasePicture(replacement)
        case .contactQR: draft = draft.stagingContactQR(replacement)
        }
        pruneMediaPreviews()
        if let preview { mediaPreviews[replacement.id] = preview }
    }
    func discardMedia(id: UUID) {
        guard !busy, !coordinator.isLocked else { return }
        if draft.contactQRReplacement?.id == id { draft = draft.removingContactQRReplacement() }
        else if draft.addedCasePictures.contains(where: { $0.id == id }) { draft = draft.removingAddedCasePicture(id: id) }
        pruneMediaPreviews()
    }
    private func pruneMediaPreviews() {
        let live = Set((draft.addedCasePictures + [draft.contactQRReplacement].compactMap { $0 }).map(\.id))
        if mediaPreviews.keys.contains(where: { !live.contains($0) }) { mediaPreviews = mediaPreviews.filter { live.contains($0.key) } }
    }
    func observeAvatarRetirement(_ action: @escaping () -> Void) { avatarRetirement = action }
    func observeMediaRetirement(_ kind: ProfileMediaKind, _ action: @escaping () -> Void) { mediaRetirements[kind] = action }
    func retireAvatar() {
        if avatarActive { suspendForBackground() } else { retireTextEdit(); retireAvatarResources() }
    }
    /// App suspension is not an explicit cancellation of same-owner text scratch.
    /// Removal/media editors retain the stricter retirement behavior.
    func suspendForBackground() {
        let retainsText: Bool
        if let edit = textEdit, [.name, .introduction, .caseIntroduction].contains(edit.field),
           edit.identity == coordinator.identity, edit.viewerRevision == coordinator.viewerRevision,
           edit.generation == generation, edit.modelRevision == revision,
           edit.draftRevision == avatarDraftRevision, Self.sameDraft(edit.draft, draft),
           let snapshot = coordinator.snapshot, Self.sameSnapshot(edit.snapshot, snapshot) {
            retainsText = true
        } else { retainsText = false }
        if !retainsText { retireTextEdit() }
        // The existing confirmTextEdit avatarActive guard denies late Apply while suspended.
        retireAvatarResources()
    }
    private func retireAvatarResources() { retirePreferencePicker(); retireSavedReturn(); cancelExit(); reviewedDraft = nil; avatarActive = false; avatarLifetimeID = UUID(); avatarPreview = nil; avatarRetirement?(); mediaPreviews = [:]; mediaRetirements.values.forEach { $0() } }
    func activateAvatar() { avatarActive = true }
    private func avatarSaveValidity(for captured: ProfileEditDraft) -> ProfileAvatarSaveValidity? {
        let uploads = captured.stagedUploads
        guard !uploads.isEmpty else { return nil }
        let revision = avatarDraftRevision, fingerprint = ProfileAvatarExact.draft(captured)
        return ProfileAvatarSaveValidity { [weak self] in
            guard let self else { return false }
            return uploads.allSatisfy({ self.ownsAvatarScope($0.receipt.target.scope) }) && self.avatarDraftRevision == revision &&
                ProfileAvatarExact.draft(self.draft) == fingerprint
        }
    }
    /// Disable unreviewed modal dismissal while local changes or an operation exist.
    /// The explicit Back action remains available after an unknown save has settled.
    var blocksInteractiveExit: Bool { !exitCommitted && (hasUnsavedDraft || textEdit != nil || busy || coordinator.isBusy) }
    var canRequestExit: Bool {
        !exitCommitted && !busy && !coordinator.isBusy && confirmation == nil
            && coordinator.confirmation == nil && reloadConfirmation == nil && textEdit == nil && !avatarPresentationActive
    }
    func cancelExit() { exitConfirmation = nil }
    /// True means the caller may dismiss now; false either presents a review or blocks
    /// a competing operation. Nothing in this path dispatches a read or a write.
    @discardableResult func requestExit() -> Bool {
        synchronizeContext()
        guard canRequestExit else { return false }
        cancelExit()
        guard hasUnsavedDraft else { return commitExit() }
        guard let identity = coordinator.identity, let snapshot = coordinator.snapshot else { return false }
        exitConfirmation = .init(identity: identity, viewerRevision: coordinator.viewerRevision,
            generation: generation, modelRevision: revision, contextRevision: reloadContextRevision,
            snapshot: snapshot, draft: draft, writeWasLocked: coordinator.isLocked)
        return false
    }
    private func canExit(_ value: ProfileEditExitConfirmation) -> Bool {
        guard canRequestExit, coordinator.identity == value.identity,
              coordinator.viewerRevision == value.viewerRevision, generation == value.generation,
              revision == value.modelRevision, reloadContextRevision == value.contextRevision,
              coordinator.isLocked == value.writeWasLocked,
              Self.sameDraft(draft, value.draft), let snapshot = coordinator.snapshot else { return false }
        return Self.sameSnapshot(snapshot, value.snapshot)
    }
    /// Validate and consume synchronously, so a stale or repeated dialog action cannot
    /// navigate a newer editor. The coordinator's pending-write lock is never cleared.
    @discardableResult func confirmExit(_ value: ProfileEditExitConfirmation) -> Bool {
        guard exitConfirmation?.id == value.id else { return false }
        guard canExit(value) else { cancelExit(); return false }
        return commitExit()
    }
    private func commitExit() -> Bool {
        guard !exitCommitted else { return false }
        exitCommitted = true
        retireReload(); retireAvatar()
        coordinator.leaveScreen()
        draft = .init()
        return true
    }
    func cancelReload() { reloadConfirmation = nil }
    func retireReload() { reloadContextRevision &+= 1; cancelReload(); cancelExit() }
    func requestReload() async {
        retireSavedReturn()
        guard !exitCommitted else { return }
        guard textEdit == nil else { return }
        synchronizeContext()
        guard !busy, !coordinator.isBusy, confirmation == nil, coordinator.confirmation == nil else { return }
        retireReload()
        // A locked write uses the original read-only reconciliation path unchanged.
        guard !coordinator.isLocked, hasUnsavedDraft else { await load(); return }
        guard let identity = coordinator.identity, let snapshot = coordinator.snapshot,
              coordinator.isConfigured else { return }
        reloadConfirmation = .init(identity: identity, viewerRevision: coordinator.viewerRevision,
            generation: generation, modelRevision: revision, reloadContextRevision: reloadContextRevision,
            snapshot: snapshot, draft: draft)
    }
    private func canReload(_ value: ProfileEditReloadConfirmation) -> Bool {
        guard !busy, !coordinator.isBusy, !coordinator.isLocked, coordinator.isConfigured,
              confirmation == nil, coordinator.confirmation == nil,
              coordinator.identity == value.identity, coordinator.viewerRevision == value.viewerRevision,
              generation == value.generation, revision == value.modelRevision,
              reloadContextRevision == value.reloadContextRevision,
              Self.sameDraft(draft, value.draft), let snapshot = coordinator.snapshot else { return false }
        return Self.sameSnapshot(snapshot, value.snapshot)
    }
    /// Consume the dialog synchronously before SwiftUI dismisses it; recheck again
    /// when the task starts so a queued action cannot reload another context.
    @discardableResult func confirmReload(_ value: ProfileEditReloadConfirmation) -> Task<Void, Never>? {
        guard reloadConfirmation?.id == value.id else { return nil }
        guard canReload(value) else { cancelReload(); return nil }
        reloadConfirmation = nil
        return Task { [weak self] in
            guard let self, !Task.isCancelled, self.canReload(value) else { return }
            await self.load()
        }
    }
    private func synchronizeContext() {
        guard contextIdentity != coordinator.identity || contextViewerRevision != coordinator.viewerRevision else { return }
        retireTextEdit()
        retireReload(); retireAvatar(); activateAvatar()
        generation += 1; draft = .init(); confirmation = nil; busy = false
        contextIdentity = coordinator.identity; contextViewerRevision = coordinator.viewerRevision
        coordinator.synchronizeSession()
    }
    func resetAndLoad() async {
        // A committed exit ends this model's lifetime. Only a new navigation
        // destination/model may reopen; a delayed or cancelled .task may not.
        guard !exitCommitted, !Task.isCancelled else { return }
        retireTextEdit()
        retireReload(); retireAvatar(); activateAvatar()
        generation += 1; draft = .init(); confirmation = nil; busy = false
        coordinator.synchronizeSession()
        await load()
    }
    func load() async {
        retireSavedReturn()
        guard !exitCommitted else { return }
        guard textEdit == nil else { return }
        retireReload()
        synchronizeContext()
        guard !busy else { return }
        let identity = coordinator.identity, viewerRevision = coordinator.viewerRevision
        let request = generation; busy = true
        let loaded = await coordinator.load()
        guard request == generation else { return }
        guard retainContext(identity: identity, viewerRevision: viewerRevision) else { return }
        // Failed refresh keeps all unsaved fields, including route preferences.
        if loaded, let snapshot = coordinator.snapshot { draft = snapshot.draft }
        if loaded, let editor = await AccountPublishContractLane.profileEditor() {
            guard request == generation, retainContext(identity: identity, viewerRevision: viewerRevision) else { return }
            contractShownName = editor.shownName
            contractPhoneMask = editor.phoneMasked
            contractIntroduction = editor.introduction
        }
        busy = false; revision += 1
    }
    // Retain drafts only within the exact viewer context, including role/token ABA fences.
    private func retainContext(identity: ProfileReadIdentity?, viewerRevision: UInt64?) -> Bool {
        guard coordinator.identity == identity, coordinator.viewerRevision == viewerRevision else {
            synchronizeContext(); revision += 1
            return false
        }
        return true
    }
    func prepare() async {
        retireSavedReturn()
        guard !exitCommitted else { return }
        guard textEdit == nil else { return }
        retireReload()
        synchronizeContext()
        let identity = coordinator.identity, viewerRevision = coordinator.viewerRevision
        let request = generation; busy = true
        let captured = draft, capturedRevision = avatarDraftRevision
        reviewedDraft = nil
        await coordinator.prepare(draft, avatarValidity: avatarSaveValidity(for: draft))
        guard request == generation else { return }
        guard retainContext(identity: identity, viewerRevision: viewerRevision) else { return }
        confirmation = coordinator.confirmation; busy = false; revision += 1
        if coordinator.messageKey == "profile.edit.changed", let snapshot = coordinator.snapshot { draft = snapshot.draft }
        if let value = confirmation, avatarDraftRevision == capturedRevision, Self.sameDraft(draft, captured) {
            reviewedDraft = .init(reviewID: value.id, generation: generation, modelRevision: revision,
                draftRevision: capturedRevision, draft: captured, identity: identity, viewerRevision: viewerRevision)
        }
    }
    func canRestoreReviewedDraft(_ value: ProfileEditConfirmation) -> Bool {
        guard !exitCommitted, !busy, !coordinator.isBusy, !coordinator.isLocked,
              textEdit == nil, !avatarPresentationActive, reloadConfirmation == nil, exitConfirmation == nil,
              confirmation == value, coordinator.confirmation == value,
              let captured = reviewedDraft, captured.reviewID == value.id,
              captured.generation == generation, captured.modelRevision == revision,
              captured.draftRevision == avatarDraftRevision, Self.sameDraft(draft, captured.draft),
              captured.identity == coordinator.identity, captured.viewerRevision == coordinator.viewerRevision else { return false }
        return true
    }
    /// Restore every field atomically from the latest reviewed self read and remain here.
    @discardableResult func restoreReviewedDraft(_ value: ProfileEditConfirmation) -> Bool {
        guard canRestoreReviewedDraft(value), let snapshot = coordinator.discardReviewedDraft(value) else { return false }
        reviewedDraft = nil; confirmation = nil
        retireReload(); retireAvatar(); activateAvatar()
        draft = snapshot.draft; revision += 1
        return true
    }
    @discardableResult func save(_ value: ProfileEditConfirmation) async -> ProfileSavedReturn? {
        let returnsReviewedDraft = canRestoreReviewedDraft(value)
        retireSavedReturn()
        guard !exitCommitted else { return nil }
        guard textEdit == nil else { return nil }
        retireReload()
        synchronizeContext()
        let identity = coordinator.identity, viewerRevision = coordinator.viewerRevision
        let request = generation, returnRevision = savedReturnRevision
        let capturedDraft = draft, capturedDraftRevision = avatarDraftRevision
        reviewedDraft = nil; confirmation = nil; busy = true
        let receipt = await coordinator.save(value)
        guard request == generation else { return nil }
        guard retainContext(identity: identity, viewerRevision: viewerRevision) else { return nil }
        let mayReturn = returnsReviewedDraft && !Task.isCancelled && !exitCommitted && returnRevision == savedReturnRevision
            && capturedDraftRevision == avatarDraftRevision && Self.sameDraft(draft, capturedDraft)
        if coordinator.messageKey == "profile.edit.saved" || coordinator.messageKey == "profile.edit.changed",
           let snapshot = coordinator.snapshot { draft = snapshot.draft }
        busy = false; revision += 1
        if coordinator.messageKey == "profile.edit.nicknameTaken" || coordinator.messageKey == "profile.edit.nicknameInvalid" {
            reopenNicknameAfterRejection()
        }
        guard mayReturn, let receipt else { return nil }
        savedReturnOwner = .init(receipt: receipt, generation: generation,
            revision: savedReturnRevision, draft: draft)
        return receipt
    }
    /// A3-07: a save the server refused for the nickname reopens the nickname sheet (its live check then
    /// shows 已被占用 and the suggestions), once the review sheet has finished leaving.
    private func reopenNicknameAfterRejection() {
        let request = generation, current = revision
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard let self, self.generation == request, self.revision == current, self.textEdit == nil, self.confirmation == nil else { return }
            self.beginTextEdit(.name)
        }
    }
}

/// Parent passes its live session revision and retains the coordinator outside navigation.
struct ProfileEditView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ProfileEditModel
    @StateObject private var currentReviewNotice: ProfileCurrentReviewNoticeOwner
    let nicknameReader: (any ProfileNicknameAvailabilityReading)?
    let currentReviewReader: ProfileCurrentReviewReader?
    let sessionRevision: UInt64
    let categoryReader: (any DiscoveryReading)?
    let avatarDependencies: ProfileAvatarDependencies?
    let caseImageReader: (any RetainedPublicImageReading)?
    let savedMedia: ProfileSavedMediaReaders?
    private let onSaved: (() -> Void)?
    /// MP `gerenziliao?field=introduction|category` (A3-08): opens that editor once after the first load.
    private let initialField: String?
    @State private var openedInitialField = false
    @State private var showReloadConfirmation = false
    @State private var showExitConfirmation = false
    /// A3-11-r7: MP 正在保存资料 → 资料已保存 → back, or an inline error with 重试保存 (gerenziliao js:743-776).
    @State private var savingProfile = false
    @State private var saveFailed = false
    @State private var savedTick = 0
    /// A3-09: best-effort name lookup; a failed read leaves the count row alone (no chips, no error line).
    @MainActor private func loadPreferenceNames() async {
        guard let reader = categoryReader, reader.isConfigured else { preferenceNames = [:]; return }
        let identity = reader.discoveryPresentationIdentity
        guard let values = try? await reader.discoveryCategories(type: 1), !Task.isCancelled,
              reader.discoveryPresentationIdentity == identity else { return }
        preferenceNames = Dictionary(values.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }
    /// A3-09: names for the route-preference chips (`discoveryCategories(type: 1)`, the picker's own read).
    @State private var preferenceNames: [Int: String] = [:]
    /// Nil when the stored `tagIds` is unreadable: the count is then an em dash, never a stand-in 0.
    private var selectedPreferences: [Int]? {
        model.draft.routePreferenceIDs ?? ProfilePreferenceRemoval.parse(model.coordinator.snapshot?.tagIds ?? "")
    }
    init(coordinator: ProfileEditCoordinator, sessionRevision: UInt64, categoryReader: (any DiscoveryReading)? = nil, avatarDependencies: ProfileAvatarDependencies? = nil, caseImageReader: (any RetainedPublicImageReading)? = nil, currentReviewReader: ProfileCurrentReviewReader? = nil, nicknameReader: (any ProfileNicknameAvailabilityReading)? = nil, savedMedia: ProfileSavedMediaReaders? = nil, onSaved: (() -> Void)? = nil, initialField: String? = nil) {
        self.initialField = initialField
        _model = StateObject(wrappedValue: ProfileEditModel(coordinator: coordinator))
        _currentReviewNotice = StateObject(wrappedValue: ProfileCurrentReviewNoticeOwner())
        self.currentReviewReader = currentReviewReader
        self.nicknameReader = nicknameReader
        self.savedMedia = savedMedia
        self.onSaved = onSaved
        self.sessionRevision = sessionRevision; self.categoryReader = categoryReader; self.avatarDependencies = avatarDependencies; self.caseImageReader = caseImageReader
    }
    private var editorForm: some View {
        Form {
            if model.coordinator.identity == nil {
                ContentUnavailableView("profile.edit.signIn", systemImage: "person.crop.circle.badge.exclamationmark")
                    .listRowBackground(Color.clear)
            } else if !model.coordinator.isConfigured {
                ContentUnavailableView("profile.edit.unavailable", systemImage: "network.slash")
                    .listRowBackground(Color.clear)
            } else {
                if model.coordinator.snapshot != nil {
                    // Mini-program pages/gerenziliao order: avatar, nickname, phone, city signature, works, contact QR, route preferences.
                    ProfileCurrentAvatarView(model: model, reader: savedMedia?.avatar)
                    ProfileAvatarDraftSection(model: model, dependencies: avatarDependencies)
                    ProfileCurrentReviewNotice(model: model, reader: currentReviewReader, owner: currentReviewNotice)
                    // Mini-program order (gerenziliao @1c80c5a): [昵称, 个人介绍], then 手机号 in its own group.
                    Section {
                        textFieldRow(.name, value: model.displayedName).disabled(!model.canBeginTextEdit)
                        textFieldRow(.introduction, value: model.displayedIntroduction).disabled(!model.canBeginTextEdit)
                    } header: { Text("profile.edit.details") }
                    if let mask = model.contractPhoneMask, !mask.isEmpty {
                        Section {
                            LabeledContent("profile.phone.title") {
                                Text(verbatim: mask).monospacedDigit()
                            }.privacySensitive().accessibilityIdentifier("profile.phone.value")
                        }
                    } else if let phone = model.coordinator.phoneDisplay {
                        Section {
                            LabeledContent("profile.phone.title") {
                                switch phone {
                                case .masked(let value):
                                    Text(verbatim: value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value).monospacedDigit()
                                case .unbound: Text("profile.phone.unbound")
                                case .unavailable: Text("profile.phone.unavailable")
                                }
                            }.privacySensitive().accessibilityIdentifier("profile.phone.value")
                        }
                    }
                    Section("profile.case.title") {
                        textFieldRow(.caseIntroduction, value: model.draft.caseIntroduction ?? model.coordinator.snapshot?.caseIntroduction ?? "")
                            .disabled(!model.canBeginTextEdit)
                        Button("profile.caseRemoval.open") { model.beginTextEdit(.casePictures) }
                            .disabled(!model.canBeginTextEdit).accessibilityIdentifier("profile.caseRemoval.open")
                        if model.draft.removesCasePictures { Text("profile.caseRemoval.staged") }
                        else if let subset = model.draft.casePictureSubset {
                            LabeledContent("profile.caseSubset.remaining", value: String(subset.retainedCount))
                                .accessibilityIdentifier("profile.caseSubset.stagedCount")
                        }
                        // A3-01: 添加作品图片 (≤ 9 in all) and the staged new pictures.
                        ProfileMediaUploadRows(model: model, dependencies: avatarDependencies, kind: .casePicture)
                    }
                    ProfileContactQRSection(wechat: model.coordinator.snapshot?.wechat ?? "", removes: model.draft.removesContactQR,
                                            replaced: model.draft.contactQRReplacement != nil) {
                        model.beginTextEdit(.contactQR)
                    } upload: {
                        // A3-01: 上传二维码 / 更换二维码 and the staged new code.
                        ProfileMediaUploadRows(model: model, dependencies: avatarDependencies, kind: .contactQR)
                    }.disabled(!model.canBeginTextEdit)
                    Section("context.preferences.title") {
                        LabeledContent("context.preferences.selected", value: selectedPreferences.map { String($0.count) } ?? "—")
                        // A3-09 (gerenziliao.wxml 路线偏好): the chosen preferences as chips; ids without a loaded name are skipped.
                        let named = (selectedPreferences ?? []).compactMap { preferenceNames[$0] }
                        if !named.isEmpty {
                            Text(verbatim: named.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("profile.edit.preferenceChips")
                        }
                        Button("profile.preferenceRemoval.open") { model.beginTextEdit(.preferences) }
                            .disabled(!model.canBeginTextEdit)
                            .accessibilityIdentifier("profile.preferenceRemoval.open")
                        Button("context.preferences.edit") { model.beginPreferencePicker(reader: categoryReader) }
                            .disabled(!model.canBeginTextEdit).accessibilityIdentifier("profile.edit.preferences")
                    }
                }
                if let key = model.coordinator.messageKey {
                    Text(LocalizedStringKey(key))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile.edit.status")
                }
                if savingProfile {
                    Label { Text("profile.edit.saving") } icon: { ProgressView() }
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile.edit.saving")
                }
                if let remote = model.coordinator.remoteMessage { Text(verbatim: remote) }
                if saveFailed, !savingProfile {
                    Label { Text("profile.edit.saveFailed") } icon: { Image(systemName: "exclamationmark.triangle").accessibilityHidden(true) }
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("profile.edit.saveFailed")
                    Button { Task { await saveProfile() } } label: {
                        Text("profile.edit.retrySave").frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(model.busy || model.textEdit != nil)
                        .accessibilityIdentifier("profile.edit.retrySave")
                }
                Button {
                    Task { await model.requestReload() }
                } label: {
                    Text(LocalizedStringKey(model.coordinator.isLocked ? "profile.edit.check" : "profile.edit.reload"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(model.busy || model.textEdit != nil).accessibilityIdentifier("profile.edit.reload")
                if model.busy { ProgressView().frame(maxWidth: .infinity).accessibilityIdentifier("profile.edit.busy") }
            }
        }
    }
    private var editorNavigation: some View {
        editorForm
        .cyGroupedSurface()
        .cyPushedChrome(domain: .player)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.coordinator.identity != nil, model.coordinator.isConfigured, model.coordinator.snapshot != nil {
                VStack(spacing: 0) {
                    Divider()
                    Button { Task { await saveProfile() } } label: {
                        Text("profile.edit.review").frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(model.busy || model.coordinator.isLocked || !model.draft.isValid
                                  || model.textEdit != nil || !(model.coordinator.snapshot.map { model.draft.hasChanges(comparedTo: $0) } ?? false))
                        .accessibilityIdentifier("profile.edit.review")
                        .sensoryFeedback(.selection, trigger: model.confirmation?.id)
                        .padding()
                }
                .background(.bar)
            }
        }
        .background(ProfileAvatarOwnerAnchor(model: model).frame(width: 0, height: 0))
        .sensoryFeedback(.success, trigger: savedTick)
        // A3-03: pushed page → inline title. A3-02 (T&C §3): the system back and its swipe while nothing is unsaved;
        // only while the draft is dirty does the same-looking guarded back ask first.
        .cyPageTitle("profile.edit.title")
        .interactiveDismissDisabled(model.blocksInteractiveExit)
        .cyGuardedBack(when: model.blocksInteractiveExit) {
            guard model.canRequestExit else { return }
            if model.requestExit() { dismiss() }
        }
        .sheet(isPresented: $showExitConfirmation) {
            if let value = model.exitConfirmation {
                MemberProfileDiscardConfirmSheet(kind: .exitDiscard, onCancel: { model.cancelExit() }) {
                    showExitConfirmation = false
                    if model.confirmExit(value) { dismiss() }
                }
            }
        }
        .onChange(of: model.exitConfirmation?.id) { _, id in showExitConfirmation = id != nil }
        .onChange(of: showExitConfirmation) { _, showing in if !showing { model.cancelExit() } }
        .onChange(of: model.preferencePicker?.id) { _, _ in model.cancelExit() }
        .sheet(isPresented: $showReloadConfirmation) {
            if let value = model.reloadConfirmation {
                MemberProfileDiscardConfirmSheet(kind: .reloadDiscard, onCancel: { model.cancelReload() }) {
                    showReloadConfirmation = false
                    _ = model.confirmReload(value)
                }
            }
        }
        .onChange(of: model.reloadConfirmation?.id) { _, id in showReloadConfirmation = id != nil }
        .onChange(of: showReloadConfirmation) { _, showing in if !showing { model.cancelReload() } }
        .onChange(of: model.confirmation?.id) { _, _ in model.retireReload() }
        .onChange(of: sessionRevision) { _, _ in model.retireSavedReturn(); model.retireReload() }
        .onChange(of: sessionRevision) { _, _ in
            if let value = model.textEdit { model.cancelTextEdit(value) }
        }
    }
    var body: some View {
        editorNavigation
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.retireReload(); model.suspendForBackground() } else { model.activateAvatar() }
        }
        .modifier(ProfileCurrentReviewNoticeLifecycle(model: model, reader: currentReviewReader, owner: currentReviewNotice))
        .task(id: sessionRevision) { model.retirePreferencePicker(); await model.resetAndLoad(); openInitialFieldOnce() }
        .task(id: categoryReader?.discoveryPresentationIdentity) { await loadPreferenceNames() }
        .background {
            if let edit = model.textEdit {
                ProfileTextEditPresentationOwner(model: model, edit: edit, caseImageReader: caseImageReader, nicknameReader: nicknameReader, savedMedia: savedMedia)
                    .id(edit.id)
            }
        }
        .background {
            if let edit = model.preferencePicker {
                ProfilePreferencePickerPresentationOwner(model: model, edit: edit)
                    .id(edit.id)
            }
        }
        .onChange(of: categoryReader.map { ObjectIdentifier($0) }) { _, _ in model.retirePreferencePicker() }
        .onChange(of: categoryReader?.discoveryPresentationIdentity) { _, _ in model.retirePreferencePicker() }
        .onChange(of: categoryReader?.isConfigured) { _, _ in model.retirePreferencePicker() }
        .onDisappear(perform: handleEditorDisappear)
    }
    // A3-06 (r9): MP pages/gerenziliao/gerenziliao.wxml:94 `saveInfo` saves on tap, with no review modal.
    // 保存 prepares (fresh read + conflict fence, unchanged) and commits the prepared payload straight away.
    private func saveProfile() async {
        saveFailed = false
        await model.prepare()
        guard let value = model.confirmation else { return }
        await commitSave(value)
    }
    private func commitSave(_ value: ProfileEditConfirmation) async {
        savingProfile = true; saveFailed = false
        let receipt = await model.save(value)
        savingProfile = false
        guard let receipt, model.consumeSavedReturn(receipt) else {
            let key = model.coordinator.messageKey
            if key != "profile.edit.saved", key != "profile.edit.nicknameTaken", key != "profile.edit.nicknameInvalid" { saveFailed = true }
            return
        }
        // The page's status line reads 资料已保存 for a beat before going back (MP toast then navigateBack).
        savedTick += 1
        try? await Task.sleep(for: .milliseconds(900))
        if let onSaved { onSaved() } else { dismiss() }
    }
    private func textFieldRow(_ field: ProfileTextField, value: String) -> some View {
        Button { model.beginTextEdit(field) } label: {
            HStack {
                LabeledContent {
                    if field == .caseIntroduction, model.coordinator.snapshot?.caseIntroduction == nil {
                        Text("profile.case.descriptionUnavailable").cyText(.meta).foregroundStyle(.secondary)
                    } else if value.isEmpty { Text("profile.fieldEdit.empty").foregroundStyle(.secondary) }
                    else { Text(verbatim: value).fixedSize(horizontal: false, vertical: true) }
                } label: { Text(LocalizedStringKey(field.titleKey)) }
                // A3-09: the system disclosure glyph size (tertiary, footnote semibold), not a hand-sized caption.
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.fieldEdit.open.\(field.rawValue)")
    }

    private func openInitialFieldOnce() {
        guard !openedInitialField, let initialField, model.coordinator.snapshot != nil else { return }
        openedInitialField = true
        switch initialField {
        case "introduction": model.beginTextEdit(.introduction)
        case "category": model.beginPreferencePicker(reader: categoryReader)
        default: break
        }
    }

    private func handleEditorDisappear() {
        if model.preferencePicker == nil, model.textEdit == nil, model.confirmation == nil, !model.avatarPresentationActive { model.retireAvatar() }
        model.retireReload()
        if let value = model.confirmation { model.coordinator.cancel(value) }
    }

}

/// The stable form mounts a separate presenter only after an exact editor exists.
/// Every callback keeps that UUID even if another editor is opened before dismissal completes.
@MainActor private struct ProfileTextEditPresentationOwner: View {
    @ObservedObject var model: ProfileEditModel
    let edit: ProfileTextFieldEdit
    let caseImageReader: (any RetainedPublicImageReading)?
    let nicknameReader: (any ProfileNicknameAvailabilityReading)?
    let savedMedia: ProfileSavedMediaReaders?
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .sheet(item: model.textEditPresentation(for: edit), onDismiss: { model.cancelTextEdit(edit) }) { value in Group {
            NavigationStack {
                if value.field == .contactQR {
                    ProfileContactQREditor(edit: value, reader: caseImageReader,
                        savedPreview: { AnyView(ProfileCurrentMediaPreview(model: model, edit: value, kind: .contactQR, reader: savedMedia?.contactQR)) },
                        cancel: { model.cancelTextEdit(value) },
                        confirm: { _ = model.confirmContactQR(value, remove: $0) })
                        .id(value.id)
                } else if value.field == .casePictures {
                    ProfileCasePictureRemovalEditor(edit: value, reader: caseImageReader,
                        savedPreview: { AnyView(ProfileCurrentMediaPreview(model: model, edit: value, kind: .caseImage, reader: savedMedia?.work)) },
                        cancel: { model.cancelTextEdit(value) },
                        confirm: { _ = model.confirmCasePictureRemoval(value, remove: $0) },
                        confirmSubset: { _ = model.confirmCasePictureSubset(value, retainedIndices: $0) })
                        .id(value.id)
                } else if value.field == .preferences {
                    ProfilePreferenceRemovalEditor(edit: value,
                        cancel: { model.cancelTextEdit(value) },
                        confirm: { _ = model.confirmPreferenceRemoval(value, selectedIDs: $0) })
                        .id(value.id)
                } else {
                    ProfileTextFieldEditor(edit: value, caseImageReader: caseImageReader, nicknameReader: value.field == .name ? nicknameReader : nil,
                        cancel: { model.cancelTextEdit(value) },
                        confirm: { _ = model.confirmTextEdit(value, text: $0) })
                        .id(value.id)
                }
            }.interactiveDismissDisabled(false)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        }
    }
}

/// The stable form mounts this presenter only after a concrete picker UUID exists.
@MainActor private struct ProfilePreferencePickerPresentationOwner: View {
    @ObservedObject var model: ProfileEditModel
    let edit: ProfilePreferencePickerEdit
    private var categoryReader: (any DiscoveryReading)? { edit.reader }
    private var selectedPreferences: [Int] { edit.selected }
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .sheet(item: model.preferencePickerPresentation(for: edit),
                   onDismiss: { model.cancelPreferencePicker(edit) }) { offered in Group {
                NavigationStack {
                    ProfileRoutePreferencePicker(reader: categoryReader, selected: selectedPreferences,
                        currentIdentity: { model.preferencePickerIdentity(offered) }) {
                            _ = model.confirmPreferencePicker(offered, selectedIDs: $0)
                        }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            }
    }
}
