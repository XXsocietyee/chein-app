import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// The session owner supplies one retained coordinator. No coordinator or writer is
/// constructed by a view, and the read-only detail remains the default without one.
@MainActor
struct ClubActionPanel: View {
    let club: ClubRecord
    let identity: ClubReadIdentity
    let coordinator: ClubActionCoordinator
    /// Guests get a way to the sign-in entry instead of a bare message.
    var onSignIn: (() -> Void)? = nil
    /// HANDOFF-R1 MC-20: `.pageEnd` renders only the quiet red 退出俱乐部 / 举报俱乐部 rows at the end of 概览;
    /// the header placement then leaves 退出 out. Both keep the same confirmation and request path.
    var placement: ClubActionPlacement = .header
    var onReportClub: (() -> Void)? = nil
    /// Header placement only: 退出 is drawn by the page-end panel instead.
    var leavesAtPageEnd = false
    let onReadbackStarted: () -> UInt64
    let onReadback: (ClubRecord, ClubReadIdentity, UInt64) -> Void
    @State private var ownerID = UUID()
    @State private var revision: UInt64 = 0
    @State private var generation: UInt64 = 0
    @State private var confirmation: ClubActionConfirmation? = nil
    @State private var issueKey: String? = nil
    @State private var task: Task<Void, Never>? = nil
    @State private var isWorking = false
    @State private var joinMessage = ""
    /// Floating placement: MP detail js:2537-2548 asks the required note in the 申请加入 modal, so the field lives in
    /// a sheet opened by the capsule, and the sheet's 提交申请 is the one confirmation (no second dialog).
    @State private var applySheet = false
    @State private var submitsOnPrepare = false
    /// Set only after the server acknowledges a join or apply. Leave never celebrates.
    @State private var rewardAction: ClubAction? = nil
    @State private var rewardHandedOff = false
    @State private var rewardPhase: CYJoinReward.Phase = .landing
    @Environment(\.locale) private var locale
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @QuestifyReduceMotion private var reduceMotion

    private var availability: ClubActionAvailability {
        ClubActionAvailability.resolve(club, viewerIsMerchant: coordinator.viewerIsMerchant)
    }
    /// The 申请留言 field is on screen (same gates as the TextField row): signed in as this panel's identity, the
    /// coordinator configured, apply available, and no settled apply chip.
    private func showsApplyMessage() -> Bool {
        guard coordinator.identity == identity, identity.isSignedIn, !rewardPlaying, coordinator.isConfigured,
              case .available(let action) = availability, action == .apply else { return false }
        return rewardAction != action
    }
    /// True while the seal is landing. The joined or pending chip stays after this ends.
    private var rewardPlaying: Bool {
        rewardAction != nil && rewardAction != .leave && !rewardHandedOff
    }
    var body: some View {
        let _ = revision
        let state = coordinator.state(clubID: club.id)
        Group {
        if placement == .pageEnd {
            pageEndSection
        } else if placement == .floating {
            floatingBar
        } else if ownerHasNothingToDo(state) {
            // Club/Header (skill-r2 `204:24899`): the creator's role is a tag in the header, so the
            // 成员身份 group would only repeat 创建者不能退出自己的俱乐部. Nothing to act on, nothing drawn.
            EmptyView()
        } else {
        Section {
            if coordinator.identity != identity || !identity.isSignedIn {
                Text("club.signInRequired").foregroundStyle(.secondary)
                if let onSignIn {
                    Button("club.signIn", action: onSignIn).accessibilityIdentifier("club.action.signIn")
                }
            } else {
                // Same-account original result/UNKNOWN remains visible after grant revocation.
                // Its journal is not a current permission and cannot enable a new writer.
                CYScreenOfflineWriteBanner(
                    routes: ["/api/club/join", "/api/club/quit"],
                    session: offlineWriteSession.session
                )
                stateContent(state)
                if !coordinator.isConfigured {
                    Text("club.action.unavailable").foregroundStyle(.secondary)
                }
                if let reward = rewardAction, reward != .leave {
                    // The settled join or apply is a status row, like the membership state in Settings.
                    Label {
                        Text(LocalizedStringKey(reward == .apply ? "club.membership.pending" : "club.membership.joined"))
                    } icon: {
                        // Contrast (a11y-dt r3): only the glyph is tinted; orange/green text on the bar is about 2:1.
                        Image(systemName: reward == .apply ? "clock" : "checkmark.circle.fill")
                            .foregroundStyle(reward == .apply ? CYColor.warningText : CYColor.successText)
                    }
                    .transition(.opacity)
                }
                if !rewardPlaying {
                    if coordinator.isConfigured, case .available(let action) = availability {
                        if action == .apply, rewardAction != action {
                            TextField(text: $joinMessage, axis: .vertical) {
                                Text("club.admission.messageLabel", tableName: "ClubApplicationMessage")
                            }
                                .disabled(isWorking || state.preventsNewAction)
                                .accessibilityIdentifier("club.application.message")
                        }
                        // A settled join or apply keeps the chip. Do not offer that action again.
                        if rewardAction != action {
                            membershipRow(action, state: state)
                        }
                    } else {
                        Text(LocalizedStringKey(availabilityKey)).foregroundStyle(.secondary)
                            .accessibilityIdentifier("club.action.gated")
                    }
                }
                if isWorking { ProgressView("club.action.working").accessibilityIdentifier("club.action.loading") }
                if let issueKey { Text(LocalizedStringKey(issueKey)).foregroundStyle(.secondary).accessibilityIdentifier("club.action.error") }
            }
        } header: {
            // Modifiers on the Section itself are applied to each of its rows in a List. Every row
            // carried its own sheet and its own onDisappear, so the 处理中 progress row leaving after
            // prepare ran reset() and cancelled the confirmation before 退出俱乐部 could present
            // `club.action.confirm` (F-08). The lifecycle lives on this one header; the sheet lives
            // on the membership button row the user tapped (see `confirmationPresenter`).
            Text("club.action.membership")
                .onChange(of: identity) { _, _ in reset() }
                .onChange(of: club.id) { old, _ in reset(clubID: old) }
                .onDisappear { reset() }
        } footer: {
            // CLB-r10-nat-detail-08: the message help and the required / too-long text are the Section footer.
            if showsApplyMessage() {
                VStack(alignment: .leading, spacing: 4) {
                    Text("club.application.messageHelp")
                    if !ClubApplicationMessage.isValid(joinMessage, for: .apply) {
                        Group {
                            if ClubApplicationMessage.isMissingRequiredMessage(joinMessage) {
                                Text("club.admission.messageRequired", tableName: "ClubApplicationMessage")
                            } else {
                                Text("club.application.messageTooLong")
                            }
                        }
                        .accessibilityIdentifier("club.application.messageTooLong")
                    }
                }
            }
        }
        }
        }
        .animation(reduceMotion ? nil : .default, value: rewardAction)
    }
    private var confirmationPresented: Binding<Bool> {
        Binding(get: { confirmation != nil }, set: { if !$0 { cancelConfirmation() } })
    }
    /// The one confirmation presenter, attached to the single membership button row (header
    /// placement) or the single page-end row (`.pageEnd`, MC-20).
    /// G-032 (design P1): the system confirmation dialog (an action sheet with a destructive 退出), as Settings uses
    /// to sign out, instead of a custom sheet. The leave consequences are the dialog's message, one per line.
    private func confirmationPresenter<Content: View>(_ content: Content) -> some View {
        content.confirmationDialog(Text(verbatim: confirmation.map { confirmationTitle($0) } ?? ""),
                                   isPresented: confirmationPresented, titleVisibility: .visible,
                                   presenting: confirmation) { value in
            confirmButton(value, confirmIdentifier: "club.action.confirm")
            Button("action.cancel", role: .cancel) { cancelConfirmation() }
        } message: { value in
            Text(verbatim: confirmationBody(value))
        }
    }
    /// The action's own name ("Leave club"), as the UI tests read the dialog; the club is named in the message.
    private func confirmationTitle(_ value: ClubActionConfirmation) -> String {
        String(localized: String.LocalizationValue(actionKey(value.action)))
    }
    private func confirmationBody(_ value: ClubActionConfirmation) -> String {
        guard value.action == .leave else { return confirmationMessage(value) }
        let question = ChannelCopy.text("退出「\(value.clubName)」？", "Leave “\(value.clubName)”?", locale: locale)
        let message = String(localized: String.LocalizationValue(confirmationKey(.leave)))
        let rows = ClubLeaveConsequences.rows(locale: locale, needsApproval: club.needsApproval).map { "· " + $0.text }
        return ([question, message] + rows).joined(separator: "\n")
    }
    /// The dialog's confirm action (`club.action.confirm`): 退出 reads destructive.
    private func confirmButton(_ value: ClubActionConfirmation, confirmIdentifier: String) -> some View {
        Button(role: value.action == .leave ? .destructive : nil) { submit(value) } label: {
            Text(verbatim: String(localized: String.LocalizationValue(actionKey(value.action))))
        }
        .accessibilityIdentifier(confirmIdentifier)
    }
    private var canLeaveHere: Bool {
        guard coordinator.identity == identity, identity.isSignedIn, coordinator.isConfigured, !rewardPlaying,
              case .available(let action) = availability else { return false }
        return action == .leave
    }
    /// One row only, so the F-08 lifecycle and the sheet sit on that row rather than on the Section.
    @ViewBuilder private var pageEndSection: some View {
        if canLeaveHere || (onReportClub != nil && identity.isSignedIn) {
            Section {
                confirmationPresenter(ClubPageEndActions(canLeave: canLeaveHere && !isWorking, onLeave: { prepare(.leave) }, onReport: onReportClub))
                    // CLB-r10-nat-detail-08: the system List cell draws the group (no cleared row and no drawn plate).
                    .listRowInsets(EdgeInsets())
                    .onChange(of: identity) { _, _ in reset() }
                    .onChange(of: club.id) { old, _ in reset(clubID: old) }
                    .onDisappear { reset() }
            }
        }
    }
    @ViewBuilder private func membershipButton(_ action: ClubAction, state: ClubActionState) -> some View {
        let button = Button(role: action == .leave ? .destructive : nil) { prepare(action) } label: {
            Label(LocalizedStringKey(actionKey(action)), systemImage: action == .leave ? "rectangle.portrait.and.arrow.right" : "person.badge.plus")
        }
        .disabled(isWorking || state.preventsNewAction || !ClubApplicationMessage.isValid(action == .apply ? joinMessage : "", for: action))
        .accessibilityIdentifier("club.action.\(action.rawValue)")
        // A Settings-style row action: 退出 reads in the system red (destructive role); 加入 / 申请 in the tint.
        // The 处理中 progress row below shows the in-flight state.
        if action == .leave {
            if !leavesAtPageEnd && placement != .floating { button }
        } else if placement == .floating {
            Button { prepare(action) } label: {
                Label(LocalizedStringKey(actionKey(action)), systemImage: "person.badge.plus").frame(maxWidth: .infinity)
            }
            .disabled(isWorking || state.preventsNewAction || !ClubApplicationMessage.isValid(action == .apply ? joinMessage : "", for: action))
            .accessibilityIdentifier("club.action.\(action.rawValue)")
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
        } else {
            button
        }
    }
    @ViewBuilder private func stateContent(_ state: ClubActionState) -> some View {
        switch state {
        case .outcomeUnknown:
            Text("club.action.unknown").accessibilityIdentifier("club.action.unknown")
            Button("club.action.readback") { readBack() }
                .disabled(isWorking || !coordinator.isConfigured).accessibilityIdentifier("club.action.readback")
            readbackContent
        case .acknowledged(let receipt):
            if let message = receipt.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(verbatim: message).accessibilityIdentifier("club.action.serverMessage")
            } else { Text("club.action.acknowledged").accessibilityIdentifier("club.action.acknowledged") }
            readbackContent
            if coordinator.readback(clubID: club.id) == .unavailable {
                Button("club.action.readback") { readBack() }.disabled(isWorking || !coordinator.isConfigured).accessibilityIdentifier("club.action.readback")
            }
        case .notSent: Text("club.action.notSent").accessibilityIdentifier("club.action.notSent")
        case .rejected(let failure):
            Text("club.action.rejected")
            if let message = failure.message { Text(verbatim: message).accessibilityIdentifier("club.action.serverMessage") }
        default: EmptyView()
        }
    }
    @ViewBuilder private var readbackContent: some View {
        switch coordinator.readback(clubID: club.id) {
        case .received:
            // The displayed club may come from a newer ordinary refresh. Never show
            // an older coordinator snapshot as current membership beside it.
            Label {
        Text(LocalizedStringKey(club.isOwner ? "club.role.creator" : club.isJoined ? "club.membership.joined" : club.joinPending ? "club.membership.pending" : "club.action.notJoined"))
            .accessibilityIdentifier("club.action.serverMembership")
    } icon: {
        // This is a status, not a Refresh action. Keep the decorative symbol
        // out of VoiceOver and attach the status identifier only to its text.
        Image(systemName: "arrow.clockwise").accessibilityHidden(true)
            }
        case .unavailable: Text("club.action.readbackUnavailable").foregroundStyle(.secondary)
        default: EmptyView()
        }
    }
    private func ownerHasNothingToDo(_ state: ClubActionState) -> Bool {
        guard case .owner = availability, state == .idle, rewardAction == nil, !isWorking, issueKey == nil,
              coordinator.identity == identity, identity.isSignedIn, coordinator.isConfigured else { return false }
        return true
    }
    /// MP detail wxml:1028-1036 (owner 2026-10-22): a non-member sees one 加入 / 申请加入 action on 概览, or the
    /// greyed 等待主理人审核; guests sign in first (js:2531). P17 + coordinator 01:20: the action is a bottom bar
    /// (full-width prominent capsule on `.bar` material in the List's bottom safe-area inset), so the list scrolls
    /// above it and nothing is covered. Status and errors sit above the button inside the same bar.
    @ViewBuilder private var floatingBar: some View {
        let state = coordinator.state(clubID: club.id)
        let signedIn = coordinator.identity == identity && identity.isSignedIn
        let showsBar = floatingHasContent(state, signedIn: signedIn)
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if !signedIn {
                if let onSignIn, !club.isJoined, !club.isOwner {
                    Button(action: onSignIn) {
                        Label(LocalizedStringKey(actionKey(club.needsApproval ? .apply : .join)), systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
                    .accessibilityIdentifier("club.action.signIn")
                }
            } else {
                if floatingShowsCard(state) {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYScreenOfflineWriteBanner(
                            routes: ["/api/club/join", "/api/club/quit"],
                            session: offlineWriteSession.session
                        )
                        stateContent(state)
                        if !coordinator.isConfigured {
                            Text("club.action.unavailable").foregroundStyle(.secondary)
                        }
                        if let reward = rewardAction, reward != .leave {
                            Label {
                                Text(LocalizedStringKey(reward == .apply ? "club.membership.pending" : "club.membership.joined"))
                            } icon: {
                                // Contrast (a11y-dt r3): only the glyph is tinted; orange/green text on the bar is about 2:1.
                                Image(systemName: reward == .apply ? "clock" : "checkmark.circle.fill")
                                    .foregroundStyle(reward == .apply ? CYColor.warningText : CYColor.successText)
                            }
                        }
                        if isWorking { ProgressView("club.action.working").accessibilityIdentifier("club.action.loading") }
                        if let issueKey { Text(LocalizedStringKey(issueKey)).foregroundStyle(.secondary).accessibilityIdentifier("club.action.error") }
                        if !rewardPlaying, floatingGatedText {
                            Text(LocalizedStringKey(availabilityKey)).foregroundStyle(.secondary)
                                .accessibilityIdentifier("club.action.gated")
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !rewardPlaying, coordinator.isConfigured, case .available(let action) = availability,
                   action != .leave, rewardAction != action {
                    if action == .apply {
                        Button { applySheet = true } label: {
                            Label(LocalizedStringKey(actionKey(.apply)), systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
                        .disabled(isWorking || state.preventsNewAction)
                        .accessibilityIdentifier("club.action.apply")
                    } else {
                        membershipRow(action, state: state)
                    }
                } else if !rewardPlaying, availability == .pending {
                    // MP join-btn--pending: the greyed, disabled 等待主理人审核 capsule.
                    Button {} label: { Text(LocalizedStringKey(availabilityKey)).frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
                        .disabled(true)
                        .accessibilityIdentifier("club.action.gated")
                }
            }
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, showsBar ? CYSpacing.sm : 0)
        .frame(maxWidth: .infinity)
        .background {
            if showsBar {
                Rectangle().fill(.bar).ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) { Divider() }
            }
        }
        .sheet(isPresented: $applySheet) { applyForm }
        .onChange(of: identity) { _, _ in reset() }
        .onChange(of: club.id) { old, _ in reset(clubID: old) }
        .onDisappear { reset() }
    }
    /// The merchant / unknown-status line; pending is the disabled capsule, and a member or the owner has nothing here.
    private var floatingGatedText: Bool {
        switch availability {
        case .merchant, .unsupportedStatus: return true
        case .owner, .available, .pending: return false
        }
    }
    /// The bottom bar is drawn only when it holds something; a member or the owner gets no empty material strip.
    private func floatingHasContent(_ state: ClubActionState, signedIn: Bool) -> Bool {
        if !signedIn { return onSignIn != nil && !club.isJoined && !club.isOwner }
        if floatingShowsCard(state) { return true }
        if rewardPlaying { return false }
        if availability == .pending { return true }
        if coordinator.isConfigured, case .available(let action) = availability, action != .leave, rewardAction != action { return true }
        return false
    }
    private func floatingShowsCard(_ state: ClubActionState) -> Bool {
        if state != .idle || !coordinator.isConfigured || isWorking || issueKey != nil { return true }
        if let reward = rewardAction, reward != .leave { return true }
        return !rewardPlaying && floatingGatedText
    }
    /// MP detail js:2537-2548 `modal.show({ title: 申请加入, content: 给主理人说一句吧…, editable, confirmText: 提交申请 })`:
    /// the note is required and at most 60 characters; an invalid note keeps 提交申请 disabled instead of re-opening.
    private var applyForm: some View {
        let state = coordinator.state(clubID: club.id)
        let valid = ClubApplicationMessage.isValid(joinMessage, for: .apply)
        return NavigationStack {
            Form {
                Section {
                    Text("club.application.prompt").foregroundStyle(.secondary)
                    TextField(text: $joinMessage, prompt: Text("club.application.placeholder"), axis: .vertical) {
                        Text("club.admission.messageLabel", tableName: "ClubApplicationMessage")
                    }
                    .lineLimit(2...4)
                    .disabled(isWorking || state.preventsNewAction)
                    .accessibilityIdentifier("club.application.message")
                } header: {
                    Text(verbatim: club.name)
                } footer: {
                    if !valid && !ClubApplicationMessage.isMissingRequiredMessage(joinMessage) {
                        Text("club.application.messageTooLong")
                            .accessibilityIdentifier("club.application.messageTooLong")
                    }
                }
            }
            .navigationTitle(Text(LocalizedStringKey(actionKey(.apply))))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { applySheet = false }
                        .accessibilityIdentifier("club.application.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("admission.submit") {
                        applySheet = false
                        submitsOnPrepare = true
                        prepare(.apply)
                    }
                    .disabled(isWorking || state.preventsNewAction || !valid)
                    .accessibilityIdentifier("club.application.submit")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    /// Header and floating placements share the one membership row and its one confirmation presenter.
    @ViewBuilder private func membershipRow(_ action: ClubAction, state: ClubActionState) -> some View {
        confirmationPresenter(membershipButton(action, state: state))
    }
    private var availabilityKey: String {
        switch availability {
        case .owner: return "club.action.owner"
        case .pending: return "club.membership.pending"
        case .merchant: return "club.action.merchant"
        case .unsupportedStatus: return "club.action.unsupported"
        case .available: return "club.action.membership"
        }
    }
    private func actionKey(_ action: ClubAction) -> String {
        if action == .apply && club.myJoinStatus == 2 { return "club.action.reapply" }
        switch action {
        case .join: return "club.action.join"
        case .apply: return "club.action.apply"
        case .leave: return "club.action.leave"
        }
    }
    private func confirmationMessage(_ value: ClubActionConfirmation) -> String {
        var text = value.clubName + "\n" + String(localized: String.LocalizationValue(confirmationKey(value.action)))
        if value.action == .apply { text += "\n" + value.joinMessage }
        return text
    }
    private func confirmationKey(_ action: ClubAction) -> String {
        switch action {
        case .join: return "club.action.confirm.join"
        case .apply: return "club.action.confirm.apply"
        case .leave: return "club.action.confirm.leave"
        }
    }
    private func prepare(_ action: ClubAction) {
        guard !isWorking, coordinator.identity == identity else { return }
        generation &+= 1
        let operation = generation, snapshot = identity, clubID = club.id
        let reviewedMessage = action == .apply ? joinMessage : ""
        let autoSubmit = submitsOnPrepare
        submitsOnPrepare = false
        isWorking = true; issueKey = nil
        task = Task {
            defer { if operation == generation { isWorking = false; revision &+= 1 } }
            do {
                let value = try await coordinator.prepare(clubID: clubID, action: action, expectedIdentity: snapshot, ownerID: ownerID, joinMessage: reviewedMessage)
                guard !Task.isCancelled, operation == generation, coordinator.identity == snapshot else { coordinator.cancel(value); return }
                if autoSubmit {
                    isWorking = false
                    submit(value)
                    return
                }
                confirmation = value
            } catch {
                guard operation == generation, coordinator.identity == snapshot, !Task.isCancelled else { return }
                issueKey = (error as? ClubActionBlock) == .eligibilityChanged ? "club.action.changed" : "club.action.prepareFailed"
                CYHaptics.warning.play()
            }
        }
    }
    private func submit(_ value: ClubActionConfirmation) {
        guard !isWorking, coordinator.identity == value.identity else { cancelConfirmation(); return }
        // Clear local presentation without cancelling the coordinator's frozen intent.
        confirmation = nil; isWorking = true; issueKey = nil
        generation &+= 1
        let operation = generation
        let route = value.action == .leave ? "/api/club/quit" : "/api/club/join"
        let offlineSession = offlineWriteSession.session
        task = Task {
            var readbackGeneration: UInt64?
            _ = await SessionOfflineSyncModel.shared.performWriteOptIn(
                environmentSession: offlineSession,
                routes: [route]
            ) {
                await coordinator.confirm(value, onReadbackStarted: { readbackGeneration = onReadbackStarted() })
            }
            guard operation == generation, !Task.isCancelled, coordinator.identity == value.identity else { return }
            isWorking = false; revision &+= 1
            let acknowledged: Bool = {
                if case .acknowledged = coordinator.state(clubID: club.id) { return true }
                return false
            }()
            if value.action == .leave, acknowledged {
                rewardAction = nil; rewardHandedOff = false; rewardPhase = .landing
                CYHaptics.success.play()
            } else if case .rejected = coordinator.state(clubID: club.id) {
                // A refused join / apply / leave reads as a warning, like the MP toast.
                CYHaptics.warning.play()
            } else if value.action != .leave, acknowledged {
                // The joined / pending status row replaces the button at once; the system haptic marks success.
                rewardAction = value.action
                rewardHandedOff = true
                rewardPhase = .chip
                CYHaptics.success.play()
            }
            if let readbackGeneration { deliverReadback(identity: value.identity, readbackGeneration: readbackGeneration) }
        }
    }
    private func readBack() {
        guard !isWorking, coordinator.identity == identity else { return }
        generation &+= 1
        let operation = generation, snapshot = identity
        isWorking = true; issueKey = nil
        task = Task {
            var readbackGeneration: UInt64?
            _ = await coordinator.readBack(clubID: club.id, ownerID: ownerID, onStarted: { readbackGeneration = onReadbackStarted() })
            guard operation == generation, !Task.isCancelled, coordinator.identity == snapshot else { return }
            isWorking = false; revision &+= 1
            if let readbackGeneration { deliverReadback(identity: snapshot, readbackGeneration: readbackGeneration) }
        }
    }
    private func deliverReadback(identity: ClubReadIdentity, readbackGeneration: UInt64) {
        if case .received(let detail) = coordinator.readback(clubID: club.id), detail.id == club.id { onReadback(detail, identity, readbackGeneration) }
    }
    private func cancelConfirmation() { if let confirmation { coordinator.cancel(confirmation) }; confirmation = nil; revision &+= 1 }
    private func reset(clubID: Int? = nil) {
        generation &+= 1; task?.cancel(); task = nil
        if let confirmation { coordinator.cancel(confirmation) }
        // Synchronization handles old-session writes even when the view now has a new identity.
        coordinator.synchronizeSession()
        coordinator.leaveScreen(clubID: clubID ?? club.id, expectedIdentity: identity, ownerID: ownerID)
        confirmation = nil; isWorking = false; issueKey = nil
        rewardAction = nil; rewardHandedOff = false; rewardPhase = .landing
        applySheet = false; submitsOnPrepare = false
        joinMessage = ""; revision &+= 1
    }
}

enum ClubActionPlacement { case header, pageEnd, floating }

/// Consequence rows of the quit-club confirmation (mini-program `pages/club/detail` quit dialog).
enum ClubLeaveConsequences {
    static func rows(locale: Locale, needsApproval: Bool = false) -> [CYConfirmConsequence] {
        [
            CYConfirmConsequence(systemImage: "rectangle.portrait.and.arrow.right",
                                 text: ChannelCopy.text("你会被移出团群，看不到成员专属内容", "You’ll be removed from the group and lose member-only content", locale: locale)),
            CYConfirmConsequence(systemImage: "ticket",
                                 text: ChannelCopy.text("会员专属活动的报名资格立即失效，已付款项不随退出自动退回", "Member-only event spots end immediately; payments already made are not refunded automatically", locale: locale)),
            CYConfirmConsequence(systemImage: "exclamationmark.triangle",
                                 text: ChannelCopy.text("此操作不可撤销，当前的成员身份与加入时间不会保留", "This can’t be undone; your membership and join date won’t be kept", locale: locale)),
            CYConfirmConsequence(systemImage: "arrow.uturn.backward",
                                 text: ClubPlayerCopy.quitRejoin(needsApproval: needsApproval, locale: locale))
        ]
    }
}
