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
                    Label(LocalizedStringKey(reward == .apply ? "club.membership.pending" : "club.membership.joined"),
                          systemImage: reward == .apply ? "clock" : "checkmark.circle.fill")
                        .foregroundStyle(reward == .apply ? Color.orange : Color.green)
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
                            Text("club.application.messageHelp").font(.footnote).foregroundStyle(.secondary)
                            if !ClubApplicationMessage.isValid(joinMessage, for: .apply) {
                                Group {
                                    if ClubApplicationMessage.isMissingRequiredMessage(joinMessage) {
                                        Text("club.admission.messageRequired", tableName: "ClubApplicationMessage")
                                    } else {
                                        Text("club.application.messageTooLong")
                                    }
                                }.foregroundStyle(.secondary)
                                    .accessibilityIdentifier("club.application.messageTooLong")
                            }
                        }
                        // A settled join or apply keeps the chip. Do not offer that action again.
                        if rewardAction != action {
                            membershipButton(action, state: state)
                                .sheet(isPresented: confirmationPresented) { confirmationSheet }
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
            // on the membership button row the user tapped (see `confirmationSheet`).
            Text("club.action.membership")
                .onChange(of: identity) { _, _ in reset() }
                .onChange(of: club.id) { old, _ in reset(clubID: old) }
                .onDisappear { reset() }
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
    @ViewBuilder private var confirmationSheet: some View {
        if let value = confirmation {
            let title = value.action == .leave
                ? ChannelCopy.text("退出「\(value.clubName)」？", "Leave “\(value.clubName)”?", locale: locale)
                : String(localized: String.LocalizationValue(actionKey(value.action)))
            let message = value.action == .leave
                ? String(localized: String.LocalizationValue(confirmationKey(.leave)))
                : confirmationMessage(value)
            let consequences = value.action == .leave ? ClubLeaveConsequences.rows(locale: locale, needsApproval: club.needsApproval) : []
            NavigationStack {
                List {
                    if consequences.isEmpty {
                        Section { Text(verbatim: message) }
                    } else {
                        Section {
                            ForEach(consequences) { row in
                                Label(row.text, systemImage: row.systemImage)
                            }
                        } footer: { Text(verbatim: message) }
                    }
                }
                .navigationTitle(Text(verbatim: title))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("action.cancel") { cancelConfirmation() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        confirmButton(value, confirmIdentifier: "club.action.confirm")
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    /// The sheet's confirm action (`club.action.confirm`): 退出 reads destructive.
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
                ClubPageEndActions(canLeave: canLeaveHere && !isWorking, onLeave: { prepare(.leave) }, onReport: onReportClub)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .sheet(isPresented: confirmationPresented) { confirmationSheet }
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
            if !leavesAtPageEnd { button }
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
        isWorking = true; issueKey = nil
        task = Task {
            defer { if operation == generation { isWorking = false; revision &+= 1 } }
            do {
                let value = try await coordinator.prepare(clubID: clubID, action: action, expectedIdentity: snapshot, ownerID: ownerID, joinMessage: reviewedMessage)
                guard !Task.isCancelled, operation == generation, coordinator.identity == snapshot else { coordinator.cancel(value); return }
                confirmation = value
            } catch {
                guard operation == generation, coordinator.identity == snapshot, !Task.isCancelled else { return }
                issueKey = (error as? ClubActionBlock) == .eligibilityChanged ? "club.action.changed" : "club.action.prepareFailed"
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
        joinMessage = ""; revision &+= 1
    }
}

enum ClubActionPlacement { case header, pageEnd }

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
