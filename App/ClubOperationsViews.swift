import SwiftUI

private struct ClubProfileDraftFlowKey: EnvironmentKey {
    static let defaultValue: ClubProfileLocalDraftFlow? = nil
}
extension EnvironmentValues {
    var clubProfileDraftFlow: ClubProfileLocalDraftFlow? {
        get { self[ClubProfileDraftFlowKey.self] }
        set { self[ClubProfileDraftFlowKey.self] = newValue }
    }
}

/// CLB-r11-edit-01 (MP edit/index.js:23-30 onDissolved): the edit page's pop, called by the dissolve form 0.5 s after
/// the acknowledged dissolve. Nil outside the edit page.
struct ClubDissolvedReturn {
    let leave: @MainActor () -> Void
}
private struct ClubDissolvedReturnKey: EnvironmentKey {
    static let defaultValue: ClubDissolvedReturn? = nil
}
extension EnvironmentValues {
    var clubDissolvedReturn: ClubDissolvedReturn? {
        get { self[ClubDissolvedReturnKey.self] }
        set { self[ClubDissolvedReturnKey.self] = newValue }
    }
}

/// Session host owns access/coordinator and passes a published identity. This additive
/// entry can be mounted on ClubHome (.create) and ClubDetail (.club(id)).
struct ClubOperationsEntryButton: View {
    let target: ClubOperationsTarget
    let identity: ClubReadIdentity?
    let access: any ClubOperationsAccess
    let coordinator: ClubOperationsCoordinator
    /// Mini-program club/create redirects non-hosts to club/apply; the host supplies the
    /// existing host-status/become-leader governance read when it has one.
    var hostApplication: ClubGovernanceContext? = nil
    var onConfirmedReturn: ((ClubProfileConfirmedReturn) -> Void)? = nil
    var onWelcomeConfirmedReturn: ((ClubWelcomeNoteConfirmedReturn) -> Void)? = nil
    @State private var visit: ClubProfileDraftVisit?
    @State private var lastVisit: ClubProfileDraftVisit?
    @State private var pendingReturn: ClubProfileConfirmedReturn?
    @State private var pendingWelcomeReturn: ClubWelcomeNoteConfirmedReturn?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Button {
            guard visit == nil else { return }
            let next = ClubProfileDraftVisit(); next.bind(target: target, identity: identity, access: access)
            pendingReturn = nil; pendingWelcomeReturn = nil; lastVisit = next; visit = next
        } label: {
            Label(target == .create ? "club.ops.create" : "club.ops.manage", systemImage: target == .create ? "plus.circle" : "slider.horizontal.3")
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
        }
            .accessibilityIdentifier("club.ops." + (target == .create ? "openCreate" : "openManage"))
            .cySheet(item: $visit, onDismiss: {
                guard visit == nil else { return }
                defer { pendingReturn = nil; pendingWelcomeReturn = nil; lastVisit = nil }
                guard let lastVisit, scenePhase == .active,
                      lastVisit.matches(target: target, identity: identity, access: access) else { return }
                if let result = pendingReturn, result.identity == identity, target == .club(result.clubID) {
                    onConfirmedReturn?(result)
                }
                if let result = pendingWelcomeReturn, result.matches(target: target, identity: identity, access: access) {
                    onWelcomeConfirmedReturn?(result)
                }
            }) { opened in Group {
                NavigationStack {
                    ClubOperationsWorkspaceView(target: target, identity: identity, access: access, coordinator: coordinator,
                        hostApplication: hostApplication, onConfirmedChange: { result in
                            guard visit?.id == opened.id, lastVisit?.id == opened.id,
                                  opened.matches(target: target, identity: identity, access: access), result.identity == identity else { return }
                            pendingReturn = result
                        }, onWelcomeConfirmedChange: { result in
                            guard visit?.id == opened.id, lastVisit?.id == opened.id,
                                  opened.matches(target: target, identity: identity, access: access),
                                  result.matches(target: target, identity: identity, access: access) else { return }
                            pendingWelcomeReturn = result
                        })
                }.id(opened.id)
            }.cySheet(detents: [.large])
            }
            .onChange(of: identity) { _, _ in visit?.retire(); lastVisit?.retire(); pendingReturn = nil; pendingWelcomeReturn = nil; visit = nil }
            .onChange(of: ObjectIdentifier(access)) { _, _ in visit?.retire(); lastVisit?.retire(); pendingReturn = nil; pendingWelcomeReturn = nil; visit = nil }
    }
}

struct ClubOperationsWorkspaceView: View {
    let target: ClubOperationsTarget
    let identity: ClubReadIdentity?
    let access: any ClubOperationsAccess
    let coordinator: ClubOperationsCoordinator
    var hostApplication: ClubGovernanceContext? = nil
    var requestedTab: String? = ClubWorkspaceTab.manage.rawValue
    var onConfirmedChange: ((ClubProfileConfirmedReturn) -> Void)? = nil
    var onWelcomeConfirmedChange: ((ClubWelcomeNoteConfirmedReturn) -> Void)? = nil
    var onEnterClubManagement: ((ClubCreateToManageDestination) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @StateObject private var profileChoice = ClubProfileChoiceController()
    @StateObject private var profileMedia = ClubProfileMediaFlow()
    @StateObject private var profileDraft = ClubProfileLocalDraftFlow()
    @StateObject private var draftVisit = ClubProfileDraftVisit()
    @StateObject private var createStepBar = ClubCreateStepBar()
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot: ClubOperationsSnapshot?
    @State private var draft = ClubOperationsDraft()
    @State private var baseline = ClubOperationsDraft()
    @State private var state: ClubOperationsState = .idle
    @State private var review: ClubOperationsReview?
    @State private var loading = false
    @State private var errorKey: String?
    @State private var serverMessage: String?
    @State private var generation: UInt64 = 0
    @State private var welcomeReadGeneration: UInt64 = 0
    @State private var screenIdentity: ClubReadIdentity?
    @State private var showDiscard = false
    @State private var readbackUnavailable = false
    @State private var ownerID = UUID()
    @State private var artworkRevision = UUID()
    @ScaledMetric(relativeTo: .body) private var identityCoverSide: CGFloat = 56
    @State private var createReceiptIdentity: ClubReadIdentity?
    @State private var createReceiptClubID: Int?
    @State private var readbackIdentity: ClubReadIdentity?
    @State private var enteredManageDestination: ClubCreateToManageDestination?
    @State private var lastSubmittedReview: ClubOperationsReview?
    @State private var lastReportedReturn: UUID?
    private struct WorkspaceKey: Equatable {
        let target: ClubOperationsTarget
        let identity: ClubReadIdentity?
        let accessID: ObjectIdentifier
        let namespace: String?
        let viewerRevision: UInt64?
    }
    private var workspaceKey: WorkspaceKey {
        let context = draftVisit.enabled ? access.profileDrafts : nil
        return .init(target: target, identity: identity, accessID: ObjectIdentifier(access), namespace: context?.namespace, viewerRevision: context?.viewerRevision)
    }
    private struct DraftObservation: Equatable {
        let bytes: Data?
        let logoReceipt: UUID?
        let coverReceipt: UUID?
    }
    private var draftObservation: DraftObservation {
        .init(bytes: ClubProfileLocalDraftForm(draft).contentIdentity, logoReceipt: draft.logoUpload?.id, coverReceipt: draft.coverUpload?.id)
    }
    private var dirty: Bool { !ClubProfileLocalDraftForm(draft).exactlyMatches(.init(baseline)) || draft != baseline }
    private var profileDraftEnabled: Bool { target != .create && draftVisit.enabled }
    private var profileDraftBlocked: Bool { profileDraftEnabled && (!draftVisit.matches(target: target, identity: identity, access: access) || profileDraft.blocksEditing) }
    private var originalBusy: Bool {
        switch state { case .preparing, .reviewing, .preflighting, .submitting: return true; default: return false }
    }
    private var title: LocalizedStringKey { target == .create ? "club.ops.create" : "club.ops.manage" }
    static func makeCreateToManageFlow(
        access: any ClubOperationsAccess,
        snapshot: ClubOperationsSnapshot?,
        readbackUnavailable: Bool,
        createReceiptIdentity: ClubReadIdentity?,
        createReceiptClubID: Int?,
        currentIdentity: ClubReadIdentity?,
        readbackIdentity: ClubReadIdentity?,
        requestedTab: String?,
        enteredManageDestination: ClubCreateToManageDestination?
    ) -> ClubCreateToManageFlowState {
        let gate = ClubCreationGate(access: access)
        var ownedIDs = snapshot?.ownedClubIDs ?? []
        if let profileID = snapshot?.profile?.club.id, !ownedIDs.contains(profileID) {
            ownedIDs.append(profileID)
        }
        let readbackSucceeded = !readbackUnavailable && snapshot != nil && readbackIdentity != nil
        return ClubCreateToManageFlowState(
            gate: gate,
            receiptAccountId: createReceiptIdentity?.accountID,
            receiptClubId: createReceiptClubID,
            currentAccountId: currentIdentity?.accountID,
            readbackAccountId: readbackIdentity?.accountID,
            readbackOwnedClubIds: ownedIDs,
            readbackSucceeded: readbackSucceeded,
            readbackUnavailable: readbackUnavailable,
            requestedTab: requestedTab,
            enteredDestination: enteredManageDestination
        )
    }
    var createToManageFlow: ClubCreateToManageFlowState {
        Self.makeCreateToManageFlow(
            access: access,
            snapshot: snapshot,
            readbackUnavailable: readbackUnavailable,
            createReceiptIdentity: createReceiptIdentity,
            createReceiptClubID: createReceiptClubID,
            currentIdentity: identity,
            readbackIdentity: readbackIdentity,
            requestedTab: requestedTab,
            enteredManageDestination: enteredManageDestination
        )
    }
    /// CLB-r9-create-02: the create check answered and this account is not a host (MP redirects to apply).
    private var hostAutoOpenActive: Bool {
        guard target == .create, !loading, let value = snapshot, !value.canCreate, value.accountRole != "club", hostApplication != nil else { return false }
        return ClubCreatePageModel.interpret(signedIn: identity != nil, configured: access.isConfigured, loading: false, gate: ClubCreationGate(access: access),
                                             snapshot: value, readback: .received(value), onPlayerFirstEntry: false).showsHostApplication
    }
    var body: some View {
        Form {
            // CLB-r9-create-01 (MP create wxml:12-15): the create check reads 正在确认创建资格 while it runs.
            if loading {
                if target == .create {
                    ProgressView { Text("club.ops.create.checking") }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("club.ops.loading")
                } else {
                    ProgressView().accessibilityIdentifier("club.ops.loading")
                }
            }
            // CLB-create-03 (MP create wxml:16-28): guest → 登录; a failed check → 重新检查.
            if identity == nil {
                // Round 4 copy (MP create wxml:20): the create page says 登录后创建俱乐部.
                ContentUnavailableView {
                    Label(LocalizedStringKey(target == .create ? "club.ops.create.signedOut" : "club.ops.signedOut"), systemImage: "person.crop.circle")
                } actions: {
                    if rootTabSwitch.isAvailable {
                        Button { dismiss(); rootTabSwitch(.mine) } label: { Text("club.host.signIn.action") }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("club.host.signIn.action")
                    }
                }
            }
            else if !access.isConfigured { Text("club.ops.unavailable") }
            if target != .create, errorKey == "club.ops.error.forbidden" {
                // CLB-edit-07 (MP scene-club-edit wxml:5): a dedicated 暂无编辑权限 state with 返回俱乐部.
                ContentUnavailableView {
                    Label { Text("club.ops.edit.noPermission").accessibilityIdentifier("club.ops.error") } icon: { Image(systemName: "lock") }
                } actions: {
                    Button { dismiss() } label: { Text("club.ops.edit.backToClub") }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("club.ops.edit.backToClub")
                }
            } else if let errorKey, target == .create, snapshot == nil {
                // Round 4 copy (MP create wxml:16-18): a failed create check is 创建资格未确认 + the reason + 重新检查.
                // CLB-r10-nat-create-04: shown as a `ContentUnavailableView`.
                ContentUnavailableView {
                    Label("club.ops.create.checkFailed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(LocalizedStringKey(errorKey)).accessibilityIdentifier("club.ops.error")
                } actions: {
                    if !loading, identity != nil {
                        Button("club.ops.recheck") { Task { await load() } }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("club.ops.recheck")
                    }
                }
            } else if let errorKey {
                Text(LocalizedStringKey(errorKey)).accessibilityIdentifier("club.ops.error")
                if !loading, identity != nil {
                    Button("club.ops.recheck") { Task { await load() } }
                        .accessibilityIdentifier("club.ops.recheck")
                }
            }
            if let serverMessage { Text(verbatim: serverMessage).textSelection(.enabled) }
            if let snapshot, !(target == .create && isCreateOutcomeUnknown) { content(snapshot) }
            if target == .create, case .outcomeUnknown = state, !loading, scenePhase == .active, let identity, access.identity == identity, access.isConfigured, case .outcomeUnknown = coordinator.state(target: .create), case .received = coordinator.readback(target: .create) {
                let page = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: ClubCreationGate(access: access), snapshot: nil, readback: coordinator.readback(target: .create), onPlayerFirstEntry: false)
                ClubCreateCurrentRecordSection(countText: page.recordCountText)
            }
            status
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if target == .create, createStepBar.step != nil, snapshot?.canCreate == true {
                ClubCreateStepBarView(bar: createStepBar, submitting: loading)
                    .disabled(loading || state.locksForm || profileDraftBlocked)
            } else if target != .create, let value = snapshot, value.profile != nil {
                // CLB-edit-01 / CLB-edit-05 (fix-r8-club): MP scene-club-edit pins 保存修改 in the bottom bar
                // (wxml:161-170); a failed save replaces it with 保存失败 + 重新保存 / 继续编辑.
                editSaveBar(value)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: loading)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                // verify-r1 2.2 (Figma `204:24591`): a round ✕, not a grey 关闭 text pill; the system draws the glass.
                Button {
                    if dirty || state.locksForm { showDiscard = true } else { dismiss() }
                } label: { Image(systemName: "xmark") }
                .accessibilityLabel(Text("club.ops.close"))
                .accessibilityIdentifier("club.ops.close")
            }
            // CLB-r9-create-03 (MP create wxml:6-8): 「n / 4」 at the bar's trailing end while a wizard step shows.
            if target == .create, let step = createStepBar.step, (1...4).contains(step) {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(verbatim: "\(step) / 4")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text(verbatim: ClubPlayerCopy.progressLabel(step, locale: locale)))
                        .accessibilityIdentifier("club.create.stepCount")
                }
            }
        }
        .interactiveDismissDisabled(dirty || state.locksForm)
        .modifier(ClubCreateHostAutoOpen(active: hostAutoOpenActive, identity: identity, governance: hostApplication))
        .confirmationDialog("club.ops.discardTitle", isPresented: $showDiscard, titleVisibility: .visible) {
            if !profileDraftEnabled {
                Button("club.ops.discard", role: .destructive) { dismiss() }
            } else {
                Button { if !draftVisit.matches(target: target, identity: identity, access: access) || preserveDraftBeforeLeaving() { dismiss() } } label: { Text("localDraft.keepAndClose", tableName: "ClubProfileLocalDraft") }
                if profileDraft.canDiscard && !originalBusy {
                    Button(role: .destructive) { if profileDraft.discard() { dismiss() } } label: { Text("localDraft.discardAndClose", tableName: "ClubProfileLocalDraft") }
                }
            }
            Button("club.ops.keepEditing", role: .cancel) {}
        } message: {
            if !profileDraftEnabled { Text("club.ops.discardMessage") }
            else { Text("localDraft.closeMessage", tableName: "ClubProfileLocalDraft") }
        }
        .cySheet(item: $review, onDismiss: cancelReview) { pending in Group {
            NavigationStack {
                ClubOperationsReviewView(review: pending, canSubmit: coordinator.writeAvailability != .unverified, isExample: coordinator.writeAvailability == .syntheticOnly, onCancel: cancelReview) {
                    review = nil; state = .preflighting
                    Task { await confirm(pending) }
                }
            }.interactiveDismissDisabled(state == .preflighting || state == .submitting)
        }.cySheet(detents: [.large])
        }
        .background {
            if let session = profileChoice.session {
                ClubProfileChoicePresentationOwner(controller: profileChoice, session: session, draft: $draft,
                    context: profileChoiceContext, isCurrent: profileChoiceIsCurrent)
                    .id(session.id)
            }
        }
        .background(ClubProfileMediaOwnerAnchor(flow: profileMedia).frame(width: 0, height: 0))
        .onChange(of: artworkRevision) { _, _ in profileMedia.retire() }
        .onChange(of: identity) { _, _ in profileMedia.retire() }
        .onChange(of: profileChoiceContext) { _, _ in profileChoice.close() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { _ = preserveDraftBeforeLeaving(); if draftVisit.enabled { draftVisit.retire(); profileDraft.retire(); snapshot = nil }; profileChoice.close(); profileMedia.retire() } }
        .onChange(of: draftObservation) { _, _ in
            guard profileDraftEnabled, draftVisit.matches(target: target, identity: identity, access: access),
                  screenIdentity == identity, access.identity == identity else { return }
            _ = profileDraft.persist(draft)
        }
        .task(id: workspaceKey) {
            if draftVisit.enabled {
                guard draftVisit.matches(target: target, identity: identity, access: access) else {
                    draftVisit.retire(); profileDraft.retire(); snapshot = nil; draft = .init(); baseline = .init()
                    generation &+= 1; cancelReview(); return
                }
            } else { draftVisit.bind(target: target, identity: identity, access: access) }
            profileDraft.retire(); lastSubmittedReview = nil; lastReportedReturn = nil
            generation &+= 1; cancelReview(); snapshot = nil; draft = .init(); baseline = .init()
            screenIdentity = identity; errorKey = nil; serverMessage = nil; readbackUnavailable = false
            readbackIdentity = nil; enteredManageDestination = nil
            if createReceiptIdentity == nil || createReceiptIdentity?.accountID == identity?.accountID {
                createReceiptIdentity = nil; createReceiptClubID = nil
            }
            coordinator.synchronizeSession()
            state = coordinator.state(target: target); loading = false
            await load()
        }
        .onDisappear {
            _ = preserveDraftBeforeLeaving()
            profileChoice.close()
            generation &+= 1
            if let screenIdentity { coordinator.leaveScreen(target: target, expectedIdentity: screenIdentity, ownerID: ownerID) }
        }
    }
    private var profileChoiceContext: ClubProfileChoiceContext? {
        ClubProfileChoiceContext(target: target, identity: identity, access: access, profile: snapshot?.profile, sourceRevision: artworkRevision)
    }
    private func profileChoiceIsCurrent(_ expected: ClubProfileChoiceContext) -> Bool {
        scenePhase == .active && screenIdentity == identity && !loading && !state.locksForm && !profileDraftBlocked && review == nil &&
            expected.matches(target: target, identity: identity, access: access, profile: snapshot?.profile, sourceRevision: artworkRevision)
    }
    /// The edit header row: the cover (or the club glyph) beside name, city and role.
    private func clubIdentityHero(_ club: ClubRecord) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: club.name).font(.headline)
                if let city = club.city, !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(verbatim: city).font(.subheadline).foregroundStyle(.secondary)
                }
                Label(LocalizedStringKey(club.isOwner ? "club.ops.owner" : "club.ops.administrator"), systemImage: club.isOwner ? "crown" : "person.badge.key")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            if let cover = QuestifyCardArtwork.safeURL(club.cover) {
                PlayerFeedRemoteImage(url: cover, maxPixel: 240, placeholder: { identityGlyph }, failure: { identityGlyph })
                    .frame(width: identityCoverSide, height: identityCoverSide)
                    .clipped()
                    .accessibilityHidden(true)
            } else {
                identityGlyph
            }
        }
        .accessibilityElement(children: .combine)
    }
    private var identityGlyph: some View {
        Image(systemName: "person.3.fill")  // CLB-edit-06
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
    @ViewBuilder private func content(_ value: ClubOperationsSnapshot) -> some View {
        if let profile = value.profile {
            Section {
                // CLB-r10-nat-edit-01 (MP scene-club-edit wxml club-head: logo + name + city): one plain row with a
                // system-size cover beside 名称 / 城市 / 角色, not a full-bleed blurred image card.
                clubIdentityHero(profile.club)
            }
        }
        if target == .create && !value.canCreate {
            // Mini-program club/create no-permission and limit states.
            Section {
                ContentUnavailableView(
                    LocalizedStringKey(value.accountRole != "club" ? "club.ops.leaderRequired.title" : "club.ops.clubLimit.title"),
                    systemImage: value.accountRole != "club" ? "person.badge.plus" : "person.3"
                )
                // verify-r1 2.3 / N-15: the limit state says the real count once, with no unrelated save warning.
                if value.accountRole != "club" { Text("club.ops.leaderRequired.apply") }
                else {
                    Text("club.ops.clubLimit.count \(value.ownedClubIDs.count)")
                    // CLB-create-03 (MP create wxml:25-28, js:205 goManageClub): 管理我的俱乐部 opens the owner's club on
                    // its 管理 tab (one club → that id; otherwise the MP `owner=1` route resolves my club).
                    NavigationLink {
                        MPReviewedPageScreen(page: "pages/club/detail/index",
                                             query: value.ownedClubIDs.count == 1 ? ["id": String(value.ownedClubIDs[0]), "tab": "manage"]
                                                                                  : ["owner": "1", "tab": "manage"])
                    } label: {
                        Text("club.ops.clubLimit.manage")
                    }
                    .accessibilityIdentifier("club.ops.clubLimit.manage")
                }
                if value.accountRole != "club", let hostApplication {
                    if ClubCreatePageModel.interpret(signedIn: identity != nil, configured: access.isConfigured, loading: false, gate: ClubCreationGate(access: access), snapshot: value, readback: .received(value), onPlayerFirstEntry: false).showsHostApplication { ClubCreateHostApplicationLink(identity: identity, governance: hostApplication) }
                }
            }
        } else {
            if profileDraftEnabled {
                ClubProfileDraftRecoverySection(flow: profileDraft, busy: loading || originalBusy || !draftVisit.matches(target: target, identity: identity, access: access), restore: {
                    guard draftVisit.matches(target: target, identity: identity, access: access) else { return }
                    if let restored = profileDraft.restore() { draft = restored }
                }, discard: {
                    guard draftVisit.matches(target: target, identity: identity, access: access) else { return }
                    if profileDraft.discard() { draft = baseline; snapshot = nil; Task { await load(discardingLocalInput: true) } }
                }, readFresh: { Task { await load() } }, useCurrentImages: {
                    guard draftVisit.matches(target: target, identity: identity, access: access) else { return }
                    draft.discardMedia(.logo, original: value.profile); draft.discardMedia(.cover, original: value.profile)
                })
            }
            if target != .create, let profile = value.profile {
                ClubEditFactsSection(clubID: profile.club.id, governanceAvailable: hostApplication != nil)
            }
            // CLB-create-01: MP create step 3 carries a 16:9 cover and a 1:1 logo above the name.
            if target != .create || ClubPlayerSurface.flatCreateForm || createStepBar.step == 3 {
                ClubProfileMediaSection(draft: $draft, snapshot: value, identity: identity, service: access.profileMedia,
                    flow: profileMedia, enabled: scenePhase == .active && !loading && !state.locksForm && !profileDraftBlocked && access.identity == identity)
            }
            ClubOperationsProfileForm(draft: $draft, isCreate: target == .create, isOwner: value.profile?.club.isOwner == true, joinPolicySupported: value.profile?.club.joinPolicySupported == true,
                choiceContext: profileChoiceContext, choiceIsCurrent: profileChoiceIsCurrent, choiceController: profileChoice,
                checkClubName: { await access.checkClubName($0) }, submitCreate: { Task { await prepare(.create(draft), confirmsInline: !ClubPlayerSurface.flatCreateForm) } },
                createNameTaken: createNameTakenMessage,
                createBar: target == .create && !ClubPlayerSurface.flatCreateForm ? createStepBar : nil)
                .disabled(loading || state.locksForm || profileDraftBlocked)
            if target == .create && ClubPlayerSurface.flatCreateForm {
                Section {
                    reviewProfileButton(value, inRow: true)
                        .disabled(loading || state.locksForm || profileDraftBlocked || (target != .create && !dirty) || (target == .create && ClubOperationsPort.missingCreateStep(clubType: draft.clubType, name: draft.name, city: draft.city) != nil))
                        .accessibilityIdentifier("club.ops.reviewProfile")
                }
            }
        }
        if let profile = value.profile, profile.club.isOwner {
            ClubWelcomeNoteEntry(club: profile.club, identity: identity, access: access,
                enabled: scenePhase == .active && !loading && !state.locksForm, onConfirmed: { result in
                    guard scenePhase == .active, screenIdentity == identity,
                          result.matches(target: target, identity: identity, access: access) else { return }
                    onWelcomeConfirmedChange?(result)
                    Task { await refreshAfterWelcome(result) }
                })
            Section("club.ops.openSettings") {
                ForEach(ClubOpenSetting.allCases, id: \.rawValue) { setting in
                    if let enabled = profile.value(setting) {
                        Button {
                            Task { await prepare(.openSetting(setting, enabled: !enabled, previous: enabled)) }
                        } label: {
                            LabeledContent(LocalizedStringKey("club.ops." + setting.rawValue)) { Text(enabled ? "club.ops.enabled" : "club.ops.disabled") }
                        }
                        .disabled(loading || state.locksForm)
                        .accessibilityIdentifier("club.ops.setting." + setting.rawValue)
                    } else { LabeledContent(LocalizedStringKey("club.ops." + setting.rawValue)) { Text("club.ops.unknownValue") } }
                }
            }
            // CLB-edit-03 (fix-r8-club): the legacy 设为管理员 rows are gone; MP edit has none, and roles live on
            // governance 角色与权限.
        }
        if ClubEditDissolveAccess.isAvailable(snapshot: value), let profile = value.profile, let governance = hostApplication {
            // Mini-program club/edit: owner-only dissolve. The blockers read gates the destructive step
            // and the transfer-owner alternative lives on the governance members list.
            Section {
                NavigationLink {
                    ClubGovernanceReadView(operation: .dissolutionBlockers, scope: .init(clubID: profile.club.id), identity: identity,
                        access: governance.access, coordinator: governance.coordinator)
                        .environment(\.clubProfileDraftFlow, profileDraft)
                        .environment(\.clubDissolvedReturn, ClubDissolvedReturn(leave: { dismiss() }))
                } label: { Label("club.ops.dissolve", systemImage: "trash").foregroundStyle(.red) }
                    .disabled(loading || state.locksForm)
                    .accessibilityIdentifier("club.ops.dissolve")
                // CLB-G19 (r9, MP edit js:35-39 goGovernance; scene-club-edit wxml:206 alt): 改为转让主理人 next to 解散
                // opens the governance manage page (pages/club/governance/index?clubId=…), where the transfer lives.
                NavigationLink {
                    ClubGovernanceReadView(operation: .bans, scope: .init(clubID: profile.club.id), identity: identity,
                        access: governance.access, coordinator: governance.coordinator)
                } label: { Label("改为转让主理人", systemImage: "person.crop.circle.badge.checkmark") }
                    .disabled(loading || state.locksForm)
                    .accessibilityIdentifier("club.ops.transferInstead")
            } header: {
                // CLB-edit-02 (parity r2): MP 危险操作 section with its consequence beside the button.
                Text("club.ops.danger")
            } footer: { Text("club.ops.dissolve.consequence") }
        }
        if access.writeAvailability == .unverified, !(target == .create && !value.canCreate) {
            Section { Text("club.ops.writeGated").accessibilityIdentifier("club.ops.writeGated") }
        }
    }
    /// CLB-edit-05: the last profile save was rejected; the bottom bar carries the failure until 继续编辑.
    private var editSaveFailed: Bool {
        guard target != .create, case .rejected = state, let last = lastSubmittedReview, case .update = last.command else { return false }
        return true
    }
    @ViewBuilder private func editSaveBar(_ value: ClubOperationsSnapshot) -> some View {
        if editSaveFailed, case .rejected(let failure) = state {
            VStack(alignment: .leading, spacing: 8) {
                Text("clubR8b.edit.saveFailed").font(.headline).foregroundStyle(.red)
                    .accessibilityIdentifier("club.ops.edit.saveFailed")
                if let message = failure.message { Text(verbatim: message).font(.subheadline).foregroundStyle(.secondary) }
                HStack(spacing: 8) {
                    Button { state = .idle } label: { Text("club.ops.keepEditing").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("club.ops.edit.keepEditing")
                    reviewProfileButton(value, titleKey: "clubR8b.edit.saveAgain")
                        .disabled(loading || profileDraftBlocked)
                        .accessibilityIdentifier("club.ops.edit.saveAgain")
                }
            }
        } else {
            reviewProfileButton(value)
                .disabled(loading || state.locksForm || profileDraftBlocked || !dirty)
                .accessibilityIdentifier("club.ops.reviewProfile")
        }
    }
    @ViewBuilder private func reviewProfileButton(_ value: ClubOperationsSnapshot, titleKey: LocalizedStringKey? = nil, inRow: Bool = false) -> some View {
        let button = Button {
            let command: ClubOperationsCommand
            if let original = value.profile { command = .update(draft, original: original) }
            else { command = .create(draft) }
            // CLB-edit-05 (fix-r8-club): MP 保存修改 saves on the tap; the review sheet stays only when writes are unverified.
            Task { await prepare(command, confirmsInline: target != .create) }
        } label: {
            Text(titleKey ?? LocalizedStringKey(target == .create ? "club.ops.create" : "club.ops.reviewProfile")).frame(maxWidth: inRow ? nil : .infinity)
        }
        // A Form row action keeps the Settings look; the pinned bottom bar carries the one prominent button.
        if inRow {
            button
        } else {
            button.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
    @ViewBuilder private var status: some View {
        Section {
            switch state {
            case .preparing, .preflighting, .submitting:
                ProgressView("club.ops.checking")
            case .notSent: Text("club.ops.notSent").accessibilityIdentifier("club.ops.notSent")
            case .acknowledged(let receipt):
                Text("club.ops.acknowledged").accessibilityIdentifier("club.ops.acknowledged")
                if let message = receipt.message { Text(verbatim: message) }
            case .rejected(let failure):
                if target == .create {
                    // CLB-r8-create-01 (fix-r8-club): MP create wxml:134-135 创建没有完成 + the reason + 重试. A taken
                    // name shows 去改名称 instead of 重试 (MP wxml:135, js:482 refreshStep(3)); the wizard stays put until tapped.
                    Text("clubR8b.create.failed").font(.headline).foregroundStyle(.red)
                        .accessibilityIdentifier("club.ops.create.failed")
                    Text(verbatim: failure.message ?? appLocalized("clubR8b.create.failedHint", locale: locale))
                    if createNameTakenMessage == nil {
                        Button("clubR8b.retry") { Task { await prepare(.create(draft), confirmsInline: true) } }
                            .disabled(loading || identity == nil)
                            .accessibilityIdentifier("club.ops.create.retry")
                    } else {
                        // CLB-r8-create-01 (r9, MP create wxml:135 action 去改名称, js:482 refreshStep(3)).
                        Button("club.ops.create.editName") { createStepBar.editName() }
                            .accessibilityIdentifier("club.ops.create.editName")
                    }
                } else if !editSaveFailed {
                    Text("club.ops.rejected")
                    if let message = failure.message { Text(verbatim: message) }
                }
            case .outcomeUnknown: Text("club.ops.outcomeUnknown").accessibilityIdentifier("club.ops.outcomeUnknown")
            default: EmptyView()
            }
            if readbackUnavailable { Text("club.ops.readbackUnavailable") }
            if createToManageFlow.requiresReadbackRecovery(state: state, hasSnapshot: snapshot != nil) {
                Button { Task { await readBack() } } label: {
                    if target == .create { Text(verbatim: ClubPlayerCopy.confirmResult(locale)) }
                    else { Text("club.ops.readBack") }
                }
                .disabled(loading).accessibilityIdentifier("club.ops.readBack")
            }
            if snapshot == nil, identity != nil, access.isConfigured, !loading {
                Button("club.ops.retryRead") {
                    Task {
                        if profileDraftEnabled && lastSubmittedReview == nil {
                            // Restarted UNKNOWN may have only the original durable journal,
                            // not an in-memory coordinator record. This read never unlocks it.
                            await load()
                        } else if createToManageFlow.requiresReadbackRecovery(state: state, hasSnapshot: snapshot != nil) {
                            await readBack()
                        } else {
                            await load()
                        }
                    }
                }.accessibilityIdentifier("club.ops.retryRead")
            }
            if target == .create, shouldShowPostCreateManagementClosure {
                postCreateManagementClosure
            }
        }
    }
    private var createPendingReview: Bool {
        if case .acknowledged(let receipt) = state { return receipt.pendingReview == true }
        return false
    }
    private var shouldShowPostCreateManagementClosure: Bool {
        if case .acknowledged = state { return true }
        if case .notSent = state { return true }
        return createReceiptClubID != nil || readbackUnavailable
    }
    @ViewBuilder private var postCreateManagementClosure: some View {
        let flow = createToManageFlow
        // CLB-create-02 (MP create wxml:29-31): 俱乐部已创建, then 名称 · 城市; semantic type, no raw headline.
        // CLB-create-02 (MP create wxml:30, js:415): a resubmission (status 0) reads 已重新提交，等待审核.
        Text(LocalizedStringKey(flow.blockReason == nil && createPendingReview ? "club.ops.createdStatus.resubmitted" : Self.createStatusKey(flow.blockReason)))
            .font(flow.canEnterManagement ? .headline : .body)
            .foregroundStyle(flow.canEnterManagement ? .primary : .secondary)
            .accessibilityIdentifier("clubCreateManage.status")
        let createdFacts = [draft.name, draft.city].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if flow.canEnterManagement, !createdFacts.isEmpty {
            Text(verbatim: createdFacts.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary)
                .accessibilityIdentifier("clubCreateManage.facts")
        }
        Button {
            if let destination = Self.performEnterClubManagement(
                access: access,
                snapshot: snapshot,
                readbackUnavailable: readbackUnavailable,
                createReceiptIdentity: createReceiptIdentity,
                createReceiptClubID: createReceiptClubID,
                currentIdentity: identity,
                readbackIdentity: readbackIdentity,
                requestedTab: requestedTab,
                enteredManageDestination: &enteredManageDestination
            ) {
                onEnterClubManagement?(destination)
            }
        } label: {
            Text(flow.validatedTab == .manage || !flow.canEnterManagement ? "club.ops.enterManagement" : "club.ops.enterDetail")
        }
        .disabled(loading || !flow.canEnterManagement)
        .accessibilityIdentifier("clubCreateManage.enterManagement")
        if let destination = enteredManageDestination,
           flow.canEnterManagement,
           destination.accountId == identity?.accountID {
            if destination.opensManagementWorkspace {
                NavigationLink {
                    ClubOperationsWorkspaceView(
                        target: .club(destination.clubId),
                        identity: identity,
                        access: access,
                        coordinator: coordinator,
                        hostApplication: hostApplication
                    )
                } label: {
                    Text("club.ops.openManagement")
                }
                .accessibilityIdentifier("clubCreateManage.destination")
            } else {
                Text("club.ops.destinationDetail")
                    .accessibilityIdentifier("clubCreateManage.fallbackDestination")
            }
        }
    }
    /// Core's flow copy is bilingual engineering text; the screen shows one localized line per state.
    static func createStatusKey(_ reason: ClubCreateToManageBlockReason?) -> String {
        switch reason {
        case nil: return "club.ops.createdStatus.ready"
        case .gateBlocked: return "club.ops.createdStatus.closed"
        case .awaitingConfirmedReceipt: return "club.ops.createdStatus.confirming"
        case .accountMismatch: return "club.ops.createdStatus.accountChanged"
        case .readbackFailed, .clubIdMismatch: return "club.ops.createdStatus.unread"
        }
    }
    @MainActor private func refreshAfterWelcome(_ result: ClubWelcomeNoteConfirmedReturn) async {
        guard scenePhase == .active, screenIdentity == identity,
              result.matches(target: target, identity: identity, access: access) else { return }
        let run = generation
        welcomeReadGeneration &+= 1; let welcomeRun = welcomeReadGeneration
        do {
            let fresh = try await ClubWelcomeNoteCurrentReadback.read(result, access: access,
                current: { scenePhase == .active && generation == run && welcomeReadGeneration == welcomeRun && screenIdentity == identity })
            guard !Task.isCancelled, scenePhase == .active, generation == run, welcomeReadGeneration == welcomeRun,
                  result.matches(target: target, identity: identity, access: access), fresh.target == target else { return }
            readbackUnavailable = false
            // Update actual current facts without resetting an unrelated, unsaved profile draft.
            snapshot = fresh
            if profileDraftEnabled, let profile = fresh.profile { profileDraft.compareFresh(profile) }
        } catch {
            guard scenePhase == .active, generation == run, welcomeReadGeneration == welcomeRun,
                  result.matches(target: target, identity: identity, access: access) else { return }
            readbackUnavailable = true
        }
    }
    @MainActor private func load(discardingLocalInput: Bool = false) async {
        guard let identity, access.isConfigured, !loading else { return }
        if profileDraftEnabled {
            guard draftVisit.matches(target: target, identity: identity, access: access) else { return }
            if let lastSubmittedReview { profileDraft.receiveOriginalResult(coordinator.state(target: target), review: lastSubmittedReview) }
            if !discardingLocalInput, dirty, !profileDraft.hasPersisted(draft) {
                guard profileDraft.retryPersistence(draft) else { return }
            }
        }
        generation &+= 1; let run = generation
        loading = true; errorKey = nil; serverMessage = nil
        do {
            let result = try await access.snapshot(target: target)
            guard generation == run, access.identity == identity, !Task.isCancelled,
                  !profileDraftEnabled || draftVisit.matches(target: target, identity: identity, access: access) else { return }
            guard result.target == target else { throw ClubOperationsBlock.changed }
            artworkRevision = UUID(); snapshot = result; draft = result.profile.map(ClubOperationsDraft.init(profile:)) ?? .init(); baseline = draft
            loading = false; state = coordinator.state(target: target)
            if let profile = result.profile, profileDraftEnabled {
                let reconciled = profileDraft.begin(profile: profile, context: draftVisit.context)
                if reconciled, let receiptID = profileDraft.reconciledReviewID { reportConfirmedReturn(identity: identity, clubID: profile.club.id, receiptID: receiptID) }
            }
        } catch {
            guard generation == run, access.identity == identity, !Task.isCancelled,
                  !profileDraftEnabled || draftVisit.matches(target: target, identity: identity, access: access) else { return }
            loading = false; show(error)
        }
    }
    /// CLB-create-06 (MP create wxml:142-144): the stepped wizard's 创建俱乐部 confirms in place (创建中…) with no
    /// review sheet. The reviewed command still runs (prepare, then confirm); an unverified write path keeps the sheet,
    /// which explains why it cannot be sent. The flat form (UI tests) keeps the review sheet.
    @MainActor private func prepare(_ command: ClubOperationsCommand, confirmsInline: Bool = false) async {
        guard let identity, !state.locksForm, !loading, access.identity == identity,
              !profileDraftEnabled || draftVisit.matches(target: target, identity: identity, access: access) else { return }
        if case .update(let value, let original) = command, profileDraftEnabled {
            guard profileDraft.persist(value) else { return }
            do { try profileDraft.verifyForReview(value, original: original) }
            catch { show(error); return }
        }
        generation &+= 1; let run = generation
        state = .preparing; errorKey = nil; serverMessage = nil
        do {
            if case .update(_, let original) = command, profileDraftEnabled {
                let fresh = try await access.snapshot(target: target)
                guard run == generation, access.identity == identity, profileDraft.isCurrent, !Task.isCancelled else { return }
                guard fresh.target == target, let profile = fresh.profile else { throw ClubOperationsBlock.changed }
                profileDraft.compareFresh(profile)
                guard ClubProfileLocalDraftBaseline(original).matches(profile), !profileDraft.blocksEditing else { throw ClubOperationsBlock.changed }
            }
            let pending = try await coordinator.prepare(command, target: target, expectedIdentity: identity, ownerID: ownerID)
            guard run == generation, access.identity == identity, !Task.isCancelled else { coordinator.cancel(pending); return }
            if confirmsInline, coordinator.writeAvailability != .unverified {
                state = .preflighting
                await confirm(pending)
                return
            }
            review = pending; state = coordinator.state(target: target)
        } catch {
            guard run == generation, access.identity == identity else { return }
            state = coordinator.state(target: target); show(error)
        }
    }
    private func cancelReview() {
        if let review { coordinator.cancel(review) }; review = nil
        state = coordinator.state(target: target)
    }
    @MainActor private func confirm(_ pending: ClubOperationsReview) async {
        if case .update = pending.command, profileDraftEnabled,
           (!draftVisit.matches(target: target, identity: identity, access: access) || !profileDraft.beginSubmission(pending)) {
            coordinator.cancel(pending); state = coordinator.state(target: target); return
        }
        lastSubmittedReview = pending
        let preservedDraft = draft, preservedBaseline = baseline
        generation &+= 1; let run = generation
        Self.performBeginConfirm(
            pending,
            target: target,
            snapshot: &snapshot,
            readbackUnavailable: &readbackUnavailable,
            createReceiptIdentity: &createReceiptIdentity,
            createReceiptClubID: &createReceiptClubID,
            readbackIdentity: &readbackIdentity,
            enteredManageDestination: &enteredManageDestination
        )
        await coordinator.confirm(pending, onOriginalResult: { result in
            if profileDraftEnabled { profileDraft.receiveOriginalResult(result, review: pending) }
        })
        guard run == generation, !Task.isCancelled,
              !profileDraftEnabled || draftVisit.matches(target: target, identity: identity, access: access) else { return }
        Self.performFinishConfirm(
            pending,
            target: target,
            identity: identity,
            access: access,
            coordinator: coordinator,
            snapshot: &snapshot,
            draft: &draft,
            baseline: &baseline,
            state: &state,
            readbackUnavailable: &readbackUnavailable,
            artworkRevision: &artworkRevision,
            createReceiptIdentity: &createReceiptIdentity,
            createReceiptClubID: &createReceiptClubID,
            readbackIdentity: &readbackIdentity
        )
        if profileDraftEnabled { finishProfileReadback(pending, preservedDraft: preservedDraft, preservedBaseline: preservedBaseline) }
    }
    private var isCreateOutcomeUnknown: Bool {
        if case .outcomeUnknown = state { return true }
        return false
    }
    /// Create rejection that names a taken club name. The name field shows the message and 去改名称 takes the user back to
    /// the name step on tap (no auto-jump); the lock stays if the result is unknown.
    private var createNameTakenMessage: String? {
        guard target == .create, case .rejected(let failure) = state, ClubNameCheck.isTakenMessage(failure.message) else { return nil }
        return failure.message
    }
    @MainActor static func unknownCreateCurrentCount(target: ClubOperationsTarget, state: ClubOperationsState,
        identity: ClubReadIdentity?, access: any ClubOperationsAccess, coordinator: ClubOperationsCoordinator,
        loading: Bool, active: Bool) -> Int? {
        coordinator.synchronizeSession()
        guard target == .create, case .outcomeUnknown = state, !loading, active,
              let identity, access.identity == identity, access.isConfigured,
              case .outcomeUnknown = coordinator.state(target: target),
              case .received(let current) = coordinator.readback(target: target), current.target == target,
              current.ownedClubIDs.allSatisfy({ $0 > 0 }),
              Set(current.ownedClubIDs).count == current.ownedClubIDs.count else { return nil }
        return current.ownedClubIDs.count
    }

    @MainActor private func readBack() async {
        guard let identity, !loading else { return }
        guard !profileDraftEnabled || draftVisit.matches(target: target, identity: identity, access: access) else { return }
        let preservedDraft = draft, preservedBaseline = baseline
        generation &+= 1; let run = generation; loading = true
        await coordinator.readBack(target: target, ownerID: ownerID)
        guard run == generation, !Task.isCancelled,
              !profileDraftEnabled || draftVisit.matches(target: target, identity: identity, access: access) else { return }
        Self.performFinishReadBack(
            target: target,
            identity: identity,
            access: access,
            coordinator: coordinator,
            loading: &loading,
            snapshot: &snapshot,
            draft: &draft,
            baseline: &baseline,
            state: &state,
            readbackUnavailable: &readbackUnavailable,
            artworkRevision: &artworkRevision,
            createReceiptIdentity: &createReceiptIdentity,
            createReceiptClubID: &createReceiptClubID,
            readbackIdentity: &readbackIdentity
        )
        if profileDraftEnabled, let lastSubmittedReview { finishProfileReadback(lastSubmittedReview, preservedDraft: preservedDraft, preservedBaseline: preservedBaseline) }
    }
    private func preserveDraftBeforeLeaving() -> Bool {
        guard profileDraftEnabled, dirty else { return true }
        // A submission/UNKNOWN marker is already durable and must not be rewritten.
        if originalBusy || state.locksForm || profileDraft.blocksEditing { return profileDraft.hasPersisted(draft) }
        return profileDraft.persist(draft)
    }
    private func finishProfileReadback(_ pending: ClubOperationsReview, preservedDraft: ClubOperationsDraft, preservedBaseline: ClubOperationsDraft) {
        guard profileDraftEnabled, draftVisit.matches(target: target, identity: identity, access: access), pending.identity == identity, access.identity == identity, screenIdentity == identity,
              pending.target == target else { return }
        guard case .acknowledged = coordinator.state(target: target),
              case .received(let value) = coordinator.readback(target: target),
              value.target == target, let profile = value.profile else {
            // Rejection/UNKNOWN/no readback must never erase the user's input.
            if case .received(let value) = coordinator.readback(target: target), let profile = value.profile {
                profileDraft.observeUnconfirmedReadback(profile)
            }
            draft = preservedDraft; baseline = preservedBaseline; return
        }
        switch pending.command {
        case .update(let submitted, let original):
            let matches = ClubProfileLocalDraftBaseline(original).sameRole(profile) &&
                ClubProfileLocalDraftForm(submitted).submitted(against: original).matchesReadback(profile)
            profileDraft.receiveOriginalResult(coordinator.state(target: target), review: pending)
            let cleared = profileDraft.reconcile(profile)
            if !cleared { draft = preservedDraft; baseline = preservedBaseline }
            if matches { reportConfirmedReturn(identity: pending.identity, clubID: profile.club.id, receiptID: pending.id) }
        case .openSetting(let setting, let enabled, _):
            draft = preservedDraft; baseline = preservedBaseline
            profileDraft.compareFresh(profile)
            if profile.value(setting) == enabled { reportConfirmedReturn(identity: pending.identity, clubID: profile.club.id, receiptID: pending.id) }
        case .memberRole:
            draft = preservedDraft; baseline = preservedBaseline; profileDraft.compareFresh(profile)
        case .create: break
        }
    }
    private func reportConfirmedReturn(identity: ClubReadIdentity, clubID: Int, receiptID: UUID) {
        guard target == .club(clubID), self.identity == identity, access.identity == identity,
              screenIdentity == identity, lastReportedReturn != receiptID else { return }
        lastReportedReturn = receiptID
        onConfirmedChange?(.init(identity: identity, clubID: clubID, receiptID: receiptID))
    }
    @MainActor static func performBeginConfirm(
        _ pending: ClubOperationsReview,
        target: ClubOperationsTarget,
        snapshot: inout ClubOperationsSnapshot?,
        readbackUnavailable: inout Bool,
        createReceiptIdentity: inout ClubReadIdentity?,
        createReceiptClubID: inout Int?,
        readbackIdentity: inout ClubReadIdentity?,
        enteredManageDestination: inout ClubCreateToManageDestination?
    ) {
        snapshot = nil; readbackUnavailable = false; readbackIdentity = nil; enteredManageDestination = nil
        if target == .create { createReceiptIdentity = pending.identity; createReceiptClubID = nil }
    }
    @MainActor static func performFinishConfirm(
        _ pending: ClubOperationsReview,
        target: ClubOperationsTarget,
        identity: ClubReadIdentity?,
        access: any ClubOperationsAccess,
        coordinator: ClubOperationsCoordinator,
        snapshot: inout ClubOperationsSnapshot?,
        draft: inout ClubOperationsDraft,
        baseline: inout ClubOperationsDraft,
        state: inout ClubOperationsState,
        readbackUnavailable: inout Bool,
        artworkRevision: inout UUID,
        createReceiptIdentity: inout ClubReadIdentity?,
        createReceiptClubID: inout Int?,
        readbackIdentity: inout ClubReadIdentity?
    ) {
        guard access.identity == pending.identity else { return }
        state = coordinator.state(target: target)
        if target == .create, case .acknowledged(let receipt) = state {
            createReceiptIdentity = pending.identity
            createReceiptClubID = receipt.clubID
        }
        performAcceptReadback(
            target: target,
            identity: identity,
            access: access,
            coordinator: coordinator,
            snapshot: &snapshot,
            draft: &draft,
            baseline: &baseline,
            readbackUnavailable: &readbackUnavailable,
            artworkRevision: &artworkRevision,
            createReceiptIdentity: &createReceiptIdentity,
            createReceiptClubID: &createReceiptClubID,
            readbackIdentity: &readbackIdentity
        )
    }
    @MainActor static func performFinishReadBack(
        target: ClubOperationsTarget,
        identity: ClubReadIdentity,
        access: any ClubOperationsAccess,
        coordinator: ClubOperationsCoordinator,
        loading: inout Bool,
        snapshot: inout ClubOperationsSnapshot?,
        draft: inout ClubOperationsDraft,
        baseline: inout ClubOperationsDraft,
        state: inout ClubOperationsState,
        readbackUnavailable: inout Bool,
        artworkRevision: inout UUID,
        createReceiptIdentity: inout ClubReadIdentity?,
        createReceiptClubID: inout Int?,
        readbackIdentity: inout ClubReadIdentity?
    ) {
        guard access.identity == identity else { return }
        loading = false
        performAcceptReadback(
            target: target,
            identity: identity,
            access: access,
            coordinator: coordinator,
            snapshot: &snapshot,
            draft: &draft,
            baseline: &baseline,
            readbackUnavailable: &readbackUnavailable,
            artworkRevision: &artworkRevision,
            createReceiptIdentity: &createReceiptIdentity,
            createReceiptClubID: &createReceiptClubID,
            readbackIdentity: &readbackIdentity
        )
        state = coordinator.state(target: target)
    }
    @MainActor static func performAcceptReadback(
        target: ClubOperationsTarget,
        identity: ClubReadIdentity?,
        access: any ClubOperationsAccess,
        coordinator: ClubOperationsCoordinator,
        snapshot: inout ClubOperationsSnapshot?,
        draft: inout ClubOperationsDraft,
        baseline: inout ClubOperationsDraft,
        readbackUnavailable: inout Bool,
        artworkRevision: inout UUID,
        createReceiptIdentity: inout ClubReadIdentity?,
        createReceiptClubID: inout Int?,
        readbackIdentity: inout ClubReadIdentity?
    ) {
        switch coordinator.readback(target: target) {
        case .received(let value):
            artworkRevision = UUID(); snapshot = value; readbackUnavailable = false
            readbackIdentity = access.identity
            if case .acknowledged(let receipt) = coordinator.state(target: target) {
                if target == .create {
                    if createReceiptIdentity == nil { createReceiptIdentity = identity }
                    createReceiptClubID = receipt.clubID
                }
                draft = value.profile.map(ClubOperationsDraft.init(profile:)) ?? .init(); baseline = draft
            }
        case .unavailable:
            readbackUnavailable = true
            readbackIdentity = nil
        default: break
        }
    }
    @MainActor static func performEnterClubManagement(
        access: any ClubOperationsAccess,
        snapshot: ClubOperationsSnapshot?,
        readbackUnavailable: Bool,
        createReceiptIdentity: ClubReadIdentity?,
        createReceiptClubID: Int?,
        currentIdentity: ClubReadIdentity?,
        readbackIdentity: ClubReadIdentity?,
        requestedTab: String?,
        enteredManageDestination: inout ClubCreateToManageDestination?
    ) -> ClubCreateToManageDestination? {
        var nextFlow = makeCreateToManageFlow(
            access: access,
            snapshot: snapshot,
            readbackUnavailable: readbackUnavailable,
            createReceiptIdentity: createReceiptIdentity,
            createReceiptClubID: createReceiptClubID,
            currentIdentity: currentIdentity,
            readbackIdentity: readbackIdentity,
            requestedTab: requestedTab,
            enteredManageDestination: enteredManageDestination
        )
        guard let destination = nextFlow.enterClubManagement(requestedTab: requestedTab) else { return nil }
        enteredManageDestination = destination
        return destination
    }
    private func show(_ error: Error) {
        serverMessage = (error as? ClubReadFailure)?.message
        if let block = error as? ClubOperationsBlock { errorKey = "club.ops.error." + String(describing: block) }
        else if (error as? ClubReadFailure)?.isForbidden == true { errorKey = "club.ops.error.forbidden" }
        else { errorKey = "club.ops.readFailed" }
    }
}

private struct ClubOperationsProfileForm: View {
    @Binding var draft: ClubOperationsDraft
    let isCreate: Bool
    let isOwner: Bool
    let joinPolicySupported: Bool
    var choiceContext: ClubProfileChoiceContext? = nil
    var choiceIsCurrent: (ClubProfileChoiceContext) -> Bool = { _ in false }
    let choiceController: ClubProfileChoiceController
    var checkClubName: (String) async -> ClubNameCheck.Result = { _ in .unchecked }
    var submitCreate: () -> Void = {}
    var createNameTaken: String? = nil
    /// verify-r1 2.2: the stepped create flow publishes its 上一步 / 下一步 here; the page pins them in one bar.
    var createBar: ClubCreateStepBar? = nil
    @Environment(\.locale) private var formLocale
    @QuestifyReduceMotion private var reduceMotion
    @State private var createStep = 0
    @State private var createChecking = false
    @State private var createCheckName: String?
    @State private var createCheckWantsAdvance = false
    @State private var nameCheckGeneration = 0
    @State private var createNameError: String?
    @State private var createTypeError: String?
    @State private var createCityError: String?
    @State private var createDirectionNote: String?
    @FocusState private var createNameFocused: Bool
    var body: some View {
        if isCreate { createSections } else { editSections }
    }
    /// Mini-program club/create steps, in order: 类型 → 活动方向 → 资料 → 城市.
    /// UI tests keep the flat form so the name field and review button are on screen immediately.
    @ViewBuilder private var createSections: some View {
        if ClubPlayerSurface.flatCreateForm { flatCreateSections } else { steppedCreateSections }
    }
    @ViewBuilder private var flatCreateSections: some View {
        // The page title (club.ops.create) is the navigation title; the type header names the first section.
        Section {
            Picker("club.ops.clubType", selection: $draft.clubType) {
                ForEach(ClubOperationsCatalog.types, id: \.self) { Text(LocalizedStringKey("club.ops.value." + $0)).tag($0) }
                if !draft.clubType.isEmpty, !ClubOperationsCatalog.types.contains(draft.clubType) { Text(verbatim: draft.clubType).tag(draft.clubType) }
            }.pickerStyle(.inline).labelsHidden().accessibilityIdentifier("club.ops.clubType")
        } header: { Text("club.ops.clubType") } footer: {
            if ClubOperationsPort.missingCreateStep(clubType: draft.clubType, name: "x", city: "x") == 1 { Text("club.ops.create.needType") }
        }
        Section {
            directionToggles
        } header: { Text("club.ops.directions") } footer: { Text("club.ops.directionsCount \(draft.activityPrefs.count)") }
        Section {
            field("name", text: $draft.name)
            field("description", text: $draft.description, axis: .vertical)
        } header: { Text("club.ops.profile") } footer: {
            VStack(alignment: .leading, spacing: 2) {
                if ClubOperationsPort.missingCreateStep(clubType: "x", name: draft.name, city: "x") == 3 { Text("club.ops.create.needName") }
                counterLabel("description", draft.description)
            }
        }
        Section {
            field("city", text: $draft.city)
            field("keywords", text: $draft.keywords)
            field("style", text: $draft.style)
        } header: { Text("club.ops.city") } footer: {
            if ClubOperationsPort.missingCreateStep(clubType: "x", name: "x", city: draft.city) == 4 { Text("club.ops.create.needCity") }
        }
    }
    @ViewBuilder private var steppedCreateSections: some View {
        if createStep == 0 {
            Section {
                Text(verbatim: ClubPlayerCopy.createIntroTitle(formLocale))
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("club.player.create.intro")
                    // A Section's own onAppear does not fire inside a List; the row's does.
                    .onAppear { publishCreateBar() }
            }
        } else {
            // verify-r1 2.2 / N-08: the step header is a system progress bar, the step eyebrow and the step title,
            // and on step 2 the 已选 n / 3 count at the trailing end.
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: Double(min(max(createStep, 0), 4)), total: 4)
                        .accessibilityHidden(true)
                    Text(verbatim: ClubPlayerCopy.progressLabel(createStep, locale: formLocale))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("club.player.create.progress")
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: ClubPlayerCopy.createTitle(step: createStep, locale: formLocale))
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("club.player.create.stepTitle")
                        if createStep == 2 {
                            Text(verbatim: ClubPlayerCopy.directionCount(draft.activityPrefs.count, locale: formLocale))
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                                .accessibilityIdentifier("club.player.create.directionCount")
                        }
                    }
                }
                .onAppear { publishCreateBar() }
            }
        }
        if createStep == 1 { createTypeSection }
        if createStep == 2 { createDirectionSection }
        if createStep == 3 { createProfileSection }
        if createStep == 4 { createCitySection }
        Section {
            // verify-r1 2.2 / N-08: 下一步 is pinned at the bottom of the page (the page's `ClubCreateStepBar`), so it
            // no longer jumps from 93% to 67% of the screen between steps. Without a bar host it stays inline.
            if createBar == nil {
                if createStep == 4 { createAdvanceButton.accessibilityIdentifier("club.ops.reviewProfile") }
                else { createAdvanceButton.accessibilityIdentifier("club.player.create.next") }
                if createStep > 1 {
                    Button { setCreateStep(createStep - 1) } label: {
                        Text(verbatim: ChannelCopy.text("上一步", "Back", locale: formLocale))
                    }
                    .accessibilityIdentifier("club.player.create.back")
                }
            }
        }
            .onAppear { publishCreateBar() }
            .onDisappear { createBar?.step = nil }
            .onChange(of: createStep) { _, _ in publishCreateBar() }
            .onChange(of: createChecking) { _, _ in publishCreateBar() }
            .onChange(of: createNameFocused) { _, focused in
                guard !focused, createStep == 3 else { return }
                Task { await runNameCheck(advance: false) }
            }
            .onChange(of: draft.name) { _, _ in
                createNameError = nil
                nameCheckGeneration += 1
                createChecking = false
                createCheckName = nil
                createCheckWantsAdvance = false
            }
            .onChange(of: draft.city) { _, _ in createCityError = nil }
            .onChange(of: draft.clubType) { _, _ in createTypeError = nil }
            // CLB-r8-create-01 (r9, MP create wxml:133-135): a taken name shows the inline 创建没有完成 block with
            // 去改名称; the wizard only goes back to the name step when the user taps it (no auto-jump).
            .onChange(of: createNameTaken) { _, message in
                guard let message else { return }
                createNameError = message
            }
            .onAppear {
                if let createNameTaken { createNameError = createNameTaken }
            }
    }
    @ViewBuilder private var createTypeSection: some View {
        // HANDOFF-R1 MC-10: a Settings-style single-choice list with a checkmark on the chosen type.
        Section {
            ForEach(Array(ClubOperationsCatalog.types.enumerated()), id: \.element) { index, value in
                // CLB-r7-C-04 MP-first: create/index.js:40 + wxml:68 show the type name only.
                checkRow(title: Text(LocalizedStringKey("club.ops.value." + value)),
                         icon: Image(systemName: ClubR1CreateSymbols.type(index)),
                         isSelected: draft.clubType == value) {
                    draft.clubType = draft.clubType == value ? "" : value
                    createTypeError = nil
                }
                .accessibilityIdentifier(index == 0 ? "club.ops.clubType" : "club.player.create.type.\(index)")
            }
            if !draft.clubType.isEmpty, !ClubOperationsCatalog.types.contains(draft.clubType) {
                Text(verbatim: draft.clubType)
            }
        } footer: {
            // CLB-r10-nat-create-01: the field error is the Section footer (MP create wxml:70 field-error).
            if let createTypeError {
                fieldError(createTypeError)
                    .accessibilityIdentifier("club.player.create.typeError")
            }
        }
        .sensoryFeedback(.selection, trigger: draft.clubType)
    }
    @ViewBuilder private var createDirectionSection: some View {
        // HANDOFF-R1 MC-10: a multi-choice checkmark list (at most 3); a fourth tap only shows the limit note.
        Section {
            ForEach(Array(ClubOperationsCatalog.directions.enumerated()), id: \.element) { index, value in
                let selected = draft.activityPrefs.contains(value)
                checkRow(title: Text(LocalizedStringKey("club.ops.value." + value)), icon: ClubDirectionIcon.image(for: value), isSelected: selected) {
                    if selected {
                        draft.activityPrefs.removeAll { $0 == value }
                        createDirectionNote = nil
                    } else if draft.activityPrefs.count >= 3 {
                        createDirectionNote = ClubPlayerCopy.directionLimit(formLocale)
                    } else {
                        draft.activityPrefs.append(value)
                        createDirectionNote = nil
                    }
                }
                .accessibilityIdentifier("club.player.create.direction.\(index)")
            }
        } footer: {
            // CLB-r10-nat-create-01: the 最多选 3 个 note is the Section footer.
            if let createDirectionNote {
                fieldError(createDirectionNote)
                    .accessibilityIdentifier("club.player.create.directionLimit")
            }
        }
        .sensoryFeedback(.selection, trigger: draft.activityPrefs)
    }
    /// Settings-style choice row: the option's icon and name, and a trailing checkmark when chosen.
    private func checkRow(title: Text, icon: Image?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label {
                    title.foregroundStyle(.primary)
                } icon: {
                    if let icon { icon.resizable().renderingMode(.template).scaledToFit().frame(width: 22, height: 22) }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.tint).accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    /// Inline validation under a field, in the system red.
    private func fieldError(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var createProfileSection: some View {
        Section {
            field("name", text: $draft.name, focus: $createNameFocused)
            field("description", label: "club.ops.createDescription", text: $draft.description, axis: .vertical)
            if let createNameError {
                Text(verbatim: createNameError).font(.footnote).foregroundStyle(.red)
                    .accessibilityIdentifier("club.player.create.nameError")
            }
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                Text("club.ops.nameRequired")
                counterLabel("description", draft.description)
            }
        }
    }
    @ViewBuilder private var createCitySection: some View {
        Section {
            // HANDOFF-R1 MC-10: 城市 is a row that opens the city picker sheet, not a typed field.
            ClubCreateCityRow(city: $draft.city, currentCity: nil, hasError: createCityError != nil)
                .accessibilityIdentifier("club.player.create.city")
            if let createCityError {
                fieldError(createCityError)
                    .accessibilityIdentifier("club.player.create.cityError")
            }
            field("keywords", text: $draft.keywords)
            field("style", text: $draft.style)
        }
    }
    private var createAdvanceButton: some View {
        Button(action: advanceCreate) {
            Group {
                if createChecking && createStep == 3 { Text(verbatim: ClubPlayerCopy.checkingName(formLocale)) }
                else if createStep == 0 { Text(verbatim: ClubPlayerCopy.createStart(formLocale)) }
                else if createStep == 4 { Text("club.ops.create") }
                else { Text(verbatim: ClubPlayerCopy.next(formLocale)) }
            }
        }
        .disabled(createChecking && createStep != 3)
    }
    private func publishCreateBar() {
        guard let createBar else { return }
        createBar.step = createStep
        createBar.checking = createChecking && createStep == 3
        createBar.primaryTitle = createChecking && createStep == 3 ? ClubPlayerCopy.checkingName(formLocale)
            : createStep == 0 ? ClubPlayerCopy.createStart(formLocale)
            : createStep == 4 ? appLocalized("club.ops.create", locale: formLocale)
            : ClubPlayerCopy.next(formLocale)
        createBar.backTitle = ChannelCopy.text("上一步", "Back", locale: formLocale)
        createBar.advance = { advanceCreate() }
        createBar.back = { setCreateStep(max(1, createStep - 1)) }
        // CLB-r8-create-01 (r9, MP create js:481-483): 去改名称 → refreshStep(3).
        createBar.editName = { setCreateStep(3) }
    }
    private func setCreateStep(_ next: Int) {
        if reduceMotion { createStep = next } else { withAnimation(.smooth(duration: 0.35)) { createStep = next } }
    }
    private func advanceCreate() {
        switch createStep {
        case 0: setCreateStep(1)
        case 1:
            guard ClubCreateSteps.canAdvance(step: 1, clubType: draft.clubType, name: draft.name, nameBlocked: false, city: draft.city) else {
                createTypeError = ClubPlayerCopy.needType(formLocale)
                return
            }
            createTypeError = nil
            setCreateStep(2)
        case 2: setCreateStep(3)
        case 3:
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty {
                createNameError = ClubPlayerCopy.needName(formLocale)
                return
            }
            if createNameError != nil, !createChecking { return }
            Task { await runNameCheck(advance: true) }
        case 4:
            guard ClubCreateSteps.canAdvance(step: 4, clubType: draft.clubType, name: draft.name, nameBlocked: false, city: draft.city) else {
                createCityError = ClubPlayerCopy.needCity(formLocale)
                return
            }
            createCityError = nil
            submitCreate()
        default: break
        }
    }
    private func runNameCheck(advance: Bool) async {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ClubNameCheck.shouldQuery(name) else {
            if advance { createNameError = ClubPlayerCopy.needName(formLocale) }
            return
        }
        if createChecking, createCheckName == name {
            if advance { createCheckWantsAdvance = true }
            return
        }
        let generation = nameCheckGeneration
        createChecking = true
        createCheckName = name
        createCheckWantsAdvance = advance
        let result = await checkClubName(name)
        guard generation == nameCheckGeneration, draft.name.trimmingCharacters(in: .whitespacesAndNewlines) == name else { return }
        let shouldAdvance = createCheckWantsAdvance
        createChecking = false
        createCheckName = nil
        createCheckWantsAdvance = false
        switch result {
        case .taken(let reason):
            createNameError = reason
        case .available, .unchecked:
            createNameError = nil
            if shouldAdvance, createStep == 3 { setCreateStep(4) }
        }
    }
    /// Mini-program cy-scene-club-edit order: 基础信息 → 俱乐部介绍 → 定位 → 会员经营配置.
    @ViewBuilder private var editSections: some View {
        Section {
            // cy-scene-club-edit admin-note: administrators may only edit display information.
            if !isOwner { Text("club.ops.adminNote").cyText(.meta).foregroundStyle(.secondary).accessibilityIdentifier("club.ops.adminNote") }
            // Round 4 copy (MP scene-club-edit wxml:50-72): the edit page has its own labels and placeholders
            // (名称* / 城市* / 关键词 / 风格, 俱乐部名称 / 所在城市 / 如：城市探索、解谜（选填）…), not the create wizard's.
            field("name", text: $draft.name, editCopy: true)
            field("city", text: $draft.city, editCopy: true)
            field("keywords", text: $draft.keywords, editCopy: true)
            field("style", text: $draft.style, editCopy: true)
        } header: { Text("club.ops.basics") } footer: { Text("club.ops.requiredFooter") }
        Section {
            field("description", text: $draft.description, axis: .vertical, editCopy: true)
        } header: { Text("club.ops.introduction") } footer: { counterLabel("description", draft.description) }
        Section("club.ops.positioning") {
            ClubProfileChoiceControl(kind: .type, draft: $draft, context: choiceContext, isCurrent: choiceIsCurrent, controller: choiceController)
            ClubProfileChoiceControl(kind: .directions, draft: $draft, context: choiceContext, isCurrent: choiceIsCurrent, controller: choiceController)
        }
        if !isOwner {
            // Locked card instead of disabled toggles, echoing the current owner-only values.
            Section("club.ops.signupSettings") {
                Text("club.ops.locked.title").cyText(.bodyMedium)
                lockedCurrent.cyText(.meta).accessibilityIdentifier("club.ops.locked.current")
            }
        } else {
            Section("club.ops.signupSettings") {
                // HANDOFF-R1 MC-13: one neutral switch tint (owner Q-B) and one explanation line per switch.
                Toggle(isOn: $draft.prioritySignupEnabled) {
                    Text("club.ops.prioritySignup")
                    Text(verbatim: clubR1("switch.prioritySignup", formLocale))
                }
                .accessibilityIdentifier("club.ops.prioritySignup")
                if joinPolicySupported {
                    Toggle(isOn: Binding(get: { draft.joinPolicy == 1 }, set: { draft.joinPolicy = $0 ? 1 : 0 })) {
                        Text("club.ops.joinReview")
                        Text(verbatim: clubR1("switch.joinReview", formLocale))
                    }
                    .accessibilityIdentifier("club.ops.joinPolicy")
                }
                LabeledContent {
                    // CLB-edit-08 (MP edit wxml:138): the quota reads with its unit 「个」.
                    HStack(spacing: 4) {
                        field("quota", text: $draft.memberReservedQuota).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 96)
                        Text("club.ops.quotaUnit").foregroundStyle(.secondary)
                    }
                } label: {
                    Text("club.ops.quota").accessibilityIdentifier("clubQuota.visibleLabel")
                }
            }
        }
    }
    @ViewBuilder private var directionToggles: some View {
        ForEach(ClubOperationsCatalog.directions, id: \.self) { value in
            Toggle(isOn: Binding(get: { draft.activityPrefs.contains(value) }, set: { enabled in
                if enabled { if draft.activityPrefs.count < 3 { draft.activityPrefs.append(value) } }
                else { draft.activityPrefs.removeAll { $0 == value } }
            })) { ClubDirectionLabel(value: value) }
            .disabled(!draft.activityPrefs.contains(value) && draft.activityPrefs.count >= 3)
        }
        if draft.activityPrefs.contains(where: { !ClubOperationsCatalog.directions.contains($0) }) {
            Text(verbatim: draft.activityPrefs.filter { !ClubOperationsCatalog.directions.contains($0) }.joined(separator: ", "))
        }
    }
    private var lockedCurrent: Text {
        let quota = Int(draft.memberReservedQuota)
        var text = Text("club.ops.locked.current") + Text(verbatim: " ")
            + Text(draft.prioritySignupEnabled ? "club.ops.locked.priority.on" : "club.ops.locked.priority.off")
        if joinPolicySupported {
            text = text + Text(verbatim: " · ") + Text(draft.joinPolicy == 1 ? "club.ops.locked.join.on" : "club.ops.locked.join.off")
        }
        let quotaText: Text = quota.map { Text("club.ops.locked.quota \($0)") } ?? Text(verbatim: ClubEditPage.unknownMark)
        return text + Text(verbatim: " · ") + quotaText
    }
    @ViewBuilder private func counterLabel(_ key: String, _ value: String) -> some View {
        if let counter = ClubOperationsPort.counter(value, field: key) {
            Text("club.ops.counter \(counter.used) \(counter.limit)")
                .foregroundStyle(counter.used > counter.limit ? Color.red : Color.secondary)
                .accessibilityIdentifier("club.ops.counter." + key)
        }
    }
    /// CLB-create-05 / CLB-edit-04 (parity r2): a persistent label on the field, and the mini-program placeholder as
    /// the prompt, so the label does not vanish once typed.
    private static let placeholderKeys: Set<String> = ["name", "description", "city", "keywords", "style"]
    private func field(_ key: String, label: String? = nil, text: Binding<String>, axis: Axis = .horizontal,
                       focus: FocusState<Bool>.Binding? = nil, editCopy: Bool = false) -> some View {
        let labelKey = LocalizedStringKey(label ?? ((editCopy ? "club.ops.edit.label." : "club.ops.") + key))
        let promptKey = (editCopy ? "club.ops.edit.placeholder." : "club.ops.placeholder.") + key
        let input = TextField(labelKey, text: text,
                              prompt: Self.placeholderKeys.contains(key) ? Text(LocalizedStringKey(promptKey)) : nil,
                              axis: axis)
            .accessibilityLabel(Text(labelKey))
            .accessibilityIdentifier("club.ops.field." + key)
        // CLB-r10-nat-create-05: one-line fields are system-labelled rows (label leading, field trailing); the MP `*`
        // became the Section footer's required note (club.ops.requiredFooter / club.ops.nameRequired).
        return Group {
            if axis == .horizontal {
                LabeledContent {
                    if let focus { input.focused(focus) } else { input }
                } label: {
                    Text(labelKey).accessibilityHidden(true)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    // The edit page's 俱乐部介绍 is the section header (MP sec-label), so its field carries no second label.
                    if !(editCopy && key == "description") {
                        Text(labelKey)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    if let focus { input.focused(focus) } else { input }
                }
            }
        }
    }
}

@MainActor final class ClubCreateWorkspaceDriver {
    let target: ClubOperationsTarget
    let access: any ClubOperationsAccess
    let coordinator: ClubOperationsCoordinator
    var identity: ClubReadIdentity?
    var requestedTab: String?
    private(set) var snapshot: ClubOperationsSnapshot?
    private(set) var draft = ClubOperationsDraft()
    private(set) var baseline = ClubOperationsDraft()
    private(set) var state: ClubOperationsState = .idle
    private(set) var loading = false
    private(set) var readbackUnavailable = false
    private(set) var artworkRevision = UUID()
    private(set) var createReceiptIdentity: ClubReadIdentity?
    private(set) var createReceiptClubID: Int?
    private(set) var readbackIdentity: ClubReadIdentity?
    private(set) var enteredManageDestination: ClubCreateToManageDestination?
    let ownerID = UUID()

    init(
        target: ClubOperationsTarget = .create,
        identity: ClubReadIdentity?,
        access: any ClubOperationsAccess,
        coordinator: ClubOperationsCoordinator,
        requestedTab: String? = ClubWorkspaceTab.manage.rawValue
    ) {
        self.target = target
        self.identity = identity
        self.access = access
        self.coordinator = coordinator
        self.requestedTab = requestedTab
    }

    var createToManageFlow: ClubCreateToManageFlowState {
        ClubOperationsWorkspaceView.makeCreateToManageFlow(
            access: access,
            snapshot: snapshot,
            readbackUnavailable: readbackUnavailable,
            createReceiptIdentity: createReceiptIdentity,
            createReceiptClubID: createReceiptClubID,
            currentIdentity: identity,
            readbackIdentity: readbackIdentity,
            requestedTab: requestedTab,
            enteredManageDestination: enteredManageDestination
        )
    }

    func load() async throws {
        guard let identity, access.isConfigured else { return }
        let result = try await access.snapshot(target: target)
        guard access.identity == identity, result.target == target else { throw ClubOperationsBlock.changed }
        snapshot = result
        state = coordinator.state(target: target)
    }

    func prepare(_ command: ClubOperationsCommand) async throws -> ClubOperationsReview {
        guard let identity else { throw APIError.unauthorized }
        let pending = try await coordinator.prepare(command, target: target, expectedIdentity: identity, ownerID: ownerID)
        state = coordinator.state(target: target)
        return pending
    }

    func confirm(_ pending: ClubOperationsReview) async {
        ClubOperationsWorkspaceView.performBeginConfirm(
            pending,
            target: target,
            snapshot: &snapshot,
            readbackUnavailable: &readbackUnavailable,
            createReceiptIdentity: &createReceiptIdentity,
            createReceiptClubID: &createReceiptClubID,
            readbackIdentity: &readbackIdentity,
            enteredManageDestination: &enteredManageDestination
        )
        await coordinator.confirm(pending)
        guard !Task.isCancelled else { return }
        ClubOperationsWorkspaceView.performFinishConfirm(
            pending,
            target: target,
            identity: identity,
            access: access,
            coordinator: coordinator,
            snapshot: &snapshot,
            draft: &draft,
            baseline: &baseline,
            state: &state,
            readbackUnavailable: &readbackUnavailable,
            artworkRevision: &artworkRevision,
            createReceiptIdentity: &createReceiptIdentity,
            createReceiptClubID: &createReceiptClubID,
            readbackIdentity: &readbackIdentity
        )
    }

    func readBack() async {
        guard let identity else { return }
        loading = true
        await coordinator.readBack(target: target, ownerID: ownerID)
        guard !Task.isCancelled else { return }
        ClubOperationsWorkspaceView.performFinishReadBack(
            target: target,
            identity: identity,
            access: access,
            coordinator: coordinator,
            loading: &loading,
            snapshot: &snapshot,
            draft: &draft,
            baseline: &baseline,
            state: &state,
            readbackUnavailable: &readbackUnavailable,
            artworkRevision: &artworkRevision,
            createReceiptIdentity: &createReceiptIdentity,
            createReceiptClubID: &createReceiptClubID,
            readbackIdentity: &readbackIdentity
        )
    }

    func acceptReadback() {
        ClubOperationsWorkspaceView.performAcceptReadback(
            target: target,
            identity: identity,
            access: access,
            coordinator: coordinator,
            snapshot: &snapshot,
            draft: &draft,
            baseline: &baseline,
            readbackUnavailable: &readbackUnavailable,
            artworkRevision: &artworkRevision,
            createReceiptIdentity: &createReceiptIdentity,
            createReceiptClubID: &createReceiptClubID,
            readbackIdentity: &readbackIdentity
        )
    }

    @discardableResult
    func enterClubManagement(requestedTab overrideTab: String? = nil) -> ClubCreateToManageDestination? {
        ClubOperationsWorkspaceView.performEnterClubManagement(
            access: access,
            snapshot: snapshot,
            readbackUnavailable: readbackUnavailable,
            createReceiptIdentity: createReceiptIdentity,
            createReceiptClubID: createReceiptClubID,
            currentIdentity: identity,
            readbackIdentity: readbackIdentity,
            requestedTab: overrideTab ?? requestedTab,
            enteredManageDestination: &enteredManageDestination
        )
    }
}

/// verify-r1 2.2 / N-08 (Figma 204:24591): the create wizard's 上一步 / 下一步, pinned in one bar at the bottom of the page.
/// The step state stays in the profile form; it publishes the titles and actions here.
@MainActor final class ClubCreateStepBar: ObservableObject {
    @Published var step: Int?
    @Published var checking = false
    @Published var primaryTitle = ""
    @Published var backTitle = ""
    var advance: () -> Void = {}
    var back: () -> Void = {}
    var editName: () -> Void = {}
}

struct ClubCreateStepBarView: View {
    @ObservedObject var bar: ClubCreateStepBar
    /// MP create wxml:141: the last step's button reads 创建中… while the create is in flight.
    var submitting = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var primary: some View {
        Button { bar.advance() } label: {
            Group {
                if submitting && bar.step == 4 { Text("club.ops.create.submitting") } else { Text(verbatim: bar.primaryTitle) }
            }
            .frame(maxWidth: .infinity)
        }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(bar.checking)
    }

    var body: some View {
        let step = bar.step ?? 0
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
            if step > 1 {
                Button { bar.back() } label: { Text(verbatim: bar.backTitle).frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("club.player.create.back")
            }
            if step == 4 {
                primary.accessibilityIdentifier("club.ops.reviewProfile")
            } else {
                primary.accessibilityIdentifier("club.player.create.next")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
