import SwiftUI

/// View-local PII disappears with the form; the injected coordinator retains only the
/// operation lock/readback needed to prevent a dismissed request from being sent twice.
/// An UNKNOWN create retains its immutable retry payload only in this form lifetime.
@MainActor
final class ParticipantFormModel: ObservableObject {
    let reader: any ProfileReading
    let coordinator: ParticipantMutationCoordinator
    let id: Int?
    @Published var draft = ParticipantFormDraft()
    @Published private(set) var loading = true
    @Published private(set) var loaded = false
    @Published private(set) var issue: ParticipantScreenIssue?
    @Published private(set) var operation: ParticipantMutationState = .idle
    @Published private(set) var readback: ParticipantReadbackState = .idle
    @Published var showConfirmation = false
    @Published private(set) var validationReview = ProfileParticipantValidationReview()
    private(set) var confirmationSummary = ""
    private(set) var confirmation: ParticipantConfirmation?
    @Published private(set) var originalCreateRetry: ParticipantOriginalCreateRetry?
    private var loadedIdentity: ProfileReadIdentity?
    private var generation: UInt64 = 0
    private var originalRetryIsActive = true
    /// mp-states r3: MP addressinfo.wxml:44 titles a rejected save 参与人信息没有保存 · 重试保存; a rejected delete keeps the shared title.
    @Published private(set) var lastMutationIsDelete = false

    init(id: Int?, reader: any ProfileReading, coordinator: ParticipantMutationCoordinator) {
        self.id = id; self.reader = reader; self.coordinator = coordinator
    }
    var canSave: Bool {
        canMutate && draft.validation == nil
    }
    var canMutate: Bool { loaded && coordinator.canPrepare && loadedIdentity == coordinator.identity }
    var busy: Bool { operation == .submitting || readback == .loading }
    var hasCurrentProjection: Bool { loadedIdentity != nil && reader.identity == loadedIdentity && coordinator.identity == loadedIdentity }
    var canReadBack: Bool { reader.isConfigured && loadedIdentity != nil && reader.identity == loadedIdentity && reader.identity == coordinator.identity }
    var showsOwnedUnknown: Bool {
        guard reader.identity != nil, reader.identity == coordinator.identity else { return false }
        if case .outcomeUnknown = coordinator.state { return true }; return false
    }
    var canReviewForSave: Bool {
        canMutate && !busy && reader.isConfigured && coordinator.isConfigured
            && loadedIdentity != nil && reader.identity == loadedIdentity
    }
    var validationIssue: ProfileParticipantValidationField? {
        guard canReviewForSave else { return nil }
        return validationReview.issue(in: draft)
    }
    /// Invalid input only reveals local feedback. Valid input uses the original
    /// confirmation, never dispatching a mutation from this action.
    func reviewForSave() -> ProfileParticipantValidationField? {
        guard canReviewForSave else { return nil }
        let field = validationReview.request(in: draft)
        if field == nil { prepareSave() }
        return field
    }
    func sync() {
        if let originalCreateRetry, originalCreateRetry.identity != coordinator.identity { self.originalCreateRetry = nil }
        coordinator.synchronizeSession()
        operation = coordinator.state; readback = coordinator.readbackState
    }
    func load() async {
        coordinator.leaveScreen(confirmation: confirmation ?? originalCreateRetry?.confirmation)
        confirmation = nil; originalCreateRetry = nil; confirmationSummary = ""; showConfirmation = false
        generation &+= 1
        let stamp = generation
        loaded = false; loading = true; issue = nil; draft = ParticipantFormDraft()
        validationReview = ProfileParticipantValidationReview()
        loadedIdentity = nil; sync()
        // A withdrawn write/read grant must not hide a still-owned original UNKNOWN.
        if showsOwnedUnknown { loadedIdentity = reader.identity; loading = false; return }
        guard reader.isConfigured, coordinator.isConfigured else { loading = false; return }
        guard let identity = reader.identity, identity == coordinator.identity else { loading = false; return }
        loadedIdentity = identity
        if case .outcomeUnknown = operation { loading = false; return }
        defer { if stamp == generation { loading = false } }
        do {
            let value: ParticipantFormDraft
            if let id {
                let detail = try await reader.profileParticipant(id: id)
                guard detail.id == id else { throw APIError.malformedResponse }
                value = ParticipantFormDraft(detail: detail)
            } else { value = ParticipantFormDraft() }
            guard stamp == generation, !Task.isCancelled, reader.identity == identity,
                  coordinator.identity == identity else { return }
            draft = value; loadedIdentity = identity; loaded = true
        } catch {
            guard stamp == generation, !Task.isCancelled, reader.identity == identity,
                  coordinator.identity == identity else { return }
            issue = ParticipantScreenIssue(error)
        }
    }
    func prepareSave() {
        guard canSave, let identity = loadedIdentity else { return }
        do {
            confirmation = try coordinator.prepare(.save(draft), expectedIdentity: identity)
            lastMutationIsDelete = false
            originalCreateRetry = confirmation.flatMap(ParticipantOriginalCreateRetry.init(confirmation:))
            confirmationSummary = draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
                + "\n" + draft.mobilePhone.trimmingCharacters(in: .whitespacesAndNewlines)
            showConfirmation = true; issue = nil; sync()
        } catch { issue = ParticipantScreenIssue(error) }
    }
    func prepareDelete() {
        guard canMutate, let id, let identity = loadedIdentity else { return }
        do {
            confirmation = try coordinator.prepare(.delete(id: id), expectedIdentity: identity)
            lastMutationIsDelete = true
            confirmationSummary = draft.fullName + "\n" + draft.mobilePhone
            showConfirmation = true; issue = nil; sync()
        } catch { issue = ParticipantScreenIssue(error) }
    }
    /// r9 A6-02: MP addressinfo.wxml:49 `saveAddress` saves on tap with no modal, so a prepared save is
    /// committed straight away by the view; only delete keeps its confirm.
    var pendingIsSave: Bool {
        guard let confirmation else { return false }
        if case .save = confirmation.mutation { return true }
        return false
    }
    func cancelConfirmation() {
        if let confirmation { coordinator.cancelConfirmation(confirmation) }
        confirmation = nil; originalCreateRetry = nil; confirmationSummary = ""; showConfirmation = false; sync()
    }
    func confirmMutation() async -> Bool {
        guard let confirmation else { return false }
        let stamp = generation
        showConfirmation = false; operation = .submitting
        let result: ParticipantCoordinatorAction
        if case .save = confirmation.mutation {
            result = await SessionOfflineSyncModel.shared.performWriteOptIn(
                routes: ["/api/user/address/action"]
            ) {
                await coordinator.confirm(confirmation)
            }
        } else {
            result = await coordinator.confirm(confirmation)
        }
        guard generation == stamp, loadedIdentity == confirmation.identity,
              reader.identity == confirmation.identity, coordinator.identity == confirmation.identity else { return false }
        self.confirmation = nil; confirmationSummary = ""; sync()
        if case .outcomeUnknown = operation {} else { originalCreateRetry = nil }
        issue = ParticipantScreenIssue.feedback(for: result)
        return result == .applied && operation == .succeeded
    }
    var ownsOriginalCreateRetry: Bool {
        guard id == nil, let originalCreateRetry, loadedIdentity == originalCreateRetry.identity,
              reader.identity == originalCreateRetry.identity,
              coordinator.identity == originalCreateRetry.identity else { return false }
        return true
    }
    var canRetryOriginalCreate: Bool {
        guard originalRetryIsActive, ownsOriginalCreateRetry, !busy, let originalCreateRetry else { return false }
        return coordinator.canRetryOriginalCreate(originalCreateRetry)
    }
    func retryOriginalCreate() async -> Bool {
        guard canRetryOriginalCreate, let original = originalCreateRetry else { return false }
        let stamp = generation
        operation = .submitting; issue = nil
        let result = await coordinator.retryOriginalCreate(original)
        guard generation == stamp, ownsOriginalCreateRetry, originalCreateRetry == original else { return false }
        sync()
        issue = ParticipantScreenIssue.feedback(for: result)
        if result == .applied, operation == .succeeded,
           original.accepts(coordinator.savedParticipant) {
            originalCreateRetry = nil; return true
        }
        return false
    }
    /// Backgrounding retires callbacks, not the same-page immutable retry payload.
    /// No automatic resend occurs on foregrounding.
    func resumeOriginalCreateRetry() { originalRetryIsActive = true }
    func suspendOriginalCreateRetry() {
        originalRetryIsActive = false
        guard let original = originalCreateRetry else { return }
        generation &+= 1
        coordinator.leaveScreen(confirmation: original.confirmation)
        showConfirmation = false
        if let confirmation { coordinator.cancelConfirmation(confirmation) }
        confirmation = nil; confirmationSummary = ""; sync()
        if case .outcomeUnknown = operation {} else { originalCreateRetry = nil }
    }
    func readBack() async {
        guard canReadBack, let identity = loadedIdentity else { return }
        let stamp = generation
        readback = .loading; issue = nil
        let result = await coordinator.readBackUncertainOutcome()
        guard generation == stamp, loadedIdentity == identity,
              reader.identity == identity, coordinator.identity == identity else { return }
        sync()
        issue = ParticipantScreenIssue.feedback(for: result)
    }
    func disappear() {
        generation &+= 1
        coordinator.leaveScreen(confirmation: confirmation ?? originalCreateRetry?.confirmation)
        originalCreateRetry = nil
        if let loadedIdentity { coordinator.discardReadback(expectedIdentity: loadedIdentity) }
        confirmation = nil; confirmationSummary = ""; showConfirmation = false
        draft = ParticipantFormDraft(); loaded = false; loadedIdentity = nil
        readback = .idle; issue = nil
        validationReview = ProfileParticipantValidationReview()
    }
}

@MainActor
struct ParticipantFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @StateObject private var model: ParticipantFormModel
    @FocusState private var focusedField: ProfileParticipantValidationField?
    let onSaved: () -> Void
    let onCreated: (ProfileParticipant, ProfileReadIdentity) -> Void
    @State private var savedTick = 0
    /// r9 A6-01b: MP addressinfo.wxml:29-30 — when the account has a bound phone and this participant has no
    /// valid number of its own (`ownPhone`), the phone row shows that bound number read-only.
    let boundPhoneLoader: (() async -> String?)?
    @State private var boundPhone: ProfileParticipantPhone?
    @State private var ownPhone = false
    private func requiredLabel(_ key: LocalizedStringKey) -> some View {
        HStack(spacing: 2) {
            Text(key)
            Text(verbatim: "*").foregroundStyle(CYColor.dangerText).accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("participant.form.required"))
    }

    init(id: Int? = nil, reader: any ProfileReading, coordinator: ParticipantMutationCoordinator,
         onSaved: @escaping () -> Void = {},
         onCreated: @escaping (ProfileParticipant, ProfileReadIdentity) -> Void = { _, _ in },
         boundPhoneLoader: (() async -> String?)? = nil) {
        _model = StateObject(wrappedValue: ParticipantFormModel(id: id, reader: reader, coordinator: coordinator))
        self.onSaved = onSaved; self.onCreated = onCreated; self.boundPhoneLoader = boundPhoneLoader
    }

    /// MP addressinfo.js:59-72 `loadBoundPhone` + :107 `ownPhone`: a valid bound phone fills the form and
    /// locks the row, unless the participant being edited already carries its own valid number.
    private func loadBoundPhone() async {
        guard model.loaded, boundPhone == nil, let boundPhoneLoader else { return }
        let own = model.id != nil && ProfileParticipantPhone(source: model.draft.mobilePhone) != nil
        guard let raw = await boundPhoneLoader(), let phone = ProfileParticipantPhone(source: raw) else { return }
        ownPhone = own
        boundPhone = phone
        if !own { model.draft.mobilePhone = phone.text }
    }

    /// r9 A6-02: the alert stays only for a non-save (delete) confirmation.
    private var deleteConfirmationShown: Binding<Bool> {
        Binding(get: { model.showConfirmation && !model.pendingIsSave },
                set: { model.showConfirmation = $0 })
    }

    /// MP addressinfo.wxml:45 重试保存 → `saveAddress`: the same review + save as the toolbar 保存.
    private func retrySaveAction() {
        focusedField = model.reviewForSave()
        if focusedField == nil, model.pendingIsSave { Task { await commitMutation() } }
    }

    @MainActor private func commitMutation() async {
        if await model.confirmMutation() {
            if let row = model.coordinator.savedParticipant, let identity = model.coordinator.identity { onCreated(row, identity) }
            savedTick += 1
            try? await Task.sleep(for: .milliseconds(700))
            onSaved(); dismiss()
        }
    }

    var body: some View {
        Group {
            if model.reader.identity == nil || model.coordinator.identity == nil {
                ContentUnavailableView {
                    Label("profile.signInRequired", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("auth.expired")
                }
            } else if model.showsOwnedUnknown {
                Form {
                    ParticipantOriginalCreateRetrySection(model: model) {
                        if let row = model.coordinator.savedParticipant, let identity = model.coordinator.identity { onCreated(row, identity) }
                        onSaved(); dismiss()
                    }
                    ParticipantOperationSections(state: model.coordinator.state, readback: model.coordinator.readbackState, canReadAgain: model.canReadBack, actionIssue: model.issue) {
                        Task { await model.readBack() }
                    }
                }
            } else if !model.reader.isConfigured || !model.coordinator.isConfigured {
                ContentUnavailableView {
                    Label("profile.unavailable", systemImage: "network.slash")
                } description: {
                    Text("auth.notConfigured")
                }
            } else if model.ownsOriginalCreateRetry && model.operation == .submitting {
                Form {
                    ProgressView("participant.form.saving")
                }
            } else if model.loading || (model.loaded && !model.hasCurrentProjection) {
                ProgressView("participant.form.loadingFirst") // mp-settings r3: MP addressinfo.wxml loading-label 正在读取参与人信息
                    .accessibilityIdentifier("participant.form.loading")
            } else if !model.loaded {
                ParticipantLoadFailureView(issue: model.issue) { Task { await model.load() } }
            } else {
                Form {
                    // Native iOS: the inline nav title is the one title (参与人信息); the purpose line heads the fields.
                    Section {
                        // A6-04: MP addressinfo rows are "label * | input" (wxml:18-34): a native labelled row with a
                        // red required mark, not an icon label stacked over each field.
                        LabeledContent {
                            TextField("profile.participants.name", text: $model.draft.fullName, prompt: Text("participant.form.namePrompt"))
                            .textContentType(.name).textInputAutocapitalization(.words)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.next).focused($focusedField, equals: .name)
                            .onSubmit { focusedField = .phone }
                            .accessibilityIdentifier("participant.form.name")
                        } label: { requiredLabel("profile.participants.name") }
                        if let boundPhone, !ownPhone {
                            LabeledContent {
                                Text(verbatim: boundPhone.text)
                                    .foregroundStyle(CYColor.textSecondary)
                                    .accessibilityIdentifier("participant.form.phone.bound")
                            } label: { requiredLabel("profile.participants.phone") }
                        } else {
                        LabeledContent {
                            // US launch r1: +86 / +1 picker; the draft keeps the server value (China bare digits, US E.164).
                            PhoneCountryField("profile.participants.phone", wire: $model.draft.mobilePhone,
                                              prompt: Text("participant.form.phonePrompt"), identifier: "participant.form.phone",
                                              focus: $focusedField, equals: .phone)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .onSubmit { focusedField = model.reviewForSave(); if focusedField == nil, model.pendingIsSave { Task { await commitMutation() } } }
                        } label: { requiredLabel("profile.participants.phone") }
                        }
                        // Input errors sit in red under the fields (ui-spec States).
                        if let field = model.validationIssue {
                            Text(LocalizedStringKey(field.messageKey)).cyText(.bodyCompact).foregroundStyle(CYColor.dangerText)
                                .accessibilityIdentifier("profile.participantValidation.issue." + field.rawValue)
                        }
                    } header: {
                        Text("participant.form.purpose").textCase(nil)
                    } footer: {
                        // Phone rule up front, so the red error is never the first time the rule is seen.
                        if model.validationIssue == nil {
                            Text("participant.form.phoneHint").accessibilityIdentifier("participant.form.phoneHint")
                        }
                    }
                    .disabled(model.operation.preventsNewMutation)
                    if let issue = model.issue {
                        Section { ParticipantIssueText(issue: issue) }
                    }
                    if savedTick > 0 {
                        // A6-05: MP toast 参与人信息已保存 before navigateBack (addressinfo.js:209).
                        Section {
                            Label("participant.form.savedToast", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(CYColor.successText)
                                .accessibilityIdentifier("participant.form.saved")
                        }
                    }
                    CYScreenOfflineWriteSection(
                        routes: ["/api/user/address/action"],
                        session: offlineWriteSession.session
                    )
                    ParticipantOperationSections(state: model.operation, readback: model.readback, canReadAgain: model.canReadBack, actionIssue: model.issue,
                                                 saveRetry: model.lastMutationIsDelete ? nil : retrySaveAction) {
                        Task { await model.readBack() }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    // native-r2 N-07: MP addressinfo.wxml:49 保存 as the toolbar confirmation action (Contacts-style).
                    ToolbarItem(placement: .confirmationAction) {
                        Button(LocalizedStringKey(model.operation == .submitting ? "participant.form.saving"
                            : model.draft.validation == nil ? "participant.form.save" : "profile.participantValidation.check")) {
                            focusedField = model.reviewForSave()
                            // r9 A6-02: MP addressinfo.wxml:49 saves on tap (progress → success), no confirm.
                            if focusedField == nil, model.pendingIsSave { Task { await commitMutation() } }
                        }
                        .disabled(!model.canReviewForSave)
                        .accessibilityIdentifier("participant.form.save")
                    }
                }
            }
        }
        .cyGroupedSurface()
        .cyPushedChrome(domain: .player)
        .appNavigationTitle(key: "profile.participants.title") // MP addressinfo.json: 参与人信息 for add and edit alike
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("action.cancel") { model.disappear(); dismiss() }
                    .disabled(model.busy).accessibilityIdentifier("participant.form.cancel")
            }
        }
        .interactiveDismissDisabled(model.busy)
        .sensoryFeedback(.success, trigger: savedTick)
        .alert("participant.form.confirmSave", isPresented: deleteConfirmationShown) {
            Button("participant.form.save") {
                Task { await commitMutation() }
            }
            Button("action.cancel", role: .cancel) { model.cancelConfirmation() }
        } message: {
            Text("participant.form.confirmSaveHint") + Text(verbatim: "\n\(model.confirmationSummary)")
        }
        .task(id: model.reader.identity) { await model.load(); await loadBoundPhone() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { model.resumeOriginalCreateRetry() }
            else { model.suspendOriginalCreateRetry() }
        }
        .onDisappear { model.disappear() }
    }
}

struct ParticipantScreenIssue {
    let key: String
    let message: String?
    private(set) var tableName: String? = nil
    static func feedback(for action: ParticipantCoordinatorAction) -> ParticipantScreenIssue? {
        guard case .blocked(let reason) = action, reason != .readbackInProgress else { return nil }
        return ParticipantScreenIssue(reason)
    }
    init(_ error: Error) {
        let failure = error as? ProfileReadFailure
        if error as? APIError == .unauthorized || failure?.isUnauthorized == true {
            key = "auth.expired"; message = nil
        } else if let block = error as? ParticipantCoordinatorBlock {
            message = nil
            switch block {
            case .signedOut: key = "auth.expired"
            case .accountChanged: key = "participant.form.sessionChanged"
            case .unavailable: key = "participant.recovery.safetyUnavailable"; tableName = "ProfileParticipantRecovery"
            case .invalidForm: key = "participant.recovery.invalidForm"; tableName = "ProfileParticipantRecovery"
            case .pendingOperation: key = "participant.recovery.pendingOperation"; tableName = "ProfileParticipantRecovery"
            case .confirmationNoLongerValid: key = "participant.recovery.confirmationExpired"; tableName = "ProfileParticipantRecovery"
            case .cancelledBeforeDispatch: key = "participant.recovery.cancelledBeforeDispatch"; tableName = "ProfileParticipantRecovery"
            case .noUncertainOutcome: key = "participant.recovery.noUncertainOutcome"; tableName = "ProfileParticipantRecovery"
            case .readbackInProgress: key = "participant.recovery.readInProgress"; tableName = "ProfileParticipantRecovery"
            }
        } else {
            key = "profile.retryHint"
            message = failure?.message.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        }
    }
}

struct ParticipantIssueText: View {
    let issue: ParticipantScreenIssue
    var body: some View {
        if let message = issue.message { Text(verbatim: message).foregroundStyle(CYColor.dangerText) }
        else { Text(LocalizedStringKey(issue.key), tableName: issue.tableName).foregroundStyle(CYColor.dangerText) }
    }
}

struct ParticipantLoadFailureView: View {
    let issue: ParticipantScreenIssue?
    let retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("profile.loadFailed", systemImage: "exclamationmark.circle")
        } description: {
            if let issue { ParticipantIssueText(issue: issue) }
            else { Text("participant.form.sessionChanged") }
        } actions: {
            Button("action.retry", action: retry)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("participant.form.reload")
        }
    }
}

/// Used in both forms and detail actions. An uncertain write exposes readback, never a
/// general retry-save/delete button. Only the original-create form has a separate
/// explicitly scoped retry. Readback never turns uncertainty into success.
struct ParticipantOperationSections: View {
    let state: ParticipantMutationState
    let readback: ParticipantReadbackState
    var canReadAgain: Bool = true
    var actionIssue: ParticipantScreenIssue? = nil
    /// mp-states r3: set only by the add/edit form after a rejected save (MP addressinfo.wxml:44
    /// cy-inline-error 参与人信息没有保存 · sub saveError · 重试保存). Delete / detail flows pass nil.
    var saveRetry: (() -> Void)? = nil
    let readAgain: () -> Void
    var body: some View {
        switch state {
        case .submitting:
            Section { ProgressView("participant.form.saving") }
        case .rejected(let failure) where saveRetry != nil:
            Section {
                ContentUnavailableView {
                    Label("participant.form.saveRejected", systemImage: "exclamationmark.triangle")
                } description: {
                    if let message = failure.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(verbatim: message)
                    } else { Text("participant.form.rejectedHint") }
                } actions: {
                    Button("participant.form.retrySave") { saveRetry?() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("participant.form.retrySave")
                }
                .accessibilityIdentifier("participant.form.saveRejected")
                if let row = RequestReferenceRow(pathFragment: "/api/user/") { row }
            }
        case .rejected(let failure):
            Section("participant.form.rejected") {
                if let message = failure.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(verbatim: message)
                } else { Text("participant.form.rejectedHint") }
                if let row = RequestReferenceRow(pathFragment: "/api/user/") { row }
            }
        case .notSent:
            Section { Text("participant.form.notSent") }
        case .outcomeUnknown:
            Section("participant.form.unknown") {
                Text("participant.form.unknownHint")
                if let actionIssue { ParticipantIssueText(issue: actionIssue).accessibilityIdentifier("participant.recovery.actionIssue") }
                if let row = RequestReferenceRow(pathFragment: "/api/user/") { row }
                Button("participant.form.readBack", action: readAgain)
                        .disabled(!canReadAgain || readback == .loading).accessibilityIdentifier("participant.form.readBack")
                if !canReadAgain { Text("participant.recovery.readUnavailable", tableName: "ProfileParticipantRecovery") }
            }
            switch readback {
            case .loading:
                Section { ProgressView("profile.loading") }
            case .unavailable:
                Section { Text("participant.form.readBackFailed") }
            case .received(let result):
                Section("participant.form.readBackTitle") {
                    switch result {
                    case .list(let rows):
                        if rows.isEmpty { ContentUnavailableView("profile.participants.empty", systemImage: "person.text.rectangle") }
                        ForEach(rows) { row in ParticipantReadbackRow(row: row) }
                    case .detail(let row): ParticipantReadbackRow(row: row)
                    }
                    Text("participant.form.readBackHint").foregroundStyle(.secondary)
                }
            case .idle: EmptyView()
            }
        default: EmptyView()
        }
    }
}

private struct ParticipantReadbackRow: View {
    let row: ProfileParticipant
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: ProfileParticipantDisplay.text(row.fullName)).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
            Text(verbatim: ProfileParticipantDisplay.text(row.mobilePhone)).cyText(.numericBody).monospacedDigit().foregroundStyle(CYColor.textSecondary)
            if !row.oneLineAddress.isEmpty { Text(verbatim: row.oneLineAddress).foregroundStyle(.secondary) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }
}
